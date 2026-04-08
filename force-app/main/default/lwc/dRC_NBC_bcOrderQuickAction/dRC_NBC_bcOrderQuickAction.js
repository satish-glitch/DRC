import { LightningElement, api } from 'lwc';
import triggerBCIntegration from '@salesforce/apex/DRC_NBC_OrderBCController.triggerBCIntegration';
import getAccountSyncStatus from '@salesforce/apex/DRC_NBC_OrderBCController.getAccountSyncStatus';
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

        triggerBCIntegration({ orderId: this.recordId })
            .then((integrationResult) => {

                if (integrationResult === 'Account Sync SUCCESS') {
                    // Wait 5s for queueable to finish, then check Posted_To_BC__c once
                    setTimeout(() => {
                        getAccountSyncStatus({ orderId: this.recordId })
                            .then((isPosted) => {
                                this.isLoading = false;
                                if (isPosted === true) {
                                    this.showToast('Success', 'Account has been successfully synced with BC.', 'success');
                                } else {
                                    this.showToast('Error', 'Account sync failed. Please retry.', 'error');
                                }
                                this.closeAction();
                            })
                            .catch((error) => {
                                this.isLoading = false;
                                this.showToast('Error', error.body?.message || 'Failed to verify account sync.', 'error');
                                this.closeAction();
                            });
                    }, 5000);

                } else if (integrationResult?.startsWith('FAILURE') || integrationResult?.startsWith('ERROR')) {
                    this.isLoading = false;
                    this.showToast('Error', integrationResult, 'error');
                    this.closeAction();

                } else {
                    // Order path — unchanged
                    setTimeout(() => {
                        getIntegrationStatus({ orderId: this.recordId })
                            .then((status) => {
                                this.handleOrderStatus(status);
                            })
                            .catch((error) => {
                                this.isLoading = false;
                                this.showToast('Error', error.body?.message || 'Failed to fetch integration status', 'error');
                                this.closeAction();
                            });
                    }, 3000);
                }
            })
            .catch((error) => {
                this.isLoading = false;
                this.showToast('Error', error.body?.message || 'Integration call failed', 'error');
                this.closeAction();
            });
    }

    handleOrderStatus(status) {
        let title = 'Success', variant = 'success', message = '';
        if (status === 'ORDER_SUCCESS') {
            message = 'Order has been successfully pushed to BC.';
        } else if (status === 'ORDER_FAILED') {
            title = 'Error'; variant = 'error';
            message = 'Order push to BC failed. Please check logs.';
        } else if (status === 'IN_PROGRESS') {
            title = 'Info'; variant = 'info';
            message = 'Integration is still in progress. Please check later.';
        } else {
            title = 'Warning'; variant = 'warning';
            message = 'Read Time Out. Try Again.';
        }
        this.isLoading = false;
        this.showToast(title, message, variant);
        this.closeAction();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}