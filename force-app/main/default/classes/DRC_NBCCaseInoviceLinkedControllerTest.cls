/**
* @File Name        : DRC_NBCCaseInoviceLinkedControllerTest.cls
* @Description      : Test class for DRC_NBCCaseInoviceLinkedController
* @Coverage Target  : 100%
* @Modification Log :
*==============================================================================
* Ver   | Date             | Author    | Modification
*==============================================================================
* 1.0   | January 2026     | Developer | Initial Version
* 1.1   | January 2026     | Developer | Added tests for buildLotComplaintQuantityInfo branches
**/
@isTest
private class DRC_NBCCaseInoviceLinkedControllerTest {
    
    private static Account createAccount(String name) {
        Account acc = new Account(Name = name);
        insert acc;
        return acc;
    }
    
    private static Contact createContact(Id accountId, String firstName, String lastName) {
        Contact con = new Contact(
            FirstName = firstName,
            LastName  = lastName,
            AccountId = accountId,
            Email     = firstName.toLowerCase() + '.' + lastName.toLowerCase() + '@test.com',
            Phone     = '9876543210'
        );
        insert con;
        return con;
    }
    
    private static Order createOrder(Id accountId) {
        Order ord = new Order(
            AccountId     = accountId,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id  = Test.getStandardPricebookId()
        );
        insert ord;
        return ord;
    }
    
    private static DRC_NBC_Invoice__c createInvoice(Id accountId, Id orderId) {
        DRC_NBC_Invoice__c inv = new DRC_NBC_Invoice__c(
            DRC_NBC_Account__c = accountId,
            DRC_NBC_Order__c   = orderId
        );
        insert inv;
        return inv;
    }
    
    private static Product2 createProduct(String name, String code) {
        Product2 prod = new Product2(
            Name        = name,
            ProductCode = code,
            IsActive    = true
        );
        insert prod;
        return prod;
    }
    
    private static DRC_NBC_Invoice_Line_Item__c createLineItem(Id invoiceId, Id productId, String productCode) {
        DRC_NBC_Invoice_Line_Item__c li = new DRC_NBC_Invoice_Line_Item__c(
            DRC_NBC_Invoice_Number__c = invoiceId,
            DRC_NBC_Product__c        = productId,
            DRC_NBC_Product_Code__c   = productCode,
            DRC_NBC_Amount__c         = 1000
        );
        insert li;
        return li;
    }
    
    private static DRC_NBC_Invoice_Lot__c createInvoiceLot(Id lineItemId, Id invoiceId, Id productId, String lotNumber, Decimal qty) {
        DRC_NBC_Invoice_Lot__c lot = new DRC_NBC_Invoice_Lot__c(
            DRC_NBC_Invoice_Line_Item__c = lineItemId,
            DRC_NBC_Invoice__c           = invoiceId,
            DRC_NBC_Product__c           = productId,
            DRC_NBC_Lot_Number__c        = lotNumber,
            DRC_NBC_Lot_Quantity__c      = String.valueOf(qty)
        );
        insert lot;
        return lot;
    }
    
    private static Case createCase(Id accountId, Id contactId, Id invoiceId) {
        Case c = new Case(
            Subject               = 'Test Case',
            Status                = 'New',
            Origin                = 'Email',
            Priority              = 'Medium',
            AccountId             = accountId,
            ContactId             = contactId,
            DRC_NBC_Invoice__c    = invoiceId,
            Description           = 'Test Description',
            DRC_NBC_Issue_type__c = 'Others'
        );
        insert c;
        return c;
    }
    
    /**
     * Builds the caseDataJson string used in saveCase
     */
    private static String buildCaseDataJson(
        Id accountId,
        Id contactId,
        Id parentId,
        Boolean isEscalated,
        Boolean capaUploaded
    ) {
        Map<String, Object> data = new Map<String, Object>{
            'Subject'                                     => 'Test Subject',
            'Status'                                      => 'New',
            'ParentId'                                    => parentId != null ? String.valueOf(parentId) : '',
            'IsEscalated'                                 => isEscalated,
            'DRC_NBC_CAPA_File_Uploaded__c'               => capaUploaded,
            'Origin'                                      => 'Email',
            'Priority'                                    => 'Medium',
            'Description'                                 => 'Test description',
            'DRC_NBC_Issue_type__c'                       => 'Quality',
            'DRC_NBC_Action_Inititated_By_DRC__c'         => 'Rework',
            'DRC_NBCPreferred_Resolution_to_Customers__c' => 'Replacement',
            'AccountId'                                   => accountId != null ? String.valueOf(accountId) : '',
            'ContactId'                                   => contactId != null ? String.valueOf(contactId) : ''
        };
        return JSON.serialize(data);
    }
    
    /**
     * Builds selectedLotsJson with configurable options
     * includeProductInfo : whether to include productName/productCode
     * nullQty            : whether to pass null for quantity/complaintQuantity
     */
    private static String buildSelectedLotsJson(List<Id> lotIds, Boolean includeProductInfo, Boolean nullQty) {
        List<Map<String, Object>> lots = new List<Map<String, Object>>();
        Integer i = 1;
        for (Id lotId : lotIds) {
            Map<String, Object> lot = new Map<String, Object>{
                'lotId'     => String.valueOf(lotId),
                'lotNumber' => 'LOT00' + i
            };
            if (nullQty) {
                lot.put('quantity',          null);
                lot.put('complaintQuantity', null);
            } else {
                lot.put('quantity',          i * 100);
                lot.put('complaintQuantity', i * 10);
            }
            if (includeProductInfo) {
                lot.put('productName', 'Product ' + i);
                lot.put('productCode', 'P00' + i);
            } else {
                lot.put('productName', '');
                lot.put('productCode', '');
            }
            lots.add(lot);
            i++;
        }
        return JSON.serialize(lots);
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: getAvailableInvoices
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testGetAvailableInvoices_ReturnsResults() {
        Account acc = createAccount('Inv Account');
        Order ord   = createOrder(acc.Id);
        createInvoice(acc.Id, ord.Id);
        
        Test.startTest();
        List<DRC_NBC_Invoice__c> result = DRC_NBCCaseInoviceLinkedController.getAvailableInvoices();
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.size() >= 1, 'Should return at least 1 invoice');
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: getCaseDetails
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testGetCaseDetails_NullId_ReturnsEmptyCase() {
        Test.startTest();
        Case result = DRC_NBCCaseInoviceLinkedController.getCaseDetails(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(null, result.Id, 'Empty case should have no Id');
    }
    
    @isTest
    static void testGetCaseDetails_WithValidId() {
        Account acc = createAccount('Case Account');
        Contact con = createContact(acc.Id, 'John', 'Doe');
        Order ord   = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Case c = createCase(acc.Id, con.Id, inv.Id);
        
        Test.startTest();
        Case result = DRC_NBCCaseInoviceLinkedController.getCaseDetails(c.Id);
        Test.stopTest();
        
        System.assertEquals(c.Id,        result.Id);
        System.assertEquals('Test Case',  result.Subject);
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: searchParentCases  (4 branches)
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testSearchParentCases_WithAccount_BlankTerm() {
        Account acc = createAccount('Search Account 1');
        insert new Case(AccountId = acc.Id, Subject = 'Parent Case', Status = 'New', Origin = 'Email',
                        Description = 'Description', DRC_NBC_Issue_type__c = 'Others');
        
        Test.startTest();
        List<Case> result = DRC_NBCCaseInoviceLinkedController.searchParentCases('', acc.Id);
        Test.stopTest();
        
        System.assert(result.size() >= 1);
    }
    
    @isTest
    static void testSearchParentCases_WithAccount_WithTerm() {
        Account acc = createAccount('Search Account 2');
        insert new Case(AccountId = acc.Id, Subject = 'Specific Subject', Status = 'New', Origin = 'Email',
                        Description = 'Description', DRC_NBC_Issue_type__c = 'Others');
        
        Test.startTest();
        List<Case> result = DRC_NBCCaseInoviceLinkedController.searchParentCases('Specific', acc.Id);
        Test.stopTest();
        
        System.assert(result.size() >= 1);
    }
    
    @isTest
    static void testSearchParentCases_NoAccount_BlankTerm() {
        Test.startTest();
        List<Case> result = DRC_NBCCaseInoviceLinkedController.searchParentCases('', null);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: searchAccounts
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testSearchAccounts_WithInvoiceId_MatchingSearch() {
        Account acc = createAccount('Invoice Account Alpha');
        Order ord   = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        
        Test.startTest();
        List<Account> result = DRC_NBCCaseInoviceLinkedController.searchAccounts('Invoice Account Alpha', inv.Id);
        Test.stopTest();
        
        System.assertEquals(1, result.size());
    }
    
    @isTest
    static void testSearchAccounts_WithInvoiceId_BlankSearch() {
        Account acc = createAccount('Invoice Account Beta');
        Order ord   = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        
        Test.startTest();
        List<Account> result = DRC_NBCCaseInoviceLinkedController.searchAccounts('', inv.Id);
        Test.stopTest();
        
        System.assertEquals(1, result.size());
    }
    
    @isTest
    static void testSearchAccounts_WithInvoiceId_NonMatchingSearch() {
        Account acc = createAccount('Invoice Account Gamma');
        Order ord   = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        
        Test.startTest();
        List<Account> result = DRC_NBCCaseInoviceLinkedController.searchAccounts('ZZZNOMATCH', inv.Id);
        Test.stopTest();
        
        System.assertEquals(0, result.size());
    }
    
    @isTest
    static void testSearchAccounts_WithInvoiceId_NoLinkedAccount() {
        Account acc = createAccount('Satish');
        DRC_NBC_Invoice__c inv = new DRC_NBC_Invoice__c();
        inv.DRC_NBC_Account__c = acc.Id;
        insert inv;
        
        Test.startTest();
        List<Account> result = DRC_NBCCaseInoviceLinkedController.searchAccounts('anything', inv.Id);
        Test.stopTest();
        
        System.assertEquals(0, result.size());
    }
    
    @isTest
    static void testSearchAccounts_NoInvoiceId_FallbackSearch() {
        createAccount('Fallback Search Account');
        
        Test.startTest();
        List<Account> result = DRC_NBCCaseInoviceLinkedController.searchAccounts('Fallback', '');
        Test.stopTest();
        
        System.assert(result.size() >= 1);
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: searchContacts  (4 branches)
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testSearchContacts_WithAccount_BlankTerm() {
        Account acc = createAccount('Contact Account 1');
        createContact(acc.Id, 'Alice', 'Smith');
        
        Test.startTest();
        List<Contact> result = DRC_NBCCaseInoviceLinkedController.searchContacts('', acc.Id);
        Test.stopTest();
        
        System.assert(result.size() >= 1);
    }
    
    @isTest
    static void testSearchContacts_WithAccount_WithTerm() {
        Account acc = createAccount('Contact Account 2');
        createContact(acc.Id, 'Robert', 'Jones');
        
        Test.startTest();
        List<Contact> result = DRC_NBCCaseInoviceLinkedController.searchContacts('Robert', acc.Id);
        Test.stopTest();
        
        System.assert(result.size() >= 1);
    }
    
    @isTest
    static void testSearchContacts_NoAccount_BlankTerm() {
        Test.startTest();
        List<Contact> result = DRC_NBCCaseInoviceLinkedController.searchContacts('', null);
        Test.stopTest();
        
        System.assertEquals(0, result.size());
    }
    
    @isTest
    static void testSearchContacts_NoAccount_WithTerm() {
        Account acc = createAccount('Contact Account 3');
        createContact(acc.Id, 'Charlie', 'Brown');
        
        Test.startTest();
        List<Contact> result = DRC_NBCCaseInoviceLinkedController.searchContacts('Charlie', null);
        Test.stopTest();
        
        System.assert(result.size() >= 1);
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: getContactDetails
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testGetContactDetails_NullId() {
        Test.startTest();
        Map<String, String> result = DRC_NBCCaseInoviceLinkedController.getContactDetails(null);
        Test.stopTest();
        
        System.assertEquals(0, result.size());
    }
    
    @isTest
    static void testGetContactDetails_ValidId() {
        Account acc = createAccount('Contact Details Account');
        Contact con = createContact(acc.Id, 'Details', 'User');
        
        Test.startTest();
        Map<String, String> result = DRC_NBCCaseInoviceLinkedController.getContactDetails(con.Id);
        Test.stopTest();
        
        System.assert(result.containsKey('Email'));
        System.assert(result.containsKey('Phone'));
        System.assert(result.containsKey('AccountId'));
        System.assert(result.containsKey('AccountName'));
        System.assertEquals(String.valueOf(acc.Id), result.get('AccountId'));
    }
    
    @isTest
    static void testGetContactDetails_NullEmailAndPhone() {
        Account acc = createAccount('Null Contact Account');
        Contact con = new Contact(LastName = 'NoDetails', AccountId = acc.Id, Email = null, Phone = null);
        insert con;
        
        Test.startTest();
        Map<String, String> result = DRC_NBCCaseInoviceLinkedController.getContactDetails(con.Id);
        Test.stopTest();
        
        System.assertEquals('', result.get('Email'), 'Null email should return empty string');
        System.assertEquals('', result.get('Phone'), 'Null phone should return empty string');
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: saveCase – Exception / rollback
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testSaveCase_Exception_RollsBack() {
        Account acc = createAccount('Exception Account');
        Order ord   = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        
        try {
            Test.startTest();
            DRC_NBCCaseInoviceLinkedController.saveCase(null, 'INVALID_JSON', inv.Id, '[]');
            Test.stopTest();
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: saveCase – NEW CASE: with lots that have productName + productCode
    // Covers: non-null qty branches, isNotBlank(productName) + isNotBlank(productCode)
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testSaveCase_NewCase_WithLotsAndProductInfo() {
        Account acc   = createAccount('SaveCase New Account 1');
        Contact con   = createContact(acc.Id, 'Save', 'New');
        Order ord     = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Product2 prod = createProduct('Test Product A', 'TPA001');
        DRC_NBC_Invoice_Line_Item__c li = createLineItem(inv.Id, prod.Id, 'TPA001');
        DRC_NBC_Invoice_Lot__c lot1 = createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOT-001', 100);
        DRC_NBC_Invoice_Lot__c lot2 = createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOT-002', 200);
        
        String caseDataJson     = buildCaseDataJson(acc.Id, con.Id, null, false, false);
        // includeProductInfo=true, nullQty=false
        // → covers non-null qty branch AND productName/productCode branch
        String selectedLotsJson = buildSelectedLotsJson(
            new List<Id>{ lot1.Id, lot2.Id }, true, false
        );
        
        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(
            null, caseDataJson, inv.Id, selectedLotsJson
        );
        Test.stopTest();
        
        System.assertEquals(true,  result.get('success'));
        System.assertNotEquals(null, result.get('caseId'));
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: saveCase – NEW CASE: lots with blank productName/productCode
    // Covers: isBlank(productName) branch → no product suffix appended
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testSaveCase_NewCase_WithLotsBlankProductInfo() {
        Account acc   = createAccount('SaveCase New Account 2');
        Order ord     = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Product2 prod = createProduct('Test Product B', 'TPB001');
        DRC_NBC_Invoice_Line_Item__c li = createLineItem(inv.Id, prod.Id, 'TPB001');
        DRC_NBC_Invoice_Lot__c lot = createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOT-BLANK-001', 50);
        
        String caseDataJson     = buildCaseDataJson(acc.Id, null, null, false, false);
        // includeProductInfo=false → blank productName/productCode branch
        String selectedLotsJson = buildSelectedLotsJson(
            new List<Id>{ lot.Id }, false, false
        );
        
        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(
            null, caseDataJson, inv.Id, selectedLotsJson
        );
        Test.stopTest();
        
        System.assertEquals(true, result.get('success'));
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: saveCase – NEW CASE: lots where quantity and complaintQuantity are null
    // Covers: qtyObj == null → quantity = 'N/A'
    //         complaintQtyObj == null → complaintQuantity = '0'
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testSaveCase_NewCase_WithLotsNullQty() {
        Account acc   = createAccount('SaveCase New Account 3');
        Order ord     = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Product2 prod = createProduct('Test Product C', 'TPC001');
        DRC_NBC_Invoice_Line_Item__c li = createLineItem(inv.Id, prod.Id, 'TPC001');
        DRC_NBC_Invoice_Lot__c lot = createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOT-NULL-001', 30);
        
        String caseDataJson     = buildCaseDataJson(acc.Id, null, null, false, false);
        // nullQty=true → quantity==null and complaintQuantity==null branches
        String selectedLotsJson = buildSelectedLotsJson(
            new List<Id>{ lot.Id }, true, true
        );
        
        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(
            null, caseDataJson, inv.Id, selectedLotsJson
        );
        Test.stopTest();
        
        System.assertEquals(true, result.get('success'));
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: saveCase – NEW CASE: productName set but productCode is blank
    // Covers: isNotBlank(productName) but isBlank(productCode) → name only, no " - code"
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testSaveCase_NewCase_WithProductNameNoCode() {
        Account acc   = createAccount('SaveCase New Account 4');
        Order ord     = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Product2 prod = createProduct('Test Product D', 'TPD001');
        DRC_NBC_Invoice_Line_Item__c li = createLineItem(inv.Id, prod.Id, 'TPD001');
        DRC_NBC_Invoice_Lot__c lot = createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOT-NOCODE-001', 60);
        
        // Manually build lot JSON: productName present, productCode blank
        List<Map<String, Object>> lotsList = new List<Map<String, Object>>{
            new Map<String, Object>{
                'lotId'             => String.valueOf(lot.Id),
                'lotNumber'         => 'LOT-NOCODE-001',
                'quantity'          => 60,
                'complaintQuantity' => 5,
                'productName'       => 'Test Product D',
                'productCode'       => ''
            }
        };
        String selectedLotsJson = JSON.serialize(lotsList);
        String caseDataJson     = buildCaseDataJson(acc.Id, null, null, false, false);
        
        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(
            null, caseDataJson, inv.Id, selectedLotsJson
        );
        Test.stopTest();
        
        System.assertEquals(true, result.get('success'));
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: saveCase – UPDATE CASE: clears old lot links and links new ones
    // Covers: isNewCase=false block, clear existing lots, update selected lots,
    //         non-blank ParentId branch
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testSaveCase_UpdateCase_ClearsOldLotsAndLinksNew() {
        Account acc   = createAccount('SaveCase Update Account');
        Contact con   = createContact(acc.Id, 'Update', 'User');
        Order ord     = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Product2 prod = createProduct('Test Product E', 'TPE001');
        DRC_NBC_Invoice_Line_Item__c li = createLineItem(inv.Id, prod.Id, 'TPE001');
        
        // lot1 was previously linked, lot2 is the new selection
        DRC_NBC_Invoice_Lot__c lot1 = createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOT-OLD-001', 100);
        DRC_NBC_Invoice_Lot__c lot2 = createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOT-NEW-001', 200);
        
        // Create the existing case and manually link lot1 to it
        Case existingCase = createCase(acc.Id, con.Id, inv.Id);
        lot1.DRC_NBC_Case__c = existingCase.Id;
        update lot1;
        
        // Create a parent case to cover the non-blank ParentId branch
        Case parentCase = new Case(
            Subject               = 'Parent Case',
            Status                = 'New',
            Origin                = 'Email',
            AccountId             = acc.Id,
            Description           = 'Parent',
            DRC_NBC_Issue_type__c = 'Others'
        );
        insert parentCase;
        
        String caseDataJson = buildCaseDataJson(acc.Id, con.Id, parentCase.Id, true, true);
        // Only lot2 in selection → lot1 should be cleared, lot2 linked
        String selectedLotsJson = buildSelectedLotsJson(
            new List<Id>{ lot2.Id }, true, false
        );
        
        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(
            existingCase.Id, caseDataJson, inv.Id, selectedLotsJson
        );
        Test.stopTest();
        
        System.assertEquals(true,           result.get('success'));
        System.assertEquals(existingCase.Id, (Id) result.get('caseId'));
        
        // Verify lot1 was cleared
        DRC_NBC_Invoice_Lot__c clearedLot = [
            SELECT DRC_NBC_Case__c FROM DRC_NBC_Invoice_Lot__c WHERE Id = :lot1.Id
        ];
        System.assertEquals(null, clearedLot.DRC_NBC_Case__c, 'lot1 should have been unlinked');
        
        // Verify lot2 was linked
        DRC_NBC_Invoice_Lot__c linkedLot = [
            SELECT DRC_NBC_Case__c FROM DRC_NBC_Invoice_Lot__c WHERE Id = :lot2.Id
        ];
        System.assertEquals(existingCase.Id, linkedLot.DRC_NBC_Case__c, 'lot2 should be linked to the case');
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: saveCase – NEW CASE: no AccountId in caseData
    // Covers: isBlank(accountIdFromData) → falls back to invoice.DRC_NBC_Account__c
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testSaveCase_NewCase_FallsBackToInvoiceAccount() {
        Account acc = createAccount('Fallback Invoice Account');
        Order ord   = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        
        // Pass null AccountId so fallback branch (invoice.DRC_NBC_Account__c) is hit
        String caseDataJson = buildCaseDataJson(null, null, null, false, false);
        
        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(
            null, caseDataJson, inv.Id, '[]'
        );
        Test.stopTest();
        
        System.assertEquals(true, result.get('success'));
        Case saved = [SELECT AccountId FROM Case WHERE Id = :(Id) result.get('caseId')];
        System.assertEquals(acc.Id, saved.AccountId, 'Should fall back to invoice account');
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: getInvoiceDetails
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testGetInvoiceDetails() {
        Account acc = createAccount('Invoice Details Account');
        Order ord   = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        
        Test.startTest();
        DRC_NBC_Invoice__c result = DRC_NBCCaseInoviceLinkedController.getInvoiceDetails(inv.Id);
        Test.stopTest();
        
        System.assertEquals(inv.Id, result.Id);
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: getLineItemsForInvoice
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testGetLineItemsForInvoice() {
        Account acc   = createAccount('Line Items Account');
        Order ord     = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Product2 prod = createProduct('Line Item Product', 'LIP001');
        DRC_NBC_Invoice_Line_Item__c li = createLineItem(inv.Id, prod.Id, 'LIP001');
        createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOT-LINE-001', 75);
        
        Test.startTest();
        List<DRC_NBC_Invoice_Line_Item__c> result = DRC_NBCCaseInoviceLinkedController.getLineItemsForInvoice(inv.Id);
        Test.stopTest();
        
        System.assertEquals(1, result.size());
        System.assertEquals(1, result[0].Invoice_Lots__r.size());
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: Picklist value methods
    // ─────────────────────────────────────────────────────────────────────────
    
    @isTest
    static void testGetIssueTypePicklistValues() {
        Test.startTest();
        List<String> result = DRC_NBCCaseInoviceLinkedController.getIssueTypePicklistValues();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetOriginPicklistValues() {
        Test.startTest();
        List<String> result = DRC_NBCCaseInoviceLinkedController.getOriginPicklistValues();
        Test.stopTest();
        System.assert(result.size() > 0);
    }
    
    @isTest
    static void testGetPriorityPicklistValues() {
        Test.startTest();
        List<String> result = DRC_NBCCaseInoviceLinkedController.getPriorityPicklistValues();
        Test.stopTest();
        System.assert(result.size() > 0);
    }
    
    @isTest
    static void testGetStatusPicklistValues() {
        Test.startTest();
        List<String> result = DRC_NBCCaseInoviceLinkedController.getStatusPicklistValues();
        Test.stopTest();
        System.assert(result.size() > 0);
    }
}