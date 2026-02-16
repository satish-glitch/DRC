/**
 * @File Name : DRC_NBC_SalesPersonCode_Callout_Test.cls
 * @Description : Test class for DRC_NBC_SalesPersonCode_Callout and DRC_NBC_SalesPerson_BC_Integration
 * @Author : Satish
 * @Last Modified On : January 02, 2026
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
    
    private static Account createTestAccount() {
        Account acc = new Account(
            Name = 'Test Account',
            CurrencyIsoCode = 'INR',
            Phone = '1234567890',
            AccountNumber = 'A123',
            DRC_NBC_PAN_No__c = 'AWVPY9594J',
            DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
            DRC_NBC_Customer_Number__c = 'CUST123',
            DRC_NBC_Payment_Term_Code__c = '10 DAYS',
            DRC_NBC_Account_Email_Email__c = 'test@example.com',
            BillingStreet = '123 Street',
            BillingCity = 'City',
            BillingCountry = 'India',
            BillingCountryCode = 'IN',
            BillingPostalCode = '462002',
            BillingState = 'Maharashtra',
            BillingStateCode = 'MH'
        );
        insert acc;
        return acc;
    }
    
    private static Contact createTestContact(Id accountId) {
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'testcontact@example.com',
            Phone = '9876543210',
            AccountId = accountId
        );
        insert con;
        return con;
    }
    
    private static Order createTestOrder(Id accountId, Id contactId) {
        Order ord = new Order(
            Name = 'Test Order',
            AccountId = accountId,
            ShipToContactId = contactId,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            DRC_NBC_Account_Approval_Status__c = 'Pending'
        );
        insert ord;
        return ord;
    }
    
    // Test successful callout in queueable context
    @isTest
    static void test_Queueable_SuccessfulCallout() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"message": "Success"}'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_SalesPersonCode_Callout(ord.Id));
        Test.stopTest();
    }
    
    // Test executeCallout method directly with success (200)
    @isTest
    static void test_ExecuteCallout_Success200() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(200, '{"message": "Success"}'));
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result);
    }
    
    // Test executeCallout with 201 Created response
    @isTest
    static void test_ExecuteCallout_Success201() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"message": "Created"}'));
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result);
    }
    
    // Test executeCallout with 204 No Content response
    @isTest
    static void test_ExecuteCallout_Success204() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(204, ''));
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result);
    }
    
    // Test executeCallout with failed HTTP response (500)
    @isTest
    static void test_ExecuteCallout_HttpFailure500() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, '{"error": "Server error"}'));
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }
    
    // Test executeCallout with 400 Bad Request
    @isTest
    static void test_ExecuteCallout_BadRequest400() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(400, '{"error": "Bad Request"}'));
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }
    
    // Test executeCallout with 404 Not Found
    @isTest
    static void test_ExecuteCallout_NotFound404() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(404, '{"error": "Not Found"}'));
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }
    
    // Test executeCallout with 401 Unauthorized
    @isTest
    static void test_ExecuteCallout_Unauthorized401() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(401, '{"error": "Unauthorized"}'));
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }
    
    // Test executeCallout when no Contact exists for Account
    @isTest
    static void test_ExecuteCallout_NoContact() {
        Account acc = createTestAccount();
        Order ord = new Order(
            Name = 'Test Order',
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today()
        );
        insert ord;
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
    }
    
    // Test executeCallout with invalid Order Id
    @isTest
    static void test_ExecuteCallout_InvalidOrderId() {
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout('801000000000000AAA');
        Test.stopTest();
    }
    
    // Test executeCallout with null Order Id
    @isTest
    static void test_ExecuteCallout_NullOrderId() {
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(null);
        Test.stopTest();
    }
    
    // Test Integration prepareRequest method
    @isTest
    static void test_Integration_PrepareRequest() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        
        Map<String, Object> payloadMap = new Map<String, Object>{
            'Name' => con.Name,
            'Phone_No' => con.Phone,
            'E_Mail' => con.Email,
            'Code' => con.Id
        };
        String payload = JSON.serialize(payloadMap);
        
        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint',
            'POST',
            payload,
            con.Id
        );
        
        Test.startTest();
        HttpRequest req = integration.prepareRequest();
        Test.stopTest();
        
        System.assertNotEquals(null, req);
        System.assertEquals('POST', req.getMethod());
        System.assertEquals(payload, req.getBody());
    }
    
    // Test Integration processResponse with success (200)
    @isTest
    static void test_Integration_ProcessResponse_Success200() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        
        Map<String, Object> payloadMap = new Map<String, Object>{
            'Name' => con.Name,
            'Phone_No' => con.Phone,
            'E_Mail' => con.Email,
            'Code' => con.Id
        };
        String payload = JSON.serialize(payloadMap);
        
        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint',
            'POST',
            payload,
            con.Id
        );
        
        HttpResponse successResp = new HttpResponse();
        successResp.setStatusCode(200);
        successResp.setBody('{"message":"Success"}');
        
        Test.startTest();
        integration.processResponse(successResp);
        Test.stopTest();
        
        System.assertEquals(200, integration.httpStatusCode);
        System.assertEquals('{"message":"Success"}', integration.responseSummary);
    }
    
    // Test Integration processResponse with success (201)
    @isTest
    static void test_Integration_ProcessResponse_Success201() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        
        Map<String, Object> payloadMap = new Map<String, Object>{
            'Name' => con.Name,
            'Phone_No' => con.Phone,
            'E_Mail' => con.Email,
            'Code' => con.Id
        };
        String payload = JSON.serialize(payloadMap);
        
        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint',
            'POST',
            payload,
            con.Id
        );
        
        HttpResponse successResp = new HttpResponse();
        successResp.setStatusCode(201);
        successResp.setBody('{"message":"Created"}');
        
        Test.startTest();
        integration.processResponse(successResp);
        Test.stopTest();
        
        System.assertEquals(201, integration.httpStatusCode);
        System.assertEquals('{"message":"Created"}', integration.responseSummary);
    }
    
    // Test Integration processResponse with error (500)
    @isTest
    static void test_Integration_ProcessResponse_Error500() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        
        Map<String, Object> payloadMap = new Map<String, Object>{
            'Name' => con.Name,
            'Phone_No' => con.Phone,
            'E_Mail' => con.Email,
            'Code' => con.Id
        };
        String payload = JSON.serialize(payloadMap);
        
        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint',
            'POST',
            payload,
            con.Id
        );
        
        HttpResponse errorResp = new HttpResponse();
        errorResp.setStatusCode(500);
        errorResp.setBody('{"error":"Internal Server Error"}');
        
        Test.startTest();
        integration.processResponse(errorResp);
        Test.stopTest();
        
        System.assertEquals(500, integration.httpStatusCode);
        System.assertEquals('{"error":"Internal Server Error"}', integration.responseSummary);
    }
    
    // Test Integration processResponse with error (400)
    @isTest
    static void test_Integration_ProcessResponse_Error400() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        
        Map<String, Object> payloadMap = new Map<String, Object>{
            'Name' => con.Name,
            'Phone_No' => con.Phone,
            'E_Mail' => con.Email,
            'Code' => con.Id
        };
        String payload = JSON.serialize(payloadMap);
        
        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint',
            'POST',
            payload,
            con.Id
        );
        
        HttpResponse errorResp = new HttpResponse();
        errorResp.setStatusCode(400);
        errorResp.setBody('{"error":"Bad Request"}');
        
        Test.startTest();
        integration.processResponse(errorResp);
        Test.stopTest();
        
        System.assertEquals(400, integration.httpStatusCode);
        System.assertEquals('{"error":"Bad Request"}', integration.responseSummary);
    }
    
    // Test Integration executeAndReturnResponse
    @isTest
    static void test_Integration_ExecuteAndReturnResponse() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        
        Map<String, Object> payloadMap = new Map<String, Object>{
            'Name' => con.Name,
            'Phone_No' => con.Phone,
            'E_Mail' => con.Email,
            'Code' => con.Id
        };
        String payload = JSON.serialize(payloadMap);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"message": "Success"}'));
        
        DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
            'test-endpoint',
            'POST',
            payload,
            con.Id
        );
        
        Test.startTest();
        HttpResponse response = integration.executeAndReturnResponse();
        Test.stopTest();
        
        System.assertNotEquals(null, response);
        System.assertEquals(201, response.getStatusCode());
        System.assertEquals(201, integration.httpStatusCode);
    }
    
    // Test payload structure
    @isTest
    static void test_PayloadStructure() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        
        Map<String, Object> payloadMap = new Map<String, Object>{
            'Name' => con.Name,
            'Phone_No' => con.Phone,
            'E_Mail' => con.Email,
            'Code' => con.Id
        };
        
        Test.startTest();
        String payload = JSON.serialize(payloadMap);
        Map<String, Object> deserializedPayload = (Map<String, Object>) JSON.deserializeUntyped(payload);
        Test.stopTest();
    }
    
    // Test with Contact having null phone
    @isTest
    static void test_ExecuteCallout_ContactNullPhone() {
        Account acc = createTestAccount();
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'testcontact@example.com',
            Phone = null,
            AccountId = acc.Id
        );
        insert con;
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"message": "Success"}'));
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result);
    }
    
    // Test with Contact having null email
    @isTest
    static void test_ExecuteCallout_ContactNullEmail() {
        Account acc = createTestAccount();
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = null,
            Phone = '9876543210',
            AccountId = acc.Id
        );
        insert con;
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"message": "Success"}'));
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result);
    }
    
    // Test with Contact having both null phone and email
    @isTest
    static void test_ExecuteCallout_ContactNullPhoneAndEmail() {
        Account acc = createTestAccount();
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = null,
            Phone = null,
            AccountId = acc.Id
        );
        insert con;
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, '{"message": "Success"}'));
        
        Test.startTest();
        String result = DRC_NBC_SalesPersonCode_Callout.executeCallout(ord.Id);
        Test.stopTest();
        
        System.assertEquals('SUCCESS', result);
    }
    
    // Test queueable with failed response
    @isTest
    static void test_Queueable_FailedCallout() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, '{"error": "Server Error"}'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_SalesPersonCode_Callout(ord.Id));
        Test.stopTest();
    }
    
    // Test queueable with 400 error
    @isTest
    static void test_Queueable_BadRequestCallout() {
        Account acc = createTestAccount();
        Contact con = createTestContact(acc.Id);
        Order ord = createTestOrder(acc.Id, con.Id);
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(400, '{"error": "Bad Request"}'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_SalesPersonCode_Callout(ord.Id));
        Test.stopTest();
    }
}