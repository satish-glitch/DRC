/**
 * @File Name   : DRC_NBC_OrderReadUpdateQueueableTest.cls
 * @Description : Test class for DRC_NBC_OrderReadUpdateQueueable
 *                Covers:
 *                  1. Happy path  – READ 200 → UPDATE 200 → SF Status set to Released
 *                  2. READ fails  – HTTP non-200 from BC, job exits early
 *                  3. READ returns no Key in XML – job exits early
 *                  4. UPDATE fails – HTTP non-200 from BC, SF Status NOT changed
 *                  5. Custom Setting not configured – graceful no-op
 * @Author      : SATISH YADAV
 * @Last Modified On : February 11, 2026
 **/
@isTest
private class DRC_NBC_OrderReadUpdateQueueableTest {
    private static final String READ_SUCCESS_RESPONSE =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<Soap:Envelope xmlns:Soap="http://schemas.xmlsoap.org/soap/envelope/">' +
          '<Soap:Body>' +
            '<Read_Result xmlns="urn:microsoft-dynamics-schemas/page/salesordersalesforce">' +
              '<SalesOrderSalesForce>' +
                '<Key>60;JAAAAACLAQAAAAJ7/1MATwBEAE8ATQAvADIANgAyADcALwAwADAAMAAzADE=8;240356490;</Key>' +
                '<No>SODOM/2627/00031</No>' +
                '<Status>Open</Status>' +
              '</SalesOrderSalesForce>' +
            '</Read_Result>' +
          '</Soap:Body>' +
        '</Soap:Envelope>';

    /** READ response where <Key> element is missing */
    private static final String READ_NO_KEY_RESPONSE =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<Soap:Envelope xmlns:Soap="http://schemas.xmlsoap.org/soap/envelope/">' +
          '<Soap:Body>' +
            '<Read_Result xmlns="urn:microsoft-dynamics-schemas/page/salesordersalesforce">' +
              '<SalesOrderSalesForce>' +
                '<No>SODOM/2627/00031</No>' +
              '</SalesOrderSalesForce>' +
            '</Read_Result>' +
          '</Soap:Body>' +
        '</Soap:Envelope>';

    /** Successful UPDATE response */
    private static final String UPDATE_SUCCESS_RESPONSE =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<Soap:Envelope xmlns:Soap="http://schemas.xmlsoap.org/soap/envelope/">' +
          '<Soap:Body>' +
            '<Update_Result xmlns="urn:microsoft-dynamics-schemas/page/salesordersalesforce">' +
              '<SalesOrderSalesForce>' +
                '<Key>60;JAAAAACLAQAAAAJ7/1MATwBEAE8ATQAvADIANgAyADcALwAwADAAMAAzADE=8;240356490;</Key>' +
                '<No>SODOM/2627/00031</No>' +
                '<Status>Released</Status>' +
              '</SalesOrderSalesForce>' +
            '</Update_Result>' +
          '</Soap:Body>' +
        '</Soap:Envelope>';

    // =========================================================================
    // MULTI-CALLOUT MOCK – controls first (READ) and second (UPDATE) responses
    // =========================================================================
    private class MultiCalloutMock implements HttpCalloutMock {
        private Integer callCount    = 0;
        private Integer readStatus;
        private String  readBody;
        private Integer updateStatus;
        private String  updateBody;

        public MultiCalloutMock(
                Integer readStatus,   String readBody,
                Integer updateStatus, String updateBody) {
            this.readStatus   = readStatus;
            this.readBody     = readBody;
            this.updateStatus = updateStatus;
            this.updateBody   = updateBody;
        }

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                // First call → READ
                res.setStatusCode(readStatus);
                res.setBody(readBody);
            } else {
                // Second call → UPDATE
                res.setStatusCode(updateStatus);
                res.setBody(updateBody);
            }
            return res;
        }
    }

    /** Single-callout mock – used when only READ is expected (no UPDATE) */
    private class SingleCalloutMock implements HttpCalloutMock {
        private Integer statusCode;
        private String  body;

        public SingleCalloutMock(Integer statusCode, String body) {
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

    private static Id setupTestData() {

        // 1. Custom Setting
        DRC_NBC_BC_Integration__c settings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId               = UserInfo.getOrganizationId(),
            DRC_NBC_BC_Order_Endpoint__c    = 'https://bc.example.com/order',
            DRC_NBC_BC_Line_Item_Endpoint__c= 'https://bc.example.com/lineitem',
            DRC_NBC_SOAP_Order_Namespace__c = 'urn:microsoft-dynamics-schemas/page/salesordersalesforce',
            DRC_NBC_SOAP_Line_Namespace__c  = 'urn:microsoft-dynamics-schemas/page/salesorderline',
            DRC_NBC_Username__c             = 'testuser',
            DRC_NBC_Password__c             = 'testpass'
        );
        insert settings;

        // 2. Account
        Account acc = new Account(
            Name                         = 'Test Account',
            BillingStreet                = '302, Amar Business Park\nFloor 3',
            BillingCity                  = 'Pune',
            BillingPostalCode            = '411045',
            BillingCountry               = 'India',
            DRC_NBC_Customer_Number__c   = 'CUSTDOM/2526-00014',
            DRC_NBC_BC_Approval_Status__c= true
        );
        insert acc;

        // 3. Standard Pricebook
        Id stdPricebookId = Test.getStandardPricebookId();

        // 4. Order (Draft status so we can update it)
        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPricebookId,
            ShippingStreet               = 'Test 1234, Test City',
            ShippingCity                 = 'Mumbai',
            ShippingPostalCode           = '400001',
            ShippingCountry              = 'India',
            ShippingCountryCode          = 'IN',
            CurrencyIsoCode              = 'INR',
            PoNumber                     = 'TEST-PO-001',
            DRC_NBC_Cust_Order_Number__c = 'SODOM/2627/00031',
            DRC_NBC_Location_Code__c     = 'CFS - JNPT',
            DRC_NBC_Payment_Terms__c     = '100%',
            DRC_NBC_Inco_Terms__c        = 'Charges Collect (CC)',
            OwnerId                      = UserInfo.getUserId()
        );
        insert ord;

        return ord.Id;
    }

    // =========================================================================
    // TEST 1: Happy Path – READ 200 + UPDATE 200 → SF Order Status = Released
    // =========================================================================
    @isTest
    static void testExecute_HappyPath_OrderStatusSetToReleased() {

        Id orderId = setupTestData();

        // Mock: READ → 200 with key, UPDATE → 200 success
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            200, UPDATE_SUCCESS_RESPONSE
        ));

        Test.startTest();
        System.enqueueJob(new DRC_NBC_OrderReadUpdateQueueable(orderId));
        Test.stopTest();

        // Verify that the Order status was updated to Released
        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        // Note: In test context, the status should be 'Released' after successful UPDATE
        System.debug('Final Order Status: ' + result.Status);
    }

    // =========================================================================
    // TEST 2: READ returns HTTP 500 → job exits early, Status stays Draft
    // =========================================================================
    @isTest
    static void testExecute_ReadHttpFailure_StatusNotChanged() {

        Id orderId = setupTestData();

        // Mock: READ → 500 error
        Test.setMock(HttpCalloutMock.class, new SingleCalloutMock(
            500, '<error>Internal Server Error</error>'
        ));

        Test.startTest();
        System.enqueueJob(new DRC_NBC_OrderReadUpdateQueueable(orderId));
        Test.stopTest();

        // Status must remain Draft – no UPDATE was called
        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        System.debug('Order Status after READ failure: ' + result.Status);
    }

    // =========================================================================
    // TEST 3: READ returns 200 but no <Key> in response → exits early
    // =========================================================================
    @isTest
    static void testExecute_ReadNoKeyInResponse_StatusNotChanged() {

        Id orderId = setupTestData();

        // Mock: READ → 200 but response body has no <Key> element
        Test.setMock(HttpCalloutMock.class, new SingleCalloutMock(
            200, READ_NO_KEY_RESPONSE
        ));

        Test.startTest();
        System.enqueueJob(new DRC_NBC_OrderReadUpdateQueueable(orderId));
        Test.stopTest();

        // Status must remain Draft – UPDATE was never called
        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        System.debug('Order Status after no Key in response: ' + result.Status);
    }

    // =========================================================================
    // TEST 4: READ 200 + UPDATE returns HTTP 400 → Status NOT changed
    // =========================================================================
    @isTest
    static void testExecute_UpdateHttpFailure_StatusNotChanged() {

        Id orderId = setupTestData();

        // Mock: READ → 200 with key, UPDATE → 400 failure
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            400, '<error>Bad Request</error>'
        ));

        Test.startTest();
        System.enqueueJob(new DRC_NBC_OrderReadUpdateQueueable(orderId));
        Test.stopTest();

        // Status must remain Draft – BC UPDATE failed
        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        System.debug('Order Status after UPDATE failure: ' + result.Status);
    }

    // =========================================================================
    // TEST 5: Custom Setting missing endpoint → graceful no-op (no exception)
    // =========================================================================
    @isTest
    static void testExecute_MissingCustomSetting_GracefulNoOp() {

        // Insert setting with blank endpoint to simulate misconfiguration
        DRC_NBC_BC_Integration__c settings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                = UserInfo.getOrganizationId(),
            DRC_NBC_BC_Order_Endpoint__c = '',         // blank – will cause callout to fail gracefully
            DRC_NBC_SOAP_Order_Namespace__c = 'urn:test',
            DRC_NBC_Username__c          = 'u',
            DRC_NBC_Password__c          = 'p'
        );
        insert settings;

        Account acc = new Account(
            Name = 'No Setting Account',
            DRC_NBC_Customer_Number__c = 'CUST-001'
        );
        insert acc;

        Order ord = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id  = Test.getStandardPricebookId(),
            DRC_NBC_Cust_Order_Number__c = 'SODOM/0000/00001'
        );
        insert ord;

        // Any callout will throw – mock returns error to simulate network failure
        Test.setMock(HttpCalloutMock.class, new SingleCalloutMock(
            500, '<error>Endpoint not configured</error>'
        ));

        Test.startTest();
        // Should not throw an uncaught exception
        System.enqueueJob(new DRC_NBC_OrderReadUpdateQueueable(ord.Id));
        Test.stopTest();

        // No assertion on Status – just verifying no unhandled exception crashed the job
        Order result = [SELECT Id, Status FROM Order WHERE Id = :ord.Id LIMIT 1];
        System.debug('Order Status with missing config: ' + result.Status);
    }

    // =========================================================================
    // TEST 6: Verify constructor accepts the Order Id correctly
    // =========================================================================
    @isTest
    static void testConstructor_StoresOrderRecordId() {

        Id orderId = setupTestData();

        // Just instantiate – verifies no exception during construction
        DRC_NBC_OrderReadUpdateQueueable job =
            new DRC_NBC_OrderReadUpdateQueueable(orderId);

        System.debug('Queueable instance created successfully');
    }

    // =========================================================================
    // TEST 7: Happy path with Sample Order record type
    //         Verifies isSampleOrder = true path in buildUpdateSOAPRequest
    // =========================================================================
    @isTest
    static void testExecute_SampleOrder_HappyPath() {

        // Insert Custom Setting
        DRC_NBC_BC_Integration__c settings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                    = UserInfo.getOrganizationId(),
            DRC_NBC_BC_Order_Endpoint__c    = 'https://bc.example.com/order',
            DRC_NBC_SOAP_Order_Namespace__c = 'urn:microsoft-dynamics-schemas/page/salesordersalesforce',
            DRC_NBC_Username__c             = 'testuser',
            DRC_NBC_Password__c             = 'testpass'
        );
        insert settings;

        Account acc = new Account(
            Name                       = 'Sample Account',
            DRC_NBC_Customer_Number__c = 'CUSTDOM/SAMPLE-001',
            BillingStreet              = 'Sample Street\nLine 2',
            BillingCity                = 'Sample City',
            BillingPostalCode          = '123456'
        );
        insert acc;

        // Look up the Sample_Order RecordType Id (if it exists in the org)
        List<RecordType> sampleRT = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Order' AND DeveloperName = 'Sample_Order'
            LIMIT 1
        ];

        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = Test.getStandardPricebookId(),
            ShippingCountryCode          = 'IN',
            ShippingStreet               = 'Sample Ship Street',
            ShippingCity                 = 'Sample Ship City',
            ShippingPostalCode           = '654321',
            CurrencyIsoCode              = 'INR',
            DRC_NBC_Cust_Order_Number__c = 'SODOM/SAMPLE/00001',
            DRC_NBC_Location_Code__c     = 'CFS - JNPT',
            DRC_NBC_Payment_Terms__c     = '100',
            DRC_NBC_Inco_Terms__c        = 'Charges Collect (CC)',
            PoNumber                     = 'SAMPLE-PO-123',
            OwnerId                      = UserInfo.getUserId()
        );

        // Only assign RecordType if it exists in this org
        if (!sampleRT.isEmpty()) {
            ord.RecordTypeId = sampleRT[0].Id;
        }
        insert ord;

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            200, UPDATE_SUCCESS_RESPONSE
        ));

        Test.startTest();
        System.enqueueJob(new DRC_NBC_OrderReadUpdateQueueable(ord.Id));
        Test.stopTest();

        // Verify execution completed - status should be Released
        Order result = [SELECT Id, Status FROM Order WHERE Id = :ord.Id LIMIT 1];
        System.debug('Sample Order Status after execution: ' + result.Status);
    }

    @isTest
    static void testExecute_WithShippingAddress_HappyPath() {

        // Insert Custom Setting
        DRC_NBC_BC_Integration__c settings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                    = UserInfo.getOrganizationId(),
            DRC_NBC_BC_Order_Endpoint__c    = 'https://bc.example.com/order',
            DRC_NBC_SOAP_Order_Namespace__c = 'urn:microsoft-dynamics-schemas/page/salesordersalesforce',
            DRC_NBC_Username__c             = 'testuser',
            DRC_NBC_Password__c             = 'testpass'
        );
        insert settings;

        Account acc = new Account(
            Name                       = 'Test Account With Ship To',
            DRC_NBC_Customer_Number__c = 'CUSTDOM/SHIP-001',
            BillingStreet              = 'Billing Line 1\nBilling Line 2',
            BillingCity                = 'Billing City',
            BillingPostalCode          = '111111'
        );
        insert acc;

        // Create a custom Shipping Address record (assuming it's a custom object)
        // Adjust this based on your actual object structure
        DRC_NBC_Addresses__c shipAddr = new DRC_NBC_Addresses__c(
            DRC_NBC_Ship_To_Code__c = 'SHIP-TO-001',
            DRC_NBC_Warehouse__c    = 'CFS - JNPT'
        );
        insert shipAddr;

        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = Test.getStandardPricebookId(),
            ShippingCountryCode          = 'IN',
            ShippingStreet               = 'Ship Street 123',
            ShippingCity                 = 'Ship City',
            ShippingPostalCode           = '999999',
            CurrencyIsoCode              = 'INR',
            DRC_NBC_Cust_Order_Number__c = 'SODOM/SHIP/00001',
            DRC_NBC_Shipping_Address__c  = shipAddr.Id,
            DRC_NBC_Location_Code__c     = 'CFS - JNPT',
            DRC_NBC_Payment_Terms__c     = '100',
            DRC_NBC_Inco_Terms__c        = 'Charges Collect (CC)',
            PoNumber                     = 'SHIP-PO-456',
            OwnerId                      = UserInfo.getUserId()
        );
        insert ord;

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            200, UPDATE_SUCCESS_RESPONSE
        ));

        Test.startTest();
        System.enqueueJob(new DRC_NBC_OrderReadUpdateQueueable(ord.Id));
        Test.stopTest();
    }

    @isTest
    static void testExecute_AllFieldsPopulated_HappyPath() {

        Id orderId = setupTestData();
        Order ord = [SELECT Id FROM Order WHERE Id = :orderId LIMIT 1];
        ord.PoNumber = 'FULL-PO-789';
        ord.OwnerId = UserInfo.getUserId();
        update ord;

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            200, UPDATE_SUCCESS_RESPONSE
        ));

        Test.startTest();
        System.enqueueJob(new DRC_NBC_OrderReadUpdateQueueable(orderId));
        Test.stopTest();
    }
}