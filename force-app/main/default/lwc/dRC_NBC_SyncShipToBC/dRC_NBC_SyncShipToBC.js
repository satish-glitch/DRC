import { LightningElement, api } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import syncByAddressId from '@salesforce/apex/DRC_NBC_Shipping_BC_Integration_SOAP.syncByAddressId';

export default class DRC_NBC_SyncShipToBC extends LightningElement {

    @api recordId;   // automatically set to the Address record Id

    isLoading = false;
    isDone    = false;
    isSuccess = false;
    resultMessage = '';

    // ── Trigger the Apex callout ──────────────────────────────────────────
    handleSync() {
        this.isLoading = true;

        syncByAddressId({ addressId: this.recordId })
            .then(result => {
                this.isLoading = false;
                this.isDone    = true;

                if (result && result.startsWith('SUCCESS')) {
                    this.isSuccess    = true;
                    this.resultMessage = result.replace('SUCCESS: ', '');
                    this._fireToast('Sync Successful', this.resultMessage, 'success');
                } else {
                    this.isSuccess    = false;
                    this.resultMessage = result
                        ? result.replace('FAILURE: ', '')
                        : 'An unexpected error occurred.';
                    this._fireToast('Sync Failed', this.resultMessage, 'error');
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.isDone    = true;
                this.isSuccess = false;
                this.resultMessage = error?.body?.message || 'An unexpected error occurred.';
                this._fireToast('Sync Failed', this.resultMessage, 'error');
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // ── Computed CSS ──────────────────────────────────────────────────────
    get resultClass() {
        return this.isSuccess
            ? 'slds-var-m-top_medium slds-text-body_regular slds-text-color_success'
            : 'slds-var-m-top_medium slds-text-body_regular slds-text-color_error';
    }

    get closeVariant() {
        return this.isSuccess ? 'brand' : 'destructive';
    }

    // ── Toast helper ──────────────────────────────────────────────────────
    _fireToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}