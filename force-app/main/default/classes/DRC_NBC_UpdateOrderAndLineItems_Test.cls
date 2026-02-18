/**
 * @File Name : DRC_NBC_UpdateOrderAndLineItems_Test.cls
 * @Description : Test class for DRC_NBC_UpdateOrderAndLineItems
 * @Author : Test Generator
 * @Last Modified On : February 09, 2026
 **/
@isTest
private class DRC_NBC_UpdateOrderAndLineItems_Test {
    
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
        
        // Create Warehouse Location Code Metadata (simulated with custom object if metadata can't be inserted in tests)
        // Note: In real tests, you may need to use @IsTest(SeeAllData=true) or mock the metadata query
        
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
        
        // Create RecordType for Sample Order
        // Note: You may need to query existing RecordTypes or create them if possible
        
        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            DRC_NBC_FG_Code__c = 'FG001',
            DRC_NBC_GST_Group_Code__c = 'GST18',
            DRC_NBC_HSN_SAC_Code__c = 'HSN1234',
            IsActive = true
        );
        insert prod;
        
        // Create PricebookEntry
        Id stdPricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        // Create Order
        Order ord = new Order(
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
        insert ord;
        
        // Create OrderItem
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 100,
            Description = 'Test Product',
            DRC_NBC_Discount__c = 5,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oi;
    }
    
    /**
     * Test: Successful Order Update with existing Ship-To Code
     */
    @isTest
    static void testOrderUpdateWithShipToCode() {
        // Setup Mock
        Test.setMock(HttpCalloutMock.class, new BC_SuccessHttpMock());
        
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.contains('SUCCESS') || result.contains('UPDATE'), 'Should indicate success or update');
    }
    
    /**
     * Test: Order with missing Ship-To Code (triggers Queueable chain)
     */
    @isTest
    static void testOrderUpdateWithoutShipToCode() {
        // Remove Ship-To Code
        DRC_NBC_Addresses__c shipAddr = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        shipAddr.DRC_NBC_Ship_To_Code__c = null;
        update shipAddr;
        
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
        
        System.assert(result.contains('QUEUED'), 'Should indicate queued process: ' + result);
    }
    
    /**
     * Test: Exception handling in orderId
     */
    @isTest
    static void testOrderIdException() {
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(null);
        Test.stopTest();
        
        System.assert(result.contains('ERROR'), 'Should return error for null ID');
    }
    
    /**
     * Test: processOrderSync with successful BC interaction
     */
    @isTest
    static void testProcessOrderSync() {
        Test.setMock(HttpCalloutMock.class, new BC_SuccessHttpMock());
        
        Order ord = [SELECT Id, AccountId, OrderNumber, DRC_NBC_Cust_Order_Number__c, 
                     Account.DRC_NBC_Customer_Number__c, DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c,
                     DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c, DRC_NBC_Warehouse__c,
                     DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c, RecordType.Name
                     FROM Order LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.processOrderSync(ord, ord.AccountId);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    /**
     * Test: BCLineItem wrapper class
     */
    @isTest
    static void testBCLineItemWrapper() {
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.BCLineItem bcLine = 
            new DRC_NBC_UpdateOrderAndLineItems.BCLineItem('KEY123', 10000, 'Item', 'FG001', 10, 'Test Item');
        Test.stopTest();
        
        System.assertEquals('KEY123', bcLine.key);
        System.assertEquals(10000, bcLine.lineNo);
        System.assertEquals('Item', bcLine.lineType);
        System.assertEquals('FG001', bcLine.itemNo);
        System.assertEquals(10, bcLine.quantity);
    }
    
    /**
     * Test: ShipToCodeGeneratorQueueable
     */
    @isTest
    static void testShipToCodeGeneratorQueueable() {
        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_UpdateOrderAndLineItems.ShipToCodeGeneratorQueueable(ord.Id, ord.AccountId));
        Test.stopTest();
        
        // Verify queueable was enqueued (can't verify execution in test context)
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * Test: ShippingAndOrderCalloutQueueable
     */
    @isTest
    static void testShippingAndOrderCalloutQueueable() {
        Test.setMock(HttpCalloutMock.class, new BC_SuccessHttpMock());
        
        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_UpdateOrderAndLineItems.ShippingAndOrderCalloutQueueable(ord.Id, ord.AccountId));
        Test.stopTest();
        
        // Verify queueable execution
        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }
    
    /**
     * Test: Missing Custom Settings
     */
    @isTest
    static void testMissingCustomSettings() {
        delete [SELECT Id FROM DRC_NBC_BC_Integration__c];
        
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
        
        System.assert(result.contains('ERROR'), 'Should return error for missing settings');
    }
    
    /**
     * HTTP Mock for successful BC responses
     */
    private class BC_SuccessHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            String soapAction = req.getHeader('SOAPAction');
            
            if (soapAction != null && soapAction.contains(':Read')) {
                // Read response with BC Key
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soap:Body>' +
                    '<Read_Result>' +
                    '<SalesOrderSalesForce>' +
                    '<Key>TEST-KEY-12345</Key>' +
                    '<No>BC-ORD-001</No>' +
                    '</SalesOrderSalesForce>' +
                    '</Read_Result>' +
                    '</soap:Body>' +
                    '</soap:Envelope>'
                );
            } else if (soapAction != null && soapAction.contains(':ReadMultiple')) {
                // ReadMultiple response with line items
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soap:Body>' +
                    '<ReadMultiple_Result>' +
                    '<ReadMultiple_Result>' +
                    '<SalesOrderLineSalesForce>' +
                    '<Key>LINE-KEY-001</Key>' +
                    '<Line_No>10000</Line_No>' +
                    '<Type>Item</Type>' +
                    '<No>FG001</No>' +
                    '<Quantity>10</Quantity>' +
                    '<Description>Test Product</Description>' +
                    '</SalesOrderLineSalesForce>' +
                    '<SalesOrderLineSalesForce>' +
                    '<Key>LINE-KEY-002</Key>' +
                    '<Line_No>20000</Line_No>' +
                    '<Type>G/L Account</Type>' +
                    '<No></No>' +
                    '<Quantity>1</Quantity>' +
                    '<Description>Other Tax Amount</Description>' +
                    '</SalesOrderLineSalesForce>' +
                    '</ReadMultiple_Result>' +
                    '</ReadMultiple_Result>' +
                    '</soap:Body>' +
                    '</soap:Envelope>'
                );
            } else {
                // Generic success response for Update, Create, Delete
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soap:Body>' +
                    '<Response>Success</Response>' +
                    '</soap:Body>' +
                    '</soap:Envelope>'
                );
            }
            
            return res;
        }
    }
    
    /**
     * HTTP Mock for failed BC responses
     */
    private class BC_FailureHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
}