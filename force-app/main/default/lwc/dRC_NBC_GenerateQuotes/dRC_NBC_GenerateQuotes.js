import { LightningElement, api, track } from 'lwc';
import getOpportunityContacts from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.getOpportunityContacts';
import getQuoteMdtDetails from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.getQuoteMdtDetails';
import searchProducts from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.searchProducts';
import getAccountBillingAddress from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.getAccountBillingAddress';
import getAccountAddresses from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.getAccountAddresses';
import createQuoteWithLines from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import DRC_NBC_Order_Button_CSS from '@salesforce/resourceUrl/DRC_NBC_Order_Button_CSS';

export default class DRC_NBC_Generate_Quotes extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @track showModal = true;
    @track isLoading = false;
    @track quoteRec = {};
    @track contactOptions = [];
    @track allContacts = [];
    @track selectedContactId;
    @track selectedContactName = '';
    @track selectedContactEmail = '';
    @track selectedContactPhone = '';
    @track selectedContactFax = '';
    @track billingAddressDisplay = '';
    @track shippingAddressOptions = [];
    @track addrDetails = [];
    @track selectedShippingId;
    @track currencyCode;
    @track showContactSuggestions = false;
    @track filteredContacts = [];
    oppCurrency;
    accountSpecialInstruction;

    // Product table data
    @track filteredData = [];
    @track showFilterData = false;
    @track showAddProducts = true;
    @track productsMasterList = [];

    @track isFinancialOpen = true;
    @track isBasicInfoOpen = true;
    @track isPreparedOpen = true;
    @track isAddressOpen = true;
    @track isProductOpen = true;

    toggleBasicInfo() {
        this.isBasicInfoOpen = !this.isBasicInfoOpen;
    }

    togglePrepared() {
        this.isPreparedOpen = !this.isPreparedOpen;
    }

    toggleAddressInfo() {
        this.isAddressOpen = !this.isAddressOpen;
    }

    toggleProduct() {
        this.isProductOpen = !this.isProductOpen;
    }

    toggleFinancial() {
        this.isFinancialOpen = !this.isFinancialOpen;
    }

    get getBasicInfoClass() {
        return `slds-section ${this.isBasicInfoOpen ? 'slds-is-open' : ''}`;
    }

    get getPreparedClass() {
        return `slds-section slds-m-top_medium ${this.isPreparedOpen ? 'slds-is-open' : ''}`;
    }

    get getAddressClass() {
        return `slds-section slds-m-top_medium ${this.isAddressOpen ? 'slds-is-open' : ''}`;
    }

    get getProductClass() {
        return `slds-section slds-m-top_medium ${this.isProductOpen ? 'slds-is-open' : ''}`;
    }

    get getFinancialClass() {
        return `slds-section slds-m-top_medium ${this.isFinancialOpen ? 'slds-is-open' : ''}`;
    }

    get getBasicInfoIcon() {
        return this.isBasicInfoOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getPreparedIcon() {
        return this.isPreparedOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getAddressIcon() {
        return this.isAddressOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getProductIcon() {
        return this.isProductOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getFinancialIcon() {
        return this.isFinancialOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get isDomestic() {
        return this.quoteRec?.DRC_NBC_Type__c === 'Domestic';
    }
     get isExport() {
        return this.quoteRec?.DRC_NBC_Type__c === 'Export';
    }

    connectedCallback() {
        this.extractRecordIdFromUrl();
        console.log('Component connected with recordId:', this.recordId);
        if (!this.recordId) {
            console.error('No recordId available');
            this.showToast('Error', 'No Opportunity ID found. Please try again.', 'error');
            this.isLoading = false;
            return;
        }
        if (!this.currencyCode) {
            this.currencyCode = 'INR';
            this.quoteRec.CurrencyIsoCode = 'INR';
            console.log('Defaulting currency to INR');
        }
        this.quoteRec.Status = 'Draft';
        this.isLoading = true;
        this.initializeComponent();
        this.loadCustomStyles();
        
        // Don't show any products initially - user must click "Add Products"
        this.filteredData = [];
        this.showFilterData = false;
        this.showAddProducts = true;
    }

    extractRecordIdFromUrl() {
        const url = window.location.href;
        const recordIdMatch = url.match(/([a-zA-Z0-9]{18})/);
        this.recordId = recordIdMatch ? recordIdMatch[1] : null;
        console.log('Record ID:', this.recordId);
    }

    loadCustomStyles() {
        Promise.all([
            loadStyle(this, DRC_NBC_Order_Button_CSS)
        ])
            .then(() => console.log('All custom styles loaded.'))
            .catch(error => console.error('Error loading styles:', error));
    }

    async initializeComponent() {
        try {
            console.log('Initializing component with Opportunity ID:', this.recordId);
            if (!this.recordId) {
                throw new Error('Opportunity ID is missing');
            }

            const [contacts, billingAddress, shippingAddresses, quoteWrapper] = await Promise.all([
                getOpportunityContacts({ oppId: this.recordId }),
                getAccountBillingAddress({ oppId: this.recordId }),
                getAccountAddresses({ oppId: this.recordId }),
                getQuoteMdtDetails({ oppId: this.recordId })
            ]);

            console.log('Contacts fetched:', contacts?.length || 0);
            console.log('Addresses fetched:', shippingAddresses?.length || 0);
            console.log('oppCurrecy', JSON.stringify(quoteWrapper));

            this.oppCurrency = quoteWrapper.oppCurrency || [];
            this.accountSpecialInstruction = quoteWrapper.accountSpecialInstruction || [];
            this.accountId = quoteWrapper.accountId;
            this.allContacts = contacts || [];
            this.contactOptions = this.allContacts.map(contact => ({
                label: contact.Name,
                value: contact.Id,
                email: contact.Email,
                phone: contact.Phone,
                fax: contact.Fax
            }));
            if (quoteWrapper.accountSpecialInstruction) {
                this.quoteRec.DRC_NBC_Special_Requirements__c = quoteWrapper.accountSpecialInstruction;
            }

            // Auto-select first contact if available
            if (this.contactOptions.length > 0) {
                const firstContact = this.contactOptions[0];
                this.selectedContactId = firstContact.value;
                this.selectedContactName = firstContact.label;
                this.selectedContactEmail = firstContact.email || '';
                this.selectedContactPhone = firstContact.phone || '';
                this.selectedContactFax = firstContact.fax || '';
                
                // Update quote record with selected contact
                this.quoteRec.ContactId = firstContact.value;
                this.quoteRec.Email = firstContact.email || '';
                this.quoteRec.Phone = firstContact.phone || '';
                this.quoteRec.Fax = firstContact.fax || '';
                
                console.log('Auto-selected first contact:', {
                    id: firstContact.value,
                    name: firstContact.label,
                    email: firstContact.email
                });
            } else {
                console.log('No contacts found for this opportunity');
            }

            // Initialize filtered contacts for search
            this.filteredContacts = this.contactOptions;

            if (billingAddress) {
                const labelParts = [];
                if (billingAddress.street) labelParts.push(billingAddress.street);
                if (billingAddress.city) labelParts.push(billingAddress.city);
                if (billingAddress.state) labelParts.push(billingAddress.state);
                if (billingAddress.postalCode) labelParts.push(billingAddress.postalCode);
                if (billingAddress.country) labelParts.push(billingAddress.country);

                this.billingAddressDisplay = labelParts.join(', ') || 'No billing address found';
                
                this.quoteRec.BillingStreet = billingAddress.street || '';
                this.quoteRec.BillingCity = billingAddress.city || '';
                this.quoteRec.BillingState = billingAddress.state || '';
                this.quoteRec.BillingPostalCode = billingAddress.postalCode || '';
                this.quoteRec.BillingCountry = billingAddress.country || '';
                this.quoteRec.BillingCountryCode = billingAddress.countryCode || '';
            }

            this.addrDetails = shippingAddresses || [];
            this.shippingAddressOptions = [];

            shippingAddresses.forEach(addr => {
                const details = addr.DRC_NBC_Address__c;
                const labelParts = [];
                if (details?.street) labelParts.push(details.street);
                if (details?.city) labelParts.push(details.city);
                if (details?.postalCode) labelParts.push(details.postalCode);
                if (details?.country) labelParts.push(details.country);
                if (details?.state) labelParts.push(details.state);

                const label = labelParts.join(', ') || 'Unknown Address';
                this.shippingAddressOptions.push({ label, value: addr.Id });
            });

            // Auto-select shipping address if only one exists
            if (this.shippingAddressOptions.length === 1) {
                this.selectedShippingId = this.shippingAddressOptions[0].value;
                this.updateShippingAddress(this.selectedShippingId);
            }

            console.log('Component initialized successfully');

        } catch (error) {
            console.error('Initialization Error:', error);
            this.showToast('Error', 'Failed to load initial data: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Handler for "Add Products" button click - creates first row
    handleAddFirstRow() {
        let newRow = this.getBaseRecordData();
        newRow.ProductName = '';
        newRow.searchResults = [];
        newRow.showSearch = true;
        newRow.noResultsFound = false;

        this.filteredData = [{ id: Date.now().toString(), recordData: newRow }];
        this.showFilterData = true;
        this.showAddProducts = false;
    }

    // Handler for plus icon - adds additional rows
    handleAddRow() {
        let newRow = this.getBaseRecordData();
        newRow.ProductName = '';
        newRow.showSearch = true;
        newRow.searchResults = [];
        newRow.noResultsFound = false;

        this.filteredData.push({ id: Date.now().toString(), recordData: newRow });
        this.filteredData = [...this.filteredData];
    }

    handleRemoveRow(event) {
        const index = parseInt(event.target.dataset.index);
        this.filteredData.splice(index, 1);
        
        if (this.filteredData.length === 0) {
            this.showAddProducts = true;
            this.showFilterData = false;
        } else {
            this.filteredData = [...this.filteredData];
        }
    }

    // NEW METHOD: Clear selected product and return to search mode
    handleClearProduct(event) {
        const index = parseInt(event.currentTarget.dataset.index);
        
        // Reset the row to search mode with base data
        let clearedRow = this.getBaseRecordData();
        clearedRow.ProductName = '';
        clearedRow.searchResults = [];
        clearedRow.showSearch = true;
        clearedRow.noResultsFound = false;
        
        this.filteredData[index].recordData = clearedRow;
        this.filteredData = [...this.filteredData];
        
        console.log('Product cleared for row:', index);
    }

    // Contact Search Handlers
    handleContactInputFocus() {
        this.filteredContacts = this.contactOptions;
        this.showContactSuggestions = true;
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
            this.selectedContactId = null;
            this.selectedContactEmail = '';
            this.selectedContactPhone = '';
            this.selectedContactFax = '';

            this.quoteRec.ContactId = null;
            this.quoteRec.Email = '';
            this.quoteRec.Phone = '';
            this.quoteRec.Fax = '';

            this.filteredContacts = [];
            this.showContactSuggestions = true;
            return;
        }

        this.filteredContacts = this.contactOptions.filter(c =>
            c.label.toLowerCase().includes(searchKey.toLowerCase())
        );
        this.showContactSuggestions = true;
    }

    handleContactSelect(event) {
        const selectedId = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;

        this.selectedContactId = selectedId;
        this.selectedContactName = selectedName;

        const selectedContact = this.contactOptions.find(c => c.value === selectedId);
        if (selectedContact) {
            this.selectedContactEmail = selectedContact.email || '';
            this.selectedContactPhone = selectedContact.phone || '';
            this.selectedContactFax = selectedContact.fax || '';
        }

        this.quoteRec.ContactId = selectedId;
        this.quoteRec.Email = this.selectedContactEmail;
        this.quoteRec.Phone = this.selectedContactPhone;
        this.quoteRec.Fax = this.selectedContactFax;

        this.showContactSuggestions = false;
    }

    handleAddressChange(event) {
        const selectedValue = event.detail.value;
        this.selectedShippingId = selectedValue;
        this.updateShippingAddress(selectedValue);
    }

    updateShippingAddress(addressId) {
        const selectedAddr = this.addrDetails.find(addr => addr.Id === addressId);

        if (!selectedAddr) {
            console.warn('No matching shipping address found for ID:', addressId);
            return;
        }

        const addr = selectedAddr.DRC_NBC_Address__c;
        if (!addr || typeof addr !== 'object') {
            console.warn('Invalid address format for selectedAddr:', selectedAddr);
            return;
        }
        this.quoteRec.DRC_NBC_Shipping_Address_Id__c = addressId;
        this.quoteRec.ShippingStreet = addr.street || '';
        this.quoteRec.ShippingCity = addr.city || '';
        this.quoteRec.ShippingPostalCode = addr.postalCode || '';
        this.quoteRec.ShippingCountry = addr.country || '';
        this.quoteRec.ShippingCountryCode = addr.countryCode || '';
        this.quoteRec.ShippingStateCode = addr.stateCode || '';
    }

    handleFieldChange(event) {
        try {
            const fieldName = event.target.fieldName || event.target.dataset.field;
            const value = event.detail?.value || event.target.value;

            if (fieldName) {
                this.quoteRec[fieldName] = value;

                if (fieldName === 'CurrencyIsoCode') {
                    this.currencyCode = value;
                }

                console.log('Quote field updated:', fieldName, '=', value);
            }
        } catch (error) {
            console.error('Error in handleFieldChange:', error);
        }
    }

    // Product Table Handlers
    handleValueChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.name;
        const value = event.target.value;
        
        this.filteredData[index].recordData[field] = value;

        // Trigger product search when typing in ProductName field
        if (field === 'ProductName' && value.length >= 2) {
            if (!this.currencyCode) {
                this.showToast('Warning', 'Please select a currency first', 'warning');
                return;
            }

            searchProducts({
                keyword: value,
                currencyIsoCode: this.currencyCode,
                accountId: this.accountId
            })
                .then(results => {
                    this.filteredData[index].recordData.searchResults = results;
                    this.filteredData[index].recordData.noResultsFound = results.length === 0;
                    this.filteredData = [...this.filteredData];
                })
                .catch(error => {
                    console.error('Product search error:', error);
                    this.filteredData[index].recordData.searchResults = [];
                    this.filteredData[index].recordData.noResultsFound = false;
                    this.filteredData = [...this.filteredData];
                });
        } else if (field === 'ProductName' && value.length < 2) {
            this.filteredData[index].recordData.searchResults = [];
            this.filteredData[index].recordData.noResultsFound = false;
            this.filteredData = [...this.filteredData];
        }
    }

    // NEW: Parse packing sizes from multiselect picklist
    parsePackingSizes(packingSizesString) {
        if (!packingSizesString) return [];
        
        // Split by semicolon (Salesforce multiselect picklist separator)
        return packingSizesString.split(';').map(size => ({
            label: size.trim(),
            value: size.trim()
        }));
    }

    // NEW: Extract number from packing size (e.g., "PAPER BAGS 15 KGS" -> 15)
    extractPackingNumber(packingSizeText) {
        if (!packingSizeText) return null;
        
        // Match any number in the string
        const match = packingSizeText.match(/(\d+(?:\.\d+)?)/);
        return match ? parseFloat(match[1]) : null;
    }

    handleProductSelect(event) {
        const index = parseInt(event.target.dataset.index);
        const selectedId = event.target.dataset.id;
        const searchResults = this.filteredData[index].recordData.searchResults;
        const selectedProduct = searchResults.find(p => p.PricebookEntryId === selectedId);

        if (selectedProduct) {
            const unitPrice = selectedProduct.UnitPrice || 0;
            
            // Parse packing sizes into options
            const packingSizeOptions = this.parsePackingSizes(selectedProduct.PackingSizes);
            
            // Update the row with selected product details
            this.filteredData[index].recordData = {
                ...this.filteredData[index].recordData,
                showSearch: false,
                ProductName: selectedProduct.Name,
                Name: selectedProduct.Name,
                Product2Id: selectedProduct.Product2Id,
                Description: '',
                UnitPrice: unitPrice,
                OriginalUnitPrice: unitPrice,
                DRC_NBC_HSN_SAC_Code__c: selectedProduct.HSNCode || '-',
                DRC_NBC_FG_Code__c: selectedProduct.FGCode || '-',
                PricebookEntryId: selectedProduct.PricebookEntryId,
                DRC_NBC_Unit_Of_Measurement__c: selectedProduct.QuantityUnitOfMeasure || '-',
                modifiedPrice: unitPrice,
                packingSizeOptions: packingSizeOptions,
                selectedPackingSize: '',
                packingQuantity: '',
                searchResults: [],
                noResultsFound: false
            };
            this.filteredData = [...this.filteredData];
        }
    }

    // NEW: Handle packing size selection
    handlePackingSizeChange(event) {
        const index = event.target.dataset.index;
        const selectedSize = event.detail.value;
        
        this.filteredData[index].recordData.selectedPackingSize = selectedSize;
        
        // Calculate packing quantity: Quantity / extracted number from packing size
        const quantity = this.filteredData[index].recordData.Quantity || 0;
        const packingNumber = this.extractPackingNumber(selectedSize);
        
        if (packingNumber && packingNumber > 0) {
            const packingQty = Math.ceil(quantity / packingNumber);
            this.filteredData[index].recordData.packingQuantity = String(packingQty);
        } else {
            this.filteredData[index].recordData.packingQuantity = '';
        }
        
        this.filteredData = [...this.filteredData];
    }

    // MODIFIED: Recalculate packing quantity when main quantity changes
    handleQuantityChange(event) {
        const index = event.target.dataset.index;
        const quantity = parseFloat(event.target.value) || 0;
        
        this.filteredData[index].recordData.Quantity = quantity;
        
        // Recalculate packing quantity if packing size is selected
        const selectedSize = this.filteredData[index].recordData.selectedPackingSize;
        if (selectedSize) {
            const packingNumber = this.extractPackingNumber(selectedSize);
            if (packingNumber && packingNumber > 0) {
                const packingQty = Math.ceil(quantity / packingNumber);
                this.filteredData[index].recordData.packingQuantity = String(packingQty);
            }
        }
        
        this.filteredData = [...this.filteredData];
    }
    
    handleModifiedPriceChange(event) {
        const index = event.target.dataset.index;
        const value = parseFloat(event.target.value) || 0;
        this.filteredData[index].recordData.modifiedPrice = value;
        this.filteredData = [...this.filteredData];
    }

    getBaseRecordData() {
        return {
            Id: null,
            Name: '',
            PricebookEntryId: '',
            Description: '',
            Discount: 0,
            ListPrice: 0,
            Product2Id: '',
            Quantity: 1,
            UnitPrice: 0,
            OriginalUnitPrice: 0,
            ProductName: '',
            DRC_NBC_HSN_SAC_Code__c: '-',
            DRC_NBC_FG_Code__c:'-',
            DRC_NBC_Unit_Of_Measurement__c: '-',
            modifiedPrice: 0,
            packingSizeOptions: [],
            selectedPackingSize: '',
            packingQuantity: '',
            showSearch: true,
            searchResults: [],
            noResultsFound: false
        };
    }

    validateQuoteData() {
        if (!this.quoteRec.ExpirationDate) {
            this.showToast('Error', 'Please enter Expiration Date.', 'error');
            return false;
        }
         if (!this.quoteRec.DRC_NBC_Lead_Time__c) {
            this.showToast('Error', 'Please enter Lead  Date.', 'error');
            return false;
        }

        const expirationDate = new Date(this.quoteRec.ExpirationDate + 'T00:00:00');
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        const todayStr = `${yyyy}-${mm}-${dd}`;
        const todayDate = new Date(todayStr + 'T00:00:00');

        // Compare expiration date with today
        if (expirationDate <= !this.quoteRec.DRC_NBC_Lead_Time__c) {
            this.showToast(
                'Error',
                'Expiration Date must be greater than Lead Date.',
                'error'
            );
            return false;
        }

         if (expirationDate <= todayDate) {
            this.showToast(
                'Error',
                'Expiration Date must be greater than today.',
                'error'
            );
            return false;
        }

        if (!this.selectedContactId) {
            this.showToast('Error', 'Please select a contact.', 'error');
            return false;
        }

        if (!this.selectedContactEmail) {
            this.showToast('Error', 'Selected contact must have an email address.', 'error');
            return false;
        }

        if (!this.selectedContactPhone) {
            this.showToast('Error', 'Selected contact must have a phone number.', 'error');
            return false;
        }

        if (!this.quoteRec.DRC_NBC_Payemnt_Term__c) {
            this.showToast('Error', 'Payment Term is required.', 'error');
            return false;
        }

        if (!this.quoteRec.DRC_NBC_Inco_terms__c) {
            this.showToast('Error', 'Inco Term is required.', 'error');
            return false;
        }
        
        if (!this.quoteRec.DRC_NBC_Type__c) {
            this.showToast('Error', 'Type is required.', 'error');
            return false;
        }

        if (!this.quoteRec.CurrencyIsoCode) {
            this.showToast('Error', 'Currency is required.', 'error');
            return false;
        }

        if (!this.selectedShippingId) {
            this.showToast('Error', 'Please select Shipping Address.', 'error');
            return false;
        }

        if (this.filteredData.length === 0) {
            this.showToast('Error', 'Please add at least one product.', 'error');
            return false;
        }

        // Validate each product row
        for (let i = 0; i < this.filteredData.length; i++) {
            const row = this.filteredData[i].recordData;
            if (!row.Product2Id) {
                this.showToast('Error', `Please select a product for row ${i + 1}.`, 'error');
                return false;
            }
            if (!row.Quantity || row.Quantity <= 0) {
                this.showToast('Error', `Please enter a valid quantity for row ${i + 1}.`, 'error');
                return false;
            }
        }

        return true;
    }

    async handleSave() {
        this.isLoading = true;

        if (!this.validateQuoteData()) {
            this.isLoading = false;
            return;
        }

        try {
            const lineItems = this.filteredData.map(item => {
                const row = item.recordData;
                return {
                    Product2Id: row.Product2Id,
                    PricebookEntryId: row.PricebookEntryId,
                    Quantity: row.Quantity || 1,
                    UnitPrice: row.modifiedPrice || row.UnitPrice || 0,
                    Description: row.Description || '',
                    CurrencyIsoCode: this.currencyCode || 'INR',
                    QuantityUnitOfMeasure: row.DRC_NBC_Unit_Of_Measurement__c || '',
                    PackingSize: row.selectedPackingSize || '',
                    PackingQuantity: row.packingQuantity || ''
                };
            });
            
            console.log('Saving quote with data:', {
                quoteData: this.quoteRec,
                lineItems: lineItems,
                opportunityId: this.recordId
            });

            const result = await createQuoteWithLines({
                oppId: this.recordId,
                quoteData: this.quoteRec,
                lineItems: lineItems
            });

            const parsed = JSON.parse(result);

            if (parsed.success) {
                const quoteId = parsed.quoteId;

                if (!quoteId) {
                    throw new Error('Quote ID not returned from server');
                }

                this.showToast('Success', 'Quote created successfully!', 'success');

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: quoteId,
                        objectApiName: 'Quote',
                        actionName: 'view'
                    }
                });

                this.handleCancel();
            } else {
                throw new Error(parsed.error || 'Unknown error occurred while creating quote');
            }

        } catch (error) {
            console.error('Error creating quote:', error);
            const errorMessage = error.body?.message || error.message || 'An unexpected error occurred';
            this.showToast('Error', errorMessage, 'error');

        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.showModal = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}