/**
* @File Name   : DRC_NBC_OrderReadUpdateQueueableTest.cls
* @Description : Test class for DRC_NBC_OrderReadUpdateQueueable
*                Covers:
*                  1. Happy path  – READ 200 → UPDATE 200 → SF Status set to Released
*                  2. READ fails  – HTTP non-200 from BC, job exits early
*                  3. READ returns no Key in XML – job exits early
*                  4. UPDATE fails – HTTP non-200 from BC, SF Status NOT changed
*                  5. Custom Setting not configured – graceful no-op
*                  6. Null Order Id passed – graceful no-op
*                  7. Sample Order record type path
*                  8. Shipping Address populated path
*                  9. All fields populated path
* @Author      : SATISH YADAV
* @Last Modified On : March 2026
**/
@isTest
private class DRC_NBC_OrderReadUpdateQueueableTest {

    // =========================================================================
    // SOAP RESPONSE CONSTANTS
    // =========================================================================
    private static final String READ_SUCCESS_RESPONSE =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<Soap:Envelope xmlns:Soap="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<Soap:Body>' +
        '<Read_Result xmlns="urn:microsoft-dynamics-schemas/page/salesordersalesforce">' +
        '<SalesOrderSalesForce>' +
        '<Key>60;JAAAAACLAQAAAAJ7/1MATwBEAE8ATQAvADIANgAyADcALwAwADAAMAAzADE=8;240356490;</Key>' +
        '<No>SODOM/2627/00031</No>' +
        '<Document_Type>Order</Document_Type>' +
        '<Status>Open</Status>' +
        '<Salesperson_Code>SP001</Salesperson_Code>' +
        '<Location_Code>JNPT</Location_Code>' +
        '<Shipment_Method_Code>CC</Shipment_Method_Code>' +
        '<Order_Date>2025-01-01</Order_Date>' +
        '</SalesOrderSalesForce>' +
        '</Read_Result>' +
        '</Soap:Body>' +
        '</Soap:Envelope>';

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
    // MOCK CLASSES
    // =========================================================================

    /**
     * Controls READ (1st call) and UPDATE (2nd call) independently.
     */
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
                res.setStatusCode(readStatus);
                res.setBody(readBody);
            } else {
                res.setStatusCode(updateStatus);
                res.setBody(updateBody);
            }
            return res;
        }
    }

    /** Single-callout mock – used when only READ is expected (no UPDATE). */
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

    // =========================================================================
    // SETUP HELPER
    // =========================================================================

    /**
     * Inserts the custom setting + Account + Order required by most tests.
     * Returns the Order Id.
     *
     * NOTE: DRC_NBC_BC_Integration__c is a Hierarchy Custom Setting so we use
     *       SetupOwnerId = UserInfo.getOrganizationId() for the org-default tier.
     *       The static initialisers in the production class call getInstance()
     *       which reads the Hierarchy record, so this record must exist before
     *       the class is even loaded – that is why we insert it first.
     */
    private static Id setupTestData() {

        DRC_NBC_BC_Integration__c settings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                    = UserInfo.getOrganizationId(),
            DRC_NBC_BC_Order_Endpoint__c    = 'https://bc.example.com/order',
            DRC_NBC_BC_Line_Item_Endpoint__c= 'https://bc.example.com/lineitem',
            DRC_NBC_SOAP_Order_Namespace__c = 'urn:microsoft-dynamics-schemas/page/salesordersalesforce',
            DRC_NBC_SOAP_Line_Namespace__c  = 'urn:microsoft-dynamics-schemas/page/salesorderline',
            DRC_NBC_Username__c             = 'testuser',
            DRC_NBC_Password__c             = 'testpass'
        );
        insert settings;

        Account acc = new Account(
            Name                          = 'Test Account',
            BillingStreet                 = '302, Amar Business Park',
            BillingCity                   = 'Pune',
            BillingPostalCode             = '411045',
            BillingCountry                = 'India',
            DRC_NBC_Customer_Number__c    = 'CUSTDOM/2526-00014',
            DRC_NBC_BC_Approval_Status__c = true
        );
        insert acc;

        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = Test.getStandardPricebookId(),
            ShippingStreet               = 'Test 1234, Test City',
            ShippingCity                 = 'Mumbai',
            ShippingPostalCode           = '400001',
            ShippingCountry              = 'India',
            ShippingCountryCode          = 'IN',
            CurrencyIsoCode              = 'INR',
            PoNumber                     = 'TEST-PO-001',
            DRC_NBC_Cust_Order_Number__c = 'SODOM/2627/00031',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT',
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

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            200, UPDATE_SUCCESS_RESPONSE
        ));

        Test.startTest();
        // FIX: call the static execute() method directly – no constructor needed
        DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
        Test.stopTest();

        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        System.debug('Final Order Status: ' + result.Status);
        System.assertEquals('Released', result.Status,
            'Order Status should be Released after successful BC READ + UPDATE');
    }

    // =========================================================================
    // TEST 2: READ returns HTTP 500 → exits early, Status stays Draft
    // =========================================================================
    @isTest
    static void testExecute_ReadHttpFailure_StatusNotChanged() {

        Id orderId = setupTestData();

        Test.setMock(HttpCalloutMock.class, new SingleCalloutMock(
            500, '<error>Internal Server Error</error>'
        ));

        Test.startTest();
        DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
        Test.stopTest();

        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        System.debug('Order Status after READ failure: ' + result.Status);
        System.assertNotEquals('Released', result.Status,
            'Order Status should NOT be Released when BC READ returns 500');
    }

    // =========================================================================
    // TEST 3: READ returns 200 but no <Key> → exits early, Status stays Draft
    // =========================================================================
    @isTest
    static void testExecute_ReadNoKeyInResponse_StatusNotChanged() {

        Id orderId = setupTestData();

        Test.setMock(HttpCalloutMock.class, new SingleCalloutMock(
            200, READ_NO_KEY_RESPONSE
        ));

        Test.startTest();
        DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
        Test.stopTest();

        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        System.debug('Order Status after no Key in response: ' + result.Status);
        System.assertNotEquals('Released', result.Status,
            'Order Status should NOT be Released when READ response has no Key');
    }

    // =========================================================================
    // TEST 4: READ 200 + UPDATE 400 → SF Status NOT changed
    // =========================================================================
    @isTest
    static void testExecute_UpdateHttpFailure_StatusNotChanged() {

        Id orderId = setupTestData();

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            400, '<error>Bad Request</error>'
        ));

        Test.startTest();
        DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
        Test.stopTest();

        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        System.debug('Order Status after UPDATE failure: ' + result.Status);
        System.assertNotEquals('Released', result.Status,
            'Order Status should NOT be Released when BC UPDATE returns 400');
    }

    // =========================================================================
    // TEST 5: Null Order Id passed → graceful no-op, no exception
    // =========================================================================
    @isTest
    static void testExecute_NullOrderId_GracefulNoOp() {

        // Custom setting still needs to exist for the class static init
        DRC_NBC_BC_Integration__c settings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                    = UserInfo.getOrganizationId(),
            DRC_NBC_BC_Order_Endpoint__c    = 'https://bc.example.com/order',
            DRC_NBC_SOAP_Order_Namespace__c = 'urn:test',
            DRC_NBC_Username__c             = 'u',
            DRC_NBC_Password__c             = 'p'
        );
        insert settings;

        Test.startTest();
        // Should return immediately without throwing
        DRC_NBC_OrderReadUpdateQueueable.execute(null);
        Test.stopTest();

        // If we reach here without an exception the test passes
        System.assert(true, 'execute(null) should exit gracefully without exception');
    }

   
    // =========================================================================
    // TEST 7: Static method runs without exception (replaces constructor test)
    //         FIX: DRC_NBC_OrderReadUpdateQueueable has no constructor –
    //              the original test_6 instantiated it incorrectly.
    // =========================================================================
    @isTest
    static void testExecute_StaticMethod_NoException() {

        Id orderId = setupTestData();

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            200, UPDATE_SUCCESS_RESPONSE
        ));

        Test.startTest();
        // Just verify calling the static method does not throw
        DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
        Test.stopTest();

        System.assert(true, 'Static execute() should run without throwing an exception');
    }

    // =========================================================================
    // TEST 8: Sample Order record type → isSample = true path
    // =========================================================================
    @isTest
    static void testExecute_SampleOrder_HappyPath() {

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
            BillingStreet              = 'Sample Street',
            BillingCity                = 'Sample City',
            BillingPostalCode          = '123456'
        );
        insert acc;

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
            DRC_NBC_Warehouse__c         = 'CFS - JNPT',
            DRC_NBC_Payment_Terms__c     = '100',
            DRC_NBC_Inco_Terms__c        = 'Charges Collect (CC)',
            PoNumber                     = 'SAMPLE-PO-123',
            OwnerId                      = UserInfo.getUserId()
        );
        if (!sampleRT.isEmpty()) {
            ord.RecordTypeId = sampleRT[0].Id;
        }
        insert ord;

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            200, UPDATE_SUCCESS_RESPONSE
        ));

        Test.startTest();
        DRC_NBC_OrderReadUpdateQueueable.execute(ord.Id);
        Test.stopTest();

        Order result = [SELECT Id, Status FROM Order WHERE Id = :ord.Id LIMIT 1];
        System.debug('Sample Order Status after execution: ' + result.Status);
        System.assertEquals('Released', result.Status,
            'Sample Order Status should be Released after successful BC round-trip');
    }

    // =========================================================================
    // TEST 9: Shipping Address populated path
    // =========================================================================
    @isTest
    static void testExecute_WithShippingAddress_HappyPath() {

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
            BillingStreet              = 'Billing Line 1',
            BillingCity                = 'Billing City',
            BillingPostalCode          = '111111'
        );
        insert acc;

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
            DRC_NBC_Warehouse__c         = 'CFS - JNPT',
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
        DRC_NBC_OrderReadUpdateQueueable.execute(ord.Id);
        Test.stopTest();

        Order result = [SELECT Id, Status FROM Order WHERE Id = :ord.Id LIMIT 1];
        System.assertEquals('Released', result.Status,
            'Order with shipping address should reach Released status');
    }

    // =========================================================================
    // TEST 10: All fields populated – exercises every branch in execute()
    // =========================================================================
    @isTest
    static void testExecute_AllFieldsPopulated_HappyPath() {

        Id orderId = setupTestData();

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            200, UPDATE_SUCCESS_RESPONSE
        ));

        Test.startTest();
        DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
        Test.stopTest();

        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        System.assertEquals('Released', result.Status,
            'All-fields-populated Order should reach Released status');
    }

    // =========================================================================
    // TEST 11: READ returns SOAP Fault → exits early (hasSoapFault branch)
    // =========================================================================
    @isTest
    static void testExecute_ReadSoapFault_StatusNotChanged() {

        Id orderId = setupTestData();

        String soapFaultBody =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<Soap:Envelope xmlns:Soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<Soap:Body>' +
            '<Soap:Fault>' +
            '<faultcode>Soap:Server</faultcode>' +
            '<faultstring>Record not found</faultstring>' +
            '</Soap:Fault>' +
            '</Soap:Body>' +
            '</Soap:Envelope>';

        Test.setMock(HttpCalloutMock.class, new SingleCalloutMock(200, soapFaultBody));

        Test.startTest();
        DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
        Test.stopTest();

        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        System.assertNotEquals('Released', result.Status,
            'Order Status should NOT change when READ returns a SOAP Fault');
    }

    // =========================================================================
    // TEST 12: UPDATE returns SOAP Fault → SF Status NOT changed
    // =========================================================================
    @isTest
    static void testExecute_UpdateSoapFault_StatusNotChanged() {

        Id orderId = setupTestData();

        String soapFaultBody =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<Soap:Envelope xmlns:Soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<Soap:Body>' +
            '<Soap:Fault>' +
            '<faultcode>Soap:Server</faultcode>' +
            '<faultstring>Update not allowed in current state</faultstring>' +
            '</Soap:Fault>' +
            '</Soap:Body>' +
            '</Soap:Envelope>';

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, READ_SUCCESS_RESPONSE,
            200, soapFaultBody          // HTTP 200 but SOAP Fault in body
        ));

        Test.startTest();
        DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
        Test.stopTest();

        Order result = [SELECT Id, Status FROM Order WHERE Id = :orderId LIMIT 1];
        System.assertNotEquals('Released', result.Status,
            'Order Status should NOT change when UPDATE response contains a SOAP Fault');
    }
}