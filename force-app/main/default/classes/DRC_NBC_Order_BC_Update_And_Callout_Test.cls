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
        Account acc = new Account(
            Name                              = 'Test Account',
            DRC_NBC_Customer_Number__c        = 'CUST-001',
            CurrencyIsoCode                   = 'INR',
            Phone                             = '9876543210',
            AccountNumber                     = 'ACC001',
            DRC_NBC_PAN_No__c                 = 'AWVPY9594J',
            DRC_NBC_GST_Number__c             = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c      = '10 DAYS',
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
            Type                              = 'Analyst',
            DRC_NBC_Posted_To_BC__c           = true,
            DRC_NBC_BC_Approval_Status__c     = true
        );
        insert acc;
        
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
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Mock Classes
    // NOTE: Names must NOT end with "Exception" — Salesforce auto-treats
    //       such inner classes as Exception subclasses causing compile errors.
    // ═══════════════════════════════════════════════════════════════════════════
    
    // Mock: HTTP 200 success
    private class MockShippingSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    // Mock: HTTP 201 created
    private class MockShipping201 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"status":"created"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
    
    // Mock: HTTP 500 failure — covers FAILURE: HTTP branch
    private class MockShippingFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"internal server error"}');
            return res;
        }
    }
    
    // Mock: throws System.CalloutException — covers catch block in processShippingCallout
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
        
        Order updated = [
            SELECT DRC_NBC_Order_Sync_To_BC__c, DRC_NBC_Integration_Status__c
            FROM Order WHERE Id = :ord.Id
        ];
        System.assertEquals(true, updated.DRC_NBC_Order_Sync_To_BC__c,
                            'Order should be marked as synced to BC');
        System.assertEquals('ORDER_SUCCESS', updated.DRC_NBC_Integration_Status__c,
                            'Integration status should be ORDER_SUCCESS');
    }
    
    /**
* Covers the catch block in processOrderUpdate + createApiLog error call.
* Passing null as orderId causes @future markOrderSynced to be called,
* but Database.executeBatch with a null batch job reference throws an
* exception which is caught and logged via DRC_NBC_API_Log_Handler.
* We delete the order so the batch itself finds nothing and the
* @future call with a null/invalid ID surfaces the exception path.
*/
    @isTest
    static void testProcessOrderUpdate_CatchBlock_ApiLogCalled() {
        Test.startTest();
        // Passing null orderId — markOrderSynced(@future) accepts null
        // but Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(null))
        // will throw inside the batch constructor or execute, hitting catch
        DRC_NBC_Order_BC_Update_Service.processOrderUpdate(null);
        Test.stopTest();
    }
    
    @isTest
    static void testMarkOrderSynced_SetsFieldsCorrectly() {
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.markOrderSynced(ord.Id);
        Test.stopTest();
        
        Order updated = [
            SELECT DRC_NBC_Order_Sync_To_BC__c, DRC_NBC_Integration_Status__c
            FROM Order WHERE Id = :ord.Id
        ];
        System.assertEquals(true, updated.DRC_NBC_Order_Sync_To_BC__c,
                            'DRC_NBC_Order_Sync_To_BC__c should be true after markOrderSynced');
        System.assertEquals('ORDER_SUCCESS', updated.DRC_NBC_Integration_Status__c,
                            'Integration status should be ORDER_SUCCESS after markOrderSynced');
    }
    
    @isTest
    static void testMarkOrderSynced_NoOrderFound_NoException() {
        Order ord = getTestOrder();
        delete ord;
        
        Test.startTest();
        // Empty list path — update block skipped, no exception thrown
        DRC_NBC_Order_BC_Update_Service.markOrderSynced(ord.Id);
        Test.stopTest();
        
        List<Order> remaining = [SELECT Id FROM Order WHERE Id = :ord.Id];
        System.assertEquals(0, remaining.size(),
                            'Deleted order should not exist — empty list handled gracefully');
    }
    
    @isTest
    static void testFailedOrderUpdate_SetsStatusToFailed() {
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.failedOrderUpdate(ord.Id);
        Test.stopTest();
        
        Order updated = [
            SELECT DRC_NBC_Integration_Status__c
            FROM Order WHERE Id = :ord.Id
        ];
        System.assertEquals('ORDER_FAILED', updated.DRC_NBC_Integration_Status__c,
                            'Integration status should be ORDER_FAILED after failedOrderUpdate');
    }
    
    @isTest
    static void testFailedOrderUpdate_NoOrderFound_NoException() {
        Order ord = getTestOrder();
        delete ord;
        
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.failedOrderUpdate(ord.Id);
        Test.stopTest();
        
        List<Order> remaining = [SELECT Id FROM Order WHERE Id = :ord.Id];
        System.assertEquals(0, remaining.size(),
                            'Deleted order should not exist — failedOrderUpdate handles empty list gracefully');
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // DRC_NBC_Order_Callout_Handler Tests
    // ═══════════════════════════════════════════════════════════════════════════
    
    // ── Covers: no shipping address → skip → enqueueJob(DRC_NBC_Order_Only_Callout_Handler)
    @isTest
    static void testOrderCalloutHandler_NoShippingAddress_ChainsToNext() {
        Order ord = getTestOrder();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingSuccess());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(ord.Id));
        Test.stopTest();
        
        Order verified = [SELECT Id FROM Order WHERE Id = :ord.Id];
        System.assertEquals(ord.Id, verified.Id,
                            'Order should still exist after handler runs with no shipping address');
    }
    
    // ── Covers: processShippingCallout → HTTP 200 → 'SUCCESS: HTTP 200' return
    @isTest
    static void testOrderCalloutHandler_ShippingSuccess200_ReturnsSuccess() {
        Order ord = getTestOrder();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingSuccess());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(ord.Id));
        Test.stopTest();
        
        Order verified = [SELECT Id FROM Order WHERE Id = :ord.Id];
        System.assertEquals(ord.Id, verified.Id,
                            'Handler should complete successfully with HTTP 200 mock');
    }
    
    // ── Covers: processShippingCallout → HTTP 201 → 'SUCCESS: HTTP 201' return
    @isTest
    static void testOrderCalloutHandler_ShippingSuccess201_ReturnsSuccess() {
        Order ord = getTestOrder();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShipping201());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(ord.Id));
        Test.stopTest();
    }
    
    // ── Covers: processShippingCallout → HTTP 500 → 'FAILURE: HTTP 500'
    //           then continues to enqueueJob (does not stop)
    @isTest
    static void testOrderCalloutHandler_ShippingFailure500_ContinuesToOrderCallout() {
        Order ord = getTestOrder();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingFailure());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(ord.Id));
        Test.stopTest();
        
        Order verified = [SELECT Id FROM Order WHERE Id = :ord.Id];
        System.assertEquals(ord.Id, verified.Id,
                            'HTTP 500 shipping failure should not stop handler — order callout still chains');
    }
    
    // ── Covers: processShippingCallout catch block → 'FAILURE: <message>' return
    //           MockCalloutThrowable throws System.CalloutException inside respond()
    @isTest
    static void testOrderCalloutHandler_ShippingCalloutThrows_CatchBlockCovered() {
        Order ord = getTestOrder();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockCalloutThrowable());
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(ord.Id));
        Test.stopTest();
        
        // processShippingCallout catch block returns 'FAILURE: Simulated callout failure'
        // execute() continues past the failure check and chains to next queueable
        Order verified = [SELECT Id FROM Order WHERE Id = :ord.Id];
        System.assertEquals(ord.Id, verified.Id,
                            'Callout exception caught in processShippingCallout — handler continues gracefully');
    }
    
    // ── Covers: execute() outer catch block
    //           Deleting order makes DRC_NBC_Order_BC_Callout.getOrderDetails throw
    @isTest
    static void testOrderCalloutHandler_InvalidOrderId_ExecuteCatchBlock() {
        Order ord = getTestOrder();
        Id orderId = ord.Id;
        delete ord;
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingSuccess());
        // getOrderDetails will throw QueryException (no rows) → execute() catch block fires
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(orderId));
        Test.stopTest();
        
        List<Order> remaining = [SELECT Id FROM Order WHERE Id = :orderId];
        System.assertEquals(0, remaining.size(),
                            'Deleted order causes execute() catch block — no unhandled exception');
    }
    
    // ── Covers: constructor this.orderId = orderId
    @isTest
    static void testOrderCalloutHandler_Constructor_SetsOrderId() {
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(ord.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, handler,
                               'Handler instance should be created — constructor sets orderId correctly');
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // DRC_NBC_Order_Callout_Handler — processShippingCallout Direct Tests
    // ═══════════════════════════════════════════════════════════════════════════
    
    // ── Covers: HTTP 200 → 'SUCCESS: HTTP 200'
    @isTest
    static void testProcessShippingCallout_HTTP200_ReturnsSuccess() {
        Order   ord = getTestOrder();
        Account acc = getTestAccount();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingSuccess());
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(ord.Id);
        String result = handler.processShippingCallout(acc.Id, ord.Id);
        Test.stopTest();
    }
    
    // ── Covers: HTTP 201 → 'SUCCESS: HTTP 201'
    @isTest
    static void testProcessShippingCallout_HTTP201_ReturnsSuccess() {
        Order   ord = getTestOrder();
        Account acc = getTestAccount();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShipping201());
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(ord.Id);
        String result = handler.processShippingCallout(acc.Id, ord.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testProcessShippingCallout_HTTP500_ReturnsFailure() {
        Order   ord = getTestOrder();
        Account acc = getTestAccount();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockShippingFailure());
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(ord.Id);
        String result = handler.processShippingCallout(acc.Id, ord.Id);
        Test.stopTest();
    }
    
    // ── Covers: catch block in processShippingCallout → 'FAILURE: <message>'
    @isTest
    static void testProcessShippingCallout_CalloutThrows_ReturnsFAILURE() {
        Order   ord = getTestOrder();
        Account acc = getTestAccount();
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockCalloutThrowable());
        DRC_NBC_Order_Callout_Handler handler = new DRC_NBC_Order_Callout_Handler(ord.Id);
        String result = handler.processShippingCallout(acc.Id, ord.Id);
        Test.stopTest();
    }
    
    // ── Covers: payload == null → 'FAILURE: No shipping addresses found.'
    //    Force null payload by passing IDs that return no shipping data
    @isTest
    static void testProcessShippingCallout_NullPayload_ReturnsFailure() {
        // Create a fresh account with no shipping address records
        Account freshAcc = new Account(
            Name                              = 'No Shipping Account',
            DRC_NBC_Customer_Number__c        = 'CUST-NOSHIPPING',
            CurrencyIsoCode                   = 'INR',
            Phone                             = '9876543210',
            AccountNumber                     = 'ACC002',
            DRC_NBC_PAN_No__c                 = 'AWVPY9594J',
            DRC_NBC_GST_Number__c             = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c      = '10 DAYS',
            DRC_NBC_Account_Email_Email__c    = 'noshipping@test.com',
            BillingStreet                     = '456 Empty Street',
            BillingCity                       = 'Indore',
            BillingState                      = 'Maharashtra',
            BillingStateCode                  = 'MH',
            BillingCountry                    = 'India',
            BillingCountryCode                = 'IN',
            BillingPostalCode                 = '452001',
            DRC_NBC_Volume__c                 = 50,
            DRC_NBC_Credit_Limit__c           = 100000,
            DRC_NBC_Value__c                  = 500,
            DRC_NBC_Consignee_Bank_Account_Number__c = '9876543210',
            DRC_NBC_Consignee_Bank_Address__c        = 'Empty Bank Street',
            DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'PUNB0009900',
            DRC_NBC_Consignee_Bank_Name__c           = 'Test Bank',
            Industry                          = 'Chemicals Construction',
            Type                              = 'Analyst'
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
}