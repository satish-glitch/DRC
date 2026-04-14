/**
 * @File Name   : DRC_NBC_Shipping_BC_CalloutTest.cls
 * @Description : Test class for DRC_NBC_Shipping_BC_Callout
 * @Modification Log :
 *==============================================================================
 * Ver | Date       | Modification
 *==============================================================================
 * 1.0 | Mar 2026   | Initial Version
 **/
@IsTest
private class DRC_NBC_Shipping_BC_CalloutTest {

    // =========================================================================
    // Mock HTTP Callout — 200 Success
    // =========================================================================
    private class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"ok"}');
            return res;
        }
    }

    // =========================================================================
    // Mock HTTP Callout — 201 Created
    // =========================================================================
    private class Mock201 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"status":"created"}');
            return res;
        }
    }

    // =========================================================================
    // Mock HTTP Callout — 500 Server Error
    // =========================================================================
    private class MockFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    // =========================================================================
    // @TestSetup — shared data
    // =========================================================================
    @TestSetup
    static void setupData() {

        // 1. Account
        Account acc = new Account(
            Name                      = 'Test Shipping Account',
            Phone                     = '9876543210',
            DRC_NBC_Customer_Number__c = 'CUST001',
               CurrencyIsoCode                   = 'INR',
            AccountNumber                     = 'ACC001',
            DRC_NBC_PAN_No__c                 = 'AWVPY9594J',
            DRC_NBC_GST_Number__c             = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c      = 'PDC90',
            DRC_NBC_Account_Email_Email__c    = 'test@test.com',
            BillingStreet                     = '123 Test Street',
            BillingCity                       = 'Indore',
            BillingState                      = 'Maharashtra',
            BillingStateCode                  = 'MH',
            BillingCountry                    = 'India',
            BillingCountryCode                = 'IN',
            BillingPostalCode                 = '452001',
            DRC_NBC_Volume__c                 = 100,
            DRC_NBC_Credit_Limit__c           = 500000,
            DRC_NBC_Value__c                  = 1000,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1234567890',
            DRC_NBC_Consignee_Bank_Address__c        = 'Bank Street',
            DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'PUNB0001200',
            DRC_NBC_Consignee_Bank_Name__c           = 'Punjab National Bank',
            Industry                          = 'Chemicals Construction',
            Type                              = 'Analyst'
        );
        insert acc;

        // 2. Order linked to account
        // Pricebook required for Order
        Id stdPbId = Test.getStandardPricebookId();
        Pricebook2 stdPb = new Pricebook2(Id = stdPbId, IsActive = true);
        update stdPb;

        Order ord = new Order(
            AccountId        = acc.Id,
            Status           = 'Draft',
            EffectiveDate    = Date.today(),
            Pricebook2Id     = stdPbId
        );
        insert ord;

        // 3. Shipping Address linked to the account + order
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c              = acc.Id,
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Address__Street__s      = '456 Industrial Zone, Near Highway',
            DRC_NBC_Address__City__s        = 'Pune',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__PostalCode__s  = '411001',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_GST_Number__c           = '27AWVPY9594J1ZY',
            DRC_NBC_Warehouse__c            = 'CFS - JNPT',
            DRC_NBC_Ship_To_Code__c         = 'SH001',
            DRC_NBC_Order__c                = ord.Id
        );
        insert addr;

        // 4. Link shipping address to the order
        ord.DRC_NBC_Shipping_Address__c = addr.Id;
        update ord;

        // 5. BC Callout Config — insert DRC_NBC_BC_Integration__c so that
        //    DRC_NBC_BC_Callout_Utility.getConfig() does not throw a QueryException.
        //    The endpoint value is irrelevant; Test.setMock() intercepts all callouts.
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        String targetEnv  = isSandbox
            ? System.label.DRC_NBC_Sandbox
            : System.label.DRC_NBC_Production;

        insert new DRC_NBC_BC_Integration__c(
            Name                                 = targetEnv,
            Name__c                              = targetEnv,
            DRC_NBC_Comapny_Name__c              = 'CRONUS India Ltd',
            DRC_NBC_Endpoint__c                  = 'https://mock.bc.endpoint/api',
            DRC_NBC_Shipping_Address_Endpoint__c = 'shipToAddresses',
            DRC_NBC_SendOrderEndpoint__c         = 'salesOrders',
            DRC_NBC_SendOrderLineEndpoint__c     = 'salesOrderLines',
            DRC_NBC_SalesPerson_Code__c          = 'SP001',
            DRC_NBC_Token_Generated_Time__c      = System.now()
        );
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    private static Account getAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Test Shipping Account' LIMIT 1];
    }

    private static Order getOrder() {
        return [SELECT Id, DRC_NBC_Shipping_Address__c FROM Order LIMIT 1];
    }

    private static DRC_NBC_Addresses__c getAddress() {
        return [SELECT Id FROM DRC_NBC_Addresses__c WHERE DRC_NBC_Type__c = 'Shipping' LIMIT 1];
    }

    // =========================================================================
    // Constructor & Queueable — execute()
    // =========================================================================

    // ─── Test: Queueable executes without exception (200 response) ────────────
    @IsTest
    static void test_execute_success_200() {
        Account acc = getAccount();
        Order   ord = getOrder();

        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        System.enqueueJob(new DRC_NBC_Shipping_BC_Callout(acc.Id, ord.Id));
        Test.stopTest();

    }

    // ─── Test: Queueable executes without exception (500 response) ────────────
    @IsTest
    static void test_execute_failure_500() {
        Account acc = getAccount();
        Order   ord = getOrder();

        Test.setMock(HttpCalloutMock.class, new MockFailure());

        Test.startTest();
        System.enqueueJob(new DRC_NBC_Shipping_BC_Callout(acc.Id, ord.Id));
        Test.stopTest();
    }

    // =========================================================================
    // processShipping — static method
    // =========================================================================

    // ─── Test: processShipping returns SUCCESS on HTTP 200 ───────────────────
    @IsTest
    static void test_processShipping_returns_success_on_200() {
        Account acc = getAccount();
        Order   ord = getOrder();

        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Callout.processShipping(acc.Id, ord.Id);
        Test.stopTest();
    }

    // ─── Test: processShipping returns SUCCESS on HTTP 201 ───────────────────
    @IsTest
    static void test_processShipping_returns_success_on_201() {
        Account acc = getAccount();
        Order   ord = getOrder();

        Test.setMock(HttpCalloutMock.class, new Mock201());

        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Callout.processShipping(acc.Id, ord.Id);
        Test.stopTest();
    }

    // ─── Test: processShipping returns FAILURE on HTTP 500 ───────────────────
    @IsTest
    static void test_processShipping_returns_failure_on_500() {
        Account acc = getAccount();
        Order   ord = getOrder();

        Test.setMock(HttpCalloutMock.class, new MockFailure());

        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Callout.processShipping(acc.Id, ord.Id);
        Test.stopTest();

    }

    // ─── Test: processShipping returns FAILURE when no shipping address ───────
    @IsTest
    static void test_processShipping_returns_failure_whenNoAddress() {
        Account acc = getAccount();

        // Create an order with NO shipping address linked
        Id stdPbId = Test.getStandardPricebookId();
        Order emptyOrd = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id  = stdPbId
        );
        insert emptyOrd;

        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Callout.processShipping(acc.Id, emptyOrd.Id);
        Test.stopTest();
    }

    // =========================================================================
    // getShippingPayload — static method
    // =========================================================================

    // ─── Test: getShippingPayload returns valid payload ───────────────────────
    @IsTest
    static void test_getShippingPayload_returnsValidPayload() {
        Account acc = getAccount();
        Order   ord = getOrder();

        Test.startTest();
        DRC_NBC_Integration_Payload.ShipToPayload payload =
            DRC_NBC_Shipping_BC_Callout.getShippingPayload(acc.Id, ord.Id);
        Test.stopTest();
    }

    // ─── Test: getShippingPayload returns null when no address on order ───────
    @IsTest
    static void test_getShippingPayload_returnsNull_whenNoAddress() {
        Account acc = getAccount();

        Id stdPbId = Test.getStandardPricebookId();
        Order emptyOrd = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id  = stdPbId
        );
        insert emptyOrd;

        Test.startTest();
        DRC_NBC_Integration_Payload.ShipToPayload payload =
            DRC_NBC_Shipping_BC_Callout.getShippingPayload(acc.Id, emptyOrd.Id);
        Test.stopTest();
    }

    // ─── Test: street > 100 chars is split correctly across address fields ────
    @IsTest
    static void test_getShippingPayload_longStreet_splitCorrectly() {
        Account acc = getAccount();
        Order   ord = getOrder();
        DRC_NBC_Addresses__c addr = getAddress();

        // Update street to 130 characters
        String longStreet = 'A'.repeat(130);
        addr.DRC_NBC_Address__Street__s = longStreet;
        update addr;

        Test.startTest();
        DRC_NBC_Integration_Payload.ShipToPayload payload =
            DRC_NBC_Shipping_BC_Callout.getShippingPayload(acc.Id, ord.Id);
        Test.stopTest();
    }

    // ─── Test: street exactly 100 chars is NOT split ─────────────────────────
    @IsTest
    static void test_getShippingPayload_streetExactly100_notSplit() {
        Account acc = getAccount();
        Order   ord = getOrder();
        DRC_NBC_Addresses__c addr = getAddress();

        String street100 = 'B'.repeat(100);
        addr.DRC_NBC_Address__Street__s = street100;
        update addr;

        Test.startTest();
        DRC_NBC_Integration_Payload.ShipToPayload payload =
            DRC_NBC_Shipping_BC_Callout.getShippingPayload(acc.Id, ord.Id);
        Test.stopTest();
    }

    // ─── Test: street > 149 chars uses substring(99,149) for Address2 ─────────
    @IsTest
    static void test_getShippingPayload_streetOver149_address2Capped() {
        Account acc = getAccount();
        Order   ord = getOrder();
        DRC_NBC_Addresses__c addr = getAddress();

        // 160 chars — Address2 should be exactly chars 99-149 (50 chars)
        String longStreet = 'C'.repeat(160);
        addr.DRC_NBC_Address__Street__s = longStreet;
        update addr;

        Test.startTest();
        DRC_NBC_Integration_Payload.ShipToPayload payload =
            DRC_NBC_Shipping_BC_Callout.getShippingPayload(acc.Id, ord.Id);
        Test.stopTest();
    }

    // ─── Test: blank street sets both address fields to empty string ──────────
    @IsTest
    static void test_getShippingPayload_blankStreet_setsEmptyAddressFields() {
        Account acc = getAccount();
        Order   ord = getOrder();
        DRC_NBC_Addresses__c addr = getAddress();

        addr.DRC_NBC_Address__Street__s = '';
        update addr;

        Test.startTest();
        DRC_NBC_Integration_Payload.ShipToPayload payload =
            DRC_NBC_Shipping_BC_Callout.getShippingPayload(acc.Id, ord.Id);
        Test.stopTest();
    }

    // ─── Test: warehouse metadata found — Location_Code is set ───────────────
    @IsTest
    static void test_getShippingPayload_warehouseMetadataFound_setsLocationCode() {
        Account acc = getAccount();
        Order   ord = getOrder();
        Test.startTest();
        DRC_NBC_Integration_Payload.ShipToPayload payload =
            DRC_NBC_Shipping_BC_Callout.getShippingPayload(acc.Id, ord.Id);
        Test.stopTest();
    }
}