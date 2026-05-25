import { LightningElement, api, track } from 'lwc';
import getDefaultValues from '@salesforce/apex/DRC_NBC_Generate_Order_Controller.getDefaultValues';
import createOrderRec from '@salesforce/apex/DRC_NBC_Generate_Order_Controller.createOrder';
import getOrderRecordTypes from '@salesforce/apex/DRC_NBC_Generate_Order_Controller.getOrderRecordTypes';
import getOrderTypes from '@salesforce/apex/DRC_NBC_Generate_Order_Controller.getOrderTypes';
import getFieldPicklistValues from '@salesforce/apex/DRC_NBC_Generate_Order_Controller.getFieldPicklistValues';
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

    // Contact search
    @track allBillToContacts = [];
    @track allShipToContacts = [];
    @track filteredBillToContacts = [];
    @track filteredShipToContacts = [];
    @track showBillToContactDropdown = false;
    @track showShipToContactDropdown = false;

    // ── Sales Person Code (Apex picklist) ────────────────────────────────────
    @track salesPersonCodeOptions = [];
    @track filteredSalesPersonCodes = [];
    @track salesPersonCodeDisplay = '';
    @track showSalesPersonDropdown = false;

    // ── Transport Agent (Domestic – Apex picklist) ────────────────────────────
    @track transportAgentOptions = [];
    @track filteredTransportAgents = [];
    @track transportAgentDisplay = '';
    @track showTransportAgentDropdown = false;

    // ── Port of Loading (Export – Apex picklist) ──────────────────────────────
    @track portOfLoadingOptions = [];
    @track filteredPortOfLoading = [];
    @track portOfLoadingDisplay = '';
    @track showPortOfLoadingDropdown = false;

    // ── Port of Discharge (Export – Apex picklist) ────────────────────────────
    @track portOfDischargeOptions = [];
    @track filteredPortOfDischarge = [];
    @track portOfDischargeDisplay = '';
    @track showPortOfDischargeDropdown = false;

    // ── Final Destination (Export – Apex picklist) ────────────────────────────
    @track finalDestinationOptions = [];
    @track filteredFinalDestination = [];
    @track finalDestinationDisplay = '';
    @track showFinalDestinationDropdown = false;

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

    // Section open/close state
    isBasicInfoOpen    = true;
    isExportOpen       = true;
    isDomesticOpen     = true;
    isContactOpen      = true;
    isAddressOpen      = true;
    isProductOpen      = true;
    isConsigneeBankOpen = true;
    isProcurementOpen  = true;

    // ── Toggle methods ────────────────────────────────────────────────────────
    toggleBasicInfo()        { this.isBasicInfoOpen     = !this.isBasicInfoOpen; }
    toggleConsigneeBankInfo(){ this.isConsigneeBankOpen = !this.isConsigneeBankOpen; }
    toggleProcurementInfo()  { this.isProcurementOpen   = !this.isProcurementOpen; }
    toggleExportInfo()       { this.isExportOpen        = !this.isExportOpen; }
    toggleDomesticInfo()     { this.isDomesticOpen      = !this.isDomesticOpen; }
    toggleContactInfo()      { this.isContactOpen       = !this.isContactOpen; }
    toggleAddressInfo()      { this.isAddressOpen       = !this.isAddressOpen; }
    toggleProductInfo()      { this.isProductOpen       = !this.isProductOpen; }

    // ── Section CSS getters ───────────────────────────────────────────────────
    get getBasicInfoClass()     { return `slds-section ${this.isBasicInfoOpen     ? 'slds-is-open' : ''}`; }
    get getConsigneeBankClass() { return `slds-section slds-m-top_medium ${this.isConsigneeBankOpen ? 'slds-is-open' : ''}`; }
    get getProcurementClass()   { return `slds-section slds-m-top_medium ${this.isProcurementOpen   ? 'slds-is-open' : ''}`; }
    get getExportClass()        { return `slds-section slds-m-top_medium ${this.isExportOpen        ? 'slds-is-open' : ''}`; }
    get getDomesticClass()      { return `slds-section slds-m-top_medium ${this.isDomesticOpen      ? 'slds-is-open' : ''}`; }
    get getContactClass()       { return `slds-section slds-m-top_medium ${this.isContactOpen       ? 'slds-is-open' : ''}`; }
    get getAddressClass()       { return `slds-section slds-m-top_medium ${this.isAddressOpen       ? 'slds-is-open' : ''}`; }
    get getProductClass()       { return `slds-section slds-m-top_medium ${this.isProductOpen       ? 'slds-is-open' : ''}`; }

    // ── Icon getters ──────────────────────────────────────────────────────────
    get getBasicInfoIcon()     { return this.isBasicInfoOpen     ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getConsigneeBankIcon() { return this.isConsigneeBankOpen ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getProcurementIcon()   { return this.isProcurementOpen   ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getExportIcon()        { return this.isExportOpen        ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getDomesticIcon()      { return this.isDomesticOpen      ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getContactIcon()       { return this.isContactOpen       ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getAddressIcon()       { return this.isAddressOpen       ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getProductIcon()       { return this.isProductOpen       ? 'utility:chevrondown' : 'utility:chevronright'; }

    get isOrderFormStep()       { return this.currentStep === 'orderForm'; }
    get isNextDisabled()        { return !this.selectedOrderType; }
    get selectedProductsLabel() { return `Selected: ${this.orderProductsList.filter(p => p.Selected).length}`; }

    get modalTitle() {
        if (this.selectedOrderType === 'Export')   return 'Generate Export Order';
        if (this.selectedOrderType === 'Domestic') return 'Generate Domestic Order';
        return 'Generate Order';
    }

    get todayDate() {
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm   = String(today.getMonth() + 1).padStart(2, '0');
        const dd   = String(today.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    connectedCallback() {
        this.initializeComponent();
        document.addEventListener('click', this.handleDocumentClick.bind(this));
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleDocumentClick.bind(this));
    }

    // ── Initialisation ────────────────────────────────────────────────────────

    initializeComponent() {
        this.extractRecordIdFromUrl();
        this.loadCustomStyles();
        this.loadOrderTypes();
        this.loadAllPicklists();       // Apex picklists (sales person, transport, ports, etc.)
        this.getOrderDefaultDetails(); // Apex default values
    }

    extractRecordIdFromUrl() {
        const url = window.location.href;
        const match = url.match(/([a-zA-Z0-9]{18})/);
        this.recordId = match ? match[1] : null;
        console.log('Record ID:', this.recordId);
    }

    loadCustomStyles() {
        Promise.all([loadStyle(this, DRC_NBC_Order_Button_CSS)])
            .then(() => console.log('All custom styles loaded.'))
            .catch(error => console.error('Error loading styles:', error));
    }

    loadOrderTypes() {
        getOrderTypes()
            .then(result => { this.orderTypeOptions = result; })
            .catch(error => {
                console.error('Error loading order types:', error);
                this.showToastMessage('Error', 'Failed to load order types.', 'error');
            });
    }

    // Apex picklists – all fetched from backend
    loadAllPicklists() {
        // ── Sales Person Code ─────────────────────────────────────────────────
        getFieldPicklistValues({ objectName: 'Order', fieldName: 'DRC_NBC_SalesPerson_Code__c' })
            .then(result => {
                this.salesPersonCodeOptions   = result || [];
                this.filteredSalesPersonCodes = [...this.salesPersonCodeOptions];
            })
            .catch(err => console.warn('Sales Person Code picklist not loaded:', err));

        // ── Transport Agent ───────────────────────────────────────────────────
        getFieldPicklistValues({ objectName: 'Order', fieldName: 'DRC_NBC_Transport_Agent__c' })
            .then(result => {
                this.transportAgentOptions    = result || [];
                this.filteredTransportAgents  = [...this.transportAgentOptions];
            })
            .catch(err => console.warn('Transport Agent picklist not loaded:', err));

        // ── Port of Loading ───────────────────────────────────────────────────
        getFieldPicklistValues({ objectName: 'Order', fieldName: 'DRC_NBC_Port_of_Loading__c' })
            .then(result => {
                this.portOfLoadingOptions   = result || [];
                this.filteredPortOfLoading  = [...this.portOfLoadingOptions];
            })
            .catch(err => console.warn('Port of Loading picklist not loaded:', err));

        // ── Port of Discharge ─────────────────────────────────────────────────
        getFieldPicklistValues({ objectName: 'Order', fieldName: 'DRC_NBC_Port_Of_Discharge__c' })
            .then(result => {
                this.portOfDischargeOptions   = result || [];
                this.filteredPortOfDischarge  = [...this.portOfDischargeOptions];
            })
            .catch(err => console.warn('Port of Discharge picklist not loaded:', err));

        // ── Final Destination ─────────────────────────────────────────────────
        getFieldPicklistValues({ objectName: 'Order', fieldName: 'DRC_NBC_Final_Destination__c' })
            .then(result => {
                this.finalDestinationOptions   = result || [];
                this.filteredFinalDestination  = [...this.finalDestinationOptions];
            })
            .catch(err => console.warn('Final Destination picklist not loaded:', err));
    }

    // ── Document click – close all dropdowns when clicking outside ────────────

    handleDocumentClick(event) {
        const tryClose = (inputId, showProp) => {
            const el = this.template.querySelector(`#${inputId}`);
            if (el && !el.contains(event.target)) {
                this[showProp] = false;
            }
        };
        tryClose('billToContact',        'showBillToContactDropdown');
        tryClose('shipToContact',        'showShipToContactDropdown');
        tryClose('salesPersonCodeInput', 'showSalesPersonDropdown');
        tryClose('transportAgentInput',  'showTransportAgentDropdown');
        tryClose('portOfLoadingInput',   'showPortOfLoadingDropdown');
        tryClose('portOfDischargeInput', 'showPortOfDischargeDropdown');
        tryClose('finalDestinationInput','showFinalDestinationDropdown');
    }

    // ── Generic dropdown helpers ──────────────────────────────────────────────

    _openDropdown(showProp) {
        const allProps = [
            'showSalesPersonDropdown', 'showTransportAgentDropdown',
            'showPortOfLoadingDropdown', 'showPortOfDischargeDropdown',
            'showFinalDestinationDropdown', 'showBillToContactDropdown',
            'showShipToContactDropdown'
        ];
        allProps.forEach(p => { this[p] = false; });
        this[showProp] = true;
    }

    _filterOptions(allOptions, searchTerm) {
        if (!searchTerm) return [...allOptions];
        const term = searchTerm.toLowerCase();
        return allOptions.filter(o => o.label.toLowerCase().includes(term));
    }

    // ── Sales Person Code handlers (Apex picklist) ────────────────────────────

    handleSalesPersonFocus(event) {
        event.stopPropagation();
        this.filteredSalesPersonCodes = [...this.salesPersonCodeOptions];
        this._openDropdown('showSalesPersonDropdown');
    }

    handleSalesPersonSearch(event) {
        this.salesPersonCodeDisplay   = event.target.value;
        this.filteredSalesPersonCodes = this._filterOptions(this.salesPersonCodeOptions, event.target.value);
        this.showSalesPersonDropdown  = true;
    }

    handleSalesPersonSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const lbl = event.currentTarget.dataset.label;
        this.salesPersonCodeDisplay                  = lbl;
        this.samplingRec.DRC_NBC_SalesPerson_Code__c = val;
        this.showSalesPersonDropdown                 = false;
    }

    // ── Transport Agent handlers ──────────────────────────────────────────────

    handleTransportAgentFocus(event) {
        event.stopPropagation();
        this.filteredTransportAgents = [...this.transportAgentOptions];
        this._openDropdown('showTransportAgentDropdown');
    }

    handleTransportAgentSearch(event) {
        this.transportAgentDisplay      = event.target.value;
        this.filteredTransportAgents    = this._filterOptions(this.transportAgentOptions, event.target.value);
        this.showTransportAgentDropdown = true;
    }

    handleTransportAgentSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const lbl = event.currentTarget.dataset.label;
        this.transportAgentDisplay                 = lbl;
        this.samplingRec.DRC_NBC_Transport_Agent__c = val;
        this.showTransportAgentDropdown             = false;
    }

    // ── Port of Loading handlers ──────────────────────────────────────────────

    handlePortOfLoadingFocus(event) {
        event.stopPropagation();
        this.filteredPortOfLoading = [...this.portOfLoadingOptions];
        this._openDropdown('showPortOfLoadingDropdown');
    }

    handlePortOfLoadingSearch(event) {
        this.portOfLoadingDisplay      = event.target.value;
        this.filteredPortOfLoading     = this._filterOptions(this.portOfLoadingOptions, event.target.value);
        this.showPortOfLoadingDropdown = true;
    }

    handlePortOfLoadingSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const lbl = event.currentTarget.dataset.label;
        this.portOfLoadingDisplay                   = lbl;
        this.samplingRec.DRC_NBC_Port_of_Loading__c = val;
        this.showPortOfLoadingDropdown              = false;
    }

    // ── Port of Discharge handlers ────────────────────────────────────────────

    handlePortOfDischargeFocus(event) {
        event.stopPropagation();
        this.filteredPortOfDischarge = [...this.portOfDischargeOptions];
        this._openDropdown('showPortOfDischargeDropdown');
    }

    handlePortOfDischargeSearch(event) {
        this.portOfDischargeDisplay      = event.target.value;
        this.filteredPortOfDischarge     = this._filterOptions(this.portOfDischargeOptions, event.target.value);
        this.showPortOfDischargeDropdown = true;
    }

    handlePortOfDischargeSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const lbl = event.currentTarget.dataset.label;
        this.portOfDischargeDisplay                    = lbl;
        this.samplingRec.DRC_NBC_Port_Of_Discharge__c  = val;
        this.showPortOfDischargeDropdown               = false;
    }

    // ── Final Destination handlers ────────────────────────────────────────────

    handleFinalDestinationFocus(event) {
        event.stopPropagation();
        this.filteredFinalDestination = [...this.finalDestinationOptions];
        this._openDropdown('showFinalDestinationDropdown');
    }

    handleFinalDestinationSearch(event) {
        this.finalDestinationDisplay      = event.target.value;
        this.filteredFinalDestination     = this._filterOptions(this.finalDestinationOptions, event.target.value);
        this.showFinalDestinationDropdown = true;
    }

    handleFinalDestinationSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const lbl = event.currentTarget.dataset.label;
        this.finalDestinationDisplay                   = lbl;
        this.samplingRec.DRC_NBC_Final_Destination__c  = val;
        this.showFinalDestinationDropdown              = false;
    }

    // ── Order Type ────────────────────────────────────────────────────────────

    handleOrderTypeChange(event) {
        this.selectedOrderType = event.detail.value;
        this.showExportSection   = this.selectedOrderType === 'Export';
        this.showDomesticSection = this.selectedOrderType === 'Domestic';
        this.samplingRec.DRC_NBC_Type__c = this.selectedOrderType;
    }

    // ── Bill To Contact handlers ──────────────────────────────────────────────

    handleBillToContactFocus(event) {
        event.stopPropagation();
        this.filteredBillToContacts = [...this.allBillToContacts];
        this._openDropdown('showBillToContactDropdown');
    }

    handleBillToContactSearch(event) {
        const term = event.target.value.toLowerCase();
        this.billToContactName      = event.target.value;
        this.filteredBillToContacts = this.allBillToContacts.filter(c => c.label.toLowerCase().includes(term));
        this.showBillToContactDropdown = true;
    }

    handleBillToContactSelect(event) {
        event.stopPropagation();
        this.billToContactId             = event.currentTarget.dataset.id;
        this.billToContactName           = event.currentTarget.dataset.name;
        this.samplingRec.BillToContactId = this.billToContactId;
        this.showBillToContactDropdown   = false;
    }

    // ── Ship To Contact handlers ──────────────────────────────────────────────

    handleShipToContactFocus(event) {
        event.stopPropagation();
        this.filteredShipToContacts = [...this.allShipToContacts];
        this._openDropdown('showShipToContactDropdown');
    }

    handleShipToContactSearch(event) {
        const term = event.target.value.toLowerCase();
        this.shipToContactName      = event.target.value;
        this.filteredShipToContacts = this.allShipToContacts.filter(c => c.label.toLowerCase().includes(term));
        this.showShipToContactDropdown = true;
    }

    handleShipToContactSelect(event) {
        event.stopPropagation();
        this.shipToContactId             = event.currentTarget.dataset.id;
        this.shipToContactName           = event.currentTarget.dataset.name;
        this.samplingRec.ShipToContactId = this.shipToContactId;
        this.showShipToContactDropdown   = false;
    }

    // ── Price change ──────────────────────────────────────────────────────────

    handleFinalPriceChange(event) {
        const id    = event.target.dataset.id;
        const value = parseFloat(event.target.value) || 0;
        this.orderProductsList = this.orderProductsList.map(item => {
            if (item.QuoteLineItemId === id) {
                const base = parseFloat(item.OriginalUnitPrice) || 0;
                return { ...item, finalPrice: value, modifier: value - base, pendingModifierInput: 0 };
            }
            return item;
        });
    }

    // ── Load default values from Apex ─────────────────────────────────────────

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
                this.selectedOrderType           = orderType;
                this.samplingRec.DRC_NBC_Type__c = orderType;
                this.showExportSection   = orderType === 'Export';
                this.showDomesticSection = orderType === 'Domestic';
                this.samplingRec.Status  = 'Draft';
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

        this.samplingRec.QuoteId      = this.recordId;
        this.samplingRec.Pricebook2Id = result.Pricebook2Id;
        this.priceBookId              = result.Pricebook2Id;

        this.samplingRec.DRC_NBC_Payment_Terms__c            = result.paymentTerm;
        this.samplingRec.DRC_NBC_Payment_Term_Description__c = result.paymentTermDes;
        this.samplingRec.DRC_NBC_TCS_Amount__c               = result.tcsAmount;
        this.samplingRec.DRC_NBC_IGST__c                     = result.igst;
        this.samplingRec.DRC_NBC_CGST__c                     = result.cgst;
        this.samplingRec.DRC_NBC_SGST__c                     = result.sgst;
        this.samplingRec.DRC_NBC_Other_Tax_Amount__c         = result.otherTaxAmount;
        this.samplingRec.DRC_NBC_Inco_Terms__c               = result.incoTerm;
        this.samplingRec.DRC_NBC_Type__c                     = result.types;
        this.samplingRec.DRC_NBC_Delivery_Terms__c           = result.deliveryTerm;

        const acc = result.acc[0];
        this.samplingRec.DRC_NBC_Consignee_Bank_Address__c        = acc.DRC_NBC_Consignee_Bank_Address__c;
        this.samplingRec.DRC_NBC_Special_Instructions__c          = acc.DRC_NBC_Special_Instructions__c;
        this.samplingRec.DRC_NBC_Consignee_Bank_Name__c           = acc.DRC_NBC_Consignee_Bank_Name__c;
        this.samplingRec.DRC_NBC_Consignee_Bank_IFSC_Code__c      = acc.DRC_NBC_Consignee_Bank_IFSC_Code__c;
        this.samplingRec.DRC_NBC_Consignee_Bank_Account_Number__c = acc.DRC_NBC_Consignee_Bank_Account_Number__c;

        // ── Sales Person Code: pre-populate from Account, full picklist stays selectable ──
        const accountSalesPersonCode = result.salesPersonCode || acc.SalesPerson_Code__c || '';
        this.samplingRec.DRC_NBC_SalesPerson_Code__c = accountSalesPersonCode;

        // Match against the Apex-loaded picklist options to get the display label
        const matched = this.salesPersonCodeOptions.find(o => o.value === accountSalesPersonCode);
        this.salesPersonCodeDisplay = matched ? matched.label : accountSalesPersonCode;

        // Reset filtered list so it is ready on first focus
        this.filteredSalesPersonCodes = [...this.salesPersonCodeOptions];

        this.currencyCode = result.opportunityObj[0].CurrencyIsoCode;

        if (result.acc && result.acc.length > 0) {
            this.samplingRec.AccountId = acc.Id;

            this.samplingRec.BillingStreet      = result.BillingStreet      || '';
            this.samplingRec.BillingCity        = result.BillingCity        || '';
            this.samplingRec.BillingState       = result.BillingState       || '';
            this.samplingRec.BillingPostalCode  = result.BillingPostalCode  || '';
            this.samplingRec.BillingCountry     = result.BillingCountry     || '';
            this.samplingRec.BillingCountryCode = result.BillingCountryCode || '';

            const billingParts = [
                result.BillingStreet, result.BillingCity,
                result.BillingState,  result.BillingPostalCode,
                result.BillingCountry
            ].filter(Boolean);
            this.billingAddressDisplay = billingParts.join(', ') || 'No billing address';

            this.shippingAddressOptions = [];
            this.customerContacts       = result.customerContacts;

            if (acc.Address__r && acc.Address__r.length > 0) {
                this.addrDetails = acc.Address__r;
                acc.Address__r.forEach(addr => {
                    const d = addr.DRC_NBC_Address__c;
                    const labelParts = [d?.street, d?.city, d?.postalCode, d?.country].filter(Boolean);
                    const label = labelParts.join(', ') || 'Unknown Address';
                    if (addr.DRC_NBC_Type__c === 'Shipping') {
                        this.shippingAddressOptions.push({ label, value: addr.Id });
                    }
                });

                if (this.shippingAddressOptions.length === 1) {
                    this.selectedShippingId = this.shippingAddressOptions[0].value;
                    const addressToAdd = this.addrDetails.find(item => item.Id === this.selectedShippingId);
                    if (addressToAdd?.DRC_NBC_Address__c) {
                        const a = addressToAdd.DRC_NBC_Address__c;
                        this.samplingRec.ShippingStreet                = a.street      || '';
                        this.samplingRec.ShippingCity                  = a.city        || '';
                        this.samplingRec.ShippingPostalCode            = a.postalCode  || '';
                        this.samplingRec.ShippingCountry               = a.country     || '';
                        this.samplingRec.ShippingCountryCode           = a.countryCode || '';
                        this.samplingRec.DRC_NBC_Shipping_Address__c   = addressToAdd.Id;
                    }
                }
            }
        }

        this.customerContacts       = result.customerContacts || [];
        this.allBillToContacts      = this.customerContacts.map(c => ({ label: c.Name, value: c.Id }));
        this.allShipToContacts      = [...this.allBillToContacts];
        this.filteredBillToContacts = [...this.allBillToContacts];
        this.filteredShipToContacts = [...this.allShipToContacts];

        if (this.allBillToContacts.length > 0) {
            this.billToContactId             = this.allBillToContacts[0].value;
            this.billToContactName           = this.allBillToContacts[0].label;
            this.samplingRec.BillToContactId = this.billToContactId;
        }
        if (this.allShipToContacts.length > 0) {
            this.shipToContactId             = this.allShipToContacts[0].value;
            this.shipToContactName           = this.allShipToContacts[0].label;
            this.samplingRec.ShipToContactId = this.shipToContactId;
        }

        this.processOrderItems(result.orderItems || []);
    }

    processAccountData(account) {
        this.accountId             = account.Id;
        this.samplingRec.AccountId = account.Id;
        this.shippingAddressOptions = [];
    }

    processOrderItems(orderItems) {
        this.orderProductsList = orderItems.map(item => {
            const basePrice       = parseFloat(item.UnitPrice) || 0;
            const packingSize     = item.DRC_NBC_Packing_Size    || item.DRC_NBC_Packing_Size__c    || '';
            const packingQuantity = item.DRC_NBC_Packing_Quantity || item.DRC_NBC_Packing_Quantity__c || '';
            return {
                ...item,
                QuoteLineItemId:  item.QuoteLineItemId || item.Id,
                Product2Id:       item.Product2Id,
                PriceBookEntryId: item.PriceBookEntryId || item.PricebookEntryId,
                Selected:  false,
                disabled:  true,
                Product2:  item.Product2 || { Name: 'N/A' },
                UnitPrice: basePrice,
                OriginalUnitPrice: basePrice,
                modifier:   0,
                finalPrice: basePrice,
                DRC_NBC_FG_Code:                item.Product2?.DRC_NBC_FG_Code      || '',
                DRC_NBC_HSN_Code:               item.Product2?.DRC_NBC_HSN_SAC_Code || '',
                DRC_NBC_Unit_Of_Measurement__c: 'KGS',
                DRC_NBC_Packing_Size__c:        packingSize,
                DRC_NBC_Packing_Quantity__c:    packingQuantity
            };
        });
        this.originalOrderProductsList = [...this.orderProductsList];
    }

    // ── Address ───────────────────────────────────────────────────────────────

    handleAddressChange(event) {
        const selectedValue = event.detail.value;
        const addressToAdd  = this.addrDetails.find(item => item.Id === selectedValue);
        if (!addressToAdd) return;
        if (event.target.name === 'shipping') {
            this.selectedShippingId = selectedValue;
            this.updateAddressFields('Shipping', addressToAdd);
        }
    }

    updateAddressFields(type, address) {
        if (!address) return;
        const d = address.DRC_NBC_Address__c || address;
        this.samplingRec[`${type}Street`]              = d.street      || '';
        this.samplingRec[`${type}City`]                = d.city        || '';
        this.samplingRec[`${type}PostalCode`]          = d.postalCode  || '';
        this.samplingRec[`${type}Country`]             = d.country     || '';
        this.samplingRec[`${type}CountryCode`]         = d.countryCode || '';
        this.samplingRec[`DRC_NBC_${type}_Address__c`] = address.Id;
    }

    // ── Field change handlers ─────────────────────────────────────────────────

    handleOrderItemChange(event) {
        const id        = event.target.dataset.id;
        const fieldName = event.target.dataset.apiname;
        const value     = event.target.value;
        this.orderProductsList = this.orderProductsList.map(item =>
            item.QuoteLineItemId === id ? { ...item, [fieldName]: value } : item
        );
    }

    handleValueChange(event) {
        try {
            const fieldName = event.target.fieldName || event.target.name;
            const value     = event.target.value;
            if (fieldName !== undefined) {
                this.samplingRec = { ...this.samplingRec, [fieldName]: value };
            }
        } catch (error) {
            console.error('Error in handleValueChange:', error);
        }
    }

    handleFormLoad(event) {
        const record = event.detail.record;
        if (record?.fields) {
            if (record.fields.Status?.value) {
                this.samplingRec.Status = record.fields.Status.value;
            }
            if (!this.samplingRec.EffectiveDate) {
                this.samplingRec.EffectiveDate = new Date().toISOString().split('T')[0];
            }
        }
    }

    handleInputFieldChange(event) {
        const fieldName = event.currentTarget.dataset.field || event.target.fieldName;
        const newValue  = event.detail.value !== undefined ? event.detail.value : event.target.value;
        if (fieldName) {
            this.samplingRec[fieldName] = newValue;
        }
    }

    handleProductSelect(event) {
        const id        = event.target.dataset.id;
        const isChecked = event.target.checked;
        this.orderProductsList = this.orderProductsList.map(item => {
            if (item.QuoteLineItemId === id) {
                return { ...item, Selected: isChecked, disabled: !isChecked };
            }
            return item;
        });
    }

    handleSearch(event) {
        const key = event.target.value.toLowerCase();
        this.orderProductsList = key
            ? this.originalOrderProductsList.filter(item =>
                item.Product2?.Name?.toLowerCase().includes(key))
            : [...this.originalOrderProductsList];
    }

    // ── Validation ────────────────────────────────────────────────────────────

    validateOrderData() {
        const validations = [
            { field: 'EffectiveDate',                       message: 'Enter Order Start Date.' },
            { field: 'EndDate',                             message: 'Enter Order End Date.' },
            { field: 'Pricebook2Id',                        message: 'Enter Price Book.' },
            { field: 'BillToContactId',                     message: 'Enter Bill To Contact.' },
            { field: 'ShipToContactId',                     message: 'Enter Ship To Contact.' },
            { field: 'DRC_NBC_Payment_Terms__c',            message: 'Enter Payment Term Code.' },
            { field: 'DRC_NBC_Payment_Term_Description__c', message: 'Enter Payment Term Description.' },
            { field: 'DRC_NBC_Inco_Terms__c',               message: 'Enter Inco Term.' },
            { field: 'DRC_NBC_Warehouse__c',                message: 'Enter Warehouse.' },
            { field: 'DRC_NBC_SalesPerson_Code__c',         message: 'Enter Sales Person Code.' },
        ];

        for (const v of validations) {
            if (!this.samplingRec[v.field]) {
                this.showToastMessage('Error', v.message, 'error');
                return false;
            }
        }

        if (!this.selectedShippingId) {
            this.showToastMessage('Error', 'Enter Shipping Address.', 'error');
            return false;
        }

        const today = new Date(); today.setHours(0, 0, 0, 0);
        const effectiveDate = new Date(this.samplingRec.EffectiveDate); effectiveDate.setHours(0, 0, 0, 0);
        const endDate       = new Date(this.samplingRec.EndDate);       endDate.setHours(0, 0, 0, 0);

        if (effectiveDate > today) { this.showToastMessage('Error', 'Order Start Date cannot be greater than today.', 'error'); return false; }
        if (effectiveDate < today) { this.showToastMessage('Error', 'Order Start Date cannot be less than today.', 'error');    return false; }
        if (endDate <= today)      { this.showToastMessage('Error', 'End Date must be greater than today.', 'error');           return false; }
        if (this.samplingRec.EffectiveDate > this.samplingRec.EndDate) {
            this.showToastMessage('Error', 'End Date must be later than Start Date.', 'error'); return false;
        }

        const dateChecks = [
            { field: 'DRC_NBC_Expected_Delivery_Date__c', label: 'Expected Delivery Date' },
            { field: 'DRC_NBC_Courier_date__c',           label: 'Courier date' },
            { field: 'DRC_NBC_Shipment_Date__c',          label: 'Shipment Date' },
            { field: 'NBC_DRC_Dispatch_Date__c',          label: 'Dispatch Date' },
            { field: 'PoDate',                            label: 'PO Date' },
        ];
        for (const dc of dateChecks) {
            if (this.samplingRec[dc.field] && this.samplingRec[dc.field] > this.samplingRec.EndDate) {
                this.showToastMessage('Error', `${dc.label} must be less than End Date.`, 'error');
                return false;
            }
        }
        return true;
    }

    validateOrderProducts() {
        this.finalOrderProducts = this.orderProductsList.filter(item => item.Selected);
        if (this.finalOrderProducts.length === 0) {
            this.showToastMessage('Error', 'Please select at least one product.', 'error');
            return false;
        }
        for (const item of this.finalOrderProducts) {
            if (!item.Product2Id) {
                this.showToastMessage('Error', 'Missing Product ID for selected products.', 'error'); return false;
            }
            if (!item.PriceBookEntryId && !item.PricebookEntryId) {
                this.showToastMessage('Error', 'Missing Pricebook Entry for selected products.', 'error'); return false;
            }
            if (!(parseFloat(item.finalPrice || item.UnitPrice) > 0)) {
                this.showToastMessage('Error', 'Enter valid Price per piece for all selected products.', 'error'); return false;
            }
            if (!item.Quantity || item.Quantity <= 0) {
                this.showToastMessage('Error', 'Enter valid Quantity for all selected products.', 'error'); return false;
            }
        }
        return true;
    }

    // ── Save ──────────────────────────────────────────────────────────────────

    handleSave() {
        this.disabledButton = true;
        if (!this.validateOrderData())     { this.disabledButton = false; return; }
        if (!this.validateOrderProducts()) { this.disabledButton = false; return; }

        const cleanedOrderProducts = this.orderProductsList
            .filter(item => item.Selected)
            .map(item => {
                const adjustedPrice = parseFloat(item.finalPrice) ||
                    (parseFloat(item.OriginalUnitPrice || item.UnitPrice || 0) + parseFloat(item.modifier || 0));
                return {
                    QuoteLineItemId:          item.QuoteLineItemId || item.Id,
                    Product2Id:               item.Product2Id,
                    PriceBookEntryId:         item.PriceBookEntryId || item.PricebookEntryId,
                    Description:              item.Description || '',
                    Quantity:                 parseFloat(item.Quantity) || 1,
                    UnitPrice:                adjustedPrice,
                    UOM:                      'KGS',
                    DRC_NBC_Packing_Size:     item.DRC_NBC_Packing_Size__c    || item.DRC_NBC_Packing_Size     || '',
                    DRC_NBC_Packing_Quantity: item.DRC_NBC_Packing_Quantity__c || item.DRC_NBC_Packing_Quantity || ''
                };
            });

        this.samplingRec.CurrencyIsoCode = this.currencyCode;
        this.createOrder(cleanedOrderProducts);
    }

    createOrder(cleanedOrderProducts) {
        this.load = true;
        createOrderRec({
            orderObj:   this.samplingRec,
            orderItems: cleanedOrderProducts,
            quoteID:    this.recordId
        })
        .then(result => { this.handleOrderCreationResult(result); })
        .catch(error => {
            this.load           = false;
            this.disabledButton = false;
            this.showToastMessage('Error', error.body?.message || 'Failed to create order.', 'error');
        });
    }

    handleOrderCreationResult(result) {
        this.load           = false;
        this.disabledButton = false;
        if (!result) {
            this.showToastMessage('Error', 'No response received from server.', 'error');
            return;
        }
        try {
            const response = JSON.parse(result);
            if (response.success === false) {
                this.showToastMessage('Error', response.error || 'Failed to create order.', 'error');
                return;
            }
            if (response.success && response.orders?.length > 0) {
                const order = response.orders[0];
                if (!order.Id || !order.OrderNumber) throw new Error('Missing required order fields');
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Success',
                    message: `Order ${order.OrderNumber} created successfully.`,
                    variant: 'success'
                }));
                this.navigateToOrder(order.Id);
                this.showModal = false;
                this.dispatchEvent(new CloseActionScreenEvent());
                return;
            }
            throw new Error('Unexpected response structure');
        } catch (error) {
            this.showToastMessage('Error', 'Failed to process order creation response: ' + error.message, 'error');
        }
    }

    navigateToOrder(orderId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: orderId, objectApiName: 'Order', actionName: 'view' }
        });
    }

    handleCancel() {
        this.showModal = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToastMessage(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}