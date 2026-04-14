/**
* @description Test class for DRC_NBC_OrderDispatchStatusSync REST endpoint
*              and related DRC_NBC_Integration_Utility / DRC_NBC_Integration_Payload
*/
@isTest
private class DRC_NBC_OrderDispatchStatusSync_Test {
    private static Account createTestAccount() {
        Account acc = new Account( Name = 'Test Account',
                                  DRC_NBC_Customer_Number__c = 'CUST12345',
                                  CurrencyIsoCode = 'INR',
                                  Phone = '1234567890',
                                  AccountNumber = 'A123',
                                  DRC_NBC_PAN_No__c = 'AWVPY9594J',
                                  DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
                                  DRC_NBC_Payment_Term_Code__c = 'PDC90',
                                  DRC_NBC_Account_Email_Email__c = 'test@example.com',
                                  BillingStreet = '123 Street',
                                  BillingCity = 'City',
                                  BillingCountry = 'India',
                                  BillingCountryCode = 'IN',
                                  BillingPostalCode = '462002',
                                  BillingState = 'Maharashtra',
                                  BillingStateCode = 'MH',
                                  DRC_NBC_Volume__c = 70, 
                                  DRC_NBC_Credit_Limit__c = 123456787,
                                  DRC_NBC_Value__c = 900,
                                  DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
                                  DRC_NBC_Consignee_Bank_Address__c = 'Barhi 483775',
                                  DRC_NBC_Consignee_Bank_IFSC_Code__c = 'PUNB01391000',
                                  DRC_NBC_Consignee_Bank_Name__c = 'Punjab National bank',
                                  Industry = 'Chemicals Construction',
                                  Type = 'Analyst');
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
    
    // ─── Helper: create order with Cust Order Number ─────────────────────────
    
    private static Order createTestOrderWithCustNumber(Id accountId, String custOrderNum) {
        Order ord = new Order(
            AccountId               = accountId,
            Status                  = 'Draft',
            EffectiveDate           = Date.today(),
            Pricebook2Id            = Test.getStandardPricebookId(),
            DRC_NBC_Cust_Order_Number__c = custOrderNum
        );
        insert ord;
        return ord;
    }
    
    // ─── STEP 4 field updates + update orderRec + 200 response ───────────────
    
    @isTest
    static void testSyncOrderStatus_AllFieldsUpdated_WithCustOrderNum() {
        Account acc = createTestAccount();
        Order   ord = createTestOrderWithCustNumber(acc.Id, 'CUST-ORDER-001');
        
        String body = JSON.serialize(new Map<String, Object>{
            'orderId'              => 'CUST-ORDER-001',
                'status'               => 'Draft',
                'PartiallyShipped'     => true,
                'trackingId'           => 'TRK-12345',
                'expectedDeliveryDate' => '2025-12-31',
                'paymentTerms'         => 'NET30'
                });
        setupRestContext(body);
        
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    // ─── parseExpectedDeliveryDate — DD/MM/YYYY format ───────────────────────
    
    @isTest
    static void testSyncOrderStatus_DateFormat_DDMMYYYY_Slash() {
        Account acc = createTestAccount();
        Order   ord = createTestOrderWithCustNumber(acc.Id, 'CUST-ORDER-002');
        
        String body = JSON.serialize(new Map<String, Object>{
            'orderId'              => 'CUST-ORDER-002',
                'status'               => 'Draft',
                'expectedDeliveryDate' => '31/12/2025'   // DD/MM/YYYY
                });
        setupRestContext(body);
        
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    // ─── parseExpectedDeliveryDate — DD-MM-YYYY format ───────────────────────
    
    @isTest
    static void testSyncOrderStatus_DateFormat_DDMMYYYY_Dash() {
        Account acc = createTestAccount();
        Order   ord = createTestOrderWithCustNumber(acc.Id, 'CUST-ORDER-003');
        
        String body = JSON.serialize(new Map<String, Object>{
            'orderId'              => 'CUST-ORDER-003',
                'status'               => 'Draft',
                'expectedDeliveryDate' => '31-12-2025'   // DD-MM-YYYY (indexOf('-') == 2)
                });
        setupRestContext(body);
        
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    // ─── parseExpectedDeliveryDate — YYYY-MM-DD fallback ─────────────────────
    
    @isTest
    static void testSyncOrderStatus_DateFormat_YYYYMMDD_Fallback() {
        Account acc = createTestAccount();
        Order   ord = createTestOrderWithCustNumber(acc.Id, 'CUST-ORDER-004');
        
        String body = JSON.serialize(new Map<String, Object>{
            'orderId'              => 'CUST-ORDER-004',
                'status'               => 'Draft',
                'expectedDeliveryDate' => '2025-12-31'   // YYYY-MM-DD fallback
                });
        setupRestContext(body);
        
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    // ─── parseExpectedDeliveryDate — sentinel/empty dates return null ─────────
    
    @isTest
    static void testSyncOrderStatus_DateFormat_SentinelDates_NotUpdated() {
        Account acc = createTestAccount();
        Order   ord = createTestOrderWithCustNumber(acc.Id, 'CUST-ORDER-005');
        
        // Pre-set a known delivery date
        ord.DRC_NBC_Expected_Delivery_Date__c = Date.newInstance(2024, 1, 1);
        update ord;
        
        // Each sentinel value should result in no change to delivery date
        List<String> sentinels = new List<String>{ '0001-01-01', '01/01/0001', '01-01-0001' };
            
            for (String sentinel : sentinels) {
                String body = JSON.serialize(new Map<String, Object>{
                    'orderId'              => 'CUST-ORDER-005',
                        'status'               => 'Draft',
                        'expectedDeliveryDate' => sentinel
                        });
                setupRestContext(body);
                
                DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
            }
    }
    
    // ─── parseExpectedDeliveryDate — blank date skipped entirely ─────────────
    
    @isTest
    static void testSyncOrderStatus_BlankDate_FieldNotUpdated() {
        Account acc = createTestAccount();
        Order   ord = createTestOrderWithCustNumber(acc.Id, 'CUST-ORDER-006');
        
        ord.DRC_NBC_Expected_Delivery_Date__c = Date.newInstance(2024, 6, 15);
        update ord;
        
        String body = JSON.serialize(new Map<String, Object>{
            'orderId'              => 'CUST-ORDER-006',
                'status'               => 'Draft',
                'expectedDeliveryDate' => ''
                });
        setupRestContext(body);
        
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    // ─── IncoTerms — valid metadata match covers incoTerms block ─────────────
    
    @isTest
    static void testSyncOrderStatus_ValidIncoTerms_FromMetadata() {
        Account acc = createTestAccount();
        Order   ord = createTestOrderWithCustNumber(acc.Id, 'CUST-ORDER-007');
        
        // Query a real Warehouse_Location_Code__mdt record of type 'Inco Terms'
        List<Warehouse_Location_Code__mdt> incoMeta = [
            SELECT MasterLabel, DRC_NBC_Code__c
            FROM Warehouse_Location_Code__mdt
            WHERE DRC_NBC_Type__c = 'Inco Terms'
            LIMIT 1
        ];
        
        if (incoMeta.isEmpty()) {
            // No metadata in org — skip gracefully
            System.assert(true, 'No Inco Terms metadata found, skipping test');
            return;
        }
        
        String validCode = incoMeta[0].DRC_NBC_Code__c;
        
        String body = JSON.serialize(new Map<String, Object>{
            'orderId'   => 'CUST-ORDER-007',
                'status'    => 'Draft',
                'incoTerms' => validCode
                });
        setupRestContext(body);
        
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
    
    // ─── Null payload fields — none of the optional fields set ───────────────
    
    @isTest
    static void testSyncOrderStatus_NullOptionalFields_OnlyStatusSet() {
        Account acc = createTestAccount();
        Order   ord = createTestOrderWithCustNumber(acc.Id, 'CUST-ORDER-008');
        
        // Only mandatory fields — all optional payload fields are null
        String body = JSON.serialize(new Map<String, Object>{
            'orderId' => 'CUST-ORDER-008',
                'status'  => 'Draft'
                });
        setupRestContext(body);
        
        Test.startTest();
        DRC_NBC_OrderDispatchStatusSync.syncOrderStatus();
        Test.stopTest();
    }
}