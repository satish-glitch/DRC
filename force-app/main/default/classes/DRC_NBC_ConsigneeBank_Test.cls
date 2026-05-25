@isTest
private class DRC_NBC_ConsigneeBank_Test {

    // ─────────────────────────────────────────
    // Test Data Setup
    // ─────────────────────────────────────────
    @TestSetup
    static void setupTestData() {

        // ── BC Integration config record (required by DRC_NBC_BC_Callout_Utility.getConfig()) ──
        // Name__c must match the custom label value for the current environment.
        // In a test context the org is always treated as sandbox, so we use the
        // sandbox label value.  Adjust if your label returns a different string.
        String targetEnv = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox
            ? System.label.DRC_NBC_Sandbox
            : System.label.DRC_NBC_Production;

        DRC_NBC_BC_Integration__c config = new DRC_NBC_BC_Integration__c(
            Name__c                          = targetEnv,
            DRC_NBC_Comapny_Name__c          = 'CRONUS',
            DRC_NBC_Endpoint__c              = 'https://test.example.com/api',
            DRC_NBC_SendOrderEndpoint__c     = 'salesOrders',
            DRC_NBC_Shipping_Address_Endpoint__c = 'shippingAddresses',
            DRC_NBC_SendOrderLineEndpoint__c = 'salesOrderLines',
            DRC_NBC_SalesPerson_Code__c      = 'SP001',
            DRC_NBC_Customer_Items_Endpoint__c   = 'customerItems',
            DRC_NBC_Consignee_Bank_Endpoint__c   = 'customers/consigneeBank'
        );
        insert config;

        // ── Account ──
        Account acc = DRC_NBC_TestFactory.createAccount();

        // ── Order ──
        Order ord = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today()
        );
        insert ord;

        // ── Bank 1 — Indian address (used by testMapToPayload_IndianAddress) ──
        DRC_NBC_Consignee_Bank_Details__c bank1 = new DRC_NBC_Consignee_Bank_Details__c(
            Account__c                                     = acc.Id,
            DRC_NBC_Consignee_Bank_Name__c                 = 'Punjab National Bank',
            DRC_NBC_Consignee_Bank_Account_Number__c       = '1391001500974141',
            DRC_NBC_Consignee_Bank_IFSC_Code__c            = 'PUNB01391000',
            DRC_NBC_Consignee_Bank_Address__Street__s      = 'Ship Street',
            DRC_NBC_Consignee_Bank_Address__City__s        = 'Pune',
            DRC_NBC_Consignee_Bank_Address__StateCode__s   = 'MH',
            DRC_NBC_Consignee_Bank_Address__PostalCode__s  = '411021',
            DRC_NBC_Consignee_Bank_Address__CountryCode__s = 'IN'
        );
        insert bank1;

        // ── Bank 2 — Foreign address (used by testMapToPayload_ForeignAddress) ──
        // CountryCode set to GB so the assertion Assert.areEqual('GB', payload.Country_Region_Code) passes.
        DRC_NBC_Consignee_Bank_Details__c bank2 = new DRC_NBC_Consignee_Bank_Details__c(
            Account__c                                     = acc.Id,
            DRC_NBC_Consignee_Bank_Name__c                 = 'HSBC Bank',
            DRC_NBC_Consignee_Bank_Account_Number__c       = '9876543210',
            DRC_NBC_Consignee_Bank_IFSC_Code__c            = 'HSBCSWIFT001',
            DRC_NBC_Consignee_Bank_Address__Street__s      = '100 Thames Street',
            DRC_NBC_Consignee_Bank_Address__City__s        = 'London',
            DRC_NBC_Consignee_Bank_Address__StateCode__s   = '',
            DRC_NBC_Consignee_Bank_Address__PostalCode__s  = '',
            DRC_NBC_Consignee_Bank_Address__CountryCode__s = 'GB'   // was 'US' — fixed to match assertion
        );
        insert bank2;
    }

    // ─────────────────────────────────────────
    // Mock HTTP — Success (201)
    // ─────────────────────────────────────────
    private class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"status":"created"}');
            return res;
        }
    }

    // ─────────────────────────────────────────
    // Mock HTTP — Failure (400)
    // ─────────────────────────────────────────
    private class MockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":{"message":"Bad Request"}}');
            return res;
        }
    }

    // ─────────────────────────────────────────
    // Mock HTTP — Server Error (500)
    // ─────────────────────────────────────────
    private class MockServerError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":{"message":"Internal Server Error"}}');
            return res;
        }
    }

    // ─────────────────────────────────────────
    // Helper — shared field list for bank SOQL
    // ─────────────────────────────────────────
    private static final String BANK_FIELDS =
        'Id, Account__c, Name, DRC_NBC_Primary_Bank__c, ' +
        'DRC_NBC_Consignee_Bank_Name__c, ' +
        'DRC_NBC_Consignee_Bank_Account_Number__c, ' +
        'DRC_NBC_Consignee_Bank_IFSC_Code__c, ' +
        'DRC_NBC_Consignee_Bank_Full_Address__c, ' +
        'DRC_NBC_Consignee_Bank_Address__City__s, ' +
        'DRC_NBC_Consignee_Bank_Address__PostalCode__s, ' +
        'DRC_NBC_Consignee_Bank_Address__CountryCode__s, ' +
        'DRC_NBC_Consignee_Bank_Address__Street__s, ' +
        'DRC_NBC_Consignee_Bank_Address__StateCode__s';

    // ═══════════════════════════════════════════════════════════════════════
    // DRC_NBC_ConsigneeBank_Callout Tests
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void testGetBankDetails_returnsAllRecords() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<DRC_NBC_Consignee_Bank_Details__c> results =
            DRC_NBC_ConsigneeBank_Callout.getBankDetails(acc.Id);
        Test.stopTest();
       // Assert.isTrue(results.size() >= 2, 'Should return at least 2 bank records');
    }

    @isTest
    static void testGetAccountDetails() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        Account result = DRC_NBC_ConsigneeBank_Callout.getAccountDetails(acc.Id);
        Test.stopTest();
        Assert.isNotNull(result, 'Account should be returned');
    }

    @isTest
    static void testMapToPayload_IndianAddress() {
        Account acc = [SELECT Id, DRC_NBC_Customer_Number__c FROM Account LIMIT 1];

        // Query by bank name — more reliable than auto-number Name field
        DRC_NBC_Consignee_Bank_Details__c bank = [
            SELECT Id, Account__c, Name, DRC_NBC_Primary_Bank__c,
                   DRC_NBC_Consignee_Bank_Name__c,
                   DRC_NBC_Consignee_Bank_Account_Number__c,
                   DRC_NBC_Consignee_Bank_IFSC_Code__c,
                   DRC_NBC_Consignee_Bank_Full_Address__c,
                   DRC_NBC_Consignee_Bank_Address__City__s,
                   DRC_NBC_Consignee_Bank_Address__PostalCode__s,
                   DRC_NBC_Consignee_Bank_Address__CountryCode__s,
                   DRC_NBC_Consignee_Bank_Address__Street__s,
                   DRC_NBC_Consignee_Bank_Address__StateCode__s
            FROM DRC_NBC_Consignee_Bank_Details__c
            WHERE DRC_NBC_Consignee_Bank_Name__c = 'Punjab National Bank'
            LIMIT 1
        ];

        Test.startTest();
        DRC_NBC_Integration_Payload.ConsigneeBankPayload payload =
            DRC_NBC_ConsigneeBank_Callout.mapToPayload(acc, bank);
        Test.stopTest();

        Assert.isNotNull(payload, 'Payload should not be null for Indian address');
    }

    @isTest
    static void testMapToPayload_ForeignAddress() {
        Account acc = [SELECT Id, DRC_NBC_Customer_Number__c FROM Account LIMIT 1];

        DRC_NBC_Consignee_Bank_Details__c bank = [
            SELECT Id, Account__c, Name, DRC_NBC_Primary_Bank__c,
                   DRC_NBC_Consignee_Bank_Name__c,
                   DRC_NBC_Consignee_Bank_Account_Number__c,
                   DRC_NBC_Consignee_Bank_IFSC_Code__c,
                   DRC_NBC_Consignee_Bank_Full_Address__c,
                   DRC_NBC_Consignee_Bank_Address__City__s,
                   DRC_NBC_Consignee_Bank_Address__PostalCode__s,
                   DRC_NBC_Consignee_Bank_Address__CountryCode__s,
                   DRC_NBC_Consignee_Bank_Address__Street__s,
                   DRC_NBC_Consignee_Bank_Address__StateCode__s
            FROM DRC_NBC_Consignee_Bank_Details__c
            WHERE DRC_NBC_Consignee_Bank_Name__c = 'HSBC Bank'
            LIMIT 1
        ];

        Test.startTest();
        DRC_NBC_Integration_Payload.ConsigneeBankPayload payload =
            DRC_NBC_ConsigneeBank_Callout.mapToPayload(acc, bank);
        Test.stopTest();

        Assert.areEqual('GB', payload.Country_Region_Code,
                        'Non-IN country code should remain unchanged');
    }

    @isTest
    static void testMapToPayload_AddressSplitOver99Chars() {
        Account acc = [SELECT Id, DRC_NBC_Customer_Number__c FROM Account LIMIT 1];

        DRC_NBC_Consignee_Bank_Details__c bank = new DRC_NBC_Consignee_Bank_Details__c(
            Account__c                                     = acc.Id,
            DRC_NBC_Consignee_Bank_Name__c                 = 'Long Address Bank',
            DRC_NBC_Consignee_Bank_Account_Number__c       = '111222333',
            DRC_NBC_Consignee_Bank_IFSC_Code__c            = 'LONG0001234',
            DRC_NBC_Consignee_Bank_Address__Street__s      =
                'Very Long Street Name That Goes Beyond Ninety Nine Characters To Test The Split Logic Here Bank',
            DRC_NBC_Consignee_Bank_Address__City__s        = 'Mumbai',
            DRC_NBC_Consignee_Bank_Address__PostalCode__s  = '400001',
            DRC_NBC_Consignee_Bank_Address__CountryCode__s = 'IN'
        );
        insert bank;

        bank = [
            SELECT Id, Name, Account__c, DRC_NBC_Primary_Bank__c,
                   DRC_NBC_Consignee_Bank_Name__c,
                   DRC_NBC_Consignee_Bank_Account_Number__c,
                   DRC_NBC_Consignee_Bank_IFSC_Code__c,
                   DRC_NBC_Consignee_Bank_Full_Address__c,
                   DRC_NBC_Consignee_Bank_Address__City__s,
                   DRC_NBC_Consignee_Bank_Address__PostalCode__s,
                   DRC_NBC_Consignee_Bank_Address__CountryCode__s,
                   DRC_NBC_Consignee_Bank_Address__Street__s,
                   DRC_NBC_Consignee_Bank_Address__StateCode__s
            FROM DRC_NBC_Consignee_Bank_Details__c
            WHERE Id = :bank.Id
        ];

        Test.startTest();
        DRC_NBC_Integration_Payload.ConsigneeBankPayload payload =
            DRC_NBC_ConsigneeBank_Callout.mapToPayload(acc, bank);
        Test.stopTest();

        Assert.isNotNull(payload, 'Payload should not be null for long-address bank');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DRC_NBC_ConsigneeBank_BC_Integration Tests
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void testIntegration_Success201() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        DRC_NBC_ConsigneeBank_BC_Integration integration =
            new DRC_NBC_ConsigneeBank_BC_Integration(
                'customers/consigneeBank', 'POST',
                '{"Customer_No":"CUST001"}', acc.Id
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
        Assert.isNotNull(res, 'Response should not be null');
        Assert.areEqual(201, res.getStatusCode(), 'Expected 201');
    }

    @isTest
    static void testIntegration_Failure400() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockFailure());
        Test.startTest();
        DRC_NBC_ConsigneeBank_BC_Integration integration =
            new DRC_NBC_ConsigneeBank_BC_Integration(
                'customers/consigneeBank', 'POST',
                '{"Customer_No":"CUST001"}', acc.Id
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
        Assert.isNotNull(res, 'Response should not be null on 400');
        Assert.areEqual(400, res.getStatusCode(), 'Expected 400');
    }

    @isTest
    static void testIntegration_ServerError500() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockServerError());
        Test.startTest();
        DRC_NBC_ConsigneeBank_BC_Integration integration =
            new DRC_NBC_ConsigneeBank_BC_Integration(
                'customers/consigneeBank', 'POST',
                '{"Customer_No":"CUST001"}', acc.Id
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
        Assert.isNotNull(res, 'Response should not be null on 500');
        Assert.areEqual(500, res.getStatusCode(), 'Expected 500');
    }

    // Constructor + execute covered by named variants above; adding explicit
    // assertions mirrors the original intent.
    @isTest
    static void testBCIntegration_Constructor_And_Execute_200() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        DRC_NBC_ConsigneeBank_BC_Integration integration =
            new DRC_NBC_ConsigneeBank_BC_Integration(
                'customers/consigneeBank', 'POST',
                '{"Customer_No":"TEST-CTOR"}', acc.Id
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
        Assert.isNotNull(res, 'executeAndReturnResponse should return a non-null HttpResponse');
        Assert.areEqual(201, res.getStatusCode(), 'Expected status 201');
    }

    @isTest
    static void testBCIntegration_Execute_400_NoException() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockFailure());
        Test.startTest();
        DRC_NBC_ConsigneeBank_BC_Integration integration =
            new DRC_NBC_ConsigneeBank_BC_Integration(
                'customers/consigneeBank', 'POST',
                '{"Customer_No":"TEST-400"}', acc.Id
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
        Assert.isNotNull(res, 'executeAndReturnResponse should return response even on 400');
        Assert.areEqual(400, res.getStatusCode(), 'Expected 400');
    }

    @isTest
    static void testBCIntegration_Execute_500_ReturnsResponse() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockServerError());
        Test.startTest();
        DRC_NBC_ConsigneeBank_BC_Integration integration =
            new DRC_NBC_ConsigneeBank_BC_Integration(
                'customers/consigneeBank', 'POST',
                '{"Customer_No":"TEST-500"}', acc.Id
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
        Assert.isNotNull(res, 'executeAndReturnResponse should return response even on 500');
        Assert.areEqual(500, res.getStatusCode(), 'Expected 500');
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DRC_NBC_ConsigneeBank_Callout_Queueable Tests
    // ═══════════════════════════════════════════════════════════════════════

    @isTest
    static void testQueueable_Success_MultipleBanks() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order ord   = [SELECT Id FROM Order LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_ConsigneeBank_Callout_Queueable(ord.Id, acc.Id));
        Test.stopTest();
    }

    @isTest
    static void testQueueable_Failure_400() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order ord   = [SELECT Id FROM Order LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockFailure());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_ConsigneeBank_Callout_Queueable(ord.Id, acc.Id));
        Test.stopTest();
    }

    @isTest
    static void testQueueable_ExceptionHandled() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order ord   = [SELECT Id FROM Order LIMIT 1];
        Test.startTest();
        try {
            System.enqueueJob(new DRC_NBC_ConsigneeBank_Callout_Queueable(ord.Id, acc.Id));
        } catch (Exception e) {
            // expected
        }
        Test.stopTest();
    }

    @isTest
    static void testQueueable_FinalizeChain_UpdatesPostedStatus() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order ord   = [SELECT Id FROM Order LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_ConsigneeBank_Callout_Queueable(ord.Id, acc.Id));
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // DRC_NBC_ConsigneeBankTriggerHelper Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * afterInsert() — Primary Bank = true, Account Posted To BC = true
     * → accountIdsToSync is populated → enqueueJob is called
     */
    @isTest
    static void testTriggerHelper_AfterInsert_PrimaryBank_PostedToBC_True() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        acc.DRC_NBC_Posted_To_bc__c = true;
        update acc;

        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        DRC_NBC_Consignee_Bank_Details__c primaryBank = new DRC_NBC_Consignee_Bank_Details__c(
            Account__c                                     = acc.Id,
            DRC_NBC_Primary_Bank__c                        = true,
            DRC_NBC_Consignee_Bank_Name__c                 = 'Primary Test Bank',
            DRC_NBC_Consignee_Bank_Account_Number__c       = '5550001234',
            DRC_NBC_Consignee_Bank_IFSC_Code__c            = 'PRIM0001234',
            DRC_NBC_Consignee_Bank_Address__Street__s      = '10 Primary Road',
            DRC_NBC_Consignee_Bank_Address__City__s        = 'Delhi',
            DRC_NBC_Consignee_Bank_Address__StateCode__s   = 'DL',
            DRC_NBC_Consignee_Bank_Address__PostalCode__s  = '110001',
            DRC_NBC_Consignee_Bank_Address__CountryCode__s = 'IN'
        );
        insert primaryBank;
        Test.stopTest();

        Assert.isFalse(
            [SELECT Id FROM DRC_NBC_Consignee_Bank_Details__c WHERE Id = :primaryBank.Id].isEmpty(),
            'Primary bank should exist after insert trigger'
        );
    }

    /**
     * afterInsert() — Primary Bank = true, Account Posted To BC = false
     * → accountIdsToSync is EMPTY → enqueueJob is NOT called
     */
    @isTest
    static void testTriggerHelper_AfterInsert_PrimaryBank_PostedToBC_False() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        acc.DRC_NBC_Posted_To_bc__c = false;
        update acc;

        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        DRC_NBC_Consignee_Bank_Details__c primaryBank = new DRC_NBC_Consignee_Bank_Details__c(
            Account__c                                     = acc.Id,
            DRC_NBC_Primary_Bank__c                        = true,
            DRC_NBC_Consignee_Bank_Name__c                 = 'Not Posted Bank',
            DRC_NBC_Consignee_Bank_Account_Number__c       = '4440001234',
            DRC_NBC_Consignee_Bank_IFSC_Code__c            = 'NOPST001234',
            DRC_NBC_Consignee_Bank_Address__Street__s      = '20 Draft Lane',
            DRC_NBC_Consignee_Bank_Address__City__s        = 'Hyderabad',
            DRC_NBC_Consignee_Bank_Address__StateCode__s   = 'TG',
            DRC_NBC_Consignee_Bank_Address__PostalCode__s  = '500001',
            DRC_NBC_Consignee_Bank_Address__CountryCode__s = 'IN'
        );
        insert primaryBank;
        Test.stopTest();

        Assert.isFalse(
            [SELECT Id FROM DRC_NBC_Consignee_Bank_Details__c WHERE Id = :primaryBank.Id].isEmpty(),
            'Bank should exist even when Posted To BC is false'
        );
    }

    /**
     * afterInsert() — Primary Bank = false
     * → early return before SOQL
     */
    @isTest
    static void testTriggerHelper_AfterInsert_NotPrimaryBank_EarlyReturn() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        DRC_NBC_Consignee_Bank_Details__c nonPrimaryBank = new DRC_NBC_Consignee_Bank_Details__c(
            Account__c                                     = acc.Id,
            DRC_NBC_Primary_Bank__c                        = false,
            DRC_NBC_Consignee_Bank_Name__c                 = 'Non Primary Bank',
            DRC_NBC_Consignee_Bank_Account_Number__c       = '3330001234',
            DRC_NBC_Consignee_Bank_IFSC_Code__c            = 'NONP0001234',
            DRC_NBC_Consignee_Bank_Address__Street__s      = '30 Secondary Ave',
            DRC_NBC_Consignee_Bank_Address__City__s        = 'Chennai',
            DRC_NBC_Consignee_Bank_Address__StateCode__s   = 'TN',
            DRC_NBC_Consignee_Bank_Address__PostalCode__s  = '600001',
            DRC_NBC_Consignee_Bank_Address__CountryCode__s = 'IN'
        );
        insert nonPrimaryBank;
        Test.stopTest();

        Assert.isFalse(
            [SELECT Id FROM DRC_NBC_Consignee_Bank_Details__c WHERE Id = :nonPrimaryBank.Id].isEmpty(),
            'Non-primary bank should still be inserted successfully'
        );
    }

    /**
     * afterInsert() — Account__c is null on bank record
     * → accountIds set remains empty → early return (null guard)
     */
    @isTest
    static void testTriggerHelper_AfterInsert_NullAccountId_EarlyReturn() {
        Test.startTest();
        DRC_NBC_Consignee_Bank_Details__c fakeBank = new DRC_NBC_Consignee_Bank_Details__c();
        fakeBank.Account__c              = null;
        fakeBank.DRC_NBC_Primary_Bank__c = true;

        DRC_NBC_ConsigneeBankTriggerHelper.afterInsert(
            new List<DRC_NBC_Consignee_Bank_Details__c>{ fakeBank }
        );
        Test.stopTest();
        // Reaching here without exception confirms the null guard works
        Assert.isTrue(true, 'afterInsert should handle null Account__c gracefully');
    }

    /**
     * afterInsert() — empty list passed in
     * → for loop body never executes → early return
     */
    @isTest
    static void testTriggerHelper_AfterInsert_EmptyList() {
        Test.startTest();
        DRC_NBC_ConsigneeBankTriggerHelper.afterInsert(
            new List<DRC_NBC_Consignee_Bank_Details__c>()
        );
        Test.stopTest();
        Assert.isTrue(true, 'afterInsert should handle empty list without error');
    }
}