/**
* @File Name   : DRC_NBC_Order_BC_Second_FutureTest.cls
* @Description : Test class for DRC_NBC_Order_BC_Callout_Second_Future
* @Modification Log :
*==============================================================================
* Ver | Date       | Modification
*==============================================================================
* 1.0 | 2026       | Initial Version
**/
@IsTest
private class DRC_NBC_Order_BC_Second_FutureTest {
    
    // =========================================================================
    // Mock HTTP — configurable status code + body
    // =========================================================================
    private class OrderBCMock implements HttpCalloutMock {
        private Integer statusCode;
        private String  body;
        
        OrderBCMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body       = body;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            return res;
        }
    }
    
    // =========================================================================
    // @TestSetup — shared data
    // =========================================================================
    @TestSetup
    static void setupData() {
        // Account
        Account acc = new Account(
            Name             = 'BC Future Test Account',
            CurrencyIsoCode = 'INR',
            Phone = '1234567890',
            AccountNumber = 'A123',
            DRC_NBC_PAN_No__c = 'AWVPY9594J',
            DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
            DRC_NBC_Customer_Number__c = 'CUST123',
            DRC_NBC_Payment_Term_Code__c = 'PDC90',
            DRC_NBC_Account_Email_Email__c = 'test@example.com',
            BillingStreet = '123 Street',
            BillingCity = 'City',
            BillingCountry = 'India',
            BillingCountryCode = 'IN',
            BillingPostalCode = '462002',
            BillingState = 'Maharashtra',
            BillingStateCode = 'MH',
            DRC_NBC_Volume__c = 70, 
            DRC_NBC_Credit_Limit__c = 123456787,
            DRC_NBC_Value__c = 900,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
            DRC_NBC_Consignee_Bank_Address__c = 'Barhi 483775',
            DRC_NBC_Consignee_Bank_IFSC_Code__c = 'PUNB01391000',
            DRC_NBC_Consignee_Bank_Name__c = 'Punjab National bank',
            Industry = 'Chemicals Construction',
            Type = 'Analyst'
        );
        insert acc;
        
        // Order
        Order ord = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id  = Test.getStandardPricebookId(),
            CurrencyIsoCode = 'INR',
            BillingStreet    = '1 Test Street',
            BillingCity      = 'Mumbai',
            BillingState     = 'Maharashtra',
            BillingPostalCode= '400001',
            BillingCountry   = 'India'
        );
        insert ord;
    }
    
    private static Id getOrderId() {
        return [SELECT Id FROM Order LIMIT 1].Id;
    }
    
    // =========================================================================
    // Test 1 — HTTP 201: success path
    // Covers: httpStatusCode == 201 → processOrderUpdate called
    // =========================================================================
    @IsTest
    static void test_processOrderBC_201_success() {
        Id orderId = getOrderId();
        
        Test.setMock(HttpCalloutMock.class,
                     new OrderBCMock(201, '{"status":"created"}'));
        
        Test.startTest();
        DRC_NBC_Order_BC_Callout_Second_Future.processOrderBC(orderId);
        Test.stopTest();
        // No exception = success path executed
    }
    
    // =========================================================================
    // Test 2 — HTTP 400: non-201 failure path
    // Covers: httpStatusCode != 201 → logError called with responseSummary
    // =========================================================================
    @IsTest
    static void test_processOrderBC_400_failure() {
        Id orderId = getOrderId();
        
        Test.setMock(HttpCalloutMock.class,
                     new OrderBCMock(400, '{"error":"Bad Request"}'));
        
        Test.startTest();
        DRC_NBC_Order_BC_Callout_Second_Future.processOrderBC(orderId);
        Test.stopTest();
    }
    
    // =========================================================================
    // Test 3 — HTTP 500: non-201, covers fallback 'No response body' message
    // responseSummary may be null/empty on server errors → triggers null check
    // =========================================================================
    @IsTest
    static void test_processOrderBC_500_nullResponseSummary() {
        Id orderId = getOrderId();
        
        Test.setMock(HttpCalloutMock.class,
                     new OrderBCMock(500, ''));
        
        Test.startTest();
        DRC_NBC_Order_BC_Callout_Second_Future.processOrderBC(orderId);
        Test.stopTest();
    }
    
    // =========================================================================
    // Test 4 — Exception path: pass a null/invalid orderId
    // Covers: catch block → logError(orderId, e.getMessage())
    // =========================================================================
    @IsTest
    static void test_processOrderBC_exceptionPath() {
        // null orderId causes getOrderDetails SOQL to throw or
        // mapOrderToBCPayload to throw a NullPointerException
        Test.setMock(HttpCalloutMock.class,
                     new OrderBCMock(201, '{"status":"created"}'));
        
        Test.startTest();
        DRC_NBC_Order_BC_Callout_Second_Future.processOrderBC(null);
        Test.stopTest();
        // catch block fires → logError called → no unhandled exception
    }
    
    // =========================================================================
    // Test 5 — HTTP 200: another non-201 code (not 400/500)
    // Ensures the `!= 201` branch is hit regardless of specific code
    // =========================================================================
    @IsTest
    static void test_processOrderBC_200_treatedAsFailure() {
        Id orderId = getOrderId();
        
        Test.setMock(HttpCalloutMock.class,
                     new OrderBCMock(200, '{"status":"ok"}'));
        
        Test.startTest();
        DRC_NBC_Order_BC_Callout_Second_Future.processOrderBC(orderId);
        Test.stopTest();
    }
}