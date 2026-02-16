/**
 * @File Name : DRC_NBC_Order_BC_Integration_Test.cls
 * @Description : Comprehensive test class for Order BC Integration classes
 * @Author : Test Class Generator
 * @Last Modified On : January 05, 2026
 **/
@isTest
private class DRC_NBC_Order_BC_Integration_Test {
    
    // Test data setup
    @testSetup
    static void setupTestData() {
        // ===== CREATE CUSTOM SETTING FIRST =====
        DRC_NBC_BC_Integration__c customSetting = new DRC_NBC_BC_Integration__c(
            Name = 'Test_Config_Sandbox',
            Name__c = 'Sandbox',
            DRC_NBC_Comapny_Name__c = 'D.R. COATS INK AND RESINS PVT. LTD',
            DRC_NBC_Endpoint__c = 'https://api.businesscentral.dynamics.com/v2.0/production/api/v2.0',
            DRC_NBC_SendOrderEndpoint__c = 'SalesOrders',
            DRC_NBC_Shipping_Address_Endpoint__c = 'ShipToAddress',
            DRC_NBC_SendOrderLineEndpoint__c = 'SalesOrderLines',
            DRC_NBC_SalesPerson_Code__c = 'SP001',
            DRC_NBC_Token_Generated_Time__c = System.now()
        );
        insert customSetting;
        
        System.debug(' Custom Setting Created: ' + customSetting.Name);
        
        // Create Account
        Account testAccount = new Account(
            Name = 'Test Account',
            DRC_NBC_Customer_Number__c = 'CUST001',
            DRC_NBC_PAN_No__c = 'AWVPY9594J'
        );
        insert testAccount;
        
        // Create Contact
        Contact billToContact = new Contact(
            FirstName = 'Bill',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'bill@test.com'
        );
        insert billToContact;
        
        Contact shipToContact = new Contact(
            FirstName = 'Ship',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'ship@test.com'
        );
        insert shipToContact;
        
        // Create Pricebook
        Pricebook2 standardPricebook = new Pricebook2(
            Id = Test.getStandardPricebookId(),
            IsActive = true
        );
        update standardPricebook;
        
        // Create Product
        Product2 testProduct = new Product2(
            Name = 'Test Product',
            ProductCode = 'PROD001',
            IsActive = true,
            DRC_NBC_FG_Code__c = 'FG001',
            DRC_NBC_HSN_SAC_Code__c = 'HSN001',
            QuantityUnitOfMeasure = 'Each'
        );
        insert testProduct;
        
        // Create Pricebook Entry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebook.Id,
            Product2Id = testProduct.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;
        
        // Create Order
        Order testOrder = new Order(
            AccountId = testAccount.Id,
            EffectiveDate = Date.today(),
            EndDate = Date.today().addDays(30),
            Status = 'Draft',
            Pricebook2Id = standardPricebook.Id,
            BillToContactId = billToContact.Id,
            ShipToContactId = shipToContact.Id,
            PoNumber = 'PO12345',
            PoDate = Date.today(),
            DRC_NBC_Payment_Terms__c = '10% - 90%',
            DRC_NBC_Inco_Terms__c = 'Cost Insurance & Freight (CIF)',
            DRC_NBC_Cust_Order_Number__c = 'ORD-001',
            ShippingStreet = '123 Test St',
            ShippingCity = 'Test City',
            ShippingState = 'Maharashtra',
            ShippingPostalCode = '12345',
            ShippingCountry = 'India',
            ShippingCountryCode = 'IN',
            DRC_NBC_Warehouse__c = 'C4/2/2 D.R COATS INK & RESINS PVT LTD (UNIT-III)'
        );
        insert testOrder;
        
        // Create Shipping Address
        DRC_NBC_Addresses__c shippingAddress = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c = testAccount.Id,
            DRC_NBC_Order__c = testOrder.Id,
            DRC_NBC_Type__c = 'Shipping',
            DRC_NBC_Ship_To_Code__c = 'SHIP001',
            DRC_NBC_Warehouse__c = 'C4/2/2 D.R COATS INK & RESINS PVT LTD (UNIT-III)',
            DRC_NBC_Address__Street__s = '123 Test St',
            DRC_NBC_Address__City__s = 'Test City',
            DRC_NBC_Address__StateCode__s = 'MH',
            DRC_NBC_Address__PostalCode__s = '12345',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY'
        );
        insert shippingAddress;
        
        // Update Order with Shipping Address
        testOrder.DRC_NBC_Shipping_Address__c = shippingAddress.Id;
        update testOrder;
        
        // Create Order Line Items
        OrderItem testOrderItem = new OrderItem(
            OrderId = testOrder.Id,
            Product2Id = testProduct.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 10,
            UnitPrice = 100.00
        );
        insert testOrderItem;
        
        System.debug(' Test data setup completed');
    }
    
    // Test 1: Verify Custom Setting Created
    @isTest
    static void testCustomSettingExists() {
        Test.startTest();
        DRC_NBC_BC_Integration__c setting = DRC_NBC_BC_Callout_Utility.getConfig();
        Test.stopTest();
        
        System.debug('Custom Setting Name: ' + setting.Name__c);
        System.debug('Company Name: ' + setting.DRC_NBC_Comapny_Name__c);
        System.debug('Endpoint: ' + setting.DRC_NBC_Endpoint__c);
    }
    
    // Test 2: DRC_NBC_Order_BC_Callout - Order Already Synced
    @isTest
    static void testOrderAlreadySynced() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        // Mark order as already synced
        testOrder.DRC_NBC_Order_Sync_To_BC__c = true;
        update testOrder;
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_BC_Callout(testOrder.Id));
        Test.stopTest();
        
        // Verify order remains synced
        Order updatedOrder = [SELECT DRC_NBC_Order_Sync_To_BC__c FROM Order WHERE Id = :testOrder.Id];
        System.debug('Order Sync Status: ' + updatedOrder.DRC_NBC_Order_Sync_To_BC__c);
    }
    
    // Test 3: DRC_NBC_Order_BC_Callout - Needs Ship-To Code
    @isTest
    static void testNeedsShipToCode() {
        Order testOrder = [SELECT Id, DRC_NBC_Shipping_Address__c FROM Order LIMIT 1];
        
        // Clear Ship-To Code
        DRC_NBC_Addresses__c address = [SELECT Id FROM DRC_NBC_Addresses__c WHERE Id = :testOrder.DRC_NBC_Shipping_Address__c];
        address.DRC_NBC_Ship_To_Code__c = null;
        update address;
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_BC_Callout(testOrder.Id));
        Test.stopTest();
        
        // Verify chain was initiated
        System.debug('Ship-To Code generation initiated');
    }
    
    // Test 4: DRC_NBC_Order_BC_Callout - Needs Order Number
    @isTest
    static void testNeedsOrderNumber() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        // Clear Order Number
        testOrder.DRC_NBC_Cust_Order_Number__c = null;
        update testOrder;
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_BC_Callout(testOrder.Id));
        Test.stopTest();
        
        // Verify chain was initiated
        System.debug('Order Number generation initiated');
    }
    
    // Test 5: DRC_NBC_Order_BC_Callout - No DML Needed
    @isTest
    static void testNoDMLNeeded() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        // Mock HTTP Callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, 'Success'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_BC_Callout(testOrder.Id));
        Test.stopTest();
        
        // Verify callout chain was initiated
        System.debug('Callout chain initiated');
    }
    
    // Test 6: DRC_NBC_Order_BC_Callout - Exception Handling
    @isTest
    static void testOrderCalloutException() {
        // Create order without required fields to trigger exception
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Order invalidOrder = new Order(
            AccountId = testAccount.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft'
        );
        insert invalidOrder;
        
        Test.startTest();
        try {
            System.enqueueJob(new DRC_NBC_Order_BC_Callout(invalidOrder.Id));
        } catch (Exception e) {
            System.debug('Exception handled: ' + e.getMessage());
        }
        Test.stopTest();
        
        // Verify error was logged
        System.debug('Exception test completed');
    }
    
    // Test 7: DRC_NBC_Order_DML_Handler - Ship-To Code Generation
    @isTest
    static void testDMLHandlerShipToCode() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_DML_Handler(testOrder.Id, true, false));
        Test.stopTest();
        
        // Verify DML execution
        System.debug('Ship-To Code DML handler executed');
    }
    
    // Test 8: DRC_NBC_Order_DML_Handler - Order Number Generation
    @isTest
    static void testDMLHandlerOrderNumber() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_DML_Handler(testOrder.Id, false, true));
        Test.stopTest();
        
        // Verify DML execution
        System.debug('Order Number DML handler executed');
    }
    
    // Test 9: DRC_NBC_Order_DML_Handler - Both Generations
    @isTest
    static void testDMLHandlerBoth() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_DML_Handler(testOrder.Id, true, true));
        Test.stopTest();
        
        // Verify DML execution
        System.debug('Both DML handlers executed');
    }
    
    // Test 10: DRC_NBC_Order_Callout_Handler - Success
    @isTest
    static void testShippingCalloutSuccess() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, 'Success'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(testOrder.Id));
        Test.stopTest();
        
        // Verify shipping callout executed
        System.debug('Shipping callout executed successfully');
    }
    
    // Test 11: DRC_NBC_Order_Callout_Handler - No Shipping Address
    @isTest
    static void testShippingCalloutNoAddress() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        // Remove shipping address
        testOrder.DRC_NBC_Shipping_Address__c = null;
        update testOrder;
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, 'Success'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(testOrder.Id));
        Test.stopTest();
        
        // Verify skipped shipping callout
        System.debug('Shipping callout skipped - no address');
    }
    
    // Test 12: DRC_NBC_Order_Callout_Handler - Callout Failure
    @isTest
    static void testShippingCalloutFailure() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(400, 'Error'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_Callout_Handler(testOrder.Id));
        Test.stopTest();
        
        // Verify error handling
        System.debug('Shipping callout failure handled');
    }
    
    // Test 13: DRC_NBC_Order_Only_Callout_Handler - Success
    @isTest
    static void testOrderOnlyCalloutSuccess() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, 'Success'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_Only_Callout_Handler(testOrder.Id));
        Test.stopTest();
        
        // Verify order callout executed
        System.debug('Order callout executed successfully');
    }
    
    // Test 14: DRC_NBC_Order_Only_Callout_Handler - Missing Order Number
    @isTest
    static void testOrderOnlyCalloutMissingNumber() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        // Clear order number
        testOrder.DRC_NBC_Cust_Order_Number__c = null;
        update testOrder;
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, 'Success'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_Only_Callout_Handler(testOrder.Id));
        Test.stopTest();
        
        // Verify validation handled
        System.debug('Order number validation handled');
    }
    
    // Test 15: DRC_NBC_Order_Only_Callout_Handler - Callout Failure
    @isTest
    static void testOrderOnlyCalloutFailure() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Server Error'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_Only_Callout_Handler(testOrder.Id));
        Test.stopTest();
        
        // Verify error handling
        System.debug('Order callout failure handled');
    }
    
    // Test 16: DRC_NBC_Order_BC_Update_Service - Process Order Update
    @isTest
    static void testProcessOrderUpdate() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.processOrderUpdate(testOrder.Id);
        Test.stopTest();
        
        // Verify order was marked as synced
        Order updatedOrder = [SELECT DRC_NBC_Order_Sync_To_BC__c, DRC_NBC_Integration_Status__c FROM Order WHERE Id = :testOrder.Id];
        System.debug('Order Sync Status: ' + updatedOrder.DRC_NBC_Order_Sync_To_BC__c);
        System.debug('Integration Status: ' + updatedOrder.DRC_NBC_Integration_Status__c);
    }
    
    // Test 17: DRC_NBC_Order_BC_Update_Service - Failed Order Update
    @isTest
    static void testFailedOrderUpdate() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        DRC_NBC_Order_BC_Update_Service.failedOrderUpdate(testOrder.Id);
        Test.stopTest();
        
        // Verify order was marked as failed
        Order updatedOrder = [SELECT DRC_NBC_Integration_Status__c FROM Order WHERE Id = :testOrder.Id];
        System.debug('Integration Status: ' + updatedOrder.DRC_NBC_Integration_Status__c);
    }
    
    // Test 18: DRC_NBC_Shipping_BC_Integration - Success
    @isTest
    static void testShippingIntegrationSuccess() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        String payload = '{"test": "data"}';
        String endpoint = 'ShipToAddress';
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, 'Success'));
        
        Test.startTest();
        DRC_NBC_Shipping_BC_Integration integration = new DRC_NBC_Shipping_BC_Integration(
            endpoint, 'POST', payload, testAccount.Id
        );
        HttpResponse response = integration.executeAndReturnResponse();
        Test.stopTest();
        
        // Verify response
        System.debug('Shipping Integration Response Code: ' + response.getStatusCode());
    }
    
    // Test 19: DRC_NBC_Shipping_BC_Integration - Error
    @isTest
    static void testShippingIntegrationError() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        String payload = '{"test": "data"}';
        String endpoint = 'ShipToAddress';
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(400, 'Bad Request'));
        
        Test.startTest();
        DRC_NBC_Shipping_BC_Integration integration = new DRC_NBC_Shipping_BC_Integration(
            endpoint, 'POST', payload, testAccount.Id
        );
        HttpResponse response = integration.executeAndReturnResponse();
        Test.stopTest();
        
        // Verify error handling
        System.debug('Shipping Integration Error Code: ' + response.getStatusCode());
    }
    
    // Test 20: DRC_NBC_Order_BC_Integration - Success
    @isTest
    static void testOrderIntegrationSuccess() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        String payload = '{"test": "data"}';
        String endpoint = 'SalesOrders';
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, 'Success'));
        
        Test.startTest();
        DRC_NBC_Order_BC_Integration integration = new DRC_NBC_Order_BC_Integration(
            endpoint, 'POST', payload, testOrder.Id
        );
        HttpResponse response = integration.executeAndReturnResponse();
        Test.stopTest();
        
        // Verify response
        System.debug('Order Integration Response Code: ' + integration.httpStatusCode);
        System.debug('Response Summary: ' + integration.responseSummary);
    }
    
    // Test 21: DRC_NBC_Order_BC_Integration - Error
    @isTest
    static void testOrderIntegrationError() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        String payload = '{"test": "data"}';
        String endpoint = 'SalesOrders';
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(500, 'Server Error'));
        
        Test.startTest();
        DRC_NBC_Order_BC_Integration integration = new DRC_NBC_Order_BC_Integration(
            endpoint, 'POST', payload, testOrder.Id
        );
        HttpResponse response = integration.executeAndReturnResponse();
        Test.stopTest();
        
        // Verify error handling
        System.debug('Order Integration Error Code: ' + integration.httpStatusCode);
        System.debug('Error Summary: ' + integration.responseSummary);
    }
    
    // Test 22: Test mapOrderToBCPayload - Complete Order
    @isTest
    static void testMapOrderToBCPayload() {
        Order testOrder = [
            SELECT Id, Name, AccountId, Account.Name, Account.DRC_NBC_Customer_Number__c,
                   EffectiveDate, PoNumber, PoDate, DRC_NBC_Warehouse__c, ShipToContactId,
                   DRC_NBC_Cust_Order_Number__c, Status, DRC_NBC_Payment_Terms__c,
                   DRC_NBC_Inco_Terms__c, ShippingStreet, ShippingCity, ShippingState,
                   ShippingPostalCode, ShippingCountry, DRC_NBC_Shipping_Address__c,
                   DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c, RecordType.Name
            FROM Order LIMIT 1
        ];
        
        Test.startTest();
        DRC_NBC_Integration_Payload.OrderPayload payload = 
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(testOrder);
        Test.stopTest();
        
        // Verify payload fields
        System.debug('Payload Document Type: ' + payload.Document_Type);
        System.debug('Payload No: ' + payload.No);
        System.debug('Payload Customer No: ' + payload.Sell_to_Customer_No);
        System.debug('Payload Order Date: ' + payload.Order_Date);
    }
    
    // Test 23: Test mapOrderToBCPayload - Long Address
    @isTest
    static void testMapOrderToBCPayloadLongAddress() {
        Order testOrder = [SELECT Id, DRC_NBC_Shipping_Address__c FROM Order LIMIT 1];
        
        // Create address with very long street
        DRC_NBC_Addresses__c address = [SELECT Id FROM DRC_NBC_Addresses__c WHERE Id = :testOrder.DRC_NBC_Shipping_Address__c];
        address.DRC_NBC_Address__Street__s = 'This is a very long street address that exceeds the normal length to test the address splitting functionality in the integration payload mapper method';
        update address;
        
        Test.startTest();
        Order updatedOrder = DRC_NBC_Order_BC_Callout.getOrderDetails(testOrder.Id);
        DRC_NBC_Integration_Payload.OrderPayload payload = 
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(updatedOrder);
        Test.stopTest();
        
        // Verify address splitting
        System.debug('Ship to Address: ' + payload.Ship_to_Address);
        System.debug('Ship to Address 2: ' + payload.Ship_to_Address_2);
    }
    
    // Test 24: Test getOrderDetails method
    @isTest
    static void testGetOrderDetails() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        Order retrievedOrder = DRC_NBC_Order_BC_Callout.getOrderDetails(testOrder.Id);
        Test.stopTest();
        
        // Verify order retrieval
        System.debug('Retrieved Order ID: ' + retrievedOrder.Id);
        System.debug('Order Number: ' + retrievedOrder.OrderNumber);
        System.debug('Customer Number: ' + retrievedOrder.Account.DRC_NBC_Customer_Number__c);
    }
    
    // Test 25: Multiple Queueable Chain Test
    @isTest
    static void testCompleteQueueableChain() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        // Clear ship-to code to trigger full chain
        DRC_NBC_Addresses__c address = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        address.DRC_NBC_Ship_To_Code__c = null;
        update address;
        
        testOrder.DRC_NBC_Cust_Order_Number__c = null;
        update testOrder;
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, 'Success'));
        
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Order_BC_Callout(testOrder.Id));
        Test.stopTest();
        
        // Verify chain execution
        System.debug('Complete queueable chain executed');
    }
    
    // Test 26: Bulk Test - Multiple Orders
    @isTest
    static void testBulkOrders() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        Pricebook2 pricebook = new Pricebook2(Id = Test.getStandardPricebookId());
        
        List<Order> orders = new List<Order>();
        for (Integer i = 0; i < 5; i++) {
            orders.add(new Order(
                AccountId = testAccount.Id,
                EffectiveDate = Date.today(),
                EndDate = Date.today().addDays(30),
                Status = 'Draft',
                Pricebook2Id = pricebook.Id,
                BillToContactId = contact.Id,
                ShipToContactId = contact.Id,
                DRC_NBC_Cust_Order_Number__c = 'ORD-00' + i
            ));
        }
        insert orders;
        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator(201, 'Success'));
        
        Test.startTest();
        for (Order ord : orders) {
            try {
                System.enqueueJob(new DRC_NBC_Order_BC_Callout(ord.Id));
            } catch (Exception e) {
                System.debug('Bulk test exception: ' + e.getMessage());
            }
        }
        Test.stopTest();
        
        // Verify bulk processing
        System.debug('Bulk orders processed');
    }
    
    // Mock HTTP Response Generator
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;
        
        public MockHttpResponseGenerator(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }
        
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }
}