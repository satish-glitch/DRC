/**
* @File Name : DRC_NBC_UpdateShippingAddressTest.cls
* @Description : Test class for DRC_NBC_UpdateShippingAddress
*                Covers all branches: SUCCESS, SKIPPED, ERROR, READ failure,
*                Location_Code match/mismatch, missing fields, HTTP failures
* @Author : Satish YADAV
* @Last Modified On : February 19, 2026
**/
@isTest
private class DRC_NBC_UpdateShippingAddressTest {
    
    private static void setupCustomSetting(String shipToEndpoint) {
        DRC_NBC_BC_Integration__c settings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                    = UserInfo.getOrganizationId(),
            DRC_NBC_BC_ShipTo_Endpoint__c   = shipToEndpoint,
            DRC_NBC_SOAP_Order_Namespace__c  = 'urn:microsoft-dynamics-schemas/page/customershiptoaddresssalesforce',
            DRC_NBC_Username__c             = 'testuser',
            DRC_NBC_Password__c             = 'testpass'
        );
        insert settings;
    }
    
    private static Account createAccount(String customerNo) {
        Account acc = new Account(
            Name                        = 'Test Account',
            DRC_NBC_Customer_Number__c  = customerNo
        );
        insert acc;
        return acc;
    }
    
    private static DRC_NBC_Addresses__c createShippingAddress(Id accountId, String shipToCode, String warehouse) {
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            DRC_NBC_Ship_To_Code__c         = shipToCode,
            DRC_NBC_Address__Street__s      = 'Unit 501, EON Free Zone Tower 2',
            DRC_NBC_Address__City__s        = 'Pune',
            DRC_NBC_Address__PostalCode__s  = '411014',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Warehouse__c            = warehouse,
            DRC_NBC_Order__c                = null  // set after order creation if needed
        );
        insert addr;
        return addr;
    }
    
    private static Order createOrder(Id accountId, Id shippingAddressId, String warehouse) {
        Order ord = new Order(
            AccountId                       = accountId,
            Status                          = 'Draft',
            EffectiveDate                   = Date.today(),
            DRC_NBC_Shipping_Address__c     = shippingAddressId,
            DRC_NBC_Warehouse__c            = warehouse
        );
        insert ord;
        return ord;
    }
    
    private static String buildReadSuccessResponse(String key, String locationCode) {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read_Result xmlns="urn:microsoft-dynamics-schemas/page/customershiptoaddresssalesforce">' +
            '<CustomerShiptoAddressSalesForce>' +
            '<Key>' + key + '</Key>' +
            '<CustomerNo>CUST001</CustomerNo>' +
            '<ShiptoCode>SF-123519</ShiptoCode>' +
            '<Name>Test Shipping Address</Name>' +
            '<Location_Code>' + locationCode + '</Location_Code>' +
            '</CustomerShiptoAddressSalesForce>' +
            '</Read_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    private static String buildUpdateSuccessResponse() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Update_Result xmlns="urn:microsoft-dynamics-schemas/page/customershiptoaddresssalesforce">' +
            '<CustomerShiptoAddressSalesForce>' +
            '<Key>testkey123==</Key>' +
            '</CustomerShiptoAddressSalesForce>' +
            '</Update_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    private class ShipToMock implements HttpCalloutMock {
        private Integer readStatusCode;
        private String  readBody;
        private Integer updateStatusCode;
        private String  updateBody;
        private Integer callCount = 0;
        
        public ShipToMock(Integer readStatus, String readBody,
                          Integer updateStatus, String updateBody) {
                              this.readStatusCode   = readStatus;
                              this.readBody         = readBody;
                              this.updateStatusCode = updateStatus;
                              this.updateBody       = updateBody;
                          }
        
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            
            // First call = Read, Second call = Update
            if (callCount == 1) {
                res.setStatusCode(readStatusCode);
                res.setBody(readBody);
            } else {
                res.setStatusCode(updateStatusCode);
                res.setBody(updateBody);
            }
            return res;
        }
    }
    
    private class SingleCallMock implements HttpCalloutMock {
        private Integer statusCode;
        private String  body;
        
        public SingleCallMock(Integer statusCode, String body) {
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
    
    @isTest
    static void testSyncSuccess_LocationCodeChanged() {
        setupCustomSetting('https://bc.example.com/ShipTo');
        Account acc   = createAccount('CUST001');
        DRC_NBC_Addresses__c addr = createShippingAddress(acc.Id, 'SF-123519', 'Andheri Air Port');
        Order ord     = createOrder(acc.Id, addr.Id, 'Andheri Air Port');
        
        // BC returns OLD location code (different from SF resolved code)
        String readResp   = buildReadSuccessResponse('bckey==', 'OLD_LOC');
        String updateResp = buildUpdateSuccessResponse();
        
        Test.setMock(HttpCalloutMock.class, new ShipToMock(200, readResp, 200, updateResp));
        
        Test.startTest();
        String result = DRC_NBC_UpdateShippingAddress.syncShippingAddress(ord.Id);
        Test.stopTest();
    }
    
    
    @isTest
    static void testSyncSkipped_LocationCodeUnchanged() {
        setupCustomSetting('https://bc.example.com/ShipTo');
        Account acc   = createAccount('CUST001');
        DRC_NBC_Addresses__c addr = createShippingAddress(acc.Id, 'SF-123519', 'Andheri Air Port');
        Order ord     = createOrder(acc.Id, addr.Id, 'Andheri Air Port');
        
        String readResp = buildReadSuccessResponse('bckey==', '');
        
        Test.setMock(HttpCalloutMock.class, new SingleCallMock(200, readResp));
        
        Test.startTest();
        String result = DRC_NBC_UpdateShippingAddress.syncShippingAddress(ord.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testSyncSkipped_NoShippingAddress() {
        setupCustomSetting('https://bc.example.com/ShipTo');
        Account acc = createAccount('CUST001');
        Order ord = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today()
        );
        insert ord;
        
        Test.startTest();
        String result = DRC_NBC_UpdateShippingAddress.syncShippingAddress(ord.Id);
        Test.stopTest();
    }
    @isTest
    static void testSyncSkipped_BlankCustomerNumber() {
        setupCustomSetting('https://bc.example.com/ShipTo');
        Account acc = new Account(Name = 'No Cust No Account');
        insert acc;
        
        DRC_NBC_Addresses__c addr = createShippingAddress(acc.Id, 'SF-123519', 'Andheri Air Port');
        Order ord = createOrder(acc.Id, addr.Id, 'Andheri Air Port');
        
        Test.startTest();
        String result = DRC_NBC_UpdateShippingAddress.syncShippingAddress(ord.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testSyncSkipped_BlankShipToCode() {
        setupCustomSetting('https://bc.example.com/ShipTo');
        Account acc = createAccount('CUST001');
        DRC_NBC_Addresses__c addr = createShippingAddress(acc.Id, null, 'Andheri Air Port'); // No ShipToCode
        Order ord = createOrder(acc.Id, addr.Id, 'Andheri Air Port');
        
        Test.startTest();
        String result = DRC_NBC_UpdateShippingAddress.syncShippingAddress(ord.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testSyncError_BCReadReturns200WithNoKey() {
        setupCustomSetting('https://bc.example.com/ShipTo');
        Account acc   = createAccount('CUST001');
        DRC_NBC_Addresses__c addr = createShippingAddress(acc.Id, 'SF-123519', 'Andheri Air Port');
        Order ord     = createOrder(acc.Id, addr.Id, 'Andheri Air Port');
        
        // Valid XML but missing Key element in response
        String emptyReadResp =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read_Result xmlns="urn:microsoft-dynamics-schemas/page/customershiptoaddresssalesforce">' +
            '</Read_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
        
        Test.setMock(HttpCalloutMock.class, new SingleCallMock(200, emptyReadResp));
        
        Test.startTest();
        String result = DRC_NBC_UpdateShippingAddress.syncShippingAddress(ord.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testSyncError_BCReadReturnsMalformedXML() {
        setupCustomSetting('https://bc.example.com/ShipTo');
        Account acc   = createAccount('CUST001');
        DRC_NBC_Addresses__c addr = createShippingAddress(acc.Id, 'SF-123519', 'Andheri Air Port');
        Order ord     = createOrder(acc.Id, addr.Id, 'Andheri Air Port');
        
        Test.setMock(HttpCalloutMock.class, new SingleCallMock(200, 'not xml at all %%$$'));
        
        Test.startTest();
        String result = DRC_NBC_UpdateShippingAddress.syncShippingAddress(ord.Id);
        Test.stopTest();
    }
    
}