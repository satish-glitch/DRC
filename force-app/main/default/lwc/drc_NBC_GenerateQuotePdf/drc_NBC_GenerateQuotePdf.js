import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import saveQuotePdfToContent from '@salesforce/apex/DRC_NBC_GenerateQuotePdfController.saveQuotePdfToContent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DRC_NBC_GenerateQuotePdf extends LightningElement {
    @api recordId;
    errorFound = false;
    errorMessage;
    isLoading = false;
    vfPageUrl;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state?.recordId;
            console.log('Quote Record ID:', this.recordId);
        }
    }

    connectedCallback() {
        if (this.recordId) {
            this.isLoading = true;
            this.vfPageUrl = '/apex/DRC_NBC_DomesticQuotationTemplate?id=' + this.recordId;
            this.isLoading = false;
        }
    }
    

    savePdf() {
        this.isLoading = true;
        this.errorFound = false;
        const vfPageUrl = this.vfPageUrl + '&pdf=true';
        
        saveQuotePdfToContent({
            recordId: this.recordId,
            vfPageUrl: vfPageUrl,
        })
            .then(() => {
                this.isLoading = false;
                this.showToast('Success', 'Quote PDF saved successfully.', 'success');
                // Close modal and refresh page
                setTimeout(() => {
                    this.dispatchEvent(new CloseActionScreenEvent());
                    // Use Salesforce standard refresh instead of window.location.reload()
                    eval("$A.get('e.force:refreshView').fire();");
                }, 800);
            })
            .catch((error) => {
                this.isLoading = false;
                this.errorFound = true;
                this.errorMessage = this.getErrorMessage(error);
                this.showToast('Error', this.errorMessage, 'error');
                console.error('Error saving Quote PDF:', error);
            });
    }

    getErrorMessage(error) {
        if (typeof error === 'string') {
            return error;
        } else if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        } else if (Array.isArray(error?.body?.pageErrors)) {
            return error.body.pageErrors.map(e => e.message).join(', ');
        } else if (typeof error?.body?.message === 'string') {
            return error.body.message;
        }
        return 'An unknown error occurred while saving the PDF';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}