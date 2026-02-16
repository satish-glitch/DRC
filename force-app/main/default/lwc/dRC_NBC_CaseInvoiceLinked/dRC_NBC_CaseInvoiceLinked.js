import { LightningElement, api, track } from 'lwc';
import getAvailableInvoices from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.getAvailableInvoices';
import getInvoiceDetails from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.getInvoiceDetails';
import getLineItemsForInvoice from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.getLineItemsForInvoice';
import getIssueTypePicklistValues from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.getIssueTypePicklistValues';
import getPriorityPicklistValues from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.getPriorityPicklistValues';
import getStatusPicklistValues from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.getStatusPicklistValues';
import getOriginPicklistValues from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.getOriginPicklistValues';
import getCaseDetails from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.getCaseDetails';
import saveCase from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.saveCase';
import searchParentCases from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.searchParentCases';
import searchAccounts from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.searchAccounts';
import searchContacts from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.searchContacts';
import getContactDetails from '@salesforce/apex/DRC_NBCCaseInoviceLinkedController.getContactDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class DRC_NBC_CaseInvoiceLinked extends NavigationMixin(LightningElement) {
    @api recordId; // Will be null for New button, populated for Edit button
    @track isModalOpen = false;
    @track isUpdateDisabled = false;
    @track isNewCase = false;
    
    @track caseData = {
        CaseNumber: '',
        Subject: '',
        Status: 'New',
        ParentId: '',
        IsEscalated: false,
        DRC_NBC_CAPA_File_Uploaded__c: false,
        Origin: '',
        Priority: '',
        Description: '',
        DRC_NBC_Issue_type__c: '',
        DRC_NBC_Action_Inititated_By_DRC__c: '',
        DRC_NBCPreferred_Resolution_to_Customers__c: '',
        AccountId: '',
        ContactId: ''
    };
    
    // Invoice and line items
    @track invoiceInfo = {};
    @track selectedInvoiceId;
    @track lineItems = [];
    @track lineItemOptions = [];
    @track selectedLineItemId;
    @track selectedInvoiceLots = []; // Stores all selected lots with complaint quantities
    @track allInvoices = []; // Store all invoices for searching
    
    // Parent Case search
    @track parentCaseOptions = [];
    @track selectedParentCaseLabel = '';
    @track parentCaseSearchTerm = '';
    @track isParentCaseDropdownOpen = false;
    
    // Contact Information
    @track accountOptions = [];
    @track contactOptions = [];
    @track selectedAccountName = '';
    @track selectedContactName = '';
    @track accountSearchTerm = '';
    @track contactSearchTerm = '';
    @track isAccountDropdownOpen = false;
    @track isContactDropdownOpen = false;
    @track contactEmail = '';
    @track contactPhone = '';
    
    // Invoice search
    @track invoiceOptions = [];
    @track selectedInvoiceName = '';
    @track invoiceSearchTerm = '';
    @track isInvoiceDropdownOpen = false;
    
    // Picklist options
    @track issueTypeOptions = [];
    @track priorityOptions = [];
    @track statusOptions = [];
    @track originOptions = [];
    @track availableInvoices = [];
    
    // Section toggles
    @track isCaseInfoOpen = true;
    @track isContactInfoOpen = true;
    @track isLineItemSelectionOpen = true;
    @track isBatchInfoOpen = true;

    /**
     * Get current selected line item details
     */
    get currentLineItem() {
        if (!this.selectedLineItemId) return null;
        
        const lineItem = this.lineItems.find(item => item.Id === this.selectedLineItemId);
        if (!lineItem) return null;
        
        return {
            lineItemId: lineItem.Id,
            productName: lineItem.DRC_NBC_Product__r?.Name || '',
            productCode: lineItem.DRC_NBC_Product_Code__c || '',
            productDescription: lineItem.DRC_NBC_Product__r?.Description || ''
        };
    }

    /**
     * Get lot numbers for currently selected line item from Invoice Lot object
     */
    get currentLineItemLots() {
        if (!this.selectedLineItemId) return [];
        
        const lineItem = this.lineItems.find(item => item.Id === this.selectedLineItemId);
        if (!lineItem || !lineItem.Invoice_Lots__r) return [];
        
        return lineItem.Invoice_Lots__r.map(lot => {
            const alreadySelected = this.selectedInvoiceLots.find(sl => sl.lotId === lot.Id);
            
            // Check if there's a temporary complaint quantity entered but not yet added
            let complaintQty = alreadySelected ? alreadySelected.complaintQuantity : 0;
            if (this.tempComplaintQuantities && this.tempComplaintQuantities.has(lot.Id)) {
                complaintQty = this.tempComplaintQuantities.get(lot.Id);
            }
            
            return {
                lotId: lot.Id,
                lotNumber: lot.DRC_NBC_Lot_Number__c,
                quantity: lot.DRC_NBC_Lot_Quantity__c || 0,
                complaintQuantity: complaintQty,
                productId: lot.DRC_NBC_Product__c,
                productName: lineItem.DRC_NBC_Product__r?.Name,
                productCode: lineItem.DRC_NBC_Product_Code__c
            };
        });
    }

    /**
     * Get selected lots grouped by product for display
     */
    get selectedLotsGrouped() {
        const groupedMap = new Map();
        
        this.selectedInvoiceLots.forEach(lot => {
            if (!groupedMap.has(lot.lineItemId)) {
                groupedMap.set(lot.lineItemId, {
                    lineItemId: lot.lineItemId,
                    productName: lot.productName,
                    productCode: lot.productCode,
                    lots: []
                });
            }
            groupedMap.get(lot.lineItemId).lots.push(lot);
        });
        
        return Array.from(groupedMap.values());
    }

    /**
     * Check if save/update button should be disabled
     */
    get isSaveDisabled() {
        return this.isUpdateDisabled || 
               !this.caseData.Subject || 
               !this.caseData.Status || 
               !this.caseData.DRC_NBC_Issue_type__c ||
               !this.selectedInvoiceId ||
               this.selectedInvoiceLots.length === 0;
    }

    /**
     * Get button label based on mode
     */
    get saveButtonLabel() {
        return this.isNewCase ? 'Create Case' : 'Update Case';
    }

    /**
     * Toggle methods for collapsible sections
     */
    toggleCaseInfo() {
        this.isCaseInfoOpen = !this.isCaseInfoOpen;
    }

    toggleContactInfo() {
        this.isContactInfoOpen = !this.isContactInfoOpen;
    }

    toggleLineItemSelection() {
        this.isLineItemSelectionOpen = !this.isLineItemSelectionOpen;
    }

    toggleBatchInfo() {
        this.isBatchInfoOpen = !this.isBatchInfoOpen;
    }

    /**
     * Computed properties for section CSS classes
     */
    get getCaseInfoClass() {
        return `slds-section slds-m-top_medium ${this.isCaseInfoOpen ? 'slds-is-open' : ''}`;
    }
    
    get getContactInfoClass() {
        return `slds-section slds-m-top_medium ${this.isContactInfoOpen ? 'slds-is-open' : ''}`;
    }
    
    get getLineItemSelectionClass() {
        return `slds-section slds-m-top_medium ${this.isLineItemSelectionOpen ? 'slds-is-open' : ''}`;
    }
    
    get getBatchInfoClass() {
        return `slds-section slds-m-top_medium ${this.isBatchInfoOpen ? 'slds-is-open' : ''}`;
    }

    /**
     * Computed properties for section icons
     */
    get getCaseInfoIcon() {
        return this.isCaseInfoOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }
    
    get getContactInfoIcon() {
        return this.isContactInfoOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }
    
    get getLineItemSelectionIcon() {
        return this.isLineItemSelectionOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }
    
    get getBatchInfoIcon() {
        return this.isBatchInfoOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    /**
     * Computed properties for lookup dropdown classes
     */
    get parentCaseLookupClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.isParentCaseDropdownOpen ? 'slds-is-open' : ''}`;
    }

    get accountLookupClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.isAccountDropdownOpen ? 'slds-is-open' : ''}`;
    }

    get contactLookupClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.isContactDropdownOpen ? 'slds-is-open' : ''}`;
    }

    get invoiceLookupClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${this.isInvoiceDropdownOpen ? 'slds-is-open' : ''}`;
    }

    /**
     * Component initialization
     */
    connectedCallback() {
        // Initialize temporary complaint quantities map
        this.tempComplaintQuantities = new Map();

        // Determine if this is a new case or edit
        this.isNewCase = !this.recordId;

        // Load picklists and invoices first, then load case data if editing
        this.loadInitialData()
            .then(() => {
                if (!this.isNewCase) {
                    return this.loadCaseData();
                }
            })
            .catch(error => {
                console.error('Error in initialization:', error);
            });
        
        this.openModal();
    }

    /**
     * Track rendering to ensure data is displayed
     */
    renderedCallback() {
        // Log render state for debugging
        if (this.recordId && this.selectedInvoiceLots.length > 0) {
            console.log('Component rendered with selected lots:', this.selectedInvoiceLots.length);
        }
    }

    /**
     * Load all initial data (invoices and picklists) - USING IMPERATIVE CALLS
     */
    loadInitialData() {
        return Promise.all([
            getAvailableInvoices(),
            getIssueTypePicklistValues(),
            getPriorityPicklistValues(),
            getStatusPicklistValues(),
            getOriginPicklistValues()
        ])
        .then(([invoices, issueTypes, priorities, statuses, origins]) => {
            console.log('Invoices received from Apex:', invoices.length);
            
            // Store all invoices for searching
            this.allInvoices = invoices.map(inv => ({
                label: `${inv.Name}${inv.DRC_NBC_Invoice_Number__c ? ' (' + inv.DRC_NBC_Invoice_Number__c + ')' : ''}`,
                value: inv.Id,
                name: inv.Name,
                number: inv.DRC_NBC_Invoice_Number__c || ''
            }));
            
            console.log('allInvoices array created:', this.allInvoices.length);
            
            this.issueTypeOptions = issueTypes.map(val => ({ label: val, value: val }));
            this.priorityOptions = priorities.map(val => ({ label: val, value: val }));
            this.statusOptions = statuses.map(val => ({ label: val, value: val }));
            this.originOptions = origins.map(val => ({ label: val, value: val }));
            
            console.log('Initial data loaded successfully');
        })
        .catch(error => {
            console.error('Error loading initial data:', error);
            this.showToast('Error', 'Failed to load form data', 'error');
            throw error;
        });
    }

    /**
     * Load existing case data (for edit mode) - USING IMPERATIVE CALL
     */
    loadCaseData() {
        console.log('Loading case data for recordId:', this.recordId);
        
        return getCaseDetails({ caseId: this.recordId })
            .then(caseRecord => {
                console.log('Case record loaded:', caseRecord);
                
                this.caseData = {
                    CaseNumber: caseRecord.CaseNumber || '',
                    Subject: caseRecord.Subject || '',
                    Status: caseRecord.Status || 'New',
                    ParentId: caseRecord.ParentId || '',
                    IsEscalated: caseRecord.IsEscalated || false,
                    DRC_NBC_CAPA_File_Uploaded__c: caseRecord.DRC_NBC_CAPA_File_Uploaded__c || false,
                    Origin: caseRecord.Origin || '',
                    Priority: caseRecord.Priority || '',
                    Description: caseRecord.Description || '',
                    DRC_NBC_Issue_type__c: caseRecord.DRC_NBC_Issue_type__c || '',
                    DRC_NBC_Action_Inititated_By_DRC__c: caseRecord.DRC_NBC_Action_Inititated_By_DRC__c || '',
                    DRC_NBCPreferred_Resolution_to_Customers__c: caseRecord.DRC_NBCPreferred_Resolution_to_Customers__c || '',
                    AccountId: caseRecord.AccountId || '',
                    ContactId: caseRecord.ContactId || ''
                };

                // Set Parent Case label and search term
                if (caseRecord.Parent) {
                    this.selectedParentCaseLabel = caseRecord.Parent.CaseNumber;
                    this.parentCaseSearchTerm = caseRecord.Parent.CaseNumber;
                }

                // Set Account info
                if (caseRecord.Account) {
                    this.selectedAccountName = caseRecord.Account.Name;
                    this.accountSearchTerm = caseRecord.Account.Name;
                }

                // Set Contact info
                if (caseRecord.Contact) {
                    this.selectedContactName = caseRecord.Contact.Name;
                    this.contactSearchTerm = caseRecord.Contact.Name;
                    this.contactEmail = caseRecord.Contact.Email || '';
                    this.contactPhone = caseRecord.Contact.Phone || '';
                }

                console.log('Case data set:', this.caseData);

                // If case already has an invoice linked, load it with imperative call
                if (caseRecord.DRC_NBC_Invoice__c) {
                    console.log('Loading invoice:', caseRecord.DRC_NBC_Invoice__c);
                    this.selectedInvoiceId = caseRecord.DRC_NBC_Invoice__c;
                    
                    // Set the invoice search term to show selected invoice
                    const selectedInvoice = this.allInvoices.find(inv => inv.value === caseRecord.DRC_NBC_Invoice__c);
                    if (selectedInvoice) {
                        this.selectedInvoiceName = selectedInvoice.label;
                        this.invoiceSearchTerm = selectedInvoice.label;
                        console.log('Invoice name set:', this.selectedInvoiceName);
                    } else {
                        console.warn('Invoice not found in allInvoices array');
                    }
                    
                    // Load invoice data imperatively and return the promise
                    return this.loadInvoiceDataImperative(caseRecord.DRC_NBC_Invoice__c, this.recordId);
                }
            })
            .catch(error => {
                console.error('Error loading case data:', error);
                this.showToast('Error', 'Failed to load case data: ' + (error.body?.message || error.message), 'error');
                throw error;
            });
    }

    /**
     * Handle Invoice focus - Load all invoices
     */
    handleInvoiceFocus() {
        console.log('Invoice focus - allInvoices count:', this.allInvoices ? this.allInvoices.length : 0);
        this.isInvoiceDropdownOpen = true;
        // Load all invoices when focusing
        this.performInvoiceSearch('');
    }

    /**
     * Handle Invoice blur
     */
    handleInvoiceBlur() {
        // Delay to allow click event to fire
        setTimeout(() => {
            this.isInvoiceDropdownOpen = false;
        }, 300);
    }

    /**
     * Handle Invoice search input
     */
    handleInvoiceSearch(event) {
        const searchTerm = event.target.value;
        this.invoiceSearchTerm = searchTerm;
        
        this.isInvoiceDropdownOpen = true;
        this.performInvoiceSearch(searchTerm);
    }

    /**
     * Perform Invoice search
     */
    performInvoiceSearch(searchTerm) {
        console.log('Performing invoice search with term:', searchTerm);
        console.log('allInvoices available:', this.allInvoices ? this.allInvoices.length : 0);
        
        if (!this.allInvoices || this.allInvoices.length === 0) {
            console.log('No invoices available');
            this.invoiceOptions = [];
            return;
        }

        if (!searchTerm || searchTerm.trim() === '') {
            // Show all invoices
            this.invoiceOptions = [...this.allInvoices];
            console.log('Showing all invoices:', this.invoiceOptions.length);
        } else {
            // Filter invoices based on search term
            const searchLower = searchTerm.toLowerCase();
            this.invoiceOptions = this.allInvoices.filter(inv => 
                inv.label.toLowerCase().includes(searchLower) ||
                inv.name.toLowerCase().includes(searchLower) ||
                inv.number.toLowerCase().includes(searchLower)
            );
            console.log('Filtered invoices:', this.invoiceOptions.length);
        }
    }

    /**
     * Handle Invoice selection from dropdown
     */
    handleInvoiceSelectFromDropdown(event) {
        event.preventDefault();
        const selectedValue = event.currentTarget.dataset.value;
        const selectedLabel = event.currentTarget.dataset.label;
        
        this.selectedInvoiceId = selectedValue;
        this.selectedInvoiceName = selectedLabel;
        this.invoiceSearchTerm = selectedLabel;
        this.isInvoiceDropdownOpen = false;
        this.invoiceOptions = [];
        
        // Load invoice data imperatively
        if (this.selectedInvoiceId) {
            this.loadInvoiceDataImperative(this.selectedInvoiceId, null);
        }
    }

    /**
     * Clear Invoice selection
     */
    clearInvoice() {
        this.selectedInvoiceId = '';
        this.selectedInvoiceName = '';
        this.invoiceSearchTerm = '';
        this.invoiceOptions = [];
        this.invoiceInfo = {};
        this.lineItems = [];
        this.lineItemOptions = [];
        this.selectedLineItemId = null;
        this.selectedInvoiceLots = [];
    }

    /**
     * Load invoice data and line items with lots - IMPERATIVE METHOD
     */
    loadInvoiceDataImperative(invoiceId, caseId) {
        console.log('Loading invoice data imperatively for invoice:', invoiceId);
        
        return Promise.all([
            getInvoiceDetails({ invoiceId: invoiceId }),
            getLineItemsForInvoice({ invoiceId: invoiceId })
        ])
        .then(([invoice, lineItems]) => {
            console.log('Invoice details loaded:', invoice);
            console.log('Line items loaded:', lineItems.length);
            
            this.invoiceInfo = invoice;
            this.processLineItems(lineItems, caseId);
            
            // Force open the line item selection section
            this.isLineItemSelectionOpen = true;
            
            console.log('Invoice data loaded, selectedInvoiceLots count:', this.selectedInvoiceLots.length);
            
            // Force multiple re-renders to ensure UI updates
            return new Promise(resolve => {
                // Use setTimeout to ensure the updates happen in the next render cycle
                setTimeout(() => {
                    // Force re-render of line items
                    this.lineItems = [...this.lineItems];
                    this.lineItemOptions = [...this.lineItemOptions];
                    
                    // Force re-render of selected lots
                    if (this.selectedInvoiceLots.length > 0) {
                        this.selectedInvoiceLots = [...this.selectedInvoiceLots];
                        console.log('Forced UI update for selectedInvoiceLots');
                    }
                    
                    resolve();
                }, 100);
            });
        })
        .catch(error => {
            console.error('Error loading invoice details:', error);
            this.showToast('Error', 'Failed to load invoice details', 'error');
            throw error;
        });
    }

    /**
     * Process line items and their invoice lots
     */
    processLineItems(lineItems, caseId) {
        console.log('Processing line items, caseId:', caseId);
        
        // Create new arrays (immutable pattern for reactivity)
        const processedLineItems = lineItems.map(item => ({
            ...item,
            productDescription: item.DRC_NBC_Product__r?.Description || 'N/A'
        }));

        const processedLineItemOptions = processedLineItems.map(item => ({
            label: `${item.DRC_NBC_Product__r?.Name || 'Unknown'} (${item.DRC_NBC_Product_Code__c || 'N/A'})`,
            value: item.Id
        }));

        console.log('Line item options created:', processedLineItemOptions.length);

        // If editing existing case, pre-populate selected lots that have complaint quantities
        let tempSelectedLots = [];
        
        if (caseId) {
            processedLineItems.forEach(lineItem => {
                if (lineItem.Invoice_Lots__r && lineItem.Invoice_Lots__r.length > 0) {
                    console.log(`Processing ${lineItem.Invoice_Lots__r.length} lots for line item ${lineItem.Id}`);
                    
                    lineItem.Invoice_Lots__r.forEach(lot => {
                        console.log(`Checking lot ${lot.Id}, Case__c: ${lot.DRC_NBC_Case__c}, looking for: ${caseId}`);
                        
                        // Load lots that are linked to this case
                        if (lot.DRC_NBC_Case__c === caseId) {
                            // Parse complaint quantity (it's stored as string)
                            let complaintQty = 0;
                            if (lot.DRC_NBC_Lot_Complaint_Quantity__c) {
                                complaintQty = parseFloat(lot.DRC_NBC_Lot_Complaint_Quantity__c) || 0;
                            }
                            
                            console.log(`Lot ${lot.Id} matches case, complaint qty: ${complaintQty}`);
                            
                            // Only add if there's a complaint quantity
                            if (complaintQty > 0) {
                                tempSelectedLots.push({
                                    lotId: lot.Id,
                                    lineItemId: lineItem.Id,
                                    productId: lot.DRC_NBC_Product__c,
                                    productName: lineItem.DRC_NBC_Product__r?.Name,
                                    productCode: lineItem.DRC_NBC_Product_Code__c,
                                    lotNumber: lot.DRC_NBC_Lot_Number__c,
                                    quantity: lot.DRC_NBC_Lot_Quantity__c || 0,
                                    complaintQuantity: complaintQty
                                });
                                console.log(`Added lot ${lot.DRC_NBC_Lot_Number__c} to selected lots`);
                            }
                        }
                    });
                }
            });
            
            console.log('Total selected invoice lots for case:', tempSelectedLots.length);
            console.log('Selected lots:', JSON.stringify(tempSelectedLots));
        }

        // Assign all at once to trigger reactivity
        this.lineItems = processedLineItems;
        this.lineItemOptions = processedLineItemOptions;
        this.selectedInvoiceLots = tempSelectedLots;
        this.selectedLineItemId = null;
        
        console.log('Process line items complete. lineItems:', this.lineItems.length, 
                    'lineItemOptions:', this.lineItemOptions.length,
                    'selectedInvoiceLots:', this.selectedInvoiceLots.length);
    }

    /**
     * Handle line item selection from combobox
     */
    handleLineItemComboboxSelect(event) {
        this.selectedLineItemId = event.detail.value;
        
        if (this.selectedLineItemId) {
            this.isBatchInfoOpen = true;
        }
    }

    /**
     * Clear current line item selection
     */
    clearLineItemSelection() {
        this.selectedLineItemId = null;
        
        // Clear temporary complaint quantities for current line item
        if (this.tempComplaintQuantities) {
            this.tempComplaintQuantities.clear();
        }
    }

    /**
     * Handle complaint quantity change for specific lot
     */
    handleComplaintQuantityChange(event) {
        const lotId = event.target.dataset.lotId;
        const complaintQuantity = parseFloat(event.target.value) || 0;
        const maxQuantityStr = event.target.max;
        const maxQuantity = parseFloat(maxQuantityStr) || 0;
        
        // Validate complaint quantity
        if (complaintQuantity > maxQuantity) {
            this.showToast('Error', `Complaint quantity (${complaintQuantity}) cannot exceed available quantity (${maxQuantity})`, 'error');
            event.target.value = maxQuantity;
            return;
        }
        
        if (complaintQuantity < 0) {
            this.showToast('Error', 'Complaint quantity cannot be negative', 'error');
            event.target.value = 0;
            return;
        }
        
        // Store the complaint quantity in a temporary map for tracking changes
        if (!this.tempComplaintQuantities) {
            this.tempComplaintQuantities = new Map();
        }
        this.tempComplaintQuantities.set(lotId, complaintQuantity);
    }

    /**
     * Add selected lots from current line item to case
     */
    addLotsToCase() {
        if (!this.selectedLineItemId) {
            this.showToast('Warning', 'Please select a line item', 'warning');
            return;
        }

        const currentLots = this.currentLineItemLots;
        
        // Filter lots that have complaint quantity (either from temp map or already selected)
        const lotsWithComplaint = currentLots.filter(lot => {
            const qty = this.tempComplaintQuantities ? 
                        this.tempComplaintQuantities.get(lot.lotId) || lot.complaintQuantity : 
                        lot.complaintQuantity;
            return qty > 0;
        });

        if (lotsWithComplaint.length === 0) {
            this.showToast('Warning', 'Please enter at least one complaint quantity', 'warning');
            return;
        }

        // Validate complaint quantities
        for (let lot of lotsWithComplaint) {
            const availableQty = parseFloat(lot.quantity) || 0;
            const complaintQty = this.tempComplaintQuantities ? 
                                 this.tempComplaintQuantities.get(lot.lotId) || lot.complaintQuantity : 
                                 lot.complaintQuantity;
            
            if (complaintQty > availableQty) {
                this.showToast('Error', `Complaint quantity for lot ${lot.lotNumber} exceeds available quantity`, 'error');
                return;
            }
        }

        // Add or update lots in selectedInvoiceLots
        lotsWithComplaint.forEach(lot => {
            const complaintQty = this.tempComplaintQuantities ? 
                                 this.tempComplaintQuantities.get(lot.lotId) || lot.complaintQuantity : 
                                 lot.complaintQuantity;
            
            const existingIndex = this.selectedInvoiceLots.findIndex(sl => sl.lotId === lot.lotId);
            
            const lotData = {
                lotId: lot.lotId,
                lineItemId: this.selectedLineItemId,
                productId: lot.productId,
                productName: lot.productName,
                productCode: lot.productCode,
                lotNumber: lot.lotNumber,
                quantity: lot.quantity,
                complaintQuantity: complaintQty
            };
            
            if (existingIndex !== -1) {
                // Update existing lot
                this.selectedInvoiceLots[existingIndex] = lotData;
                this.showToast('Success', `Updated complaint quantity for lot ${lot.lotNumber}`, 'success');
            } else {
                // Add new lot
                this.selectedInvoiceLots.push(lotData);
                this.showToast('Success', `Added lot ${lot.lotNumber} to case`, 'success');
            }
        });

        // Clear temporary complaint quantities for added lots
        if (this.tempComplaintQuantities) {
            lotsWithComplaint.forEach(lot => {
                this.tempComplaintQuantities.delete(lot.lotId);
            });
        }

        this.clearLineItemSelection();
    }

    /**
     * Remove lot from selected lots
     */
    removeLotFromCase(event) {
        const lotId = event.target.dataset.lotId;
        this.selectedInvoiceLots = this.selectedInvoiceLots.filter(lot => lot.lotId !== lotId);
        
        this.showToast('Success', 'Lot removed from case', 'success');
    }

    /**
     * Handle complaint quantity change in the selected lots table (for editing)
     */
    handleSelectedLotQuantityChange(event) {
        const lotId = event.target.dataset.lotId;
        const newComplaintQuantity = parseFloat(event.target.value) || 0;
        const maxQuantityStr = event.target.max;
        const maxQuantity = parseFloat(maxQuantityStr) || 0;
        
        // Validate complaint quantity
        if (newComplaintQuantity > maxQuantity) {
            this.showToast('Error', `Complaint quantity (${newComplaintQuantity}) cannot exceed available quantity (${maxQuantity})`, 'error');
            // Reset to previous value
            const lotIndex = this.selectedInvoiceLots.findIndex(lot => lot.lotId === lotId);
            if (lotIndex !== -1) {
                event.target.value = this.selectedInvoiceLots[lotIndex].complaintQuantity;
            }
            return;
        }
        
        if (newComplaintQuantity < 0) {
            this.showToast('Error', 'Complaint quantity cannot be negative', 'error');
            event.target.value = 0;
            return;
        }
        
        // Update the complaint quantity in selectedInvoiceLots
        const lotIndex = this.selectedInvoiceLots.findIndex(lot => lot.lotId === lotId);
        if (lotIndex !== -1) {
            this.selectedInvoiceLots[lotIndex].complaintQuantity = newComplaintQuantity;
            this.showToast('Success', 'Complaint quantity updated', 'success');
        }
    }

    /**
     * Modal control methods
     */
    openModal() {
        this.isModalOpen = true;
    }

    /**
     * Close modal and navigate appropriately
     */
    closeModal() {
        this.isModalOpen = false;
        if (this.recordId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Case',
                    actionName: 'home'
                }
            });
        }
    }

    /**
     * Handle case field changes
     */
    handleChange(event) {
        const field = event.target.dataset.field;
        if (field) {
            this.caseData[field] = event.detail.value;
        }
    }

    /**
     * Save the case (create or update)
     * SOLUTION 1: Refresh page after save
     */
    saveCase() {
        // Final validation
        if (!this.caseData.Subject || !this.caseData.Status) {
            this.showToast('Warning', 'Please fill in required fields (Subject and Status)', 'warning');
            return;
        }

        if (!this.caseData.DRC_NBC_Issue_type__c) {
            this.showToast('Warning', 'Please fill in required field: Issue Type', 'warning');
            return;
        }

        if (!this.caseData.Description) {
            this.showToast('Warning', 'Please fill in required field: Description', 'warning');
            return;
        }

        if (!this.caseData.Priority) {
            this.showToast('Warning', 'Please fill in required field: Priority', 'warning');
            return;
        }

        if (!this.caseData.Origin) {
            this.showToast('Warning', 'Please fill in required field: Origin', 'warning');
            return;
        }

        if (!this.selectedInvoiceId) {
            this.showToast('Warning', 'Please select an Invoice', 'warning');
            return;
        }

        if (this.selectedInvoiceLots.length === 0) {
            this.showToast('Warning', 'Please add at least one lot with complaint quantity', 'warning');
            return;
        }

        this.isUpdateDisabled = true;

        // Call Apex to save case
        saveCase({
            caseId: this.recordId,
            caseDataJson: JSON.stringify(this.caseData),
            invoiceId: this.selectedInvoiceId,
            selectedLotsJson: JSON.stringify(this.selectedInvoiceLots)
        })
        .then(result => {
            // Show success message
            this.showToast('Success', result.message, 'success');
            
            // Close the modal
            this.isModalOpen = false;
            
            // Navigate to the case record with refresh
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: result.caseId,
                    objectApiName: 'Case',
                    actionName: 'view'
                }
            });
            
            // Refresh the page after a short delay to ensure navigation completes
            setTimeout(() => {
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                location.reload();
            }, 500);
        })
        .catch(error => {
            console.error('Error saving case:', error);
            const errorMessage = error.body?.message || error.message || 'Failed to save case';
            this.showToast('Error', errorMessage, 'error');
            this.isUpdateDisabled = false;
        });
    }

    /**
     * Handle Parent Case focus - Load all cases sorted by date ascending
     */
    handleParentCaseFocus() {
        this.isParentCaseDropdownOpen = true;
        if (!this.parentCaseSearchTerm) {
            this.parentCaseSearchTerm = '';
        }
        this.performParentCaseSearch('', this.caseData.AccountId || null);
    }

    /**
     * Handle Parent Case blur
     */
    handleParentCaseBlur() {
        setTimeout(() => {
            this.isParentCaseDropdownOpen = false;
        }, 300);
    }

    /**
     * Handle Parent Case search input
     */
    handleParentCaseSearch(event) {
        const searchTerm = event.target.value;
        this.parentCaseSearchTerm = searchTerm;
        
        this.isParentCaseDropdownOpen = true;
        this.performParentCaseSearch(searchTerm, this.caseData.AccountId);
    }

    /**
     * Perform Parent Case search
     */
    performParentCaseSearch(searchTerm, accountId) {
        console.log('Performing parent case search with term:', searchTerm, 'accountId:', accountId);
        
        searchParentCases({ searchTerm: searchTerm, accountId: accountId })
            .then(cases => {
                console.log('Parent cases returned:', cases.length);
                this.parentCaseOptions = cases.map(c => {
                    let createdDate = '';
                    if (c.CreatedDate) {
                        const dateObj = new Date(c.CreatedDate);
                        createdDate = dateObj.toLocaleDateString();
                    }
                    
                    return {
                        label: `${c.CaseNumber} - ${c.Subject} (${createdDate})`,
                        value: c.Id
                    };
                });
                console.log('Parent case options created:', this.parentCaseOptions.length);
            })
            .catch(error => {
                console.error('Error searching parent cases:', error);
                this.parentCaseOptions = [];
            });
    }

    /**
     * Handle Parent Case selection
     */
    handleParentCaseSelect(event) {
        event.preventDefault();
        const selectedValue = event.currentTarget.dataset.value;
        const selectedLabel = event.currentTarget.dataset.label;
        
        this.caseData.ParentId = selectedValue;
        this.selectedParentCaseLabel = selectedLabel;
        this.parentCaseSearchTerm = selectedLabel;
        this.isParentCaseDropdownOpen = false;
        this.parentCaseOptions = [];
    }

    /**
     * Clear Parent Case selection
     */
    clearParentCase() {
        this.caseData.ParentId = '';
        this.selectedParentCaseLabel = '';
        this.parentCaseSearchTerm = '';
        this.parentCaseOptions = [];
    }

    /**
     * Handle Escalated checkbox change
     */
    handleEscalatedChange(event) {
        this.caseData.IsEscalated = event.target.checked;
    }
    
    handleCapaChange(event) {
        this.caseData.DRC_NBC_CAPA_File_Uploaded__c = event.target.checked;
    }

    /**
     * Handle Account focus - Load accounts related to selected invoice
     */
    handleAccountFocus() {
        // Only allow account selection if invoice is selected
        if (!this.selectedInvoiceId) {
            this.showToast('Warning', 'Please select an Invoice first', 'warning');
            return;
        }
        
        this.isAccountDropdownOpen = true;
        this.performAccountSearch('');
    }

    /**
     * Handle Account blur
     */
    handleAccountBlur() {
        setTimeout(() => {
            this.isAccountDropdownOpen = false;
        }, 300);
    }

    /**
     * Handle Account search input
     */
    handleAccountSearch(event) {
        const searchTerm = event.target.value;
        this.accountSearchTerm = searchTerm;
        
        if (!this.selectedInvoiceId) {
            this.showToast('Warning', 'Please select an Invoice first', 'warning');
            return;
        }
        
        this.isAccountDropdownOpen = true;
        this.performAccountSearch(searchTerm);
    }

    /**
     * Perform Account search - Only searches accounts related to selected invoice
     */
    performAccountSearch(searchTerm) {
        // Pass the selected invoice ID to search only related accounts
        searchAccounts({ searchTerm: searchTerm, invoiceId: this.selectedInvoiceId })
            .then(accounts => {
                if (accounts.length === 0 && !searchTerm) {
                    // If no accounts found and no search term, show message
                    this.accountOptions = [{
                        label: 'No accounts found for this invoice',
                        value: '',
                        disabled: true
                    }];
                } else {
                    this.accountOptions = accounts.map(acc => ({
                        label: acc.Name,
                        value: acc.Id
                    }));
                }
            })
            .catch(error => {
                console.error('Error searching accounts:', error);
                this.accountOptions = [];
            });
    }

    /**
     * Handle Account selection
     */
    handleAccountSelect(event) {
        event.preventDefault();
        const selectedValue = event.currentTarget.dataset.value;
        const selectedLabel = event.currentTarget.dataset.label;
        
        this.caseData.AccountId = selectedValue;
        this.selectedAccountName = selectedLabel;
        this.accountSearchTerm = selectedLabel;
        this.isAccountDropdownOpen = false;
        this.accountOptions = [];
        
        // Clear contact when account changes
        this.caseData.ContactId = '';
        this.selectedContactName = '';
        this.contactEmail = '';
        this.contactPhone = '';
        this.contactSearchTerm = '';
        this.contactOptions = [];
    }

    /**
     * Clear Account selection
     */
    clearAccount() {
        this.caseData.AccountId = '';
        this.selectedAccountName = '';
        this.accountSearchTerm = '';
        this.accountOptions = [];
        
        // Also clear contact
        this.caseData.ContactId = '';
        this.selectedContactName = '';
        this.contactEmail = '';
        this.contactPhone = '';
        this.contactSearchTerm = '';
        this.contactOptions = [];
    }

    /**
     * Handle Contact focus
     */
    handleContactFocus() {
        this.isContactDropdownOpen = true;
        if (this.caseData.AccountId) {
            this.performContactSearch('', this.caseData.AccountId);
        }
    }

    /**
     * Handle Contact blur
     */
    handleContactBlur() {
        setTimeout(() => {
            this.isContactDropdownOpen = false;
        }, 300);
    }

    /**
     * Handle Contact search input
     */
    handleContactSearch(event) {
        const searchTerm = event.target.value;
        this.contactSearchTerm = searchTerm;
        
        if (this.caseData.AccountId) {
            this.isContactDropdownOpen = true;
            this.performContactSearch(searchTerm, this.caseData.AccountId);
        } else {
            this.contactOptions = [];
            this.isContactDropdownOpen = false;
        }
    }

    /**
     * Perform Contact search
     */
    performContactSearch(searchTerm, accountId) {
        searchContacts({ searchTerm: searchTerm, accountId: accountId })
            .then(contacts => {
                this.contactOptions = contacts.map(con => ({
                    label: con.Name,
                    value: con.Id
                }));
            })
            .catch(error => {
                console.error('Error searching contacts:', error);
                this.contactOptions = [];
            });
    }

    /**
     * Handle Contact selection
     */
    handleContactSelect(event) {
        event.preventDefault();
        const selectedValue = event.currentTarget.dataset.value;
        const selectedLabel = event.currentTarget.dataset.label;
        
        this.caseData.ContactId = selectedValue;
        this.selectedContactName = selectedLabel;
        this.contactSearchTerm = selectedLabel;
        this.isContactDropdownOpen = false;
        this.contactOptions = [];
        
        // Fetch contact details (email and phone)
        if (this.caseData.ContactId) {
            getContactDetails({ contactId: this.caseData.ContactId })
                .then(details => {
                    this.contactEmail = details.Email || '';
                    this.contactPhone = details.Phone || '';
                })
                .catch(error => {
                    console.error('Error fetching contact details:', error);
                });
        }
    }

    /**
     * Clear Contact selection
     */
    clearContact() {
        this.caseData.ContactId = '';
        this.selectedContactName = '';
        this.contactSearchTerm = '';
        this.contactEmail = '';
        this.contactPhone = '';
        this.contactOptions = [];
    }

    /**
     * Show toast notification
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }
}