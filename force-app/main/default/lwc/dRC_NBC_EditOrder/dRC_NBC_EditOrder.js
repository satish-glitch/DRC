import { LightningElement, track, api, wire } from 'lwc';
import getExistingOrderLineItems from '@salesforce/apex/DRC_NBC_OrderController.getExistingOrderLineItems';
import saveOrderLineItems from '@salesforce/apex/DRC_NBC_OrderController.saveOrderLineItems';
import getContactsByAccount from '@salesforce/apex/DRC_NBC_OrderController.getContactsByAccount';
import getOrderRecord from '@salesforce/apex/DRC_NBC_OrderController.getOrderRecord';
import getAccountAddresses from '@salesforce/apex/DRC_NBC_OrderController.getAccountAddresses';
import getOpportunitiesByAccount from '@salesforce/apex/DRC_NBC_OrderController.getOpportunitiesByAccount';
import getQuotesByOpportunity from '@salesforce/apex/DRC_NBC_OrderController.getQuotesByOpportunity';
import getPicklistValues from '@salesforce/apex/DRC_NBC_OrderController.getPicklistValues';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import AddProductCSS from '@salesforce/resourceUrl/DRC_NBC_Order_Button_CSS';

export default class DRC_NBC_EditOrder extends NavigationMixin(LightningElement) {
    @track allData = [];
    @track filteredData = [];
    @api recordId;
    @track isPartiallyShipped = false;
    @track showFilterData = false;
    @track showLoading = false;
    @track orderRec = {};
    productsMasterList = [];
    filteredProductList = [];
    oliIdsToDelete = [];
    @track accountOptions = [];
    @track billToContactOptions = [];
    @track shipToContactOptions = [];
    @track opportunityOptions = [];
    @track quoteOptions = [];

    @track showRejectionReason = false;
    @track showOtherRejectionText = false;

    // Section toggles
    @track isProductOpen = true;
    @track showAddProducts = true;
    @track isOrderDetailsOpen = true;
    @track isDomesticOpen = true;
    @track isExportOpen = true;
    @track isSampleOpen = true;
    @track isProcurementOpen = true;
    @track isCustomerOpen = true;
    @track isAddressOpen = true;
    @track isConsigneeBankOpen = true;

    // Order type flags
    @track isDomestic = false;
    @track isExport = false;
    @track isSample = false;
    @track isSamplePaid = false;

    @track recordTypeName = '';

    // Customer details
    @track billToAccountId = '';
    @track billToAccountName = '';
    @track shipToAccountId = '';
    @track shipToAccountName = '';
    @track billToContactId = '';
    @track billToContactName = '';
    @track shipToContactId = '';
    @track shipToContactName = '';
    @track sameAsBillTo = false;

    // Contact search
    @track allBillToContacts = [];
    @track allShipToContacts = [];
    @track filteredBillToContacts = [];
    @track filteredShipToContacts = [];
    @track showBillToContactDropdown = false;
    @track showShipToContactDropdown = false;

    // Opportunity / Quote
    @track opportunityName = '';
    @track quoteName = '';
    @track allOpportunities = [];
    @track allQuotes = [];
    @track filteredOpportunities = [];
    @track filteredQuotes = [];
    @track showOpportunityDropdown = false;
    @track showQuoteDropdown = false;
    @track isQuoteDisabled = true;

    // Address
    @track billToAddressFormatted = '';
    @track shipToAddressOptions = [];
    @track selectedShipToAddressId = '';

    // ── Searchable picklist fields ─────────────────────────────────────────────
    // Transport Agent (Domestic)
    @track allTransportAgentOptions = [];
    @track filteredTransportAgentOptions = [];
    @track showTransportAgentDropdown = false;
    @track transportAgentName = '';

    // Port of Loading (Export)
    @track allPortOfLoadingOptions = [];
    @track filteredPortOfLoadingOptions = [];
    @track showPortOfLoadingDropdown = false;
    @track portOfLoadingName = '';

    // Port of Discharge (Export)
    @track allPortOfDischargeOptions = [];
    @track filteredPortOfDischargeOptions = [];
    @track showPortOfDischargeDropdown = false;
    @track portOfDischargeName = '';

    // Final Destination (Export)
    @track allFinalDestinationOptions = [];
    @track filteredFinalDestinationOptions = [];
    @track showFinalDestinationDropdown = false;
    @track finalDestinationName = '';

    // Sales Person Code — loaded from Apex picklist
    @track salesPersonCodeOptions = [];

    // Packing details map: Product2Id → List of { packingSize, packingQuantity }
    packingDetailsMap = {};

    // ─── Wire / Init ─────────────────────────────────────────────────────────

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            let state = currentPageReference.state;
            if (state.recordId) {
                this.recordId = state.recordId;
            } else if (state.inContextOfRef) {
                try {
                    let context = JSON.parse(window.atob(state.inContextOfRef));
                    this.recordId = context.attributes.recordId;
                } catch (error) {
                    console.error('Error decoding inContextOfRef:', error);
                }
            }
            if (this.recordId) {
                this.fetchPicklistValues();
                this.fetchOrderDetails();
                this.fetchOrderLineItems();
            }
        }
    }

    connectedCallback() {
        this.addCustomCss();
        document.addEventListener('click', this.handleDocumentClick.bind(this));
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleDocumentClick.bind(this));
    }

    handleDocumentClick(event) {
        const closeIfOutside = (selector, prop) => {
            const el = this.template.querySelector(selector);
            if (el && !el.contains(event.target)) this[prop] = false;
        };
        closeIfOutside('#billToContact',          'showBillToContactDropdown');
        closeIfOutside('#shipToContact',          'showShipToContactDropdown');
        closeIfOutside('#opportunitySearch',      'showOpportunityDropdown');
        closeIfOutside('#quoteSearch',            'showQuoteDropdown');
        closeIfOutside('#transportAgentSearch',   'showTransportAgentDropdown');
        closeIfOutside('#portOfLoadingSearch',    'showPortOfLoadingDropdown');
        closeIfOutside('#portOfDischargeSearch',  'showPortOfDischargeDropdown');
        closeIfOutside('#finalDestinationSearch', 'showFinalDestinationDropdown');
    }

    addCustomCss() { loadStyle(this, AddProductCSS); }

    // ─── Picklist fetch ───────────────────────────────────────────────────────

    fetchPicklistValues() {
        getPicklistValues()
            .then(result => {
                if (result.DRC_NBC_Transport_Agent__c) {
                    this.allTransportAgentOptions      = result.DRC_NBC_Transport_Agent__c.map(v => ({ label: v, value: v }));
                    this.filteredTransportAgentOptions = [...this.allTransportAgentOptions];
                }
                if (result.DRC_NBC_Port_of_Loading__c) {
                    this.allPortOfLoadingOptions      = result.DRC_NBC_Port_of_Loading__c.map(v => ({ label: v, value: v }));
                    this.filteredPortOfLoadingOptions = [...this.allPortOfLoadingOptions];
                }
                if (result.DRC_NBC_Port_Of_Discharge__c) {
                    this.allPortOfDischargeOptions      = result.DRC_NBC_Port_Of_Discharge__c.map(v => ({ label: v, value: v }));
                    this.filteredPortOfDischargeOptions = [...this.allPortOfDischargeOptions];
                }
                if (result.DRC_NBC_Final_Destination__c) {
                    this.allFinalDestinationOptions      = result.DRC_NBC_Final_Destination__c.map(v => ({ label: v, value: v }));
                    this.filteredFinalDestinationOptions = [...this.allFinalDestinationOptions];
                }
                if (result.DRC_NBC_SalesPerson_Code__c) {
                    this.salesPersonCodeOptions = result.DRC_NBC_SalesPerson_Code__c.map(v => ({ label: v, value: v }));
                }
            })
            .catch(() => {
                this.showToastEvent('Error', 'Failed to load picklist values', 'error');
            });
    }

    // ─── Transport Agent handlers ─────────────────────────────────────────────

    handleTransportAgentFocus(event) {
        event.stopPropagation();
        this.filteredTransportAgentOptions = [...this.allTransportAgentOptions];
        this.showTransportAgentDropdown    = true;
    }
    handleTransportAgentSearch(event) {
        const term = event.target.value.toLowerCase();
        this.transportAgentName = event.target.value;
        this.filteredTransportAgentOptions = term.length === 0
            ? [...this.allTransportAgentOptions]
            : this.allTransportAgentOptions.filter(o => o.label.toLowerCase().includes(term));
        this.showTransportAgentDropdown = true;
    }
    handleTransportAgentSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        this.transportAgentName = val;
        this.orderRec = { ...this.orderRec, DRC_NBC_Transport_Agent__c: val };
        this.showTransportAgentDropdown = false;
    }

    // ─── Port of Loading handlers ─────────────────────────────────────────────

    handlePortOfLoadingFocus(event) {
        event.stopPropagation();
        this.filteredPortOfLoadingOptions = [...this.allPortOfLoadingOptions];
        this.showPortOfLoadingDropdown    = true;
    }
    handlePortOfLoadingSearch(event) {
        const term = event.target.value.toLowerCase();
        this.portOfLoadingName = event.target.value;
        this.filteredPortOfLoadingOptions = term.length === 0
            ? [...this.allPortOfLoadingOptions]
            : this.allPortOfLoadingOptions.filter(o => o.label.toLowerCase().includes(term));
        this.showPortOfLoadingDropdown = true;
    }
    handlePortOfLoadingSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        this.portOfLoadingName = val;
        this.orderRec = { ...this.orderRec, DRC_NBC_Port_of_Loading__c: val };
        this.showPortOfLoadingDropdown = false;
    }

    // ─── Port of Discharge handlers ───────────────────────────────────────────

    handlePortOfDischargeFocus(event) {
        event.stopPropagation();
        this.filteredPortOfDischargeOptions = [...this.allPortOfDischargeOptions];
        this.showPortOfDischargeDropdown    = true;
    }
    handlePortOfDischargeSearch(event) {
        const term = event.target.value.toLowerCase();
        this.portOfDischargeName = event.target.value;
        this.filteredPortOfDischargeOptions = term.length === 0
            ? [...this.allPortOfDischargeOptions]
            : this.allPortOfDischargeOptions.filter(o => o.label.toLowerCase().includes(term));
        this.showPortOfDischargeDropdown = true;
    }
    handlePortOfDischargeSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        this.portOfDischargeName = val;
        this.orderRec = { ...this.orderRec, DRC_NBC_Port_Of_Discharge__c: val };
        this.showPortOfDischargeDropdown = false;
    }

    // ─── Final Destination handlers ───────────────────────────────────────────

    handleFinalDestinationFocus(event) {
        event.stopPropagation();
        this.filteredFinalDestinationOptions = [...this.allFinalDestinationOptions];
        this.showFinalDestinationDropdown    = true;
    }
    handleFinalDestinationSearch(event) {
        const term = event.target.value.toLowerCase();
        this.finalDestinationName = event.target.value;
        this.filteredFinalDestinationOptions = term.length === 0
            ? [...this.allFinalDestinationOptions]
            : this.allFinalDestinationOptions.filter(o => o.label.toLowerCase().includes(term));
        this.showFinalDestinationDropdown = true;
    }
    handleFinalDestinationSelect(event) {
        event.stopPropagation();
        const val = event.currentTarget.dataset.value;
        this.finalDestinationName = val;
        this.orderRec = { ...this.orderRec, DRC_NBC_Final_Destination__c: val };
        this.showFinalDestinationDropdown = false;
    }

    // ─── Section toggles ──────────────────────────────────────────────────────

    toggleOrderDetails()  { this.isOrderDetailsOpen  = !this.isOrderDetailsOpen;  }
    toggleDomestic()      { this.isDomesticOpen       = !this.isDomesticOpen;       }
    toggleExport()        { this.isExportOpen         = !this.isExportOpen;         }
    toggleSample()        { this.isSampleOpen         = !this.isSampleOpen;         }
    toggleProcurement()   { this.isProcurementOpen    = !this.isProcurementOpen;    }
    toggleCustomer()      { this.isCustomerOpen       = !this.isCustomerOpen;       }
    toggleAddress()       { this.isAddressOpen        = !this.isAddressOpen;        }
    toggleProduct()       { this.isProductOpen        = !this.isProductOpen;        }
    toggleConsigneeBank() { this.isConsigneeBankOpen  = !this.isConsigneeBankOpen;  }

    // ─── Getters ──────────────────────────────────────────────────────────────

    get getConsigneeBankClass() { return `slds-section slds-m-top_medium ${this.isConsigneeBankOpen ? 'slds-is-open' : ''}`; }
    get getConsigneeBankIcon()  { return this.isConsigneeBankOpen  ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getOrderDetailsClass()  { return `slds-section ${this.isOrderDetailsOpen   ? 'slds-is-open' : ''}`; }
    get getDomesticClass()      { return `slds-section slds-m-top_medium ${this.isDomesticOpen    ? 'slds-is-open' : ''}`; }
    get getExportClass()        { return `slds-section slds-m-top_medium ${this.isExportOpen      ? 'slds-is-open' : ''}`; }
    get getSampleClass()        { return `slds-section slds-m-top_medium ${this.isSampleOpen      ? 'slds-is-open' : ''}`; }
    get getProcurementClass()   { return `slds-section slds-m-top_medium ${this.isProcurementOpen ? 'slds-is-open' : ''}`; }
    get getCustomerClass()      { return `slds-section slds-m-top_medium ${this.isCustomerOpen    ? 'slds-is-open' : ''}`; }
    get getAddressClass()       { return `slds-section slds-m-top_medium ${this.isAddressOpen     ? 'slds-is-open' : ''}`; }
    get getProductClass()       { return `slds-section slds-m-top_medium ${this.isProductOpen     ? 'slds-is-open' : ''}`; }
    get getOrderDetailsIcon()   { return this.isOrderDetailsOpen  ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getDomesticIcon()       { return this.isDomesticOpen      ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getExportIcon()         { return this.isExportOpen        ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getSampleIcon()         { return this.isSampleOpen        ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getProcurementIcon()    { return this.isProcurementOpen   ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getCustomerIcon()       { return this.isCustomerOpen      ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getAddressIcon()        { return this.isAddressOpen       ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getProductIcon()        { return this.isProductOpen       ? 'utility:chevrondown' : 'utility:chevronright'; }

    get hasProducts()           { return this.filteredData && this.filteredData.length > 0; }
    get showFrightChargeFields() {
        return this.isExport && (
            this.orderRec?.Fright_Required__c === true ||
            this.orderRec?.Fright_Required__c === 'true'
        );
    }

    // ─── Sales Person Code ────────────────────────────────────────────────────

    handleSalesPersonCodeChange(event) {
        this.orderRec = { ...this.orderRec, DRC_NBC_SalesPerson_Code__c: event.detail.value };
    }

    // ─── Packing helpers ──────────────────────────────────────────────────────

    buildPackingSizeOptions(packingDetailsList) {
        if (!packingDetailsList || packingDetailsList.length === 0) return [];
        return packingDetailsList.map(pd => ({ label: pd.packingSize || '', value: pd.packingSize || '' }));
    }

    getPackingDetailsForProduct(product2Id) {
        if (!product2Id || !this.packingDetailsMap) return [];
        return this.packingDetailsMap[product2Id] || [];
    }

    /**
     * Validates that the entered quantity is a positive multiple of the packing quantity.
     * Skipped entirely for Sample orders (isSample = true).
     * Skipped when no packing size is selected or packing quantity is zero/blank.
     * Returns an error string, or null if valid.
     */
    _validateQuantityMultiple(rowData) {
        if (this.isSample) return null;

        const rawPkgQty = parseFloat(rowData.rawPackingQuantity) || 0;

        if (rawPkgQty <= 0 || !rowData.selectedPackingSize) return null;

        const qty = parseFloat(rowData.Quantity) || 0;

        if (qty <= 0) return null;

        if (qty % rawPkgQty !== 0) {
            return `Quantity must be a multiple of ${rawPkgQty}. Allowed: ${rawPkgQty}, ${rawPkgQty * 2}, ${rawPkgQty * 3}, …`;
        }

        return null;
    }

    // ─── Order data fetching ──────────────────────────────────────────────────

    fetchOrderDetails() {
        getOrderRecord({ orderId: this.recordId })
            .then(result => {
                this.orderRec = {
                    ...result,
                    DRC_NBC_SalesPerson_Code__c: result.DRC_NBC_SalesPerson_Code__c || ''
                };
                this.isPartiallyShipped = result.DRC_NBC_Order_PartiallyShipped__c === true;

                if (result.DRC_NBC_Type__c === 'Domestic') {
                    this.isDomestic = true;
                    this.isExport   = false;
                } else if (result.DRC_NBC_Type__c === 'Export') {
                    this.isDomestic = false;
                    this.isExport   = true;
                } else if (result.Type === 'Sample Order') {
                    this.isSample   = true;
                    if (result.DRC_NBC_Sample_Type__c === 'Paid Sample') this.isSamplePaid = true;
                    this.isDomestic = false;
                    this.isExport   = false;
                }

                this.billToContactId   = result.BillToContactId          || '';
                this.billToContactName = result.BillToContact?.Name      || '';
                this.billToAccountId   = result.BillToContact?.AccountId || '';
                this.billToAccountName = result.BillToContact?.Account?.Name || '';
                this.shipToContactId   = result.ShipToContactId          || '';
                this.shipToContactName = result.ShipToContact?.Name      || '';
                this.shipToAccountId   = result.ShipToContact?.AccountId || '';
                this.shipToAccountName = result.ShipToContact?.Account?.Name || '';
                this.accountOptions    = [{ label: this.billToAccountName, value: this.billToAccountId }];
                this.opportunityName   = result.Opportunity?.Name || '';
                this.quoteName         = result.Quote?.Name       || '';

                if (result.Opportunity?.CurrencyIsoCode && !this.orderRec.CurrencyIsoCode) {
                    this.orderRec.CurrencyIsoCode = result.Opportunity.CurrencyIsoCode;
                }

                this.transportAgentName   = result.DRC_NBC_Transport_Agent__c   || '';
                this.portOfLoadingName    = result.DRC_NBC_Port_of_Loading__c   || '';
                this.portOfDischargeName  = result.DRC_NBC_Port_Of_Discharge__c || '';
                this.finalDestinationName = result.DRC_NBC_Final_Destination__c || '';

                this.fetchContacts(this.billToAccountId);
                this.billToAddressFormatted = this.formatAddress({
                    street: result.BillingStreet, city: result.BillingCity,
                    state: result.BillingState, postalCode: result.BillingPostalCode,
                    country: result.BillingCountry
                });
                this.selectedShipToAddressId = result.DRC_NBC_Shipping_Address__c || '';
                if (this.shipToAccountId) this.fetchShipToAddresses();
                if (this.billToAccountId) this.fetchOpportunities(this.billToAccountId);
                this.updateRejectionVisibility();
            })
            .catch(error => {
                this.showToastEvent('Error', 'Failed to load order details: ' + (error.body?.message || error.message), 'error');
            });
    }

    updateRejectionVisibility() {
        this.showRejectionReason    = this.orderRec.Status === 'Rejected';
        this.showOtherRejectionText = this.showRejectionReason &&
                                      this.orderRec.DRC_NBC_Reject_Reason_Text__c === 'Other';
    }

    formatAddress(addr) {
        const parts = [addr.street, addr.city, addr.state, addr.postalCode, addr.country].filter(p => p);
        return parts.join(', ') || 'No address available';
    }

    fetchShipToAddresses() {
        if (!this.shipToAccountId) return;
        getAccountAddresses({ accountId: this.shipToAccountId })
            .then(result => { this.shipToAddressOptions = result || []; })
            .catch(() => { this.showToastEvent('Error', 'Failed to load ship to addresses', 'error'); });
    }

    fetchContacts(accountId) {
        if (!accountId) return;
        getContactsByAccount({ accountId })
            .then(result => {
                this.allBillToContacts      = result.map(c => ({ label: c.Name, value: c.Id }));
                this.allShipToContacts      = [...this.allBillToContacts];
                this.filteredBillToContacts = [...this.allBillToContacts];
                this.filteredShipToContacts = [...this.allShipToContacts];
                this.billToContactOptions   = [...this.allBillToContacts];
                this.shipToContactOptions   = [...this.allShipToContacts];
            })
            .catch(() => { this.showToastEvent('Error', 'Failed to fetch contacts for account', 'error'); });
    }

    fetchOrderLineItems() {
        getExistingOrderLineItems({ orderId: this.recordId })
            .then(data => {
                this.productsMasterList  = data.productsList;
                this.filteredProductList = [...data.productsList];
                this.packingDetailsMap   = {};
                const packingList        = data.packingDetailsList || [];
                packingList.forEach(item => {
                    if (item.product2Id) this.packingDetailsMap[item.product2Id] = item.packingDetails || [];
                });
                if (data.olis.length > 0) {
                    this.result = data;
                    this.getOrganizedData();
                } else {
                    let newRow        = this.getBaseRecordData().olis;
                    newRow.OrderId    = this.recordId;
                    newRow.showSearch = true;
                    this.filteredData = [{ recordData: newRow }];
                }
                this.showFilterData = true;
            })
            .catch(error => {
                this.showToastEvent("Error", error.body?.message || error.message, 'error');
            });
    }

    getOrganizedData() {
        const data = this.result.olis;
        for (let item of data) {
            let record               = this.getBaseRecordData().olis;
            const originalUnitPrice  = item.UnitPrice || 0;
            const savedModifiedPrice = item.UnitPrice  || originalUnitPrice;
            const packingDetails     = this.getPackingDetailsForProduct(item.Product2Id);
            const packingSizeOptions = this.buildPackingSizeOptions(packingDetails);
            const savedPackingSize   = item.DRC_NBC_Packing_Size__c    || '';
            const savedPackingQty    = item.DRC_NBC_Packing_Quantity__c || '';
            let rawPackingQuantity   = '';
            if (savedPackingSize) {
                const matchedDetail = packingDetails.find(pd => pd.packingSize === savedPackingSize);
                rawPackingQuantity  = matchedDetail ? (matchedDetail.packingQuantity || '') : '';
            }
            Object.assign(record, {
                Id:                      item.Id,
                Name:                    item.Product2?.Name || '',
                PricebookEntryId:        item.PricebookEntryId,
                Description:             item.Description || '',
                Product2Id:              item.Product2Id,
                Quantity:                item.Quantity || 1,
                UnitPrice:               originalUnitPrice,
                OriginalUnitPrice:       originalUnitPrice,
                DRC_NBC_FG_Code__c:      item.Product2?.DRC_NBC_FG_Code__c      || '-',
                DRC_NBC_HSN_SAC_Code__c: item.Product2?.DRC_NBC_HSN_SAC_Code__c || '-',
                UOM:                     item.Product2?.QuantityUnitOfMeasure    || 'KGS',
                // FIX: read Mark & Nos and Hazardous from OrderItem fields (not Product2)
                // for existing rows; use === true to correctly handle false booleans
                DRC_NBC_MARKS_NOS__c:    item.DRC_NBC_MARKS_NOS__c || '',
                DRC_NBC_Hazardous__c:    item.DRC_NBC_Hazardous__c === true,
                showSearch:              false,
                modifiedPrice:           savedModifiedPrice,
                packingDetails:          packingDetails,
                packingSizeOptions:      packingSizeOptions,
                selectedPackingSize:     savedPackingSize,
                rawPackingQuantity:      rawPackingQuantity,
                packingQuantity:         rawPackingQuantity || savedPackingQty,
                quantityError:           ''
            });
            this.allData.push({ recordData: record });
        }
        this.filteredData = [...this.allData];
    }

    // ─── Contact handlers ─────────────────────────────────────────────────────

    handleBillToContactFocus(event) {
        event.stopPropagation();
        this.filteredBillToContacts    = [...this.allBillToContacts];
        this.showBillToContactDropdown = true;
        this.showShipToContactDropdown = false;
    }
    handleBillToContactSearch(event) {
        const term = event.target.value.toLowerCase();
        this.billToContactName = event.target.value;
        this.filteredBillToContacts = term.length === 0
            ? [...this.allBillToContacts]
            : this.allBillToContacts.filter(c => c.label.toLowerCase().includes(term));
        this.showBillToContactDropdown = true;
    }
    handleBillToContactSelect(event) {
        event.stopPropagation();
        this.billToContactId   = event.currentTarget.dataset.id;
        this.billToContactName = event.currentTarget.dataset.name;
        this.showBillToContactDropdown = false;
        this.handleFieldChange({ target: { fieldName: 'BillToContactId' }, detail: { value: this.billToContactId } });
    }
    handleShipToContactFocus(event) {
        event.stopPropagation();
        this.filteredShipToContacts    = [...this.allShipToContacts];
        this.showShipToContactDropdown = true;
        this.showBillToContactDropdown = false;
    }
    handleShipToContactSearch(event) {
        const term = event.target.value.toLowerCase();
        this.shipToContactName = event.target.value;
        this.filteredShipToContacts = term.length === 0
            ? [...this.allShipToContacts]
            : this.allShipToContacts.filter(c => c.label.toLowerCase().includes(term));
        this.showShipToContactDropdown = true;
    }
    handleShipToContactSelect(event) {
        event.stopPropagation();
        this.shipToContactId   = event.currentTarget.dataset.id;
        this.shipToContactName = event.currentTarget.dataset.name;
        this.showShipToContactDropdown = false;
        this.handleFieldChange({ target: { fieldName: 'ShipToContactId' }, detail: { value: this.shipToContactId } });
    }

    handleAddressChange(event) { this.selectedShipToAddressId = event.detail.value; }

    // ─── Opportunity / Quote handlers ─────────────────────────────────────────

    fetchOpportunities(accountId) {
        getOpportunitiesByAccount({ accountId })
            .then(result => {
                this.allOpportunities      = result.map(opp => ({ label: opp.Name, value: opp.Id, currencyIsoCode: opp.CurrencyIsoCode }));
                this.filteredOpportunities = [...this.allOpportunities];
                this.opportunityOptions    = [...this.allOpportunities];
                if (this.orderRec.OpportunityId) {
                    const sel = this.allOpportunities.find(o => o.value === this.orderRec.OpportunityId);
                    if (sel) {
                        this.opportunityName = sel.label;
                        if (sel.currencyIsoCode) this.orderRec = { ...this.orderRec, CurrencyIsoCode: sel.currencyIsoCode };
                    }
                    this.fetchQuotes(this.orderRec.OpportunityId);
                }
            })
            .catch(() => { this.showToastEvent('Error', 'Failed to fetch opportunities', 'error'); });
    }

    fetchQuotes(opportunityId) {
        getQuotesByOpportunity({ opportunityId })
            .then(result => {
                this.allQuotes       = result.map(q => ({ label: q.Name, value: q.Id }));
                this.filteredQuotes  = [...this.allQuotes];
                this.quoteOptions    = [...this.allQuotes];
                this.isQuoteDisabled = false;
                if (this.orderRec.QuoteId) {
                    const sel = this.allQuotes.find(q => q.value === this.orderRec.QuoteId);
                    if (sel) this.quoteName = sel.label;
                }
            })
            .catch(() => { this.showToastEvent('Error', 'Failed to fetch quotes', 'error'); });
    }

    handleOpportunityFocus(event) {
        event.stopPropagation();
        this.filteredOpportunities     = [...this.allOpportunities];
        this.showOpportunityDropdown   = true;
        this.showQuoteDropdown         = false;
        this.showBillToContactDropdown = false;
        this.showShipToContactDropdown = false;
    }
    handleOpportunitySearch(event) {
        const term = event.target.value.toLowerCase();
        this.opportunityName = event.target.value;
        this.filteredOpportunities = term.length === 0
            ? [...this.allOpportunities]
            : this.allOpportunities.filter(o => o.label.toLowerCase().includes(term));
        this.showOpportunityDropdown = true;
    }
    handleOpportunitySelect(event) {
        event.stopPropagation();
        const selectedId   = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;
        this.orderRec.OpportunityId  = selectedId;
        this.opportunityName         = selectedName;
        this.showOpportunityDropdown = false;
        const sel = this.allOpportunities.find(o => o.value === selectedId);
        if (sel && sel.currencyIsoCode) this.orderRec = { ...this.orderRec, CurrencyIsoCode: sel.currencyIsoCode };
        this.orderRec.QuoteId = ''; this.quoteName = ''; this.allQuotes = []; this.filteredQuotes = []; this.isQuoteDisabled = true;
        this.handleFieldChange({ target: { fieldName: 'OpportunityId' }, detail: { value: selectedId } });
        if (selectedId) this.fetchQuotes(selectedId);
    }
    handleQuoteFocus(event) {
        event.stopPropagation();
        if (!this.isQuoteDisabled) {
            this.filteredQuotes            = [...this.allQuotes];
            this.showQuoteDropdown         = true;
            this.showOpportunityDropdown   = false;
            this.showBillToContactDropdown = false;
            this.showShipToContactDropdown = false;
        }
    }
    handleQuoteSearch(event) {
        const term = event.target.value.toLowerCase();
        this.quoteName = event.target.value;
        this.filteredQuotes = term.length === 0
            ? [...this.allQuotes]
            : this.allQuotes.filter(q => q.label.toLowerCase().includes(term));
        this.showQuoteDropdown = true;
    }
    handleQuoteSelect(event) {
        event.stopPropagation();
        const selectedId   = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;
        this.orderRec.QuoteId = selectedId;
        this.quoteName        = selectedName;
        this.showQuoteDropdown = false;
        this.handleFieldChange({ target: { fieldName: 'QuoteId' }, detail: { value: selectedId } });
    }

    // ─── Generic field change ─────────────────────────────────────────────────

    handleFieldChange(event) {
        const fieldName = event.target.fieldName || event.target.name || event.target.dataset.field;
        const value     = event.detail?.value    || event.target.value;
        if (fieldName) {
            this.orderRec = { ...this.orderRec, [fieldName]: value };
            if (fieldName === 'DRC_NBC_Type__c')           { this.isDomestic = value === 'Domestic'; this.isExport = value === 'Export'; }
            if (fieldName === 'DRC_NBC_Sample_Type__c')    { this.isSamplePaid = (value === 'Paid Sample'); }
            if (fieldName === 'Status' || fieldName === 'DRC_NBC_Reject_Reason_Text__c') { this.updateRejectionVisibility(); }
            if (fieldName === 'CurrencyIsoCode')           { this.currencyCode = value; }
        }
    }

    // ─── Product table handlers ───────────────────────────────────────────────

    handleValueChange(event) {
        const index = parseInt(event.target.dataset.index, 10);
        const field = event.target.name;

        const value = event.target.type === 'checkbox'
            ? event.target.checked
            : event.target.value;

        this.filteredData[index].recordData[field] = value;

        if (field === 'ProductName' && value.length >= 2) {
            const selectedProduct2Ids = this.filteredData
                .filter((_, i) => i !== index)
                .map(row => row.recordData.Product2Id)
                .filter(Boolean)
                .map(id => String(id));

            const matches = this.productsMasterList.filter(product => {
                const product2Id  = String(product.Product2Id || product.Product2?.Id || '');
                const nameMatch   = product.Product2.Name.toLowerCase().includes(value.toLowerCase());
                const notSelected = !selectedProduct2Ids.includes(product2Id);
                return nameMatch && notSelected;
            });

            this.filteredData[index].recordData.searchResults  = matches;
            this.filteredData[index].recordData.noResultsFound = matches.length === 0;
        } else if (field === 'ProductName') {
            this.filteredData[index].recordData.searchResults  = [];
            this.filteredData[index].recordData.noResultsFound = false;
        }

        if (field === 'Quantity') {
            this.handleQuantityChange(event);
        }

        this.filteredData = [...this.filteredData];
    }

    handlePackingSizeChange(event) {
        const index        = parseInt(event.target.dataset.index);
        const selectedSize = event.detail.value;
        this.filteredData[index].recordData.selectedPackingSize = selectedSize;
        const packingDetails = this.filteredData[index].recordData.packingDetails || [];
        const matchedDetail  = packingDetails.find(pd => pd.packingSize === selectedSize);
        if (matchedDetail && matchedDetail.packingQuantity != null && matchedDetail.packingQuantity !== '') {
            this.filteredData[index].recordData.rawPackingQuantity = String(matchedDetail.packingQuantity);
            this.filteredData[index].recordData.packingQuantity    = String(matchedDetail.packingQuantity);
        } else {
            this.filteredData[index].recordData.rawPackingQuantity = '';
            this.filteredData[index].recordData.packingQuantity    = '';
        }
        const qtyError = this._validateQuantityMultiple(this.filteredData[index].recordData);
        this.filteredData[index].recordData.quantityError = qtyError || '';
        this.filteredData = [...this.filteredData];
    }

    handleQuantityChange(event) {
        const index    = parseInt(event.target.dataset.index);
        const quantity = parseFloat(event.target.value) || 0;
        this.filteredData[index].recordData.Quantity = quantity;

        const qtyError = this._validateQuantityMultiple(this.filteredData[index].recordData);
        this.filteredData[index].recordData.quantityError = qtyError || '';

        this.updateTotal(index);
        this.filteredData = [...this.filteredData];
    }

    handleAddRow() {
        let newRow            = this.getBaseRecordData().olis;
        newRow.Id             = null;
        newRow.showSearch     = true;
        newRow.searchResults  = [];
        newRow.noResultsFound = false;
        this.filteredData     = [...this.filteredData, { recordData: newRow }];
        this.showAddProducts  = false;
    }

    handleRemoveRow(event) {
        const index = event.target.dataset.index;
        const id    = event.target.dataset.id;
        if (id) { this.oliIdsToDelete.push(id); }
        this.filteredData.splice(index, 1);
        if (this.filteredData.length === 0) { this.showAddProducts = true; }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
        this.dispatchEvent(new CustomEvent('cancel', { bubbles: true, composed: true }));
    }

    handleModifiedPriceChange(event) {
        const index = parseInt(event.target.dataset.index);
        const value = parseFloat(event.target.value) || 0;
        let record  = this.filteredData[index].recordData;
        record.modifiedPrice = value;
        this.updateTotal(index);
        this.filteredData = [...this.filteredData];
    }

    handleProductSelect(event) {
        const index           = parseInt(event.target.dataset.index);
        const selectedId      = event.target.dataset.id;
        const selectedProduct = this.productsMasterList.find(p => p.Id === selectedId);
        if (selectedProduct) {
            const unitPrice          = selectedProduct.UnitPrice || 0;
            const product2Id         = selectedProduct.Product2Id || selectedProduct.Product2?.Id;
            const packingDetails     = this.getPackingDetailsForProduct(product2Id);
            const packingSizeOptions = this.buildPackingSizeOptions(packingDetails);
            this.filteredData[index].recordData = {
                ...this.filteredData[index].recordData,
                showSearch:              false,
                Name:                    selectedProduct.Product2.Name,
                Product2Id:              product2Id,
                Description:             selectedProduct.Product2.Description,
                UnitPrice:               unitPrice,
                OriginalUnitPrice:       unitPrice,
                DRC_NBC_HSN_SAC_Code__c: selectedProduct.Product2.DRC_NBC_HSN_SAC_Code__c,
                DRC_NBC_FG_Code__c:      selectedProduct.Product2.DRC_NBC_FG_Code__c,
                // FIX: for NEW products, seed Mark & Nos and Hazardous from Product2
                // so defaults are pre-filled but remain editable by the user
                DRC_NBC_MARKS_NOS__c:    selectedProduct.Product2.DRC_NBC_MARKS_NOS__c || '',
                DRC_NBC_Hazardous__c:    selectedProduct.Product2.DRC_NBC_Hazardous__c,
                PricebookEntryId:        selectedProduct.Id,
                UOM:                     selectedProduct.Product2.QuantityUnitOfMeasure,
                modifiedPrice:           unitPrice,
                packingDetails,
                packingSizeOptions,
                selectedPackingSize:     '',
                rawPackingQuantity:      '',
                packingQuantity:         '',
                quantityError:           '',
                searchResults:           [],
                noResultsFound:          false
            };
            this.updateTotal(index);
            this.filteredData = [...this.filteredData];
        }
    }

    // ─── Save ─────────────────────────────────────────────────────────────────

    handleSave() {
        this.showLoading = true;
        let isValid  = true;
        let rowCount = 0;

        for (let record of this.filteredData) {
            rowCount++;
            const row = record.recordData;

            if (!row.ProductName && !row.Product2Id) {
                this.showToastEvent("Error", `Product Name is required for row ${rowCount}`, 'error');
                isValid = false;
            }
            if (!row.Quantity) {
                this.showToastEvent("Error", `Quantity is required for row ${rowCount}`, 'error');
                isValid = false;
            }

            if (!this.isSample) {
                const qtyError = this._validateQuantityMultiple(row);
                if (qtyError) {
                    record.recordData.quantityError = qtyError;
                    this.showToastEvent("Error", `Row ${rowCount}: ${qtyError}`, 'error');
                    isValid = false;
                }
            }
        }

        this.filteredData = [...this.filteredData];

        if (this.isPartiallyShipped)          { this.showToastEvent('Error', 'Order cannot be modified because the order is partially shipped.', 'error'); isValid = false; }
        if (!this.orderRec?.EffectiveDate)    { this.showToastEvent("Error", "Effective Date is required", "error"); isValid = false; }
        if (!this.orderRec?.EndDate)          { this.showToastEvent("Error", "End Date is required", "error"); isValid = false; }
        if (!this.orderRec?.DRC_NBC_Warehouse__c)         { this.showToastEvent("Error", "Warehouse is required", "error"); isValid = false; }
        if (!this.orderRec?.DRC_NBC_SalesPerson_Code__c)  { this.showToastEvent("Error", "Sales Person Code is required", "error"); isValid = false; }
        if (!this.orderRec?.DRC_NBC_Part_Shipment__c)     { this.showToastEvent("Error", "Part Shipment is required", "error");  isValid = false; }
        if (!this.orderRec?.DRC_NBC_Trans_Shipment__c)    { this.showToastEvent("Error", "Trans Shipment is required", "error"); isValid = false; }

        if (this.orderRec?.EndDate) {
            const endDate = new Date(this.orderRec.EndDate); endDate.setHours(0,0,0,0);
            const today   = new Date(); today.setHours(0,0,0,0);
            if (endDate <= today) { this.showToastEvent('Error', 'End Date must be greater than today.', 'error'); isValid = false; }
        }

        if (!this.billToContactId)         { this.showToastEvent("Error", "Bill To Contact is required",  "error"); isValid = false; }
        if (!this.shipToContactId)         { this.showToastEvent("Error", "Ship To Contact is required",  "error"); isValid = false; }
        if (!this.selectedShipToAddressId) { this.showToastEvent("Error", "Ship To Address is required",  "error"); isValid = false; }

        const dateChecks = [
            ['DRC_NBC_Expected_Delivery_Date__c', 'Expected Delivery Date'],
            ['DRC_NBC_Courier_date__c',            'Courier date'],
            ['DRC_NBC_Shipment_Date__c',           'Shipment Date'],
            ['NBC_DRC_Dispatch_Date__c',            'Dispatch Date'],
            ['PoDate',                             'PO Date']
        ];
        dateChecks.forEach(([field, label]) => {
            if (this.orderRec[field] && this.orderRec.EndDate && new Date(this.orderRec[field]) > new Date(this.orderRec.EndDate)) {
                this.showToastEvent('Error', `${label} must be less than End Date.`, 'error');
                isValid = false;
            }
        });

        if (!isValid) { this.showLoading = false; return; }

        const recordsToSave = this.filteredData.map(row => {
            const r = row.recordData;
            return {
                Id:                         r.Id || null,
                Product2Id:                 r.Product2Id,
                Quantity:                   r.Quantity,
                UnitPrice:                  parseFloat(r.modifiedPrice) || parseFloat(r.UnitPrice) || 0,
                OrderId:                    this.recordId,
                PricebookEntryId:           r.PricebookEntryId,
                Description:                r.Description,
                // Both existing and new rows always send current editable values
                DRC_NBC_MARKS_NOS__c:        r.DRC_NBC_MARKS_NOS__c || '',
                DRC_NBC_Hazardous__c:        r.DRC_NBC_Hazardous__c === true,
                DRC_NBC_Packing_Size__c:    r.selectedPackingSize || '',
                DRC_NBC_Packing_Quantity__c: r.rawPackingQuantity || ''
            };
        });

        const updatedOrder = {
            Id:               this.recordId,
            Name:             this.orderRec.Name,
            EffectiveDate:    this.orderRec.EffectiveDate,
            EndDate:          this.orderRec.EndDate,
            Description:      this.orderRec.Description,
            CurrencyIsoCode:  this.orderRec.CurrencyIsoCode,
            Status:           this.orderRec.Status,
            Type:             this.orderRec.Type,
            DRC_NBC_Type__c:  this.orderRec.DRC_NBC_Type__c,
            DRC_NBC_Payment_Terms__c:             this.orderRec.DRC_NBC_Payment_Terms__c,
            DRC_NBC_Payment_Term_Description__c:  this.orderRec.DRC_NBC_Payment_Term_Description__c,
            DRC_NBC_Reject_Reason_Text__c:        this.orderRec.DRC_NBC_Reject_Reason_Text__c,
            DRC_NBC_Other_Rejection_Reason__c:    this.orderRec.DRC_NBC_Other_Rejection_Reason__c,
            DRC_NBC_Inco_Terms__c:                this.orderRec.DRC_NBC_Inco_Terms__c,
            DRC_NBC_Warehouse__c:                 this.orderRec.DRC_NBC_Warehouse__c,
            Fright_Required__c:                   this.orderRec.Fright_Required__c,
            DRC_NBC_SalesPerson_Code__c:          this.orderRec.DRC_NBC_SalesPerson_Code__c,
            DRC_NBC_Select_Bank__c:               this.orderRec.DRC_NBC_Select_Bank__c,
            DRC_NBC_Terms_and_Conditions__c:      this.orderRec.DRC_NBC_Terms_and_Conditions__c,
            PoNumber:                             this.orderRec.PoNumber,
            Is_Domestic_Merchnat__c: this.orderRec.Is_Domestic_Merchnat__c || false,
            DRC_NBC_Other_Tax_Amount__c:          this.orderRec.DRC_NBC_Other_Tax_Amount__c,
            DRC_NBC_Consignee_Bank_Name__c:           this.orderRec.DRC_NBC_Consignee_Bank_Name__c,
            DRC_NBC_Consignee_Bank_Account_Number__c: this.orderRec.DRC_NBC_Consignee_Bank_Account_Number__c,
            DRC_NBC_Consignee_Bank_IFSC_Code__c:      this.orderRec.DRC_NBC_Consignee_Bank_IFSC_Code__c,
            DRC_NBC_Consignee_Bank_Address__c:        this.orderRec.DRC_NBC_Consignee_Bank_Address__c,
            DRC_NBC_TCS_Amount__c:                this.orderRec.DRC_NBC_TCS_Amount__c,
            PoDate:                               this.orderRec.PoDate,
            DRC_NBC_Special_Instructions__c:      this.orderRec.DRC_NBC_Special_Instructions__c,
            OpportunityId:    this.orderRec.OpportunityId,
            QuoteId:          this.orderRec.QuoteId,
            BillToContactId:  this.billToContactId,
            ShipToContactId:  this.shipToContactId,
            DRC_NBC_Shipping_Address__c: this.selectedShipToAddressId
        };

        if (this.isDomestic) {
            updatedOrder.DRC_NBC_Transporter_Name__c  = this.orderRec.DRC_NBC_Transporter_Name__c;
            updatedOrder.DRC_NBC_Transport_Agent__c   = this.orderRec.DRC_NBC_Transport_Agent__c;
            updatedOrder.DRC_NBC_Shipment_Method__c   = this.orderRec.DRC_NBC_Shipment_Method__c;
            updatedOrder.DRC_NBC_Prepayment_Method__c = this.orderRec.DRC_NBC_Prepayment_Method__c;
            updatedOrder.DRC_NBC_Shipment_Date__c     = this.orderRec.DRC_NBC_Shipment_Date__c;
            updatedOrder.DRC_NBC_Part_Shipment__c     = this.orderRec.DRC_NBC_Part_Shipment__c;
            updatedOrder.DRC_NBC_Trans_Shipment__c    = this.orderRec.DRC_NBC_Trans_Shipment__c;
        }

        if (this.isExport) {
            updatedOrder.DRC_NBC_Country_of_Origin__c            = this.orderRec.DRC_NBC_Country_of_Origin__c;
            updatedOrder.DRC_NBC_Country_of_Final_Destination__c = this.orderRec.DRC_NBC_Country_of_Final_Destination__c;
            updatedOrder.DRC_NBC_Shipment_Method__c              = this.orderRec.DRC_NBC_Shipment_Method__c;
            updatedOrder.DRC_NBC_Port_Of_Discharge__c            = this.orderRec.DRC_NBC_Port_Of_Discharge__c;
            updatedOrder.DRC_NBC_Port_of_Loading__c              = this.orderRec.DRC_NBC_Port_of_Loading__c;
            updatedOrder.DRC_NBC_Notify_Party__c                 = this.orderRec.DRC_NBC_Notify_Party__c;
            updatedOrder.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c  = this.orderRec.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c;
            updatedOrder.DRC_NBC_Prepayment_Method__c            = this.orderRec.DRC_NBC_Prepayment_Method__c;
            updatedOrder.DRC_NBC_Vessel_no_Flight_no__c          = this.orderRec.DRC_NBC_Vessel_no_Flight_no__c;
            updatedOrder.DRC_NBC_Part_Shipment__c                = this.orderRec.DRC_NBC_Part_Shipment__c;
            updatedOrder.DRC_NBC_Trans_Shipment__c               = this.orderRec.DRC_NBC_Trans_Shipment__c;
            updatedOrder.DRC_NBC_Final_Destination__c            = this.orderRec.DRC_NBC_Final_Destination__c;
            updatedOrder.DRC_NBC_Required_Documents__c           = this.orderRec.DRC_NBC_Required_Documents__c;
            updatedOrder.DRC_NBC_Fright_Charges__c               = this.orderRec.DRC_NBC_Fright_Charges__c;
            updatedOrder.DRC_NBC_Insurance__c                    = this.orderRec.DRC_NBC_Insurance__c;
            updatedOrder.DRC_NBC_Delivery_Terms__c               = this.orderRec.DRC_NBC_Delivery_Terms__c;
        }

        if (this.isSample) {
            updatedOrder.DRC_NBC_Sample_Name__c            = this.orderRec.DRC_NBC_Sample_Name__c;
            updatedOrder.DRC_NBC_Sample_Type__c            = this.orderRec.DRC_NBC_Sample_Type__c;
            updatedOrder.DRC_NBC_Courier_service__c        = this.orderRec.DRC_NBC_Courier_service__c;
            updatedOrder.DRC_NBC_Delivery_status__c        = this.orderRec.DRC_NBC_Delivery_status__c;
            updatedOrder.DRC_NBC_Courier_Number__c         = this.orderRec.DRC_NBC_Courier_Number__c;
            updatedOrder.DRC_NBC_Expected_Delivery_Date__c = this.orderRec.DRC_NBC_Expected_Delivery_Date__c;
            updatedOrder.DRC_NBC_Courier_date__c           = this.orderRec.DRC_NBC_Courier_date__c;
            updatedOrder.DRC_NBC_Sample_Shipping_Cost__c   = this.orderRec.DRC_NBC_Sample_Shipping_Cost__c;
            updatedOrder.DRC_NBC_Special_request__c        = this.orderRec.DRC_NBC_Special_request__c;
            updatedOrder.DRC_NBC_Sample_Amount__c          = this.orderRec.DRC_NBC_Sample_Amount__c;
            updatedOrder.DRC_NBC_Rejection_Reason__c       = this.orderRec.DRC_NBC_Rejection_Reason__c;
            updatedOrder.DRC_NBC_Remarks__c                = this.orderRec.DRC_NBC_Remarks__c;
            updatedOrder.DRC_NBC_Part_Shipment__c          = this.orderRec.DRC_NBC_Part_Shipment__c;
            updatedOrder.DRC_NBC_Trans_Shipment__c         = this.orderRec.DRC_NBC_Trans_Shipment__c;
            updatedOrder.Type                              = 'Sample Order';
        }

        saveOrderLineItems({ oliList: recordsToSave, oliIdsToDelete: this.oliIdsToDelete, orderData: updatedOrder })
            .then(() => {
                this.showToastEvent("Success", "Order and Line Items saved successfully", "success");
                this.showLoading = false;
                setTimeout(() => { window.location.href = '/' + this.recordId; }, 500);
            })
            .catch(error => {
                console.error('SaveOrderLineItems Error:', JSON.stringify(error, null, 2));
                let message = error?.body?.message || error?.message || 'Unknown error occurred';
                if (!message && error?.body?.pageErrors?.length > 0) message = error.body.pageErrors[0].message;
                if (!message && error?.body?.fieldErrors) {
                    const fe = Object.values(error.body.fieldErrors).flat();
                    if (fe.length > 0) message = fe[0].message;
                }
                this.showToastEvent("Error", message, "error");
                this.showLoading = false;
            });
    }

    // ─── Utilities ────────────────────────────────────────────────────────────

    showToastEvent(title, error, variant) {
        let message = typeof error === 'string' ? error : (error?.body?.message || 'Unknown error');
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getBaseRecordData() {
        return {
            olis: {
                Id: '', Name: '', PricebookEntryId: '', Description: '', Product2Id: '',
                Quantity: 1, UnitPrice: 0, OriginalUnitPrice: 0, ProductName: '',
                DRC_NBC_FG_Code__c: '', DRC_NBC_HSN_SAC_Code__c: '', UOM: '',
                DRC_NBC_MARKS_NOS__c: '', DRC_NBC_Hazardous__c: false,
                modifiedPrice: 0, totalAmount: 0, showSearch: true,
                searchResults: [], noResultsFound: false,
                packingDetails: [], packingSizeOptions: [],
                selectedPackingSize: '', rawPackingQuantity: '',
                packingQuantity: '', quantityError: ''
            }
        };
    }

    updateTotal(index) {
        let record = this.filteredData[index].recordData;
        record.totalAmount = (parseFloat(record.modifiedPrice) || 0) * (parseFloat(record.Quantity) || 0);
    }
}