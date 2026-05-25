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
    
    // Contact search functionality
    @track allBillToContacts = [];
    @track allShipToContacts = [];
    @track filteredBillToContacts = [];
    @track filteredShipToContacts = [];
    @track showBillToContactDropdown = false;
    @track showShipToContactDropdown = false;

    // ─── Searchable Picklist: Sales Person Code ───────────────────────────────
    @track salesPersonCodeOptions = [];
    @track filteredSalesPersonCodes = [];
    @track salesPersonCodeDisplay = '';
    @track showSalesPersonDropdown = false;

    // ─── Searchable Picklist: Transport Agent (Domestic) ─────────────────────
    @track transportAgentOptions = [];
    @track filteredTransportAgents = [];
    @track transportAgentDisplay = '';
    @track showTransportAgentDropdown = false;

    // ─── Searchable Picklist: Port of Loading (Export) ────────────────────────
    @track portOfLoadingOptions = [];
    @track filteredPortOfLoading = [];
    @track portOfLoadingDisplay = '';
    @track showPortOfLoadingDropdown = false;

    // ─── Searchable Picklist: Port of Discharge (Export) ─────────────────────
    @track portOfDischargeOptions = [];
    @track filteredPortOfDischarge = [];
    @track portOfDischargeDisplay = '';
    @track showPortOfDischargeDropdown = false;

    // ─── Searchable Picklist: Final Destination (Export) ─────────────────────
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
    isBasicInfoOpen = true;
    isExportOpen = true;
    isDomesticOpen = true;
    isContactOpen = true;
    isAddressOpen = true;
    isProductOpen = true;
    isConsigneeBankOpen = true;
    isProcurementOpen = true;

    // Toggle methods
    toggleBasicInfo() { this.isBasicInfoOpen = !this.isBasicInfoOpen; }
    toggleConsigneeBankInfo() { this.isConsigneeBankOpen = !this.isConsigneeBankOpen; }
    toggleProcurementInfo() { this.isProcurementOpen = !this.isProcurementOpen; }
    toggleExportInfo() { this.isExportOpen = !this.isExportOpen; }
    toggleDomesticInfo() { this.isDomesticOpen = !this.isDomesticOpen; }
    toggleContactInfo() { this.isContactOpen = !this.isContactOpen; }
    toggleAddressInfo() { this.isAddressOpen = !this.isAddressOpen; }
    toggleProductInfo() { this.isProductOpen = !this.isProductOpen; }

    // Getter methods for classes
    get getBasicInfoClass() { return `slds-section ${this.isBasicInfoOpen ? 'slds-is-open' : ''}`; }
    get getConsigneeBankClass() { return `slds-section slds-m-top_medium ${this.isConsigneeBankOpen ? 'slds-is-open' : ''}`; }
    get getProcurementClass() { return `slds-section slds-m-top_medium ${this.isProcurementOpen ? 'slds-is-open' : ''}`; }
    get getExportClass() { return `slds-section slds-m-top_medium ${this.isExportOpen ? 'slds-is-open' : ''}`; }
    get getDomesticClass() { return `slds-section slds-m-top_medium ${this.isDomesticOpen ? 'slds-is-open' : ''}`; }
    get getContactClass() { return `slds-section slds-m-top_medium ${this.isContactOpen ? 'slds-is-open' : ''}`; }
    get getAddressClass() { return `slds-section slds-m-top_medium ${this.isAddressOpen ? 'slds-is-open' : ''}`; }
    get getProductClass() { return `slds-section slds-m-top_medium ${this.isProductOpen ? 'slds-is-open' : ''}`; }

    // Getter methods for icons
    get getBasicInfoIcon() { return this.isBasicInfoOpen ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getConsigneeBankIcon() { return this.isConsigneeBankOpen ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getProcurementIcon() { return this.isProcurementOpen ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getExportIcon() { return this.isExportOpen ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getDomesticIcon() { return this.isDomesticOpen ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getContactIcon() { return this.isContactOpen ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getAddressIcon() { return this.isAddressOpen ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getProductIcon() { return this.isProductOpen ? 'utility:chevrondown' : 'utility:chevronright'; }

    get isOrderFormStep() { return this.currentStep === 'orderForm'; }
    get isNextDisabled() { return !this.selectedOrderType; }
    get selectedProductsLabel() { return `Selected: ${this.orderProductsList.filter(p => p.Selected).length}`; }

    get modalTitle() {
        if (this.selectedOrderType === 'Export') return 'Generate Export Order';
        if (this.selectedOrderType === 'Domestic') return 'Generate Domestic Order';
        return 'Generate Order';
    }

    connectedCallback() {
        this.initializeComponent();
        document.addEventListener('click', this.handleDocumentClick.bind(this));
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleDocumentClick.bind(this));
    }

    handleDocumentClick(event) {
        const closeDropdown = (inputId, showProp, filteredProp, allOptions) => {
            const el = this.template.querySelector(`#${inputId}`);
            if (el && !el.contains(event.target)) {
                this[showProp] = false;
            }
        };
        closeDropdown('billToContact', 'showBillToContactDropdown');
        closeDropdown('shipToContact', 'showShipToContactDropdown');
        closeDropdown('salesPersonCodeInput', 'showSalesPersonDropdown');
        closeDropdown('transportAgentInput', 'showTransportAgentDropdown');
        closeDropdown('portOfLoadingInput', 'showPortOfLoadingDropdown');
        closeDropdown('portOfDischargeInput', 'showPortOfDischargeDropdown');
        closeDropdown('finalDestinationInput', 'showFinalDestinationDropdown');
    }

    initializeComponent() {
        this.extractRecordIdFromUrl();
        this.loadCustomStyles();
        this.loadOrderTypes();
        this.loadAllPicklists();
        this.getOrderDefaultDetails();
    }

    extractRecordIdFromUrl() {
        const url = window.location.href;
        const recordIdMatch = url.match(/([a-zA-Z0-9]{18})/);
        this.recordId = recordIdMatch ? recordIdMatch[1] : null;
        console.log('Record ID:', this.recordId);
    }

    loadCustomStyles() {
        Promise.all([loadStyle(this, DRC_NBC_Order_Button_CSS)])
            .then(() => console.log('All custom styles loaded.'))
            .catch(error => console.error('Error loading styles:', error));
    }

    loadOrderTypes() {
        getOrderTypes()
            .then(result => {
                this.orderTypeOptions = result;
            })
            .catch(error => {
                console.error('Error loading order types:', error);
                this.showToastMessage('Error', 'Failed to load order types.', 'error');
            });
    }

    /**
     * Load all picklist values in parallel for searchable dropdowns.
     * Adjust the objectName/fieldName pairs to match your org's API names.
     */
    loadAllPicklists() {
        // Transport Agent (Domestic)
        getFieldPicklistValues({ objectName: 'Order', fieldName: 'DRC_NBC_Transport_Agent__c' })
            .then(result => {
                this.transportAgentOptions = result || [];
                this.filteredTransportAgents = [...this.transportAgentOptions];
            })
            .catch(err => console.warn('Transport Agent picklist not loaded:', err));

        // Port of Loading (Export)
        getFieldPicklistValues({ objectName: 'Order', fieldName: 'DRC_NBC_Port_of_Loading__c' })
            .then(result => {
                this.portOfLoadingOptions = result || [];
                this.filteredPortOfLoading = [...this.portOfLoadingOptions];
            })
            .catch(err => console.warn('Port of Loading picklist not loaded:', err));

        // Port of Discharge (Export)
        getFieldPicklistValues({ objectName: 'Order', fieldName: 'DRC_NBC_Port_Of_Discharge__c' })
            .then(result => {
                this.portOfDischargeOptions = result || [];
                this.filteredPortOfDischarge = [...this.portOfDischargeOptions];
            })
            .catch(err => console.warn('Port of Discharge picklist not loaded:', err));

        // Final Destination (Export)
        getFieldPicklistValues({ objectName: 'Order', fieldName: 'DRC_NBC_Final_Destination__c' })
            .then(result => {
                this.finalDestinationOptions = result || [];
                this.filteredFinalDestination = [...this.finalDestinationOptions];
            })
            .catch(err => console.warn('Final Destination picklist not loaded:', err));
    }

    // ─── Generic Searchable Picklist Helpers ─────────────────────────────────

    _openDropdown(showProp, otherProps) {
        // Close all others
        const allProps = [
            'showSalesPersonDropdown', 'showTransportAgentDropdown',
            'showPortOfLoadingDropdown', 'showPortOfDischargeDropdown',
            'showFinalDestinationDropdown', 'showBillToContactDropdown', 'showShipToContactDropdown'
        ];
        allProps.forEach(p => { this[p] = false; });
        this[showProp] = true;
    }

    _filterOptions(allOptions, searchTerm) {
        if (!searchTerm) return [...allOptions];
        const term = searchTerm.toLowerCase();
        return allOptions.filter(o => o.label.toLowerCase().includes(term));
    }

    // ─── Sales Person Code ────────────────────────────────────────────────────

    handleSalesPersonFocus(event) {
        event.stopPropagation();
        this.filteredSalesPersonCodes = [...this.salesPersonCodeOptions];
        this._openDropdown('showSalesPersonDropdown');
    }

    handleSalesPersonSearch(event) {
        this.salesPersonCodeDisplay = event.target.value;
        this.filteredSalesPersonCodes = this._filterOptions(this.salesPersonCodeOptions, event.target.value);
        this.showSalesPersonDropdown = true;
    }

    handleSalesPersonSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const lbl = event.currentTarget.dataset.label;
        this.salesPersonCodeDisplay = lbl;
        this.samplingRec.DRC_NBC_SalesPerson_Code__c = val;
        this.showSalesPersonDropdown = false;
    }

    // ─── Transport Agent (Domestic) ───────────────────────────────────────────

    handleTransportAgentFocus(event) {
        event.stopPropagation();
        this.filteredTransportAgents = [...this.transportAgentOptions];
        this._openDropdown('showTransportAgentDropdown');
    }

    handleTransportAgentSearch(event) {
        this.transportAgentDisplay = event.target.value;
        this.filteredTransportAgents = this._filterOptions(this.transportAgentOptions, event.target.value);
        this.showTransportAgentDropdown = true;
    }

    handleTransportAgentSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const lbl = event.currentTarget.dataset.label;
        this.transportAgentDisplay = lbl;
        this.samplingRec.DRC_NBC_Transport_Agent__c = val;
        this.showTransportAgentDropdown = false;
    }

    // ─── Port of Loading (Export) ─────────────────────────────────────────────

    handlePortOfLoadingFocus(event) {
        event.stopPropagation();
        this.filteredPortOfLoading = [...this.portOfLoadingOptions];
        this._openDropdown('showPortOfLoadingDropdown');
    }

    handlePortOfLoadingSearch(event) {
        this.portOfLoadingDisplay = event.target.value;
        this.filteredPortOfLoading = this._filterOptions(this.portOfLoadingOptions, event.target.value);
        this.showPortOfLoadingDropdown = true;
    }

    handlePortOfLoadingSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const lbl = event.currentTarget.dataset.label;
        this.portOfLoadingDisplay = lbl;
        this.samplingRec.DRC_NBC_Port_of_Loading__c = val;
        this.showPortOfLoadingDropdown = false;
    }

    // ─── Port of Discharge (Export) ───────────────────────────────────────────

    handlePortOfDischargeFocus(event) {
        event.stopPropagation();
        this.filteredPortOfDischarge = [...this.portOfDischargeOptions];
        this._openDropdown('showPortOfDischargeDropdown');
    }

    handlePortOfDischargeSearch(event) {
        this.portOfDischargeDisplay = event.target.value;
        this.filteredPortOfDischarge = this._filterOptions(this.portOfDischargeOptions, event.target.value);
        this.showPortOfDischargeDropdown = true;
    }

    handlePortOfDischargeSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const lbl = event.currentTarget.dataset.label;
        this.portOfDischargeDisplay = lbl;
        this.samplingRec.DRC_NBC_Port_Of_Discharge__c = val;
        this.showPortOfDischargeDropdown = false;
    }

    // ─── Final Destination (Export) ───────────────────────────────────────────

    handleFinalDestinationFocus(event) {
        event.stopPropagation();
        this.filteredFinalDestination = [...this.finalDestinationOptions];
        this._openDropdown('showFinalDestinationDropdown');
    }

    handleFinalDestinationSearch(event) {
        this.finalDestinationDisplay = event.target.value;
        this.filteredFinalDestination = this._filterOptions(this.finalDestinationOptions, event.target.value);
        this.showFinalDestinationDropdown = true;
    }

    handleFinalDestinationSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        const lbl = event.currentTarget.dataset.label;
        this.finalDestinationDisplay = lbl;
        this.samplingRec.DRC_NBC_Final_Destination__c = val;
        this.showFinalDestinationDropdown = false;
    }

    // ─── Order Type ───────────────────────────────────────────────────────────

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

    // ─── Bill To Contact ──────────────────────────────────────────────────────

    handleBillToContactFocus(event) {
        event.stopPropagation();
        this.filteredBillToContacts = [...this.allBillToContacts];
        this._openDropdown('showBillToContactDropdown');
    }

    handleBillToContactSearch(event) {
        const searchTerm = event.target.value.toLowerCase();
        this.billToContactName = event.target.value;
        this.filteredBillToContacts = this.allBillToContacts.filter(c =>
            c.label.toLowerCase().includes(searchTerm)
        );
        this.showBillToContactDropdown = true;
    }

    handleBillToContactSelect(event) {
        event.stopPropagation();
        this.billToContactId = event.currentTarget.dataset.id;
        this.billToContactName = event.currentTarget.dataset.name;
        this.samplingRec.BillToContactId = this.billToContactId;
        this.showBillToContactDropdown = false;
    }

    // ─── Ship To Contact ──────────────────────────────────────────────────────

    handleShipToContactFocus(event) {
        event.stopPropagation();
        this.filteredShipToContacts = [...this.allShipToContacts];
        this._openDropdown('showShipToContactDropdown');
    }

    handleShipToContactSearch(event) {
        const searchTerm = event.target.value.toLowerCase();
        this.shipToContactName = event.target.value;
        this.filteredShipToContacts = this.allShipToContacts.filter(c =>
            c.label.toLowerCase().includes(searchTerm)
        );
        this.showShipToContactDropdown = true;
    }

    handleShipToContactSelect(event) {
        event.stopPropagation();
        this.shipToContactId = event.currentTarget.dataset.id;
        this.shipToContactName = event.currentTarget.dataset.name;
        this.samplingRec.ShipToContactId = this.shipToContactId;
        this.showShipToContactDropdown = false;
    }

    // ─── Price Change ─────────────────────────────────────────────────────────

    handleFinalPriceChange(event) {
        const id = event.target.dataset.id;
        const value = parseFloat(event.target.value) || 0;
        this.orderProductsList = this.orderProductsList.map(item => {
            if (item.QuoteLineItemId === id) {
                const basePrice = parseFloat(item.OriginalUnitPrice) || 0;
                return { ...item, finalPrice: value, modifier: value - basePrice, pendingModifierInput: 0 };
            }
            return item;
        });
    }

    get todayDate() {
        const today = new Date();
        const yyyy = today.getFullYear();
        const mm = String(today.getMonth() + 1).padStart(2, '0');
        const dd = String(today.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    // ─── Load Default Values ──────────────────────────────────────────────────

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
        this.samplingRec.DRC_NBC_Payment_Term_Description__c = result.paymentTermDes;
        this.samplingRec.DRC_NBC_TCS_Amount__c = result.tcsAmount;
        this.samplingRec.DRC_NBC_IGST__c = result.igst;
        this.samplingRec.DRC_NBC_CGST__c = result.cgst;
        this.samplingRec.DRC_NBC_SGST__c = result.sgst;
        this.samplingRec.DRC_NBC_Other_Tax_Amount__c = result.otherTaxAmount;
        this.samplingRec.DRC_NBC_Inco_Terms__c = result.incoTerm;
        this.samplingRec.DRC_NBC_Type__c = result.types;
        this.samplingRec.DRC_NBC_Delivery_Terms__c = result.deliveryTerm;
        this.samplingRec.DRC_NBC_Consignee_Bank_Address__c = result.acc[0].DRC_NBC_Consignee_Bank_Address__c;
        this.samplingRec.DRC_NBC_Special_Instructions__c = result.acc[0].DRC_NBC_Special_Instructions__c;
        this.samplingRec.DRC_NBC_Consignee_Bank_Name__c = result.acc[0].DRC_NBC_Consignee_Bank_Name__c;
        this.samplingRec.DRC_NBC_Consignee_Bank_IFSC_Code__c = result.acc[0].DRC_NBC_Consignee_Bank_IFSC_Code__c;
        this.samplingRec.DRC_NBC_Consignee_Bank_Account_Number__c = result.acc[0].DRC_NBC_Consignee_Bank_Account_Number__c;

        // ── Sales Person Code from Account (pre-populate & allow change) ──────
        const accountSalesPersonCode = result.salesPersonCode || result.acc[0].SalesPerson_Code__c || '';
        this.samplingRec.DRC_NBC_SalesPerson_Code__c = accountSalesPersonCode;
        this.salesPersonCodeDisplay = accountSalesPersonCode;

        // Build salesPersonCodeOptions from Account field picklist
        // (These are loaded separately via getFieldPicklistValues if Sales Person Code
        //  is a picklist on Order; if it's hardcoded on Account we show it as-is
        //  and load order picklist for overrides. Here we seed from the SALES_PERSON_CODES constant
        //  pattern — replace with getFieldPicklistValues call if it's a picklist on Order)
        if (this.salesPersonCodeOptions.length === 0 && accountSalesPersonCode) {
            // Ensure current account value appears in dropdown even before picklist loads
            this.salesPersonCodeOptions = [{ label: accountSalesPersonCode, value: accountSalesPersonCode }];
            this.filteredSalesPersonCodes = [...this.salesPersonCodeOptions];
        }

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
        }

        this.customerContacts = result.customerContacts || [];
        this.allBillToContacts = this.customerContacts.map(c => ({ label: c.Name, value: c.Id }));
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
    }

    processAccountData(account) {
        this.accountId = account.Id;
        this.samplingRec.AccountId = account.Id;
        this.shippingAddressOptions = [];
    }

    processOrderItems(orderItems) {
        this.orderProductsList = orderItems.map((item) => {
            const basePrice = parseFloat(item.UnitPrice) || 0;
            const packingSize     = item.DRC_NBC_Packing_Size     || item.DRC_NBC_Packing_Size__c     || '';
            const packingQuantity = item.DRC_NBC_Packing_Quantity  || item.DRC_NBC_Packing_Quantity__c  || '';

            return {
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
                DRC_NBC_Packing_Size__c: packingSize,
                DRC_NBC_Packing_Quantity__c: packingQuantity
            };
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
                this.samplingRec = { ...this.samplingRec, [fieldName]: value };
            }
        } catch (error) {
            console.error('Error in handleValueChange:', error);
        }
    }

    handleFormLoad(event) {
        const record = event.detail.record;
        if (record && record.fields) {
            if (record.fields.Status && record.fields.Status.value) {
                this.samplingRec.Status = record.fields.Status.value;
            }
            if (!this.samplingRec.EffectiveDate) {
                this.samplingRec.EffectiveDate = new Date().toISOString().split('T')[0];
            }
        }
    }

    handleInputFieldChange(event) {
        const fieldName = event.currentTarget.dataset.field || event.target.fieldName;
        const newValue = event.detail.value !== undefined ? event.detail.value : event.target.value;
        if (fieldName) {
            this.samplingRec[fieldName] = newValue;
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
    }

    handleSearch(event) {
        const searchKey = event.target.value.toLowerCase();
        if (searchKey) {
            this.orderProductsList = this.originalOrderProductsList.filter(item =>
                item.Product2 && item.Product2.Name && item.Product2.Name.toLowerCase().includes(searchKey)
            );
        } else {
            this.orderProductsList = [...this.originalOrderProductsList];
        }
    }

    validateOrderData() {
        const validations = [
            { field: 'EffectiveDate', message: 'Enter Order Start Date.' },
            { field: 'EndDate', message: 'Enter Order End Date.' },
            { field: 'Pricebook2Id', message: 'Enter Price Book.' },
            { field: 'BillToContactId', message: 'Enter Bill To Contact.' },
            { field: 'ShipToContactId', message: 'Enter Ship To Contact.' },
            { field: 'DRC_NBC_Payment_Terms__c', message: 'Enter Payment Term Code.' },
            { field: 'DRC_NBC_Payment_Term_Description__c', message: 'Enter Payment Term Description.' },
            { field: 'DRC_NBC_Inco_Terms__c', message: 'Enter Inco Term.' },
            { field: 'DRC_NBC_Warehouse__c', message: 'Enter Warehouse.' },
            { field: 'DRC_NBC_SalesPerson_Code__c', message: 'Enter Sales Person Code.' },
        ];

        for (const validation of validations) {
            if (!this.samplingRec[validation.field]) {
                this.showToastMessage('Error', validation.message, 'error');
                return false;
            }
        }

        if (!this.selectedShippingId) {
            this.showToastMessage('Error', 'Enter Shipping Address.', 'error');
            return false;
        }

        const effectiveDate = new Date(this.samplingRec.EffectiveDate);
        effectiveDate.setHours(0, 0, 0, 0);
        const today = new Date();
        today.setHours(0, 0, 0, 0);

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
                this.showToastMessage('Error', 'Missing Product ID for selected products.', 'error');
                return false;
            }
            if (!item.PriceBookEntryId && !item.PricebookEntryId) {
                this.showToastMessage('Error', 'Missing Pricebook Entry for selected products.', 'error');
                return false;
            }
            const priceToCheck = parseFloat(item.finalPrice || item.UnitPrice);
            if (!priceToCheck || priceToCheck <= 0) {
                this.showToastMessage('Error', 'Enter valid Price per piece for all selected products.', 'error');
                return false;
            }
            if (!item.Quantity || item.Quantity <= 0) {
                this.showToastMessage('Error', 'Enter valid Quantity for all selected products.', 'error');
                return false;
            }
        }
        return true;
    }

    handleSave() {
        this.disabledButton = true;
        if (!this.validateOrderData()) { this.disabledButton = false; return; }
        if (!this.validateOrderProducts()) { this.disabledButton = false; return; }

        const selectedItems = this.orderProductsList.filter(item => item.Selected);
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
                DRC_NBC_Packing_Size: item.DRC_NBC_Packing_Size__c || item.DRC_NBC_Packing_Size || '',
                DRC_NBC_Packing_Quantity: item.DRC_NBC_Packing_Quantity__c || item.DRC_NBC_Packing_Quantity || ''
            };
        });

        this.samplingRec.CurrencyIsoCode = this.currencyCode;
        this.createOrder(cleanedOrderProducts);
    }

    createOrder(cleanedOrderProducts) {
        this.load = true;
        createOrderRec({
            orderObj: this.samplingRec,
            orderItems: cleanedOrderProducts,
            quoteID: this.recordId
        })
        .then(result => { this.handleOrderCreationResult(result); })
        .catch(error => {
            this.load = false;
            this.disabledButton = false;
            this.showToastMessage('Error', error.body?.message || 'Failed to create order.', 'error');
        });
    }

    handleOrderCreationResult(result) {
        this.load = false;
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
            if (response.success && response.orders && response.orders.length > 0) {
                const order = response.orders[0];
                if (!order.Id || !order.OrderNumber) throw new Error('Missing required order fields');
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
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