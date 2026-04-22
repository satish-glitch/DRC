@isTest
public class DRC_NBC_CheckShippingDetails_Test {
    
    // ── Test Data Setup ────────────────────────────────────────────────────────
    @TestSetup
    static void setupTestData() {
        
        // Create Custom Setting
        DRC_NBC_BC_Integration__c settings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                   = UserInfo.getOrganizationId(),
            DRC_NBC_Shipping_Endpoint__c   = 'https://mock-bc-endpoint.com/shipping',
            DRC_NBC_Shipping_Name_Space__c = 'urn:microsoft-dynamics-schemas/page/customershiptoaddresssalesforce',
            DRC_NBC_Username__c            = 'testuser',
            DRC_NBC_Password__c            = 'testpassword'
        );
        insert settings;
        
        // Create Account
        Account acc = new Account(
            Name                                     = 'Test Shipping Account',
            Phone                                    = '9876543210',
            DRC_NBC_Customer_Number__c               = 'CUST001',
            CurrencyIsoCode                          = 'INR',
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
            Type                                     = 'Analyst'
        );
        insert acc;
        
        // Create Shipping Address
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Ship_To_Code__c         = 'SHIP001',
            DRC_NBC_Address__Street__s      = '123 Test Street',
            DRC_NBC_Address__City__s        = 'Mumbai',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__PostalCode__s  = '400001',
            DRC_NBC_Address__CountryCode__s = 'IN'
        );
        insert addr;
        
        // Create Order linked to shipping address
        Order ord = new Order(
            AccountId                   = acc.Id,
            Status                      = 'Draft',
            EffectiveDate               = Date.today(),
            DRC_NBC_Shipping_Address__c = addr.Id
        );
        insert ord;
    }
    
    // ── Helpers ────────────────────────────────────────────────────────────────
    private static Account getAccount() {
        return [SELECT Id, DRC_NBC_Customer_Number__c FROM Account 
                WHERE Name = 'Test Shipping Account' LIMIT 1];
    }
    
    private static Order getOrder() {
        return [SELECT Id, DRC_NBC_Shipping_Address__c FROM Order LIMIT 1];
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // TEST 1: Ship-To EXISTS in BC → 200 with body data → return false
    // ══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testShipToExists_Returns_False() {
        Account acc = getAccount();
        Order   ord = getOrder();
        
        String mockResponse =
            '<Soap:Envelope xmlns:Soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<Soap:Body>' +
            '<ReadResult>' +
            '<CustomerNo>CUST001</CustomerNo>' +
            '<ShiptoCode>SHIP001</ShiptoCode>' +
            '</ReadResult>' +
            '</Soap:Body>' +
            '</Soap:Envelope>';
        
        Test.setMock(HttpCalloutMock.class, new DRC_NBC_MockHttpResponse(200, mockResponse));
        
        Test.startTest();
        Boolean result = DRC_NBC_CheckShiipingDetails.checkShippingExists(ord.Id, acc.Id);
        Test.stopTest();
        
        System.assertEquals(false, result, 'Should return false — Ship-To already exists in BC');
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // TEST 2: BC returns empty Soap:Body (self-closing) → return true
    // ══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testEmptySoapBody_SelfClosing_Returns_True() {
        Account acc = getAccount();
        Order   ord = getOrder();
        
        String mockResponse =
            '<Soap:Envelope xmlns:Soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<Soap:Body/>' +
            '</Soap:Envelope>';
        
        Test.setMock(HttpCalloutMock.class, new DRC_NBC_MockHttpResponse(200, mockResponse));
        
        Test.startTest();
        Boolean result = DRC_NBC_CheckShiipingDetails.checkShippingExists(ord.Id, acc.Id);
        Test.stopTest();
        
        System.assertEquals(true, result, 'Should return true — empty self-closing Soap:Body means not found');
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // TEST 3: BC returns empty Soap:Body (open-close tags) → return true
    // ══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testEmptySoapBody_OpenClose_Returns_True() {
        Account acc = getAccount();
        Order   ord = getOrder();
        
        String mockResponse =
            '<Soap:Envelope xmlns:Soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<Soap:Body></Soap:Body>' +
            '</Soap:Envelope>';
        
        Test.setMock(HttpCalloutMock.class, new DRC_NBC_MockHttpResponse(200, mockResponse));
        
        Test.startTest();
        Boolean result = DRC_NBC_CheckShiipingDetails.checkShippingExists(ord.Id, acc.Id);
        Test.stopTest();
        
        System.assertEquals(true, result, 'Should return true — empty open/close Soap:Body means not found');
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // TEST 4: BC returns 500 SOAP Fault → return true
    // ══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testSoapFault_500_Returns_True() {
        Account acc = getAccount();
        Order   ord = getOrder();
        
        String mockResponse =
            '<Soap:Envelope xmlns:Soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<Soap:Body>' +
            '<Soap:Fault>' +
            '<faultcode>Soap:Client</faultcode>' +
            '<faultstring>Record not found</faultstring>' +
            '</Soap:Fault>' +
            '</Soap:Body>' +
            '</Soap:Envelope>';
        
        Test.setMock(HttpCalloutMock.class, new DRC_NBC_MockHttpResponse(500, mockResponse));
        
        Test.startTest();
        Boolean result = DRC_NBC_CheckShiipingDetails.checkShippingExists(ord.Id, acc.Id);
        Test.stopTest();
        
        System.assertEquals(true, result, 'Should return true — 500 SOAP Fault means not found in BC');
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // TEST 5: Account has no Customer Number → return true (guard clause)
    // ══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testNoCustomerNumber_Returns_True() {
        Order ord = getOrder();
        
        Account accNoCustomer = new Account(  Name                                     = 'Excel11',
                                            Phone                                    = '9876453210',
                                            DRC_NBC_Customer_Number__c               = 'CUST001',
                                            CurrencyIsoCode                          = 'INR',
                                            AccountNumber                            = 'ACC301',
                                            DRC_NBC_PAN_No__c                        = 'AWVPY9594J',
                                            DRC_NBC_GST_Number__c                    = '27AWVPY9594J1ZY',
                                            DRC_NBC_Payment_Term_Code__c             = 'PDC90',
                                            DRC_NBC_Account_Email_Email__c           = 'test23@test.com',
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
                                            Type                                     = 'Analyst');
        insert accNoCustomer;
        
        Test.startTest();
        Boolean result = DRC_NBC_CheckShiipingDetails.checkShippingExists(ord.Id, accNoCustomer.Id);
        Test.stopTest();
        
        System.assertEquals(true, result, 'Should return true — no Customer Number on Account');
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // TEST 6: Order has no Shipping Address linked → return true (guard clause)
    // ══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testNoShippingAddressOnOrder_Returns_True() {
        Account acc = getAccount();
        
        Order ordNoAddr = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today()
        );
        insert ordNoAddr;
        
        Test.startTest();
        Boolean result = DRC_NBC_CheckShiipingDetails.checkShippingExists(ordNoAddr.Id, acc.Id);
        Test.stopTest();
        
        System.assertEquals(true, result, 'Should return true — no shipping address on Order');
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // TEST 7: Shipping Address has no ShipToCode → return true (guard clause)
    // ══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testNoShipToCode_Returns_True() {
        Account acc = getAccount();
        
        DRC_NBC_Addresses__c addrNoCode = new DRC_NBC_Addresses__c(
            DRC_NBC_Type__c            = 'Shipping',
            DRC_NBC_Address__Street__s = '456 No Code Street'
        );
        insert addrNoCode;
        
        Order ordNoCode = new Order(
            AccountId                   = acc.Id,
            Status                      = 'Draft',
            EffectiveDate               = Date.today(),
            DRC_NBC_Shipping_Address__c = addrNoCode.Id
        );
        insert ordNoCode;
        
        Test.startTest();
        Boolean result = DRC_NBC_CheckShiipingDetails.checkShippingExists(ordNoCode.Id, acc.Id);
        Test.stopTest();
        
        System.assertEquals(true, result, 'Should return true — ShipToCode is blank');
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // TEST 8: Endpoint unreachable / non-200 response → return true
    // ══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testCalloutFailure_Returns_True() {
        Account acc = getAccount();
        Order   ord = getOrder();
        
        // Use 503 to simulate unreachable endpoint — hits the non-200 return true path
        Test.setMock(HttpCalloutMock.class, new DRC_NBC_MockHttpResponse(503, ''));
        
        Test.startTest();
        Boolean result = DRC_NBC_CheckShiipingDetails.checkShippingExists(ord.Id, acc.Id);
        Test.stopTest();
        
        System.assertEquals(true, result, 'Should return true — non-200 response treated as not found');
    }
    
    
    // ══════════════════════════════════════════════════════════════════════════
    // MOCK: Single unified HTTP Response mock
    // Handles all scenarios via statusCode + body
    // ══════════════════════════════════════════════════════════════════════════
    private class DRC_NBC_MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String  body;
        
        public DRC_NBC_MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body       = body;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(body);
            res.setHeader('Content-Type', 'text/xml');
            return res;
        }
    }
}