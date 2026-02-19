/**
* @description Test class for DRC_NBC_OrderDispatchStatusSync REST endpoint
*              and related DRC_NBC_Integration_Utility / DRC_NBC_Integration_Payload
*/
@isTest
private class DRC_NBC_OrderDispatchStatusSync_Test {
    private static Account createTestAccount() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        return acc;
    }
    
    private static Order createTestOrder(Id accountId) {
        Order ord = new Order(
            AccountId    = accountId,
            Status       = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id  = Test.getStandardPricebookId()
        );
        insert ord;
        return ord;
    }
    
    private static void setupRestContext(String jsonBody) {
        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI   = '/services/apexrest/OrderDispatchStatusSync/';
        req.httpMethod   = 'POST';
        req.requestBody  = Blob.valueOf(jsonBody);
        RestContext.request  = req;
        RestContext.response = res;
    }
    @isTest
    static void testValidateOrderStatusPayload_BlankPayload() {
        Test.startTest();
        try {
            DRC_NBC_Integration_Utility.validateOrderStatusPayload('');
            System.assert(false, 'Expected exception not thrown');
        } catch (DRC_NBC_CustomException e) {
            System.assertEquals('Payload cannot be null or empty', e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateOrderStatusPayload_InvalidJson() {
        Test.startTest();
        try {
            DRC_NBC_Integration_Utility.validateOrderStatusPayload('not-valid-json{{{');
            System.assert(false, 'Expected exception not thrown');
        } catch (DRC_NBC_CustomException e) {
            System.assert(e.getMessage().startsWith('Invalid JSON format:'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateOrderStatusPayload_MissingOrderId() {
        String payload = JSON.serialize(new Map<String, Object>{
            'status' => 'Accepted'
                });
        Test.startTest();
        try {
            DRC_NBC_Integration_Utility.validateOrderStatusPayload(payload);
            System.assert(false, 'Expected exception not thrown');
        } catch (DRC_NBC_CustomException e) {
            System.assertEquals('Order ID is mandatory in payload', e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateOrderStatusPayload_MissingStatus() {
        String payload = JSON.serialize(new Map<String, Object>{
            'orderId' => 'someId'
                });
        Test.startTest();
        try {
            DRC_NBC_Integration_Utility.validateOrderStatusPayload(payload);
            System.assert(false, 'Expected exception not thrown');
        } catch (DRC_NBC_CustomException e) {
            System.assertEquals('Order Status is mandatory in payload', e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateOrderStatusPayload_InvalidDateFormat() {
        String payload = JSON.serialize(new Map<String, Object>{
            'orderId'              => 'someId',
                'status'               => 'Activated',
                'expectedDeliveryDate' => 'not-a-date'
                });
        Test.startTest();
        try {
            DRC_NBC_Integration_Utility.validateOrderStatusPayload(payload);
            System.assert(false, 'Expected exception not thrown');
        } catch (DRC_NBC_CustomException e) {
            System.assertEquals('Invalid expectedDeliveryDate format. Use yyyy-MM-dd', e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateOrderStatusPayload_ValidPayload() {
        String payload = JSON.serialize(new Map<String, Object>{
            'orderId'              => 'someId',
                'status'               => 'Activated',
                'expectedDeliveryDate' => '2025-12-31',
                'trackingId'           => 'TRK123',
                'paymentTerms'         => 'NET30',
                'PartiallyShipped'     => true
                });
        Test.startTest();
        DRC_NBC_Integration_Payload.OrderStatusPayload result =
            DRC_NBC_Integration_Utility.validateOrderStatusPayload(payload);
        Test.stopTest();
    }
    
    // ─── REST Endpoint Tests (DRC_NBC_OrderDispatchStatusSync) ───────────────
    
    @isTest
    static void testSyncOrderStatus_BlankBody() {
        setupRestContext('');
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    @isTest
    static void testSyncOrderStatus_InvalidJson() {
        setupRestContext('{invalid-json}');
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    @isTest
    static void testSyncOrderStatus_MissingOrderId() {
        String body = JSON.serialize(new Map<String, Object>{
            'status' => 'Activated'
                });
        setupRestContext(body);
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    @isTest
    static void testSyncOrderStatus_OrderNotFound() {
        // Valid payload structure but non-existent Order Id
        String fakeId = '8015g000000XXXXXXABC'; // 18-char fake Id won't match real records
        String body = JSON.serialize(new Map<String, Object>{
            'orderId' => fakeId,
                'status'  => 'Activated'
                });
        setupRestContext(body);
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    @isTest
    static void testSyncOrderStatus_SuccessAllFields() {
        Account acc = createTestAccount();
        Order   ord = createTestOrder(acc.Id);
        
        String body = JSON.serialize(new Map<String, Object>{
            'orderId'              => ord.Id,
                'status'               => 'Draft',
                'expectedDeliveryDate' => '2025-12-31',
                'trackingId'           => 'TRK-9999',
                'paymentTerms'         => 'NET60',
                'PartiallyShipped'     => true
                // incoTerms intentionally omitted to avoid metadata dependency
                });
        setupRestContext(body);
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    @isTest
    static void testSyncOrderStatus_InvalidIncoTermsCode() {
        Account acc = createTestAccount();
        Order   ord = createTestOrder(acc.Id);
        
        String body = JSON.serialize(new Map<String, Object>{
            'orderId'   => ord.Id,
                'status'    => 'Activated',
                'incoTerms' => 'INVALID_CODE_THAT_DOES_NOT_EXIST'
                });
        setupRestContext(body);
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    
    @isTest
    static void testValidateInvoiceSyncPayload_BlankPayload() {
        Test.startTest();
        try {
            DRC_NBC_Integration_Utility.validateInvoiceSyncPayload('');
            System.assert(false, 'Expected exception not thrown');
        } catch (DRC_NBC_CustomException e) {
            System.assertEquals('Payload cannot be null or empty', e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateInvoiceSyncPayload_MissingInvoiceNumber() {
        String payload = JSON.serialize(new Map<String, Object>{
            'OrderNumber' => 'ORD-001'
                });
        Test.startTest();
        try {
            DRC_NBC_Integration_Utility.validateInvoiceSyncPayload(payload);
            System.assert(false, 'Expected exception not thrown');
        } catch (DRC_NBC_CustomException e) {
            System.assertEquals('InvoiceNumber is mandatory in payload', e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateInvoiceSyncPayload_MissingOrderNumber() {
        String payload = JSON.serialize(new Map<String, Object>{
            'InvoiceNumber' => 'INV-001'
                });
        Test.startTest();
        try {
            DRC_NBC_Integration_Utility.validateInvoiceSyncPayload(payload);
            System.assert(false, 'Expected exception not thrown');
        } catch (DRC_NBC_CustomException e) {
            System.assertEquals('OrderNumber is mandatory in payload', e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testValidateInvoiceSyncPayload_ValidPayload() {
        String payload = JSON.serialize(new Map<String, Object>{
            'InvoiceNumber' => 'INV-001',
                'OrderNumber'   => 'ORD-001',
                'InvoiceDate'   => '2025-09-01'
                });
        Test.startTest();
        DRC_NBC_Integration_Payload.invoiceSyncPayload result =
            DRC_NBC_Integration_Utility.validateInvoiceSyncPayload(payload);
        Test.stopTest();
        
        System.assertEquals('INV-001', result.InvoiceNumber);
        System.assertEquals('ORD-001', result.OrderNumber);
    }
    
    @isTest
    static void testSyncOrderStatus_SuccessMinimalFields() {
        Account acc = createTestAccount();
        Order   ord = createTestOrder(acc.Id);
        String body = JSON.serialize(new Map<String, Object>{
            'orderId' => ord.Id,
                'status'  => 'Draft'   // ← use same or valid next status from your org
                });
        setupRestContext(body);
        
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
}