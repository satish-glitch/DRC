import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';

import getExistingOLIs from '@salesforce/apex/DRC_NBC_OpportunityProductsController.getExistingOLIs';
import searchProducts  from '@salesforce/apex/DRC_NBC_OpportunityProductsController.searchProducts';
import saveOLIData     from '@salesforce/apex/DRC_NBC_OpportunityProductsController.saveOLIData';
import AddProductCSS   from '@salesforce/resourceUrl/DRC_NBC_Order_Button_CSS';

// How many multiples to generate for the Quantity combobox
const QUANTITY_MULTIPLES_COUNT = 20;

export default class Drc_nbc_addProductsToOpportunity extends LightningElement {

    _oppId      = null;
    _dataLoaded = false;

    @api
    get recordId() {
        return this._oppId;
    }
    set recordId(value) {
        console.log('[LWC recordId setter] received:', value);
        if (value && value !== this._oppId) {
            this._oppId = value;
            this._tryLoad();
        }
    }

    @api
    setRecordId(id) {
        console.log('[LWC setRecordId] received:', id);
        if (id && id !== this._oppId) {
            this._oppId = id;
            this._tryLoad();
        }
    }

    @track filteredData  = [];
    @track showLoading   = false;
    @track isProductOpen = true;

    oliIdsToDelete    = [];
    packingDetailsMap = {};
    _rowCounter       = 0;
    _searchTimers     = {};

    connectedCallback() {
        loadStyle(this, AddProductCSS).catch(() => {});
        this._tryLoad();
    }

    _tryLoad() {
        if (this._dataLoaded || !this._oppId) return;
        this._dataLoaded = true;
        this.fetchOLIData();
    }

    // ─── Getters ──────────────────────────────────────────────────────────────
    toggleProduct() { this.isProductOpen = !this.isProductOpen; }

    get getProductClass() {
        return `slds-section slds-m-top_medium ${this.isProductOpen ? 'slds-is-open' : ''}`;
    }
    get getProductIcon() {
        return this.isProductOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }
    get hasProducts() {
        return this.filteredData && this.filteredData.length > 0;
    }

    // ─── Packing helpers ─────────────────────────────────────────────────────

    _buildPackingSizeOptions(list) {
        if (!list || list.length === 0) return [];
        return list.map(pd => ({ label: pd.packingSize || '', value: pd.packingSize || '' }));
    }

    _getPackingDetailsForProduct(product2Id) {
        if (!product2Id) return [];
        return this.packingDetailsMap[product2Id] || [];
    }

    /**
     * Returns the raw packingQuantity (DRC_NBC_Packing_Qauntity__c) of the
     * currently selected packing size — this is what is shown in the
     * "Packing Qty" column.
     */
    _getRawPackingQty(rowData) {
        const pkgQty = parseFloat(rowData.rawPackingQuantity) || 0;
        return pkgQty > 0 ? String(pkgQty) : '';
    }

    /**
     * Builds combobox options for Quantity as multiples of the packing quantity.
     * e.g. packingQty = 100 → [100, 200, 300 … 2000]
     * If no packing size is selected, returns [] so a plain number input is used.
     */
    _buildQuantityOptions(rawPackingQty) {
        const pkgQty = parseFloat(rawPackingQty) || 0;
        if (pkgQty <= 0) return [];
        const options = [];
        for (let i = 1; i <= QUANTITY_MULTIPLES_COUNT; i++) {
            const val = String(pkgQty * i);
            options.push({ label: val, value: val });
        }
        return options;
    }

    /**
     * Validates that the entered quantity is a positive multiple of packingQty.
     * Returns an error string or '' if valid.
     */
    _validateQuantity(qty, rawPackingQty) {
        const pkgQty = parseFloat(rawPackingQty) || 0;
        const q      = parseFloat(qty) || 0;
        if (q <= 0) return 'Quantity must be greater than 0.';
        if (pkgQty > 0 && q % pkgQty !== 0) {
            return `Quantity must be a multiple of ${pkgQty}.`;
        }
        return '';
    }

    // ─── Load existing OLIs ───────────────────────────────────────────────────
    fetchOLIData() {
        this.showLoading = true;
        getExistingOLIs({ opportunityId: this._oppId })
            .then(data => {
                this.packingDetailsMap = data.packingDetailsMap || {};
                if (data.olis && data.olis.length > 0) {
                    this._buildRowsFromOLIs(data.olis);
                } else {
                    this.filteredData = [{ recordData: this._newBaseRow() }];
                }
            })
            .catch(error => {
                this._toast('Error', error?.body?.message || error?.message || 'Error loading data', 'error');
            })
            .finally(() => { this.showLoading = false; });
    }

    _buildRowsFromOLIs(olis) {
        this.filteredData = olis.map(item => {
            const packingDetails     = this._getPackingDetailsForProduct(item.Product2Id);
            const packingSizeOptions = this._buildPackingSizeOptions(packingDetails);
            const savedPackingSize   = item.DRC_NBC_Packing_Size__c      || '';
            // DRC_NBC_Packing_Qauntity__c stored on OLI is the raw packing qty
            const savedPackingQty    = item.DRC_NBC_Packing_Qauntity__c  || '';

            let rawPackingQuantity = '';
            if (savedPackingSize) {
                const matched      = packingDetails.find(pd => pd.packingSize === savedPackingSize);
                rawPackingQuantity = matched ? (matched.packingQuantity || '') : savedPackingQty;
            }

            const quantityOptions = this._buildQuantityOptions(rawPackingQuantity);

            const prod = item.Product2 || {};
            return {
                recordData: {
                    ...this._newBaseRow(),
                    Id:                             item.Id,
                    Name:                           prod.Name                    || '',
                    PricebookEntryId:               item.PricebookEntryId        || '',
                    Description:                    item.Description             || '',
                    Discount:                       item.Discount                || 0,
                    Product2Id:                     item.Product2Id              || '',
                    Quantity:                       item.Quantity                || 1,
                    UnitPrice:                      item.UnitPrice               || 0,
                    DRC_NBC_FG_Code__c:             prod.DRC_NBC_FG_Code__c      || '-',
                    DRC_NBC_HSN_SAC_Code__c:        prod.DRC_NBC_HSN_SAC_Code__c || '-',
                    DRC_NBC_Unit_Of_Measurement__c: prod.QuantityUnitOfMeasure   || '-',
                    showSearch:                     false,
                    packingDetails,
                    packingSizeOptions,
                    selectedPackingSize:            savedPackingSize,
                    rawPackingQuantity,
                    // "Packing Qty" column = the raw packing unit qty (e.g. 100)
                    packingQuantity:                rawPackingQuantity,
                    quantityOptions,
                    quantityError:                  ''
                }
            };
        });
    }

    _newBaseRow() {
        return {
            rowKey:                         ++this._rowCounter,
            Id:                             null,
            Name:                           '',
            PricebookEntryId:               '',
            Description:                    '',
            Discount:                       0,
            Product2Id:                     '',
            Quantity:                       1,
            UnitPrice:                      0,
            ProductName:                    '',
            DRC_NBC_FG_Code__c:             '',
            DRC_NBC_HSN_SAC_Code__c:        '',
            DRC_NBC_Unit_Of_Measurement__c: '',
            showSearch:                     true,
            searchResults:                  [],
            noResultsFound:                 false,
            isSearching:                    false,
            packingDetails:                 [],
            packingSizeOptions:             [],
            selectedPackingSize:            '',
            rawPackingQuantity:             '',
            packingQuantity:                '',   // raw packing unit qty shown in column
            quantityOptions:                [],   // multiples combobox options
            quantityError:                  ''
        };
    }

    // ─── Row management ───────────────────────────────────────────────────────
    handleAddRow() {
        this.filteredData = [...this.filteredData, { recordData: this._newBaseRow() }];
    }

    handleRemoveRow(event) {
        const index = parseInt(event.currentTarget.dataset.index);
        const id    = event.currentTarget.dataset.id;
        if (id) this.oliIdsToDelete.push(id);
        const updated = [...this.filteredData];
        updated.splice(index, 1);
        this.filteredData = updated;
    }

    handleClearProduct(event) {
        const index     = parseInt(event.currentTarget.dataset.index);
        const freshRow  = this._newBaseRow();
        freshRow.rowKey = this.filteredData[index].recordData.rowKey;
        const updated   = [...this.filteredData];
        updated[index]  = { recordData: freshRow };
        this.filteredData = updated;
    }

    // ─── Product search ───────────────────────────────────────────────────────
    handleValueChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.name;
        const value = event.target.value;

        const updated = [...this.filteredData];
        updated[index] = { recordData: { ...updated[index].recordData, [field]: value } };

        if (field === 'ProductName') {
            if (value && value.length >= 2) {
                updated[index].recordData.isSearching    = true;
                updated[index].recordData.searchResults  = [];
                updated[index].recordData.noResultsFound = false;
                this.filteredData = updated;

                clearTimeout(this._searchTimers[index]);
                this._searchTimers[index] = setTimeout(() => {
                    this._callSearchApex(index, value);
                }, 300);
            } else {
                clearTimeout(this._searchTimers[index]);
                updated[index].recordData.isSearching    = false;
                updated[index].recordData.searchResults  = [];
                updated[index].recordData.noResultsFound = false;
                this.filteredData = updated;
            }
        } else {
            this.filteredData = updated;
        }
    }

    _callSearchApex(index, searchTerm) {
        if (!this._oppId) {
            this._toast('Error', 'Opportunity ID not available. Please close and reopen.', 'error');
            return;
        }
        searchProducts({ searchTerm, opportunityId: this._oppId })
        .then(results => {
            const updated = [...this.filteredData];
            if (!updated[index]) return;
            updated[index] = {
                recordData: {
                    ...updated[index].recordData,
                    searchResults:  results || [],
                    noResultsFound: !results || results.length === 0,
                    isSearching:    false
                }
            };
            this.filteredData = updated;
        })
        .catch(err => {
            console.error('[search] error:', err);
            const updated = [...this.filteredData];
            if (!updated[index]) return;
            updated[index] = {
                recordData: {
                    ...updated[index].recordData,
                    searchResults:  [],
                    noResultsFound: true,
                    isSearching:    false
                }
            };
            this.filteredData = updated;
            this._toast('Error', err?.body?.message || 'Error searching products', 'error');
        });
    }

    handleProductSelect(event) {
        const index      = parseInt(event.currentTarget.dataset.index);
        const selectedId = event.currentTarget.dataset.id;
        const selected   = this.filteredData[index].recordData.searchResults
                               .find(r => r.pricebookEntryId === selectedId);
        if (!selected) return;

        if (selected.packingDetails && selected.packingDetails.length > 0) {
            this.packingDetailsMap = {
                ...this.packingDetailsMap,
                [selected.product2Id]: selected.packingDetails
            };
        }
        const packingDetails     = selected.packingDetails || [];
        const packingSizeOptions = this._buildPackingSizeOptions(packingDetails);

        const updated = [...this.filteredData];
        updated[index] = {
            recordData: {
                ...updated[index].recordData,
                showSearch:                     false,
                Name:                           selected.product2Name,
                Product2Id:                     selected.product2Id,
                PricebookEntryId:               selected.pricebookEntryId,
                Description:                    selected.description  || '',
                UnitPrice:                      selected.unitPrice    || 0,
                DRC_NBC_FG_Code__c:             selected.fgCode       || '-',
                DRC_NBC_HSN_SAC_Code__c:        selected.hsnCode      || '-',
                DRC_NBC_Unit_Of_Measurement__c: selected.uom          || '-',
                searchResults:                  [],
                noResultsFound:                 false,
                isSearching:                    false,
                packingDetails,
                packingSizeOptions,
                selectedPackingSize:            '',
                rawPackingQuantity:             '',
                packingQuantity:                '',   // cleared until packing size chosen
                quantityOptions:                [],
                quantityError:                  '',
                Quantity:                       1
            }
        };
        this.filteredData = updated;
    }

    // ─── Field handlers ───────────────────────────────────────────────────────

    /**
     * Quantity change handler.
     * - If packing size is selected → user picks from combobox (multiples), no free input.
     * - If NO packing size → free number input, any positive value allowed.
     */
    handleQuantityChange(event) {
        const index   = parseInt(event.target.dataset.index);
        const updated = [...this.filteredData];
        const row     = updated[index].recordData;
        const newQty  = parseFloat(event.detail ? event.detail.value : event.target.value) || 0;
        const error   = this._validateQuantity(newQty, row.rawPackingQuantity);

        updated[index].recordData = { ...row, Quantity: newQty, quantityError: error };
        this.filteredData = updated;
    }

    handleUnitPriceChange(event) {
        const index   = parseInt(event.target.dataset.index);
        const updated = [...this.filteredData];
        updated[index].recordData.UnitPrice = parseFloat(event.target.value) || 0;
        this.filteredData = updated;
    }

    handlePackingSizeChange(event) {
        const index        = parseInt(event.target.dataset.index);
        const selectedSize = event.detail.value;
        const updated      = [...this.filteredData];
        const row          = { ...updated[index].recordData };

        const packingDetails = row.packingDetails || [];
        const matched        = packingDetails.find(pd => pd.packingSize === selectedSize);
        const rawPkgQty      = matched?.packingQuantity ? String(matched.packingQuantity) : '';

        const quantityOptions = this._buildQuantityOptions(rawPkgQty);

        // Reset quantity to first multiple when packing size changes
        const firstQty = quantityOptions.length > 0 ? parseFloat(quantityOptions[0].value) : row.Quantity;

        row.selectedPackingSize = selectedSize;
        row.rawPackingQuantity  = rawPkgQty;
        // "Packing Qty" column shows the raw packing unit quantity (e.g. 100)
        row.packingQuantity     = rawPkgQty;
        row.quantityOptions     = quantityOptions;
        row.Quantity            = firstQty;
        row.quantityError       = '';

        updated[index] = { recordData: row };
        this.filteredData = updated;
    }

    handleDescriptionChange(event) {
        const index   = parseInt(event.target.dataset.index);
        const updated = [...this.filteredData];
        updated[index].recordData.Description = event.target.value;
        this.filteredData = updated;
    }

    // ─── Save ─────────────────────────────────────────────────────────────────
    handleSave() {
        let isValid = true;
        let rowCount = 0;

        for (const row of this.filteredData) {
            rowCount++;
            const r = row.recordData;

            if (!r.Product2Id) {
                this._toast('Error', `Product required for row ${rowCount}`, 'error');
                isValid = false;
            }

            const qtyError = this._validateQuantity(r.Quantity, r.rawPackingQuantity);
            if (qtyError) {
                this._toast('Error', `Row ${rowCount}: ${qtyError}`, 'error');
                isValid = false;
            }

            if (r.UnitPrice == null || r.UnitPrice < 0) {
                this._toast('Error', `Unit Price required for row ${rowCount}`, 'error');
                isValid = false;
            }
        }
        if (!isValid) return;

        this.showLoading = true;
        const olisToSave = this.filteredData.map(row => {
            const r = row.recordData;
            return {
                Id:                             r.Id || null,
                Product2Id:                     r.Product2Id,
                Quantity:                       r.Quantity,
                UnitPrice:                      parseFloat(r.UnitPrice) || 0,
                Discount:                       r.Discount || 0,
                OpportunityId:                  this._oppId,
                PricebookEntryId:               r.PricebookEntryId,
                Description:                    r.Description || '',
                DRC_NBC_Unit_Of_Measurement__c: r.DRC_NBC_Unit_Of_Measurement__c || '',
                DRC_NBC_Packing_Size__c:        r.selectedPackingSize || '',
                // Save the raw packing unit qty (e.g. 100) to DRC_NBC_Packing_Qauntity__c
                DRC_NBC_Packing_Qauntity__c:    r.rawPackingQuantity || ''
            };
        });

        saveOLIData({ oliList: olisToSave, oliIdsToDelete: this.oliIdsToDelete, opportunityId: this._oppId })
        .then(() => {
            this._toast('Success', 'Products saved successfully', 'success');
            setTimeout(() => { this._goToOpportunity(); }, 1500);
        })
        .catch(error => {
            this._toast('Error', error?.body?.message || error?.message || 'Unknown error', 'error');
            this.showLoading = false;
        });
    }

    // ─── Cancel ───────────────────────────────────────────────────────────────
    handleCancel() {
        this._goToOpportunity();
    }

    _goToOpportunity() {
        if (!this._oppId) return;
        window.location.href = '/' + this._oppId;
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}