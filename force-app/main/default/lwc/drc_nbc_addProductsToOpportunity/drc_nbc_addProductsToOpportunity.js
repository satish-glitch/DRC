import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadStyle } from 'lightning/platformResourceLoader';

import getExistingOLIs from '@salesforce/apex/DRC_NBC_OpportunityProductsController.getExistingOLIs';
import searchProducts  from '@salesforce/apex/DRC_NBC_OpportunityProductsController.searchProducts';
import saveOLIData     from '@salesforce/apex/DRC_NBC_OpportunityProductsController.saveOLIData';
import AddProductCSS   from '@salesforce/resourceUrl/DRC_NBC_Order_Button_CSS';

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

    // Aura-callable method fallback
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
        console.log('[_tryLoad] opportunityId:', this._oppId);
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

    _recalcPackingQuantity(rowData) {
        const qty    = parseFloat(rowData.Quantity)           || 0;
        const pkgQty = parseFloat(rowData.rawPackingQuantity) || 0;
        return (pkgQty > 0 && qty > 0) ? String(Math.ceil(qty / pkgQty)) : '';
    }

    // ─── Load existing OLIs ───────────────────────────────────────────────────
    fetchOLIData() {
        console.log('[fetchOLIData] opportunityId:', this._oppId);
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
            const savedPackingSize   = item.DRC_NBC_Packing_Size__c     || '';
            const savedPackingQty    = item.DRC_NBC_Packing_Qauntity__c || '';
            let   rawPackingQuantity = '';
            if (savedPackingSize) {
                const matched      = packingDetails.find(pd => pd.packingSize === savedPackingSize);
                rawPackingQuantity = matched ? (matched.packingQuantity || '') : '';
            }
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
                    packingQuantity:                savedPackingQty
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
            packingQuantity:                ''
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
        console.log('[search] term:', searchTerm, '| opportunityId:', this._oppId);
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
        const updated            = [...this.filteredData];
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
                packingQuantity:                ''
            }
        };
        this.filteredData = updated;
    }

    // ─── Field handlers ───────────────────────────────────────────────────────
    handleQuantityChange(event) {
        const index   = parseInt(event.target.dataset.index);
        const updated = [...this.filteredData];
        updated[index].recordData.Quantity = parseFloat(event.target.value) || 0;
        if (updated[index].recordData.selectedPackingSize) {
            updated[index].recordData.packingQuantity =
                this._recalcPackingQuantity(updated[index].recordData);
        }
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
        const packingDetails = updated[index].recordData.packingDetails || [];
        const matched        = packingDetails.find(pd => pd.packingSize === selectedSize);
        updated[index].recordData.selectedPackingSize = selectedSize;
        updated[index].recordData.rawPackingQuantity  =
            matched?.packingQuantity ? String(matched.packingQuantity) : '';
        updated[index].recordData.packingQuantity =
            this._recalcPackingQuantity(updated[index].recordData);
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
        let isValid = true, rowCount = 0;
        for (const row of this.filteredData) {
            rowCount++;
            const r = row.recordData;
            if (!r.Product2Id)                    { this._toast('Error', `Product required for row ${rowCount}`, 'error');       isValid = false; }
            if (!r.Quantity || r.Quantity <= 0)   { this._toast('Error', `Quantity > 0 required for row ${rowCount}`, 'error');  isValid = false; }
            if (r.UnitPrice == null || r.UnitPrice < 0) { this._toast('Error', `Unit Price required for row ${rowCount}`, 'error'); isValid = false; }
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
                DRC_NBC_Packing_Qauntity__c:    r.packingQuantity || ''
            };
        });

        saveOLIData({ oliList: olisToSave, oliIdsToDelete: this.oliIdsToDelete, opportunityId: this._oppId })
        .then(() => {
            this._toast('Success', 'Products saved successfully', 'success');
            // Small delay so the toast is visible before redirect
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

    // ─── Navigate to Opportunity ──────────────────────────────────────────────
    // In VF + Lightning Out context:
    //   - NavigationMixin does NOT work (no Lightning App context)
    //   - CloseActionScreenEvent does NOT work
    //   - window.location.href is the only reliable redirect
    _goToOpportunity() {
        if (!this._oppId) return;
        // Standard Salesforce record page URL — works in Classic and LEX via VF
        window.location.href = '/' + this._oppId;
    }

    // ─── Toast ────────────────────────────────────────────────────────────────
    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}