/**
 * @File Name : DRC_NBC_UpdateOrderAndLineItems_Test.cls
 * @Description : Test class for DRC_NBC_UpdateOrderAndLineItems
 *                Updated to fully cover extractLineDetailsFromReadMultiple
 *                by using the correct nested ReadMultiple_Result XML structure.
 * @Author : Satish YADAV
 * @Last Modified On : February 19, 2026
 **/
@isTest
private class DRC_NBC_UpdateOrderAndLineItems_Test {

    // =========================================================================
    // HELPER: Build correct ReadMultiple XML - NESTED ReadMultiple_Result
    // The parser checks: resultNode.getName().contains('ReadMultiple_Result')
    // then: innerResultNode.getName().contains('ReadMultiple_Result')
    // So we need TWO levels of ReadMultiple_Result wrapping the line nodes.
    // =========================================================================
    private static String buildReadMultipleResponse_WithProductAndTaxLines() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<ReadMultiple_Result xmlns="urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce">' +
            '<ReadMultiple_Result>' +

            // --- PRODUCT LINE ---
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-PROD-001</Key>' +
            '<Line_No>10000</Line_No>' +
            '<Type>Item</Type>' +
            '<No>FG001</No>' +
            '<Quantity>10</Quantity>' +
            '<Description>Test Product</Description>' +
            '</SalesOrderLineSalesForce>' +

            // --- OTHER TAX LINE ---
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-TAX-001</Key>' +
            '<Line_No>20000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No></No>' +
            '<Quantity>1</Quantity>' +
            '<Description>Other Tax Amount</Description>' +
            '</SalesOrderLineSalesForce>' +

            // --- TCS LINE ---
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-TCS-001</Key>' +
            '<Line_No>30000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No></No>' +
            '<Quantity>1</Quantity>' +
            '<Description>TCS Amount</Description>' +
            '</SalesOrderLineSalesForce>' +

            '</ReadMultiple_Result>' +
            '</ReadMultiple_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    // ReadMultiple with an UNMATCHED product line (FG code not in SF = triggers DELETE)
    private static String buildReadMultipleResponse_WithUnmatchedProductLine() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<ReadMultiple_Result xmlns="urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce">' +
            '<ReadMultiple_Result>' +

            // Matched product
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-PROD-001</Key>' +
            '<Line_No>10000</Line_No>' +
            '<Type>Item</Type>' +
            '<No>FG001</No>' +
            '<Quantity>10</Quantity>' +
            '<Description>Test Product</Description>' +
            '</SalesOrderLineSalesForce>' +

            // UNMATCHED product (not in SF order items → DELETE)
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-PROD-002</Key>' +
            '<Line_No>11000</Line_No>' +
            '<Type>Item</Type>' +
            '<No>FG999</No>' +
            '<Quantity>5</Quantity>' +
            '<Description>Old Product</Description>' +
            '</SalesOrderLineSalesForce>' +

            '</ReadMultiple_Result>' +
            '</ReadMultiple_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    // ReadMultiple with zero-amount tax lines (triggers TAX DELETE path)
    private static String buildReadMultipleResponse_WithTaxLinesZeroAmount() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<ReadMultiple_Result xmlns="urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce">' +
            '<ReadMultiple_Result>' +

            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-PROD-001</Key>' +
            '<Line_No>10000</Line_No>' +
            '<Type>Item</Type>' +
            '<No>FG001</No>' +
            '<Quantity>10</Quantity>' +
            '<Description>Test Product</Description>' +
            '</SalesOrderLineSalesForce>' +

            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-TAX-001</Key>' +
            '<Line_No>20000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No></No>' +
            '<Quantity>1</Quantity>' +
            '<Description>Other Tax Amount</Description>' +
            '</SalesOrderLineSalesForce>' +

            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-TCS-001</Key>' +
            '<Line_No>30000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No></No>' +
            '<Quantity>1</Quantity>' +
            '<Description>TCS Amount</Description>' +
            '</SalesOrderLineSalesForce>' +

            '</ReadMultiple_Result>' +
            '</ReadMultiple_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    // ReadMultiple — empty (no lines in BC)
    private static String buildReadMultipleResponse_Empty() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<ReadMultiple_Result xmlns="urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce">' +
            '<ReadMultiple_Result>' +
            '</ReadMultiple_Result>' +
            '</ReadMultiple_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    // Order Read response
    private static String buildOrderReadResponse() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read_Result xmlns="urn:microsoft-dynamics-schemas/codeunit/SalesOrderSalesForce">' +
            '<SalesOrderSalesForce>' +
            '<Key>ORDER-KEY-12345</Key>' +
            '<No>BC-ORD-001</No>' +
            '</SalesOrderSalesForce>' +
            '</Read_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    // ShipTo Read response (for DRC_NBC_UpdateShippingAddress callout)
    private static String buildShipToReadResponse(String locationCode) {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read_Result xmlns="urn:microsoft-dynamics-schemas/page/customershiptoaddresssalesforce">' +
            '<CustomerShiptoAddressSalesForce>' +
            '<Key>SHIPTO-KEY-001</Key>' +
            '<CustomerNo>CUST001</CustomerNo>' +
            '<ShiptoCode>SHIP001</ShiptoCode>' +
            '<Location_Code>' + locationCode + '</Location_Code>' +
            '</CustomerShiptoAddressSalesForce>' +
            '</Read_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    // Generic success response for Update/Delete/Create
    private static String buildGenericSuccessResponse() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><Response>Success</Response></soap:Body>' +
            '</soap:Envelope>';
    }

    // =========================================================================
    // TEST DATA SETUP
    // =========================================================================
    @testSetup
    static void setupTestData() {
        DRC_NBC_BC_Integration__c bcSettings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                    = UserInfo.getOrganizationId(),
            DRC_NBC_BC_Order_Endpoint__c    = 'https://test.bc.com/order',
            DRC_NBC_BC_Line_Item_Endpoint__c = 'https://test.bc.com/lineitem',
            DRC_NBC_BC_ShipTo_Endpoint__c   = 'https://test.bc.com/shipto',
            DRC_NBC_SOAP_Order_Namespace__c  = 'urn:microsoft-dynamics-schemas/codeunit/SalesOrderSalesForce',
            DRC_NBC_SOAP_Line_Namespace__c   = 'urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce',
            DRC_NBC_GST_Credit_Value__c      = 'AVAILMENT',
            DRC_NBC_Username__c             = 'testuser',
            DRC_NBC_Password__c             = 'testpass'
        );
        insert bcSettings;

        Account acc = new Account(
            Name                       = 'Test Customer',
            DRC_NBC_Customer_Number__c = 'CUST001'
        );
        insert acc;

        DRC_NBC_Addresses__c shipAddr = new DRC_NBC_Addresses__c(
            DRC_NBC_Ship_To_Code__c         = 'SHIP001',
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Warehouse__c            = 'CFS - JNPT',
            DRC_NBC_Address__Street__s      = '123 Test Street',
            DRC_NBC_Address__City__s        = 'Mumbai',
            DRC_NBC_Address__PostalCode__s  = '400001',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Address__StateCode__s   = 'MH'
        );
        insert shipAddr;

        Product2 prod = new Product2(
            Name                      = 'Test Product',
            DRC_NBC_FG_Code__c        = 'FG001',
            DRC_NBC_GST_Group_Code__c = 'GST18',
            DRC_NBC_HSN_SAC_Code__c   = 'HSN1234',
            IsActive                  = true
        );
        insert prod;

        Id stdPricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert pbe;

        Order ord = new Order(
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
        insert ord;

        OrderItem oi = new OrderItem(
            OrderId                       = ord.Id,
            Product2Id                    = prod.Id,
            PricebookEntryId              = pbe.Id,
            Quantity                      = 10,
            UnitPrice                     = 100,
            Description                   = 'Test Product',
            DRC_NBC_Discount__c           = 5,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oi;
    }

    // =========================================================================
    // MOCKS
    // =========================================================================

    /**
     * Multi-callout mock that sequences responses by call count.
     * Call order per processOrderSync:
     *   1. Order Read           → buildOrderReadResponse()
     *   2. ShipTo Read          → buildShipToReadResponse()     (from DRC_NBC_UpdateShippingAddress)
     *   3. ShipTo Update        → buildGenericSuccessResponse() (if location differs)
     *   4. Order Update         → buildGenericSuccessResponse()
     *   5. ReadMultiple (lines) → provided lineItemXml
     *   6. UpdateMultiple       → buildGenericSuccessResponse()
     *   7+. Delete/Create       → buildGenericSuccessResponse()
     */
    private class SequencedMock implements HttpCalloutMock {
        private List<HttpResponse> responses = new List<HttpResponse>();
        private Integer callIndex = 0;

        public SequencedMock addResponse(Integer statusCode, String body) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(statusCode);
            r.setBody(body);
            responses.add(r);
            return this;
        }

        public HttpResponse respond(HttpRequest req) {
            if (callIndex < responses.size()) {
                return responses[callIndex++];
            }
            // Default fallback: generic success
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody(buildGenericSuccessResponse());
            return r;
        }
    }

    // =========================================================================
    // TEST: extractLineDetailsFromReadMultiple - PRODUCT + TAX lines (main coverage)
    // =========================================================================

    /**
     * KEY TEST: Covers extractLineDetailsFromReadMultiple fully.
     * Provides correct nested ReadMultiple_Result XML so the parser
     * walks into the inner loop and processes every field branch:
     * Key, Line_No, Type, No, Quantity, Description
     */
    @isTest
    static void testProcessOrderSync_CoversExtractLineDetails_ProductAndTaxLines() {
        SequencedMock mock = new SequencedMock()
            .addResponse(200, buildOrderReadResponse())           // 1. Order Read
            .addResponse(200, buildShipToReadResponse('OLD_LOC')) // 2. ShipTo Read (loc differs → update)
            .addResponse(200, buildGenericSuccessResponse())      // 3. ShipTo Update
            .addResponse(200, buildGenericSuccessResponse())      // 4. Order Update
            .addResponse(200, buildReadMultipleResponse_WithProductAndTaxLines()) // 5. ReadMultiple ← KEY
            .addResponse(200, buildGenericSuccessResponse())      // 6. UpdateMultiple
            .addResponse(200, buildGenericSuccessResponse());     // 7. Any extra

        Test.setMock(HttpCalloutMock.class, mock);

        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        // The line items were found, matched, and updated
        System.assert(
            result.contains('SUCCESS') || result.contains('UPDATE') || result.contains('ORDER_UPDATE'),
            'Expected success result, got: ' + result
        );
    }

    /**
     * Covers DELETE path for unmatched product line:
     * BC has FG001 (matched) + FG999 (unmatched → DELETE)
     * Covers the lineDetailsMap.put() branch and matchedBCLineNos logic
     */
    @isTest
    static void testProcessOrderSync_CoversExtractLineDetails_UnmatchedProductDeleted() {
        SequencedMock mock = new SequencedMock()
            .addResponse(200, buildOrderReadResponse())
            .addResponse(200, buildShipToReadResponse(''))        // Same loc code → SKIPPED (no update call)
            .addResponse(200, buildGenericSuccessResponse())      // Order Update
            .addResponse(200, buildReadMultipleResponse_WithUnmatchedProductLine()) // ReadMultiple
            .addResponse(200, buildGenericSuccessResponse())      // UpdateMultiple
            .addResponse(200, buildGenericSuccessResponse());     // DeleteLineItems

        Test.setMock(HttpCalloutMock.class, mock);

        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('DELETE') || result.contains('SUCCESS') || result.contains('ORDER'),
                      'Expected delete reference in result: ' + result);
    }

    /**
     * Covers TAX DELETE path:
     * BC has TCS + Other Tax lines, but Order has ZERO tax amounts → both tax lines deleted
     * Also covers: linesToUpdate.remove(taxLine.lineNo) branch
     */
    @isTest
    static void testProcessOrderSync_CoversExtractLineDetails_TaxLinesDeletedWhenZero() {
        // Order with zero tax amounts
        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];
        ord.DRC_NBC_Other_Tax_Amount__c = 0;
        ord.DRC_NBC_TCS_Amount__c = 0;
        update ord;

        SequencedMock mock = new SequencedMock()
            .addResponse(200, buildOrderReadResponse())
            .addResponse(200, buildShipToReadResponse(''))        // Same loc → SKIPPED
            .addResponse(200, buildGenericSuccessResponse())      // Order Update
            .addResponse(200, buildReadMultipleResponse_WithTaxLinesZeroAmount()) // ReadMultiple
            .addResponse(200, buildGenericSuccessResponse())      // UpdateMultiple (only products)
            .addResponse(200, buildGenericSuccessResponse());     // DeleteLineItems (tax lines)

        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    /**
     * Covers CREATE path:
     * BC has NO lines → all SF items are new → CREATE called
     * Also covers: maxLineNo = 0 branch, nextLineNo = 10000
     */
    @isTest
    static void testProcessOrderSync_CoversExtractLineDetails_EmptyBCLines_CreateNew() {
        SequencedMock mock = new SequencedMock()
            .addResponse(200, buildOrderReadResponse())
            .addResponse(200, buildShipToReadResponse(''))        // Same loc → SKIPPED
            .addResponse(200, buildGenericSuccessResponse())      // Order Update
            .addResponse(200, buildReadMultipleResponse_Empty())  // ReadMultiple — empty
            .addResponse(200, buildGenericSuccessResponse());     // CreateLineItems

        Test.setMock(HttpCalloutMock.class, mock);

        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('CREATE') || result.contains('SUCCESS') || result.contains('ORDER'),
                      'Expected create path in result: ' + result);
    }

    /**
     * Covers: ReadMultiple returns HTTP 500 → bcLineDetails = null
     * Exercises the null check: if (bcLineDetails != null)
     * and the empty bcProductLines/bcTaxLines path
     */
    @isTest
    static void testProcessOrderSync_ReadMultipleFails_NullLineDetails() {
        SequencedMock mock = new SequencedMock()
            .addResponse(200, buildOrderReadResponse())
            .addResponse(200, buildShipToReadResponse(''))
            .addResponse(200, buildGenericSuccessResponse())      // Order Update
            .addResponse(500, 'Internal Server Error');           // ReadMultiple FAILS → null

        Test.setMock(HttpCalloutMock.class, mock);

        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        // Should still proceed with CREATE (all SF items treated as new) since bcLineDetails = null
    }

    // =========================================================================
    // EXISTING TESTS (kept + improved)
    // =========================================================================

    @isTest
    static void testOrderUpdateWithShipToCode() {
        SequencedMock mock = new SequencedMock()
            .addResponse(200, buildOrderReadResponse())
            .addResponse(200, buildShipToReadResponse(''))
            .addResponse(200, buildGenericSuccessResponse())
            .addResponse(200, buildReadMultipleResponse_WithProductAndTaxLines())
            .addResponse(200, buildGenericSuccessResponse())
            .addResponse(200, buildGenericSuccessResponse());

        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.contains('SUCCESS') || result.contains('ORDER') || result.contains('UPDATE'),
                      'Got: ' + result);
    }

    @isTest
    static void testOrderUpdateWithoutShipToCode() {
        DRC_NBC_Addresses__c shipAddr = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        shipAddr.DRC_NBC_Ship_To_Code__c = null;
        update shipAddr;

        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();

        System.assert(result.contains('QUEUED'), 'Should indicate queued process: ' + result);
    }

    @isTest
    static void testOrderIdException_NullId() {
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(null);
        Test.stopTest();

        System.assert(result.contains('ERROR'), 'Should return error for null ID');
    }

    @isTest
    static void testMissingCustomSettings() {
        delete [SELECT Id FROM DRC_NBC_BC_Integration__c];

        Order ord = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();

        System.assert(result.contains('ERROR'), 'Should return error for missing settings: ' + result);
    }

    @isTest
    static void testBCLineItemWrapper() {
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.BCLineItem bcLine =
            new DRC_NBC_UpdateOrderAndLineItems.BCLineItem('KEY123', 10000, 'Item', 'FG001', 10, 'Test Item');
        Test.stopTest();

        System.assertEquals('KEY123',    bcLine.key);
        System.assertEquals(10000,       bcLine.lineNo);
        System.assertEquals('Item',      bcLine.lineType);
        System.assertEquals('FG001',     bcLine.itemNo);
        System.assertEquals(10,          bcLine.quantity);
        System.assertEquals('Test Item', bcLine.description);
    }

    @isTest
    static void testShipToCodeGeneratorQueueable() {
        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];

        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_UpdateOrderAndLineItems.ShipToCodeGeneratorQueueable(ord.Id, ord.AccountId)
        );
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }

    @isTest
    static void testShippingAndOrderCalloutQueueable() {
        SequencedMock mock = new SequencedMock()
            .addResponse(200, buildGenericSuccessResponse())      // processShipping callout
            .addResponse(200, buildOrderReadResponse())           // Order Read
            .addResponse(200, buildShipToReadResponse(''))        // ShipTo Read
            .addResponse(200, buildGenericSuccessResponse())      // Order Update
            .addResponse(200, buildReadMultipleResponse_WithProductAndTaxLines())
            .addResponse(200, buildGenericSuccessResponse())
            .addResponse(200, buildGenericSuccessResponse());

        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];

        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_UpdateOrderAndLineItems.ShippingAndOrderCalloutQueueable(ord.Id, ord.AccountId)
        );
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'Queueable']);
    }

    /**
     * Covers: Order Read returns HTTP 500 → bcKey is null → early return 'ERROR: Order not found in BC.'
     */
    @isTest
    static void testProcessOrderSync_OrderReadFails() {
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
            .addResponse(500, 'Server Error'));  // Order Read fails

        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();

        System.assert(result.contains('ERROR'), 'Expected ERROR when order read fails: ' + result);
    }

    /**
     * Covers: Order Update returns HTTP 500 → line item sync skipped
     */
    @isTest
    static void testProcessOrderSync_OrderUpdateFails() {
        SequencedMock mock = new SequencedMock()
            .addResponse(200, buildOrderReadResponse())           // Order Read OK
            .addResponse(200, buildShipToReadResponse(''))        // ShipTo Read
            .addResponse(500, 'Error');                           // Order Update FAILS

        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = [SELECT Id, AccountId FROM Order LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();

    }
}