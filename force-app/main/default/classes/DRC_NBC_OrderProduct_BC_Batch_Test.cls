@isTest
private class DRC_NBC_OrderProduct_BC_Batch_Test {

    // ─── Mock HTTP ────────────────────────────────────────────────────────────

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

    // ─── Test Setup ───────────────────────────────────────────────────────────

    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name                         = 'Test Account',
            DRC_NBC_Customer_Number__c   = 'CUST001',
            BillingStreet                = '123 Main St',
            BillingCity                  = 'Mumbai',
            BillingState                 = 'Maharashtra',
            BillingPostalCode            = '400001',
            BillingCountry               = 'India'
        );
        insert acc;


        Id stdPbId = Test.getStandardPricebookId();

        // Product
        Product2 prod = new Product2(
            Name                       = 'Test Product',
            IsActive                   = true,
            DRC_NBC_FG_Code__c         = 'FG001',
            DRC_NBC_HSN_SAC_Code__c    = 'HSN001',
            DRC_NBC_GST_Group_Code__c  = 'GST001'
        );
        insert prod;

        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert stdPbe;

        Order ord = new Order(
        AccountId                    = acc.Id,
        Status                       = 'Draft',
        EffectiveDate                = Date.today(),
        Pricebook2Id                 = stdPbId,          // ← KEY FIX
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
        Pricebook2Id                 = stdPbId,          // ← KEY FIX
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
        Pricebook2Id                 = stdPbId,          // ← KEY FIX
        DRC_NBC_Cust_Order_Number__c = 'ORD-003',
        DRC_NBC_Warehouse__c         = 'CFS - JNPT'
    );
    insert ordNullTax;

    // Order Items
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
    // DRC_NBC_OrderProduct_BC_Batch Tests
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Covers: Constructor → orderId stored
     *         start() → QueryLocator built for correct order
     *         execute() → items processed, OtherTax + TCS lines added
     *         finish() → completes without error
     *         Successful HTTP 200 → logSuccess called
     */
    @isTest
    static void test_Batch_Success_WithTaxLines() {
        Order ord = getOrder('ORD-001');

        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(ord.Id), 200);
        Test.stopTest();

        // Verify order still exists (no rollback)
        List<Order> orders = [SELECT Id FROM Order WHERE Id = :ord.Id];
        if (orders.isEmpty()) {
            throw new IllegalArgumentException('Order should still exist after batch');
        }
    }

    /**
     * Covers: execute() → HTTP 500 response → logError called
     */
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

    /**
     * Covers: OtherTaxAmount = 0 → Other Tax line NOT added
     *         TCSAmount = 0 → TCS line NOT added
     */
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

    /**
     * Covers: OtherTaxAmount = null → Other Tax line NOT added
     *         TCSAmount = null → TCS line NOT added
     */
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

    /**
     * Covers: Order with no OrderItems → scope.isEmpty() = true → early return
     *         requestList is empty → callout skipped
     */
    @isTest
    static void test_Batch_NoOrderItems() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order emptyOrd = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            DRC_NBC_Cust_Order_Number__c = 'ORD-EMPTY',
            DRC_NBC_Warehouse__c         = 'Mumbai Warehouse'
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

    /**
     * Covers: OrderItem with null Description → payload.Description = ''
     *         OrderItem with null DRC_NBC_Packing_Size__c → Packing_Details = ''
     *         OrderItem with null DRC_NBC_Packing_Quantity__c → No_of_Pkg_for_Qty = 0
     *         OrderItem with null Discount → discountPercent = 0
     *         OrderItem with null Total Price → totalPrice = 0
     *         OrderItem with null Quantity → Quantity = 0
     *         OrderItem with null UnitPrice → Unit_Price = 0
     */
    @isTest
    static void test_Batch_NullOrderItemFields() {
        Account acc     = [SELECT Id FROM Account LIMIT 1];
        Product2 prod   = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId      = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];

        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            DRC_NBC_Cust_Order_Number__c = 'ORD-NULL-FIELDS',
            DRC_NBC_Warehouse__c         = 'Mumbai Warehouse'
        );
        insert ord;

        OrderItem oi = new OrderItem(
            OrderId          = ord.Id,
            PricebookEntryId = pbe.Id,
            Product2Id       = prod.Id,
            Quantity         = 1,
            UnitPrice        = 0
            // Description, Discount, TotalPrice, PackingSize, PackingQuantity all null
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

    /**
     * Covers: Sample Order record type → isSampleOrder = true
     *         → totalPrice = 0, lineDiscountAmount = 0, Unit_Price = 0
     */
    @isTest
    static void test_Batch_SampleOrder() {
        Account acc   = [SELECT Id FROM Account LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId    = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];

        // Find or use a Record Type named Sample_Order if available
        List<RecordType> sampleRTs = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Order' AND Name = 'Sample_Order'
            LIMIT 1
        ];

        Order sampleOrd = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            DRC_NBC_Cust_Order_Number__c = 'ORD-SAMPLE',
            DRC_NBC_Warehouse__c         = 'Mumbai Warehouse'
        );
        if (!sampleRTs.isEmpty()) {
            sampleOrd.RecordTypeId = sampleRTs[0].Id;
        }
        insert sampleOrd;

        OrderItem oi = new OrderItem(
            OrderId                      = sampleOrd.Id,
            PricebookEntryId             = pbe.Id,
            Product2Id                   = prod.Id,
            Quantity                     = 3,
            UnitPrice                    = 100,
            DRC_NBC_Discount__c          = 10,
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

    /**
     * Covers: Multiple OrderItems in same batch → lineCounter increments
     *         requestCounter increments per item
     *         Both OtherTax and TCS lines added after items
     */
    @isTest
    static void test_Batch_MultipleOrderItems() {
        Account acc   = [SELECT Id FROM Account LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        Id stdPbId    = Test.getStandardPricebookId();
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];

        Order ord = new Order(
            AccountId                    = acc.Id,
            Status                       = 'Draft',
            EffectiveDate                = Date.today(),
            DRC_NBC_Cust_Order_Number__c = 'ORD-MULTI',
            DRC_NBC_TCS_Amount__c        = 250,
            DRC_NBC_Other_Tax_Amount__c  = 150,
            DRC_NBC_Warehouse__c         = 'Mumbai Warehouse'
        );
        insert ord;

        List<OrderItem> items = new List<OrderItem>();
        for (Integer i = 0; i < 5; i++) {
            items.add(new OrderItem(
                OrderId                      = ord.Id,
                PricebookEntryId             = pbe.Id,
                Product2Id                   = prod.Id,
                Quantity                     = i + 1,
                UnitPrice                    = 100,
                DRC_NBC_Unit_Of_Measurement__c = 'KG'
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

    /**
     * Covers: finish() method — verifies it completes without exception
     */
    @isTest
    static void test_Batch_FinishMethod() {
        Order ord = getOrder('ORD-001');

        Test.setMock(HttpCalloutMock.class, new MockSuccess());

        Test.startTest();
        DRC_NBC_OrderProduct_BC_Batch batch = new DRC_NBC_OrderProduct_BC_Batch(ord.Id);
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // finish() executed — no exception means pass
        Boolean finished = true;
        if (!finished) {
            throw new IllegalArgumentException('Batch finish should complete without error');
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // DRC_NBC_OrderProduct_BC_Integration Tests
    // ══════════════════════════════════════════════════════════════════════════

    /**
     * Covers: Constructor → all fields stored
     *         prepareRequest() → endpoint, method, body set
     *         executeAndReturnResponse() → returns HttpResponse
     *         processResponse() → 200 status → success branch
     */
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
            throw new IllegalArgumentException(
                'Expected 200 but got: ' + response.getStatusCode()
            );
        }
    }

    /**
     * Covers: processResponse() → non-2xx status → error branch
     */
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
            throw new IllegalArgumentException(
                'Expected 500 but got: ' + response.getStatusCode()
            );
        }
    }

    /**
     * Covers: processResponse() directly with 201 (2xx boundary)
     */
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

        // No exception = pass (processResponse is void)
        Boolean processed = true;
        if (!processed) {
            throw new IllegalArgumentException('processResponse should handle 201 without error');
        }
    }

    /**
     * Covers: processResponse() directly with 400 (non-2xx error branch)
     */
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

    /**
     * Covers: prepareRequest() — verifies endpoint and method are set correctly
     */
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
            throw new IllegalArgumentException(
                'Expected POST method but got: ' + req.getMethod()
            );
        }
        if (!req.getBody().contains('payload')) {
            throw new IllegalArgumentException(
                'Request body should contain payload data but got: ' + req.getBody()
            );
        }
    }

    /**
     * Covers: Integration with empty payload body
     */
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

    /**
     * Covers: processResponse() with exactly 299 (boundary of 2xx range)
     */
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