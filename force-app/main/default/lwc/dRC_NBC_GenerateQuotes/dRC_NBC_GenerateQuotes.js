import { LightningElement, api, track } from 'lwc';
import getOpportunityContacts    from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.getOpportunityContacts';
import getQuoteMdtDetails        from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.getQuoteMdtDetails';
import searchProducts            from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.searchProducts';
import getAccountBillingAddress  from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.getAccountBillingAddress';
import getAccountAddresses       from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.getAccountAddresses';
import createQuoteWithLines      from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines';
import getExistingOLIs           from '@salesforce/apex/DRC_NBC_GenerateQuotes_Controller.getExistingOLIs';
import { ShowToastEvent }        from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { NavigationMixin }       from 'lightning/navigation';
import { loadStyle }             from 'lightning/platformResourceLoader';
import DRC_NBC_Order_Button_CSS  from '@salesforce/resourceUrl/DRC_NBC_Order_Button_CSS';

export default class DRC_NBC_Generate_Quotes extends NavigationMixin(LightningElement) {
    @api recordId;
    @api objectApiName;
    @track showModal   = true;
    @track isLoading   = false;
    @track quoteRec    = {};
    @track contactOptions       = [];
    @track allContacts          = [];
    @track selectedContactId;
    @track selectedContactName  = '';
    @track selectedContactEmail = '';
    @track selectedContactPhone = '';
    @track selectedContactFax   = '';
    @track billingAddressDisplay = '';
    @track shippingAddressOptions = [];
    @track addrDetails            = [];
    @track selectedShippingId;
    @track currencyCode;
    @track showContactSuggestions = false;
    @track filteredContacts       = [];
    oppCurrency;
    accountSpecialInstruction;
    accountId;

    // Product table
    @track filteredData    = [];
    @track showFilterData  = false;
    @track showAddProducts = true;
    @track productsMasterList = [];

    // Section open/close
    @track isFinancialOpen = true;
    @track isBasicInfoOpen = true;
    @track isPreparedOpen  = true;
    @track isAddressOpen   = true;
    @track isProductOpen   = true;

    toggleBasicInfo()   { this.isBasicInfoOpen = !this.isBasicInfoOpen; }
    togglePrepared()    { this.isPreparedOpen  = !this.isPreparedOpen;  }
    toggleAddressInfo() { this.isAddressOpen   = !this.isAddressOpen;   }
    toggleProduct()     { this.isProductOpen   = !this.isProductOpen;   }
    toggleFinancial()   { this.isFinancialOpen = !this.isFinancialOpen; }

    get getBasicInfoClass()  { return `slds-section ${this.isBasicInfoOpen ? 'slds-is-open' : ''}`; }
    get getPreparedClass()   { return `slds-section slds-m-top_medium ${this.isPreparedOpen  ? 'slds-is-open' : ''}`; }
    get getAddressClass()    { return `slds-section slds-m-top_medium ${this.isAddressOpen   ? 'slds-is-open' : ''}`; }
    get getProductClass()    { return `slds-section slds-m-top_medium ${this.isProductOpen   ? 'slds-is-open' : ''}`; }
    get getFinancialClass()  { return `slds-section slds-m-top_medium ${this.isFinancialOpen ? 'slds-is-open' : ''}`; }
    get getBasicInfoIcon()   { return this.isBasicInfoOpen  ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getPreparedIcon()    { return this.isPreparedOpen   ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getAddressIcon()     { return this.isAddressOpen    ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getProductIcon()     { return this.isProductOpen    ? 'utility:chevrondown' : 'utility:chevronright'; }
    get getFinancialIcon()   { return this.isFinancialOpen  ? 'utility:chevrondown' : 'utility:chevronright'; }
    get isDomestic()         { return this.quoteRec?.DRC_NBC_Type__c === 'Domestic'; }
    get isExport()           { return this.quoteRec?.DRC_NBC_Type__c === 'Export';   }

    // ─── Lifecycle ────────────────────────────────────────────────────────────
    connectedCallback() {
        this.extractRecordIdFromUrl();
        if (!this.recordId) {
            this.showToast('Error', 'No Opportunity ID found. Please try again.', 'error');
            this.isLoading = false;
            return;
        }
        // Default currency before data loads
        this.currencyCode             = 'INR';
        this.quoteRec.CurrencyIsoCode = 'INR';
        this.quoteRec.Status          = 'Draft';
        this.isLoading = true;
        this.initializeComponent();
        this.loadCustomStyles();
    }

    extractRecordIdFromUrl() {
        const url           = window.location.href;
        const recordIdMatch = url.match(/([a-zA-Z0-9]{18})/);
        this.recordId       = recordIdMatch ? recordIdMatch[1] : null;
    }

    loadCustomStyles() {
        Promise.all([loadStyle(this, DRC_NBC_Order_Button_CSS)])
            .then(() => console.log('Styles loaded.'))
            .catch(error => console.error('Error loading styles:', error));
    }

    // ─── Initialise ───────────────────────────────────────────────────────────
    async initializeComponent() {
        try {
            if (!this.recordId) throw new Error('Opportunity ID is missing');

            const [contacts, billingAddress, shippingAddresses, quoteWrapper, oliData] = await Promise.all([
                getOpportunityContacts({ oppId: this.recordId }),
                getAccountBillingAddress({ oppId: this.recordId }),
                getAccountAddresses({ oppId: this.recordId }),
                getQuoteMdtDetails({ oppId: this.recordId }),
                getExistingOLIs({ oppId: this.recordId })
            ]);

            // ── Currency: ALWAYS driven by Opportunity ────────────────────────
            this.oppCurrency              = quoteWrapper.oppCurrency || 'INR';
            this.currencyCode             = this.oppCurrency;
            this.quoteRec.CurrencyIsoCode = this.oppCurrency;

            // ── Account meta ──────────────────────────────────────────────────
            this.accountSpecialInstruction = quoteWrapper.accountSpecialInstruction || '';
            this.accountId                 = quoteWrapper.accountId;
            if (quoteWrapper.accountSpecialInstruction) {
                this.quoteRec.DRC_NBC_Special_Requirements__c = quoteWrapper.accountSpecialInstruction;
            }
            this.quoteRec = {
                ...this.quoteRec,
                DRC_NBC_Payemnt_Term__c:             quoteWrapper.paymentTerm,
                DRC_NBC_Payment_Term_Description__c: quoteWrapper.paymentTermDescription,
                DRC_NBC_Inco_terms__c:               quoteWrapper.incoterms || ''
            };

            // ── Contacts ──────────────────────────────────────────────────────
            this.allContacts    = contacts || [];
            this.contactOptions = this.allContacts.map(c => ({
                label: c.Name, value: c.Id,
                email: c.Email, phone: c.Phone, fax: c.Fax
            }));
            this.filteredContacts = this.contactOptions;

            if (this.contactOptions.length > 0) {
                const first = this.contactOptions[0];
                this.selectedContactId    = first.value;
                this.selectedContactName  = first.label;
                this.selectedContactEmail = first.email || '';
                this.selectedContactPhone = first.phone || '';
                this.selectedContactFax   = first.fax   || '';
                this.quoteRec.ContactId   = first.value;
                this.quoteRec.Email       = first.email || '';
                this.quoteRec.Phone       = first.phone || '';
                this.quoteRec.Fax         = first.fax   || '';
            }

            // ── Billing address ───────────────────────────────────────────────
            if (billingAddress) {
                const parts = [
                    billingAddress.street, billingAddress.city, billingAddress.state,
                    billingAddress.postalCode, billingAddress.country
                ].filter(Boolean);
                this.billingAddressDisplay       = parts.join(', ') || 'No billing address found';
                this.quoteRec.BillingStreet      = billingAddress.street      || '';
                this.quoteRec.BillingCity        = billingAddress.city        || '';
                this.quoteRec.BillingState       = billingAddress.state       || '';
                this.quoteRec.BillingPostalCode  = billingAddress.postalCode  || '';
                this.quoteRec.BillingCountry     = billingAddress.country     || '';
                this.quoteRec.BillingCountryCode = billingAddress.countryCode || '';
            }

            // ── Shipping addresses ────────────────────────────────────────────
            this.addrDetails            = shippingAddresses || [];
            this.shippingAddressOptions = [];
            (shippingAddresses || []).forEach(addr => {
                const d     = addr.DRC_NBC_Address__c;
                const parts = [d?.street, d?.city, d?.postalCode, d?.country, d?.state].filter(Boolean);
                this.shippingAddressOptions.push({
                    label: parts.join(', ') || 'Unknown Address',
                    value: addr.Id
                });
            });
            if (this.shippingAddressOptions.length === 1) {
                this.selectedShippingId = this.shippingAddressOptions[0].value;
                this.updateShippingAddress(this.selectedShippingId);
            }

            // ── Pre-populate from existing OLIs ───────────────────────────────
            if (oliData && oliData.olis && oliData.olis.length > 0) {
                this._buildRowsFromOLIs(oliData.olis, oliData.packingDetailsMap || {});
                this.showFilterData  = true;
                this.showAddProducts = false;
            } else {
                this.filteredData    = [];
                this.showFilterData  = false;
                this.showAddProducts = true;
            }

        } catch (error) {
            console.error('Initialization Error:', error);
            this.showToast('Error', 'Failed to load: ' + (error.body?.message || error.message), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ─── Build rows from existing OLIs ────────────────────────────────────────
    // Priority for Hazardous & Marks & Nos:
    //   1. OLI's own saved field value (previously saved on the line item)
    //   2. Fall back to Product2 default (for lines that never had a value saved)
    _buildRowsFromOLIs(olis, packingDetailsMap) {
        this.filteredData = olis.map(item => {
            const prod             = item.Product2 || {};
            const product2Id       = item.Product2Id || '';
            const packingDetails   = packingDetailsMap[product2Id] || [];
            const packingSizeOpts  = this._buildPackingSizeOptions(packingDetails);
            const savedPackingSize = item.DRC_NBC_Packing_Size__c || '';
            const quantity         = item.Quantity || 1;

            let rawPackingQuantity = '';
            if (savedPackingSize) {
                const matched      = packingDetails.find(pd => pd.packingSize === savedPackingSize);
                rawPackingQuantity = matched ? (matched.packingQuantity || '') : '';
            }

            const packingQuantity = rawPackingQuantity;
            const quantityError   = this._getQuantityError(quantity, rawPackingQuantity);
            const unitPrice       = item.UnitPrice || 0;

            // ── Hazardous: OLI saved value wins; fall back to Product2 default ──
            const hazardous = (item.DRC_NBC_Hazardous__c != null)
                ? item.DRC_NBC_Hazardous__c
                : (prod.DRC_NBC_Hazardous__c || false);

            // ── Marks & Nos: OLI saved value wins; fall back to Product2 default ─
            const marksAndNos = (item.DRC_NBC_MARKS_NOS__c != null && item.DRC_NBC_MARKS_NOS__c !== '')
                ? item.DRC_NBC_MARKS_NOS__c
                : (prod.DRC_NBC_MARKS_NOS__c || '');

            return {
                id: item.Id || String(Date.now() + Math.random()),
                recordData: {
                    ...this.getBaseRecordData(),
                    Id:                             item.Id,
                    Name:                           prod.Name                    || '',
                    ProductName:                    prod.Name                    || '',
                    Product2Id:                     product2Id,
                    PricebookEntryId:               item.PricebookEntryId        || '',
                    Description:                    item.Description             || '',
                    Discount:                       item.Discount                || 0,
                    Quantity:                       quantity,
                    UnitPrice:                      unitPrice,
                    OriginalUnitPrice:              unitPrice,
                    modifiedPrice:                  unitPrice,
                    DRC_NBC_FG_Code__c:             prod.DRC_NBC_FG_Code__c      || '-',
                    DRC_NBC_HSN_SAC_Code__c:        prod.DRC_NBC_HSN_SAC_Code__c || '-',
                    DRC_NBC_Unit_Of_Measurement__c: prod.QuantityUnitOfMeasure   || '-',
                    showSearch:                     false,
                    packingDetails,
                    packingSizeOptions:             packingSizeOpts,
                    selectedPackingSize:            savedPackingSize,
                    DRC_NBC_Hazardous__c:           hazardous,    // OLI value → Product2 fallback
                    DRC_NBC_MARKS_NOS__c:           marksAndNos,  // OLI value → Product2 fallback
                    rawPackingQuantity,
                    packingQuantity,
                    quantityError
                }
            };
        });
    }

    _buildPackingSizeOptions(packingDetails) {
        if (!packingDetails || packingDetails.length === 0) return [];
        return packingDetails.map(pd => ({ label: pd.packingSize || '', value: pd.packingSize || '' }));
    }

    // ─── "Add Products" — first row ───────────────────────────────────────────
    handleAddFirstRow() {
        this.filteredData    = [{ id: String(Date.now()), recordData: this.getBaseRecordData() }];
        this.showFilterData  = true;
        this.showAddProducts = false;
    }

    handleAddRow() {
        this.filteredData = [...this.filteredData, { id: String(Date.now()), recordData: this.getBaseRecordData() }];
    }

    handleRemoveRow(event) {
        const index = parseInt(event.target.dataset.index);
        this.filteredData.splice(index, 1);
        if (this.filteredData.length === 0) {
            this.showAddProducts = true;
            this.showFilterData  = false;
        } else {
            this.filteredData = [...this.filteredData];
        }
    }

    handleClearProduct(event) {
        const index = parseInt(event.currentTarget.dataset.index);
        this.filteredData[index].recordData = this.getBaseRecordData();
        this.filteredData = [...this.filteredData];
    }

    // ─── Contact search ───────────────────────────────────────────────────────
    handleContactInputFocus() {
        this.filteredContacts       = this.contactOptions;
        this.showContactSuggestions = true;
    }
    handleContactInputBlur() {
        setTimeout(() => { this.showContactSuggestions = false; }, 200);
    }
    handleContactInputChange(event) {
        const searchKey          = event.target.value;
        this.selectedContactName = searchKey;
        if (!searchKey) {
            this.selectedContactId    = null;
            this.selectedContactEmail = '';
            this.selectedContactPhone = '';
            this.selectedContactFax   = '';
            this.quoteRec.ContactId   = null;
            this.quoteRec.Email       = '';
            this.quoteRec.Phone       = '';
            this.quoteRec.Fax         = '';
            this.filteredContacts       = [];
            this.showContactSuggestions = true;
            return;
        }
        this.filteredContacts = this.contactOptions.filter(c =>
            c.label.toLowerCase().includes(searchKey.toLowerCase())
        );
        this.showContactSuggestions = true;
    }
    handleContactSelect(event) {
        const selectedId         = event.currentTarget.dataset.id;
        const selectedName       = event.currentTarget.dataset.name;
        this.selectedContactId   = selectedId;
        this.selectedContactName = selectedName;
        const c = this.contactOptions.find(x => x.value === selectedId);
        if (c) {
            this.selectedContactEmail = c.email || '';
            this.selectedContactPhone = c.phone || '';
            this.selectedContactFax   = c.fax   || '';
        }
        this.quoteRec.ContactId = selectedId;
        this.quoteRec.Email     = this.selectedContactEmail;
        this.quoteRec.Phone     = this.selectedContactPhone;
        this.quoteRec.Fax       = this.selectedContactFax;
        this.showContactSuggestions = false;
    }

    // ─── Address ──────────────────────────────────────────────────────────────
    handleAddressChange(event) {
        this.selectedShippingId = event.detail.value;
        this.updateShippingAddress(this.selectedShippingId);
    }
    updateShippingAddress(addressId) {
        const selectedAddr = this.addrDetails.find(a => a.Id === addressId);
        if (!selectedAddr) return;
        const addr = selectedAddr.DRC_NBC_Address__c;
        if (!addr || typeof addr !== 'object') return;
        this.quoteRec.DRC_NBC_Shipping_Address_Id__c = addressId;
        this.quoteRec.ShippingStreet      = addr.street      || '';
        this.quoteRec.ShippingCity        = addr.city        || '';
        this.quoteRec.ShippingPostalCode  = addr.postalCode  || '';
        this.quoteRec.ShippingCountry     = addr.country     || '';
        this.quoteRec.ShippingCountryCode = addr.countryCode || '';
        this.quoteRec.ShippingStateCode   = addr.stateCode   || '';
    }

    handleFieldChange(event) {
        try {
            const fieldName = event.target.fieldName || event.target.dataset.field;
            const value     = event.detail?.value    || event.target.value;
            if (fieldName) {
                this.quoteRec[fieldName] = value;
            }
        } catch (error) {
            console.error('Error in handleFieldChange:', error);
        }
    }

    // ─── Product name search ──────────────────────────────────────────────────
   /* handleValueChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.name;
        const value = event.target.value;

        this.filteredData[index].recordData[field] = value;

        if (field === 'ProductName' && value.length >= 2) {
            searchProducts({
                keyword:         value,
                currencyIsoCode: this.currencyCode,
                accountId:       this.accountId
            })
            .then(results => {
                // Exclude products already selected in other rows
                const selectedProductIds = this.filteredData
                    .filter((_, i) => i !== index)
                    .map(row => row.recordData.Product2Id)
                    .filter(Boolean);

                const filteredResults = results.filter(
                    r => !selectedProductIds.includes(r.Product2Id)
                );

                this.filteredData[index].recordData.searchResults  = filteredResults;
                this.filteredData[index].recordData.noResultsFound = filteredResults.length === 0;
                this.filteredData = [...this.filteredData];
            })
            .catch(error => {
                console.error('Product search error:', error);
                this.filteredData[index].recordData.searchResults  = [];
                this.filteredData[index].recordData.noResultsFound = false;
                this.filteredData = [...this.filteredData];
            });
        } else if (field === 'ProductName' && value.length < 2) {
            this.filteredData[index].recordData.searchResults  = [];
            this.filteredData[index].recordData.noResultsFound = false;
            this.filteredData = [...this.filteredData];
        }
    } */

    handleValueChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.name;
        const value = event.target.value;

        this.filteredData[index].recordData[field] = value;

        if (field === 'ProductName' && value.length >= 2) {
            searchProducts({
                keyword:         value,
                currencyIsoCode: this.currencyCode,
                accountId:       this.accountId
            })
            .then(results => {
                this.filteredData[index].recordData.searchResults  = results;
                this.filteredData[index].recordData.noResultsFound = results.length === 0;
                this.filteredData = [...this.filteredData];
            })
            .catch(error => {
                console.error('Product search error:', error);
                this.filteredData[index].recordData.searchResults  = [];
                this.filteredData[index].recordData.noResultsFound = false;
                this.filteredData = [...this.filteredData];
            });
        } else if (field === 'ProductName' && value.length < 2) {
            this.filteredData[index].recordData.searchResults  = [];
            this.filteredData[index].recordData.noResultsFound = false;
            this.filteredData = [...this.filteredData];
        }
    }

    buildPackingSizeOptions(packingDetails) {
        if (!packingDetails || packingDetails.length === 0) return [];
        return packingDetails.map(pd => ({ label: pd.packingSize || '', value: pd.packingSize || '' }));
    }

    handleCheckboxChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.name;
        this.filteredData[index].recordData[field] = event.target.checked;
        this.filteredData = [...this.filteredData];
    }

    // ─── Product select from search dropdown ──────────────────────────────────
    // Pre-populates Hazardous and Marks & Nos from Product2 defaults.
    // User can still edit both fields after selection.
    handleProductSelect(event) {
        const index      = parseInt(event.target.dataset.index);
        const selectedId = event.target.dataset.id;
        const selected   = this.filteredData[index].recordData.searchResults
                               .find(p => p.PricebookEntryId === selectedId);
        if (selected) {
            const unitPrice          = selected.UnitPrice || 0;
            const packingDetails     = selected.PackingDetails || [];
            const packingSizeOptions = this.buildPackingSizeOptions(packingDetails);

            this.filteredData[index].recordData = {
                ...this.filteredData[index].recordData,
                showSearch:                     false,
                ProductName:                    selected.Name,
                Name:                           selected.Name,
                Product2Id:                     selected.Product2Id,
                Description:                    selected.Name,
                UnitPrice:                      unitPrice,
                OriginalUnitPrice:              unitPrice,
                DRC_NBC_HSN_SAC_Code__c:        selected.HSNCode               || '-',
                DRC_NBC_FG_Code__c:             selected.FGCode                || '-',
                PricebookEntryId:               selected.PricebookEntryId,
                DRC_NBC_Unit_Of_Measurement__c: selected.QuantityUnitOfMeasure || '-',
                modifiedPrice:                  unitPrice,
                packingDetails,
                packingSizeOptions,
                selectedPackingSize:            '',
                packingQuantity:                '',
                rawPackingQuantity:             '',
                searchResults:                  [],
                noResultsFound:                 false,
                quantityError:                  '',
                // ── Pre-fill from Product2 defaults; user can override ──────────
                DRC_NBC_Hazardous__c: (selected.IsHazardous  != null) ? selected.IsHazardous  : false,
                DRC_NBC_MARKS_NOS__c: (selected.MarksAndNos  != null) ? selected.MarksAndNos  : ''
            };
            this.filteredData = [...this.filteredData];
        }
    }

    // ─── Packing Size change ──────────────────────────────────────────────────
    handlePackingSizeChange(event) {
        const index        = parseInt(event.target.dataset.index);
        const selectedSize = event.detail.value;
        const row          = this.filteredData[index].recordData;

        row.selectedPackingSize = selectedSize;

        const packingDetails = row.packingDetails || [];
        const matched        = packingDetails.find(pd => pd.packingSize === selectedSize);

        row.rawPackingQuantity = (matched?.packingQuantity != null && matched.packingQuantity !== '')
            ? String(matched.packingQuantity) : '';

        row.packingQuantity = row.rawPackingQuantity;
        row.quantityError   = this._getQuantityError(row.Quantity, row.rawPackingQuantity);

        this.filteredData = [...this.filteredData];
    }

    // ─── Quantity change ──────────────────────────────────────────────────────
    handleQuantityChange(event) {
        const index    = parseInt(event.target.dataset.index);
        const quantity = parseFloat(event.target.value) || 0;
        const row      = this.filteredData[index].recordData;

        row.Quantity      = quantity;
        row.quantityError = this._getQuantityError(quantity, row.rawPackingQuantity);

        this.filteredData = [...this.filteredData];
    }

    /**
     * Returns an error message string if qty is invalid, or '' if valid.
     * A quantity is valid when:
     *  - no packing size has been selected (rawPackingQty is blank), OR
     *  - qty > 0 AND qty is an exact multiple of rawPackingQty
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

    _recalcPackingQuantity(rowData) {
        return rowData.rawPackingQuantity || '';
    }

    handleModifiedPriceChange(event) {
        const index = parseInt(event.target.dataset.index);
        const value = parseFloat(event.target.value) || 0;
        this.filteredData[index].recordData.modifiedPrice = value;
        this.filteredData = [...this.filteredData];
    }

    getBaseRecordData() {
        return {
            Id:                             null,
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
            DRC_NBC_HSN_SAC_Code__c:        '-',
            DRC_NBC_FG_Code__c:             '-',
            DRC_NBC_Unit_Of_Measurement__c: '-',
            modifiedPrice:                  0,
            packingDetails:                 [],
            packingSizeOptions:             [],
            selectedPackingSize:            '',
            packingQuantity:                '',
            rawPackingQuantity:             '',
            showSearch:                     true,
            searchResults:                  [],
            noResultsFound:                 false,
            quantityError:                  '',
            DRC_NBC_Hazardous__c:           false,
            DRC_NBC_MARKS_NOS__c:           ''
        };
    }

    // ─── Validation ───────────────────────────────────────────────────────────
    validateQuoteData() {
        if (!this.quoteRec.ExpirationDate) {
            this.showToast('Error', 'Please enter Expiration Date.', 'error'); return false;
        }
        if (!this.quoteRec.DRC_NBC_Lead_Time__c) {
            this.showToast('Error', 'Please enter Lead Date.', 'error'); return false;
        }
        const expirationDate = new Date(this.quoteRec.ExpirationDate + 'T00:00:00');
        const today          = new Date();
        const todayDate      = new Date(
            `${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}T00:00:00`
        );
        if (expirationDate <= todayDate) {
            this.showToast('Error', 'Expiration Date must be greater than today.', 'error'); return false;
        }
        if (!this.selectedContactId)    { this.showToast('Error', 'Please select a contact.', 'error');                     return false; }
        if (!this.selectedContactEmail) { this.showToast('Error', 'Selected contact must have an email address.', 'error'); return false; }
        if (!this.selectedContactPhone) { this.showToast('Error', 'Selected contact must have a phone number.', 'error');   return false; }
        if (!this.quoteRec.DRC_NBC_Payment_Term_Description__c) { this.showToast('Error', 'Payment Term Description is required.', 'error'); return false; }
        if (!this.quoteRec.DRC_NBC_Inco_terms__c)               { this.showToast('Error', 'Inco Term is required.', 'error');                return false; }
        if (!this.quoteRec.DRC_NBC_Type__c)                     { this.showToast('Error', 'Type is required.', 'error');                     return false; }
        if (!this.quoteRec.CurrencyIsoCode)                     { this.showToast('Error', 'Currency is required.', 'error');                 return false; }
        if (!this.selectedShippingId)                           { this.showToast('Error', 'Please select Shipping Address.', 'error');        return false; }
        if (this.filteredData.length === 0)                     { this.showToast('Error', 'Please add at least one product.', 'error');      return false; }

        for (let i = 0; i < this.filteredData.length; i++) {
            const row = this.filteredData[i].recordData;
            if (!row.Product2Id) {
                this.showToast('Error', `Please select a product for row ${i + 1}.`, 'error'); return false;
            }
            if (!row.Quantity || row.Quantity <= 0) {
                this.showToast('Error', `Enter valid quantity for row ${i + 1}.`, 'error'); return false;
            }
            if (row.quantityError) {
                this.showToast('Error', `Row ${i + 1}: ${row.quantityError}`, 'error'); return false;
            }
                    // Product has no packing size data configured at all
            if (!row.packingSizeOptions || row.packingSizeOptions.length === 0) {
                this.showToast(
                    'Error',
                    `Row ${i + 1}: "${row.ProductName || row.Name}" has no Packing Size configured and cannot be added to this quote. Please select a different product.`,
                    'error'
                );
                return false;
            }
            // Product has packing sizes available but user hasn't picked one
            if (!row.selectedPackingSize) {
                this.showToast(
                    'Error',
                    `Row ${i + 1}: Please select a Packing Size for "${row.ProductName || row.Name}".`,
                    'error'
                );
                return false;
            }
        }
        return true;
    }

    // ─── Save ─────────────────────────────────────────────────────────────────
    async handleSave() {
        this.isLoading = true;
        if (!this.validateQuoteData()) { this.isLoading = false; return; }

        try {
            const lineItems = this.filteredData.map(item => {
                const row = item.recordData;
                return {
                    Product2Id:            row.Product2Id,
                    PricebookEntryId:      row.PricebookEntryId,
                    Quantity:              row.Quantity              || 1,
                    UnitPrice:             row.modifiedPrice         || row.UnitPrice || 0,
                    Description:           row.Description           || '',
                    CurrencyIsoCode:       this.currencyCode         || 'INR',
                    QuantityUnitOfMeasure: row.DRC_NBC_Unit_Of_Measurement__c || '',
                    PackingSize:           row.selectedPackingSize   || '',
                    PackingQuantity:       row.packingQuantity       || '',
                    // User-edited values (may differ from Product2 defaults)
                    hazardous:   row.DRC_NBC_Hazardous__c != null ? row.DRC_NBC_Hazardous__c : false,
                    marksAndNos: row.DRC_NBC_MARKS_NOS__c || ''
                };
            });

            const result = await createQuoteWithLines({
                oppId:     this.recordId,
                quoteData: this.quoteRec,
                lineItems
            });

            const parsed = JSON.parse(result);
            if (parsed.success) {
                this.showToast('Success', 'Quote created successfully!', 'success');
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: { recordId: parsed.quoteId, objectApiName: 'Quote', actionName: 'view' }
                });
                this.handleCancel();
            } else {
                throw new Error(parsed.error || 'Unknown error occurred while creating quote');
            }
        } catch (error) {
            console.error('Error creating quote:', error);
            this.showToast('Error', error.body?.message || error.message || 'Unexpected error', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.showModal = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}