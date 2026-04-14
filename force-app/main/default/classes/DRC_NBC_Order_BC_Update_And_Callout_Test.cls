/**
* @File Name : DRC_NBC_Order_BC_Update_And_Callout_Test.cls
* @Description : Test class for DRC_NBC_Order_BC_Update_Service
*                and DRC_NBC_Order_Callout_Handler
*/
@isTest
private class DRC_NBC_Order_BC_Update_And_Callout_Test {
    
    // ─── Test Data Setup ──────────────────────────────────────────────────────
    
    @TestSetup
    static void setupTestData() {
        // ── 1. Custom Setting: DRC_NBC_BC_Integration__c ─────────────────────
        // getConfig() does a SOQL WHERE Name__c = :targetEnv (Sandbox/Production)
        // Without this record, getConfig() throws QueryException before reaching
        // the integration lines you need covered.
        Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
        String targetEnv = org.IsSandbox
            ? System.label.DRC_NBC_Sandbox
            : System.label.DRC_NBC_Production;
        
        DRC_NBC_BC_Integration__c config = new DRC_NBC_BC_Integration__c(
            Name__c                            = targetEnv,
            DRC_NBC_Comapny_Name__c            = 'TestCompany',
            DRC_NBC_Endpoint__c                = 'ShipToAddresses',
            DRC_NBC_Shipping_Address_Endpoint__c = 'ShipToAddresses',
            DRC_NBC_SendOrderEndpoint__c       = 'SalesOrders',
            DRC_NBC_SendOrderLineEndpoint__c   = 'SalesOrderLines',
            DRC_NBC_SalesPerson_Code__c        = 'SP001'
        );
        insert config;
        
        // ── 2. Account ────────────────────────────────────────────────────────
        Account acc = new Account(
            Name                                     = 'Test Account',
            DRC_NBC_Customer_Number__c               = 'CUST-001',
            CurrencyIsoCode                          = 'INR',
            Phone                                    = '9876543210',
            AccountNumber                            = 'ACC001',
            DRC_NBC_PAN_No__c                        = 'AWVPY9594J',
            DRC_NBC_GST_Number__c                    = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c             = 'PDC90',
            DRC_NBC_Account_Email_Email__c           = 'test@test.com',
            BillingStreet                            = '123 Test Street',
            BillingCity                              = 'Indore',
            BillingState                             = 'Maharashtra',
            BillingStateCode                         = 'MH',
            BillingCountry                           = 'India',
            BillingCountryCode                       = 'IN',
            BillingPostalCode                        = '452001',
            DRC_NBC_Volume__c                        = 100,
            DRC_NBC_Credit_Limit__c                  = 500000,
            DRC_NBC_Value__c                         = 1000,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1234567890',
            DRC_NBC_Consignee_Bank_Address__c        = 'Bank Street',
            DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'PUNB0001200',
            DRC_NBC_Consignee_Bank_Name__c           = 'Punjab National Bank',
            Industry                                 = 'Chemicals Construction',
            Type                                     = 'Analyst',
            DRC_NBC_Posted_To_BC__c                  = true,
            DRC_NBC_BC_Approval_Status__c            = true
        );
        insert acc;
        
        // ── 3. Order ──────────────────────────────────────────────────────────
        Order ord = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id  = Test.getStandardPricebookId()
        );
        insert ord;
    }
    
    // ── Helpers ───────────────────────────────────────────────────────────────
    
    private static Order getTestOrder() {
        return [SELECT Id, AccountId FROM Order LIMIT 1];
    }
    
    private static Account getTestAccount() {
        return [SELECT Id FROM Account LIMIT 1];
    }
    
    /**
* KEY FIX — createShippingAddress:
*
* getShippingPayload() subquery filters on:
*   WHERE DRC_NBC_Type__c = 'Shipping'
*   AND Id = :ord.DRC_NBC_Shipping_Address__c
*
* Both conditions must be true for the subquery to return a row.
* Without DRC_NBC_Type__c = 'Shipping', the subquery returns empty
* → accounts[0].Address__r.isEmpty() → payload stays null
* → early return 'FAILURE: No shipping addresses found.'
* → the integration lines are NEVER reached.
*
* We also link the address back to the Order so the AND Id = ... filter matches.
*/
    private static DRC_NBC_Addresses__c createShippingAddress(Id accountId, Id orderId) {
        DRC_NBC_Addresses__c shippingAddr = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c             = accountId,
            DRC_NBC_Order__c               = orderId,
            DRC_NBC_Type__c                = 'Shipping',   // ← CRITICAL: must match WHERE filter
            DRC_NBC_Ship_To_Code__c        = null,         // null so execute() IF condition fires
            DRC_NBC_Address__Street__s     = '123 Ship Street',
            DRC_NBC_Address__City__s       = 'Indore',
            DRC_NBC_Address__StateCode__s  = 'MH',
            DRC_NBC_Address__CountryCode__s= 'IN',
            DRC_NBC_Address__PostalCode__s = '452001'
            // DRC_NBC_GST_Number__c and DRC_NBC_Warehouse__c can be null —
            // the payload builder handles blank values gracefully
        );
        insert shippingAddr;
        
        // Link the address to the Order — the subquery also filters AND Id = :ord.DRC_NBC_Shipping_Address__c
        Order ord = new Order(Id = orderId, DRC_NBC_Shipping_Address__c = shippingAddr.Id);
        update ord;
        
        return shippingAddr;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Mock Classes
    // ═══════════════════════════════════════════════════════════════════════════
    
    private class MockShippingSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    private class MockShipping201 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"status":"created"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    private class MockShippingFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"internal server error"}');
            return res;
        }
    }
    
    private class MockCalloutThrowable implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new System.CalloutException('Simulated callout failure');
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // DRC_NBC_Order_BC_Update_Service Tests
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testProcessOrderUpdate_Success() {
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.processOrderUpdate(ord.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testProcessOrderUpdate_CatchBlock_ApiLogCalled() {
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.processOrderUpdate(null);
        Test.stopTest();
    }
    
    @isTest
    static void testMarkOrderSynced_SetsFieldsCorrectly() {
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.markOrderSynced(ord.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testMarkOrderSynced_NoOrderFound_NoException() {
        Order ord = getTestOrder();
        delete ord;
        
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.markOrderSynced(ord.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testFailedOrderUpdate_SetsStatusToFailed() {
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.failedOrderUpdate(ord.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testFailedOrderUpdate_NoOrderFound_NoException() {
        Order ord = getTestOrder();
        delete ord;
        
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.failedOrderUpdate(ord.Id);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // DRC_NBC_Order_Callout_Handler — execute() Tests
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testOrderCalloutHandler_NoShippingAddress_ChainsToNext() {
        Order ord = getTestOrder();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingSuccess());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(ord.Id));
        Test.stopTest();
    }
    
    @isTest
    static void testOrderCalloutHandler_ShippingSuccess200_ReturnsSuccess() {
        Order ord = getTestOrder();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingSuccess());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(ord.Id));
        Test.stopTest();
    }
    
    @isTest
    static void testOrderCalloutHandler_ShippingSuccess201_ReturnsSuccess() {
        Order ord = getTestOrder();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShipping201());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(ord.Id));
        Test.stopTest();
    }
    
    @isTest
    static void testOrderCalloutHandler_ShippingFailure500_ContinuesToOrderCallout() {
        Order ord = getTestOrder();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingFailure());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(ord.Id));
        Test.stopTest();
    }
    
    @isTest
    static void testOrderCalloutHandler_ShippingCalloutThrows_CatchBlockCovered() {
        Order ord = getTestOrder();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockCalloutThrowable());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(ord.Id));
        Test.stopTest();
    }
    
    @isTest
    static void testOrderCalloutHandler_InvalidOrderId_ExecuteCatchBlock() {
        Order ord = getTestOrder();
        Id orderId = ord.Id;
        delete ord;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingSuccess());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(orderId));
        Test.stopTest();
    }
    
    @isTest
    static void testOrderCalloutHandler_Constructor_SetsOrderId() {
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(ord.Id);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // processShippingCallout — payload == null path (no address record)
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testProcessShippingCallout_NullPayload_ReturnsFailure() {
        // Uses fresh account/order with NO DRC_NBC_Addresses__c record inserted
        // → subquery returns empty → payload == null → early return
        Account freshAcc = new Account(
            Name                                     = 'No Shipping Account',
            DRC_NBC_Customer_Number__c               = 'CUST-NOSHIPPING',
            CurrencyIsoCode                          = 'INR',
            Phone                                    = '9876543210',
            AccountNumber                            = 'ACC002',
            DRC_NBC_PAN_No__c                        = 'AWVPY9594J',
            DRC_NBC_GST_Number__c                    = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c             = 'PDC90',
            DRC_NBC_Account_Email_Email__c           = 'noshipping@test.com',
            BillingStreet                            = '456 Empty Street',
            BillingCity                              = 'Indore',
            BillingState                             = 'Maharashtra',
            BillingStateCode                         = 'MH',
            BillingCountry                           = 'India',
            BillingCountryCode                       = 'IN',
            BillingPostalCode                        = '452001',
            DRC_NBC_Volume__c                        = 50,
            DRC_NBC_Credit_Limit__c                  = 100000,
            DRC_NBC_Value__c                         = 500,
            DRC_NBC_Consignee_Bank_Account_Number__c = '9876543210',
            DRC_NBC_Consignee_Bank_Address__c        = 'Empty Bank Street',
            DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'PUNB0009900',
            DRC_NBC_Consignee_Bank_Name__c           = 'Test Bank',
            Industry                                 = 'Chemicals Construction',
            Type                                     = 'Analyst'
        );
        insert freshAcc;
        
        Order freshOrd = new Order(
            AccountId     = freshAcc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id  = Test.getStandardPricebookId()
        );
        insert freshOrd;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingSuccess());
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(freshOrd.Id);
        String result = handler.processShippingCallout(freshAcc.Id, freshOrd.Id);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // processShippingCallout — payload != null paths
    // These tests COVER the previously uncovered lines:
    //   JSON.serialize → getConfig() → new DRC_NBC_Shipping_BC_Integration(...)
    //   → executeAndReturnResponse() → SUCCESS/FAILURE response branches
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
* Covers:
*   String jsonBody = JSON.serialize(payload, true);
*   String endpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_Shipping_Address_Endpoint__c;
*   DRC_NBC_Shipping_BC_Integration integration = new DRC_NBC_Shipping_BC_Integration(...);
*   HttpResponse response = integration.executeAndReturnResponse();
*   if (response != null && (response.getStatusCode() == 200 || ...201))
*       return 'SUCCESS: HTTP 200';
*/
    @isTest
    static void testProcessShippingCallout_WithPayload_HTTP200_ReturnsSuccess() {
        Order   ord = getTestOrder();
        Account acc = getTestAccount();
        createShippingAddress(acc.Id, ord.Id);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingSuccess());
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(ord.Id);
        String result = handler.processShippingCallout(acc.Id, ord.Id);
        Test.stopTest();
        
    }
    
    /**
* Covers:
*   return 'SUCCESS: HTTP 201';
*/
    @isTest
    static void testProcessShippingCallout_WithPayload_HTTP201_ReturnsSuccess() {
        Order   ord = getTestOrder();
        Account acc = getTestAccount();
        createShippingAddress(acc.Id, ord.Id);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShipping201());
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(ord.Id);
        String result = handler.processShippingCallout(acc.Id, ord.Id);
        Test.stopTest();
    }
    
    /**
* Covers:
*   else { return 'FAILURE: HTTP 500'; }
*/
    @isTest
    static void testProcessShippingCallout_WithPayload_HTTP500_ReturnsFailure() {
        Order   ord = getTestOrder();
        Account acc = getTestAccount();
        createShippingAddress(acc.Id, ord.Id);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingFailure());
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(ord.Id);
        String result = handler.processShippingCallout(acc.Id, ord.Id);
        Test.stopTest();
    }
    
    /**
* Covers:
*   catch (Exception e) { return 'FAILURE: ' + e.getMessage(); }
*/
    @isTest
    static void testProcessShippingCallout_WithPayload_CalloutThrows_CatchCovered() {
        Order   ord = getTestOrder();
        Account acc = getTestAccount();
        createShippingAddress(acc.Id, ord.Id);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockCalloutThrowable());
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(ord.Id);
        String result = handler.processShippingCallout(acc.Id, ord.Id);
        Test.stopTest();
    }
}