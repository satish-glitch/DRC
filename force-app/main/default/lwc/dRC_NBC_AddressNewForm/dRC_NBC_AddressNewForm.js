import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';

export default class dRC_NBC_AddressNewForm extends NavigationMixin(LightningElement) {

    @track selectedCountry = '';
    @track currentAccountId;
    @api recordId;

    // Get the recordId from Account page
    @wire(CurrentPageReference)
    getPageRef(pageRef) {
        if (pageRef?.state?.recordId) {
            this.currentAccountId = pageRef.state.recordId;
        }
    }

    // Country selection listener
    handleCountryChange(event) {
        this.selectedCountry = event.target.value;
    }
    
     get isIndia() {
    return this.selectedCountry === 'IN';
   }

    handleSuccess(event) {
        const newRecordId = event.detail.id;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Address created successfully',
                variant: 'success'
            })
        );

        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: newRecordId,
                objectApiName: 'DRC_NBC_Addresses__c',
                actionName: 'view'
            }
        });
    }

    handleCancel() {
        history.back();
    }
}