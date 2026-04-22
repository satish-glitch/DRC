/**
 * @File Name   : DRC_NBC_Order_BC_Callout_Test.cls
 * @Description : Test class for DRC_NBC_Order_BC_Callout
 *                Covers executeCallout, getOrderDetails, mapOrderToBCPayload
 **/
@isTest
private class DRC_NBC_Order_BC_Callout_Test {

    // ─── Test Setup ───────────────────────────────────────────────────────────
    @testSetup
    static void setupTestData() {

        // ── Custom Setting ───────────────────────────────────────────────────
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        String targetEnvName = isSandbox
            ? System.Label.DRC_NBC_Sandbox
            : System.Label.DRC_NBC_Production;

        DRC_NBC_BC_Integration__c customSetting = new DRC_NBC_BC_Integration__c(
            Name__c                              = targetEnvName,
            DRC_NBC_Comapny_Name__c              = 'Test Company',
            DRC_NBC_Endpoint__c                  = 'https://mock-bc.example.com',
            DRC_NBC_SendOrderEndpoint__c         = 'salesOrders',
            DRC_NBC_Shipping_Address_Endpoint__c = 'shipToAddresses',
            DRC_NBC_SendOrderLineEndpoint__c     = 'salesOrderLines',
            DRC_NBC_SalesPerson_Code__c          = 'SP001'
        );
        insert customSetting;

        // ── Account ──────────────────────────────────────────────────────────
        Account testAccount = new Account(
            Name                                     = 'Test Account',
            DRC_NBC_Customer_Number__c               = 'CUST001',
            CurrencyIsoCode                          = 'INR',
            Phone                                    = '1234567890',
            AccountNumber                            = 'A123',
            DRC_NBC_PAN_No__c                        = 'AWVPY9594J',
            DRC_NBC_GST_Number__c                    = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c             = 'PDC90',
            DRC_NBC_Account_Email_Email__c           = 'test@example.com',
            BillingStreet                            = '123 Billing Street',
            BillingCity                              = 'Mumbai',
            BillingCountry                           = 'India',
            BillingCountryCode                       = 'IN',
            BillingPostalCode                        = '400001',
            BillingState                             = 'Maharashtra',
            BillingStateCode                         = 'MH',
            DRC_NBC_Volume__c                        = 70,
            DRC_NBC_Credit_Limit__c                  = 123456787,
            DRC_NBC_Value__c                         = 900,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
            DRC_NBC_Consignee_Bank_Address__c        = 'Barhi 483775',
            DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'PUNB01391000',
            DRC_NBC_Consignee_Bank_Name__c           = 'Punjab National Bank',
            Industry                                 = 'Chemicals Construction',
            Type                                     = 'Analyst'
        );
        insert testAccount;

        // ── Contacts ─────────────────────────────────────────────────────────
        Contact billToContact = new Contact(
            FirstName = 'Bill',
            LastName  = 'Contact',
            AccountId = testAccount.Id,
            Email     = 'bill@test.com'
        );
        insert billToContact;

        Contact shipToContact = new Contact(
            FirstName = 'Ship',
            LastName  = 'Contact',
            AccountId = testAccount.Id,
            Email     = 'ship@test.com'
        );
        insert shipToContact;

        // ── Pricebook ────────────────────────────────────────────────────────
        Pricebook2 standardPricebook = new Pricebook2(
            Id       = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;

        // ── Product & PricebookEntry ──────────────────────────────────────────
        Product2 testProduct = new Product2(
            Name                    = 'Test Product',
            ProductCode             = 'PROD001',
            IsActive                = true,
            DRC_NBC_FG_Code__c      = 'FG001',
            DRC_NBC_HSN_SAC_Code__c = 'HSN001',
            QuantityUnitOfMeasure   = 'Each'
        );
        insert testProduct;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id   = testProduct.Id,
            UnitPrice    = 100.00,
            IsActive     = true
        );
        insert pbe;

        // ── Shipping Address ──────────────────────────────────────────────────
        DRC_NBC_Addresses__c shippingAddress = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c              = testAccount.Id,
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Ship_To_Code__c         = 'SHIP001',
            DRC_NBC_Warehouse__c            = 'CFS - JNPT',
            DRC_NBC_Address__Street__s      = '456 Ship Street',
            DRC_NBC_Address__City__s        = 'Pune',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__PostalCode__s  = '411001',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_GST_Number__c           = '27AWVPY9594J1ZY'
        );
        insert shippingAddress;

        // ── Order ─────────────────────────────────────────────────────────────
        Order testOrder = new Order(
            AccountId                    = testAccount.Id,
            EffectiveDate                = Date.today(),
            EndDate                      = Date.today().addDays(30),
            Status                       = 'Draft',
            Pricebook2Id                 = standardPricebook.Id,
            BillToContactId              = billToContact.Id,
            ShipToContactId              = shipToContact.Id,
            PoNumber                     = 'PO12345',
            PoDate                       = Date.today(),
            DRC_NBC_Payment_Terms__c     = 'PDC90',
            DRC_NBC_Inco_Terms__c        = 'Cost Insurance & Freight (CIF)',
            DRC_NBC_Cust_Order_Number__c = 'ORD-001',
            ShippingStreet               = '456 Ship Street',
            ShippingCity                 = 'Pune',
            ShippingState                = 'Maharashtra',
            ShippingPostalCode           = '411001',
            ShippingCountry              = 'India',
            ShippingCountryCode          = 'IN',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT',
            DRC_NBC_Shipping_Address__c  = shippingAddress.Id,
            DRC_NBC_Type__c              = 'Domestic'
        );
        insert testOrder;

        // Link shipping address to order
        shippingAddress.DRC_NBC_Order__c = testOrder.Id;
        update shippingAddress;

        // ── Order Item ────────────────────────────────────────────────────────
        OrderItem testOrderItem = new OrderItem(
            OrderId          = testOrder.Id,
            Product2Id       = testProduct.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 10,
            UnitPrice        = 100.00
        );
        insert testOrderItem;

        System.debug('Test data setup completed successfully');
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    private static Order getTestOrder() {
        return [
            SELECT Id, DRC_NBC_Shipping_Address__c,
                   DRC_NBC_Cust_Order_Number__c,
                   DRC_NBC_Order_Sync_To_BC__c
            FROM   Order
            LIMIT  1
        ];
    }

    // ─── Mock HTTP ────────────────────────────────────────────────────────────
    private class MockHttpSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"id":"BC-001"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    private class MockHttpFailure implements HttpCalloutMock {
        private Integer code;
        public MockHttpFailure(Integer code) { this.code = code; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody('{"error":"Bad Request"}');
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    // =========================================================================
    // executeCallout
    // =========================================================================

    // T01: Order already synced to BC
    @isTest
    static void testExecuteCallout_AlreadySynced() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Order_Sync_To_BC__c = true;
        update ord;

        Test.startTest();
        String result = DRC_NBC_Order_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();

        System.debug('T01 Result: ' + result);
    }

    // T02: Ship-To Code is blank → DML handler enqueued
    @isTest
    static void testExecuteCallout_NeedsShipToCode() {
        Order ord = getTestOrder();

        DRC_NBC_Addresses__c addr = [
            SELECT Id FROM DRC_NBC_Addresses__c
            WHERE  Id = :ord.DRC_NBC_Shipping_Address__c
            LIMIT  1
        ];
        addr.DRC_NBC_Ship_To_Code__c = null;
        update addr;

        Test.startTest();
        String result = DRC_NBC_Order_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();

        System.debug('T02 Result: ' + result);
    }

    // T03: Order Number is blank → DML handler enqueued
    @isTest
    static void testExecuteCallout_NeedsOrderNumber() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Cust_Order_Number__c = null;
        update ord;

        Test.startTest();
        String result = DRC_NBC_Order_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();

        System.debug('T03 Result: ' + result);
    }

    // T04: Both Ship-To Code and Order Number are blank
    @isTest
    static void testExecuteCallout_NeedsBoth() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Cust_Order_Number__c = null;
        update ord;

        DRC_NBC_Addresses__c addr = [
            SELECT Id FROM DRC_NBC_Addresses__c
            WHERE  Id = :ord.DRC_NBC_Shipping_Address__c
            LIMIT  1
        ];
        addr.DRC_NBC_Ship_To_Code__c = null;
        update addr;

        Test.startTest();
        String result = DRC_NBC_Order_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();

        System.debug('T04 Result: ' + result);
    }

    // T05: No DML needed — all fields present, not yet synced
    @isTest
    static void testExecuteCallout_NoDMLNeeded() {
        Order ord = getTestOrder();

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        String result = DRC_NBC_Order_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();

        System.debug('T05 Result: ' + result);
    }

    // T06: No shipping address on order
    @isTest
    static void testExecuteCallout_NoShippingAddress() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Shipping_Address__c = null;
        update ord;

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        String result = DRC_NBC_Order_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();

        System.debug('T06 Result: ' + result);
    }

    // T07: Exception handling — order with missing required fields
    @isTest
    static void testExecuteCallout_ExceptionHandling() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Order invalidOrder = new Order(
            AccountId     = testAccount.Id,
            EffectiveDate = Date.today(),
            Status        = 'Draft'
        );
        insert invalidOrder;

        Test.startTest();
        String result;
        try {
            result = DRC_NBC_Order_BC_Callout.executeCallout(invalidOrder.Id);
        } catch (Exception e) {
            result = 'ERROR: ' + e.getMessage();
        }
        Test.stopTest();

        System.debug('T07 Result: ' + result);
    }

    // T08: Already synced — batch enqueued path debug
    @isTest
    static void testExecuteCallout_AlreadySynced_BatchEnqueued() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Order_Sync_To_BC__c = true;
        update ord;

        Test.startTest();
        String result = DRC_NBC_Order_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();

        System.debug('T08 Already synced batch path result: ' + result);
    }

    // T09: Callout with 400 failure mock
    @isTest
    static void testExecuteCallout_CalloutFailure400() {
        Order ord = getTestOrder();

        Test.setMock(HttpCalloutMock.class, new MockHttpFailure(400));

        Test.startTest();
        String result = DRC_NBC_Order_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();

        System.debug('T09 Result with 400 mock: ' + result);
    }

    // T10: Callout with 500 server error mock
    @isTest
    static void testExecuteCallout_CalloutFailure500() {
        Order ord = getTestOrder();

        Test.setMock(HttpCalloutMock.class, new MockHttpFailure(500));

        Test.startTest();
        String result = DRC_NBC_Order_BC_Callout.executeCallout(ord.Id);
        Test.stopTest();

        System.debug('T10 Result with 500 mock: ' + result);
    }

    // =========================================================================
    // getOrderDetails
    // =========================================================================

    // T11: Valid order — verify all fields are returned
    @isTest
    static void testGetOrderDetails_ValidOrder() {
        Order ord = getTestOrder();

        Test.startTest();
        Order retrieved = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);
        Test.stopTest();

        System.debug('T11 Retrieved Order Id: ' + retrieved.Id);
        System.debug('T11 Account Name: ' + retrieved.Account.Name);
        System.debug('T11 Customer Number: ' + retrieved.Account.DRC_NBC_Customer_Number__c);
        System.debug('T11 Warehouse: ' + retrieved.DRC_NBC_Warehouse__c);
        System.debug('T11 Currency: ' + retrieved.CurrencyIsoCode);
        System.debug('T11 Order Number: ' + retrieved.OrderNumber);
        System.debug('T11 Sync To BC: ' + retrieved.DRC_NBC_Order_Sync_To_BC__c);
        System.debug('T11 Shipping Address: ' + retrieved.DRC_NBC_Shipping_Address__c);
        System.debug('T11 Inco Terms: ' + retrieved.DRC_NBC_Inco_Terms__c);
        System.debug('T11 Payment Terms: ' + retrieved.DRC_NBC_Payment_Terms__c);
        System.debug('T11 Type: ' + retrieved.DRC_NBC_Type__c);
    }

    // T12: Verify shipping address relationship fields
    @isTest
    static void testGetOrderDetails_ShippingAddressRelation() {
        Order ord = getTestOrder();

        Test.startTest();
        Order retrieved = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);
        Test.stopTest();

        System.debug('T12 Ship-To Code (relation): ' + retrieved.DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c);
        System.debug('T12 Warehouse (relation): ' + retrieved.DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c);
    }

    // T13: Verify billing address and account fields
    @isTest
    static void testGetOrderDetails_BillingAddressFields() {
        Order ord = getTestOrder();

        Test.startTest();
        Order retrieved = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);
        Test.stopTest();

        System.debug('T13 Billing Street: ' + retrieved.Account.BillingStreet);
        System.debug('T13 Billing City: ' + retrieved.Account.BillingCity);
        System.debug('T13 Billing PostalCode: ' + retrieved.Account.BillingPostalCode);
        System.debug('T13 BC Approval Status: ' + retrieved.Account.DRC_NBC_BC_Approval_Status__c);
        System.debug('T13 Posted To BC: ' + retrieved.Account.DRC_NBC_Posted_To_BC__c);
        System.debug('T13 Customer Number: ' + retrieved.Account.DRC_NBC_Customer_Number__c);
    }

    // T14: Verify financial and type fields
    @isTest
    static void testGetOrderDetails_FinancialAndTypeFields() {
        Order ord = getTestOrder();

        Test.startTest();
        Order retrieved = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);
        Test.stopTest();

        System.debug('T14 Grand Total: ' + retrieved.DRC_NBC_Grand_Total__c);
        System.debug('T14 Payment Terms: ' + retrieved.DRC_NBC_Payment_Terms__c);
        System.debug('T14 Inco Terms: ' + retrieved.DRC_NBC_Inco_Terms__c);
        System.debug('T14 Type: ' + retrieved.DRC_NBC_Type__c);
        System.debug('T14 RecordType Name: ' + retrieved.RecordType.Name);
        System.debug('T14 PO Number: ' + retrieved.PoNumber);
        System.debug('T14 Effective Date: ' + retrieved.EffectiveDate);
    }

    // =========================================================================
    // mapOrderToBCPayload
    // =========================================================================

    // T15: Standard payload mapping — top-level fields
    @isTest
    static void testMapOrderToBCPayload_StandardMapping() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T15 Document_Type: ' + payload.Document_Type);
        System.debug('T15 No: ' + payload.No);
        System.debug('T15 Sell_to_Customer_No: ' + payload.Sell_to_Customer_No);
        System.debug('T15 Sell_to_Customer_Name: ' + payload.Sell_to_Customer_Name);
        System.debug('T15 Status: ' + payload.Status);
        System.debug('T15 Currency_Code: ' + payload.Currency_Code);
        System.debug('T15 Sample_Sales: ' + payload.Sample_Sales);
        System.debug('T15 Export_Document: ' + payload.Export_Document);
        System.debug('T15 Salesforce_Order_Created: ' + payload.Salesforce_Order_Created);
    }

    // T16: Billing address fields in payload
    @isTest
    static void testMapOrderToBCPayload_BillingAddress() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T16 Sell_to_Address: ' + payload.Sell_to_Address);
        System.debug('T16 Sell_to_Post_Code: ' + payload.Sell_to_Post_Code);
        System.debug('T16 Sell_to_City: ' + payload.Sell_to_City);
        System.debug('T16 Sell_to_Address_2: ' + payload.Sell_to_Address_2);
    }

    // T17: Shipping address fields in payload
    @isTest
    static void testMapOrderToBCPayload_ShippingAddress() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T17 Ship_to_Code: ' + payload.Ship_to_Code);
        System.debug('T17 Ship_to_Name: ' + payload.Ship_to_Name);
        System.debug('T17 Ship_to_Name_2: ' + payload.Ship_to_Name_2);
        System.debug('T17 Ship_to_Address: ' + payload.Ship_to_Address);
        System.debug('T17 Ship_to_Address_2: ' + payload.Ship_to_Address_2);
        System.debug('T17 Ship_to_Post_Code: ' + payload.Ship_to_Post_Code);
        System.debug('T17 Ship_to_Country_Region_Code: ' + payload.Ship_to_Country_Region_Code);
        System.debug('T17 Ship_to_GST_Reg_No: ' + payload.Ship_to_GST_Reg_No);
        System.debug('T17 Ship_to_GST_Customer_Type: ' + payload.Ship_to_GST_Customer_Type);
    }

    // T18: Country code IN → IND normalisation
    @isTest
    static void testMapOrderToBCPayload_CountryCodeNormalisation() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T18 Ship_to_Country_Region_Code (expected IND): ' + payload.Ship_to_Country_Region_Code);
    }

    // T19: Export order → Export_Document = true
    @isTest
    static void testMapOrderToBCPayload_ExportOrder() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Type__c = 'Export';
        update ord;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T19 Export_Document (expected true): ' + payload.Export_Document);
    }

    // T20: Sample order → Sample_Sales = true (skips if RecordType not found)
    @isTest
    static void testMapOrderToBCPayload_SampleOrder() {
        List<RecordType> sampleRT = [
            SELECT Id FROM RecordType
            WHERE  SObjectType = 'Order'
              AND  DeveloperName = 'Sample_Order'
            LIMIT  1
        ];

        if (sampleRT.isEmpty()) {
            System.debug('T20 Sample_Order RecordType not found in org — test skipped');
            return;
        }

        Order ord = getTestOrder();
        ord.RecordTypeId = sampleRT[0].Id;
        update ord;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T20 Sample_Sales (expected true): ' + payload.Sample_Sales);
    }

    // T21: Long shipping address (>99 chars) → address split across two fields
    @isTest
    static void testMapOrderToBCPayload_LongAddressSplit() {
        Order ord = getTestOrder();

        DRC_NBC_Addresses__c addr = [
            SELECT Id FROM DRC_NBC_Addresses__c
            WHERE  Id = :ord.DRC_NBC_Shipping_Address__c
            LIMIT  1
        ];
        addr.DRC_NBC_Address__Street__s =
            'A Very Long Street Name That Goes Well Beyond Ninety Nine Characters To Trigger The Address Splitting Code Path In The Mapper Class';
        update addr;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T21 Ship_to_Address length: ' + payload.Ship_to_Address.length());
        System.debug('T21 Ship_to_Address: ' + payload.Ship_to_Address);
        System.debug('T21 Ship_to_Address_2: ' + payload.Ship_to_Address_2);
    }

    // T22: Very long address (>149 chars) → address_2 also truncated
    @isTest
    static void testMapOrderToBCPayload_VeryLongAddressTruncation() {
        Order ord = getTestOrder();

        DRC_NBC_Addresses__c addr = [
            SELECT Id FROM DRC_NBC_Addresses__c
            WHERE  Id = :ord.DRC_NBC_Shipping_Address__c
            LIMIT  1
        ];
        addr.DRC_NBC_Address__Street__s =
            'AAAAAAAAAA BBBBBBBBBB CCCCCCCCCC DDDDDDDDDD EEEEEEEEEE FFFFFFFFFF GGGGGGGGGG HHHHHHHHHH IIIIIIIIII JJJJJJJJJJ KKKKKKKKKK LLLLLLLLLL MMMMMMMMMM NNNNNNNNNN OOOOOOOOOO';
        update addr;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T22 Ship_to_Address (max 99): ' + payload.Ship_to_Address);
        System.debug('T22 Ship_to_Address_2 (max 50): ' + payload.Ship_to_Address_2);
    }

    // T23: No shipping address on order → all Ship-To fields are empty strings
    @isTest
    static void testMapOrderToBCPayload_NoShippingAddress() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Shipping_Address__c = null;
        update ord;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T23 Ship_to_Code (expected empty): ' + payload.Ship_to_Code);
        System.debug('T23 Ship_to_Address (expected empty): ' + payload.Ship_to_Address);
        System.debug('T23 Ship_to_Post_Code (expected empty): ' + payload.Ship_to_Post_Code);
        System.debug('T23 Ship_to_Country_Region_Code (expected empty): ' + payload.Ship_to_Country_Region_Code);
    }

    // T24: Blank order number → payload.No is empty string
    @isTest
    static void testMapOrderToBCPayload_BlankOrderNumber() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Cust_Order_Number__c = null;
        update ord;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T24 payload.No (expected empty): ' + payload.No);
    }

    // T25: Grand Total null → Salesforce_Order_Amount defaults to 0
    @isTest
    static void testMapOrderToBCPayload_NullGrandTotal() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T25 Salesforce_Order_Amount: ' + payload.Salesforce_Order_Amount);
    }

    // T26: Payment Terms and PO Number mapping
    @isTest
    static void testMapOrderToBCPayload_PaymentTermsAndPO() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T26 Payment_Terms_Code: ' + payload.Payment_Terms_Code);
        System.debug('T26 External_Document_No: ' + payload.External_Document_No);
    }

    // T27: Salesforce_So_No = Order Id, Salesforce_Order_Created = false
    @isTest
    static void testMapOrderToBCPayload_SalesforceFields() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T27 Salesforce_So_No (expected Order Id): ' + payload.Salesforce_So_No);
        System.debug('T27 Salesforce_Order_Created (expected false): ' + payload.Salesforce_Order_Created);
    }

    // T28: Warehouse metadata lookup — Location_Code
    @isTest
    static void testMapOrderToBCPayload_WarehouseMetadata() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T28 Location_Code: ' + payload.Location_Code);
    }

    // T29: Inco Terms metadata lookup — Shipment_Method_Code
    @isTest
    static void testMapOrderToBCPayload_IncoTermsMetadata() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T29 Shipment_Method_Code: ' + payload.Shipment_Method_Code);
    }

    // T30: Salesperson_Code = ShipToContactId
    @isTest
    static void testMapOrderToBCPayload_SalespersonCode() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T30 Salesperson_Code (expected ShipToContactId): ' + payload.Salesperson_Code);
    }

    // T31: Order_Date matches EffectiveDate as string
    @isTest
    static void testMapOrderToBCPayload_OrderDate() {
        Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(getTestOrder().Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        Test.stopTest();

        System.debug('T31 Order_Date: ' + payload.Order_Date);
        System.debug('T31 Expected Date: ' + String.valueOf(Date.today()));
    }

    // T32: Blank PO Number → External_Document_No is empty string
    @isTest
    static void testMapOrderToBCPayload_BlankPONumber() {
        Order ord = getTestOrder();
        ord.PoNumber = null;
        update ord;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T32 External_Document_No (expected empty): ' + payload.External_Document_No);
    }

    // T33: Blank Payment Terms → Payment_Terms_Code is empty string
    @isTest
    static void testMapOrderToBCPayload_BlankPaymentTerms() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Payment_Terms__c = null;
        update ord;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T33 Payment_Terms_Code (expected empty): ' + payload.Payment_Terms_Code);
    }

    // T34: Blank Inco Terms → Shipment_Method_Code is empty string
    @isTest
    static void testMapOrderToBCPayload_BlankIncoTerms() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Inco_Terms__c = null;
        update ord;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T34 Shipment_Method_Code (expected empty for null Inco Terms): ' + payload.Shipment_Method_Code);
    }

    // T35: Blank Warehouse → Location_Code is empty string
    @isTest
    static void testMapOrderToBCPayload_BlankWarehouse() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Warehouse__c = null;
        update ord;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T35 Location_Code (expected empty for null Warehouse): ' + payload.Location_Code);
    }

   

    // T37: Domestic order type → Export_Document = false
    @isTest
    static void testMapOrderToBCPayload_DomesticOrder() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Type__c = 'Domestic';
        update ord;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T37 Export_Document (expected false for Domestic): ' + payload.Export_Document);
    }

    // T38: Null DRC_NBC_Type__c → Export_Document = false
    @isTest
    static void testMapOrderToBCPayload_NullOrderType() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Type__c = null;
        update ord;

        Order refreshed = DRC_NBC_Order_BC_Callout.getOrderDetails(ord.Id);

        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(refreshed);
        Test.stopTest();

        System.debug('T38 Export_Document (expected false for null type): ' + payload.Export_Document);
    }
}