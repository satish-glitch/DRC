import { LightningElement, api, track } from 'lwc';
import getOrderRecordTypes from '@salesforce/apex/DRC_NBC_Generate_Sample_Order_Controller.getOrderRecordTypes';
import getOpportunityContacts from '@salesforce/apex/DRC_NBC_Generate_Sample_Order_Controller.getOpportunityContacts';
import getAllProducts from '@salesforce/apex/DRC_NBC_Generate_Sample_Order_Controller.getAllProducts';
import searchProducts from '@salesforce/apex/DRC_NBC_Generate_Sample_Order_Controller.searchProducts';
import getAccountBillingAddress from '@salesforce/apex/DRC_NBC_Generate_Sample_Order_Controller.getAccountBillingAddress';
import getAccountAddresses from '@salesforce/apex/DRC_NBC_Generate_Sample_Order_Controller.getAccountAddresses';
import getOpportunityCurrency from '@salesforce/apex/DRC_NBC_Generate_Sample_Order_Controller.getOpportunityCurrency';
import createSampleOrder from '@salesforce/apex/DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder';
import getAccountBankDetails from '@salesforce/apex/DRC_NBC_Generate_Sample_Order_Controller.getAccountBankDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import DRC_NBC_Order_Button_CSS from '@salesforce/resourceUrl/DRC_NBC_Order_Button_CSS';

export default class DRC_NBC_Generate_Sample_Order extends NavigationMixin(LightningElement) {
    @api recordId;
    @track showModal = true;
    @track isLoading = false;
    @track disabledButton = false;
    @track selectedRecordTypeId = '';
    @track oppProducts = [];
    @track billToContactName = '';
    @track shipToContactName = '';
    @track filteredBillToContacts = [];
    @track filteredShipToContacts = [];
    @track showBillToSuggestions = false;
    @track showShipToSuggestions = false;
    @track billingAddressDisplay = '';
    @track shippingAddressOptions = [];
    @track addrDetails = [];
    @track selectedShippingId;
    @track currencyCode = '';

    @track samplingRec = {};
    @track isBasicInfoOpen = true;
    @track isSampleOrderOpen = true;
    @track isBankDetailsOpen = true;
    @track isContactInfoOpen = true;
    @track isAddressOpen = true;
    @track isProductOpen = true;
    lastScrollTop = 0;
    @track sampleStatus = '';
    @track searchKeyword = '';
    @track searchResults = [];
    @track showProductSuggestions = false;
    @track selectedProducts = [];

    // UPDATED: Simple toggle - no auto-close behavior
    toggleBasicInfo() {
        this.isBasicInfoOpen = !this.isBasicInfoOpen;
    }

    toggleSampleOrder() {
        this.isSampleOrderOpen = !this.isSampleOrderOpen;
    }

    toggleBankDetails() {
        this.isBankDetailsOpen = !this.isBankDetailsOpen;
    }

    toggleContactInfo() {
        this.isContactInfoOpen = !this.isContactInfoOpen;
    }

    toggleAddress() {
        this.isAddressOpen = !this.isAddressOpen;
    }

    toggleProduct() {
        this.isProductOpen = !this.isProductOpen;
    }

    // Getter methods for dynamic classes
    get getBasicInfoClass() {
        return `slds-section ${this.isBasicInfoOpen ? 'slds-is-open' : ''}`;
    }

    get getSampleOrderClass() {
        return `slds-section ${this.isSampleOrderOpen ? 'slds-is-open' : ''}`;
    }

    get getBankDetailsClass() {
        return `slds-section ${this.isBankDetailsOpen ? 'slds-is-open' : ''}`;
    }

    get getContactInfoClass() {
        return `slds-section ${this.isContactInfoOpen ? 'slds-is-open' : ''}`;
    }

    get getAddressClass() {
        return `slds-section ${this.isAddressOpen ? 'slds-is-open' : ''}`;
    }

    get getProductClass() {
        return `slds-section ${this.isProductOpen ? 'slds-is-open' : ''}`;
    }

    // Getter methods for dynamic icons
    get getBasicInfoIcon() {
        return this.isBasicInfoOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getSampleOrderIcon() {
        return this.isSampleOrderOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getBankDetailsIcon() {
        return this.isBankDetailsOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getContactInfoIcon() {
        return this.isContactInfoOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getAddressIcon() {
        return this.isAddressOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getProductIcon() {
        return this.isProductOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }
    
    get isRejected() {
        return this.sampleStatus === 'Rejected';
    }

    get isPaidSample() {
        return this.samplingRec.DRC_NBC_Sample_Type__c === 'Paid Sample';
    }

    connectedCallback() {
        this.isLoading = true;
        this.samplingRec.EffectiveDate = this.todayDate;
        this.initializeComponent();
        this.loadCustomStyles();
        
        // Add scroll listener after DOM is ready
        setTimeout(() => {
            const modalContent = this.template.querySelector('.slds-modal__content');
            if (modalContent) {
                modalContent.addEventListener('scroll', this.handleScroll.bind(this));
            }
        }, 100);
    }

    disconnectedCallback() {
        // Clean up scroll listener
        const modalContent = this.template.querySelector('.slds-modal__content');
        if (modalContent) {
            modalContent.removeEventListener('scroll', this.handleScroll.bind(this));
        }
    }

    handleScroll(event) {
        const scrollTop = event.target.scrollTop;
        const scrollingDown = scrollTop > this.lastScrollTop;
        
        const sections = [
            { element: this.template.querySelector('#basic-info-content')?.parentElement, state: 'isBasicInfoOpen' },
            { element: this.template.querySelector('#sample-order-content')?.parentElement, state: 'isSampleOrderOpen' },
            { element: this.template.querySelector('#bank-details-content')?.parentElement, state: 'isBankDetailsOpen' },
            { element: this.template.querySelector('#contact-info-content')?.parentElement, state: 'isContactInfoOpen' },
            { element: this.template.querySelector('#address-info-content')?.parentElement, state: 'isAddressOpen' },
            { element: this.template.querySelector('#product-content')?.parentElement, state: 'isProductOpen' }
        ];

        sections.forEach((section) => {
            if (section.element) {
                const rect = section.element.getBoundingClientRect();
                const viewportHeight = window.innerHeight || document.documentElement.clientHeight;
                
                if (scrollingDown) {
                    // Close sections that are completely above viewport
                    if (rect.bottom < 50) {
                        this[section.state] = false;
                    }
                } else {
                    // Close sections that are completely below viewport
                    if (rect.top > viewportHeight - 50) {
                        this[section.state] = false;
                    }
                }
            }
        });
        
        this.lastScrollTop = scrollTop;
    }

    loadCustomStyles() {
        Promise.all([
            loadStyle(this, DRC_NBC_Order_Button_CSS)
        ])
            .then(() => console.log('All custom styles loaded.'))
            .catch(error => console.error('Error loading one or more styles:', error));
    }

    async initializeComponent() {
        try {
            const recordTypes = await getOrderRecordTypes();
            const sampleRT = recordTypes.find(rt => rt.label === 'Sample Order');
            this.selectedRecordTypeId = sampleRT?.value;

            if (!this.selectedRecordTypeId) {
                throw new Error('Sample Order record type not found');
            }

            // Fetch data in parallel
            const [contacts, products, currencyCode, billingAddress, shippingAddresses, bankDetails] = await Promise.all([
                getOpportunityContacts({ oppId: this.recordId }),
                getAllProducts({ oppId: this.recordId }),
                getOpportunityCurrency({ oppId: this.recordId }),
                getAccountBillingAddress({ oppId: this.recordId }),
                getAccountAddresses({ oppId: this.recordId }),
                getAccountBankDetails({ oppId: this.recordId })
            ]);
            this.currencyCode = currencyCode;
            
            // Set billing address from Account (read-only)
            if (billingAddress) {
                const labelParts = [];
                if (billingAddress.street) labelParts.push(billingAddress.street);
                if (billingAddress.city) labelParts.push(billingAddress.city);
                if (billingAddress.state) labelParts.push(billingAddress.state);
                if (billingAddress.postalCode) labelParts.push(billingAddress.postalCode);
                if (billingAddress.country) labelParts.push(billingAddress.country);

                this.billingAddressDisplay = labelParts.join(', ') || 'No billing address found';
                
                // Set billing address in samplingRec
                this.samplingRec.BillingStreet = billingAddress.street || '';
                this.samplingRec.BillingCity = billingAddress.city || '';
                this.samplingRec.BillingState = billingAddress.state || '';
                this.samplingRec.BillingPostalCode = billingAddress.postalCode || '';
                this.samplingRec.BillingCountry = billingAddress.country || '';
                this.samplingRec.BillingCountryCode = billingAddress.countryCode || '';
            }

            // Add bank details
            if (bankDetails) {
                this.samplingRec.DRC_NBC_Consignee_Bank_Name__c = bankDetails.bankName || '';
                this.samplingRec.DRC_NBC_Consignee_Bank_Account_Number__c = bankDetails.accountNumber || '';
                this.samplingRec.DRC_NBC_Consignee_Bank_IFSC_Code__c = bankDetails.ifscCode || '';
                this.samplingRec.DRC_NBC_Consignee_Bank_Address__c = bankDetails.bankAddress || '';
                
                console.log('Bank Details Set in samplingRec:', {
                    bankName: this.samplingRec.DRC_NBC_Consignee_Bank_Name__c,
                    accountNumber: this.samplingRec.DRC_NBC_Consignee_Bank_Account_Number__c,
                    ifscCode: this.samplingRec.DRC_NBC_Consignee_Bank_IFSC_Code__c,
                    bankAddress: this.samplingRec.DRC_NBC_Consignee_Bank_Address__c
                });
            } else {
                console.log('No bank details returned from Account');
            }

            // Build shipping address options from custom objects
            this.addrDetails = shippingAddresses || [];
            this.shippingAddressOptions = [];

            shippingAddresses.forEach(addr => {
                const details = addr.DRC_NBC_Address__c;
                const labelParts = [];
                if (details?.street) labelParts.push(details.street);
                if (details?.city) labelParts.push(details.city);
                if (details?.postalCode) labelParts.push(details.postalCode);
                if (details?.country) labelParts.push(details.country);

                const label = labelParts.join(', ') || 'Unknown Address';
                this.shippingAddressOptions.push({ label, value: addr.Id });
            });

            // Auto-select shipping address if only one exists
            if (this.shippingAddressOptions.length === 1) {
                this.selectedShippingId = this.shippingAddressOptions[0].value;
                const selectedAddr = this.addrDetails.find(addr => addr.Id === this.selectedShippingId);
                const addr = selectedAddr?.DRC_NBC_Address__c || {};
                this.samplingRec.ShippingStreet = addr.street || '';
                this.samplingRec.ShippingCity = addr.city || '';
                this.samplingRec.ShippingPostalCode = addr.postalCode || '';
                this.samplingRec.ShippingCountry = addr.country || '';
                this.samplingRec.ShippingCountryCode = addr.countryCode || '';
                this.samplingRec.DRC_NBC_Shipping_Address__c = this.selectedShippingId;
            }

            this.filteredBillToContacts = contacts || [];
            this.filteredShipToContacts = contacts || [];
            if (contacts && contacts.length > 0) {
                const firstContact = contacts[0];
                
                // Set Bill To Contact
                this.samplingRec.BillToContactId = firstContact.Id;
                this.billToContactName = firstContact.Name;
                
                // Set Ship To Contact (same as Bill To by default)
                this.samplingRec.ShipToContactId = firstContact.Id;
                this.shipToContactName = firstContact.Name;
                
                console.log('Auto-populated contacts:', {
                    billTo: firstContact.Name,
                    shipTo: firstContact.Name,
                    contactId: firstContact.Id
                });
            } else {
                console.log('No contacts found for this account');
            }

            this.oppProducts = (products || []).map(prod => ({
                Id: prod.Product2Id,
                Product2Id: prod.Product2Id,
                Product2Name: prod.Name || 'Unknown Product',
                FGCode: prod.FGCode || '',
                HSNCode: prod.HSNCode || '',
                PricebookEntryId: prod.PricebookEntryId,
                OriginalUnitPrice: prod.UnitPrice || 0,
                UnitPrice: prod.UnitPrice || 0,
                TotalPrice: prod.UnitPrice || 0,
                Quantity: 1,
                Description: '',
                DRC_NBC_Unit_Of_Measurement__c: prod.UOM,
                PackingSize: prod.PackingSize || '',
                PackingSizeOptions: this.parsePackingSizeOptions(prod.PackingSize),
                SelectedPackingSize: '',
                PackingQuantity: null,
                isSelected: false
            }));

            console.log('Products loaded:', this.oppProducts.length);

        } catch (error) {
            console.error('Initialization Error:', error);
            this.showToast('Error', 'Failed to load initial data: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Helper method to parse packing size multi-select picklist into options
    parsePackingSizeOptions(packingSizeString) {
        if (!packingSizeString) return [];
        
        const sizes = packingSizeString.split(';').map(s => s.trim());
        return sizes.map(size => ({
            label: size,
            value: size
        }));
    }

    // Helper method to extract numeric value from packing size (e.g., "200 KGS MS" -> 200)
    extractPackingSizeNumber(packingSizeValue) {
        if (!packingSizeValue) return null;
        
        const match = packingSizeValue.match(/^(\d+(?:\.\d+)?)/);
        return match ? parseFloat(match[1]) : null;
    }

    handleAddressChange(event) {
        const selectedValue = event.detail.value;
        const selectedAddr = this.addrDetails.find(addr => addr.Id === selectedValue);

        if (!selectedAddr) return;

        const addr = selectedAddr.DRC_NBC_Address__c;
        
        this.selectedShippingId = selectedValue;
        this.samplingRec.ShippingStreet = addr?.street || '';
        this.samplingRec.ShippingCity = addr?.city || '';
        this.samplingRec.ShippingPostalCode = addr?.postalCode || '';
        this.samplingRec.ShippingCountry = addr?.country || '';
        this.samplingRec.ShippingCountryCode = addr?.countryCode || '';
        this.samplingRec.DRC_NBC_Shipping_Address__c = selectedValue;
    }

    get todayDate() {
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    // Contact Handling - Bill To
    handleBillToInputChange(event) {
        try {
            this.billToContactName = event.target.value || '';
            this.showBillToSuggestions = true;
        } catch (error) { 
            console.error('Error in handleBillToInputChange:', error);
        }
    }

    handleBillToInputFocus() {
        try {
            this.showBillToSuggestions = true;
        } catch (error) {
            console.error('Error in handleBillToInputFocus:', error);
        }
    }

    handleBillToSelect(event) {
        try {
            const id = event.currentTarget.dataset.id;
            const name = event.currentTarget.dataset.name;
            
            this.samplingRec.BillToContactId = id;
            this.billToContactName = name;
            this.showBillToSuggestions = false;
            
            console.log('Bill To Contact Selected:', name, id);
        } catch (error) {
            console.error('Error in handleBillToSelect:', error);
        }
    }

    // Contact Handling - Ship To
    handleShipToInputChange(event) {
        try {
            this.shipToContactName = event.target.value || '';
            this.showShipToSuggestions = true;
        } catch (error) {
            console.error('Error in handleShipToInputChange:', error);
        }
    }

    handleShipToInputFocus() {
        try {
            this.showShipToSuggestions = true;
        } catch (error) {
            console.error('Error in handleShipToInputFocus:', error);
        }
    }

    handleShipToSelect(event) {
        try {
            const id = event.currentTarget.dataset.id;
            const name = event.currentTarget.dataset.name;
            
            this.samplingRec.ShipToContactId = id;
            this.shipToContactName = name;
            this.showShipToSuggestions = false;
            
            console.log('Ship To Contact Selected:', name, id);
        } catch (error) {
            console.error('Error in handleShipToSelect:', error);
        }
    }

    handleFocusOut() {
        setTimeout(() => {
            this.showBillToSuggestions = false;
            this.showShipToSuggestions = false;
        }, 200);
    }

    // Handle Add Product Button - Adds empty row
    handleAddProduct() {
        const newProduct = {
            Id: 'temp_' + Date.now(),
            Product2Id: null,
            Product2Name: '',
            FGCode: '',
            HSNCode: '',
            PricebookEntryId: null,
            UnitPrice: 0,
            TotalPrice: 0,
            Quantity: 1,
            Description: '',
            DRC_NBC_Unit_Of_Measurement__c: '',
            PackingSize: '',
            PackingSizeOptions: [],
            SelectedPackingSize: '',
            PackingQuantity: null,
            isSelected: false,
            showSuggestions: false,
            showSearch: true,
            searchResults: []
        };

        this.selectedProducts = [...this.selectedProducts, newProduct];
    }

    // Handle inline product search
    handleProductSearchInline(event) {
        const rowId = event.target.dataset.id;
        const searchTerm = event.target.value;

        if (searchTerm.length < 2) {
            this.selectedProducts = this.selectedProducts.map(prod => {
                if (prod.Id === rowId) {
                    return { ...prod, showSuggestions: false, searchResults: [] };
                }
                return prod;
            });
            return;
        }

        searchProducts({
            keyword: searchTerm,
            currencyIsoCode: this.currencyCode,
            oppId: this.recordId
        })
        .then(results => {
            // Filter out already selected products
            const selectedIds = this.selectedProducts
                .filter(p => p.Product2Id)
                .map(p => p.Product2Id);
            
            const filteredResults = results.filter(r => !selectedIds.includes(r.Product2Id));

            this.selectedProducts = this.selectedProducts.map(prod => {
                if (prod.Id === rowId) {
                    return { 
                        ...prod, 
                        showSuggestions: true, 
                        searchResults: filteredResults,
                        Product2Name: searchTerm
                    };
                }
                return prod;
            });
        })
        .catch(error => {
            console.error('Product search error:', error);
            this.selectedProducts = this.selectedProducts.map(prod => {
                if (prod.Id === rowId) {
                    return { ...prod, showSuggestions: false, searchResults: [] };
                }
                return prod;
            });
        });
    }

    // Handle product focus in inline search
    handleProductFocusInline(event) {
        const rowId = event.target.dataset.id;
        
        this.selectedProducts = this.selectedProducts.map(prod => {
            if (prod.Id === rowId && prod.searchResults.length > 0) {
                return { ...prod, showSuggestions: true };
            }
            return prod;
        });
    }

    // Handle product blur in inline search
    handleProductBlurInline() {
        setTimeout(() => {
            this.selectedProducts = this.selectedProducts.map(prod => {
                return { ...prod, showSuggestions: false };
            });
        }, 200);
    }

    // Handle product selection from dropdown
    handleProductSelectInline(event) {
        const rowId = event.currentTarget.dataset.rowid;
        const productId = event.currentTarget.dataset.productid;
        const name = event.currentTarget.dataset.name;
        const fgCode = event.currentTarget.dataset.fgcode;
        const hsnCode = event.currentTarget.dataset.hsncode;
        const unitPrice = parseFloat(event.currentTarget.dataset.unitprice);
        const pbeId = event.currentTarget.dataset.pbeid;
        const uom = event.currentTarget.dataset.uom;
        const packingSize = event.currentTarget.dataset.packingsize;
        
        console.log('Product clicked:', { rowId, productId, name, unitPrice, uom, packingSize });

        if (!rowId || !productId) {
            console.error('Missing rowId or productId in handleProductSelectInline');
            return;
        }

        this.selectedProducts = this.selectedProducts.map(prod => {
            if (prod.Id === rowId) {
                return {
                    ...prod,
                    Product2Id: productId,
                    Product2Name: name,
                    FGCode: fgCode,
                    HSNCode: hsnCode,
                    PricebookEntryId: pbeId,
                    UnitPrice: unitPrice,
                    TotalPrice: unitPrice,
                    DRC_NBC_Unit_Of_Measurement__c: uom,
                    PackingSize: packingSize,
                    PackingSizeOptions: this.parsePackingSizeOptions(packingSize),
                    SelectedPackingSize: '',
                    PackingQuantity: null,
                    showSuggestions: false,
                    searchResults: [],
                    showSearch: false
                };
            }
            return prod;
        });
    }

    // Handle Packing Size selection
    handlePackingSizeChange(event) {
        const id = event.target.dataset.id;
        const selectedSize = event.detail.value;

        this.selectedProducts = this.selectedProducts.map(prod => {
            if (prod.Id === id) {
                const sizeNumber = this.extractPackingSizeNumber(selectedSize);
                const quantity = prod.Quantity || 1;
                const packingQty = sizeNumber ? Math.ceil(quantity / sizeNumber) : null;
                
                return { 
                    ...prod, 
                    SelectedPackingSize: selectedSize,
                    PackingQuantity: packingQty
                };
            }
            return prod;
        });
    }

    // Handle Packing Quantity manual change
    handlePackingQuantityChange(event) {
        const id = event.target.dataset.id;
        const value = parseFloat(event.target.value);

        if (isNaN(value) || value <= 0) {
            this.showToast('Warning', 'Packing Quantity must be a positive number.', 'warning');
            return;
        }

        this.selectedProducts = this.selectedProducts.map(prod => {
            if (prod.Id === id) {
                return { ...prod, PackingQuantity: value };
            }
            return prod;
        });
    }

    // Updated handleRemoveProduct - now removes by Id
    handleRemoveProduct(event) {
        const prodId = event.currentTarget.dataset.id;
        
        this.selectedProducts = this.selectedProducts.filter(prod => prod.Id !== prodId);
    }

    handleProductFocus() {
        this.showProductSuggestions = true;
    }

    handleProductBlur() {
        setTimeout(() => {
            this.showProductSuggestions = false;
        }, 200);
    }

    validateOrderData() {
        const validations = [
            { field: 'EffectiveDate', message: 'Enter Order Start Date.' },
            { field: 'EndDate', message: 'Enter Order End Date.' },
            { field: 'BillToContactId', message: 'Select Bill To Contact.' },
            { field: 'ShipToContactId', message: 'Select Ship To Contact.' },
            { field: 'ShippingStreet', message: 'Select Shipping Address.' }
        ];

        for (const validation of validations) {
            if (!this.samplingRec[validation.field]) {
                this.showToast('Error', validation.message, 'error');
                return false;
            }
        }

        const effectiveDate = new Date(this.samplingRec.EffectiveDate);
        const endDate = new Date(this.samplingRec.EndDate);

        if (isNaN(effectiveDate.getTime()) || isNaN(endDate.getTime())) {
            this.showToast('Error', 'Invalid date format.', 'error');
            return false;
        }

        effectiveDate.setHours(0, 0, 0, 0);
        endDate.setHours(0, 0, 0, 0);

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        if (effectiveDate > today) {
            this.showToast('Error', 'Order Start Date cannot be greater than today.', 'error');
            return false;
        }

        if (effectiveDate < today) {
            this.showToast('Error', 'Order Start Date cannot be earlier than today.', 'error');
            return false;
        }

        if (effectiveDate > endDate) {
            this.showToast('Error', 'End Date must be later than Start Date.', 'error');
            return false;
        }

        if (this.samplingRec.DRC_NBC_Courier_date__c && endDate < new Date(this.samplingRec.DRC_NBC_Courier_date__c)) {
            this.showToast('Error', 'End Date must be later than Courier Date.', 'error');
            return false;
        }

        if (this.samplingRec.DRC_NBC_Expected_Delivery_Date__c && endDate < new Date(this.samplingRec.DRC_NBC_Expected_Delivery_Date__c)) {
            this.showToast('Error', 'End Date must be later than Expected Delivery Date.', 'error');
            return false;
        }

        return true;
    }

    handleFieldChange(event) {
        try {
            const fieldName = event.target.fieldName || event.target.dataset.field || event.target.name;
            const value = event.detail?.value || event.target.value;
            
            if (fieldName) {
                this.samplingRec[fieldName] = value;

                if (fieldName === 'Status') {
                    this.sampleStatus = value;
                    console.log(`Sample status changed: ${value}`);
                }

                if (fieldName === 'DRC_NBC_Sample_Type__c') {
                    console.log(`Sample type changed: ${value}`);
                }

                console.log('Order field updated:', fieldName, '=', value);
            }
        } catch (error) {
            console.error('Error in handleFieldChange:', error);
        }
    }

    handleTotalPriceChange(event) {
        const id = event.target.dataset.id;
        const value = parseFloat(event.target.value);

        this.selectedProducts = this.selectedProducts.map(prod => {
            if (prod.Id === id) {
                return { ...prod, TotalPrice: value };
            }
            return prod;
        });
    }

    handleDescriptionChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;

        this.selectedProducts = this.selectedProducts.map(prod => {
            if (prod.Id === id) {
                return { ...prod, Description: value };
            }
            return prod;
        });
    }

    handleQuantityChange(event) {
        const id = event.target.dataset.id;
        const value = parseInt(event.target.value, 10);

        if (isNaN(value) || value <= 0) {
            this.showToast('Warning', 'Quantity must be a positive number.', 'warning');
            return;
        }

        this.selectedProducts = this.selectedProducts.map(prod => {
            if (prod.Id === id) {
                // Recalculate packing quantity if packing size is selected
                let packingQty = prod.PackingQuantity;
                if (prod.SelectedPackingSize) {
                    const sizeNumber = this.extractPackingSizeNumber(prod.SelectedPackingSize);
                    packingQty = sizeNumber ? Math.ceil(value / sizeNumber) : null;
                }
                
                return { 
                    ...prod, 
                    Quantity: value,
                    PackingQuantity: packingQty
                };
            }
            return prod;
        });
    }

    async handleSave() {
        console.log('=== handleSave called ===');
        
        this.isLoading = true;
        this.disabledButton = true;

        if (!this.validateOrderData()) {
            this.disabledButton = false;
            this.isLoading = false;
            return;
        }

        try {
            if (!this.selectedRecordTypeId) {
                this.showToast('Error', 'Sample Order record type not found. Please contact your admin.', 'error');
                this.isLoading = false;
                this.disabledButton = false;
                return;
            }

            this.samplingRec.RecordTypeId = this.selectedRecordTypeId;

            const selectedItems = this.selectedProducts.map(p => ({
                Product2Id: p.Product2Id,
                PriceBookEntryId: p.PricebookEntryId,
                Quantity: p.Quantity || 1,
                UnitPrice: p.TotalPrice || p.UnitPrice || 0,
                Description: p.Description || '',
                PackingSize: p.SelectedPackingSize || '',
                PackingQuantity: p.PackingQuantity || null
            }));

            if (selectedItems.length === 0) {
                this.showToast('Warning', 'Please add at least one product before saving.', 'warning');
                this.isLoading = false;
                this.disabledButton = false;
                return;
            }

            console.log('Saving order with data:', {
                orderObj: this.samplingRec,
                selectedProducts: selectedItems,
                opportunityId: this.recordId
            });

            const result = await createSampleOrder({
                orderObj: this.samplingRec,
                orderItems: selectedItems,
                opportunityId: this.recordId
            });

            const parsed = JSON.parse(result);

            if (parsed.success) {
                const orderId = parsed.orderId || (parsed.orders && parsed.orders[0]?.Id);

                if (!orderId) {
                    throw new Error('Order ID not returned from server');
                }

                this.showToast('Success', 'Sample Order created successfully!', 'success');

                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: orderId,
                        objectApiName: 'Order',
                        actionName: 'view'
                    }
                });

                this.handleCancel();
            } else {
                throw new Error(parsed.error || 'Unknown error occurred while creating order');
            }

        } catch (error) {
            console.error('Error creating order:', error);
            const errorMessage = error.body?.message || error.message || 'An unexpected error occurred';
            this.showToast('Error', errorMessage, 'error');

        } finally {
            this.isLoading = false;
            this.disabledButton = false;
        }
    }

    handleClearProduct(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);

        if (isNaN(index) || index < 0 || index >= this.selectedProducts.length) {
            console.error('Invalid index for clearing product:', index);
            return;
        }

        // Recreate the row with search mode enabled
        const clearedRow = {
            ...this.selectedProducts[index],
            Product2Id: null,
            Product2Name: '',
            FGCode: '',
            HSNCode: '',
            PricebookEntryId: null,
            UnitPrice: 0,
            TotalPrice: 0,
            Quantity: 1,
            Description: '',
            DRC_NBC_Unit_Of_Measurement__c: '',
            PackingSize: '',
            PackingSizeOptions: [],
            SelectedPackingSize: '',
            PackingQuantity: null,
            showSearch: true,
            showSuggestions: false,
            searchResults: []
        };

        // Replace the row
        this.selectedProducts = [
            ...this.selectedProducts.slice(0, index),
            clearedRow,
            ...this.selectedProducts.slice(index + 1)
        ];

        console.log('Product cleared for row:', index);
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