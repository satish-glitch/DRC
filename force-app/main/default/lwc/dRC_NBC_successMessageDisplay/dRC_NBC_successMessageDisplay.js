import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DRC_NBC_successMessageDisplay extends LightningElement {
    @api message;  // Message from Flow
    @api type;     // 'success' or 'error'

    connectedCallback() {
        const variant = this.type ? this.type.toLowerCase() : 'error';
        this.showToast(variant, this.message);
    }

    showToast(variant, message) {
        const evt = new ShowToastEvent({
            title: variant === 'success' ? 'Success' : 'Error',
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    // Optional: helper getters (can be removed if unused)
    get isSuccess() {
        return this.type && this.type.toLowerCase() === 'success';
    }

    get isError() {
        return this.type && this.type.toLowerCase() === 'error';
    }
}