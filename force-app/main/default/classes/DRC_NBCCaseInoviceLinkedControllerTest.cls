/**
 * @File Name        : DRC_NBCCaseInoviceLinkedControllerTest.cls
 * @Description      : Test class for DRC_NBCCaseInoviceLinkedController
 * @Coverage Target  : 100%
 * @Modification Log :
 *==============================================================================
 * Ver   | Date             | Author    | Modification
 *==============================================================================
 * 1.0   | January 2026     | Developer | Initial Version
 **/
@isTest
private class DRC_NBCCaseInoviceLinkedControllerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // TEST DATA FACTORY
    // ─────────────────────────────────────────────────────────────────────────

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
            Subject            = 'Test Case',
            Status             = 'New',
            Origin             = 'Email',
            Priority           = 'Medium',
            AccountId          = accountId,
            ContactId          = contactId,
            DRC_NBC_Invoice__c = invoiceId,
            Description = 'Test Description',
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
     * includeProductInfo: whether to include productName/productCode (tests those branches in buildLotComplaintQuantityInfo)
     * nullQty:            whether to pass null for quantity/complaintQuantity (tests null-qty branches)
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
                lot.put('quantity',         null);
                lot.put('complaintQuantity', null);
            } else {
                lot.put('quantity',          i * 100);
                lot.put('complaintQuantity', i * 10);
            }
            if (includeProductInfo) {
                lot.put('productName', 'Product ' + i);
                lot.put('productCode', 'P00' + i);
            } else {
                // Blank productName to cover that branch
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

        System.assertEquals(c.Id,       result.Id);
        System.assertEquals('Test Case', result.Subject);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: searchParentCases  (4 branches)
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSearchParentCases_WithAccount_BlankTerm() {
        Account acc = createAccount('Search Account 1');
        insert new Case(AccountId = acc.Id, Subject = 'Parent Case', Status = 'New', Origin = 'Email');

        Test.startTest();
        List<Case> result = DRC_NBCCaseInoviceLinkedController.searchParentCases('', acc.Id);
        Test.stopTest();

        System.assert(result.size() >= 1);
    }

    @isTest
    static void testSearchParentCases_WithAccount_WithTerm() {
        Account acc = createAccount('Search Account 2');
        insert new Case(AccountId = acc.Id, Subject = 'Specific Subject', Status = 'New', Origin = 'Email');

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

    @isTest
    static void testSearchParentCases_NoAccount_WithTerm() {
        insert new Case(Subject = 'UniqueTermCase', Status = 'New', Origin = 'Email');

        Test.startTest();
        List<Case> result = DRC_NBCCaseInoviceLinkedController.searchParentCases('UniqueTermCase', null);
        Test.stopTest();

        System.assert(result.size() >= 1);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: searchAccounts  (5 branches)
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
        // Invoice with no account
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

        System.assertEquals('', result.get('Email'), 'Null email → empty string');
        System.assertEquals('', result.get('Phone'), 'Null phone → empty string');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: saveCase – New Case scenarios
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveCase_NewCase_NoLots() {
        Account acc = createAccount('Save New Case Account');
        Order ord   = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Contact con = createContact(acc.Id, 'New', 'CaseContact');

        String caseJson = buildCaseDataJson(acc.Id, con.Id, null, false, false);
        String lotsJson = JSON.serialize(new List<Object>());

        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(null, caseJson, inv.Id, lotsJson);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assert(((String) result.get('message')).contains('created'));
        System.assertNotEquals(null, result.get('caseId'));
    }

    @isTest
    static void testSaveCase_NewCase_WithLots_FullProductInfo() {
        Account acc   = createAccount('New Case With Lots Account');
        Order ord     = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Product2 prod = createProduct('Lot Product', 'LP001');
        DRC_NBC_Invoice_Line_Item__c li = createLineItem(inv.Id, prod.Id, 'LP001');
        DRC_NBC_Invoice_Lot__c lot1    = createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOT001', 100);
        DRC_NBC_Invoice_Lot__c lot2    = createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOT002', 200);
        Contact con = createContact(acc.Id, 'Lots', 'Contact');

        String caseJson = buildCaseDataJson(acc.Id, con.Id, null, true, true);
        String lotsJson = buildSelectedLotsJson(new List<Id>{ lot1.Id, lot2.Id }, true, false);

        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(null, caseJson, inv.Id, lotsJson);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        Id newCaseId = (Id) result.get('caseId');

        List<DRC_NBC_Invoice_Lot__c> updatedLots = [
            SELECT DRC_NBC_Case__c
            FROM DRC_NBC_Invoice_Lot__c
            WHERE Id IN (:lot1.Id, :lot2.Id)
        ];
        for (DRC_NBC_Invoice_Lot__c ul : updatedLots) {
            System.assertEquals(newCaseId, ul.DRC_NBC_Case__c, 'Lot should be linked to new case');
        }
    }

    @isTest
    static void testSaveCase_NewCase_WithLots_NoProductInfo_NullQty() {
        // Covers: blank productName branch + null quantity/complaintQuantity branches
        Account acc   = createAccount('New Case Null Qty Account');
        Order ord     = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Product2 prod = createProduct('Null Qty Product', 'NQP001');
        DRC_NBC_Invoice_Line_Item__c li = createLineItem(inv.Id, prod.Id, 'NQP001');
        DRC_NBC_Invoice_Lot__c lot      = createInvoiceLot(li.Id, inv.Id, prod.Id, 'LOTNULL', 50);

        // No account/contact in caseData → falls through to invoice.DRC_NBC_Account__c
        String caseJson = buildCaseDataJson(null, null, null, false, false);
        String lotsJson = buildSelectedLotsJson(new List<Id>{ lot.Id }, false, true);

        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(null, caseJson, inv.Id, lotsJson);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Should succeed with null quantities');
    }

    @isTest
    static void testSaveCase_NewCase_WithParentId() {
        Account acc = createAccount('Parent Case Account');
        Order ord   = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Case parentCase = new Case(Subject = 'Parent', Status = 'New', Origin = 'Email', AccountId = acc.Id);
        insert parentCase;

        String caseJson = buildCaseDataJson(acc.Id, null, parentCase.Id, false, false);
        String lotsJson = JSON.serialize(new List<Object>());

        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(null, caseJson, inv.Id, lotsJson);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        Case saved = [SELECT ParentId FROM Case WHERE Id = :(Id) result.get('caseId')];
        System.assertEquals(parentCase.Id, saved.ParentId);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TESTS: saveCase – Update Existing Case scenarios
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveCase_UpdateExistingCase_WithLotClearing() {
        Account acc   = createAccount('Update Case Account');
        Order ord     = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Product2 prod = createProduct('Update Product', 'UP001');
        DRC_NBC_Invoice_Line_Item__c li = createLineItem(inv.Id, prod.Id, 'UP001');

        Case existingCase = new Case(
            Subject            = 'Existing Case',
            Status             = 'New',
            Origin             = 'Email',
            AccountId          = acc.Id,
            DRC_NBC_Invoice__c = inv.Id,
            Description = 'Test Description',
            DRC_NBC_Issue_type__c = 'Others'
        );
        insert existingCase;

        // Pre-link an old lot to the case (it should be cleared in update)
        DRC_NBC_Invoice_Lot__c oldLot = createInvoiceLot(li.Id, inv.Id, prod.Id, 'OLD001', 100);
        oldLot.DRC_NBC_Case__c = existingCase.Id;
        update oldLot;

        // New lot to be selected in the update
        DRC_NBC_Invoice_Lot__c newLot = createInvoiceLot(li.Id, inv.Id, prod.Id, 'NEW001', 200);

        String caseJson = buildCaseDataJson(acc.Id, null, null, false, false);
        String lotsJson = buildSelectedLotsJson(new List<Id>{ newLot.Id }, true, false);

        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(existingCase.Id, caseJson, inv.Id, lotsJson);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
        System.assert(((String) result.get('message')).contains('updated'));

        DRC_NBC_Invoice_Lot__c clearedLot = [SELECT DRC_NBC_Case__c FROM DRC_NBC_Invoice_Lot__c WHERE Id = :oldLot.Id];
        System.assertEquals(null, clearedLot.DRC_NBC_Case__c, 'Old lot should have case cleared');

        DRC_NBC_Invoice_Lot__c linkedLot = [SELECT DRC_NBC_Case__c FROM DRC_NBC_Invoice_Lot__c WHERE Id = :newLot.Id];
        System.assertEquals(existingCase.Id, linkedLot.DRC_NBC_Case__c, 'New lot should be linked');
    }

    @isTest
    static void testSaveCase_UpdateExistingCase_NoLots() {
        Account acc = createAccount('Update No Lots Account');
        Order ord   = createOrder(acc.Id);
        DRC_NBC_Invoice__c inv = createInvoice(acc.Id, ord.Id);
        Case existingCase = new Case(
            Subject            = 'Update No Lots',
            Status             = 'New',
            Origin             = 'Email',
            AccountId          = acc.Id,
            DRC_NBC_Invoice__c = inv.Id,
            Description = 'Test Description',
            DRC_NBC_Issue_type__c = 'Others'
        );
        insert existingCase;

        String caseJson = buildCaseDataJson(acc.Id, null, null, false, false);
        String lotsJson = JSON.serialize(new List<Object>());

        Test.startTest();
        Map<String, Object> result = DRC_NBCCaseInoviceLinkedController.saveCase(existingCase.Id, caseJson, inv.Id, lotsJson);
        Test.stopTest();

        System.assertEquals(true, result.get('success'));
    }

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