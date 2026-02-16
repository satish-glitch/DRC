import { LightningElement, api, track } from 'lwc';
import getDefaultValues from '@salesforce/apex/DRC_NBC_Generate_Order_Controller.getDefaultValues';
import createOrderRec from '@salesforce/apex/DRC_NBC_Generate_Order_Controller.createOrder';
import getOrderRecordTypes from '@salesforce/apex/DRC_NBC_Generate_Order_Controller.getOrderRecordTypes';
import getOrderTypes from '@salesforce/apex/DRC_NBC_Generate_Order_Controller.getOrderTypes';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { loadStyle } from 'lightning/platformResourceLoader';
import DRC_NBC_Order_Button_CSS from '@salesforce/resourceUrl/DRC_NBC_Order_Button_CSS';

export default class DRC_NBC_Generate_Order extends NavigationMixin(LightningElement) {
    @api recordId;
    @track load = false;
    @track disabledButton = false;
    @track orderProductsList = [];
    @track billToContactId;
    @track shipToContactId;
    @track billToContactName = '';
    @track shipToContactName = '';
    @track selectedList = [];
    @track orderTypeOptions = [];
    @track selectedOrderType = '';
    @track showExportSection = false;
    @track showDomesticSection = false;
    
    // Contact search functionality
    @track allBillToContacts = [];
    @track allShipToContacts = [];
    @track filteredBillToContacts = [];
    @track filteredShipToContacts = [];
    @track showBillToContactDropdown = false;
    @track showShipToContactDropdown = false;

    currentStep = 'orderForm';
    showModal = true;
    _initialFieldsCaptured = false;

    priceBookId = '';
    @track selectedShippingId;
    @track billingAddressDisplay = '';
    samplingRec = {};
    shippingAddressOptions = [];
    addrDetails = [];
    packingTypeOptions = [];
    packingSizeValues = [];
    accountGroup;
    customerContacts = [];
    orderResult;
    packingTypeResult = [];
    originalOrderProductsList = [];
    finalOrderProducts = [];
    accountId;
    currencyCode;
    selectedRecordTypeId = '';
    selectedRecordTypeName = '';
    isBasicInfoOpen = true;
    isExportOpen = true;
    isDomesticOpen = true;
    isContactOpen = true;
    isAddressOpen = true;
    isProductOpen = true;
    isConsigneeBankOpen = true;
    isProcurementOpen = true;

    // Toggle methods
    toggleBasicInfo() {
        this.isBasicInfoOpen = !this.isBasicInfoOpen;
    }

    toggleConsigneeBankInfo() {
        this.isConsigneeBankOpen = !this.isConsigneeBankOpen;
    }

    toggleProcurementInfo() {
        this.isProcurementOpen = !this.isProcurementOpen;
    }

    toggleExportInfo() {
        this.isExportOpen = !this.isExportOpen;
    }

    toggleDomesticInfo() {
        this.isDomesticOpen = !this.isDomesticOpen;
    }

    toggleContactInfo() {
        this.isContactOpen = !this.isContactOpen;
    }

    toggleAddressInfo() {
        this.isAddressOpen = !this.isAddressOpen;
    }

    toggleProductInfo() {
        this.isProductOpen = !this.isProductOpen;
    }

    // Getter methods for classes
    get getBasicInfoClass() {
        return `slds-section ${this.isBasicInfoOpen ? 'slds-is-open' : ''}`;
    }
    get getConsigneeBankClass() {
        return `slds-section slds-m-top_medium ${this.isConsigneeBankOpen ? 'slds-is-open' : ''}`;
    }

    get getProcurementClass() {
        return `slds-section slds-m-top_medium ${this.isProcurementOpen ? 'slds-is-open' : ''}`;
    }

    get getExportClass() {
        return `slds-section slds-m-top_medium ${this.isExportOpen ? 'slds-is-open' : ''}`;
    }

    get getDomesticClass() {
        return `slds-section slds-m-top_medium ${this.isDomesticOpen ? 'slds-is-open' : ''}`;
    }

    get getContactClass() {
        return `slds-section slds-m-top_medium ${this.isContactOpen ? 'slds-is-open' : ''}`;
    }

    get getAddressClass() {
        return `slds-section slds-m-top_medium ${this.isAddressOpen ? 'slds-is-open' : ''}`;
    }

    get getProductClass() {
        return `slds-section slds-m-top_medium ${this.isProductOpen ? 'slds-is-open' : ''}`;
    }

    // Getter methods for icons
    get getBasicInfoIcon() {
        return this.isBasicInfoOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getConsigneeBankIcon() {
        return this.isConsigneeBankOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getProcurementIcon() {
        return this.isProcurementOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getExportIcon() {
        return this.isExportOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getDomesticIcon() {
        return this.isDomesticOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getContactIcon() {
        return this.isContactOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getAddressIcon() {
        return this.isAddressOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getProductIcon() {
        return this.isProductOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get isOrderFormStep() {
        return this.currentStep === 'orderForm';
    }

    get isNextDisabled() {
        return !this.selectedOrderType;
    }

    get selectedProductsLabel() {
        return `Selected: ${this.orderProductsList.filter(p => p.Selected).length}`;
    }

    connectedCallback() {
        this.initializeComponent();
        document.addEventListener('click', this.handleDocumentClick.bind(this));
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleDocumentClick.bind(this));
    }

    handleDocumentClick(event) {
        const billToInput = this.template.querySelector('#billToContact');
        const shipToInput = this.template.querySelector('#shipToContact');
        
        if (billToInput && !billToInput.contains(event.target)) {
            this.showBillToContactDropdown = false;
        }
        
        if (shipToInput && !shipToInput.contains(event.target)) {
            this.showShipToContactDropdown = false;
        }
    }

    initializeComponent() {
        this.extractRecordIdFromUrl();
        this.loadCustomStyles();
        this.loadOrderTypes();
        this.getOrderDefaultDetails();
    }

    get isSelectOrderType() {
        return this.currentStep === 'selectOrderType';
    }
    
    get modalTitle() {
        if (this.selectedOrderType === 'Export') {
            return 'Generate Export Order';
        } else if (this.selectedOrderType === 'Domestic') {
            return 'Generate Domestic Order';
        } else {
            return 'Generate Order';
        }
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
            .catch(error => console.error('Error loading one or more styles:', error));
    }

    loadOrderTypes() {
        getOrderTypes()
            .then(result => {
                this.orderTypeOptions = result;
                console.log('Order types loaded:', result);
            })
            .catch(error => {
                console.error('Error loading order types:', error);
                this.showToastMessage('Error', 'Failed to load order types.', 'error');
            });
    }

    handleOrderTypeChange(event) {
        this.selectedOrderType = event.detail.value;

        if (this.selectedOrderType === 'Export') {
            this.showExportSection = true;
            this.showDomesticSection = false;
        } else if (this.selectedOrderType === 'Domestic') {
            this.showExportSection = false;
            this.showDomesticSection = true;
        } else {
            this.showExportSection = false;
            this.showDomesticSection = false;
        }

        this.samplingRec.DRC_NBC_Type__c = this.selectedOrderType;
    }

    // Bill To Contact Handlers
    handleBillToContactFocus(event) {
        event.stopPropagation();
        this.filteredBillToContacts = [...this.allBillToContacts];
        this.showBillToContactDropdown = true;
        this.showShipToContactDropdown = false;
    }

    handleBillToContactSearch(event) {
        const searchTerm = event.target.value.toLowerCase();
        this.billToContactName = event.target.value;
        
        if (searchTerm.length === 0) {
            this.filteredBillToContacts = [...this.allBillToContacts];
        } else {
            this.filteredBillToContacts = this.allBillToContacts.filter(contact =>
                contact.label.toLowerCase().includes(searchTerm)
            );
        }
        
        this.showBillToContactDropdown = true;
    }

    handleBillToContactSelect(event) {
        event.stopPropagation();
        const selectedId = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;
        
        this.billToContactId = selectedId;
        this.billToContactName = selectedName;
        this.samplingRec.BillToContactId = selectedId;
        this.showBillToContactDropdown = false;
    }

    // Ship To Contact Handlers
    handleShipToContactFocus(event) {
        event.stopPropagation();
        this.filteredShipToContacts = [...this.allShipToContacts];
        this.showShipToContactDropdown = true;
        this.showBillToContactDropdown = false;
    }

    handleShipToContactSearch(event) {
        const searchTerm = event.target.value.toLowerCase();
        this.shipToContactName = event.target.value;
        
        if (searchTerm.length === 0) {
            this.filteredShipToContacts = [...this.allShipToContacts];
        } else {
            this.filteredShipToContacts = this.allShipToContacts.filter(contact =>
                contact.label.toLowerCase().includes(searchTerm)
            );
        }
        
        this.showShipToContactDropdown = true;
    }

    handleShipToContactSelect(event) {
        event.stopPropagation();
        const selectedId = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;
        
        this.shipToContactId = selectedId;
        this.shipToContactName = selectedName;
        this.samplingRec.ShipToContactId = selectedId;
        this.showShipToContactDropdown = false;
    }
    
    handleFinalPriceChange(event) {
        const id = event.target.dataset.id;
        const value = parseFloat(event.target.value) || 0;
        this.orderProductsList = this.orderProductsList.map(item => {
            if (item.QuoteLineItemId === id) {
                const basePrice = parseFloat(item.OriginalUnitPrice) || 0;
                const modifier = value - basePrice;

                return {
                    ...item,
                    finalPrice: value,
                    modifier: modifier,
                    pendingModifierInput: 0 
                };
            }
            return item;
        });
        console.log(`Updated finalPrice for QLI ${id} to ${value}`);
    }

    get todayDate() {
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }
    
    getOrderDefaultDetails() {
        if (!this.recordId) {
            this.showToastMessage('Error', 'No record ID found.', 'error');
            return;
        }

        this.load = true;

        getDefaultValues({ quoteID: this.recordId })
            .then(result => {
                this.processDefaultValues(result);
                const orderType = result.types;
                this.selectedOrderType = orderType;
                this.samplingRec.DRC_NBC_Type__c = orderType;
                if (orderType === 'Export') {
                    this.showExportSection = true;
                    this.showDomesticSection = false;
                } else if (orderType === 'Domestic') {
                    this.showExportSection = false;
                    this.showDomesticSection = true;
                } else {
                    this.showExportSection = false;
                    this.showDomesticSection = false;
                }
                this.samplingRec.Status = 'Draft';
                this.load = false;
            })
            .catch(error => {
                console.error('Error fetching default values:', JSON.stringify(error));
                this.showToastMessage('Error', 'Failed to load default values.', 'error');
                this.load = false;
            });
    }

    processDefaultValues(result) {
        console.log('Default values result:', JSON.stringify(result, null, 2));
        this.orderResult = result;
        
        if (result.opportunityObj && result.opportunityObj.length > 0) {
            this.samplingRec.OpportunityId = result.opportunityObj[0].Id;
        }
        
        this.samplingRec.QuoteId = this.recordId;
        this.samplingRec.Pricebook2Id = result.Pricebook2Id;
        this.priceBookId = result.Pricebook2Id;
        
        this.samplingRec.DRC_NBC_Payment_Terms__c = result.paymentTerm;
        this.samplingRec.DRC_NBC_TCS_Amount__c = result.tcsAmount;
        this.samplingRec.DRC_NBC_IGST__c = result.igst;
        this.samplingRec.DRC_NBC_CGST__c = result.cgst;
        this.samplingRec.DRC_NBC_SGST__c = result.sgst;
        this.samplingRec.DRC_NBC_Other_Tax_Amount__c = result.otherTaxAmount;
        this.samplingRec.DRC_NBC_Inco_Terms__c = result.incoTerm;
        this.samplingRec.DRC_NBC_Type__c = result.types;
        this.samplingRec.DRC_NBC_Delivery_Terms__c = result.deliveryTerm;
        this.samplingRec.DRC_NBC_Consignee_Bank_Name__c = result.acc[0].DRC_NBC_Consignee_Bank_Name__c;
        this.samplingRec.DRC_NBC_Consignee_Bank_Account_Number__c = result.acc[0].DRC_NBC_Consignee_Bank_Account_Number__c;
        this.samplingRec.DRC_NBC_Consignee_Bank_IFSC_Code__c = result.acc[0].DRC_NBC_Consignee_Bank_IFSC_Code__c;
        this.samplingRec.DRC_NBC_Consignee_Bank_Address__c = result.acc[0].DRC_NBC_Consignee_Bank_Address__c;

        this.currencyCode = result.opportunityObj[0].CurrencyIsoCode;
        
        if (result.acc && result.acc.length > 0) {
            const account = result.acc[0];
            this.samplingRec.AccountId = result.acc[0].Id;
            
            this.samplingRec['BillingStreet'] = result.BillingStreet || '';
            this.samplingRec['BillingCity'] = result.BillingCity || '';
            this.samplingRec['BillingState'] = result.BillingState || '';
            this.samplingRec['BillingPostalCode'] = result.BillingPostalCode || '';
            this.samplingRec['BillingCountry'] = result.BillingCountry || '';
            this.samplingRec['BillingCountryCode'] = result.BillingCountryCode || '';
            
            let billingParts = [];
            if (result.BillingStreet) billingParts.push(result.BillingStreet);
            if (result.BillingCity) billingParts.push(result.BillingCity);
            if (result.BillingState) billingParts.push(result.BillingState);
            if (result.BillingPostalCode) billingParts.push(result.BillingPostalCode);
            if (result.BillingCountry) billingParts.push(result.BillingCountry);
            this.billingAddressDisplay = billingParts.join(', ') || 'No billing address';
            
            this.shippingAddressOptions = [];
            this.customerContacts = result.customerContacts;

            if (account.Address__r && account.Address__r.length > 0) {
                this.addrDetails = account.Address__r;
                account.Address__r.forEach(addr => {
                    const addrDetails = addr.DRC_NBC_Address__c;
                    let labelParts = [];

                    console.log('Address object:', addrDetails);

                    if (addrDetails) {
                        if (addrDetails.street) labelParts.push(addrDetails.street);
                        if (addrDetails.city) labelParts.push(addrDetails.city);
                        if (addrDetails.postalCode) labelParts.push(addrDetails.postalCode);
                        if (addrDetails.country) labelParts.push(addrDetails.country);
                    }

                    const label = labelParts.join(', ') || 'Unknown Address';
                    const option = { label, value: addr.Id };

                    if (addr.DRC_NBC_Type__c === 'Shipping') {
                        this.shippingAddressOptions.push(option);
                    }
                });

                if (this.shippingAddressOptions.length === 1) {
                    this.selectedShippingId = this.shippingAddressOptions[0].value;
                    const addressToAdd = this.addrDetails.find(item => item.Id === this.selectedShippingId);
                    if (addressToAdd && addressToAdd.DRC_NBC_Address__c) {
                        const addr = addressToAdd.DRC_NBC_Address__c;
                        this.samplingRec['ShippingStreet'] = addr.street || '';
                        this.samplingRec['ShippingCity'] = addr.city || '';
                        this.samplingRec['ShippingPostalCode'] = addr.postalCode || '';
                        this.samplingRec['ShippingCountry'] = addr.country || '';
                        this.samplingRec['ShippingCountryCode'] = addr.countryCode || '';
                        this.samplingRec['DRC_NBC_Shipping_Address__c'] = addressToAdd.Id;
                    }
                }
            }

            console.log('Updated samplingRec:', JSON.stringify(this.samplingRec));
        }
       
        this.customerContacts = result.customerContacts || [];
        this.allBillToContacts = this.customerContacts.map(c => ({
            label: c.Name,
            value: c.Id
        }));
        this.allShipToContacts = [...this.allBillToContacts];
        
        this.filteredBillToContacts = [...this.allBillToContacts];
        this.filteredShipToContacts = [...this.allShipToContacts];
        
        if (this.allBillToContacts.length > 0) {
            this.billToContactId = this.allBillToContacts[0].value;
            this.billToContactName = this.allBillToContacts[0].label;
            this.samplingRec.BillToContactId = this.billToContactId;
        }
        
        if (this.allShipToContacts.length > 0) {
            this.shipToContactId = this.allShipToContacts[0].value;
            this.shipToContactName = this.allShipToContacts[0].label;
            this.samplingRec.ShipToContactId = this.shipToContactId;
        }
        
        this.processOrderItems(result.orderItems || []);
        console.log('Sampling Rec from Apex:', JSON.stringify(this.samplingRec, null, 2));
    }

    processAccountData(account) {
        this.accountId = account.Id;
        this.samplingRec.AccountId = account.Id;
        this.shippingAddressOptions = [];
    }

    processOrderItems(orderItems) {
        this.orderProductsList = orderItems.map((item) => {
            const basePrice = parseFloat(item.UnitPrice) || 0;

            // Apex wrapper sends packing fields WITHOUT __c suffix
            // (wrapper property names: DRC_NBC_Packing_Size, DRC_NBC_Packing_Quantity)
            const packingSize     = item.DRC_NBC_Packing_Size     || item.DRC_NBC_Packing_Size__c     || '';
            const packingQuantity = item.DRC_NBC_Packing_Quantity  || item.DRC_NBC_Packing_Quantity__c  || '';

            console.log('Item packing fields => Size:', item.DRC_NBC_Packing_Size,
                        ' | Qty:', item.DRC_NBC_Packing_Quantity,
                        ' | Resolved Size:', packingSize,
                        ' | Resolved Qty:', packingQuantity);

            const processedItem = {
                ...item,
                QuoteLineItemId: item.QuoteLineItemId || item.Id,
                Product2Id: item.Product2Id,
                PriceBookEntryId: item.PriceBookEntryId || item.PricebookEntryId,
                Selected: false,
                disabled: true,
                Product2: item.Product2 || { Name: 'N/A' },
                UnitPrice: basePrice,
                OriginalUnitPrice: basePrice,
                modifier: 0,
                finalPrice: basePrice,
                DRC_NBC_FG_Code: item.Product2?.DRC_NBC_FG_Code || '',
                DRC_NBC_HSN_Code: item.Product2?.DRC_NBC_HSN_SAC_Code || '',
                DRC_NBC_Unit_Of_Measurement__c: 'KGS',
                // Store under __c key so HTML {item.DRC_NBC_Packing_Size__c} binding works
                DRC_NBC_Packing_Size__c: packingSize,
                DRC_NBC_Packing_Quantity__c: packingQuantity
            };

            return processedItem;
        });
        this.originalOrderProductsList = [...this.orderProductsList];
    }

    handleAddressChange(event) {
        const fieldName = event.target.name;
        const selectedValue = event.detail.value;
        const addressToAdd = this.addrDetails.find(item => item.Id === selectedValue);
        if (!addressToAdd) return;
        
        if (fieldName === 'shipping') {
            this.selectedShippingId = selectedValue;
            this.updateAddressFields('Shipping', addressToAdd);
        }

        console.log('Updated samplingRec:', JSON.stringify(this.samplingRec));
    }

    updateAddressFields(type, address) {
        if (!address) return;
        const addressData = address.DRC_NBC_Address__c || address;
        this.samplingRec[`${type}Street`] = addressData.street || '';
        this.samplingRec[`${type}City`] = addressData.city || '';
        this.samplingRec[`${type}PostalCode`] = addressData.postalCode || '';
        this.samplingRec[`${type}Country`] = addressData.country || '';
        this.samplingRec[`${type}CountryCode`] = addressData.countryCode || '';
        this.samplingRec[`DRC_NBC_${type}_Address__c`] = address.Id;
    }

    handleOrderItemChange(event) {
        const quoteLineItemId = event.target.dataset.id;
        const fieldName = event.target.dataset.apiname;
        const fieldValue = event.target.value;

        this.orderProductsList = this.orderProductsList.map(item => {
            if (item.QuoteLineItemId === quoteLineItemId) {
                return { ...item, [fieldName]: fieldValue };
            }
            return item;
        });
    }

    handleValueChange(event) {
        try {
            const target = event.target;
            const fieldName = target.fieldName || target.name;
            const value = target.value;
            if (fieldName !== undefined) {
                this.samplingRec = {
                    ...this.samplingRec,
                    [fieldName]: value
                };
                console.log(`Field captured: ${fieldName} = ${value}`);
            } else {
                console.warn('Field name not found in event:', event);
            }
            console.log('Current samplingRec:', JSON.stringify(this.samplingRec));
        } catch (error) {
            console.error('Error in handleValueChange:', error);
        }
    }

    handleFormLoad(event) {
        const record = event.detail.record;
        if (record && record.fields) {
            if (record.fields.Status && record.fields.Status.value) {
                this.samplingRec.Status = record.fields.Status.value;
                console.log('Default Status captured:', record.fields.Status.value);
            }
            if (!this.samplingRec.EffectiveDate) {
                const today = new Date();
                const formattedToday = today.toISOString().split('T')[0];
                this.samplingRec.EffectiveDate = formattedToday;
                console.log('Set EffectiveDate to today:', formattedToday);
            }
        }
        console.log('Initial samplingRec:', JSON.stringify(this.samplingRec));
    }

    handleInputFieldChange(event) {
        const fieldName = event.currentTarget.dataset.field || event.target.fieldName;
        const newValue = event.detail.value !== undefined ? event.detail.value : event.target.value;
        if (fieldName) {
            this.samplingRec[fieldName] = newValue;
            console.log('Field updated:', fieldName, '=', newValue);
            console.log('Current samplingRec:', JSON.stringify(this.samplingRec));
        } else {
            console.error('Could not determine field name', event);
        }
    }

    handleProductSelect(event) {
        const quoteLineItemId = event.target.dataset.id;
        const isChecked = event.target.checked;

        this.orderProductsList = this.orderProductsList.map(item => {
            if (item.QuoteLineItemId === quoteLineItemId) {
                item.Selected = isChecked;
                item.disabled = !isChecked;
            }
            return item;
        });

        console.log('Updated product selection:', JSON.stringify(this.orderProductsList));
    }

    handleSearch(event) {
        const searchKey = event.target.value.toLowerCase();
        if (searchKey) {
            this.orderProductsList = this.originalOrderProductsList.filter(item => {
                if (item.Product2 && item.Product2.Name) {
                    return item.Product2.Name.toLowerCase().includes(searchKey);
                }
                return false;
            });
        } else {
            this.orderProductsList = [...this.originalOrderProductsList];
        }
    }

    validateOrderData() {
        console.log('=== Starting Order Validation ===');
        console.log('samplingRec:', JSON.stringify(this.samplingRec, null, 2));
        
        const validations = [
            { field: 'EffectiveDate', message: 'Enter Order Start Date.' },
            { field: 'EndDate', message: 'Enter Order End Date.' },
            { field: 'Pricebook2Id', message: 'Enter Price Book.' },
            { field: 'BillToContactId', message: 'Enter Bill To Contact.' },
            { field: 'ShipToContactId', message: 'Enter Ship To Contact.' },
            { field: 'DRC_NBC_Payment_Terms__c', message: 'Enter Payment Term.' },
            { field: 'DRC_NBC_Inco_Terms__c', message: 'Enter Inco Term.' },
        ];

        for (const validation of validations) {
            if (!this.samplingRec[validation.field]) {
                console.log(`Validation failed: ${validation.field}`);
                this.showToastMessage('Error', validation.message, 'error');
                return false;
            }
        }

        if (!this.selectedShippingId) {
            console.log('Validation failed: No shipping address');
            this.showToastMessage('Error', 'Enter Shipping Address.', 'error');
            return false;
        }

        const effectiveDate = new Date(this.samplingRec.EffectiveDate);
        effectiveDate.setHours(0, 0, 0, 0);
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        console.log('Effective Date:', effectiveDate);
        console.log('Today:', today);

        if (effectiveDate > today) {
            this.showToastMessage('Error', 'Order Start Date cannot be greater than today.', 'error');
            return false;
        }
        if (effectiveDate < today) {
            this.showToastMessage('Error', 'Order Start Date cannot be less than today.', 'error');
            return false;
        }

        const endDate = new Date(this.samplingRec.EndDate);
        endDate.setHours(0, 0, 0, 0);
        
        console.log('End Date:', endDate);
    
        if (endDate <= today) {
            this.showToastMessage('Error', 'End Date must be greater than today.', 'error');
            return false;
        }

        if (this.samplingRec.EffectiveDate > this.samplingRec.EndDate) {
            this.showToastMessage('Error', 'End Date must be later than Start Date.', 'error');
            return false;
        }
        
        if (this.samplingRec.DRC_NBC_Expected_Delivery_Date__c && 
            this.samplingRec.DRC_NBC_Expected_Delivery_Date__c > this.samplingRec.EndDate) {
            this.showToastMessage('Error', 'Expected Delivery Date must be Less than End Date.', 'error');
            return false;
        }
        if (this.samplingRec.DRC_NBC_Courier_date__c && 
            this.samplingRec.DRC_NBC_Courier_date__c > this.samplingRec.EndDate) {
            this.showToastMessage('Error', 'Courier date must be Less than End Date.', 'error');
            return false;
        }
        if (this.samplingRec.DRC_NBC_Shipment_Date__c && 
            this.samplingRec.DRC_NBC_Shipment_Date__c > this.samplingRec.EndDate) {
            this.showToastMessage('Error', 'Shipment Date must be Less than End Date.', 'error');
            return false;
        }
        if (this.samplingRec.NBC_DRC_Dispatch_Date__c && 
            this.samplingRec.NBC_DRC_Dispatch_Date__c > this.samplingRec.EndDate) {
            this.showToastMessage('Error', 'Dispatch Date must be Less than End Date.', 'error');
            return false;
        }
        if (this.samplingRec.PoDate && 
            this.samplingRec.PoDate > this.samplingRec.EndDate) {
            this.showToastMessage('Error', 'Po Date must be Less than End Date.', 'error');
            return false;
        }
        
        console.log('=== Order Validation Passed ===');
        return true;
    }

    validateOrderProducts() {
        console.log('=== Starting Product Validation ===');
        
        this.finalOrderProducts = this.orderProductsList.filter(item => item.Selected);
        console.log('Selected products count:', this.finalOrderProducts.length);
        
        if (this.finalOrderProducts.length === 0) {
            this.showToastMessage('Error', 'Please select at least one product.', 'error');
            return false;
        }

        for (const item of this.finalOrderProducts) {
            console.log('Validating item:', {
                Product2Id: item.Product2Id,
                PriceBookEntryId: item.PriceBookEntryId,
                Quantity: item.Quantity,
                UnitPrice: item.UnitPrice,
                finalPrice: item.finalPrice,
                Description: item.Description
            });
            
            if (!item.Product2Id) {
                console.error('Missing Product2Id');
                this.showToastMessage('Error', 'Missing Product ID for selected products.', 'error');
                return false;
            }

            if (!item.PriceBookEntryId && !item.PricebookEntryId) {
                console.error('Missing PriceBookEntryId');
                this.showToastMessage('Error', 'Missing Pricebook Entry for selected products.', 'error');
                return false;
            }

            const priceToCheck = parseFloat(item.finalPrice || item.UnitPrice);
            if (!priceToCheck || priceToCheck <= 0) {
                console.error('Invalid price');
                this.showToastMessage('Error', 'Enter valid Price per piece for all selected products.', 'error');
                return false;
            }

            if (!item.Quantity || item.Quantity <= 0) {
                console.error('Invalid quantity');
                this.showToastMessage('Error', 'Enter valid Quantity for all selected products.', 'error');
                return false;
            }
        }
        console.log('=== Product Validation Passed ===');
        return true;
    }
    
    handleSave() {
        console.log('=== handleSave Called ===');
        
        this.disabledButton = true;
        
        if (!this.validateOrderData()) {
            console.log('Order data validation failed');
            this.disabledButton = false;
            return;
        }
        
        if (!this.validateOrderProducts()) {
            console.log('Product validation failed');
            this.disabledButton = false;
            return;
        }
        
        const selectedItems = this.orderProductsList.filter(item => item.Selected);
        console.log('Selected products for order:', JSON.stringify(selectedItems, null, 2));

        const cleanedOrderProducts = selectedItems.map((item) => {
            const adjustedPrice = parseFloat(item.finalPrice) || 
                                (parseFloat(item.OriginalUnitPrice || item.UnitPrice || 0) + 
                                parseFloat(item.modifier || 0));

            return {
                QuoteLineItemId: item.QuoteLineItemId || item.Id,
                Product2Id: item.Product2Id,
                PriceBookEntryId: item.PriceBookEntryId || item.PricebookEntryId,
                Description: item.Description || '',
                Quantity: parseFloat(item.Quantity) || 1,
                UnitPrice: adjustedPrice,
                UOM: 'KGS',
                // FIX: Send without __c suffix to match Apex wrapper property names exactly
                DRC_NBC_Packing_Size: item.DRC_NBC_Packing_Size__c || item.DRC_NBC_Packing_Size || '',
                DRC_NBC_Packing_Quantity: item.DRC_NBC_Packing_Quantity__c || item.DRC_NBC_Packing_Quantity || ''
            };
        });

        this.samplingRec.CurrencyIsoCode = this.currencyCode;
        console.log('Final samplingRec:', JSON.stringify(this.samplingRec, null, 2));
        console.log('Cleaned order products:', JSON.stringify(cleanedOrderProducts, null, 2));
        
        this.createOrder(cleanedOrderProducts);
    }

    createOrder(cleanedOrderProducts) {
        console.log('=== createOrder Called ===');
        this.load = true;
        
        console.log('Calling Apex with:');
        console.log('- orderObj:', JSON.stringify(this.samplingRec, null, 2));
        console.log('- orderItems:', JSON.stringify(cleanedOrderProducts, null, 2));
        console.log('- quoteID:', this.recordId);
        
        createOrderRec({
            orderObj: this.samplingRec,
            orderItems: cleanedOrderProducts,
            quoteID: this.recordId
        })
        .then(result => {
            console.log('Apex returned:', result);
            this.handleOrderCreationResult(result);
        })
        .catch(error => {
            console.error('Apex error:', JSON.stringify(error, null, 2));
            this.load = false;
            this.disabledButton = false;
            this.showToastMessage('Error', error.body?.message || 'Failed to create order.', 'error');
        });
    }

    handleOrderCreationResult(result) {
        console.log('=== handleOrderCreationResult Called ===');
        this.load = false;
        this.disabledButton = false;

        if (!result) {
            this.showToastMessage('Error', 'No response received from server.', 'error');
            return;
        }

        try {
            console.log('Raw result:', result);
            const response = JSON.parse(result);
            console.log('Parsed response:', response);
            
            if (response.success === false) {
                this.showToastMessage('Error', response.error || 'Failed to create order.', 'error');
                return;
            }

            if (response.success && response.orders && response.orders.length > 0) {
                const order = response.orders[0];
                console.log('Order created:', order);

                if (!order.Id || !order.OrderNumber) {
                    throw new Error('Missing required order fields');
                }

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: `Order ${order.OrderNumber} created successfully.`,
                        variant: 'success'
                    })
                );
                this.navigateToOrder(order.Id);
                this.showModal = false;
                this.dispatchEvent(new CloseActionScreenEvent());
                return;
            }
            throw new Error('Unexpected response structure');

        } catch (error) {
            console.error('Error processing order result:', error);
            console.error('Raw result:', result);
            this.showToastMessage(
                'Error',
                'Failed to process order creation response: ' + error.message,
                'error'
            );
        }
    }

    navigateToOrder(orderId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: orderId,
                objectApiName: 'Order',
                actionName: 'view'
            }
        });
    }

    handleCancel() {
        this.showModal = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToastMessage(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}