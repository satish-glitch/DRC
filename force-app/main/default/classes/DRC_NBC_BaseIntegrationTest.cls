@isTest
private class DRC_NBC_BaseIntegrationTest {
    
    // Mock HTTP Response Generator
    class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":true,"message":"Success","data":{"token":"12345"}}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    // Static Dummy Integration class for testing
    private class DummyIntegration extends DRC_NBC_Base_API_Integration {
        public override HttpRequest prepareRequest() {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://example.com/test');
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            return req;
        }
        
        public override void processResponse(HttpResponse response) {
            // Mock implementation
        }
    }
    
    @testSetup
    static void setupTestData() {
        DRC_NBC_BC_Integration__c config = new DRC_NBC_BC_Integration__c(
            Name__c = System.Label.DRC_NBC_Sandbox,
            DRC_NBC_Comapny_Name__c = 'Test Company',
            DRC_NBC_Endpoint__c = '/api/test',
            DRC_NBC_SendOrderEndpoint__c = 'SendOrder',
            DRC_NBC_Shipping_Address_Endpoint__c = 'Shipping',
            DRC_NBC_Token_Generated_Time__c = System.now().addMinutes(-5),
            DRC_NBC_SendOrderLineEndpoint__c = 'SendOrderLine',
            DRC_NBC_SalesPerson_Code__c = 'SP001'
        );
        insert config;
    }
    
    @isTest
    static void testUtilityMethods() {
        System.assertNotEquals(null, DRC_NBC_BC_Callout_Utility.isSandbox());
        
        DRC_NBC_BC_Integration__c config = DRC_NBC_BC_Callout_Utility.getConfig();
        System.assertEquals('Test Company', config.DRC_NBC_Comapny_Name__c);
        
        String endpoint = DRC_NBC_BC_Callout_Utility.getFullEndpoint('SamplePath');
        System.assert(endpoint.startsWith('callout:'));
        
        System.assertEquals(false, DRC_NBC_BC_Callout_Utility.isTokenExpired());
        
        String trimmed = DRC_NBC_BC_Callout_Utility.trimPayload('x'.repeat(150000));
        System.assert(trimmed.length() <= 131072);
        
        String json = '{"status":true,"message":"OK","data":{"key":"value"}}';
        DRC_NBC_Integration_Payload.BCResponse resp = DRC_NBC_BC_Callout_Utility.parseResponse(json);
        System.assertEquals(true, resp.status);
    }
    
    @isTest
    static void testTokenGenerationSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        DRC_NBC_BC_Generate_Token token = new DRC_NBC_BC_Generate_Token('TestPath', 'GET');
        HttpResponse response = token.executeAndReturnResponse();
        Test.stopTest();
        
        System.assertNotEquals(null, response);
    }
    
    @isTest
    static void testCreateHttpRequestAndHeaders() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        DummyIntegration dummy = new DummyIntegration();
        HttpRequest req = dummy.prepareRequest();
        Test.stopTest();
        
        System.assertNotEquals(null, req, 'Request should not be null');
        System.assertEquals('GET', req.getMethod(), 'Method should be GET');
    }
    
    @isTest
    static void testExecuteMethodWrapper() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        DummyIntegration dummy = new DummyIntegration();
        
        Test.startTest();
        dummy.execute(); // covers execute()
        Test.stopTest();
    }
    
    /* ================= BASE CLASS: catch block ================= */
/*    @isTest
    static void testExecuteMethodExceptionHandling() {
        class ExceptionThrowingMock implements HttpCalloutMock {
            public HttpResponse respond(HttpRequest req) {
                throw new CalloutException('Simulated exception');
            }
        }
        
        Test.setMock(HttpCalloutMock.class, new ExceptionThrowingMock());
        
        class DummyIntegrationException extends DRC_NBC_Base_API_Integration {
            public override HttpRequest prepareRequest() {
                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://fake.endpoint');
                req.setMethod('GET');
                return req;
            }
            
            public override void processResponse(HttpResponse res) {
                // Mock implementation
            }
        }
        
        DummyIntegrationException dummy = new DummyIntegrationException();
        
        Test.startTest();
        try {
            dummy.executeAndReturnResponse();
            System.assert(false, 'Exception expected');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('Simulated exception'));
        }
        Test.stopTest();
    }*/
    
    /* ================= PAYLOAD ================= */
    @isTest
    static void testPayloadStructures() {
        DRC_NBC_Integration_Payload.WebToLeadPayLoad lead = new DRC_NBC_Integration_Payload.WebToLeadPayLoad();
        lead.company = 'Test Company';
        lead.interestedChemistry = new Set<String>{ 'ProductA' };
        System.assertEquals('Test Company', lead.company);
        
        DRC_NBC_Integration_Payload.invoiceSyncPayload invoice = new DRC_NBC_Integration_Payload.invoiceSyncPayload();
        invoice.InvoiceNumber = 'INV1001';
        invoice.InvoiceDate = Date.today();
        
        DRC_NBC_Integration_Payload.invoiceLineItem item = new DRC_NBC_Integration_Payload.invoiceLineItem();
        item.ProductCode = 'PROD1';
        item.Amount = 500;
        
        invoice.lineItems = new List<DRC_NBC_Integration_Payload.invoiceLineItem>{ item };
        System.assertEquals('PROD1', invoice.lineItems[0].ProductCode);
    }
}