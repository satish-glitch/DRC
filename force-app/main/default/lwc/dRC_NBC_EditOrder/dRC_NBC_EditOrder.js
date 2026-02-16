import { LightningElement, track, api, wire } from 'lwc';
import getExistingOrderLineItems from '@salesforce/apex/DRC_NBC_OrderController.getExistingOrderLineItems';
import saveOrderLineItems from '@salesforce/apex/DRC_NBC_OrderController.saveOrderLineItems';
import getContactsByAccount from '@salesforce/apex/DRC_NBC_OrderController.getContactsByAccount';
import getOrderRecord from '@salesforce/apex/DRC_NBC_OrderController.getOrderRecord';
import getAccountAddresses from '@salesforce/apex/DRC_NBC_OrderController.getAccountAddresses';
import getOpportunitiesByAccount from '@salesforce/apex/DRC_NBC_OrderController.getOpportunitiesByAccount';
import getQuotesByOpportunity from '@salesforce/apex/DRC_NBC_OrderController.getQuotesByOpportunity';
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

    // Contact search functionality
    @track allBillToContacts = [];
    @track allShipToContacts = [];
    @track filteredBillToContacts = [];
    @track filteredShipToContacts = [];
    @track showBillToContactDropdown = false;
    @track showShipToContactDropdown = false;
    @track opportunityName = '';
    @track quoteName = '';
    @track allOpportunities = [];
    @track allQuotes = [];
    @track filteredOpportunities = [];
    @track filteredQuotes = [];
    @track showOpportunityDropdown = false;
    @track showQuoteDropdown = false;
    @track isQuoteDisabled = true;

    // Address options
    @track billToAddressFormatted = '';
    @track shipToAddressOptions = [];
    @track selectedShipToAddressId = '';

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            let state = currentPageReference.state;
            if (state.recordId) {
                this.recordId = state.recordId;
            } 
            else if (state.inContextOfRef) {
                try {
                    let context = JSON.parse(window.atob(state.inContextOfRef));
                    this.recordId = context.attributes.recordId;
                } catch (error) {
                    console.error('Error decoding inContextOfRef:', error);
                }
            }

            if (this.recordId) {
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
        const billToInput = this.template.querySelector('#billToContact');
        const shipToInput = this.template.querySelector('#shipToContact');
        const opportunityInput = this.template.querySelector('#opportunitySearch');
        const quoteInput = this.template.querySelector('#quoteSearch');
        
        if (billToInput && !billToInput.contains(event.target)) {
            this.showBillToContactDropdown = false;
        }
        
        if (shipToInput && !shipToInput.contains(event.target)) {
            this.showShipToContactDropdown = false;
        }
        
        if (opportunityInput && !opportunityInput.contains(event.target)) {
            this.showOpportunityDropdown = false;
        }
        
        if (quoteInput && !quoteInput.contains(event.target)) {
            this.showQuoteDropdown = false;
        }
    }

    addCustomCss() {
        loadStyle(this, AddProductCSS);
    }

    toggleOrderDetails() {
        this.isOrderDetailsOpen = !this.isOrderDetailsOpen;
    }

    toggleDomestic() {
        this.isDomesticOpen = !this.isDomesticOpen;
    }

    toggleExport() {
        this.isExportOpen = !this.isExportOpen;
    }

    toggleSample() {
        this.isSampleOpen = !this.isSampleOpen;
    }

    toggleProcurement() {
        this.isProcurementOpen = !this.isProcurementOpen;
    }

    toggleCustomer() {
        this.isCustomerOpen = !this.isCustomerOpen;
    }

    toggleAddress() {
        this.isAddressOpen = !this.isAddressOpen;
    }

    isConsigneeBankOpen = true;

    toggleConsigneeBank() {
        this.isConsigneeBankOpen = !this.isConsigneeBankOpen;
    }

    get getConsigneeBankClass() {
        return `slds-section slds-m-top_medium ${this.isConsigneeBankOpen ? 'slds-is-open' : ''}`;
    }

    get getConsigneeBankIcon() {
        return this.isConsigneeBankOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // CSS Class Getters
    get getOrderDetailsClass() {
        return `slds-section ${this.isOrderDetailsOpen ? 'slds-is-open' : ''}`;
    }

    get getDomesticClass() {
        return `slds-section slds-m-top_medium ${this.isDomesticOpen ? 'slds-is-open' : ''}`;
    }

    get getExportClass() {
        return `slds-section slds-m-top_medium ${this.isExportOpen ? 'slds-is-open' : ''}`;
    }

    get getSampleClass() {
        return `slds-section slds-m-top_medium ${this.isSampleOpen ? 'slds-is-open' : ''}`;
    }

    get getProcurementClass() {
        return `slds-section slds-m-top_medium ${this.isProcurementOpen ? 'slds-is-open' : ''}`;
    }

    get getCustomerClass() {
        return `slds-section slds-m-top_medium ${this.isCustomerOpen ? 'slds-is-open' : ''}`;
    }

    get getAddressClass() {
        return `slds-section slds-m-top_medium ${this.isAddressOpen ? 'slds-is-open' : ''}`;
    }

    // Icon Getters
    get getOrderDetailsIcon() {
        return this.isOrderDetailsOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getDomesticIcon() {
        return this.isDomesticOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getExportIcon() {
        return this.isExportOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }
    
    get getSampleIcon() {
        return this.isSampleOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getProcurementIcon() {
        return this.isProcurementOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getCustomerIcon() {
        return this.isCustomerOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getAddressIcon() {
        return this.isAddressOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get getProductClass() {
        return `slds-section slds-m-top_medium ${this.isProductOpen ? 'slds-is-open' : ''}`;
    }

    get getProductIcon() {
        return this.isProductOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get hasProducts() {
        return this.filteredData && this.filteredData.length > 0;
    }

    toggleProduct() {
        this.isProductOpen = !this.isProductOpen;
    }

    fetchOrderDetails() {
        getOrderRecord({ orderId: this.recordId })
            .then(result => {
                this.orderRec = { ...result };

                if (result.DRC_NBC_Type__c === 'Domestic') {
                    this.isDomestic = true;
                    this.isExport = false;
                } else if (result.DRC_NBC_Type__c === 'Export') {
                    this.isDomestic = false;
                    this.isExport = true;
                } else if(result.Type === 'Sample Order'){
                    this.isSample = true;
                    if(result.Type === 'Sample Order' && result.DRC_NBC_Sample_Type__c ==='Paid Sample'){
                        this.isSamplePaid = true;
                    }
                    this.isDomestic = false;
                    this.isExport = false;
                }

                this.billToContactId = result.BillToContactId || '';
                this.billToContactName = result.BillToContact?.Name || '';
                this.billToAccountId = result.BillToContact?.AccountId || '';
                this.billToAccountName = result.BillToContact?.Account?.Name || '';

                this.shipToContactId = result.ShipToContactId || '';
                this.shipToContactName = result.ShipToContact?.Name || '';
                this.shipToAccountId = result.ShipToContact?.AccountId || '';
                this.shipToAccountName = result.ShipToContact?.Account?.Name || '';
                
                this.accountOptions = [{
                    label: this.billToAccountName,
                    value: this.billToAccountId
                }];
                this.opportunityName = result.Opportunity?.Name || '';
                this.quoteName = result.Quote?.Name || '';
                this.fetchContacts(this.billToAccountId);
                
                this.billToAddressFormatted = this.formatAddress({
                    street: result.BillingStreet,
                    city: result.BillingCity,
                    state: result.BillingState,
                    postalCode: result.BillingPostalCode,
                    country: result.BillingCountry
                });

                this.selectedShipToAddressId = result.DRC_NBC_Shipping_Address__c || '';

                if (this.shipToAccountId) {
                    this.fetchShipToAddresses();
                }
                if (this.billToAccountId) {
                    this.fetchOpportunities(this.billToAccountId);
                }
                this.updateRejectionVisibility();
            })
            .catch(error => {
                this.showToastEvent('Error', 'Failed to load order details: ' + (error.body?.message || error.message), 'error');
            });
    }

    updateRejectionVisibility() {
        this.showRejectionReason = this.orderRec.Status === 'Rejected';
        this.showOtherRejectionText = this.showRejectionReason && 
                                    this.orderRec.DRC_NBC_Rejection_Reason1__c === 'Other';
    }

    formatAddress(addr) {
        const parts = [
            addr.street,
            addr.city,
            addr.state,
            addr.postalCode,
            addr.country
        ].filter(p => p);
        return parts.join(', ') || 'No address available';
    }

    fetchShipToAddresses() {
        if (!this.shipToAccountId) return;
        
        getAccountAddresses({ accountId: this.shipToAccountId })
            .then(result => {
                this.shipToAddressOptions = result || [];
            })
            .catch(error => {
                this.showToastEvent('Error', 'Failed to load ship to addresses', 'error');
            });
    }

    fetchContacts(accountId) {
        if (!accountId) return;

        getContactsByAccount({ accountId })
            .then(result => {
                this.allBillToContacts = result.map(c => ({ label: c.Name, value: c.Id }));
                this.allShipToContacts = [...this.allBillToContacts];
                
                this.filteredBillToContacts = [...this.allBillToContacts];
                this.filteredShipToContacts = [...this.allShipToContacts];
                
                this.billToContactOptions = [...this.allBillToContacts];
                this.shipToContactOptions = [...this.allShipToContacts];
            })
            .catch(error => {
                this.showToastEvent('Error', 'Failed to fetch contacts for account', 'error');
            });
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
        this.showBillToContactDropdown = false;
        
        this.handleFieldChange({
            target: {
                fieldName: 'BillToContactId'
            },
            detail: {
                value: selectedId
            }
        });
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
        this.showShipToContactDropdown = false;
        
        this.handleFieldChange({
            target: {
                fieldName: 'ShipToContactId'
            },
            detail: {
                value: selectedId
            }
        });
    }

    handleAddressChange(event) {
        this.selectedShipToAddressId = event.detail.value;
    }

    fetchOpportunities(accountId) {
        getOpportunitiesByAccount({ accountId })
            .then(result => {
                this.allOpportunities = result.map(opp => ({
                    label: opp.Name,
                    value: opp.Id
                }));
                
                this.filteredOpportunities = [...this.allOpportunities];
                this.opportunityOptions = [...this.allOpportunities];

                if (this.orderRec.OpportunityId) {
                    const selectedOpp = this.allOpportunities.find(o => o.value === this.orderRec.OpportunityId);
                    if (selectedOpp) {
                        this.opportunityName = selectedOpp.label;
                    }
                    this.fetchQuotes(this.orderRec.OpportunityId);
                }
            })
            .catch(error => {
                this.showToastEvent('Error', 'Failed to fetch opportunities', 'error');
            });
    }

    fetchQuotes(opportunityId) {
        getQuotesByOpportunity({ opportunityId })
            .then(result => {
                this.allQuotes = result.map(quote => ({
                    label: quote.Name,
                    value: quote.Id
                }));
                this.filteredQuotes = [...this.allQuotes];
                this.quoteOptions = [...this.allQuotes];
                this.isQuoteDisabled = false;
                
                if (this.orderRec.QuoteId) {
                    const selectedQuote = this.allQuotes.find(q => q.value === this.orderRec.QuoteId);
                    if (selectedQuote) {
                        this.quoteName = selectedQuote.label;
                    }
                }
            })
            .catch(error => {
                this.showToastEvent('Error', 'Failed to fetch quotes', 'error');
            });
    }

    // Opportunity Handlers
    handleOpportunityFocus(event) {
        event.stopPropagation();
        this.filteredOpportunities = [...this.allOpportunities];
        this.showOpportunityDropdown = true;
        this.showQuoteDropdown = false;
        this.showBillToContactDropdown = false;
        this.showShipToContactDropdown = false;
    }

    handleOpportunitySearch(event) {
        const searchTerm = event.target.value.toLowerCase();
        this.opportunityName = event.target.value;
        
        if (searchTerm.length === 0) {
            this.filteredOpportunities = [...this.allOpportunities];
        } else {
            this.filteredOpportunities = this.allOpportunities.filter(opp =>
                opp.label.toLowerCase().includes(searchTerm)
            );
        }
        
        this.showOpportunityDropdown = true;
    }

    handleOpportunitySelect(event) {
        event.stopPropagation();
        const selectedId = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;
        
        this.orderRec.OpportunityId = selectedId;
        this.opportunityName = selectedName;
        this.showOpportunityDropdown = false;
        
        this.orderRec.QuoteId = '';
        this.quoteName = '';
        this.allQuotes = [];
        this.filteredQuotes = [];
        this.isQuoteDisabled = true;
        
        this.handleFieldChange({
            target: {
                fieldName: 'OpportunityId'
            },
            detail: {
                value: selectedId
            }
        });
        
        if (selectedId) {
            this.fetchQuotes(selectedId);
        }
    }

    // Quote Handlers
    handleQuoteFocus(event) {
        event.stopPropagation();
        if (!this.isQuoteDisabled) {
            this.filteredQuotes = [...this.allQuotes];
            this.showQuoteDropdown = true;
            this.showOpportunityDropdown = false;
            this.showBillToContactDropdown = false;
            this.showShipToContactDropdown = false;
        }
    }

    handleQuoteSearch(event) {
        const searchTerm = event.target.value.toLowerCase();
        this.quoteName = event.target.value;
        
        if (searchTerm.length === 0) {
            this.filteredQuotes = [...this.allQuotes];
        } else {
            this.filteredQuotes = this.allQuotes.filter(quote =>
                quote.label.toLowerCase().includes(searchTerm)
            );
        }
        
        this.showQuoteDropdown = true;
    }

    handleQuoteSelect(event) {
        event.stopPropagation();
        const selectedId = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;
        
        this.orderRec.QuoteId = selectedId;
        this.quoteName = selectedName;
        this.showQuoteDropdown = false;
        
        this.handleFieldChange({
            target: {
                fieldName: 'QuoteId'
            },
            detail: {
                value: selectedId
            }
        });
    }

    handleFieldChange(event) {
        const fieldName = event.target.fieldName || event.target.name || event.target.dataset.field;
        const value = event.detail?.value || event.target.value;

        if (fieldName) {
            this.orderRec[fieldName] = value;

            if (fieldName === 'DRC_NBC_Type__c') {
                this.isDomestic = value === 'Domestic';
                this.isExport = value === 'Export';
            }
            if (fieldName === 'DRC_NBC_Sample_Type__c') {
                this.isSamplePaid = (value === 'Paid Sample');
            }

            if (fieldName === 'Status') {
                this.updateRejectionVisibility();
            }
            
            if (fieldName === 'DRC_NBC_Rejection_Reason1__c') {
                this.updateRejectionVisibility();
            }

            if (fieldName === 'CurrencyIsoCode') {
                this.currencyCode = value;
            }
        }
    }

    fetchOrderLineItems() {
        getExistingOrderLineItems({ orderId: this.recordId })
            .then(data => {
                this.productsMasterList = data.productsList;
                this.filteredProductList = [...data.productsList];

                if (data.olis.length > 0) {
                    this.result = data;
                    this.getOrganizedData();
                } else {
                    let newRow = this.getBaseRecordData().olis;
                    newRow.OrderId = this.recordId;
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
            let record = this.getBaseRecordData().olis;

            const originalUnitPrice = item.UnitPrice || 0;
            const savedModifiedPrice = item.UnitPrice || originalUnitPrice;

            // Parse packing size options from Product2.DRC_NBC_Packing_Size__c
            const packingSizeField = item.Product2?.DRC_NBC_Packing_Size__c || '';
            const packingSizeOptions = this.parsePackingSizes(packingSizeField);

            Object.assign(record, {
                Id: item.Id,
                Name: item.Product2?.Name || '',
                PricebookEntryId: item.PricebookEntryId,
                Description: item.Description || '',
                Product2Id: item.Product2Id,
                Quantity: item.Quantity || 1,
                UnitPrice: originalUnitPrice,
                OriginalUnitPrice: originalUnitPrice,
                DRC_NBC_FG_Code__c: item.Product2?.DRC_NBC_FG_Code__c || '-',
                DRC_NBC_HSN_SAC_Code__c: item.Product2?.DRC_NBC_HSN_SAC_Code__c || '-',
                UOM: item.Product2?.QuantityUnitOfMeasure || '-',
                showSearch: false,
                modifiedPrice: savedModifiedPrice,
                packingSizeOptions: packingSizeOptions,
                selectedPackingSize: item.DRC_NBC_Packing_Size__c || '',
                packingQuantity: item.DRC_NBC_Packing_Quantity__c || ''
            });
            this.allData.push({ recordData: record });
        }
        this.filteredData = [...this.allData];
    }

    // Parse packing sizes from multiselect picklist
    parsePackingSizes(packingSizesString) {
        if (!packingSizesString) return [];
        
        const sizes = packingSizesString.split(';').map(s => s.trim()).filter(s => s);
        return sizes.map(size => ({
            label: size,
            value: size
        }));
    }

    // Extract numeric value from packing size text
    extractPackingNumber(packingSizeText) {
        if (!packingSizeText) return 0;
        
        const match = packingSizeText.match(/(\d+(?:\.\d+)?)/);
        return match ? parseFloat(match[1]) : 0;
    }

    // Handle packing size change
    handlePackingSizeChange(event) {
        const index = event.target.dataset.index;
        const selectedPackingSize = event.detail.value;
        
        let record = this.filteredData[index].recordData;
        record.selectedPackingSize = selectedPackingSize;
        
        // Calculate packing quantity
        const packingNumber = this.extractPackingNumber(selectedPackingSize);
        const quantity = parseFloat(record.Quantity) || 0;
        
        if (packingNumber > 0 && quantity > 0) {
            record.packingQuantity = Math.ceil(quantity / packingNumber).toString();
        } else {
            record.packingQuantity = '';
        }
        
        this.filteredData = [...this.filteredData];
    }

    // Handle quantity change (recalculate packing quantity)
    handleQuantityChange(event) {
        const index = event.target.dataset.index;
        const value = event.target.value;
        
        this.filteredData[index].recordData.Quantity = value;
        
        // Recalculate packing quantity if packing size is selected
        const record = this.filteredData[index].recordData;
        if (record.selectedPackingSize) {
            const packingNumber = this.extractPackingNumber(record.selectedPackingSize);
            const quantity = parseFloat(value) || 0;
            
            if (packingNumber > 0 && quantity > 0) {
                record.packingQuantity = Math.ceil(quantity / packingNumber).toString();
            } else {
                record.packingQuantity = '';
            }
        }
        
        this.updateTotal(index);
        this.filteredData = [...this.filteredData];
    }

    handleAddRow() {
        let newRow = this.getBaseRecordData().olis;
        newRow.Id = null;
        newRow.showSearch = true;
        this.filteredData.push({ recordData: newRow });
        this.showAddProducts = false;
    }

    handleRemoveRow(event) {
        const index = event.target.dataset.index;
        const id = event.target.dataset.id;

        if (id) {
            this.oliIdsToDelete.push(id);
        }

        this.filteredData.splice(index, 1);

        if (this.filteredData.length === 0) {
            this.showAddProducts = true;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
        const cancelEvent = new CustomEvent('cancel', {
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(cancelEvent);
    }

    handleSave() {
        this.showLoading = true;
        let isValid = true;
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
        }

        if (!this.orderRec?.EffectiveDate) {
            this.showToastEvent("Error", "Effective Date is required", "error");
            isValid = false;
        }
        if (!this.orderRec?.EndDate) {
            this.showToastEvent("Error", "End Date is required", "error");
            isValid = false;
        }

        if (this.orderRec?.EndDate) {
            const endDate = new Date(this.orderRec.EndDate);
            endDate.setHours(0, 0, 0, 0);
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            
            if (endDate <= today) {
                this.showToastEvent('Error', 'End Date must be greater than today.', 'error');
                isValid = false;
            }
        }

        if (!this.billToContactId) {
            this.showToastEvent("Error", "Bill To Contact is required", "error");
            isValid = false;
        }

        if (!this.shipToContactId) {
            this.showToastEvent("Error", "Ship To Contact is required", "error");
            isValid = false;
        }

        if (!this.selectedShipToAddressId) {
            this.showToastEvent("Error", "Ship To Address is required", "error");
            isValid = false;
        }

        // Date validations
        if (this.orderRec.DRC_NBC_Expected_Delivery_Date__c && this.orderRec.EndDate) {
            if (new Date(this.orderRec.DRC_NBC_Expected_Delivery_Date__c) > new Date(this.orderRec.EndDate)) {
                this.showToastEvent('Error', 'Expected Delivery Date must be less than End Date.', 'error');
                isValid = false;
            }
        }
        
        if (this.orderRec.DRC_NBC_Courier_date__c && this.orderRec.EndDate) {
            if (new Date(this.orderRec.DRC_NBC_Courier_date__c) > new Date(this.orderRec.EndDate)) {
                this.showToastEvent('Error', 'Courier date must be less than End Date.', 'error');
                isValid = false;
            }
        }
        
        if (this.orderRec.DRC_NBC_Shipment_Date__c && this.orderRec.EndDate) {
            if (new Date(this.orderRec.DRC_NBC_Shipment_Date__c) > new Date(this.orderRec.EndDate)) {
                this.showToastEvent('Error', 'Shipment Date must be less than End Date.', 'error');
                isValid = false;
            }
        }
        
        if (this.orderRec.NBC_DRC_Dispatch_Date__c && this.orderRec.EndDate) {
            if (new Date(this.orderRec.NBC_DRC_Dispatch_Date__c) > new Date(this.orderRec.EndDate)) {
                this.showToastEvent('Error', 'Dispatch Date must be less than End Date.', 'error');
                isValid = false;
            }
        }
        
        if (this.orderRec.PoDate && this.orderRec.EndDate) {
            if (new Date(this.orderRec.PoDate) > new Date(this.orderRec.EndDate)) {
                this.showToastEvent('Error', 'PO Date must be less than End Date.', 'error');
                isValid = false;
            }
        }

        if (!isValid) {
            this.showLoading = false;
            return;
        }

        const recordsToSave = this.filteredData.map(row => {
            const r = row.recordData;
            return {
                Id: r.Id || null,
                Product2Id: r.Product2Id,
                Quantity: r.Quantity,
                UnitPrice: parseFloat(r.modifiedPrice) || parseFloat(r.UnitPrice) || 0,
                OrderId: this.recordId,
                PricebookEntryId: r.PricebookEntryId,
                Description: r.Description,
                DRC_NBC_Packing_Size__c: r.selectedPackingSize || '',
                DRC_NBC_Packing_Quantity__c: r.packingQuantity || ''
            };
        });

        const updatedOrder = {
            Id: this.recordId,
            Name: this.orderRec.Name,
            EffectiveDate: this.orderRec.EffectiveDate,
            EndDate: this.orderRec.EndDate,
            Description: this.orderRec.Description,
            CurrencyIsoCode: this.orderRec.CurrencyIsoCode,
            Status: this.orderRec.Status,
            Type: this.orderRec.Type,
            DRC_NBC_Type__c: this.orderRec.DRC_NBC_Type__c,
            DRC_NBC_Payment_Terms__c: this.orderRec.DRC_NBC_Payment_Terms__c,
            DRC_NBC_Rejection_Reason1__c: this.orderRec.DRC_NBC_Rejection_Reason1__c,
            DRC_NBC_Other_Rejection_Reason__c: this.orderRec.DRC_NBC_Other_Rejection_Reason__c,
            DRC_NBC_Inco_Terms__c: this.orderRec.DRC_NBC_Inco_Terms__c,
            DRC_NBC_Warehouse__c: this.orderRec.DRC_NBC_Warehouse__c,
            DRC_NBC_Select_Bank__c: this.orderRec.DRC_NBC_Select_Bank__c,
            DRC_NBC_Terms_and_Conditions__c: this.orderRec.DRC_NBC_Terms_and_Conditions__c,
            PoNumber: this.orderRec.PoNumber,
            DRC_NBC_Other_Tax_Amount__c: this.orderRec.DRC_NBC_Other_Tax_Amount__c,
            DRC_NBC_Consignee_Bank_Name__c: this.orderRec.DRC_NBC_Consignee_Bank_Name__c,
            DRC_NBC_Consignee_Bank_Account_Number__c: this.orderRec.DRC_NBC_Consignee_Bank_Account_Number__c,
            DRC_NBC_Consignee_Bank_IFSC_Code__c: this.orderRec.DRC_NBC_Consignee_Bank_IFSC_Code__c,
            DRC_NBC_Consignee_Bank_Address__c: this.orderRec.DRC_NBC_Consignee_Bank_Address__c,
            DRC_NBC_TCS_Amount__c: this.orderRec.DRC_NBC_TCS_Amount__c,
            PoDate: this.orderRec.PoDate,
            DRC_NBC_Special_Instructions__c: this.orderRec.DRC_NBC_Special_Instructions__c,
            OpportunityId: this.orderRec.OpportunityId,
            QuoteId: this.orderRec.QuoteId,
            BillToContactId: this.billToContactId,
            ShipToContactId: this.shipToContactId,
            DRC_NBC_Shipping_Address__c: this.selectedShipToAddressId
        };

        if (this.isDomestic) {
            updatedOrder.DRC_NBC_Transporter_Name__c = this.orderRec.DRC_NBC_Transporter_Name__c;
            updatedOrder.DRC_NBC_Transport_Agent__c = this.orderRec.DRC_NBC_Transport_Agent__c;
            updatedOrder.DRC_NBC_Shipment_Method__c = this.orderRec.DRC_NBC_Shipment_Method__c;
            updatedOrder.DRC_NBC_Prepayment_Method__c = this.orderRec.DRC_NBC_Prepayment_Method__c;
            updatedOrder.DRC_NBC_Shipment_Date__c = this.orderRec.DRC_NBC_Shipment_Date__c;
        }

        if (this.isExport) {
            updatedOrder.DRC_NBC_Country_of_Origin__c = this.orderRec.DRC_NBC_Country_of_Origin__c;
            updatedOrder.DRC_NBC_Country_of_Final_Destination__c = this.orderRec.DRC_NBC_Country_of_Final_Destination__c;
            updatedOrder.DRC_NBC_Shipment_Method__c = this.orderRec.DRC_NBC_Shipment_Method__c;
            updatedOrder.DRC_NBC_Port_Of_Discharge__c = this.orderRec.DRC_NBC_Port_Of_Discharge__c;
            updatedOrder.DRC_NBC_Port_of_Loading__c = this.orderRec.DRC_NBC_Port_of_Loading__c;
            updatedOrder.DRC_NBC_Notify_Party__c = this.orderRec.DRC_NBC_Notify_Party__c;
            updatedOrder.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c = this.orderRec.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c;
            updatedOrder.DRC_NBC_Prepayment_Method__c = this.orderRec.DRC_NBC_Prepayment_Method__c;
            updatedOrder.DRC_NBC_Vessel_no_Flight_no__c = this.orderRec.DRC_NBC_Vessel_no_Flight_no__c;
            updatedOrder.DRC_NBC_Part_Shipment__c = this.orderRec.DRC_NBC_Part_Shipment__c;
            updatedOrder.DRC_NBC_Trans_Shipment__c = this.orderRec.DRC_NBC_Trans_Shipment__c;
            updatedOrder.DRC_NBC_Final_Destination__c = this.orderRec.DRC_NBC_Final_Destination__c;
            updatedOrder.DRC_NBC_Required_Documents__c = this.orderRec.DRC_NBC_Required_Documents__c;
        }
        
        if (this.isSample) {
            updatedOrder.DRC_NBC_Sample_Name__c = this.orderRec.DRC_NBC_Sample_Name__c;
            updatedOrder.DRC_NBC_Sample_Type__c = this.orderRec.DRC_NBC_Sample_Type__c;
            updatedOrder.DRC_NBC_Courier_service__c = this.orderRec.DRC_NBC_Courier_service__c;
            updatedOrder.DRC_NBC_Delivery_status__c = this.orderRec.DRC_NBC_Delivery_status__c;
            updatedOrder.DRC_NBC_Courier_Number__c = this.orderRec.DRC_NBC_Courier_Number__c;
            updatedOrder.DRC_NBC_Expected_Delivery_Date__c = this.orderRec.DRC_NBC_Expected_Delivery_Date__c;
            updatedOrder.DRC_NBC_Courier_date__c = this.orderRec.DRC_NBC_Courier_date__c;
            updatedOrder.DRC_NBC_Sample_Shipping_Cost__c = this.orderRec.DRC_NBC_Sample_Shipping_Cost__c;
            updatedOrder.DRC_NBC_Special_request__c = this.orderRec.DRC_NBC_Special_request__c;
            updatedOrder.DRC_NBC_Sample_Amount__c = this.orderRec.DRC_NBC_Sample_Amount__c;
            updatedOrder.DRC_NBC_Rejection_Reason__c = this.orderRec.DRC_NBC_Rejection_Reason__c;
            updatedOrder.DRC_NBC_Remarks__c = this.orderRec.DRC_NBC_Remarks__c;
            updatedOrder.Type = 'Sample Order';
        }

        console.log('Saving Order Data:', JSON.stringify(updatedOrder, null, 2));
        console.log('Saving OLI Data:', JSON.stringify(recordsToSave, null, 2));

        saveOrderLineItems({
            oliList: recordsToSave,
            oliIdsToDelete: this.oliIdsToDelete,
            orderData: updatedOrder
        })
            .then(() => {
                this.showToastEvent("Success", "Order and Line Items saved successfully", "success");
                this.showLoading = false;
                
                setTimeout(() => {
                   window.location.href = '/' + this.recordId;
                }, 500);
            })
            .catch(error => {
                console.error('SaveOrderLineItems Error:', error);
                console.error('Error Details:', JSON.stringify(error, null, 2));
                
                let message = 'Unknown error occurred';
                if (error?.body?.message) {
                    message = error.body.message;
                } else if (error?.message) {
                    message = error.message;
                } else if (error?.body?.pageErrors && error.body.pageErrors.length > 0) {
                    message = error.body.pageErrors[0].message;
                } else if (error?.body?.fieldErrors) {
                    const fieldErrors = Object.values(error.body.fieldErrors).flat();
                    if (fieldErrors.length > 0) {
                        message = fieldErrors[0].message;
                    }
                }
                
                this.showToastEvent("Error", message, "error");
                this.showLoading = false;
            });
    }

    handleValueChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.name;
        const value = event.target.value;
        this.filteredData[index].recordData[field] = value;

        if (field === 'ProductName' && value.length >= 2) {
            const matches = this.productsMasterList.filter(product =>
                product.Product2.Name.toLowerCase().includes(value.toLowerCase())
            );
            this.filteredData[index].recordData.searchResults = matches;
            this.filteredData[index].recordData.noResultsFound = matches.length === 0;
        } else if (field === 'ProductName') {
            this.filteredData[index].recordData.searchResults = [];
            this.filteredData[index].recordData.noResultsFound = false;
        }

        if (field === 'Quantity') {
            this.handleQuantityChange(event);
        }
    }

    handleModifiedPriceChange(event) {
        const index = event.target.dataset.index;
        const value = parseFloat(event.target.value) || 0;
        let record = this.filteredData[index].recordData;

        record.modifiedPrice = value;
        this.updateTotal(index);
        this.filteredData = [...this.filteredData];
    }

    handleProductSelect(event) {
        const index = event.target.dataset.index;
        const selectedId = event.target.dataset.id;
        const selectedProduct = this.productsMasterList.find(p => p.Id === selectedId);

        if (selectedProduct) {
            const unitPrice = selectedProduct.UnitPrice || 0;
            const packingSizeField = selectedProduct.Product2?.DRC_NBC_Packing_Size__c || '';
            const packingSizeOptions = this.parsePackingSizes(packingSizeField);

            this.filteredData[index].recordData = {
                ...this.filteredData[index].recordData,
                showSearch: false,
                Name: selectedProduct.Product2.Name,
                Product2Id: selectedProduct.Product2.Id,
                Description: selectedProduct.Product2.Description,
                UnitPrice: unitPrice,
                OriginalUnitPrice: unitPrice,
                DRC_NBC_HSN_SAC_Code__c: selectedProduct.Product2.DRC_NBC_HSN_SAC_Code__c,
                DRC_NBC_FG_Code__c: selectedProduct.Product2.DRC_NBC_FG_Code__c,
                PricebookEntryId: selectedProduct.Id,
                UOM: selectedProduct.Product2.QuantityUnitOfMeasure,
                modifiedPrice: unitPrice,
                packingSizeOptions: packingSizeOptions,
                selectedPackingSize: '',
                packingQuantity: '',
                searchResults: [],
                noResultsFound: false
            };
            this.updateTotal(index);
            this.filteredData = [...this.filteredData];
        }
    }

    showToastEvent(title, error, variant) {
        let message = typeof error === 'string'
            ? error
            : (error?.body?.message || 'Unknown error');
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    getBaseRecordData() {
        return {
            olis: {
                Id: '',
                Name: '',
                PricebookEntryId: '',
                Description: '',
                Product2Id: '',
                Quantity: 1,
                UnitPrice: 0,
                OriginalUnitPrice: 0,
                ProductName: '',
                DRC_NBC_FG_Code__c: '',
                DRC_NBC_HSN_SAC_Code__c:'',
                UOM: '',
                modifiedPrice: 0,
                totalAmount: 0,
                showSearch: true,
                searchResults: [],
                noResultsFound: false,
                packingSizeOptions: [],
                selectedPackingSize: '',
                packingQuantity: ''
            }
        };
    }

    updateTotal(index) {
        let record = this.filteredData[index].recordData;
        const modifiedPrice = parseFloat(record.modifiedPrice) || 0;
        const quantity = parseFloat(record.Quantity) || 0;
        record.totalAmount = modifiedPrice * quantity;
    }
}