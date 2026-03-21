import { LightningElement, track, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';

import getExistingOLIs       from '@salesforce/apex/DRC_NBC_OpportunityProductsController.getExistingOLIs';
import saveOLIData           from '@salesforce/apex/DRC_NBC_OpportunityProductsController.saveOLIData';
import AddProductCSS         from '@salesforce/resourceUrl/DRC_NBC_Order_Button_CSS';

export default class Drc_nbc_addProductsToOpportunity extends NavigationMixin(LightningElement) {

    // ─── Public / tracked state ──────────────────────────────────────────────
    @api  recordId;                     // Opportunity Id
    @track allData       = [];
    @track filteredData  = [];
    @track showLoading   = false;
    @track isProductOpen = true;
    @track showFilterData = false;

    // Internal
    productsMasterList = [];            // PricebookEntry list from Apex
    oliIdsToDelete     = [];            // Ids to delete on save
    packingDetailsMap  = {};            // Product2Id → [{packingSize, packingQuantity}]
    _rowCounter        = 0;             // unique key generator

    // ─── Wire: get recordId when opened as Quick Action ──────────────────────

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            const state = currentPageReference.state;
            if (state?.recordId) {
                this.recordId = state.recordId;
            } else if (state?.inContextOfRef) {
                try {
                    const ctx = JSON.parse(window.atob(state.inContextOfRef));
                    this.recordId = ctx.attributes.recordId;
                } catch (e) {
                    console.error('Error decoding inContextOfRef:', e);
                }
            }
            if (this.recordId) {
                this.fetchOLIData();
            }
        }
    }

    // ADD this — fires when recordId is set via @api from Aura wrapper
    connectedCallback() {
        loadStyle(this, AddProductCSS).catch(() => {});
        if (this.recordId) {
            this.fetchOLIData();
        }
    }

    // ADD this — fires when @api recordId changes after component is connected
    renderedCallback() {
        if (this.recordId && !this._dataLoaded) {
            this._dataLoaded = true;
            this.fetchOLIData();
        }
    }
    // ─── Section toggle ──────────────────────────────────────────────────────
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

    // ─── Packing helpers (same logic as Quote component) ─────────────────────
    buildPackingSizeOptions(packingDetailsList) {
        if (!packingDetailsList || packingDetailsList.length === 0) return [];
        return packingDetailsList.map(pd => ({ label: pd.packingSize || '', value: pd.packingSize || '' }));
    }

    getPackingDetailsForProduct(product2Id) {
        if (!product2Id || !this.packingDetailsMap) return [];
        return this.packingDetailsMap[product2Id] || [];
    }

    _recalcPackingQuantity(rowData) {
        const qty       = parseFloat(rowData.Quantity)          || 0;
        const rawPkgQty = parseFloat(rowData.rawPackingQuantity) || 0;
        if (rawPkgQty > 0 && qty > 0) {
            return String(Math.ceil(qty / rawPkgQty));
        }
        return '';
    }

    // ─── Data fetching ────────────────────────────────────────────────────────
    fetchOLIData() {
        this.showLoading = true;
        getExistingOLIs({ opportunityId: this.recordId })
            .then(data => {
                this.productsMasterList = data.productsList;
                this.packingDetailsMap  = data.packingDetailsMap || {};

                if (data.olis && data.olis.length > 0) {
                    this._buildRowsFromOLIs(data.olis);
                } else {
                    this.filteredData = [{ recordData: this._newBaseRow() }];
                }
                this.showFilterData = true;
            })
            .catch(error => {
                this._toast('Error', error?.body?.message || error.message, 'error');
            })
            .finally(() => { this.showLoading = false; });
    }

    _buildRowsFromOLIs(olis) {
        this.allData = [];
        for (const item of olis) {
            const packingDetails    = this.getPackingDetailsForProduct(item.Product2Id);
            const packingSizeOptions = this.buildPackingSizeOptions(packingDetails);

            const savedPackingSize = item.DRC_NBC_Packing_Size__c || '';
            const savedPackingQty  = item.DRC_NBC_Packing_Qauntity__c || '';
            let rawPackingQuantity = '';
            if (savedPackingSize) {
                const matched = packingDetails.find(pd => pd.packingSize === savedPackingSize);
                rawPackingQuantity = matched ? (matched.packingQuantity || '') : '';
            }

            const row = {
                ...this._newBaseRow(),
                Id:                         item.Id,
                Name:                       item.Product2?.Name || '',
                PricebookEntryId:           item.PricebookEntryId,
                Description:                item.Description || '',
                Discount:                   item.Discount || 0,
                Product2Id:                 item.Product2Id,
                Quantity:                   item.Quantity || 1,
                UnitPrice:                  item.UnitPrice || 0,
                OriginalUnitPrice:          item.UnitPrice || 0,
                DRC_NBC_FG_Code__c:         item.Product2?.DRC_NBC_FG_Code__c || '-',
                DRC_NBC_HSN_SAC_Code__c:    item.Product2?.DRC_NBC_HSN_SAC_Code__c || '-',
                DRC_NBC_Unit_Of_Measurement__c: item.Product2?.QuantityUnitOfMeasure || '-',
                showSearch:                 false,
                packingDetails:             packingDetails,
                packingSizeOptions:         packingSizeOptions,
                selectedPackingSize:        savedPackingSize,
                rawPackingQuantity:         rawPackingQuantity,
                packingQuantity:            savedPackingQty
            };
            this.allData.push({ recordData: row });
        }
        this.filteredData = [...this.allData];
    }

    _newBaseRow() {
        return {
            rowKey:                     ++this._rowCounter,
            Id:                         null,
            Name:                       '',
            PricebookEntryId:           '',
            Description:                '',
            Discount:                   0,
            Product2Id:                 '',
            Quantity:                   1,
            UnitPrice:                  0,
            OriginalUnitPrice:          0,
            ProductName:                '',
            DRC_NBC_FG_Code__c:         '',
            DRC_NBC_HSN_SAC_Code__c:    '',
            DRC_NBC_Unit_Of_Measurement__c: '',
            showSearch:                 true,
            searchResults:              [],
            noResultsFound:             false,
            packingDetails:             [],
            packingSizeOptions:         [],
            selectedPackingSize:        '',
            rawPackingQuantity:         '',
            packingQuantity:            ''
        };
    }

    // ─── Row management ───────────────────────────────────────────────────────
    handleAddRow() {
        this.filteredData = [...this.filteredData, { recordData: this._newBaseRow() }];
    }

    handleRemoveRow(event) {
        const index = parseInt(event.currentTarget.dataset.index);
        const id    = event.currentTarget.dataset.id;
        if (id) { this.oliIdsToDelete.push(id); }
        this.filteredData.splice(index, 1);
        this.filteredData = [...this.filteredData];
    }

    handleClearProduct(event) {
        const index = parseInt(event.currentTarget.dataset.index);
        const freshRow = this._newBaseRow();
        // preserve the existing rowKey so the template key stays stable
        freshRow.rowKey = this.filteredData[index].recordData.rowKey;
        this.filteredData[index].recordData = freshRow;
        this.filteredData = [...this.filteredData];
    }

    // ─── Field change handlers ────────────────────────────────────────────────
    handleValueChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.name;
        const value = event.target.value;

        this.filteredData[index].recordData[field] = value;

        if (field === 'ProductName') {
            if (value.length >= 2) {
                const matches = this.productsMasterList.filter(p =>
                    p.Product2.Name.toLowerCase().includes(value.toLowerCase())
                );
                this.filteredData[index].recordData.searchResults  = matches;
                this.filteredData[index].recordData.noResultsFound = matches.length === 0;
            } else {
                this.filteredData[index].recordData.searchResults  = [];
                this.filteredData[index].recordData.noResultsFound = false;
            }
        }
        this.filteredData = [...this.filteredData];
    }

    handleQuantityChange(event) {
        const index    = parseInt(event.target.dataset.index);
        const quantity = parseFloat(event.target.value) || 0;

        this.filteredData[index].recordData.Quantity = quantity;

        if (this.filteredData[index].recordData.selectedPackingSize) {
            this.filteredData[index].recordData.packingQuantity =
                this._recalcPackingQuantity(this.filteredData[index].recordData);
        }
        this.filteredData = [...this.filteredData];
    }

    handleUnitPriceChange(event) {
        const index = parseInt(event.target.dataset.index);
        const value = parseFloat(event.target.value) || 0;
        this.filteredData[index].recordData.UnitPrice = value;
        this.filteredData = [...this.filteredData];
    }

    handlePackingSizeChange(event) {
        const index       = parseInt(event.target.dataset.index);
        const selectedSize = event.detail.value;

        this.filteredData[index].recordData.selectedPackingSize = selectedSize;

        const packingDetails = this.filteredData[index].recordData.packingDetails || [];
        const matched        = packingDetails.find(pd => pd.packingSize === selectedSize);

        this.filteredData[index].recordData.rawPackingQuantity =
            (matched && matched.packingQuantity != null && matched.packingQuantity !== '')
                ? String(matched.packingQuantity) : '';

        this.filteredData[index].recordData.packingQuantity =
            this._recalcPackingQuantity(this.filteredData[index].recordData);

        this.filteredData = [...this.filteredData];
    }

    handleProductSelect(event) {
        const index       = parseInt(event.currentTarget.dataset.index);
        const selectedId  = event.currentTarget.dataset.id;
        const selected    = this.productsMasterList.find(p => p.Id === selectedId);

        if (selected) {
            const packingDetails    = this.getPackingDetailsForProduct(selected.Product2Id);
            const packingSizeOptions = this.buildPackingSizeOptions(packingDetails);

            this.filteredData[index].recordData = {
                ...this.filteredData[index].recordData,
                showSearch:                 false,
                Name:                       selected.Product2.Name,
                Product2Id:                 selected.Product2.Id,
                Description:                selected.Product2.Description || '',
                UnitPrice:                  selected.UnitPrice || 0,
                OriginalUnitPrice:          selected.UnitPrice || 0,
                DRC_NBC_FG_Code__c:         selected.Product2.DRC_NBC_FG_Code__c || '-',
                DRC_NBC_HSN_SAC_Code__c:    selected.Product2.DRC_NBC_HSN_SAC_Code__c || '-',
                PricebookEntryId:           selected.Id,
                DRC_NBC_Unit_Of_Measurement__c: selected.Product2.QuantityUnitOfMeasure || '-',
                searchResults:              [],
                noResultsFound:             false,
                packingDetails:             packingDetails,
                packingSizeOptions:         packingSizeOptions,
                selectedPackingSize:        '',
                rawPackingQuantity:         '',
                packingQuantity:            ''
            };
            this.filteredData = [...this.filteredData];
        }
    }

    // ─── Save ─────────────────────────────────────────────────────────────────
    handleSave() {
        this.showLoading = true;
        let isValid = true;
        let rowCount = 0;

        for (const row of this.filteredData) {
            rowCount++;
            const r = row.recordData;
            if (!r.Product2Id) {
                this._toast('Error', `Product Name is required for row ${rowCount}`, 'error');
                isValid = false;
            }
            if (!r.Quantity || r.Quantity <= 0) {
                this._toast('Error', `Quantity must be greater than 0 for row ${rowCount}`, 'error');
                isValid = false;
            }
            if (r.UnitPrice == null || r.UnitPrice < 0) {
                this._toast('Error', `Unit Price is required for row ${rowCount}`, 'error');
                isValid = false;
            }
        }

        if (!isValid) {
            this.showLoading = false;
            return;
        }

        const olisToSave = this.filteredData.map(row => {
            const r = row.recordData;
            return {
                Id:                             r.Id || null,
                Product2Id:                     r.Product2Id,
                Quantity:                       r.Quantity,
                UnitPrice:                      parseFloat(r.UnitPrice) || 0,
                Discount:                       r.Discount || 0,
                OpportunityId:                  this.recordId,
                PricebookEntryId:               r.PricebookEntryId,
                Description:                    r.Description || '',
                DRC_NBC_Unit_Of_Measurement__c: r.DRC_NBC_Unit_Of_Measurement__c || '',
                DRC_NBC_Packing_Size__c:        r.selectedPackingSize || '',
                DRC_NBC_Packing_Qauntity__c:    r.packingQuantity || ''
            };
        });

        saveOLIData({
            oliList:          olisToSave,
            oliIdsToDelete:   this.oliIdsToDelete,
            opportunityId:    this.recordId
        })
            .then(() => {
                this._toast('Success', 'Opportunity Products saved successfully', 'success');
                this.dispatchEvent(new CloseActionScreenEvent());
                window.location.href = '/' + this.recordId;
            })
            .catch(error => {
                const msg = error?.body?.message || error?.message || 'Unknown error occurred';
                this._toast('Error', msg, 'error');
            })
            .finally(() => { this.showLoading = false; });
    }

    // ─── Cancel ──────────────────────────────────────────────────────────────
    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel', { bubbles: true, composed: true }));
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // ─── Toast helper ─────────────────────────────────────────────────────────
    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}