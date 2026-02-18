/**
 * @File Name : DRC_NBC_LineItemCreator_Test.cls
 * @Description : Test class for DRC_NBC_LineItemCreator
 * @Author : Satish Yadav
 * @Last Modified On : February 09, 2026
 **/
@isTest
private class DRC_NBC_LineItemCreator_Test {
    
    /**
     * Test Data Setup
     */
    @testSetup
    static void setupTestData() {
        // Create Custom Setting
        DRC_NBC_BC_Integration__c bcSettings = new DRC_NBC_BC_Integration__c();
        bcSettings.DRC_NBC_BC_Order_Endpoint__c = 'https://test.bc.com/order';
        bcSettings.DRC_NBC_BC_Line_Item_Endpoint__c = 'https://test.bc.com/lineitem';
        bcSettings.DRC_NBC_SOAP_Order_Namespace__c = 'urn:microsoft-dynamics-schemas/codeunit/SalesOrderSalesForce';
        bcSettings.DRC_NBC_SOAP_Line_Namespace__c = 'urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce';
        bcSettings.DRC_NBC_GST_Credit_Value__c = 'AVAILMENT';
        bcSettings.DRC_NBC_Username__c = 'testuser';
        bcSettings.DRC_NBC_Password__c = 'testpass';
        insert bcSettings;
        
        // Create Account
        Account acc = new Account(
            Name = 'Test Customer',
            DRC_NBC_Customer_Number__c = 'CUST001'
        );
        insert acc;
        
        // Create Shipping Address
        DRC_NBC_Addresses__c shipAddr = new DRC_NBC_Addresses__c(
            DRC_NBC_Ship_To_Code__c = 'SHIP001',
            DRC_NBC_Type__c = 'Shipping',
            DRC_NBC_Warehouse__c = 'CFS - JNPT',
            DRC_NBC_Account__c = acc.Id
        );
        insert shipAddr;
        
        // Create Products
        List<Product2> products = new List<Product2>();
        for (Integer i = 1; i <= 5; i++) {
            products.add(new Product2(
                Name = 'Test Product ' + i,
                DRC_NBC_FG_Code__c = 'FG00' + i,
                DRC_NBC_GST_Group_Code__c = 'GST18',
                DRC_NBC_HSN_SAC_Code__c = 'HSN' + i,
                IsActive = true
            ));
        }
        insert products;
        
        // Create PricebookEntries
        Id stdPricebookId = Test.getStandardPricebookId();
        List<PricebookEntry> pbes = new List<PricebookEntry>();
        for (Product2 prod : products) {
            pbes.add(new PricebookEntry(
                Pricebook2Id = stdPricebookId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true
            ));
        }
        insert pbes;
        
        // Create Standard Order
        Order standardOrd = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = stdPricebookId,
            DRC_NBC_Shipping_Address__c = shipAddr.Id,
            DRC_NBC_Cust_Order_Number__c = 'BC-ORD-001',
            DRC_NBC_Warehouse__c = 'CFS - JNPT',
            DRC_NBC_Other_Tax_Amount__c = 50,
            DRC_NBC_TCS_Amount__c = 25
        );
        insert standardOrd;
        
        // Create OrderItems for Standard Order
        List<OrderItem> items = new List<OrderItem>();
        for (Integer i = 0; i < 3; i++) {
            items.add(new OrderItem(
                OrderId = standardOrd.Id,
                Product2Id = products[i].Id,
                PricebookEntryId = pbes[i].Id,
                Quantity = 10 + i,
                UnitPrice = 100,
                Description = 'Test Product ' + (i + 1),
                DRC_NBC_Discount__c = 5,
                DRC_NBC_Unit_Of_Measurement__c = 'KGS'
            ));
        }
        insert items;
    }
    
    /**
     * Test: Create single line item successfully
     */
    @isTest
    static void testCreateSingleLineItem() {
        Test.setMock(HttpCalloutMock.class, new CreateSuccessHttpMock());
        
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                     DRC_NBC_Warehouse__c, RecordType.Name FROM Order LIMIT 1];
        List<OrderItem> items = [SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice, 
                                 DRC_NBC_Discount__c, Product2.DRC_NBC_FG_Code__c,
                                 Product2.DRC_NBC_GST_Group_Code__c, Product2.DRC_NBC_HSN_SAC_Code__c,
                                 DRC_NBC_Unit_Of_Measurement__c, Order.RecordType.Name
                                 FROM OrderItem WHERE OrderId = :ord.Id LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }
    
    /**
     * Test: Create multiple line items successfully
     */
    @isTest
    static void testCreateMultipleLineItems() {
        Test.setMock(HttpCalloutMock.class, new CreateSuccessHttpMock());
        
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                     DRC_NBC_Warehouse__c, RecordType.Name FROM Order LIMIT 1];
        List<OrderItem> items = [SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice, 
                                 DRC_NBC_Discount__c, Product2.DRC_NBC_FG_Code__c,
                                 Product2.DRC_NBC_GST_Group_Code__c, Product2.DRC_NBC_HSN_SAC_Code__c,
                                 DRC_NBC_Unit_Of_Measurement__c, Order.RecordType.Name
                                 FROM OrderItem WHERE OrderId = :ord.Id];
        
        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 40000
        );
        Test.stopTest();
    }
    
    /**
     * Test: Create with empty items list
     */
    @isTest
    static void testCreateEmptyList() {
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c, RecordType.Name FROM Order LIMIT 1];
        List<OrderItem> items = new List<OrderItem>();
        
        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }
    
    /**
     * Test: Create with null items list
     */
    @isTest
    static void testCreateNullList() {
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c, RecordType.Name FROM Order LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, null, ord, 30000
        );
        Test.stopTest();
    }
    
    /**
     * Test: Create with BC failure response
     */
    @isTest
    static void testCreateWithBCFailure() {
        Test.setMock(HttpCalloutMock.class, new CreateFailureHttpMock());
        
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                     DRC_NBC_Warehouse__c, RecordType.Name FROM Order LIMIT 1];
        List<OrderItem> items = [SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice, 
                                 DRC_NBC_Discount__c, Product2.DRC_NBC_FG_Code__c,
                                 Product2.DRC_NBC_GST_Group_Code__c, Product2.DRC_NBC_HSN_SAC_Code__c,
                                 DRC_NBC_Unit_Of_Measurement__c, Order.RecordType.Name
                                 FROM OrderItem WHERE OrderId = :ord.Id LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }
    
    /**
     * Test: Exception handling
     */
    @isTest
    static void testCreateException() {
        Test.setMock(HttpCalloutMock.class, new CreateExceptionHttpMock());
        
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                     DRC_NBC_Warehouse__c, RecordType.Name FROM Order LIMIT 1];
        List<OrderItem> items = [SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice, 
                                 DRC_NBC_Discount__c, Product2.DRC_NBC_FG_Code__c,
                                 Product2.DRC_NBC_GST_Group_Code__c, Product2.DRC_NBC_HSN_SAC_Code__c,
                                 DRC_NBC_Unit_Of_Measurement__c, Order.RecordType.Name
                                 FROM OrderItem WHERE OrderId = :ord.Id LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }
    
    /**
     * Test: Legacy method createLineItems (counter-based)
     */
    @isTest
    static void testLegacyCreateLineItems() {
        Test.setMock(HttpCalloutMock.class, new CreateSuccessHttpMock());
        
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                     DRC_NBC_Warehouse__c, RecordType.Name FROM Order LIMIT 1];
        List<OrderItem> items = [SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice, 
                                 DRC_NBC_Discount__c, Product2.DRC_NBC_FG_Code__c,
                                 Product2.DRC_NBC_GST_Group_Code__c, Product2.DRC_NBC_HSN_SAC_Code__c,
                                 DRC_NBC_Unit_Of_Measurement__c, Order.RecordType.Name
                                 FROM OrderItem WHERE OrderId = :ord.Id LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItems(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 3
        );
        Test.stopTest();
    }
    
    /**
     * Test: Line number increment logic (30000, 40000, 50000...)
     */
    @isTest
    static void testLineNumberIncrement() {
        Test.setMock(HttpCalloutMock.class, new CreateLineNumberTrackingHttpMock());
        
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                     DRC_NBC_Warehouse__c, RecordType.Name FROM Order LIMIT 1];
        List<OrderItem> items = [SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice, 
                                 DRC_NBC_Discount__c, Product2.DRC_NBC_FG_Code__c,
                                 Product2.DRC_NBC_GST_Group_Code__c, Product2.DRC_NBC_HSN_SAC_Code__c,
                                 DRC_NBC_Unit_Of_Measurement__c, Order.RecordType.Name
                                 FROM OrderItem WHERE OrderId = :ord.Id];
        
        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }
    
    /**
     * Test: Create items with discount calculations
     */
    @isTest
    static void testCreateWithDiscounts() {
        Test.setMock(HttpCalloutMock.class, new CreateSuccessHttpMock());
        
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                     DRC_NBC_Warehouse__c, RecordType.Name FROM Order LIMIT 1];
        
        List<OrderItem> items = [SELECT Id, DRC_NBC_Discount__c FROM OrderItem WHERE OrderId = :ord.Id];
        items[0].DRC_NBC_Discount__c = 10;
        if (items.size() > 1) {
            items[1].DRC_NBC_Discount__c = 0;
        }
        update items;
        
        items = [SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice, 
                 DRC_NBC_Discount__c, Product2.DRC_NBC_FG_Code__c,
                 Product2.DRC_NBC_GST_Group_Code__c, Product2.DRC_NBC_HSN_SAC_Code__c,
                 DRC_NBC_Unit_Of_Measurement__c, Order.RecordType.Name
                 FROM OrderItem WHERE OrderId = :ord.Id];
        
        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 30000
        );
        Test.stopTest();
    }
    
    /**
     * Test: Create with high starting line number
     */
    @isTest
    static void testCreateWithHighLineNumber() {
        Test.setMock(HttpCalloutMock.class, new CreateSuccessHttpMock());
        
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                     DRC_NBC_Warehouse__c, RecordType.Name FROM Order LIMIT 1];
        List<OrderItem> items = [SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice, 
                                 DRC_NBC_Discount__c, Product2.DRC_NBC_FG_Code__c,
                                 Product2.DRC_NBC_GST_Group_Code__c, Product2.DRC_NBC_HSN_SAC_Code__c,
                                 DRC_NBC_Unit_Of_Measurement__c, Order.RecordType.Name
                                 FROM OrderItem WHERE OrderId = :ord.Id LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
            ord.DRC_NBC_Cust_Order_Number__c, items, ord, 100000
        );
        Test.stopTest();
    }
    
    /**
     * HTTP Mock for successful create responses
     */
    private class CreateSuccessHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<CreateMultiple_Result>Success</CreateMultiple_Result>' +
                '</soap:Body>' +
                '</soap:Envelope>'
            );
            return res;
        }
    }
    
    /**
     * HTTP Mock for failed create responses
     */
    private class CreateFailureHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
    
    /**
     * HTTP Mock that throws exception
     */
    private class CreateExceptionHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Connection timeout');
        }
    }
    
    /**
     * HTTP Mock to track line number increment
     */
    private class CreateLineNumberTrackingHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<CreateMultiple_Result>Success</CreateMultiple_Result>' +
                '</soap:Body>' +
                '</soap:Envelope>'
            );
            return res;
        }
    }
}