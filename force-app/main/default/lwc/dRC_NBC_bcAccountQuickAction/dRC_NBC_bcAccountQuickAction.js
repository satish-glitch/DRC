import { LightningElement, api } from 'lwc';
import triggerBCIntegration from '@salesforce/apex/DRC_NBC_AccountBCController.triggerBCIntegration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class DRC_NBC_bcAccountQuickAction extends LightningElement {
    @api recordId; 
    isLoading = true; 


    connectedCallback() {
        const url = window.location.href;
        const recordIdMatch = url.match(/([a-zA-Z0-9]{18})/);
        this.recordId = recordIdMatch ? recordIdMatch[1] : null;
        console.log('Record ID:', this.recordId);
        if (!this.recordId) {
            this.showToast('Error', 'No Account Id provided', 'error');
            this.closeAction();
            return;
        }

        triggerBCIntegration({ accountId: this.recordId })
            .then((result) => {
                if (result === 'SUCCESS') {
                    this.showToast('Success', 'Account successfully sent to BC.', 'success');
                } else {
                    this.showToast('Error', result, 'error');
                }
                this.closeAction();
            })
            .catch((error) => {
                this.showToast('Error', error.body?.message || 'Unexpected error', 'error');
                this.closeAction();
            });
    }

    renderedCallback() {
        console.log('>>> recordId in renderedCallback:', this.recordId);
    }


    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}