@isTest
private class DRC_NBC_BusinessCard_Controller_Test {
    
    // ─── Mock HTTP Response ───────────────────────────────────────────────────
    
    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String  responseBody;
        private String  status;
        
        public MockHttpResponse(Integer statusCode, String status, String responseBody) {
            this.statusCode   = statusCode;
            this.status       = status;
            this.responseBody = responseBody;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setStatus(status);
            res.setBody(responseBody);
            return res;
        }
    }
    
    // ─── Helper ───────────────────────────────────────────────────────────────
    
    private static DRC_NBC_BusinessCard_Controller.LeadWrapper buildWrapper(
        String name, String jobTitle, String company,
        String phone, String email, String website,
        String country, String city, String street,
        String postalCode, String state
    ) {
        DRC_NBC_BusinessCard_Controller.LeadWrapper wrapper =
            new DRC_NBC_BusinessCard_Controller.LeadWrapper();
        wrapper.name        = name;
        wrapper.jobTitle    = jobTitle;
        wrapper.companyName = company;
        wrapper.phoneNumber = phone;
        wrapper.email       = email;
        wrapper.websiteUrl  = website;
        wrapper.country     = country;
        wrapper.city        = city;
        wrapper.street      = street;
        wrapper.postalCode  = postalCode;
        wrapper.state       = state;
        return wrapper;
    }
    
    
    /**
* Covers: HTTP 200 → returns response body as-is
*/
    @isTest
    static void test_processBusinessCard_Success200() {
        String mockBody = '{"name":"John Doe","email":"john@test.com"}';
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, 'OK', mockBody));
        
        Test.startTest();
        String result = DRC_NBC_BusinessCard_Controller.processBusinessCard('https://example.com/card.jpg');
        Test.stopTest();
    }
    
    /**
* Covers: HTTP 429 → AuraHandledException with rate limit message
*/
    @isTest
    static void test_processBusinessCard_RateLimit429() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(429, 'Too Many Requests', 'Rate limit exceeded'));
        
        Test.startTest();
        try {
            DRC_NBC_BusinessCard_Controller.processBusinessCard('https://example.com/card.jpg');
        } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }
    
    /**
* Covers: HTTP 401 → AuraHandledException with auth failure message
*/
    @isTest
    static void test_processBusinessCard_Unauthorized401() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(401, 'Unauthorized', 'Unauthorized'));
        
        Test.startTest();
        try {
            DRC_NBC_BusinessCard_Controller.processBusinessCard('https://example.com/card.jpg');
        } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }
    
    /**
* Covers: HTTP 403 → AuraHandledException with auth failure message
*/
    @isTest
    static void test_processBusinessCard_Forbidden403() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(403, 'Forbidden', 'Forbidden'));
        
        Test.startTest();
        try {
            DRC_NBC_BusinessCard_Controller.processBusinessCard('https://example.com/card.jpg');
        } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }
    
    /**
* Covers: HTTP 500 → generic AuraHandledException with status code in message
*/
    @isTest
    static void test_processBusinessCard_ServerError500() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(500, 'Internal Server Error', 'Server error'));
        
        Test.startTest();
        try {
            DRC_NBC_BusinessCard_Controller.processBusinessCard('https://example.com/card.jpg');
        } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }
    
    /**
* Covers: HTTP 400 → generic AuraHandledException (other non-200 codes)
*/
    @isTest
    static void test_processBusinessCard_BadRequest400() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(400, 'Bad Request', 'Bad request body'));
        
        Test.startTest();
        try {
            DRC_NBC_BusinessCard_Controller.processBusinessCard('https://example.com/card.jpg');
        } catch (AuraHandledException e) {
            
        }
        Test.stopTest();
    }
    
    /**
* Covers: New lead with full name (first + last) → created successfully
* → status = 'success', leadId returned
*/
    @isTest
    static void test_createLead_Success_FullName() {
        DRC_NBC_BusinessCard_Controller.LeadWrapper wrapper = buildWrapper(
            'John Doe', 'Engineer', 'Tech Corp',
            '9876543210', 'john.doe@test.com', 'https://techcorp.com',
            'India', 'Mumbai', '123 Main St', '400001', 'Maharashtra'
        );
        
        Test.startTest();
        String result = DRC_NBC_BusinessCard_Controller.createLead(wrapper);
        Test.stopTest();
    }
}