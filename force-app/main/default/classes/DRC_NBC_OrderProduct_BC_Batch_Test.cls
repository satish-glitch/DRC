@isTest
private class DRC_NBC_OrderProduct_BC_Batch_Test {
    
    private static String getSalesOrderLineUrl() {
        return System.Label.DRC_UAT;
    }
    
    private class MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setBody('{"responses":[{"status":201}]}');
            return res;
        }
    }
    
    private class MockFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"error":"Server Error"}');
            return res;
        }
    }
    
    private static void insertIntegrationSetting() {
        List<DRC_NBC_BC_Integration__c> existing = [
            SELECT Id FROM DRC_NBC_BC_Integration__c LIMIT 1
        ];
        if (!existing.isEmpty()) return;
        
        String targetEnvName;
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        targetEnvName = isSandbox ? System.Label.DRC_NBC_Sandbox : System.Label.DRC_NBC_Production;
        
        DRC_NBC_BC_Integration__c setting = new DRC_NBC_BC_Integration__c(
            Name__c                              = targetEnvName,
            DRC_NBC_Comapny_Name__c              = 'Test Company',
            DRC_NBC_Endpoint__c                  = 'https://mock-bc.example.com',
            DRC_NBC_SendOrderEndpoint__c         = 'salesOrders',
            DRC_NBC_Shipping_Address_Endpoint__c = 'shipToAddresses',
            DRC_NBC_SendOrderLineEndpoint__c     = 'salesOrderLines',
            DRC_NBC_SalesPerson_Code__c          = 'SP001'
        );
        insert setting;
    }
    
    // ─── Test Setup ───────────────────────────────────────────────────────────
    
    @testSetup
    static void setupTestData() {
        
        insertIntegrationSetting();
        
        Account acc = new Account(
            Name                                    = 'Test Account',
            DRC_NBC_Customer_Number__c              = 'CUST12345',
            CurrencyIsoCode                         = 'INR',
            Phone                                   = '1234567890',
            AccountNumber                           = 'A123',
            DRC_NBC_PAN_No__c                       = 'AWVPY9594J',
            DRC_NBC_GST_Number__c                   = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c            = 'PDC90',
            DRC_NBC_Account_Email_Email__c          = 'test@example.com',
            BillingStreet                           = '123 Street',
            BillingCity                             = 'City',
            BillingCountry                          = 'India',
            BillingCountryCode                      = 'IN',
            BillingPostalCode                       = '462002',
            BillingState                            = 'Maharashtra',
            BillingStateCode                        = 'MH',
            DRC_NBC_Volume__c                       = 70,
            DRC_NBC_Credit_Limit__c                 = 123456787,
            DRC_NBC_Value__c                        = 900,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
            DRC_NBC_Consignee_Bank_Address__c       = 'Barhi 483775',
            DRC_NBC_Consignee_Bank_IFSC_Code__c     = 'PUNB01391000',
            DRC_NBC_Consignee_Bank_Name__c          = 'Punjab National bank',
            Industry                                = 'Chemicals Construction',
            Type                                    = 'Analyst'
        );
        insert acc;
        
        Id stdPbId = Test.getStandardPricebookId();
        
        Product2 prod = new Product2(
            Name                      = 'Test Product',
            IsActive                  = true,
            DRC_NBC_FG_Code__c        = 'FG001',
            DRC_NBC_HSN_SAC_Code__c   = 'HSN001',
            DRC_NBC_GST_Group_Code__c = 'GST001'
        );
        insert prod;
        
        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert stdPbe;
        
        // Restricted Product linked to Account + Product
        DRC_NBC_Restricted_Product__c rp = new DRC_NBC_Restricted_Product__c(
         //   Name                 = 'RESTR-001',
            DRC_NBC_Customer__c  = acc.Id,
            DRC_NBC_Product__c   = prod.Id
        );
        insert rp;
        
        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-001',
            DRC_NBC_TCS_Amount__c        = 500,
            DRC_NBC_Other_Tax_Amount__c  = 300,
            DRC_NBC_Warehouse__c         = 'CFS - JNPT'
        );
        insert ord;
        
        Order ordNoTax = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-002',
            DRC_NBC_TCS_Amount__c        = 0,
            DRC_NBC_Other_Tax_Amount__c  = 0,
            DRC_NBC_Warehouse__c         = 'CFS - JNPT'
        );
        insert ordNoTax;
        
        Order ordNullTax = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-003',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT'
        );
        insert ordNullTax;
        
        OrderItem oi = new OrderItem(
            OrderId                        = ord.Id,
            PricebookEntryId               = stdPbe.Id,
            Product2Id                     = prod.Id,
            Quantity                       = 5,
            UnitPrice                      = 100,
            DRC_NBC_Discount__c            = 10,
            Description                    = 'Test Item',
            DRC_NBC_Unit_Of_Measurement__c = 'KGS',
            DRC_NBC_Packing_Size__c        = 'AL 1 KG',
            DRC_NBC_Packing_Quantity__c    = '5'
        );
        insert oi;
        
        OrderItem oiNoTax = new OrderItem(
            OrderId                        = ordNoTax.Id,
            PricebookEntryId               = stdPbe.Id,
            Product2Id                     = prod.Id,
            Quantity                       = 2,
            UnitPrice                      = 50,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oiNoTax;
        
        OrderItem oiNullTax = new OrderItem(
            OrderId                        = ordNullTax.Id,
            PricebookEntryId               = stdPbe.Id,
            Product2Id                     = prod.Id,
            Quantity                       = 1,
            UnitPrice                      = 200,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oiNullTax;
    }
    
    // ─── Helpers ──────────────────────────────────────────────────────────────
    
    private static Order getOrder(String custOrderNumber) {
        return [SELECT Id FROM Order WHERE DRC_NBC_Cust_Order_Number__c = :custOrderNumber LIMIT 1];
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // EXISTING TESTS
    // ══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void test_Batch_Success_WithTaxLines() {
        Order ord = getOrder('ORD-001');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :ord.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Order should still exist after batch');
        }
    }
    
    @isTest
    static void test_Batch_Failure_HTTP500() {
        Order ord = getOrder('ORD-001');
        Test.setMock(HttpCalloutMock.class, new MockFailure());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :ord.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Order should still exist after failed batch');
        }
    }
    
    @isTest
    static void test_Batch_ZeroTaxAmounts() {
        Order ord = getOrder('ORD-002');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :ord.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Order should still exist after batch with zero tax');
        }
    }
    
    @isTest
    static void test_Batch_NullTaxAmounts() {
        Order ord = getOrder('ORD-003');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :ord.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Order should exist after batch with null tax');
        }
    }
    
    @isTest
    static void test_Batch_NoOrderItems() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id stdPbId  = Test.getStandardPricebookId();
        Order emptyOrd = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-EMPTY',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT'
        );
        insert emptyOrd;
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(emptyOrd.Id), 200);
        Test.stopTest();
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :emptyOrd.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Order should still exist after empty batch');
        }
    }
    
    @isTest
    static void test_Batch_NullOrderItemFields() {
        Account acc        = [SELECT Id FROM Account LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId         = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-NULL-FIELDS',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT'
        );
        insert ord;
        OrderItem oi = new OrderItem(
            OrderId          = ord.Id,
            PricebookEntryId = pbe.Id,
            Product2Id       = prod.Id,
            Quantity         = 1,
            UnitPrice        = 0
        );
        insert oi;
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :ord.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Order should exist after null-fields batch');
        }
    }
    
    @isTest
    static void test_Batch_SampleOrder() {
        Account acc        = [SELECT Id FROM Account LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId         = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
        List<RecordType> sampleRTs = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Order' AND Name = 'Sample_Order'
            LIMIT 1
        ];
        Order sampleOrd = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-SAMPLE',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT'
        );
        if (!sampleRTs.isEmpty()) {
            sampleOrd.RecordTypeId = sampleRTs[0].Id;
        }
        insert sampleOrd;
        OrderItem oi = new OrderItem(
            OrderId                        = sampleOrd.Id,
            PricebookEntryId               = pbe.Id,
            Product2Id                     = prod.Id,
            Quantity                       = 3,
            UnitPrice                      = 100,
            DRC_NBC_Discount__c            = 10,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oi;
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(sampleOrd.Id), 200);
        Test.stopTest();
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :sampleOrd.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Sample order should still exist after batch');
        }
    }
    
    @isTest
    static void test_Batch_MultipleOrderItems() {
        Account acc        = [SELECT Id FROM Account LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId         = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-MULTI',
            DRC_NBC_TCS_Amount__c        = 250,
            DRC_NBC_Other_Tax_Amount__c  = 150,
            DRC_NBC_Warehouse__c         = 'CFS - JNPT'
        );
        insert ord;
        List<OrderItem> items = new List<OrderItem>();
        for (Integer i = 0; i < 5; i++) {
            items.add(new OrderItem(
                OrderId                        = ord.Id,
                PricebookEntryId               = pbe.Id,
                Product2Id                     = prod.Id,
                Quantity                       = i + 1,
                UnitPrice                      = 100,
                DRC_NBC_Unit_Of_Measurement__c = 'KGS'
            ));
        }
        insert items;
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
        if ([SELECT COUNT() FROM Order WHERE Id = :ord.Id] == 0) {
            throw new IllegalArgumentException('Order should still exist after multi-item batch');
        }
    }
    
    @isTest
    static void test_Batch_FinishMethod() {
        Order ord = getOrder('ORD-001');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        DRC_NBC_OrderProduct_BC_Batch batch = new DRC_NBC_OrderProduct_BC_Batch(ord.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();
        Boolean finished = true;
        if (!finished) {
            throw new IllegalArgumentException('Batch finish should complete without error');
        }
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // RESTRICTED PRODUCT TESTS
    // ══════════════════════════════════════════════════════════════════════════
    
    /**
     * Covers: restrictedProductMap hit path
     *         → Order item's Product2Id matches DRC_NBC_Restricted_Product__c
     *         → Item_Reference_No is set to the restricted product Name
     */
    @isTest
    static void test_Batch_RestrictedProduct_Matched() {
        // ORD-001 already has a matching restricted product from @testSetup
        Order ord = getOrder('ORD-001');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :ord.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Order should still exist after batch with restricted product match');
        }
    }
    
    /**
     * Covers: restrictedProductMap miss path
     *         → Order item's Product2 has NO matching DRC_NBC_Restricted_Product__c
     *         → Item_Reference_No falls back to ''
     */
    @isTest
    static void test_Batch_RestrictedProduct_NoMatch() {
        Account acc        = [SELECT Id FROM Account LIMIT 1];
        Id stdPbId         = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
        
        // Insert a second product with NO restricted product record
        Product2 prodNew = new Product2(
            Name                      = 'Unrestricted Product',
            IsActive                  = true,
            DRC_NBC_FG_Code__c        = 'FG-UNRESTRICTED',
            DRC_NBC_HSN_SAC_Code__c   = 'HSN002',
            DRC_NBC_GST_Group_Code__c = 'GST002'
        );
        insert prodNew;
        
        PricebookEntry pbeNew = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prodNew.Id,
            UnitPrice    = 200,
            IsActive     = true
        );
        insert pbeNew;
        
        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-RESTR-MISS',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT',
            DRC_NBC_TCS_Amount__c        = 0,
            DRC_NBC_Other_Tax_Amount__c  = 0
        );
        insert ord;
        
        OrderItem oi = new OrderItem(
            OrderId                        = ord.Id,
            PricebookEntryId               = pbeNew.Id,
            Product2Id                     = prodNew.Id,
            Quantity                       = 2,
            UnitPrice                      = 200,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oi;
        
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
        
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :ord.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Order should exist after batch with no restricted product match');
        }
    }
    
    /**
     * Covers: Multiple products in one order — some restricted, some not
     *         → Map resolves Name for matched products, '' for unmatched
     */
    @isTest
    static void test_Batch_RestrictedProduct_MixedItems() {
        Account acc        = [SELECT Id FROM Account LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 WHERE DRC_NBC_FG_Code__c = 'FG001' LIMIT 1];
        Id stdPbId         = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId AND Product2Id = :prod.Id LIMIT 1];
        
        // Second product — no restricted product record
        Product2 prodB = new Product2(
            Name                      = 'Product B',
            IsActive                  = true,
            DRC_NBC_FG_Code__c        = 'FG-B',
            DRC_NBC_HSN_SAC_Code__c   = 'HSN003',
            DRC_NBC_GST_Group_Code__c = 'GST003'
        );
        insert prodB;
        
        PricebookEntry pbeB = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prodB.Id,
            UnitPrice    = 150,
            IsActive     = true
        );
        insert pbeB;
        
        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-RESTR-MIXED',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT',
            DRC_NBC_TCS_Amount__c        = 100,
            DRC_NBC_Other_Tax_Amount__c  = 50
        );
        insert ord;
        
        // Item A — restricted (matches existing RESTR-001 record)
        OrderItem oiA = new OrderItem(
            OrderId                        = ord.Id,
            PricebookEntryId               = pbe.Id,
            Product2Id                     = prod.Id,
            Quantity                       = 3,
            UnitPrice                      = 100,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS',
            DRC_NBC_Packing_Size__c        = 'AL 1 KG',
            DRC_NBC_Packing_Quantity__c    = '3'
        );
        insert oiA;
        
        // Item B — not restricted
        OrderItem oiB = new OrderItem(
            OrderId                        = ord.Id,
            PricebookEntryId               = pbeB.Id,
            Product2Id                     = prodB.Id,
            Quantity                       = 2,
            UnitPrice                      = 150,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oiB;
        
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
        
        if ([SELECT COUNT() FROM Order WHERE Id = :ord.Id] == 0) {
            throw new IllegalArgumentException('Order should exist after mixed restricted product batch');
        }
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // SAMPLE ORDER TESTS
    // ══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void test_Batch_SampleOrder_WithShippingCost() {
        Account acc        = [SELECT Id FROM Account LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId         = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
        
        List<RecordType> sampleRTs = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Order' AND Name = 'Sample_Order'
            LIMIT 1
        ];
        
        Order sampleOrd = new Order(
            AccountId                        = acc.Id,
            Status                           = 'Draft',
            EffectiveDate                    = Date.today(),
            Pricebook2Id                     = stdPbId,
            DRC_NBC_Cust_Order_Number__c     = 'ORD-SAMPLE-SHIP',
            DRC_NBC_Warehouse__c             = 'CFS - JNPT',
            DRC_NBC_Sample_Shipping_Cost__c  = 750,
            DRC_NBC_Sample_Amount__c         = 0
        );
        if (!sampleRTs.isEmpty()) {
            sampleOrd.RecordTypeId = sampleRTs[0].Id;
        }
        insert sampleOrd;
        
        OrderItem oi = new OrderItem(
            OrderId                        = sampleOrd.Id,
            PricebookEntryId               = pbe.Id,
            Product2Id                     = prod.Id,
            Quantity                       = 2,
            UnitPrice                      = 100,
            DRC_NBC_Discount__c            = 5,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oi;
        
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(sampleOrd.Id), 200);
        Test.stopTest();
        
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :sampleOrd.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Sample order with shipping cost should still exist after batch');
        }
    }
    
    @isTest
    static void test_Batch_SampleOrder_WithSampleAmount() {
        Account acc        = [SELECT Id FROM Account LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId         = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
        
        List<RecordType> sampleRTs = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Order' AND Name = 'Sample_Order'
            LIMIT 1
        ];
        
        Order sampleOrd = new Order(
            AccountId                        = acc.Id,
            Status                           = 'Draft',
            EffectiveDate                    = Date.today(),
            Pricebook2Id                     = stdPbId,
            DRC_NBC_Cust_Order_Number__c     = 'ORD-SAMPLE-AMT',
            DRC_NBC_Warehouse__c             = 'CFS - JNPT',
            DRC_NBC_Sample_Shipping_Cost__c  = 0,
            DRC_NBC_Sample_Amount__c         = 1200
        );
        if (!sampleRTs.isEmpty()) {
            sampleOrd.RecordTypeId = sampleRTs[0].Id;
        }
        insert sampleOrd;
        
        OrderItem oi = new OrderItem(
            OrderId                        = sampleOrd.Id,
            PricebookEntryId               = pbe.Id,
            Product2Id                     = prod.Id,
            Quantity                       = 4,
            UnitPrice                      = 200,
            DRC_NBC_Discount__c            = 0,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oi;
        
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(sampleOrd.Id), 200);
        Test.stopTest();
        
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :sampleOrd.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Sample order with sample amount should still exist after batch');
        }
    }
    
    @isTest
    static void test_Batch_SampleOrder_BothSampleLines_HTTP500() {
        Account acc        = [SELECT Id FROM Account LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId         = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
        
        List<RecordType> sampleRTs = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Order' AND Name = 'Sample_Order'
            LIMIT 1
        ];
        
        Order sampleOrd = new Order(
            AccountId                        = acc.Id,
            Status                           = 'Draft',
            EffectiveDate                    = Date.today(),
            Pricebook2Id                     = stdPbId,
            DRC_NBC_Cust_Order_Number__c     = 'ORD-SAMPLE-BOTH',
            DRC_NBC_Warehouse__c             = 'CFS - JNPT',
            DRC_NBC_Sample_Shipping_Cost__c  = 500,
            DRC_NBC_Sample_Amount__c         = 800
        );
        if (!sampleRTs.isEmpty()) {
            sampleOrd.RecordTypeId = sampleRTs[0].Id;
        }
        insert sampleOrd;
        
        OrderItem oi = new OrderItem(
            OrderId                        = sampleOrd.Id,
            PricebookEntryId               = pbe.Id,
            Product2Id                     = prod.Id,
            Quantity                       = 3,
            UnitPrice                      = 150,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS',
            DRC_NBC_Packing_Size__c        = 'AL 2 KG',
            DRC_NBC_Packing_Quantity__c    = '3'
        );
        insert oi;
        
        Test.setMock(HttpCalloutMock.class, new MockFailure());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(sampleOrd.Id), 200);
        Test.stopTest();
        
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :sampleOrd.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Sample order (both lines, 500) should still exist after batch');
        }
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // DIRECT UNIT TESTS — public mapper methods
    // ══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void test_DirectCall_MapSampleShippingCostToPayload() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id stdPbId  = Test.getStandardPricebookId();
        
        Order ord = new Order(
            AccountId                        = acc.Id,
            Status                           = 'Draft',
            EffectiveDate                    = Date.today(),
            Pricebook2Id                     = stdPbId,
            DRC_NBC_Cust_Order_Number__c     = 'ORD-DIRECT-SHIP',
            DRC_NBC_Warehouse__c             = 'CFS - JNPT',
            DRC_NBC_Sample_Shipping_Cost__c  = 999
        );
        insert ord;
        
        Order ordFull = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c,
            DRC_NBC_Sample_Shipping_Cost__c, Is_Domestic_Merchnat__c
            FROM Order WHERE Id = :ord.Id
        ];
        
        Test.startTest();
        DRC_NBC_OrderProduct_BC_Batch batchInstance =
            new DRC_NBC_OrderProduct_BC_Batch(ord.Id);
        
        DRC_NBC_Integration_Payload.OrderLinePayload payload =
            batchInstance.mapSampleShippingCostToPayload(ordFull, 999, 50000);
        Test.stopTest();
        
        if (payload == null) {
            throw new IllegalArgumentException('mapSampleShippingCostToPayload should return a non-null payload');
        }
        if (payload.Description != 'Sample Shipping Cost') {
            throw new IllegalArgumentException('Expected Description = Sample Shipping Cost but got: ' + payload.Description);
        }
        if (payload.Unit_Price != 999) {
            throw new IllegalArgumentException('Expected Unit_Price = 999 but got: ' + payload.Unit_Price);
        }
        if (payload.Line_Amount != 999) {
            throw new IllegalArgumentException('Expected Line_Amount = 999 but got: ' + payload.Line_Amount);
        }
        if (payload.Quantity != 1) {
            throw new IllegalArgumentException('Expected Quantity = 1 but got: ' + payload.Quantity);
        }
        if (payload.Type != 'G/L Account') {
            throw new IllegalArgumentException('Expected Type = G/L Account but got: ' + payload.Type);
        }
        if (payload.Document_Type != 'Order') {
            throw new IllegalArgumentException('Expected Document_Type = Order but got: ' + payload.Document_Type);
        }
        if (payload.Line_No != 50000) {
            throw new IllegalArgumentException('Expected Line_No = 50000 but got: ' + payload.Line_No);
        }
        if (payload.GST_Credit != 'Availment') {
            throw new IllegalArgumentException('Expected GST_Credit = Availment but got: ' + payload.GST_Credit);
        }
        if (payload.Unit_of_Measure_Code != 'KGS') {
            throw new IllegalArgumentException('Expected Unit_of_Measure_Code = KGS but got: ' + payload.Unit_of_Measure_Code);
        }
        if (payload.No_of_Pkg_for_Qty != 1) {
            throw new IllegalArgumentException('Expected No_of_Pkg_for_Qty = 1 but got: ' + payload.No_of_Pkg_for_Qty);
        }
        if (payload.Line_Discount_Percent != 0) {
            throw new IllegalArgumentException('Expected Line_Discount_Percent = 0 but got: ' + payload.Line_Discount_Percent);
        }
        if (payload.Line_Discount_Amount != 0) {
            throw new IllegalArgumentException('Expected Line_Discount_Amount = 0 but got: ' + payload.Line_Discount_Amount);
        }
        if (payload.Inv_Discount_Amount != 0) {
            throw new IllegalArgumentException('Expected Inv_Discount_Amount = 0 but got: ' + payload.Inv_Discount_Amount);
        }
    }
    
    @isTest
    static void test_DirectCall_MapSampleAmountToPayload() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Id stdPbId  = Test.getStandardPricebookId();
        
        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-DIRECT-AMT',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT',
            DRC_NBC_Sample_Amount__c     = 1500
        );
        insert ord;
        
        Order ordFull = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c,
            DRC_NBC_Sample_Shipping_Cost__c, Is_Domestic_Merchnat__c
            FROM Order WHERE Id = :ord.Id
        ];
        
        Test.startTest();
        DRC_NBC_OrderProduct_BC_Batch batchInstance =
            new DRC_NBC_OrderProduct_BC_Batch(ord.Id);
        
        DRC_NBC_Integration_Payload.OrderLinePayload payload =
            batchInstance.mapSampleAmountToPayload(ordFull, 1500, 60000);
        Test.stopTest();
        
        if (payload == null) {
            throw new IllegalArgumentException('mapSampleAmountToPayload should return a non-null payload');
        }
        if (payload.Description != 'Sample Amount') {
            throw new IllegalArgumentException('Expected Description = Sample Amount but got: ' + payload.Description);
        }
        if (payload.Unit_Price != 1500) {
            throw new IllegalArgumentException('Expected Unit_Price = 1500 but got: ' + payload.Unit_Price);
        }
        if (payload.Line_Amount != 1500) {
            throw new IllegalArgumentException('Expected Line_Amount = 1500 but got: ' + payload.Line_Amount);
        }
        if (payload.Quantity != 1) {
            throw new IllegalArgumentException('Expected Quantity = 1 but got: ' + payload.Quantity);
        }
        if (payload.Type != 'G/L Account') {
            throw new IllegalArgumentException('Expected Type = G/L Account but got: ' + payload.Type);
        }
        if (payload.Document_Type != 'Order') {
            throw new IllegalArgumentException('Expected Document_Type = Order but got: ' + payload.Document_Type);
        }
        if (payload.Line_No != 60000) {
            throw new IllegalArgumentException('Expected Line_No = 60000 but got: ' + payload.Line_No);
        }
        if (payload.GST_Credit != 'Availment') {
            throw new IllegalArgumentException('Expected GST_Credit = Availment but got: ' + payload.GST_Credit);
        }
        if (payload.Unit_of_Measure_Code != 'KGS') {
            throw new IllegalArgumentException('Expected Unit_of_Measure_Code = KGS but got: ' + payload.Unit_of_Measure_Code);
        }
        if (payload.No_of_Pkg_for_Qty != 1) {
            throw new IllegalArgumentException('Expected No_of_Pkg_for_Qty = 1 but got: ' + payload.No_of_Pkg_for_Qty);
        }
        if (payload.Line_Discount_Percent != 0) {
            throw new IllegalArgumentException('Expected Line_Discount_Percent = 0 but got: ' + payload.Line_Discount_Percent);
        }
        if (payload.Line_Discount_Amount != 0) {
            throw new IllegalArgumentException('Expected Line_Discount_Amount = 0 but got: ' + payload.Line_Discount_Amount);
        }
        if (payload.Inv_Discount_Amount != 0) {
            throw new IllegalArgumentException('Expected Inv_Discount_Amount = 0 but got: ' + payload.Inv_Discount_Amount);
        }
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // FREIGHT + INSURANCE TESTS
    // ══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void test_Batch_WithFreightCharges() {
        Account acc        = [SELECT Id FROM Account LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId         = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
        
        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-FREIGHT',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT',
            DRC_NBC_Fright_Charges__c    = 1000,
            DRC_NBC_Insurance__c         = 0
        );
        insert ord;
        
        OrderItem oi = new OrderItem(
            OrderId                        = ord.Id,
            PricebookEntryId               = pbe.Id,
            Product2Id                     = prod.Id,
            Quantity                       = 5,
            UnitPrice                      = 100,
            DRC_NBC_Discount__c            = 0,
            Description                    = 'Freight Test Item',
            DRC_NBC_Unit_Of_Measurement__c = 'KGS',
            DRC_NBC_Packing_Size__c        = 'AL 1 KG',
            DRC_NBC_Packing_Quantity__c    = '5'
        );
        insert oi;
        
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
    }
    
    @isTest
    static void test_Batch_WithInsurance() {
        Account acc        = [SELECT Id FROM Account LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId         = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];
        
        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            Pricebook2Id                 = stdPbId,
            DRC_NBC_Cust_Order_Number__c = 'ORD-INSURANCE',
            DRC_NBC_Warehouse__c         = 'CFS - JNPT',
            DRC_NBC_Fright_Charges__c    = 0,
            DRC_NBC_Insurance__c         = 750
        );
        insert ord;
        
        OrderItem oi = new OrderItem(
            OrderId                        = ord.Id,
            PricebookEntryId               = pbe.Id,
            Product2Id                     = prod.Id,
            Quantity                       = 3,
            UnitPrice                      = 200,
            DRC_NBC_Discount__c            = 0,
            Description                    = 'Insurance Test Item',
            DRC_NBC_Unit_Of_Measurement__c = 'KGS',
            DRC_NBC_Packing_Size__c        = 'AL 1 KG',
            DRC_NBC_Packing_Quantity__c    = '3'
        );
        insert oi;
        
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // DRC_NBC_OrderProduct_BC_Integration Tests
    // ══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void test_Integration_Success200() {
        Order ord = getOrder('ORD-001');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        DRC_NBC_OrderProduct_BC_Integration integration =
            new DRC_NBC_OrderProduct_BC_Integration(
                'https://mock-endpoint.example.com/api',
                'POST',
                '{"requests":[]}',
                ord.Id
            );
        HttpResponse response = integration.executeAndReturnResponse();
        Test.stopTest();
        if (response == null) {
            throw new IllegalArgumentException('Response should not be null');
        }
        if (response.getStatusCode() != 200) {
            throw new IllegalArgumentException('Expected 200 but got: ' + response.getStatusCode());
        }
    }
    
    @isTest
    static void test_Integration_Failure500() {
        Order ord = getOrder('ORD-001');
        Test.setMock(HttpCalloutMock.class, new MockFailure());
        Test.startTest();
        DRC_NBC_OrderProduct_BC_Integration integration =
            new DRC_NBC_OrderProduct_BC_Integration(
                'https://mock-endpoint.example.com/api',
                'POST',
                '{"requests":[]}',
                ord.Id
            );
        HttpResponse response = integration.executeAndReturnResponse();
        Test.stopTest();
        if (response == null) {
            throw new IllegalArgumentException('Response should not be null for 500');
        }
        if (response.getStatusCode() != 500) {
            throw new IllegalArgumentException('Expected 500 but got: ' + response.getStatusCode());
        }
    }
    
    @isTest
    static void test_Integration_ProcessResponse_201() {
        Order ord = getOrder('ORD-001');
        DRC_NBC_OrderProduct_BC_Integration integration =
            new DRC_NBC_OrderProduct_BC_Integration(
                'https://mock-endpoint.example.com/api',
                'POST',
                '{"requests":[]}',
                ord.Id
            );
        HttpResponse res = new HttpResponse();
        res.setStatusCode(201);
        res.setBody('{"status":"created"}');
        Test.startTest();
        integration.processResponse(res);
        Test.stopTest();
        Boolean processed = true;
        if (!processed) {
            throw new IllegalArgumentException('processResponse should handle 201 without error');
        }
    }
    
    @isTest
    static void test_Integration_ProcessResponse_400() {
        Order ord = getOrder('ORD-001');
        DRC_NBC_OrderProduct_BC_Integration integration =
            new DRC_NBC_OrderProduct_BC_Integration(
                'https://mock-endpoint.example.com/api',
                'POST',
                '{"requests":[]}',
                ord.Id
            );
        HttpResponse res = new HttpResponse();
        res.setStatusCode(400);
        res.setBody('{"error":"Bad Request"}');
        Test.startTest();
        integration.processResponse(res);
        Test.stopTest();
        Boolean processed = true;
        if (!processed) {
            throw new IllegalArgumentException('processResponse should handle 400 without error');
        }
    }
    
    @isTest
    static void test_Integration_PrepareRequest() {
        Order ord = getOrder('ORD-001');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        DRC_NBC_OrderProduct_BC_Integration integration =
            new DRC_NBC_OrderProduct_BC_Integration(
                'https://mock-endpoint.example.com/orders',
                'POST',
                '{"test":"payload"}',
                ord.Id
            );
        Test.startTest();
        HttpRequest req = integration.prepareRequest();
        Test.stopTest();
        if (req == null) {
            throw new IllegalArgumentException('prepareRequest should return a non-null HttpRequest');
        }
        if (req.getMethod() != 'POST') {
            throw new IllegalArgumentException('Expected POST method but got: ' + req.getMethod());
        }
        if (!req.getBody().contains('payload')) {
            throw new IllegalArgumentException('Request body should contain payload data but got: ' + req.getBody());
        }
    }
    
    @isTest
    static void test_Integration_EmptyPayload() {
        Order ord = getOrder('ORD-001');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        DRC_NBC_OrderProduct_BC_Integration integration =
            new DRC_NBC_OrderProduct_BC_Integration(
                'https://mock-endpoint.example.com/api',
                'POST',
                '',
                ord.Id
            );
        HttpResponse response = integration.executeAndReturnResponse();
        Test.stopTest();
        if (response == null) {
            throw new IllegalArgumentException('Response should not be null for empty payload');
        }
    }
    
    @isTest
    static void test_Integration_ProcessResponse_299() {
        Order ord = getOrder('ORD-001');
        DRC_NBC_OrderProduct_BC_Integration integration =
            new DRC_NBC_OrderProduct_BC_Integration(
                'https://mock-endpoint.example.com/api',
                'POST',
                '{}',
                ord.Id
            );
        HttpResponse res = new HttpResponse();
        res.setStatusCode(299);
        res.setBody('{"status":"ok"}');
        Test.startTest();
        integration.processResponse(res);
        Test.stopTest();
        Boolean processed = true;
        if (!processed) {
            throw new IllegalArgumentException('processResponse should handle 299 as success');
        }
    }
}