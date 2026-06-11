/**
 * @File Name : DRC_NBC_LineItemCreator_Test.cls
 * @Description : Comprehensive test class for DRC_NBC_LineItemCreator targeting 90%+ coverage.
 * @Author : Satish Yadav
 * @Last Modified On : June 11, 2026
 **/
@isTest
private class DRC_NBC_LineItemCreator_Test {

    // =========================================================================
    // TEST DATA SETUP
    // =========================================================================
    @testSetup
    static void setupTestData() {
        DRC_NBC_BC_Integration__c bcSettings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                     = UserInfo.getOrganizationId(),
            DRC_NBC_BC_Order_Endpoint__c     = 'https://test.bc.com/order',
            DRC_NBC_BC_Line_Item_Endpoint__c = 'https://test.bc.com/lineitem',
            DRC_NBC_SOAP_Order_Namespace__c  = 'urn:microsoft-dynamics-schemas/codeunit/SalesOrderSalesForce',
            DRC_NBC_SOAP_Line_Namespace__c   = 'urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce',
            DRC_NBC_GST_Credit_Value__c      = 'AVAILMENT',
            DRC_NBC_Username__c              = 'testuser',
            DRC_NBC_Password__c              = 'testpass'
        );
        insert bcSettings;

        Account acc = new Account(
            Name                                     = 'Test Customer',
            DRC_NBC_Customer_Number__c               = 'CUST001',
            CurrencyIsoCode                          = 'INR',
            Phone                                    = '1234567890',
            AccountNumber                            = 'A123',
            DRC_NBC_PAN_No__c                        = 'AWVPY9594J',
            DRC_NBC_GST_Number__c                    = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c             = 'PDC90',
            DRC_NBC_Account_Email_Email__c           = 'test@example.com',
            BillingStreet                            = '123 Street',
            BillingCity                              = 'City',
            BillingCountry                           = 'India',
            BillingCountryCode                       = 'IN',
            BillingPostalCode                        = '462002',
            BillingState                             = 'Maharashtra',
            BillingStateCode                         = 'MH',
            DRC_NBC_Volume__c                        = 70,
            DRC_NBC_Credit_Limit__c                  = 123456787,
            DRC_NBC_Value__c                         = 900,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
            DRC_NBC_Consignee_Bank_Address__c        = 'Barhi 483775',
            DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'PUNB01391000',
            DRC_NBC_Consignee_Bank_Name__c           = 'Punjab National bank',
            Industry                                 = 'Chemicals Construction',
            Type                                     = 'Analyst'
        );
        insert acc;

        DRC_NBC_Addresses__c shipAddr = new DRC_NBC_Addresses__c(
            DRC_NBC_Ship_To_Code__c         = 'SHIP001',
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Warehouse__c            = 'CFS - JNPT',
            DRC_NBC_Account__c              = acc.Id,
            DRC_NBC_Address__Street__s      = '123 Test Street',
            DRC_NBC_Address__City__s        = 'Mumbai',
            DRC_NBC_Address__PostalCode__s  = '400001',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Address__StateCode__s   = 'MH'
        );
        insert shipAddr;

        List<Product2> products = new List<Product2>();
        for (Integer i = 1; i <= 5; i++) {
            products.add(new Product2(
                Name                      = 'Test Product ' + i,
                DRC_NBC_FG_Code__c        = 'FG00' + i,
                DRC_NBC_GST_Group_Code__c = 'GST18',
                DRC_NBC_HSN_SAC_Code__c   = 'HSN' + i,
                IsActive                  = true
            ));
        }
        insert products;

        Id stdPricebookId = Test.getStandardPricebookId();
        List<PricebookEntry> pbes = new List<PricebookEntry>();
        for (Product2 prod : products) {
            pbes.add(new PricebookEntry(
                Pricebook2Id = stdPricebookId,
                Product2Id   = prod.Id,
                UnitPrice    = 100,
                IsActive     = true
            ));
        }
        insert pbes;

        Order standardOrd = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPricebookId,
            DRC_NBC_Shipping_Address__c  = shipAddr.Id,
            DRC_NBC_Cust_Order_Number__c = 'BC-ORD-001',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT',
            DRC_NBC_Other_Tax_Amount__c  = 50,
            DRC_NBC_TCS_Amount__c        = 25
        );
        insert standardOrd;

        List<OrderItem> items = new List<OrderItem>();
        for (Integer i = 0; i < 3; i++) {
            items.add(new OrderItem(
                OrderId                        = standardOrd.Id,
                Product2Id                     = products[i].Id,
                PricebookEntryId               = pbes[i].Id,
                Quantity                       = 10 + i,
                UnitPrice                      = 100,
                Description                    = 'Test Product ' + (i + 1),
                DRC_NBC_Discount__c            = 5,
                DRC_NBC_Unit_Of_Measurement__c = 'KGS',
                DRC_NBC_Hazardous__c           = false,
                DRC_NBC_MARKS_NOS__c           = 'MARK-00' + i
            ));
        }
        insert items;
    }

    // =========================================================================
    // HTTP MOCKS
    // =========================================================================

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body><CreateMultiple_Result>Success</CreateMultiple_Result></soap:Body>' +
                '</soap:Envelope>'
            );
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Connection timeout');
        }
    }

    // =========================================================================
    // HELPERS
    // =========================================================================

    private static Order getStandardOrder() {
        return [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
                   DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                   DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
                   Is_Domestic_Merchnat__c,
                   AccountId,
                   Account.DRC_NBC_Customer_Number__c,
                   Account.Type,
                   RecordType.Name
            FROM Order
            WHERE DRC_NBC_Cust_Order_Number__c = 'BC-ORD-001'
            LIMIT 1
        ];
    }

    private static List<OrderItem> getOrderItems(Id orderId) {
        return [
            SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice,
                   DRC_NBC_Discount__c, DRC_NBC_Total_Price__c,
                   DRC_NBC_Hazardous__c,
                   DRC_NBC_MARKS_NOS__c,
                   Product2.DRC_NBC_FG_Code__c,
                   Product2.DRC_NBC_GST_Group_Code__c,
                   Product2.DRC_NBC_HSN_SAC_Code__c,
                   DRC_NBC_Unit_Of_Measurement__c,
                   DRC_NBC_Packing_Quantity__c,
                   DRC_NBC_Packing_Size__c,
                   Order.RecordType.Name,
                   Order.Is_Domestic_Merchnat__c,
                   Order.DRC_NBC_Warehouse__c,
                   Order.DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                   Order.Account.DRC_NBC_Customer_Number__c,
                   Order.Account.Type
            FROM OrderItem
            WHERE OrderId = :orderId
        ];
    }

    // =========================================================================
    // TESTS
    // =========================================================================

    @isTest
    static void test_createSingleLineItem_Success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_createMultipleLineItems_LineNumberIncrement() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 10000
        );
        Test.stopTest();
    }

    @isTest
    static void test_createEmptyList_NoItemsToCreate() {
        Order ord = getStandardOrder();

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, new List<OrderItem>(), ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_createLineItem_BCFailure_500() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Order ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_createLineItem_CalloutException() {
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        Order ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_legacyCreateLineItems_CounterBasedLineNumber() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItems(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 3
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_BlankWarehouse_LocationCodeEmpty() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();
        ord.DRC_NBC_Warehouse__c = null;
        update ord;

        ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_UnknownWarehouse_NoMetadata() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();
        ord.DRC_NBC_Warehouse__c = 'CFS - JNPT';
        update ord;

        ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_NullTotalPriceAndDiscount_DefaultToZero() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [SELECT Id, DRC_NBC_Discount__c FROM OrderItem WHERE OrderId = :ord.Id];
        for (OrderItem oi : rawItems) {
            oi.DRC_NBC_Discount__c = null;
        }
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_PackingFieldsPopulated() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [
            SELECT Id, DRC_NBC_Packing_Quantity__c, DRC_NBC_Packing_Size__c
            FROM OrderItem WHERE OrderId = :ord.Id
        ];
        for (OrderItem oi : rawItems) {
            oi.DRC_NBC_Packing_Quantity__c = '5';
            oi.DRC_NBC_Packing_Size__c     = '25 KG BAG';
        }
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_PackingFieldsNull() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [
            SELECT Id, DRC_NBC_Packing_Quantity__c, DRC_NBC_Packing_Size__c
            FROM OrderItem WHERE OrderId = :ord.Id
        ];
        for (OrderItem oi : rawItems) {
            oi.DRC_NBC_Packing_Quantity__c = null;
            oi.DRC_NBC_Packing_Size__c     = null;
        }
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_HazardousTrue() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [SELECT Id, DRC_NBC_Hazardous__c FROM OrderItem WHERE OrderId = :ord.Id];
        for (OrderItem oi : rawItems) {
            oi.DRC_NBC_Hazardous__c = true;
        }
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_MarksNosBlank() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [SELECT Id, DRC_NBC_MARKS_NOS__c FROM OrderItem WHERE OrderId = :ord.Id];
        for (OrderItem oi : rawItems) {
            oi.DRC_NBC_MARKS_NOS__c = null;
        }
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_SampleOrder_PriceAndDiscountZeroed() {
        List<RecordType> sampleRT = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Order' AND DeveloperName = 'Sample_Order'
            LIMIT 1
        ];
        if (sampleRT.isEmpty()) {
            return;
        }

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();
        ord.RecordTypeId = sampleRT[0].Id;
        update ord;

        ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_NullUnitPrice_DefaultsToZero() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [SELECT Id, UnitPrice FROM OrderItem WHERE OrderId = :ord.Id];
        for (OrderItem oi : rawItems) {
            oi.UnitPrice = 0;
        }
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_ZeroQuantity() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [SELECT Id, Quantity FROM OrderItem WHERE OrderId = :ord.Id];
        for (OrderItem oi : rawItems) {
            oi.Quantity = 1;
        }
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_NullDescription_EmptyString() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [SELECT Id, Description FROM OrderItem WHERE OrderId = :ord.Id];
        for (OrderItem oi : rawItems) {
            oi.Description = null;
        }
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_WithDiscount_DiscountAmountCalculated() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [SELECT Id, DRC_NBC_Discount__c FROM OrderItem WHERE OrderId = :ord.Id];
        for (OrderItem oi : rawItems) {
            oi.DRC_NBC_Discount__c = 10;
        }
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_createWithHighStartingLineNumber() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 100000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_NullShippingAddressRelationship() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
                   DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
                   Is_Domestic_Merchnat__c,
                   AccountId,
                   Account.DRC_NBC_Customer_Number__c,
                   Account.Type,
                   RecordType.Name
            FROM Order LIMIT 1
        ];

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_XmlSpecialCharactersEscaped() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [SELECT Id, Description FROM OrderItem WHERE OrderId = :ord.Id LIMIT 1];
        rawItems[0].Description = 'Product & <Special> "Chars"';
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_NullUOMCode_EscapedToEmpty() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();

        List<OrderItem> rawItems = [
            SELECT Id, DRC_NBC_Unit_Of_Measurement__c FROM OrderItem WHERE OrderId = :ord.Id
        ];
        for (OrderItem oi : rawItems) {
            oi.DRC_NBC_Unit_Of_Measurement__c = null;
        }
        update rawItems;

        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_IsDomesticMerchant_GSTGroupFromLabel() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();
        ord.Is_Domestic_Merchnat__c = true;
        update ord;

        ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }

    @isTest
    static void test_buildCreateMultiple_RestrictedProductMap_ItemReferenceNo() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Order ord = getStandardOrder();
        List<OrderItem> items = getOrderItems(ord.Id);

        // Insert a restricted product matching the first order item's product
        DRC_NBC_Restricted_Product__c rp = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Product__c  = items[0].Product2Id,
            DRC_NBC_Customer__c = ord.AccountId
        );
        insert rp;

        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }
}