/**
* @File Name : DRC_NBCCaseInoviceLinkedController.cls
* @Description : Controller for creating/updating Cases with Invoice and Invoice Lot linking
* @Author :
* @Last Modified By :
* @Last Modified On : December 31, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 19, 2025 |   | Initial Version
* 1.1 | December 23, 2025 |   | Changed to create new Case instead of update
* 1.2 | December 23, 2025 |   | Added Product Description field to query
* 1.3 | December 24, 2025 |   | Added rich text field for lot/complaint quantity info
* 1.4 | December 30, 2025 |   | Changed back to update existing Case
* 1.5 | December 30, 2025 |   | Updated to work with Invoice Lot object
* 1.6 | December 30, 2025 |   | Modified search methods to load all records on focus
* 1.7 | December 31, 2025 |   | Updated parent case search to sort by ascending date
**/

public class DRC_NBCCaseInoviceLinkedController {
    
    @AuraEnabled(cacheable=true)
    public static List<DRC_NBC_Invoice__c> getAvailableInvoices() {
        return [
            SELECT Id, Name, DRC_NBC_Invoice_Number__c, DRC_NBC_Account__c, DRC_NBC_Order__c
            FROM DRC_NBC_Invoice__c 
            ORDER BY CreatedDate DESC 
            LIMIT 50
        ];
    }

    @AuraEnabled
    public static Case getCaseDetails(Id caseId) {
        if (caseId == null) {
            // Return empty case for new record
            return new Case();
        }
        
        return [
            SELECT 
                Id,
                CaseNumber,
                Subject,
                Status,
                ParentId,
                Parent.CaseNumber,
                IsEscalated,
                DRC_NBC_CAPA_File_Uploaded__c,
                Origin,
                Priority,
                Description,
                Comments,
                DRC_NBC_Issue_type__c,
                DRC_NBC_Action_Inititated_By_DRC__c,
                DRC_NBCPreferred_Resolution_to_Customers__c,
                DRC_NBC_Invoice__c,
                AccountId,
                Account.Name,
                ContactId,
                Contact.Name,
                Contact.Email,
                Contact.Phone
            FROM Case 
            WHERE Id = :caseId 
            LIMIT 1
        ];
    }
    
    /**
     * Search parent cases - UPDATED to sort by CreatedDate ASC
     * NOTE: Not cacheable to ensure fresh results on each search
     */
    @AuraEnabled
    public static List<Case> searchParentCases(String searchTerm, Id accountId) {
        String searchKey = '%' + (String.isBlank(searchTerm) ? '' : searchTerm) + '%';
        
        // If account is selected, filter by account
        if (accountId != null) {
            if (String.isBlank(searchTerm)) {
                // Return all cases for this account - SORTED BY ASCENDING DATE
                return [
                    SELECT Id, CaseNumber, Subject, Status, CreatedDate
                    FROM Case 
                    WHERE AccountId = :accountId
                    ORDER BY CreatedDate ASC
                    LIMIT 50
                ];
            } else {
                // Search within account's cases - SORTED BY ASCENDING DATE
                return [
                    SELECT Id, CaseNumber, Subject, Status, CreatedDate
                    FROM Case 
                    WHERE AccountId = :accountId
                      AND (CaseNumber LIKE :searchKey OR Subject LIKE :searchKey)
                    ORDER BY CreatedDate ASC
                    LIMIT 50
                ];
            }
        } else {
            // No account selected - search all cases
            if (String.isBlank(searchTerm)) {
                // Return recent cases - SORTED BY ASCENDING DATE
                return [
                    SELECT Id, CaseNumber, Subject, Status, CreatedDate
                    FROM Case 
                    ORDER BY CreatedDate ASC
                    LIMIT 50
                ];
            } else {
                // Search with term - SORTED BY ASCENDING DATE
                return [
                    SELECT Id, CaseNumber, Subject, Status, CreatedDate
                    FROM Case 
                    WHERE CaseNumber LIKE :searchKey 
                       OR Subject LIKE :searchKey
                    ORDER BY CreatedDate ASC
                    LIMIT 50
                ];
            }
        }
    }
    
    /**
     * Search accounts - MODIFIED to return all accounts when search is empty
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchTerm, String invoiceId) {
        try {
            String searchPattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';
            
            // If invoiceId is provided, only return the account related to that invoice
            if (String.isNotBlank(invoiceId)) {
                // Get the account from the invoice
                List<DRC_NBC_Invoice__c> invoices = [
                    SELECT Id, DRC_NBC_Account__c, DRC_NBC_Account__r.Name
                    FROM DRC_NBC_Invoice__c 
                    WHERE Id = :invoiceId 
                    LIMIT 1
                ];
                
                if (!invoices.isEmpty() && invoices[0].DRC_NBC_Account__c != null) {
                    String accountId = invoices[0].DRC_NBC_Account__c;
                    String accountName = invoices[0].DRC_NBC_Account__r.Name;
                    
                    // Return the account if it matches search term (or no search term provided)
                    if (String.isBlank(searchTerm) || 
                        accountName.toLowerCase().contains(searchTerm.toLowerCase())) {
                        return [
                            SELECT Id, Name 
                            FROM Account 
                            WHERE Id = :accountId
                            LIMIT 1
                        ];
                    } else {
                        // Search term provided but doesn't match the invoice's account
                        return new List<Account>();
                    }
                } else {
                    // Invoice has no related account
                    return new List<Account>();
                }
            }
            
            // Fallback: If no invoiceId provided, search all accounts
            return [
                SELECT Id, Name 
                FROM Account 
                WHERE Name LIKE :searchPattern 
                ORDER BY Name 
                LIMIT 50
            ];
            
        } catch (Exception e) {
            throw new AuraHandledException('Error searching accounts: ' + e.getMessage());
        }
    }
    
    /**
     * Search contacts - MODIFIED to return all contacts for account when search is empty
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> searchContacts(String searchTerm, Id accountId) {
        String searchKey = '%' + (String.isBlank(searchTerm) ? '' : searchTerm) + '%';
        
        if (accountId != null) {
            if (String.isBlank(searchTerm)) {
                // Return all contacts for this account
                return [
                    SELECT Id, Name, Email, Phone, AccountId, Account.Name
                    FROM Contact 
                    WHERE AccountId = :accountId
                    ORDER BY Name
                    LIMIT 50
                ];
            } else {
                // Search within account's contacts
                return [
                    SELECT Id, Name, Email, Phone, AccountId, Account.Name
                    FROM Contact 
                    WHERE AccountId = :accountId
                      AND (Name LIKE :searchKey OR Email LIKE :searchKey)
                    ORDER BY Name
                    LIMIT 50
                ];
            }
        } else {
            // No account selected
            if (String.isBlank(searchTerm)) {
                return new List<Contact>();
            }
            
            return [
                SELECT Id, Name, Email, Phone, AccountId, Account.Name
                FROM Contact 
                WHERE Name LIKE :searchKey OR Email LIKE :searchKey
                ORDER BY Name
                LIMIT 50
            ];
        }
    }
    
    @AuraEnabled
    public static Map<String, String> getContactDetails(Id contactId) {
        if (contactId == null) {
            return new Map<String, String>();
        }
        
        Contact con = [
            SELECT Id, Name, Email, Phone, AccountId, Account.Name
            FROM Contact 
            WHERE Id = :contactId 
            LIMIT 1
        ];
        
        return new Map<String, String>{
            'Email' => con.Email != null ? con.Email : '',
            'Phone' => con.Phone != null ? con.Phone : '',
            'AccountId' => con.AccountId != null ? con.AccountId : '',
            'AccountName' => con.Account != null ? con.Account.Name : ''
        };
    }

    @AuraEnabled
    public static Map<String, Object> saveCase(
        Id caseId,
        String caseDataJson, 
        Id invoiceId, 
        String selectedLotsJson
    ) {
        Savepoint sp = Database.setSavepoint();
        
        try {
            // Parse case data and selected lots
            Map<String, Object> caseDataMap = (Map<String, Object>) JSON.deserializeUntyped(caseDataJson);
            List<Object> selectedLotsList = (List<Object>) JSON.deserializeUntyped(selectedLotsJson);
            
            // Get invoice details
            DRC_NBC_Invoice__c invoice = [
                SELECT Id, DRC_NBC_Account__c, DRC_NBC_Order__c
                FROM DRC_NBC_Invoice__c 
                WHERE Id = :invoiceId 
                LIMIT 1
            ];
            
            // Build rich text field content for lot/complaint quantity info
            String lotComplaintInfo = buildLotComplaintQuantityInfo(selectedLotsList);
            
            Case caseRecord;
            Boolean isNewCase = (caseId == null);
            
            if (isNewCase) {
                // Create new Case
                caseRecord = new Case();
            } else {
                // Update existing Case
                caseRecord = [SELECT Id FROM Case WHERE Id = :caseId LIMIT 1];
            }
            
            // Set case fields
            caseRecord.Subject = (String) caseDataMap.get('Subject');
            caseRecord.Status = (String) caseDataMap.get('Status');
            
            // Handle ParentId
            String parentIdStr = (String) caseDataMap.get('ParentId');
            if (String.isNotBlank(parentIdStr)) {
                caseRecord.ParentId = parentIdStr;
            }
            
            caseRecord.IsEscalated = (Boolean) caseDataMap.get('IsEscalated');
            caseRecord.DRC_NBC_CAPA_File_Uploaded__c = (Boolean) caseDataMap.get('DRC_NBC_CAPA_File_Uploaded__c');
            caseRecord.Origin = (String) caseDataMap.get('Origin');
            caseRecord.Priority = (String) caseDataMap.get('Priority');
            caseRecord.Description = (String) caseDataMap.get('Description');
            caseRecord.DRC_NBC_Issue_type__c = (String) caseDataMap.get('DRC_NBC_Issue_type__c');
            caseRecord.DRC_NBC_Action_Inititated_By_DRC__c = (String) caseDataMap.get('DRC_NBC_Action_Inititated_By_DRC__c');
            caseRecord.DRC_NBCPreferred_Resolution_to_Customers__c = (String) caseDataMap.get('DRC_NBCPreferred_Resolution_to_Customers__c');
            caseRecord.DRC_NBC_Invoice__c = invoiceId;
            
            // Set Account and Contact if provided in caseData (overrides invoice account if specified)
            String accountIdFromData = (String) caseDataMap.get('AccountId');
            if (String.isNotBlank(accountIdFromData)) {
                caseRecord.AccountId = accountIdFromData;
            } else {
                caseRecord.AccountId = invoice.DRC_NBC_Account__c;
            }
            
            String contactIdFromData = (String) caseDataMap.get('ContactId');
            if (String.isNotBlank(contactIdFromData)) {
                caseRecord.ContactId = contactIdFromData;
            }
            
            caseRecord.DRC_Lot_Complaint_Quantiy_Info__c = lotComplaintInfo;
            
            if (isNewCase) {
                insert caseRecord;
            } else {
                update caseRecord;
            }
            
            // Update Invoice Lot records with complaint quantities
            if (!selectedLotsList.isEmpty()) {
                // First, clear any existing case links for this case (for edit mode)
                if (!isNewCase) {
                    List<DRC_NBC_Invoice_Lot__c> existingLots = [
                        SELECT Id, DRC_NBC_Case__c, DRC_NBC_Lot_Complaint_Quantity__c
                        FROM DRC_NBC_Invoice_Lot__c 
                        WHERE DRC_NBC_Case__c = :caseRecord.Id
                    ];
                    
                    // Clear the case link and complaint quantity for lots not in the new selection
                    Set<String> selectedLotIds = new Set<String>();
                    for (Object lotObj : selectedLotsList) {
                        Map<String, Object> lotMap = (Map<String, Object>) lotObj;
                        selectedLotIds.add((String) lotMap.get('lotId'));
                    }
                    
                    List<DRC_NBC_Invoice_Lot__c> lotsToClear = new List<DRC_NBC_Invoice_Lot__c>();
                    for (DRC_NBC_Invoice_Lot__c existingLot : existingLots) {
                        if (!selectedLotIds.contains(existingLot.Id)) {
                            existingLot.DRC_NBC_Case__c = null;
                            existingLot.DRC_NBC_Lot_Complaint_Quantity__c = null;
                            lotsToClear.add(existingLot);
                        }
                    }
                    
                    if (!lotsToClear.isEmpty()) {
                        update lotsToClear;
                    }
                }
                
                // Now update the selected lots
                List<DRC_NBC_Invoice_Lot__c> lotsToUpdate = new List<DRC_NBC_Invoice_Lot__c>();
                
                for (Object lotObj : selectedLotsList) {
                    Map<String, Object> lotMap = (Map<String, Object>) lotObj;
                    String lotId = (String) lotMap.get('lotId');
                    Object complaintQtyObj = lotMap.get('complaintQuantity');
                    
                    if (String.isNotBlank(lotId) && complaintQtyObj != null) {
                        // Convert complaint quantity to String for text field
                        String complaintQtyStr = String.valueOf(complaintQtyObj);
                        
                        DRC_NBC_Invoice_Lot__c lot = new DRC_NBC_Invoice_Lot__c(
                            Id = lotId,
                            DRC_NBC_Lot_Complaint_Quantity__c = complaintQtyStr,
                            DRC_NBC_Case__c = caseRecord.Id
                        );
                        lotsToUpdate.add(lot);
                    }
                }
                
                if (!lotsToUpdate.isEmpty()) {
                    update lotsToUpdate;
                }
            }
            
            return new Map<String, Object>{
                'success' => true,
                'caseId' => caseRecord.Id,
                'message' => 'Case ' + (isNewCase ? 'created' : 'updated') + ' successfully'
            };
            
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException('Error saving case: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static DRC_NBC_Invoice__c getInvoiceDetails(Id invoiceId) {
        return [
            SELECT 
                Id, 
                Name, 
                DRC_NBC_Invoice_Number__c,
                DRC_NBC_Invoice_Date__c,
                DRC_NBC_Order_Number__c,
                DRC_NBC_Account__c,
                DRC_NBC_Account__r.Name,
                DRC_NBC_Shipping_Customer_Name__c,
                DRC_NBC_Shipping_Address__c,
                DRC_NBC_Order__c,
                DRC_NBC_Order__r.OrderNumber
            FROM DRC_NBC_Invoice__c 
            WHERE Id = :invoiceId
            LIMIT 1
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<DRC_NBC_Invoice_Line_Item__c> getLineItemsForInvoice(Id invoiceId) {
        return [
            SELECT 
                Id, 
                DRC_NBC_Product__c, 
                DRC_NBC_Product__r.Name,
                DRC_NBC_Product__r.Description,
                DRC_NBC_Product_Code__c,
                DRC_NBC_Amount__c,
                (SELECT 
                    Id,
                    DRC_NBC_Lot_Number__c,
                    DRC_NBC_Lot_Quantity__c,
                    DRC_NBC_Lot_Complaint_Quantity__c,
                    DRC_NBC_Product__c,
                    DRC_NBC_Product__r.Name,
                    DRC_NBC_Invoice__c,
                    DRC_NBC_Case__c
                FROM Invoice_Lots__r)
            FROM DRC_NBC_Invoice_Line_Item__c 
            WHERE DRC_NBC_Invoice_Number__c = :invoiceId
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getIssueTypePicklistValues() {
        List<String> values = new List<String>();
        Schema.DescribeFieldResult fieldResult = Case.DRC_NBC_Issue_type__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : ple) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getOriginPicklistValues() {
        List<String> values = new List<String>();
        Schema.DescribeFieldResult fieldResult = Case.Origin.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : ple) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getPriorityPicklistValues() {
        List<String> values = new List<String>();
        Schema.DescribeFieldResult fieldResult = Case.Priority.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) values.add(entry.getValue());
        }
        return values;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getStatusPicklistValues() {
        List<String> values = new List<String>();
        Schema.DescribeFieldResult fieldResult = Case.Status.getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) values.add(entry.getValue());
        }
        return values;
    }
    
    /**
     * Helper method to build formatted lot/complaint quantity information
     */
    private static String buildLotComplaintQuantityInfo(List<Object> selectedLotsList) {
        List<String> formattedLines = new List<String>();
        Integer counter = 1;
        
        for (Object lotObj : selectedLotsList) {
            Map<String, Object> lotMap = (Map<String, Object>) lotObj;
            String productName = (String) lotMap.get('productName');
            String productCode = (String) lotMap.get('productCode');
            String lotNumber = (String) lotMap.get('lotNumber');
            Object qtyObj = lotMap.get('quantity');
            Object complaintQtyObj = lotMap.get('complaintQuantity');
            
            String quantity = 'N/A';
            if (qtyObj != null) {
                quantity = String.valueOf(qtyObj);
            }
            
            String complaintQuantity = '0';
            if (complaintQtyObj != null) {
                complaintQuantity = String.valueOf(complaintQtyObj);
            }
            
            String line = counter + '. Lot: "' + lotNumber + '"    Quantity: ' + quantity + 
                          '     Complaint Quantity: ' + complaintQuantity;
            
            // Add product info for better context
            if (String.isNotBlank(productName)) {
                line += ' (Product: ' + productName;
                if (String.isNotBlank(productCode)) {
                    line += ' - ' + productCode;
                }
                line += ')';
            }
            
            formattedLines.add(line);
            counter++;
        }
        
        return String.join(formattedLines, '<br/>');
    }
    
    /**
     * Helper method to convert various types to Decimal
     */
    private static Decimal convertToDecimal(Object value) {
        if (value == null) return 0;
        
        if (value instanceof Decimal) {
            return (Decimal) value;
        } else if (value instanceof Integer) {
            return (Decimal) value;
        } else if (value instanceof String) {
            String strValue = ((String) value).trim();
            if (String.isEmpty(strValue)) return 0;
            try {
                return Decimal.valueOf(strValue);
            } catch (Exception e) {
                System.debug('Error converting to Decimal: ' + strValue);
                return 0;
            }
        }
        
        return 0;
    }
}