import { LightningElement, api } from 'lwc';
import triggerBCIntegration from '@salesforce/apex/DRC_NBC_OrderBCController.triggerBCIntegration';
import getLatestLog from '@salesforce/apex/DRC_NBC_OrderBCController.getLatestLog';
import getOrderPaymentTerm from '@salesforce/apex/DRC_NBC_OrderBCController.getOrderPaymentTerm';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

const ADVANCE_PAYMENT_TERM = '100%ADV';

export default class DRC_NBC_bcOrderQuickAction extends LightningElement {
    @api recordId;
    isLoading        = true;  // spinner on immediately when panel opens
    showConfirmation = false;

    _pollCount            = 0;
    _maxPolls             = 6;
    _pollInterval         = 5000;
    _integrationStartTime = null;

    connectedCallback() {
        const url = window.location.href;
        const recordIdMatch = url.match(/([a-zA-Z0-9]{18})/);
        this.recordId = recordIdMatch ? recordIdMatch[1] : null;

        if (!this.recordId) {
            this.showToast('Error', 'No Order Id provided', 'error');
            this.closeAction();
            return;
        }

        // Fetch payment term first — spinner is already showing
        getOrderPaymentTerm({ orderId: this.recordId })
            .then((paymentTerm) => {
                if (paymentTerm === ADVANCE_PAYMENT_TERM) {
                    // Stop spinner, show confirmation popup
                    this.isLoading = false;
                    this.showConfirmation = true;
                } else {
                    // Keep spinner running, fire integration silently
                    this.startIntegration();
                }
            })
            .catch((error) => {
                this.isLoading = false;
                this.showToast('Error', error.body?.message || 'Failed to fetch payment term.', 'error');
                this.closeAction();
            });
    }

    // User clicked "Yes, Sync to BC"
    handleConfirm() {
        this.showConfirmation = false;
        this.isLoading = true;  // spinner back on while integration runs
        this.startIntegration();
    }

    // User clicked "Cancel"
    handleCancel() {
        this.showConfirmation = false;
        this.closeAction();
    }

    startIntegration() {
        this._integrationStartTime = new Date().toISOString();

        triggerBCIntegration({ orderId: this.recordId })
            .then((integrationResult) => {
                if (
                    integrationResult == null ||
                    integrationResult?.startsWith('FAILURE') ||
                    integrationResult?.startsWith('ERROR')
                ) {
                    this.isLoading = false;
                    this.showToast('Error', integrationResult || 'Integration returned no result.', 'error');
                    this.closeAction();
                } else {
                    this._pollCount = 0;
                    const delay = integrationResult?.startsWith('QUEUED') ? this._pollInterval : 3000;
                    setTimeout(() => this.pollLog(), delay);
                }
            })
            .catch((error) => {
                this.isLoading = false;
                this.showToast('Error', error.body?.message || 'Integration call failed', 'error');
                this.closeAction();
            });
    }

    pollLog() {
        this._pollCount++;

        getLatestLog({
            orderId       : this.recordId,
            afterDateTime : this._integrationStartTime
        })
            .then((log) => {
                if (log) {
                    this.isLoading = false;

                    const logType = (log.DRC_NBC_Log_Type__c || '').trim().toLowerCase();

                    if (logType === 'error') {
                        const errorMessage = this.extractMessage(
                            log.DRC_NBC_Response_Body__c,
                            log.DRC_NBC_Error_Message__c
                        );
                        this.showToast('Error', errorMessage, 'error');

                    } else if (logType === 'success') {
                        const successMessage = this.extractMessage(
                            log.DRC_NBC_Response_Body__c,
                            null
                        );
                        this.showToast(
                            'Success',
                            successMessage || 'Successfully synced to Business Central.',
                            'success'
                        );

                    } else {
                        this.showToast(
                            'Info',
                            'Sync in progress, please refresh after a few minutes.',
                            'info'
                        );
                    }

                    this.closeAction();

                } else if (this._pollCount < this._maxPolls) {
                    setTimeout(() => this.pollLog(), this._pollInterval);

                } else {
                    this.isLoading = false;
                    this.showToast(
                        'Warning',
                        'Read timeout — sync in progress, please refresh after a few minutes.',
                        'warning'
                    );
                    this.closeAction();
                }
            })
            .catch((error) => {
                this.isLoading = false;
                this.showToast('Error', error.body?.message || 'Failed to fetch integration log.', 'error');
                this.closeAction();
            });
    }

    extractMessage(responseBody, errorMsg) {
        if (responseBody) {
            if (responseBody.trim().startsWith('<')) {
                try {
                    const parser = new DOMParser();
                    const xmlDoc = parser.parseFromString(responseBody, 'text/xml');

                    const faultString = xmlDoc.querySelector('Fault faultstring')
                                     || xmlDoc.querySelector('faultstring');
                    if (faultString?.textContent) {
                        return faultString.textContent;
                    }

                    const detailString = xmlDoc.querySelector('detail string')
                                      || xmlDoc.querySelector('string');
                    if (detailString?.textContent) {
                        return detailString.textContent;
                    }
                } catch (e) {
                    // XML parse failed — fall through
                }
                return responseBody;
            }

            try {
                const parsed = JSON.parse(responseBody);

                if (parsed.error?.message) {
                    return parsed.error.message;
                }
                if (parsed.message) {
                    return parsed.message;
                }
                if (parsed.Message) {
                    return parsed.Message;
                }
                return JSON.stringify(parsed);

            } catch (e) {
                return responseBody;
            }
        }

        return errorMsg || 'Integration failed. Please check logs.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}