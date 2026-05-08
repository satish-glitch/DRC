/**
 * @File Name : DRC_NBC_SalesPersonCode_Callout_Test.cls
 * @Description : Test class for DRC_NBC_SalesPersonCode_Callout and DRC_NBC_SalesPerson_BC_Integration
 * @Author : Satish
 * @Last Modified On : May 08, 2026
**/
@isTest(SeeAllData=true)
private class DRC_NBC_SalesPersonCode_Callout_Test {

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public MockHttpResponseGenerator(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(responseBody);
            res.setStatusCode(statusCode);
            return res;
        }
    }

    // ─── Helper: fetch a real MDT record's MasterLabel (SeeAllData=true allows this) ───
    private static String getValidSalesPersonCode() {
        List<SalesPerson_Code__mdt> mdtList = [
            SELECT MasterLabel
            FROM SalesPerson_Code__mdt
            LIMIT 1
        ];
        return mdtList.isEmpty() ? null : mdtList[0].MasterLabel;
    }

    // ─── Create Account WITH SalesPerson_Code__c matching an MDT MasterLabel ───
    private static Account createTestAccount(String salesPersonCode) {
        Account acc = new Account(
            Name                                    = 'Test Account',
            DRC_NBC_Customer_Number__c              = 'CUST12345',
            CurrencyIsoCode                         = 'INR',
            Phone                                   = '1234567890',
            AccountNumber                           = 'A123',
            DRC_NBC_PAN_No__c                       = 'AWVPY9594J',
            DRC_NBC_GST_Number__c                   = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c            = 'PDC90',
            DRC_NBC_Account_Email_Email__c          = 'test@example.com',
            BillingStreet                           = '123 Street',
            BillingCity                             = 'City',
            BillingCountry                          = 'India',
            BillingCountryCode                      = 'IN',
            BillingPostalCode                       = '462002',
            BillingState                            = 'Maharashtra',
            BillingStateCode                        = 'MH',
            DRC_NBC_Volume__c                       = 70,
            DRC_NBC_Credit_Limit__c                 = 123456787,
            DRC_NBC_Value__c                        = 900,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
            DRC_NBC_Consignee_Bank_Address__c       = 'Barhi 483775',
            DRC_NBC_Consignee_Bank_IFSC_Code__c     = 'PUNB01391000',
            DRC_NBC_Consignee_Bank_Name__c          = 'Punjab National bank',
            Industry                                = 'Chemicals Construction',
            Type                                    = 'Analyst',
            SalesPerson_Code__c                     = salesPersonCode  // NEW: links to MDT
        );
        insert acc;
        return acc;
    }

    // ─── Create Order WITHOUT ShipToContactId (Contact removed) ───
    private static Order createTestOrder(Id accountId) {
        Order ord = new Order(
            Name                               = 'Test Order',
            AccountId                          = accountId,
            Status                             = 'Draft',
            EffectiveDate                      = Date.today(),
            DRC_NBC_Account_Approval_Status__c = 'Pending'
        );
        insert ord;
        return ord;
    }

    // ─── Helper: build a dummy MDT-style payload for Integration tests ───
    private static String buildDummyPayload() {
        Map<String, Object> payloadMap = new Map<String, Object>{
            'Name'     => 'Test SalesPerson',
            'Phone_No' => '9876543210',
            'E_Mail'   => 'sp@example.com',
            'Code'     => 'SP001'
        };
        return JSON.serialize(payloadMap);
    }

    // ═══════════════════════════════════════════════════════════════
    //  QUEUEABLE TESTS
    // ═══════════════════════════════════════════════════════════════

    @isTest
    static void test_Queueable_SuccessfulCallout() {
        String spCode = getValidSalesPersonCode();
        Account acc   = createTestAccount(spCode);
        Order ord     = createTestOrder(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"message": "Success"}'));

        Test.startTest();
        System.enqueueJob(new DRC_NBC_SalesPersonCode_Callout(ord.Id));
        Test.stopTest();
    }

    @isTest
    static void test_Queueable_FailedCallout() {
        String spCode = getValidSalesPersonCode();
        Account acc   = createTestAccount(spCode);
        Order ord     = createTestOrder(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, '{"error": "Server Error"}'));

        Test.startTest();
        System.enqueueJob(new DRC_NBC_SalesPersonCode_Callout(ord.Id));
        Test.stopTest();
    }

    @isTest
    static void test_Queueable_BadRequestCallout() {
        String spCode = getValidSalesPersonCode();
        Account acc   = createTestAccount(spCode);
        Order ord     = createTestOrder(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(400, '{"error": "Bad Request"}'));

        Test.startTest();
        System.enqueueJob(new DRC_NBC_SalesPersonCode_Callout(ord.Id));
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════
    //  executeCallout — SUCCESS PATHS
    // ═══════════════════════════════════════════════════════════════

    @isTest
    static void test_ExecuteCallout_Success200() {
        String spCode = getValidSalesPersonCode();
        Account acc   = createTestAccount(spCode);
        Order ord     = createTestOrder(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"message": "Success"}'));

        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }

    @isTest
    static void test_ExecuteCallout_Success201() {
        String spCode = getValidSalesPersonCode();
        Account acc   = createTestAccount(spCode);
        Order ord     = createTestOrder(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"message": "Created"}'));

        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }

    @isTest
    static void test_ExecuteCallout_Success204() {
        String spCode = getValidSalesPersonCode();
        Account acc   = createTestAccount(spCode);
        Order ord     = createTestOrder(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(204, ''));

        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════
    //  executeCallout — FAILURE / HTTP ERROR PATHS
    // ═══════════════════════════════════════════════════════════════

    @isTest
    static void test_ExecuteCallout_HttpFailure500() {
        String spCode = getValidSalesPersonCode();
        Account acc   = createTestAccount(spCode);
        Order ord     = createTestOrder(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, '{"error": "Server error"}'));

        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }

    @isTest
    static void test_ExecuteCallout_BadRequest400() {
        String spCode = getValidSalesPersonCode();
        Account acc   = createTestAccount(spCode);
        Order ord     = createTestOrder(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(400, '{"error": "Bad Request"}'));

        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }

    @isTest
    static void test_ExecuteCallout_NotFound404() {
        String spCode = getValidSalesPersonCode();
        Account acc   = createTestAccount(spCode);
        Order ord     = createTestOrder(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(404, '{"error": "Not Found"}'));

        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }

    @isTest
    static void test_ExecuteCallout_Unauthorized401() {
        String spCode = getValidSalesPersonCode();
        Account acc   = createTestAccount(spCode);
        Order ord     = createTestOrder(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(401, '{"error": "Unauthorized"}'));

        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════
    //  executeCallout — EDGE / NEGATIVE PATHS
    // ═══════════════════════════════════════════════════════════════

    // Account has NO SalesPerson_Code__c → throws AuraHandledException
    @isTest
    static void test_ExecuteCallout_NoSalesPersonCode() {
        Account acc = createTestAccount(null); // null → blank SalesPerson_Code__c
        Order ord   = createTestOrder(acc.Id);

        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }

    // Account SalesPerson_Code__c has a value that does NOT match any MDT MasterLabel
    @isTest
    static void test_ExecuteCallout_NoMatchingMetadata() {
        Account acc = createTestAccount('NIRMAL');
        Order ord   = createTestOrder(acc.Id);

        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }

    // Order has no AccountId
    @isTest
    static void test_ExecuteCallout_NoAccountOnOrder() {
        // Insert order without account is not possible (required field),
        // so we test with an invalid Order Id to trigger exception path
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout('801000000000000AAA');
        Test.stopTest();
    }

    @isTest
    static void test_ExecuteCallout_InvalidOrderId() {
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout('801000000000000AAA');
        Test.stopTest();
    }

    @isTest
    static void test_ExecuteCallout_NullOrderId() {
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(null);
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════
    //  INTEGRATION CLASS TESTS
    // ═══════════════════════════════════════════════════════════════

    @isTest
    static void test_Integration_PrepareRequest() {
        Account acc = createTestAccount(null);
        String payload = buildDummyPayload();

        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint',
            'POST',
            payload,
            acc.Id
        );

        Test.startTest();
        HttpRequest req = integration.prepareRequest();
        Test.stopTest();
    }

    @isTest
    static void test_Integration_ProcessResponse_Success200() {
        Account acc    = createTestAccount(null);
        String payload = buildDummyPayload();

        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint', 'POST', payload, acc.Id
        );

        HttpResponse successResp = new HttpResponse();
        successResp.setStatusCode(200);
        successResp.setBody('{"message":"Success"}');

        Test.startTest();
        integration.processResponse(successResp);
        Test.stopTest();
    }

    @isTest
    static void test_Integration_ProcessResponse_Success201() {
        Account acc    = createTestAccount(null);
        String payload = buildDummyPayload();

        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint', 'POST', payload, acc.Id
        );

        HttpResponse successResp = new HttpResponse();
        successResp.setStatusCode(201);
        successResp.setBody('{"message":"Created"}');

        Test.startTest();
        integration.processResponse(successResp);
        Test.stopTest();
    }

    @isTest
    static void test_Integration_ProcessResponse_Error500() {
        Account acc    = createTestAccount(null);
        String payload = buildDummyPayload();

        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint', 'POST', payload, acc.Id
        );

        HttpResponse errorResp = new HttpResponse();
        errorResp.setStatusCode(500);
        errorResp.setBody('{"error":"Internal Server Error"}');

        Test.startTest();
        integration.processResponse(errorResp);
        Test.stopTest();
    }

    @isTest
    static void test_Integration_ProcessResponse_Error400() {
        Account acc    = createTestAccount(null);
        String payload = buildDummyPayload();

        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint', 'POST', payload, acc.Id
        );

        HttpResponse errorResp = new HttpResponse();
        errorResp.setStatusCode(400);
        errorResp.setBody('{"error":"Bad Request"}');

        Test.startTest();
        integration.processResponse(errorResp);
        Test.stopTest();
    }

    @isTest
    static void test_Integration_ExecuteAndReturnResponse() {
        Account acc    = createTestAccount(null);
        String payload = buildDummyPayload();

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"message": "Success"}'));

        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint', 'POST', payload, acc.Id
        );

        Test.startTest();
        HttpResponse response = integration.executeAndReturnResponse();
        Test.stopTest();    }

    @isTest
    static void test_PayloadStructure() {
        Test.startTest();
        String payload = buildDummyPayload();
        Map<String, Object> deserialized = (Map<String, Object>) JSON.deserializeUntyped(payload);
        Test.stopTest();

    }
}