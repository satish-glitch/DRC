import { LightningElement, track, api, wire } from 'lwc';
import getExistingQLIs from '@salesforce/apex/DRC_NBC_ProductsController.getExistingQLIs';
import saveQLIData from '@salesforce/apex/DRC_NBC_ProductsController.saveQLIData';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import getQuoteRecord from '@salesforce/apex/DRC_NBC_ProductsController.getQuoteRecord';
import getAccountAddresses from '@salesforce/apex/DRC_NBC_ProductsController.getAccountAddresses';
import getAccountContacts from '@salesforce/apex/DRC_NBC_ProductsController.getAccountContacts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import AddProductCSS from '@salesforce/resourceUrl/DRC_NBC_Order_Button_CSS';

export default class DRC_NBC_AddProductsToQuotes extends NavigationMixin(LightningElement) {
    @track allData = [];
    @track filteredData = [];
    @api recordId;
    @track showFilterData = false;
    @track showLoading = false;
    showAddProducts = false;
    @track quoteRec = {};
    productsMasterList = [];
    filteredProductList = [];
    qliIdsToDelete = [];

    @track isDomestic = false;
    @track isExport = false;

    @track isProductOpen = true;
    @track showAddProducts = false;
    @track contactOptions = [];
    @track isBasicInfoOpen = true;
    @track isPreparedOpen = true;
    @track isAddressOpen = true;
    @track isFinancialOpen = true;
    @track selectedShippingId;
    @track selectedContactId = '';
    @track selectedContactEmail = '';
    @track selectedContactPhone = '';
    @track selectedContactFax = '';
    @track shippingAddressOptions = [];
    @track selectedContactMobile = '';
    @track showContactSuggestions = false;
    @track filteredContacts  = [];
    @track selectedContactName = '';

    // Packing details map: Product2Id → List of { packingSize, packingQuantity }
    packingDetailsMap = {};

    @track showInternalHeader = true;
    isCalledFromAura = false;

    // Account billing address fields
    @track accountBillingStreet = '';
    @track accountBillingCity = '';
    @track accountBillingState = '';
    @track accountBillingPostalCode = '';
    @track accountBillingCountry = '';

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
                this.fetchQLIData();
                this.fetchQuoteDetails();
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

    toggleBasicInfo() { this.isBasicInfoOpen = !this.isBasicInfoOpen; }
    togglePrepared()   { this.isPreparedOpen  = !this.isPreparedOpen;  }
    toggleAddressInfo(){ this.isAddressOpen   = !this.isAddressOpen;   }
    toggleFinancial()  { this.isFinancialOpen = !this.isFinancialOpen; }
    toggleProduct()    { this.isProductOpen   = !this.isProductOpen;   }

    get getBasicInfoClass()  { return `slds-section ${this.isBasicInfoOpen  ? 'slds-is-open' : ''}`; }
    get getPreparedClass()   { return `slds-section slds-m-top_medium ${this.isPreparedOpen   ? 'slds-is-open' : ''}`; }
    get getAddressClass()    { return `slds-section slds-m-top_medium ${this.isAddressOpen    ? 'slds-is-open' : ''}`; }
    get getFinancialClass()  { return `slds-section slds-m-top_medium ${this.isFinancialOpen  ? 'slds-is-open' : ''}`; }
    get getProductClass()    { return `slds-section slds-m-top_medium ${this.isProductOpen    ? 'slds-is-open' : ''}`; }

    get getBasicInfoIcon()  { return this.isBasicInfoOpen  ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getPreparedIcon()   { return this.isPreparedOpen   ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getAddressIcon()    { return this.isAddressOpen    ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getFinancialIcon()  { return this.isFinancialOpen  ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getProductIcon()    { return this.isProductOpen    ? 'utility:chevrondown' : 'utility:chevronright'; }

    get hasProducts() {
        return this.filteredData && this.filteredData.length > 0;
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

    // ─── Packing helpers ──────────────────────────────────────────────────────

    buildPackingSizeOptions(packingDetailsList) {
        if (!packingDetailsList || packingDetailsList.length === 0) return [];
        return packingDetailsList.map(pd => ({
            label: pd.packingSize || '',
            value: pd.packingSize || ''
        }));
    }

    getPackingDetailsForProduct(product2Id) {
        if (!product2Id || !this.packingDetailsMap) return [];
        return this.packingDetailsMap[product2Id] || [];
    }

    /**
     * Packing quantity column = DRC_NBC_Packing_Qauntity__c directly from DB.
     * NOT a calculation — just return rawPackingQuantity as-is.
     */
    _recalcPackingQuantity(rowData) {
        return rowData.rawPackingQuantity || '';
    }

    /**
     * Returns error message if qty is not a valid multiple of rawPackingQty.
     * Returns '' if valid or no packing size selected.
     */
    _getQuantityError(qty, rawPackingQty) {
        const packQty = parseFloat(rawPackingQty);
        if (!rawPackingQty || isNaN(packQty) || packQty <= 0) return '';
        if (!qty || qty <= 0) return 'Quantity must be greater than 0.';
        if (qty % packQty !== 0) {
            return `Quantity must be a multiple of ${packQty} (e.g. ${packQty}, ${packQty * 2}, ${packQty * 3}…).`;
        }
        return '';
    }

    // ─── Contact handlers ─────────────────────────────────────────────────────

    handleClearProduct(event) {
        const index = parseInt(event.currentTarget.dataset.index);
        let clearedRow = this.getBaseRecordData().qlis;
        clearedRow.ProductName   = '';
        clearedRow.searchResults = [];
        clearedRow.showSearch    = true;
        clearedRow.noResultsFound = false;
        this.filteredData[index].recordData = clearedRow;
        this.filteredData = [...this.filteredData];
    }

    handleContactInputFocus() {
        this.filteredContacts       = this.contactOptions;
        this.showContactSuggestions = true;
    }

    handleContactInputBlur() {
        setTimeout(() => { this.showContactSuggestions = false; }, 200);
    }

    handleContactInputChange(event) {
        const searchKey = event.target.value;
        this.selectedContactName = searchKey;

        if (!searchKey) {
            this.selectedContactId    = null;
            this.selectedContactEmail = '';
            this.selectedContactPhone = '';
            this.selectedContactMobile = '';
            this.quoteRec.ContactId   = null;
            this.quoteRec.Email       = '';
            this.quoteRec.Phone       = '';
            this.quoteRec.Fax         = '';
            this.filteredContacts       = [];
            this.showContactSuggestions = false;
            return;
        }

        this.filteredContacts = this.contactOptions.filter(c =>
            c.label.toLowerCase().includes(searchKey.toLowerCase())
        );
        this.showContactSuggestions = true;
    }

    handleContactSelect(event) {
        const selectedId   = event.currentTarget.dataset.id;
        const selectedName = event.currentTarget.dataset.name;

        this.selectedContactId   = selectedId;
        this.selectedContactName = selectedName;

        const selectedContact = this.contactOptions.find(c => c.value === selectedId);
        if (selectedContact) {
            this.selectedContactEmail  = selectedContact.email || '';
            this.selectedContactPhone  = selectedContact.phone || '';
            this.selectedContactMobile = selectedContact.fax   || '';
        }

        this.quoteRec.ContactId = selectedId;
        this.quoteRec.Email     = this.selectedContactEmail;
        this.quoteRec.Phone     = this.selectedContactPhone;
        this.quoteRec.Fax       = this.selectedContactFax;

        this.showContactSuggestions = false;
    }

    // ─── Data fetching ────────────────────────────────────────────────────────

    fetchQuoteDetails() {
        getQuoteRecord({ quoteId: this.recordId })
            .then(result => {
                this.quoteRec                             = { ...result };
                this.isDomestic = result?.DRC_NBC_Type__c === 'Domestic';
                this.isExport = result?.DRC_NBC_Type__c === 'Export';
                this.selectedContactId                    = result.ContactId || '';
                this.selectedContactEmail                 = result.Email     || '';
                this.selectedContactPhone                 = result.Phone     || '';
                this.selectedContactFax                   = result.Fax       || '';
                this.quoteRec.DRC_NBC_Other_Tax_Amount__c = result.DRC_NBC_Other_Tax_Amount__c || 0;
                this.quoteRec.DRC_NBC_TCS_Amount__c       = result.DRC_NBC_TCS_Amount__c       || 0;
                this.selectedShippingId                   = result.DRC_NBC_Shipping_Address_Id__c || '';

                if (result.Opportunity?.AccountId || result.AccountId) {
                    const accountId = result.Opportunity?.AccountId || result.AccountId;
                    this.fetchAccountAddresses(accountId);
                    this.fetchAccountContacts();
                }
            })
            .catch(error => {
                this.showToastEvent('Error', 'Failed to load quote details: ' + (error.body?.message || error.message), 'error');
            });
    }

    fetchAccountAddresses(accountId) {
        getAccountAddresses({ accountId: accountId })
            .then(addressResult => {
                this.shippingAddressOptions = addressResult.shippingAddresses || [];

                if (addressResult.billingAddresses && addressResult.billingAddresses.length > 0) {
                    const billingAddr  = addressResult.billingAddresses[0];
                    const addressParts = billingAddr.label.split(', ');
                    this.accountBillingStreet     = addressParts[0] || '';
                    this.accountBillingCity       = addressParts[1] || '';
                    this.accountBillingState      = addressParts[2] || '';
                    this.accountBillingPostalCode = addressParts[3] || '';
                    this.accountBillingCountry    = addressParts[4] || '';
                }
            })
            .catch(error => {
                this.showToastEvent('Error', 'Failed to load address options: ' + (error.body?.message || error.message), 'error');
            });
    }

    fetchAccountContacts() {
        getAccountContacts({ quoteId: this.recordId })
            .then(data => {
                this.contactOptions = data.map(contact => ({
                    label: contact.Name,
                    value: contact.Id,
                    email: contact.Email,
                    phone: contact.Phone,
                    fax:   contact.Fax
                }));

                if (this.selectedContactId) {
                    const selected       = this.contactOptions.find(c => c.value === this.selectedContactId);
                    this.selectedContactName = selected ? selected.label : '';
                }
            })
            .catch(error => {
                this.showToastEvent("Error", "Failed to fetch contacts: " + (error.body?.message || error.message), "error");
            });
    }

    handleContactChange(event) {
        const selectedId = event.detail.value;
        this.selectedContactId = selectedId;
        const selected = this.contactOptions.find(c => c.value === selectedId);
        if (selected) {
            this.selectedContactEmail = selected.email || '';
            this.selectedContactPhone = selected.phone || '';
            this.selectedContactFax   = selected.fax   || '';
        } else {
            this.selectedContactEmail = '';
            this.selectedContactPhone = '';
            this.selectedContactFax   = '';
        }
    }

    handleAddressChange(event) {
        const field = event.target.name;
        const value = event.detail.value;
        if (field === 'shipping') {
            this.selectedShippingId = value;
        }
    }

    handleFieldChange(event) {
        const fieldName = event.target.fieldName || event.target.name || event.target.dataset.field;
        const value     = event.detail?.value    || event.target.value;
        if (fieldName) {
            this.quoteRec[fieldName] = value;
            if (fieldName === 'CurrencyIsoCode') {
                this.currencyCode = value;
            }
        }
    }

    fetchQLIData() {
        getExistingQLIs({ quoteId: this.recordId })
            .then(data => {
                this.productsMasterList  = data.productsList;
                this.filteredProductList = [...data.productsList];

                // Cache the packing details map from Apex
                this.packingDetailsMap = data.packingDetailsMap || {};

                if (data.qlis.length > 0) {
                    this.result = data;
                    this.getOrganizedData();
                } else {
                    let newRow      = this.getBaseRecordData().qlis;
                    newRow.QuoteId  = this.recordId;
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
        const data = this.result.qlis;
        for (let item of data) {
            let record = this.getBaseRecordData().qlis;

            const originalUnitPrice  = item.UnitPrice || 0;
            const savedModifiedPrice = item.DRC_NBC_update_Sales_price__c || originalUnitPrice;
            const calculatedModifier = savedModifiedPrice - originalUnitPrice;

            // Get packing details from the cached map (child object)
            const packingDetails     = this.getPackingDetailsForProduct(item.Product2Id);
            const packingSizeOptions = this.buildPackingSizeOptions(packingDetails);

            const savedPackingSize = item.DRC_NBC_Packing_Size__c || '';

            // ✅ rawPackingQuantity ALWAYS from packing details map (child object DRC_NBC_Packing_Details__c)
            // NOT from item.DRC_NBC_Packing_Qauntity__c (the saved QLI field)
            let rawPackingQuantity = '';
            if (savedPackingSize) {
                const matchedDetail = packingDetails.find(pd => pd.packingSize === savedPackingSize);
                rawPackingQuantity  = matchedDetail ? (matchedDetail.packingQuantity || '') : '';
            }

            // ✅ Packing quantity column = DB value directly (rawPackingQuantity), NOT a calculation
            const packingQuantity = rawPackingQuantity;

            const quantity      = item.Quantity || 1;
            // ✅ Validate on load — qty must be a multiple of rawPackingQuantity
            const quantityError = this._getQuantityError(quantity, rawPackingQuantity);

            Object.assign(record, {
                Id:                             item.Id,
                Name:                           item.Product2?.Name || '',
                PricebookEntryId:               item.PricebookEntryId,
                Description:                    item.Description || '',
                Discount:                       item.Discount || 0,
                ListPrice:                      item.ListPrice || 0,
                Product2Id:                     item.Product2Id,
                Quantity:                       quantity,
                UnitPrice:                      originalUnitPrice,
                OriginalUnitPrice:              originalUnitPrice,
                DRC_NBC_FG_Code__c:             item.Product2?.DRC_NBC_FG_Code__c || '-',
                DRC_NBC_HSN_SAC_Code__c:        item.Product2?.DRC_NBC_HSN_SAC_Code__c || '-',
                DRC_NBC_Unit_Of_Measurement__c: item.Product2?.QuantityUnitOfMeasure || '-',
                showSearch:                     false,
                modifier:                       calculatedModifier.toFixed(2),
                modifiedPrice:                  savedModifiedPrice,
                packingDetails,
                packingSizeOptions,
                selectedPackingSize:            savedPackingSize,
                rawPackingQuantity,             // from child object
                packingQuantity,               // = rawPackingQuantity (DB value directly)
                quantityError                  // validated on load
            });
            this.allData.push({ recordData: record });
        }
        this.filteredData = [...this.allData];
    }

    handleAddRow() {
        let newRow        = this.getBaseRecordData().qlis;
        newRow.Id         = null;
        newRow.showSearch = true;
        newRow.searchResults  = null;
        newRow.noResultsFound = false;
        newRow.searchKey      = '';
        this.filteredData.push({ recordData: newRow });
        this.filteredData     = [...this.filteredData];
        this.showAddProducts  = false;
    }

    handleRemoveRow(event) {
        const index = event.target.dataset.index;
        const id    = event.target.dataset.id;
        if (id) { this.qliIdsToDelete.push(id); }
        this.filteredData.splice(index, 1);
        if (this.filteredData.length === 0) { this.showAddProducts = true; }
    }

    handleCancel() {
        const cancelEvent = new CustomEvent('cancel', { bubbles: true, composed: true });
        this.dispatchEvent(cancelEvent);
        this.dispatchEvent(new CloseActionScreenEvent());
    }

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
            // ✅ Packing multiple validation
            if (row.quantityError) {
                this.showToastEvent("Error", `Row ${rowCount}: ${row.quantityError}`, 'error');
                isValid = false;
            }
        }

        if (!this.quoteRec?.ExpirationDate) {
            this.showToastEvent("Error", "Expiration Date is required in Quote", "error");
            isValid = false;
        }
        if (!this.quoteRec?.DRC_NBC_Lead_Time__c) {
            this.showToastEvent("Error", "Lead Date is required in Quote", "error");
            isValid = false;
        }

        const expirationDate = new Date(this.quoteRec.ExpirationDate + 'T00:00:00');
        const today  = new Date();
        const yyyy   = today.getFullYear();
        const mm     = String(today.getMonth() + 1).padStart(2, '0');
        const dd     = String(today.getDate()).padStart(2, '0');
        const todayDate = new Date(`${yyyy}-${mm}-${dd}T00:00:00`);

        if (expirationDate <= todayDate) {
            this.showToastEvent("Error", "Expiration Date must be a future date.", "error");
            isValid = false;
        }

        if (expirationDate <= !this.quoteRec?.DRC_NBC_Lead_Time__c) {
            this.showToastEvent("Error", "Expiration Date must be greater than Lead date.", "error");
            isValid = false;
        }

        if (!this.selectedContactId) {
            this.showToastEvent("Error", "Please select a contact.", "error");
            isValid = false;
        }
        if (!this.selectedContactEmail) {
            this.showToastEvent("Error", "Selected contact must have an email address.", "error");
            isValid = false;
        }
        if (!this.selectedContactPhone) {
            this.showToastEvent("Error", "Selected contact must have a phone number.", "error");
            isValid = false;
        }
        if (!this.quoteRec.DRC_NBC_Payment_Term_Description__c) {
            this.showToastEvent("Error", "Payment Term Description is required.", "error");
            isValid = false;
        }
        if (!this.quoteRec.DRC_NBC_Payemnt_Term__c) {
            this.showToastEvent("Error", "Payment Term Code is required.", "error");
            isValid = false;
        }
        if (!this.quoteRec.DRC_NBC_Inco_terms__c) {
            this.showToastEvent("Error", "Inco Term is required.", "error");
            isValid = false;
        }
        if (!this.quoteRec.DRC_NBC_Type__c) {
            this.showToastEvent("Error", "Type is required.", "error");
            isValid = false;
        }
        if (!this.quoteRec.Status) {
            this.showToastEvent("Error", "Status is required.", "error");
            isValid = false;
        }
        if (!this.quoteRec.CurrencyIsoCode) {
            this.showToastEvent("Error", "Currency is required.", "error");
            isValid = false;
        }
        if (!this.selectedShippingId) {
            this.showToastEvent("Error", "Please select Shipping Address.", "error");
            isValid = false;
        }

        if (isValid) {
            const recordsToSave = this.filteredData.map(row => {
                const r = row.recordData;
                return {
                    Id:                             r.Id || null,
                    Product2Id:                     r.Product2Id,
                    Quantity:                       r.Quantity,
                    UnitPrice:                      parseFloat(r.modifiedPrice) || parseFloat(r.UnitPrice) || 0,
                    Discount:                       r.Discount,
                    QuoteId:                        this.recordId,
                    PricebookEntryId:               r.PricebookEntryId,
                    Description:                    r.Description,
                    DRC_NBC_Unit_Of_Measurement__c: r.DRC_NBC_Unit_Of_Measurement__c,
                    DRC_NBC_Packing_Size__c:        r.selectedPackingSize || '',
                    // ✅ Save DRC_NBC_Packing_Qauntity__c = rawPackingQuantity (DB value from child object)
                    DRC_NBC_Packing_Qauntity__c:    r.packingQuantity || ''
                };
            });

            const updatedQuote = {
                Id:                                  this.recordId,
                Name:                                this.quoteRec.Name,
                ExpirationDate:                      this.quoteRec.ExpirationDate,
                DRC_NBC_Lead_Time__c:                this.quoteRec.DRC_NBC_Lead_Time__c
                    ? new Date(this.quoteRec.DRC_NBC_Lead_Time__c).toISOString().split('T')[0]
                    : null,
                Description:                         this.quoteRec.Description,
                CurrencyIsoCode:                     this.quoteRec.CurrencyIsoCode,
                Status:                              this.quoteRec.Status,
                DRC_NBC_Type__c:                     this.quoteRec.DRC_NBC_Type__c,
                DRC_NBC_Payemnt_Term__c:             this.quoteRec.DRC_NBC_Payemnt_Term__c,
                DRC_NBC_Payment_Term_Description__c: this.quoteRec.DRC_NBC_Payment_Term_Description__c,
                DRC_NBC_Inco_terms__c:               this.quoteRec.DRC_NBC_Inco_terms__c,
                DRC_NBC_Special_Requirements__c:     this.quoteRec.DRC_NBC_Special_Requirements__c,
                DRC_NBC_Other_Tax_Amount__c:         this.quoteRec.DRC_NBC_Other_Tax_Amount__c || 0,
                DRC_NBC_TCS_Amount__c:               this.quoteRec.DRC_NBC_TCS_Amount__c || 0,
                DRC_NBC_Shipping_Address_Id__c:      this.selectedShippingId,
                ContactId:                           this.selectedContactId,
                Email:                               this.selectedContactEmail,
                Phone:                               this.selectedContactPhone,
                Fax:                                 this.selectedContactFax,
                BillingStreet:                       this.accountBillingStreet,
                BillingCity:                         this.accountBillingCity,
                BillingState:                        this.accountBillingState,
                BillingPostalCode:                   this.accountBillingPostalCode,
                BillingCountry:                      this.accountBillingCountry
            };

            saveQLIData({
                qliList:        recordsToSave,
                qliIdsToDelete: this.qliIdsToDelete,
                quoteData:      updatedQuote
            })
                .then(() => {
                    this.showToastEvent("Success", "Quote and Line Items saved successfully", "success");
                    this.dispatchEvent(new CloseActionScreenEvent());
                    window.location.href = '/' + this.recordId;
                })
                .catch(error => {
                    console.error('SaveQLIData Error:', JSON.stringify(error, null, 2));
                    const message = error?.body?.message || error?.message || 'Unknown error occurred';
                    this.showToastEvent("Error", message, "error");
                })
                .finally(() => { this.showLoading = false; });
        } else {
            this.showLoading = false;
        }
    }

    // ─── Product search by name pattern only (not currency filtered) ──────────
    handleValueChange(event) {
        const index = event.target.dataset.index;
        const field = event.target.name;
        const value = event.target.value;
        this.filteredData[index].recordData[field] = value;

        if (field === 'ProductName' && value.length >= 2) {
            // ✅ Search by name pattern only — currency already on productsMasterList from Quote
            const matches = this.productsMasterList.filter(product =>
                product.Product2.Name.toLowerCase().includes(value.toLowerCase())
            );
            this.filteredData[index].recordData.searchResults  = matches;
            this.filteredData[index].recordData.noResultsFound = matches.length === 0;
        } else if (field === 'ProductName') {
            this.filteredData[index].recordData.searchResults  = [];
            this.filteredData[index].recordData.noResultsFound = false;
        }

        if (['Quantity', 'Discount'].includes(field)) {
            this.updateTotal(index);
        }
    }

    // ─── Packing Size change ──────────────────────────────────────────────────
    handlePackingSizeChange(event) {
        const index        = parseInt(event.target.dataset.index);
        const selectedSize = event.detail.value;
        const row          = this.filteredData[index].recordData;

        row.selectedPackingSize = selectedSize;

        const packingDetails = row.packingDetails || [];
        const matchedDetail  = packingDetails.find(pd => pd.packingSize === selectedSize);

        // ✅ rawPackingQuantity = DRC_NBC_Packing_Qauntity__c from child record
        row.rawPackingQuantity = (matchedDetail?.packingQuantity != null && matchedDetail.packingQuantity !== '')
            ? String(matchedDetail.packingQuantity) : '';

        // ✅ Packing quantity column = DB value directly, NOT a calculation
        row.packingQuantity = row.rawPackingQuantity;

        // ✅ Validate current quantity against new packing size
        row.quantityError = this._getQuantityError(row.Quantity, row.rawPackingQuantity);

        this.filteredData = [...this.filteredData];
    }

    // ─── Quantity change ──────────────────────────────────────────────────────
    handleQuantityChange(event) {
        const index    = parseInt(event.target.dataset.index);
        const quantity = parseFloat(event.target.value) || 0;
        const row      = this.filteredData[index].recordData;

        row.Quantity = quantity;

        // ✅ Validate: quantity must be a multiple of rawPackingQuantity
        row.quantityError = this._getQuantityError(quantity, row.rawPackingQuantity);

        // packingQuantity column does NOT change when quantity changes —
        // it always shows DRC_NBC_Packing_Qauntity__c from the DB record

        this.updateTotal(index);
        this.filteredData = [...this.filteredData];
    }

    handleModifiedPriceChange(event) {
        const index  = parseInt(event.target.dataset.index);
        const value  = parseFloat(event.target.value) || 0;
        let record   = this.filteredData[index].recordData;

        record.modifiedPrice = value;
        const basePrice      = parseFloat(record.OriginalUnitPrice) || 0;
        record.modifier      = (value - basePrice).toFixed(2);

        this.updateTotal(index);
        this.filteredData = [...this.filteredData];
    }

    handleProductSelect(event) {
        const index       = parseInt(event.target.dataset.index);
        const selectedId  = event.target.dataset.id;
        const selectedProduct = this.productsMasterList.find(p => p.Id === selectedId);

        if (selectedProduct) {
            const unitPrice = selectedProduct.UnitPrice || 0;

            // ✅ Fetch packing details from cached map for selected product
            const packingDetails     = this.getPackingDetailsForProduct(selectedProduct.Product2Id);
            const packingSizeOptions = this.buildPackingSizeOptions(packingDetails);

            this.filteredData[index].recordData = {
                ...this.filteredData[index].recordData,
                showSearch:                     false,
                Name:                           selectedProduct.Product2.Name,
                Product2Id:                     selectedProduct.Product2.Id,
                Description:                    selectedProduct.Product2.Description,
                UnitPrice:                      unitPrice,
                OriginalUnitPrice:              unitPrice,
                DRC_NBC_FG_Code__c:             selectedProduct.Product2.DRC_NBC_FG_Code__c,
                DRC_NBC_HSN_SAC_Code__c:        selectedProduct.Product2.DRC_NBC_HSN_SAC_Code__c,
                PricebookEntryId:               selectedProduct.Id,
                DRC_NBC_Unit_Of_Measurement__c: selectedProduct.Product2.QuantityUnitOfMeasure,
                modifier:                       0,
                modifiedPrice:                  unitPrice,
                searchResults:                  [],
                noResultsFound:                 false,
                packingDetails,
                packingSizeOptions,
                selectedPackingSize:            '',
                rawPackingQuantity:             '',
                packingQuantity:                '',   // blank until packing size selected
                quantityError:                  ''
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
            qlis: {
                Id:                             '',
                Name:                           '',
                PricebookEntryId:               '',
                Description:                    '',
                Discount:                       0,
                ListPrice:                      0,
                Product2Id:                     '',
                Quantity:                       1,
                UnitPrice:                      0,
                OriginalUnitPrice:              0,
                ProductName:                    '',
                DRC_NBC_FG_Code__c:             '',
                DRC_NBC_HSN_SAC_Code__c:        '',
                QuantityUnitOfMeasure:          '',
                modifier:                       0,
                modifiedPrice:                  0,
                totalAmount:                    0,
                showSearch:                     true,
                searchResults:                  [],
                noResultsFound:                 false,
                packingDetails:                 [],
                packingSizeOptions:             [],
                selectedPackingSize:            '',
                rawPackingQuantity:             '',
                packingQuantity:                '',
                quantityError:                  ''
            }
        };
    }

    updateTotal(index) {
        let record      = this.filteredData[index].recordData;
        const modifiedPrice = parseFloat(record.modifiedPrice) || 0;
        const quantity      = parseFloat(record.Quantity)      || 0;
        const discount      = parseFloat(record.Discount)      || 0;
    }
}