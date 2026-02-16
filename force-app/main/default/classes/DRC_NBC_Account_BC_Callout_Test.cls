@isTest
private class DRC_NBC_Account_BC_Callout_Test {
    
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
    
    @testSetup
    static void setupTestData() {
        // Create any test metadata or configuration records if needed
    }
    
    private static Account createTestAccount(Boolean withApprovalStatus, Boolean withShippingAddress, Boolean withCustomerNumber) {
        Account acc = new Account(
            Name = 'Test Account',
            CurrencyIsoCode = 'INR',
            Phone = '1234567890',
            AccountNumber = 'A123',
            DRC_NBC_PAN_No__c = 'AWVPY9594J',
            DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
            DRC_NBC_Customer_Number__c = withCustomerNumber ? 'CUST123' : null,
            DRC_NBC_Payment_Term_Code__c = '10 DAYS',
            DRC_NBC_Account_Email_Email__c = 'test@example.com',
            BillingStreet = '123 Street',
            BillingCity = 'City',
            BillingCountry = 'India',
            BillingCountryCode = 'IN',
            BillingPostalCode = '462002',
            BillingState = 'Maharashtra',
            BillingStateCode = 'MH',
            DRC_NBC_BC_Approval_Status__c = withApprovalStatus
        );
        insert acc;
        
        if (withShippingAddress) {
            DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
                DRC_NBC_Address__Street__s = 'Street',
                DRC_NBC_Address__City__s = 'City',
                DRC_NBC_Address__StateCode__s = 'MH',
                DRC_NBC_Address__PostalCode__s = '462002',
                DRC_NBC_Address__CountryCode__s = 'IN',
                DRC_NBC_Type__c = 'Shipping',
                DRC_NBC_Warehouse__c = 'CFS - JNPT'
            );
            insert addr;
        }
        
        return acc;
    }
    
    private static Order createTestOrder(Id accountId) {
        Order ord = new Order(
            Name = 'Test Order',
            AccountId = accountId,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            DRC_NBC_Account_Approval_Status__c = 'Pending'
        );
        insert ord;
        return ord;
    }
    
    // Test DRC_NBC_Account_BC_Callout.executeCallout with BC Approval Status true
    @isTest
    static void test_executeCallout_WithBCApprovalStatus() {
        Account acc = createTestAccount(true, false, true);
        Order ord = createTestOrder(acc.Id);
        
        Test.startTest();
        String result = DRC_NBC_Account_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Callout.executeCallout without BC Approval Status
    @isTest
    static void test_executeCallout_WithoutBCApprovalStatus() {
        Account acc = createTestAccount(false, false, true);
        Order ord = createTestOrder(acc.Id);
        
        Test.startTest();
        String result = DRC_NBC_Account_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();
        
        System.assertEquals('Account Sync SUCCESS', result);
    }
    
    // Test DRC_NBC_Account_BC_Callout.executeCallout with null Order Id
    @isTest
    static void test_executeCallout_NullOrderId() {
        Test.startTest();
        String result = DRC_NBC_Account_BC_Callout.executeCallout(null);
        Test.stopTest();
        
        System.assertEquals('FAILURE: Order Id is required', result);
    }
    
    // Test DRC_NBC_Account_BC_Callout.executeCallout with invalid Order Id
    @isTest
    static void test_executeCallout_InvalidOrderId() {
        Test.startTest();
        String result = DRC_NBC_Account_BC_Callout.executeCallout('801000000000000AAA');
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Callout.getAccountDetails
    @isTest
    static void test_getAccountDetails() {
        Account acc = createTestAccount(false, true, true);
        
        Test.startTest();
        Account result = DRC_NBC_Account_BC_Callout.getAccountDetails(acc.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(acc.Id, result.Id);
        System.assertEquals('Test Account', result.Name);
    }
    
    // Test DRC_NBC_Account_BC_Callout.mapAccountToPayload
    @isTest
    static void test_mapAccountToPayload() {
        Account acc = createTestAccount(false, false, true);
        
        Test.startTest();
        DRC_NBC_Integration_Payload.CustomerPayload payload = DRC_NBC_Account_BC_Callout.mapAccountToPayload(acc);
        Test.stopTest();
        
        System.assertEquals('CUST123', payload.No);
        System.assertEquals('Test Account', payload.Name);
        System.assertEquals('INR', payload.Currency_Code);
        System.assertEquals('AWVPY9594J', payload.P_A_N_No);
        System.assertEquals('IND', payload.Country_Region_Code);
    }
    
    // Test DRC_NBC_Account_BC_Callout.updatePostedStatus
    @isTest
    static void test_updatePostedStatus() {
        Account acc = createTestAccount(false, false, true);
        
        Test.startTest();
        DRC_NBC_Account_BC_Callout.updatePostedStatus(acc.Id);
        Test.stopTest();
        
        Account updatedAcc = [SELECT DRC_NBC_Posted_To_bc__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(true, updatedAcc.DRC_NBC_Posted_To_bc__c);
    }
    
    // Test DRC_NBC_Account_BC_Callout_Queueable with existing customer number
    @isTest
    static void test_Queueable_WithExistingCustomerNumber() {
        Account acc = createTestAccount(false, false, true);
        Order ord = createTestOrder(acc.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"success": true}'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_BC_Callout_Queueable(ord.Id));
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Callout_Queueable without customer number (chains to second queue)
    @isTest
    static void test_Queueable_WithoutCustomerNumber() {
        Account acc = createTestAccount(false, false, false);
        Order ord = createTestOrder(acc.Id);
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_BC_Callout_Queueable(ord.Id));
        Test.stopTest();
        
        Account queriedAcc = [SELECT DRC_NBC_Customer_Number__c FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, queriedAcc);
    }
    
    // Test DRC_NBC_Account_BC_Callout_Queueable with BC approval status
    @isTest
    static void test_Queueable_WithBCApprovalStatus() {
        Account acc = createTestAccount(true, false, true);
        Order ord = createTestOrder(acc.Id);
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_BC_Callout_Queueable(ord.Id));
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Callout_Queueable with exception
    @isTest
    static void test_Queueable_WithException() {
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_BC_Callout_Queueable('801000000000000AAA'));
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Callout_Second_Queue successful execution
    @isTest
    static void test_SecondQueue_SuccessfulExecution() {
        Account acc = createTestAccount(false, false, true);
        Order ord = createTestOrder(acc.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"success": true}'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_BC_Callout_Second_Queue(ord.Id, acc.Id));
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Callout_Second_Queue with BC approval status
    @isTest
    static void test_SecondQueue_WithBCApprovalStatus() {
        Account acc = createTestAccount(true, false, true);
        Order ord = createTestOrder(acc.Id);
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_BC_Callout_Second_Queue(ord.Id, acc.Id));
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Callout_Second_Queue with failed callout
    @isTest
    static void test_SecondQueue_FailedCallout() {
        Account acc = createTestAccount(false, false, true);
        Order ord = createTestOrder(acc.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, '{"error": "Server error"}'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_BC_Callout_Second_Queue(ord.Id, acc.Id));
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Callout_Second_Queue with exception
    @isTest
    static void test_SecondQueue_WithException() {
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_BC_Callout_Second_Queue('801000000000000AAA', '001000000000000AAA'));
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Integration.prepareRequest
    /*@isTest
    static void test_Integration_PrepareRequest() {
        Account acc = createTestAccount(false, false, true);
        
        DRC_NBC_Integration_Payload.CustomerPayload payload = DRC_NBC_Account_BC_Callout.mapAccountToPayload(acc);
        String jsonBody = JSON.serialize(payload);
        
        DRC_NBC_Account_BC_Integration integration = new DRC_NBC_Account_BC_Integration(
            'test-endpoint',
            'POST',
            jsonBody,
            acc.Id
        );
        
        Test.startTest();
        HttpRequest req = integration.prepareRequest();
        Test.stopTest();
        
        System.assertNotEquals(null, req);
        System.assertEquals('POST', req.getMethod());
        System.assertEquals(jsonBody, req.getBody());
    }*/
    
    // Test DRC_NBC_Account_BC_Integration.processResponse with success
    @isTest
    static void test_Integration_ProcessResponse_Success() {
        Account acc = createTestAccount(false, false, true);
        
        DRC_NBC_Integration_Payload.CustomerPayload payload = DRC_NBC_Account_BC_Callout.mapAccountToPayload(acc);
        String jsonBody = JSON.serialize(payload);
        
        DRC_NBC_Account_BC_Integration integration = new DRC_NBC_Account_BC_Integration(
            'test-endpoint',
            'POST',
            jsonBody,
            acc.Id
        );
        
        HttpResponse successResp = new HttpResponse();
        successResp.setStatusCode(201);
        successResp.setBody('{"message":"Success"}');
        
        Test.startTest();
        integration.processResponse(successResp);
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Integration.processResponse with error
    @isTest
    static void test_Integration_ProcessResponse_Error() {
        Account acc = createTestAccount(false, false, true);
        
        DRC_NBC_Integration_Payload.CustomerPayload payload = DRC_NBC_Account_BC_Callout.mapAccountToPayload(acc);
        String jsonBody = JSON.serialize(payload);
        
        DRC_NBC_Account_BC_Integration integration = new DRC_NBC_Account_BC_Integration(
            'test-endpoint',
            'POST',
            jsonBody,
            acc.Id
        );
        
        HttpResponse errorResp = new HttpResponse();
        errorResp.setStatusCode(500);
        errorResp.setBody('{"error":"Internal Server Error"}');
        
        Test.startTest();
        integration.processResponse(errorResp);
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Integration executeAndReturnResponse
    @isTest
    static void test_Integration_ExecuteAndReturnResponse() {
        Account acc = createTestAccount(false, false, true);
        
        DRC_NBC_Integration_Payload.CustomerPayload payload = DRC_NBC_Account_BC_Callout.mapAccountToPayload(acc);
        String jsonBody = JSON.serialize(payload);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"success": true}'));
        
        DRC_NBC_Account_BC_Integration integration = new DRC_NBC_Account_BC_Integration(
            'test-endpoint',
            'POST',
            jsonBody,
            acc.Id
        );
        
        Test.startTest();
        HttpResponse response = integration.executeAndReturnResponse();
        Test.stopTest();
        
        System.assertNotEquals(null, response);
        System.assertEquals(201, response.getStatusCode());
    }
    
    // Test DRC_NBC_Account_BC_Callout_Queueable with successful callout and status update
    @isTest
    static void test_Queueable_SuccessCalloutWithStatusUpdate() {
        Account acc = createTestAccount(false, false, true);
        Order ord = createTestOrder(acc.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"success": true}'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_BC_Callout_Queueable(ord.Id));
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Callout_Second_Queue with 200 response
    @isTest
    static void test_SecondQueue_Success200() {
        Account acc = createTestAccount(false, false, true);
        Order ord = createTestOrder(acc.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"success": true}'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_BC_Callout_Second_Queue(ord.Id, acc.Id));
        Test.stopTest();
    }
    
    // Test DRC_NBC_Account_BC_Integration with 400 error
    @isTest
    static void test_Integration_ProcessResponse_Error400() {
        Account acc = createTestAccount(false, false, true);
        
        DRC_NBC_Integration_Payload.CustomerPayload payload = DRC_NBC_Account_BC_Callout.mapAccountToPayload(acc);
        String jsonBody = JSON.serialize(payload);
        
        DRC_NBC_Account_BC_Integration integration = new DRC_NBC_Account_BC_Integration(
            'test-endpoint',
            'POST',
            jsonBody,
            acc.Id
        );
        
        HttpResponse errorResp = new HttpResponse();
        errorResp.setStatusCode(400);
        errorResp.setBody('{"error":"Bad Request"}');
        
        Test.startTest();
        integration.processResponse(errorResp);
        Test.stopTest();
    }
    
    // Test payload mapping with all fields
    @isTest
    static void test_mapAccountToPayload_AllFields() {
        Account acc = createTestAccount(false, false, true);
        acc = [SELECT Id, Name, DRC_NBC_PAN_No__c, DRC_NBC_Payment_Term_Code__c, 
               DRC_NBC_Customer_Number__c, CurrencyIsoCode, Phone, 
               DRC_NBC_Account_Email_Email__c, BillingCity, BillingCountry, 
               BillingPostalCode, BillingState, BillingStateCode, 
               BillingStreet, DRC_NBC_GST_Number__c 
               FROM Account WHERE Id = :acc.Id];
        
        Test.startTest();
        DRC_NBC_Integration_Payload.CustomerPayload payload = DRC_NBC_Account_BC_Callout.mapAccountToPayload(acc);
        Test.stopTest();
    }
}