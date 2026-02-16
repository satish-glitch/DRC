import { LightningElement, api } from 'lwc';
import triggerBCIntegration from '@salesforce/apex/DRC_NBC_OrderBCController.triggerBCIntegration';
import getAccountDetails from '@salesforce/apex/DRC_NBC_OrderBCController.getAccountDetails';
import getIntegrationStatus from '@salesforce/apex/DRC_NBC_OrderBCController.getIntegrationStatus';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class DRC_NBC_bcOrderQuickAction extends LightningElement {
    @api recordId;
    isLoading = true;

    connectedCallback() {
        const url = window.location.href;
        const recordIdMatch = url.match(/([a-zA-Z0-9]{18})/);
        this.recordId = recordIdMatch ? recordIdMatch[1] : null;

        if (!this.recordId) {
            this.showToast('Error', 'No Order Id provided', 'error');
            this.closeAction();
            return;
        }

        getAccountDetails({ orderId: this.recordId })
            .then((account) => {
                const accName = account.Name;

                // Step 1: Trigger Integration
                triggerBCIntegration({ orderId: this.recordId })
                    .then((integrationResult) => {
                        if (integrationResult === 'Account Sync SUCCESS') {
                            this.isLoading = false;
                            this.showToast('Success', 'Account has been successfully synced with BC.', 'success');
                            this.closeAction(); // ✅ No page refresh
                        } else if (
                            integrationResult.startsWith('FAILURE') ||
                            integrationResult.startsWith('ERROR')
                        ) {
                            this.isLoading = false;
                            this.showToast('Error', integrationResult, 'error');
                            this.closeAction();
                        } else {
                            // Step 2: Wait briefly, then fetch Order integration result
                            setTimeout(() => {
                                getIntegrationStatus({ orderId: this.recordId })
                                    .then((status) => {
                                        let toastTitle = 'Success';
                                        let toastVariant = 'success';
                                        let toastMessage = '';

                                        if (status === 'ORDER_SUCCESS') {
                                            toastMessage = `Order has been successfully pushed to BC.`;
                                        } else if (status === 'ORDER_FAILED') {
                                            toastTitle = 'Error';
                                            toastVariant = 'error';
                                            toastMessage = `Order push to BC failed. Please check logs.`;
                                        } else if (status === 'IN_PROGRESS') {
                                            toastTitle = 'Info';
                                            toastVariant = 'info';
                                            toastMessage = 'Integration is still in progress. Please check later.';
                                        } else {
                                            toastTitle = 'Warning';
                                            toastVariant = 'warning';
                                            toastMessage = `Read Time Out. Try Again.`;
                                        }

                                        this.isLoading = false;
                                        this.showToast(toastTitle, toastMessage, toastVariant);
                                        this.closeAction(); // ✅ No page refresh
                                    })
                                    .catch((error) => {
                                        this.isLoading = false;
                                        this.showToast('Error', error.body?.message || 'Failed to fetch integration status', 'error');
                                        this.closeAction();
                                    });
                            }, 3000); // wait 3 seconds to let async jobs process
                        }
                    })
                    .catch((error) => {
                        this.isLoading = false;
                        this.showToast('Error', error.body?.message || 'Integration call failed', 'error');
                        this.closeAction();
                    });
            })
            .catch((error) => {
                this.isLoading = false;
                this.showToast('Error', error.body?.message || 'Could not fetch Account details.', 'error');
                this.closeAction();
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}