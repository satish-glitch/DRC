import { LightningElement, api, track } from 'lwc';
import getAccountAddressesFromQuote from '@salesforce/apex/DRC_NBC_AddressController.getAccountAddressesFromQuote';
import updateQuoteAddress from '@salesforce/apex/DRC_NBC_AddressController.updateQuoteAddress';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DRC_NBC_QuoteAddressSelector extends LightningElement {
    @api recordId;
    @track shippingAddressOptions = [];
    @track addrDetails = [];
    @track selectedShippingId;
    @track billingAddressDisplay = ''; // Display-only billing address
    activeSections = ["Address Information"];
    
    // Track original values for comparison
    originalShippingId;

    connectedCallback() {
        this.loadAddresses();
    }

    handleSectionToggle(event) {
        const openSections = event.detail.openSections;

        if (openSections.length === 0) {
        } 
    }
    
    async loadAddresses() {
        try {
            const result = await getAccountAddressesFromQuote({ quoteId: this.recordId });
            this.addrDetails = result.addresses || [];
            this.shippingAddressOptions = [];
            
            // Format billing address from Account for display only
            if (result.accountBillingAddress) {
                const addr = result.accountBillingAddress;
                const labelParts = [];
                if (addr.BillingStreet) labelParts.push(addr.BillingStreet);
                if (addr.BillingCity) labelParts.push(addr.BillingCity);
                if (addr.BillingPostalCode) labelParts.push(addr.BillingPostalCode);
                if (addr.BillingCountryCode || addr.BillingCountry) {
                    labelParts.push(addr.BillingCountryCode || addr.BillingCountry);
                }
                this.billingAddressDisplay = labelParts.join(', ') || 'No Billing Address';
            }
            
            // Only populate shipping addresses
            this.addrDetails.forEach(addr => {
                if (addr.DRC_NBC_Type__c === 'Shipping') {
                    const labelParts = [];
                    if (addr.DRC_NBC_Address__Street__s) labelParts.push(addr.DRC_NBC_Address__Street__s);
                    if (addr.DRC_NBC_Address__City__s) labelParts.push(addr.DRC_NBC_Address__City__s);
                    if (addr.DRC_NBC_Address__PostalCode__s) labelParts.push(addr.DRC_NBC_Address__PostalCode__s);
                    if (addr.DRC_NBC_Address__CountryCode__s) labelParts.push(addr.DRC_NBC_Address__CountryCode__s);
                    const label = labelParts.join(', ') || 'Unknown Address';
                    this.shippingAddressOptions.push({ label, value: addr.Id });
                }
            });
            
            // Set selected shipping value from server
            this.selectedShippingId = result.selectedShippingId;
            this.originalShippingId = this.selectedShippingId;

        } catch (error) {
            console.error('Error loading quote addresses:', error);
            this.showToast('Error', 'Failed to load addresses', 'error');
        }
    }

    handleAddressChange(event) {
        const selectedValue = event.detail.value;
        this.selectedShippingId = selectedValue;

        // Notify parent
        this.dispatchEvent(new CustomEvent('addressselected', {
            detail: {
                type: 'shipping',
                addressId: selectedValue
            }
        }));
    }

    get hasChanges() {
        return this.selectedShippingId !== this.originalShippingId;
    }

    async handleSave() {
        try {
            await updateQuoteAddress({
                quoteId: this.recordId,
                shippingAddressId: this.selectedShippingId
            });

            this.originalShippingId = this.selectedShippingId;

            this.showToast('Success', 'Quote shipping address updated successfully', 'success');
        } catch (error) {
            console.error('Failed to update quote address:', error);
            this.showToast('Error', 'Failed to update quote address', 'error');
        }
    }

    handleCancel() {
        this.selectedShippingId = this.originalShippingId;
        this.dispatchEvent(new CustomEvent('cancel'));
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant,
            })
        );
    }
}