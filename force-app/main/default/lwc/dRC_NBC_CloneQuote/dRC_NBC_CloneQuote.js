import { LightningElement, track, api, wire } from 'lwc';
import getQuoteForClone from '@salesforce/apex/DRC_NBC_CloneQuoteController.getQuoteForClone';
import cloneQuoteWithLineItems from '@salesforce/apex/DRC_NBC_CloneQuoteController.cloneQuoteWithLineItems';
import getAccountContacts from '@salesforce/apex/DRC_NBC_CloneQuoteController.getAccountContacts';
import getAccountAddresses from '@salesforce/apex/DRC_NBC_CloneQuoteController.getAccountAddresses';
import searchAccounts from '@salesforce/apex/DRC_NBC_CloneQuoteController.searchAccounts';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import AddProductCSS from '@salesforce/resourceUrl/DRC_NBC_Order_Button_CSS';

export default class DRC_NBC_CloneQuote extends NavigationMixin(LightningElement) {
    @api recordId; // Original Quote ID
    @track showLoading = false;
    @track quoteRec = {};
    @track accountOptions = [];
    @track contactOptions = [];
    @track shippingAddressOptions = [];
    @track billingAddressOptions = [];
    @track lineItemCount = 0;
    
    // Section toggles
    @track isBasicInfoOpen = true;
    @track isPreparedOpen = true;
    @track isAddressOpen = true;
    @track isFinancialOpen = true;

    // Account and Opportunity
    @track selectedAccountId = '';
    @track selectedAccountName = '';
    @track selectedOpportunityId = '';
    @track showAccountSuggestions = false;
    @track filteredAccounts = [];

    // Contact fields
    @track selectedContactId = '';
    @track selectedContactEmail = '';
    @track selectedContactPhone = '';
    @track selectedContactFax = '';
    @track selectedContactName = '';
    @track showContactSuggestions = false;
    @track filteredContacts = [];

    // Address fields
    @track selectedShippingId = '';
    @track accountBillingStreet = '';
    @track accountBillingCity = '';
    @track accountBillingState = '';
    @track accountBillingPostalCode = '';
    @track accountBillingCountry = '';

    // UI control
    @track showInternalHeader = true;
    isCalledFromAura = false;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            let state = currentPageReference.state;
            
            if (state.recordId) {
                this.recordId = state.recordId;
                this.showInternalHeader = false;
                this.isCalledFromAura = false;
            } else if (state.inContextOfRef) {
                try {
                    let context = JSON.parse(window.atob(state.inContextOfRef));
                    this.recordId = context.attributes.recordId;
                    this.showInternalHeader = false;
                    this.isCalledFromAura = true;
                } catch (error) {
                    console.error('Error decoding inContextOfRef:', error);
                }
            } else {
                this.showInternalHeader = true;
                this.isCalledFromAura = false;
            }

            if (this.recordId) {
                this.fetchQuoteData();
            }
        }
    }

    connectedCallback() {
        this.addCustomCss();
        const isInModal = this.template.host.closest('.slds-modal__content') !== null || 
                         this.template.host.closest('div[role="dialog"]') !== null;
        if (isInModal) {
            this.showInternalHeader = false;
        }
    }

    addCustomCss() {
        loadStyle(this, AddProductCSS);
    }

    fetchQuoteData() {
        this.showLoading = true;
        getQuoteForClone({ quoteId: this.recordId })
            .then(result => {
                console.log('Quote Clone Data:', JSON.stringify(result, null, 2));
                
                // Set quote data - Keep Name blank for user to enter
                this.quoteRec = { ...result.quoteData };
                this.quoteRec.Name = ''; // Force blank name
                
                // Set line item count
                this.lineItemCount = result.lineItemCount || 0;
                
                // Set Account - Use accountId from wrapper
                this.selectedAccountId = result.accountId || result.quoteData.AccountId || '';
                this.selectedAccountName = result.accountName || '';
                
                console.log('✅ Selected Account ID:', this.selectedAccountId);
                console.log('✅ Selected Account Name:', this.selectedAccountName);
                
                // Set Opportunity
                this.selectedOpportunityId = result.quoteData.OpportunityId || '';
                
                // Set account options for search
                if (this.selectedAccountId && this.selectedAccountName) {
                    this.accountOptions = [{
                        label: this.selectedAccountName,
                        value: this.selectedAccountId
                    }];
                }
                
                // Set contact options
                this.contactOptions = result.contacts.map(contact => ({
                    label: contact.Name,
                    value: contact.Id,
                    email: contact.Email,
                    phone: contact.Phone,
                    fax: contact.Fax
                }));

                console.log('📞 Loaded contacts:', this.contactOptions.length);

                // Set selected contact info
                this.selectedContactId = result.quoteData.ContactId || '';
                this.selectedContactEmail = result.quoteData.Email || '';
                this.selectedContactPhone = result.quoteData.Phone || '';
                this.selectedContactFax = result.quoteData.Fax || '';
                
                if (this.selectedContactId) {
                    const selected = this.contactOptions.find(c => c.value === this.selectedContactId);
                    this.selectedContactName = selected ? selected.label : '';
                }

                // Set address options
                this.shippingAddressOptions = result.shippingAddresses || [];
                this.billingAddressOptions = result.billingAddresses || [];
                
                console.log('📦 Shipping addresses:', this.shippingAddressOptions.length);
                
                // IMPORTANT: Pre-select shipping address from original quote
                // This keeps the same shipping address selected by default
                this.selectedShippingId = result.quoteData.DRC_NBC_Shipping_Address_Id__c || '';
                console.log('📍 Pre-selected Shipping Address ID:', this.selectedShippingId);

                // Set billing address from Account
                this.accountBillingStreet = result.accountBillingStreet || '';
                this.accountBillingCity = result.accountBillingCity || '';
                this.accountBillingState = result.accountBillingState || '';
                this.accountBillingPostalCode = result.accountBillingPostalCode || '';
                this.accountBillingCountry = result.accountBillingCountry || '';

                this.showLoading = false;
            })
            .catch(error => {
                this.showLoading = false;
                console.error('❌ Error loading quote:', error);
                this.showToastEvent('Error', 'Failed to load quote details: ' + 
                    (error.body?.message || error.message), 'error');
            });
    }

    // Toggle Section Methods
    toggleBasicInfo() {
        this.isBasicInfoOpen = !this.isBasicInfoOpen;
    }

    togglePrepared() {
        this.isPreparedOpen = !this.isPreparedOpen;
    }

    toggleAddressInfo() {
        this.isAddressOpen = !this.isAddressOpen;
    }

    toggleFinancial() {
        this.isFinancialOpen = !this.isFinancialOpen;
    }

    // CSS Class Getters
    get getBasicInfoClass() {
        return `slds-section ${this.isBasicInfoOpen ? 'slds-is-open' : ''}`;
    }

    get getPreparedClass() {
        return `slds-section slds-m-top_medium ${this.isPreparedOpen ? 'slds-is-open' : ''}`;
    }

    get getAddressClass() {
        return `slds-section slds-m-top_medium ${this.isAddressOpen ? 'slds-is-open' : ''}`;
    }

    get getFinancialClass() {
        return `slds-section slds-m-top_medium ${this.isFinancialOpen ? 'slds-is-open' : ''}`;
    }

    // Icon Getters
    get getBasicInfoIcon() {
        return this.isBasicInfoOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getPreparedIcon() {
        return this.isPreparedOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getAddressIcon() {
        return this.isAddressOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getFinancialIcon() {
        return this.isFinancialOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get formattedBillingAddress() {
        const parts = [
            this.accountBillingStreet,
            this.accountBillingCity,
            this.accountBillingState,
            this.accountBillingPostalCode,
            this.accountBillingCountry
        ].filter(Boolean);
        return parts.length > 0 ? parts.join(', ') : 'No billing address found';
    }

    get hasLineItems() {
        return this.lineItemCount > 0;
    }

    get lineItemMessage() {
        return `${this.lineItemCount} line item(s) will be cloned automatically`;
    }

    // Account Lookup Handlers
    handleAccountInputFocus() {
        this.filteredAccounts = this.accountOptions;
        this.showAccountSuggestions = this.accountOptions.length > 0;
    }

    handleAccountInputBlur() {
        setTimeout(() => {
            this.showAccountSuggestions = false;
        }, 200);
    }

    handleAccountInputChange(event) {
        const searchKey = event.target.value;
        this.selectedAccountName = searchKey;

        if (!searchKey || searchKey.length < 2) {
            // Don't clear selectedAccountId if user is just editing
            this.filteredAccounts = [];
            this.showAccountSuggestions = false;
            
            // Only clear if search is completely empty
            if (!searchKey) {
                this.selectedAccountId = '';
                this.contactOptions = [];
                this.shippingAddressOptions = [];
                this.selectedContactId = '';
                this.selectedContactName = '';
                this.selectedContactEmail = '';
                this.selectedContactPhone = '';
                this.selectedContactFax = '';
                this.selectedShippingId = '';
                this.accountBillingStreet = '';
                this.accountBillingCity = '';
                this.accountBillingState = '';
                this.accountBillingPostalCode = '';
                this.accountBillingCountry = '';
            }
            return;
        }

        // Search for accounts
        searchAccounts({ searchTerm: searchKey })
            .then(accounts => {
                this.accountOptions = accounts.map(acc => ({
                    label: acc.Name,
                    value: acc.Id
                }));
                this.filteredAccounts = this.accountOptions;
                this.showAccountSuggestions = this.accountOptions.length > 0;
            })
            .catch(error => {
                console.error('Error searching accounts:', error);
                this.showToastEvent('Error', 'Failed to search accounts: ' + 
                    (error.body?.message || error.message), 'error');
            });
    }

    handleAccountSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;
        
        console.log('🎯 Account Selected - ID:', selectedId, 'Name:', selectedName);
        
        this.selectedAccountId = selectedId;
        this.selectedAccountName = selectedName;
        this.showAccountSuggestions = false;

        // Clear existing contact and address data
        this.contactOptions = [];
        this.shippingAddressOptions = [];
        this.selectedContactId = '';
        this.selectedContactName = '';
        this.selectedContactEmail = '';
        this.selectedContactPhone = '';
        this.selectedContactFax = '';
        this.selectedShippingId = '';
        this.accountBillingStreet = '';
        this.accountBillingCity = '';
        this.accountBillingState = '';
        this.accountBillingPostalCode = '';
        this.accountBillingCountry = '';

        // Fetch contacts and addresses for the new account
        if (this.selectedAccountId) {
            this.fetchContactsForAccount(this.selectedAccountId);
            this.fetchAddressesForAccount(this.selectedAccountId);
        }
    }

    // Opportunity Change Handler
    handleOpportunityChange(event) {
        this.selectedOpportunityId = event.detail.value;
    }

    // Fetch contacts for selected account
    fetchContactsForAccount(accountId) {
        this.showLoading = true;
        
        console.log('🔍 Fetching contacts for Account ID:', accountId);
        
        getAccountContacts({ accountId: accountId })
            .then(data => {
                this.contactOptions = data.map(contact => ({
                    label: contact.Name,
                    value: contact.Id,
                    email: contact.Email,
                    phone: contact.Phone,
                    fax: contact.Fax
                }));
                
                console.log('✅ Fetched contacts for account:', this.contactOptions.length);
                this.showLoading = false;
            })
            .catch(error => {
                this.showLoading = false;
                console.error('❌ Error fetching contacts:', error);
                this.showToastEvent("Error", "Failed to fetch contacts: " + 
                    (error.body?.message || error.message), "error");
            });
    }

    // Fetch addresses for selected account
    fetchAddressesForAccount(accountId) {
        this.showLoading = true;
        
        console.log('🔍 Fetching addresses for Account ID:', accountId);
        
        getAccountAddresses({ accountId: accountId })
            .then(addressResult => {
                console.log('✅ Address Result:', JSON.stringify(addressResult, null, 2));
                
                // Set shipping addresses
                this.shippingAddressOptions = addressResult.shippingAddresses || [];
                console.log('📦 Shipping addresses loaded:', this.shippingAddressOptions.length);
                
                // Set billing address from Account
                this.accountBillingStreet = addressResult.accountBillingStreet || '';
                this.accountBillingCity = addressResult.accountBillingCity || '';
                this.accountBillingState = addressResult.accountBillingState || '';
                this.accountBillingPostalCode = addressResult.accountBillingPostalCode || '';
                this.accountBillingCountry = addressResult.accountBillingCountry || '';
                
                console.log('🏠 Billing address:', this.formattedBillingAddress);
                this.showLoading = false;
            })
            .catch(error => {
                this.showLoading = false;
                console.error('❌ Error fetching addresses:', error);
                this.showToastEvent('Error', 'Failed to load address options: ' + 
                    (error.body?.message || error.message), 'error');
            });
    }

    // Contact Lookup Handlers
    handleContactInputFocus() {
        this.filteredContacts = this.contactOptions;
        this.showContactSuggestions = this.contactOptions.length > 0;
    }

    handleContactInputBlur() {
        setTimeout(() => {
            this.showContactSuggestions = false;
        }, 200);
    }

    handleContactInputChange(event) {
        const searchKey = event.target.value;
        this.selectedContactName = searchKey;

        if (!searchKey) {
            // Don't immediately clear if user is editing
            this.filteredContacts = [];
            this.showContactSuggestions = false;
            
            // Only clear completely if empty
            if (searchKey === '') {
                this.selectedContactId = '';
                this.selectedContactEmail = '';
                this.selectedContactPhone = '';
                this.selectedContactFax = '';
            }
            return;
        }

        this.filteredContacts = this.contactOptions.filter(c =>
            c.label.toLowerCase().includes(searchKey.toLowerCase())
        );
        this.showContactSuggestions = this.filteredContacts.length > 0;
    }

    handleContactSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;
        
        console.log('🎯 Contact Selected - ID:', selectedId, 'Name:', selectedName);
        
        this.selectedContactId = selectedId;
        this.selectedContactName = selectedName;

        const selectedContact = this.contactOptions.find(c => c.value === selectedId);
        if (selectedContact) {
            this.selectedContactEmail = selectedContact.email || '';
            this.selectedContactPhone = selectedContact.phone || '';
            this.selectedContactFax = selectedContact.fax || '';
            
            console.log('📧 Email:', this.selectedContactEmail);
            console.log('📱 Phone:', this.selectedContactPhone);
        }

        this.showContactSuggestions = false;
    }

    // Address Change Handler
    handleAddressChange(event) {
        const field = event.target.name;
        const value = event.detail.value;
        if (field === 'shipping') {
            this.selectedShippingId = value;
            console.log('📍 Shipping Address changed to:', value);
        }
    }

    // Field Change Handler
    handleFieldChange(event) {
        const fieldName = event.target.fieldName || event.target.name || event.target.dataset.field;
        const value = event.detail?.value || event.target.value;
        if (fieldName) {
            this.quoteRec[fieldName] = value;
            console.log(`Field changed: ${fieldName} = ${value}`);
        }
    }

    // Cancel Handler
    handleCancel() {
        const cancelEvent = new CustomEvent('cancel', {
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(cancelEvent);
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // Save Handler
    handleSave() {
        // Validate all required fields
        if (!this.validateFields()) {
            return;
        }

        this.showLoading = true;

        // Prepare quote data for cloning
        const quoteToClone = {
            Name: this.quoteRec.Name,
            Status: this.quoteRec.Status || 'Draft',
            ExpirationDate: this.quoteRec.ExpirationDate,
             DRC_NBC_Lead_Time__c: this.quoteRec.DRC_NBC_Lead_Time__c,
            Description: this.quoteRec.Description,
            CurrencyIsoCode: this.quoteRec.CurrencyIsoCode,
            DRC_NBC_Type__c: this.quoteRec.DRC_NBC_Type__c,
            DRC_NBC_Payemnt_Term__c: this.quoteRec.DRC_NBC_Payemnt_Term__c,
            DRC_NBC_Inco_terms__c: this.quoteRec.DRC_NBC_Inco_terms__c,
            DRC_NBC_Special_Requirements__c: this.quoteRec.DRC_NBC_Special_Requirements__c,
            OpportunityId: this.selectedOpportunityId,
            AccountId: this.selectedAccountId,  // CRITICAL: Include AccountId
            ContactId: this.selectedContactId,
            Email: this.selectedContactEmail,
            Phone: this.selectedContactPhone,
            Fax: this.selectedContactFax,
            DRC_NBC_Other_Tax_Amount__c: this.quoteRec.DRC_NBC_Other_Tax_Amount__c || 0,
            DRC_NBC_TCS_Amount__c: this.quoteRec.DRC_NBC_TCS_Amount__c || 0,
            DRC_NBC_Shipping_Address_Id__c: this.selectedShippingId,
            BillingStreet: this.accountBillingStreet,
            BillingCity: this.accountBillingCity,
            BillingState: this.accountBillingState,
            BillingPostalCode: this.accountBillingPostalCode,
            BillingCountry: this.accountBillingCountry
        };

        console.log('🚀 Cloning Quote with data:', JSON.stringify(quoteToClone, null, 2));

        cloneQuoteWithLineItems({
            originalQuoteId: this.recordId,
            quoteData: quoteToClone
        })
            .then(result => {
                console.log('✅ Clone Result:', JSON.stringify(result, null, 2));
                this.showToastEvent('Success', result.message || 'Quote cloned successfully', 'success');
                
                // Close the modal
                this.dispatchEvent(new CloseActionScreenEvent());
                
                // Navigate to the new quote
                if (result.quoteId) {
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: result.quoteId,
                            objectApiName: 'Quote',
                            actionName: 'view'
                        }
                    });
                }
            })
            .catch(error => {
                console.error('❌ Clone Error:', JSON.stringify(error, null, 2));
                const message = error?.body?.message || error?.message || 'Unknown error occurred';
                this.showToastEvent('Error', message, 'error');
            })
            .finally(() => {
                this.showLoading = false;
            });
    }

    validateFields() {
        let isValid = true;

        // Validate Quote Name - NOW REQUIRED AND MUST NOT BE BLANK
        if (!this.quoteRec?.Name || this.quoteRec.Name.trim() === '') {
            this.showToastEvent("Error", "Quote Name is required", "error");
            isValid = false;
        }

        // Validate Expiration Date
        if (!this.quoteRec?.ExpirationDate) {
            this.showToastEvent("Error", "Expiration Date is required", "error");
            isValid = false;
        } else {
            const expirationDate = new Date(this.quoteRec.ExpirationDate + 'T00:00:00');
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            
            if (expirationDate <= today) {
                this.showToastEvent("Error", "Expiration Date must be a future date", "error");
                isValid = false;
            }
        }
        if (!this.quoteRec?.DRC_NBC_Lead_Time__c) {
            this.showToastEvent("Error", "Lead Date is required", "error");
            isValid = false;
        }

        // Validate Account - CRITICAL VALIDATION
        if (!this.selectedAccountId) {
            this.showToastEvent("Error", "Please select an Account", "error");
            console.error('❌ Validation failed: No Account selected');
            console.error('selectedAccountId:', this.selectedAccountId);
            console.error('selectedAccountName:', this.selectedAccountName);
            isValid = false;
        }

        // Validate Opportunity
        if (!this.selectedOpportunityId) {
            this.showToastEvent("Error", "Please select an Opportunity", "error");
            isValid = false;
        }

        // Validate Contact
        if (!this.selectedContactId) {
            this.showToastEvent("Error", "Please select a contact", "error");
            isValid = false;
        }

        if (!this.selectedContactEmail) {
            this.showToastEvent("Error", "Selected contact must have an email address", "error");
            isValid = false;
        }

        if (!this.selectedContactPhone) {
            this.showToastEvent("Error", "Selected contact must have a phone number", "error");
            isValid = false;
        }

        // Validate Financial Fields
        if (!this.quoteRec.DRC_NBC_Payemnt_Term__c) {
            this.showToastEvent("Error", "Payment Term is required", "error");
            isValid = false;
        }

        if (!this.quoteRec.DRC_NBC_Inco_terms__c) {
            this.showToastEvent("Error", "Inco Term is required", "error");
            isValid = false;
        }

        if (!this.quoteRec.DRC_NBC_Type__c) {
            this.showToastEvent("Error", "Type is required", "error");
            isValid = false;
        }

        if (!this.quoteRec.Status) {
            this.showToastEvent("Error", "Status is required", "error");
            isValid = false;
        }

        if (!this.quoteRec.CurrencyIsoCode) {
            this.showToastEvent("Error", "Currency is required", "error");
            isValid = false;
        }

        // Validate Shipping Address
        if (!this.selectedShippingId) {
            this.showToastEvent("Error", "Please select Shipping Address", "error");
            isValid = false;
        }

        return isValid;
    }

    showToastEvent(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title,
            message,
            variant
        }));
    }
}