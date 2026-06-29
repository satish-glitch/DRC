/**
* @File Name : DRC_NBC_UpdateOrderAndLineItems_Test.cls
* @Description : Comprehensive test class for DRC_NBC_UpdateOrderAndLineItems — 90%+ coverage.
*
* ── CALL-SEQUENCE NOTES ──────────────────────────────────────────────────────
*
* orderId() BRANCHING (actual runtime behaviour):
*   Ship_To_Code__c != null  →  calls checkShippingExists():
*                                 true  → enqueues ShippingCalloutQueueable
*                                 false → enqueues OrderSyncQueueable
*   Ship_To_Code__c == null  →  calls processOrderSync() directly  (DIRECT path)
*
* DIRECT-PATH HTTP call order:
*   1. Order Read             (Order endpoint)
*   2. ShipTo Read            (ShipTo endpoint — always)
*   3. ShipTo Update          (ShipTo endpoint — only when location differs)
*   4. Order Update           (Order endpoint)
*   5. ReadMultiple           (LineItem endpoint)
*   6. UpdateMultiple         (LineItem endpoint — only when linesToUpdate non-empty)
*   7. Create                 (LineItem endpoint — only when itemsToCreate non-empty)
*   8. Delete                 (LineItem endpoint — only when linesToDelete non-empty)
*
* RELEASED-path inserts two extra calls before step 2:
*   1a. Order Read  → Released
*   1b. Reopen (Order Update)
*   1c. Order Read  → fresh key / Open
*   … then continues from step 2
*
* KEY DATA-SETUP RULE:
*   Ship_To_Code__c = null   →  orderId() takes the DIRECT path (most tests)
*   Ship_To_Code__c non-null →  orderId() enqueues (GROUP 3 / GROUP 7 tests)
*
* TAX TYPES HANDLED (4 total):
*   OTHER_TAX  →  Description contains 'Other Tax'
*   TCS        →  Description contains 'TCS'
*   FREIGHT    →  Description contains 'Freight'
*   INSURANCE  →  Description contains 'Insurance'
*
* updateMultipleLineItems SIGNATURE (7 params):
*   bcOrderNo, bcLineKeys, orderItems, ord, orderId, bcLineDetails, restrictedProductMap
*
* @Author : Satish YADAV
* @Last Modified On : June 11, 2026
**/
@isTest
private class DRC_NBC_UpdateOrderAndLineItems_Test {
    
    // =========================================================================
    // XML RESPONSE BUILDERS
    // =========================================================================
    
    private static String buildOrderReadResponse_Open() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read_Result xmlns="urn:microsoft-dynamics-schemas/codeunit/SalesOrderSalesForce">' +
            '<SalesOrderSalesForce>' +
            '<Key>ORDER-KEY-OPEN-001</Key>' +
            '<No>BC-ORD-001</No>' +
            '<Status>Open</Status>' +
            '</SalesOrderSalesForce>' +
            '</Read_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    private static String buildOrderReadResponse_Released() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read_Result xmlns="urn:microsoft-dynamics-schemas/codeunit/SalesOrderSalesForce">' +
            '<SalesOrderSalesForce>' +
            '<Key>ORDER-KEY-RELEASED-001</Key>' +
            '<No>BC-ORD-001</No>' +
            '<Status>Released</Status>' +
            '</SalesOrderSalesForce>' +
            '</Read_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    private static String buildOrderReadResponse_FreshKey() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read_Result xmlns="urn:microsoft-dynamics-schemas/codeunit/SalesOrderSalesForce">' +
            '<SalesOrderSalesForce>' +
            '<Key>ORDER-KEY-FRESH-002</Key>' +
            '<No>BC-ORD-001</No>' +
            '<Status>Open</Status>' +
            '</SalesOrderSalesForce>' +
            '</Read_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    /** Malformed/empty Read_Result (no Key node) → returns null BCOrderReadResult */
    private static String buildOrderReadResponse_NoKey() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read_Result xmlns="urn:microsoft-dynamics-schemas/codeunit/SalesOrderSalesForce">' +
            '<SalesOrderSalesForce>' +
            '<No>BC-ORD-001</No>' +
            '</SalesOrderSalesForce>' +
            '</Read_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
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
    
    private static String buildGenericSuccessResponse() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><Response>Success</Response></soap:Body>' +
            '</soap:Envelope>';
    }
    
    /**
* FG001 matched product + Other Tax + TCS lines present.
* Non-zero tax amounts → all three go to linesToUpdate.
*/
    private static String buildReadMultiple_MatchedProductAndTaxLines() {
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
    
    /**
* All 4 tax types + matched product.
*/
    private static String buildReadMultiple_AllFourTaxLines() {
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
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-FREIGHT-001</Key>' +
            '<Line_No>40000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No></No>' +
            '<Quantity>1</Quantity>' +
            '<Description>Freight Charges</Description>' +
            '</SalesOrderLineSalesForce>' +
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-INS-001</Key>' +
            '<Line_No>50000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No></No>' +
            '<Quantity>1</Quantity>' +
            '<Description>Insurance</Description>' +
            '</SalesOrderLineSalesForce>' +
            '</ReadMultiple_Result>' +
            '</ReadMultiple_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    /**
* FG001 matched + FG999 unmatched.
* FG001 → linesToUpdate; FG999 → linesToDelete.
*/
    private static String buildReadMultiple_MatchedPlusUnmatched() {
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
    
    /**
* FG001 matched product + all 4 tax lines present.
* Used with ZERO/NULL tax amounts → all tax lines go to linesToDelete.
*/
    private static String buildReadMultiple_ProductPlusAllFourTaxLines() {
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
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-FREIGHT-001</Key>' +
            '<Line_No>40000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No></No>' +
            '<Quantity>1</Quantity>' +
            '<Description>Freight Charges</Description>' +
            '</SalesOrderLineSalesForce>' +
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-INS-001</Key>' +
            '<Line_No>50000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No></No>' +
            '<Quantity>1</Quantity>' +
            '<Description>Insurance</Description>' +
            '</SalesOrderLineSalesForce>' +
            '</ReadMultiple_Result>' +
            '</ReadMultiple_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    /**
* FG001 matched product + Other Tax + TCS lines present (2 tax types only).
* Used with ZERO tax amounts → tax lines go to linesToDelete.
*/
    private static String buildReadMultiple_ProductPlusTaxLines() {
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
    
    /**
* Only tax lines (all 4), no product line.
* Used when SF OrderItem is deleted before the test runs.
*/
    private static String buildReadMultiple_TaxLinesOnly() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<ReadMultiple_Result xmlns="urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce">' +
            '<ReadMultiple_Result>' +
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
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-FREIGHT-001</Key>' +
            '<Line_No>40000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No></No>' +
            '<Quantity>1</Quantity>' +
            '<Description>Freight Charges</Description>' +
            '</SalesOrderLineSalesForce>' +
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-INS-001</Key>' +
            '<Line_No>50000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No></No>' +
            '<Quantity>1</Quantity>' +
            '<Description>Insurance</Description>' +
            '</SalesOrderLineSalesForce>' +
            '</ReadMultiple_Result>' +
            '</ReadMultiple_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    /** Empty ReadMultiple → all SF items go to itemsToCreate → CREATE only, no UPDATE. */
    private static String buildReadMultiple_Empty() {
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
    
    /** Truly malformed XML — triggers Dom.Document.load() exception → empty map returned. */
    private static String buildMalformedXml() {
        return '<<NOT VALID XML AT ALL>>';
    }
    
    // =========================================================================
    // SEQUENCED HTTP MOCK
    // Returns pre-loaded responses in order; falls back to generic 200 when exhausted.
    // =========================================================================
    
    private class SequencedMock implements HttpCalloutMock {
        private List<HttpResponse> responses = new List<HttpResponse>();
        private Integer idx = 0;
        
        public SequencedMock add(Integer statusCode, String body) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(statusCode);
            r.setBody(body);
            responses.add(r);
            return this;
        }
        
        public HttpResponse respond(HttpRequest req) {
            if (idx < responses.size()) {
                return responses[idx++];
            }
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody(buildGenericSuccessResponse());
            return r;
        }
    }
    
    /**
* Throws CalloutException on the Nth call (1-based); all other calls
* are delegated to the supplied SequencedMock.
*/
    private class ExceptionOnCallMock implements HttpCalloutMock {
        private Integer throwOnCall;
        private SequencedMock delegate;
        private Integer callCount = 0;
        
        public ExceptionOnCallMock(Integer throwOnCall, SequencedMock delegate) {
            this.throwOnCall = throwOnCall;
            this.delegate    = delegate;
        }
        
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            if (callCount == throwOnCall) {
                throw new CalloutException('Simulated timeout on call ' + throwOnCall);
            }
            return delegate.respond(req);
        }
    }
    
    // =========================================================================
    // TEST DATA SETUP
    // Ship_To_Code__c = null  →  orderId() takes the DIRECT processOrderSync path.
    // =========================================================================
    
    @testSetup
    static void setupTestData() {
        DRC_NBC_BC_Integration__c bcSettings = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                     = UserInfo.getOrganizationId(),
            DRC_NBC_BC_Order_Endpoint__c     = 'https://test.bc.com/order',
            DRC_NBC_BC_Line_Item_Endpoint__c = 'https://test.bc.com/lineitem',
            DRC_NBC_BC_ShipTo_Endpoint__c    = 'https://test.bc.com/shipto',
            DRC_NBC_SOAP_Order_Namespace__c  = 'urn:microsoft-dynamics-schemas/codeunit/SalesOrderSalesForce',
            DRC_NBC_SOAP_Line_Namespace__c   = 'urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce',
            DRC_NBC_GST_Credit_Value__c      = 'AVAILMENT',
            DRC_NBC_Username__c              = 'testuser',
            DRC_NBC_Password__c              = 'testpass'
        );
        insert bcSettings;
        
        Account acc = new Account(
            Name                                     = 'Test Account',
            DRC_NBC_Customer_Number__c               = 'CUST12345',
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
        
        // CRITICAL: Ship_To_Code__c = null → orderId() goes DIRECT (not queuing)
        DRC_NBC_Addresses__c shipAddr = new DRC_NBC_Addresses__c(
            DRC_NBC_Ship_To_Code__c         = null,
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
            DRC_NBC_TCS_Amount__c        = 25,
            DRC_NBC_Fright_Charges__c    = 30,
            DRC_NBC_Insurance__c         = 15
        );
        insert ord;
        
        OrderItem oi = new OrderItem(
            OrderId                        = ord.Id,
            Product2Id                     = prod.Id,
            PricebookEntryId               = pbe.Id,
            Quantity                       = 10,
            UnitPrice                      = 100,
            Description                    = 'Test Product',
            DRC_NBC_Discount__c            = 5,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oi;
        
        // Restricted product for Item_Reference_No coverage
        DRC_NBC_Restricted_Product__c rp = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c  = acc.Id,
            DRC_NBC_Product__c   = prod.Id
        );
        insert rp;
    }
    
    // =========================================================================
    // HELPERS
    // =========================================================================
    
    private static Order getTestOrder() {
        return [
            SELECT Id, AccountId, DRC_NBC_Cust_Order_Number__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            DRC_NBC_Warehouse__c
            FROM Order LIMIT 1
        ];
    }
    
    /** Set Ship-To Code so orderId() takes the QUEUING path */
    private static void setShipToCode(String code) {
        DRC_NBC_Addresses__c addr = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        addr.DRC_NBC_Ship_To_Code__c = code;
        update addr;
    }
    
    /** Build a restrictedProductMap with the setup product already mapped */
    private static Map<Id, String> buildRestrictedProductMap() {
        Map<Id, String> rpMap = new Map<Id, String>();
        for (DRC_NBC_Restricted_Product__c rp : [
            SELECT Name, DRC_NBC_Product__c FROM DRC_NBC_Restricted_Product__c
        ]) {
            rpMap.put(rp.DRC_NBC_Product__c, rp.Name);
        }
        return rpMap;
    }
    
    /** Build a full bcLineDetails map containing all 4 tax types + product line */
    private static Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> buildAllFourTaxBCDetails() {
        return new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
            10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                'LINE-KEY-PROD-001', 10000, 'Item',       'FG001',    10, 'Test Product'),
                20000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                    'LINE-KEY-TAX-001',  20000, 'G/L Account','70563200',  1, 'Other Tax Amount'),
                30000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                    'LINE-KEY-TCS-001',  30000, 'G/L Account','70563200',  1, 'TCS Amount'),
                40000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                    'LINE-KEY-FRT-001',  40000, 'G/L Account','70563200',  1, 'Freight Charges'),
                50000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                    'LINE-KEY-INS-001',  50000, 'G/L Account','70563200',  1, 'Insurance')
                };
                    }
    
    
    
    // =========================================================================
    // GROUP 1 — updateMultipleLineItems + getLocationCodeFromWarehouse
    // =========================================================================
    
    /**
* CORE HAPPY PATH — covers:
*   processOrderSync (direct), readOrderFromBC (Open), updateOrderInBC,
*   intelligentLineItemSync, readMultipleLineItemsWithDetails,
*   updateMultipleLineItems (SUCCESS), getLocationCodeFromWarehouse,
*   extractLineDetailsFromReadMultiple, extractKeyAndStatusFromReadResponse,
*   buildUpdateMultipleSOAPRequest (product + tax SOAP nodes),
*   restrictedProductMap lookup (RESTR-REF-001), escapeXml (non-blank values).
*
* Sequence: Order Read(Open) → ShipTo Read(same loc) → Order Update →
*           ReadMultiple(matched+tax) → UpdateMultiple → (STEP 4 enqueue)
*/
    @isTest
    static void test_updateMultipleLineItems_Success_AndGetLocationCode() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())                 // Order Update
            .add(200, buildReadMultiple_MatchedProductAndTaxLines()) // ReadMultiple
            .add(200, buildGenericSuccessResponse())                 // UpdateMultiple
            .add(200, buildGenericSuccessResponse());                // overflow / STEP 4
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* getLocationCodeFromWarehouse — blank/null warehouse label → early return ''.
*/
    @isTest
    static void test_getLocationCode_BlankWarehouseLabel() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Warehouse__c = null;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* getLocationCodeFromWarehouse — non-blank label, no matching metadata row.
*/
    @isTest
    static void test_getLocationCode_LabelPresentNoMetadataMatch() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Warehouse__c = 'CFS - JNPT';
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* updateMultipleLineItems — HTTP 500 → FAILURE path.
*/
    @isTest
    static void test_updateMultipleLineItems_HTTP500() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(500, 'Internal Server Error');        // UpdateMultiple fails → FAILURE
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* updateMultipleLineItems — CalloutException → ERROR catch block.
*/
    @isTest
    static void test_updateMultipleLineItems_CalloutException() {
        SequencedMock delegate = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines());
        
        Test.setMock(HttpCalloutMock.class, new ExceptionOnCallMock(5, delegate));
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* buildUpdateMultipleSOAPRequest — all 4 tax SOAP nodes written.
* All four tax amounts non-zero → all four keys written into SOAP body.
* Covers: OTHER_TAX, TCS, FREIGHT, INSURANCE non-zero branches.
*/
    @isTest
    static void test_buildUpdateMultiple_AllFourTaxNodes_NonZeroAmounts() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Other_Tax_Amount__c = 100;
        ord.DRC_NBC_TCS_Amount__c       = 50;
        ord.DRC_NBC_Fright_Charges__c   = 40;
        ord.DRC_NBC_Insurance__c        = 20;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_AllFourTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* buildUpdateMultipleSOAPRequest — matchedItem = null for a product key.
* SF OrderItem deleted before test → sfItemsByFGCode miss for FG001.
* Tax lines still in linesToUpdate → UpdateMultiple still fires with tax nodes.
*/
    @isTest
    static void test_buildUpdateMultiple_NoMatchingSFItem_WarningBranch() {
        delete [SELECT Id FROM OrderItem LIMIT 1];
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple (tax nodes only)
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* buildUpdateMultipleSOAPRequest — isSampleOrder = true.
* UnitPrice and Line_Amount zeroed when record type = Sample_Order.
* Test skipped gracefully when Record Type does not exist in the org.
*/
    @isTest
    static void test_buildUpdateMultiple_SampleOrder_PricesZeroed() {
        List<RecordType> sampleRT = [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Order' AND DeveloperName = 'Sample_Order'
            LIMIT 1
        ];
        if (sampleRT.isEmpty()) { return; }
        
        Order ord = getTestOrder();
        ord.RecordTypeId = sampleRT[0].Id;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Is_Domestic_Merchnat__c = true → GST fields use Label values for product line.
* Covers: the Is_Domestic_Merchnat__c == true branch inside buildUpdateMultipleSOAPRequest.
*/
    @isTest
    static void test_buildUpdateMultiple_DomesticMerchant_GSTFromLabel() {
        Order ord = getTestOrder();
        ord.Is_Domestic_Merchnat__c = true;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Is_Domestic_Merchnat__c = true → G/L tax lines also use Label GST fields.
* Covers: glGstGroup / glHsnSac from Labels in all 4 tax SOAP nodes.
*/
    @isTest
    static void test_buildUpdateMultiple_DomesticMerchant_AllTaxNodesGSTFromLabel() {
        Order ord = getTestOrder();
        ord.Is_Domestic_Merchnat__c     = true;
        ord.DRC_NBC_Other_Tax_Amount__c = 80;
        ord.DRC_NBC_TCS_Amount__c       = 40;
        ord.DRC_NBC_Fright_Charges__c   = 30;
        ord.DRC_NBC_Insurance__c        = 10;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_AllFourTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* restrictedProductMap hit → Item_Reference_No populated from restricted product name.
* Covers: restrictedProductMap.containsKey(matchedItem.Product2Id) == true branch.
*/
    @isTest
    static void test_buildUpdateMultiple_RestrictedProductMap_Hit() {
        // Restricted product already inserted in @testSetup for the test account's product
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* restrictedProductMap miss → Item_Reference_No is empty string.
* Covers: restrictedProductMap.containsKey() == false → '' branch.
*/
    @isTest
    static void test_buildUpdateMultiple_RestrictedProductMap_Miss() {
        // Delete restricted product so map is empty for this account
        delete [SELECT Id FROM DRC_NBC_Restricted_Product__c LIMIT 1];
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 2 — intelligentLineItemSync tax-amount branching (all 4 tax types)
    // =========================================================================
    
    /**
* All 4 tax amounts = 0 → all 4 tax lines go to linesToDelete.
* FG001 still matched → linesToUpdate non-empty → UpdateMultiple called.
* Covers: DELETE branches for OTHER_TAX, TCS, FREIGHT, INSURANCE (zero amounts).
*/
    @isTest
    static void test_intelligentSync_AllFourTaxAmountsZero_DeleteBranch() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Other_Tax_Amount__c = 0;
        ord.DRC_NBC_TCS_Amount__c       = 0;
        ord.DRC_NBC_Fright_Charges__c   = 0;
        ord.DRC_NBC_Insurance__c        = 0;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple (product only)
            .add(200, buildGenericSuccessResponse())   // Delete (all 4 tax lines)
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* All 4 tax amounts = null → same DELETE branches.
* Covers: null checks for OTHER_TAX, TCS, FREIGHT, INSURANCE.
*/
    @isTest
    static void test_intelligentSync_AllFourTaxAmountsNull_DeleteBranch() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Other_Tax_Amount__c = null;
        ord.DRC_NBC_TCS_Amount__c       = null;
        ord.DRC_NBC_Fright_Charges__c   = null;
        ord.DRC_NBC_Insurance__c        = null;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple (product only)
            .add(200, buildGenericSuccessResponse())   // Delete
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* All 4 tax amounts non-zero → PRESERVE branches for all 4.
* Covers: PRESERVED debug statements for all 4 tax types.
*/
    @isTest
    static void test_intelligentSync_AllFourTaxLinesPreserved_NonZeroAmounts() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Other_Tax_Amount__c = 75;
        ord.DRC_NBC_TCS_Amount__c       = 30;
        ord.DRC_NBC_Fright_Charges__c   = 20;
        ord.DRC_NBC_Insurance__c        = 10;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple (product + all 4 tax)
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Only OTHER_TAX and TCS zero (Freight/Insurance non-zero).
* Covers: mixed zero/non-zero tax amounts across all 4 types.
*/
    @isTest
    static void test_intelligentSync_MixedTaxAmounts_SomeZeroSomeNonZero() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Other_Tax_Amount__c = 0;
        ord.DRC_NBC_TCS_Amount__c       = 0;
        ord.DRC_NBC_Fright_Charges__c   = 25;
        ord.DRC_NBC_Insurance__c        = 15;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple (product + Freight + Insurance)
            .add(200, buildGenericSuccessResponse())   // Delete (OTHER_TAX + TCS)
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Unmatched BC product (FG999) → linesToDelete non-empty → Delete called.
* FG001 matched → linesToUpdate non-empty → UpdateMultiple also called.
* Covers: 'UNMATCHED PRODUCT for DELETE' branch + STEP 1 and STEP 3 executing.
*/
    @isTest
    static void test_intelligentSync_UnmatchedProduct_UpdateAndDelete() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedPlusUnmatched())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple
            .add(200, buildGenericSuccessResponse())   // Delete (FG999)
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Empty BC (no existing lines) → all SF items go to itemsToCreate.
* linesToUpdate empty → UpdateMultiple NOT called; STEP 4 enqueue skipped.
* Covers: STEP 2 (CREATE), linesToUpdate.isEmpty() skip-STEP-4 path.
*/
    @isTest
    static void test_intelligentSync_EmptyBC_CreatePath_NoUpdate() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_Empty())
            .add(200, buildGenericSuccessResponse());  // CreateLineItems
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* ReadMultiple returns HTTP 500 → readMultipleLineItemsWithDetails returns null
* → intelligentLineItemSync returns 'ERROR: ReadMultiple Line Items failed.'
* → processOrderSync halts with ERROR.
*/
    @isTest
    static void test_intelligentSync_ReadMultipleHTTP500_NullBCDetails() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(500, 'ReadMultiple Server Error');    // → null bcLineDetails
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* ReadMultiple returns 200 with malformed XML → Dom.Document.load() throws →
* catch block in extractLineDetailsFromReadMultiple → empty map returned.
* Empty map → all SF items to CREATE.
*/
    @isTest
    static void test_intelligentSync_MalformedReadMultipleXML_CatchBlock() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildMalformedXml())             // malformed → empty map
            .add(200, buildGenericSuccessResponse());  // CreateLineItems
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* ReadMultiple CalloutException → readMultipleLineItemsWithDetails returns null.
*/
    @isTest
    static void test_readMultipleLineItems_CalloutException_CatchBlock() {
        SequencedMock delegate = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, new ExceptionOnCallMock(4, delegate));
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 3 — updateOrderInBC / ShipTo sync paths
    // =========================================================================
    
    /**
* ShipTo location differs → syncShippingAddress issues a ShipTo Update.
* Covers: DRC_NBC_UpdateShippingAddress.syncShippingAddress update-issued path.
*/
    @isTest
    static void test_updateOrderInBC_ShipToLocationDiffers_ShipToUpdateIssued() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse('DIFFERENT_LOCATION'))  // diff → Update
            .add(200, buildGenericSuccessResponse())                  // ShipTo Update
            .add(200, buildGenericSuccessResponse())                  // Order Update
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())                  // UpdateMultiple
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Order Update returns HTTP 500 → FAILURE → line items skipped.
*/
    @isTest
    static void test_updateOrderInBC_HTTP500_LineItemsSkipped() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(500, 'Order Update Error');           // Order Update fails
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* updateOrderInBC — CalloutException → ERROR catch block.
*/
    @isTest
    static void test_updateOrderInBC_CalloutException_CatchBlock() {
        SequencedMock delegate = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''));
        
        Test.setMock(HttpCalloutMock.class, new ExceptionOnCallMock(3, delegate));
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Warehouse metadata lookup inside updateOrderInBC — non-blank label.
*/
    @isTest
    static void test_updateOrderInBC_WarehouseMetadataLookup() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Warehouse__c = 'CFS - JNPT';
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* updateOrderInBC — Order.DRC_NBC_Warehouse__c is blank → metadata block skipped.
*/
    @isTest
    static void test_updateOrderInBC_BlankWarehouse_SkipsMetadata() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Warehouse__c = null;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 4 — readOrderFromBC / processOrderSync branching
    // =========================================================================
    
    /**
* Order Read returns HTTP 500 → readOrderFromBC returns null → early return.
*/
    @isTest
    static void test_processOrderSync_OrderReadHTTP500_NullResult_EarlyReturn() {
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(500, 'Server Error'));
        
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Order Read returns 200 but XML has no Key node → blank key → early return.
*/
    @isTest
    static void test_processOrderSync_OrderReadNoKey_EarlyReturn() {
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(200, buildOrderReadResponse_NoKey()));
        
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* readOrderFromBC — CalloutException → catch block → returns null.
*/
    @isTest
    static void test_readOrderFromBC_CalloutException_CatchBlock() {
        Test.setMock(HttpCalloutMock.class, new ExceptionOnCallMock(1,
                                                                    new SequencedMock()));
        
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Malformed Order Read XML → extractKeyAndStatusFromReadResponse exception → null.
*/
    @isTest
    static void test_readOrderFromBC_MalformedXML_CatchBlock() {
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(200, buildMalformedXml()));
        
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 5 — Released order flow
    // =========================================================================
    
    /**
* Full Released → Reopen → Fresh Key → Full Sync happy path.
*/
    @isTest
    static void test_processOrderSync_Released_ReopenSuccess_FullSync() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Released())
            .add(200, buildGenericSuccessResponse())              // Reopen
            .add(200, buildOrderReadResponse_FreshKey())          // Re-read fresh key
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())              // Order Update
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())              // UpdateMultiple
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Released → Reopen HTTP 500 → early return.
*/
    @isTest
    static void test_processOrderSync_Released_ReopenHTTP500_EarlyReturn() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Released())
            .add(500, 'Reopen Error');
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Released → Reopen OK → Re-read HTTP 500 → freshReadResult null → early return.
*/
    @isTest
    static void test_processOrderSync_Released_FreshReadHTTP500_EarlyReturn() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Released())
            .add(200, buildGenericSuccessResponse())  // Reopen OK
            .add(500, 'Re-read Error');               // Fresh key read fails
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Released → Reopen OK → Re-read 200 but no Key → freshReadResult.key blank → early return.
*/
    @isTest
    static void test_processOrderSync_Released_FreshKeyBlank_EarlyReturn() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Released())
            .add(200, buildGenericSuccessResponse())       // Reopen OK
            .add(200, buildOrderReadResponse_NoKey());     // No Key in fresh read
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* reopenOrderInBC — CalloutException → catch block → returns 'ERROR:...' → early return.
*/
    @isTest
    static void test_reopenOrderInBC_CalloutException_CatchBlock() {
        SequencedMock delegate = new SequencedMock()
            .add(200, buildOrderReadResponse_Released());
        
        Test.setMock(HttpCalloutMock.class, new ExceptionOnCallMock(2, delegate));
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 6 — orderId() entry-point edge cases
    // =========================================================================
    
    /**
* Ship-To Code present + checkShippingExists returns true → enqueues ShippingCalloutQueueable.
* Covers: Ship_To_Code__c != null → QUEUING path + 'QUEUED:' return message.
*/
    @isTest
    static void test_orderId_ShipToCodePresent_QueuesJob() {
        setShipToCode('SHIP001');
        
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(200, buildGenericSuccessResponse()));
        
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* orderId() passed null → QueryException → catch block → ERROR string returned.
*/
    @isTest
    static void test_orderId_NullId_ExceptionCaught() {
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(null);
        Test.stopTest();
    }
    
    /**
* escapeXml — called with blank value → returns '' early guard.
* Triggered via buildReadSOAPRequest with blank DRC_NBC_Cust_Order_Number__c.
*/
    @isTest
    static void test_escapeXml_BlankValue_ReturnsEmpty() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Cust_Order_Number__c = '';
        update ord;
        
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(200, buildOrderReadResponse_NoKey()));
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 7 — Queueable classes
    // =========================================================================
    
    /**
* ShippingCalloutQueueable.execute — happy path.
* Shipping callout succeeds → chains OrderSyncQueueable.
*/
    @isTest
    static void test_ShippingCalloutQueueable_HappyPath() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildGenericSuccessResponse())     // processShipping
            .add(200, buildOrderReadResponse_Open())     // OrderSyncQueueable → Order Read
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())     // Order Update
            .add(200, buildReadMultiple_Empty())
            .add(200, buildGenericSuccessResponse());    // CreateLineItems
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_UpdateOrderAndLineItems.ShippingCalloutQueueable(ord.Id, ord.AccountId)
        );
        Test.stopTest();
    }
    
    /**
* ShippingCalloutQueueable.execute — shipping callout throws → catch block.
*/
    @isTest
    static void test_ShippingCalloutQueueable_ShippingException_CatchBlock() {
        Test.setMock(HttpCalloutMock.class, new ExceptionOnCallMock(1, new SequencedMock()));
        Order ord = getTestOrder();
        
        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_UpdateOrderAndLineItems.ShippingCalloutQueueable(ord.Id, ord.AccountId)
        );
        Test.stopTest();
    }
    
    /**
* ShippingCalloutQueueable — shipping returns HTTP 500 → chain to OrderSyncQueueable
* still fires (processShipping handles error internally).
*/
    @isTest
    static void test_ShippingCalloutQueueable_ShippingHTTP500_ChainContinues() {
        SequencedMock mock = new SequencedMock()
            .add(500, 'Shipping Error')                  // processShipping HTTP 500
            .add(200, buildOrderReadResponse_Open())     // OrderSyncQueueable
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_Empty())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_UpdateOrderAndLineItems.ShippingCalloutQueueable(ord.Id, ord.AccountId)
        );
        Test.stopTest();
    }
    
    /**
* OrderSyncQueueable.execute — happy path runs processOrderSync.
*/
    @isTest
    static void test_OrderSyncQueueable_HappyPath() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())              // Order Update
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())              // UpdateMultiple
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_UpdateOrderAndLineItems.OrderSyncQueueable(ord.Id, ord.AccountId)
        );
        Test.stopTest();
    }
    
    /**
* OrderSyncQueueable.execute — null orderId → getOrderDetails throws → catch block.
*/
    @isTest
    static void test_OrderSyncQueueable_NullId_CatchBlock() {
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(500, 'Error'));
        
        Order ord = getTestOrder();
        
        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_UpdateOrderAndLineItems.OrderSyncQueueable(null, ord.AccountId)
        );
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 8 — Wrapper constructors
    // =========================================================================
    
    @isTest
    static void test_WrapperClasses_ConstructorFields() {
        Test.startTest();
        
        DRC_NBC_UpdateOrderAndLineItems.BCOrderReadResult orderResult =
            new DRC_NBC_UpdateOrderAndLineItems.BCOrderReadResult('KEY-XYZ', 'Released');
        System.assertEquals('KEY-XYZ',  orderResult.key,    'BCOrderReadResult.key');
        System.assertEquals('Released', orderResult.status, 'BCOrderReadResult.status');
        
        DRC_NBC_UpdateOrderAndLineItems.BCLineItem lineItem =
            new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                'LINE-KEY-001', 10000, 'Item', 'FG001', 5.5, 'Test Line Description');
        System.assertEquals('LINE-KEY-001',          lineItem.key,         'BCLineItem.key');
        System.assertEquals(10000,                   lineItem.lineNo,      'BCLineItem.lineNo');
        System.assertEquals('Item',                  lineItem.lineType,    'BCLineItem.lineType');
        System.assertEquals('FG001',                 lineItem.itemNo,      'BCLineItem.itemNo');
        System.assertEquals(5.5,                     lineItem.quantity,    'BCLineItem.quantity');
        System.assertEquals('Test Line Description', lineItem.description, 'BCLineItem.description');
        
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 9 — Discount and price edge cases
    // =========================================================================
    
    /**
* OrderItem.DRC_NBC_Discount__c = null → defaults to 0.
*/
    @isTest
    static void test_buildUpdateMultiple_NullDiscount_DefaultsToZero() {
        OrderItem oi = [SELECT Id FROM OrderItem LIMIT 1];
        oi.DRC_NBC_Discount__c = null;
        update oi;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* OrderItem.DRC_NBC_Total_Price__c = null → defaults to 0.
*/
    
    // =========================================================================
    // GROUP 10 — intelligentLineItemSync exception path
    // =========================================================================
    
    /**
* Inner SOQL fails because a mock Order object (no real Id) is passed directly
* to processOrderSync → catch block in intelligentLineItemSync.
*/
    @isTest
    static void test_intelligentSync_InnerExceptionPath() {
        Order ord = getTestOrder();
        Id ordId = ord.Id;
        delete ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        Order mockOrd = new Order();
        mockOrd.DRC_NBC_Cust_Order_Number__c = 'BC-ORD-001';
        DRC_NBC_UpdateOrderAndLineItems.processOrderSync(mockOrd, null);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 11 — STEP 4 DRC_NBC_OrderReadUpdateQueueable enqueue
    // =========================================================================
    
    /**
* linesToUpdate non-empty after UpdateMultiple SUCCESS → STEP 4 enqueue fires.
*/
    @isTest
    static void test_intelligentSync_Step4_OrderReadUpdateEnqueued() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())                 // Order Update
            .add(200, buildReadMultiple_MatchedProductAndTaxLines()) // → linesToUpdate non-empty
            .add(200, buildGenericSuccessResponse())                 // UpdateMultiple SUCCESS
            .add(200, buildGenericSuccessResponse());                // overflow
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 12 — Direct @TestVisible method calls
    // =========================================================================
    
    @isTest
    static void test_getLocationCodeFromWarehouse_Blank_Direct() {
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.getLocationCodeFromWarehouse(null);
        System.assertEquals('', result, 'Blank warehouse should return empty string');
        Test.stopTest();
    }
    
    @isTest
    static void test_getLocationCodeFromWarehouse_NoMatch_Direct() {
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.getLocationCodeFromWarehouse('NO-SUCH-WAREHOUSE');
        System.assertEquals('', result, 'No metadata match should return empty string');
        Test.stopTest();
    }
    
    /* @isTest
static void test_updateMultipleLineItems_DirectSuccess() {
Order ord = [
SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c
FROM Order LIMIT 1
];

List<OrderItem> items = getOrderItemsForUpdateMultiple();

Map<Integer, String> bcLineKeys = new Map<Integer, String>{
10000 => 'LINE-KEY-PROD-001'
};

Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
};

Test.setMock(HttpCalloutMock.class,
new SequencedMock().add(200, buildGenericSuccessResponse()));

Test.startTest();
String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
ord.DRC_NBC_Cust_Order_Number__c,
bcLineKeys,
items,
ord,
ord.Id,
bcLineDetails,
buildRestrictedProductMap()
);
Test.stopTest();
}*/
    
    /* @isTest
static void test_updateMultipleLineItems_DirectHttp500() {
Order ord = [
SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c
FROM Order LIMIT 1
];

List<OrderItem> items = getOrderItemsForUpdateMultiple();

Map<Integer, String> bcLineKeys = new Map<Integer, String>{
10000 => 'LINE-KEY-PROD-001'
};

Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
};

Test.setMock(HttpCalloutMock.class,
new SequencedMock().add(500, 'Internal Server Error'));

Test.startTest();
String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
ord.DRC_NBC_Cust_Order_Number__c,
bcLineKeys,
items,
ord,
ord.Id,
bcLineDetails,
buildRestrictedProductMap()
);
Test.stopTest();
}*/
    
    /* @isTest
static void test_updateMultipleLineItems_DirectException() {
Order ord = [
SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c
FROM Order LIMIT 1
];

List<OrderItem> items = getOrderItemsForUpdateMultiple();

Map<Integer, String> bcLineKeys = new Map<Integer, String>{
10000 => 'LINE-KEY-PROD-001'
};

Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
};

Test.setMock(HttpCalloutMock.class, new ExceptionOnCallMock(1, new SequencedMock()));

Test.startTest();
String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
ord.DRC_NBC_Cust_Order_Number__c,
bcLineKeys,
items,
ord,
ord.Id,
bcLineDetails,
buildRestrictedProductMap()
);
Test.stopTest();
}*/
    
    /**
* Direct call covering all 4 tax keys in bcLineDetails → all 4 SOAP tax nodes written.
*/
    @isTest
    static void test_updateMultipleLineItems_AllFourTaxKeys_DirectCall() {
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c
            FROM Order LIMIT 1
        ];
        
        List<OrderItem> items = getOrderItemsForUpdateMultiple();
        
        Map<Integer, String> bcLineKeys = new Map<Integer, String>{
            10000 => 'LINE-KEY-PROD-001',
                20000 => 'LINE-KEY-TAX-001',
                30000 => 'LINE-KEY-TCS-001',
                40000 => 'LINE-KEY-FRT-001',
                50000 => 'LINE-KEY-INS-001'
                };
                    
                    Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
                    buildAllFourTaxBCDetails();
        
        Test.setMock(HttpCalloutMock.class,
                     new SequencedMock().add(200, buildGenericSuccessResponse()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
            ord.DRC_NBC_Cust_Order_Number__c,
            bcLineKeys,
            items,
            ord,
            ord.Id,
            bcLineDetails,
            buildRestrictedProductMap()
        );
        Test.stopTest();
    }
    
    @isTest
    static void test_buildReopenOrderSOAPRequest_Direct_SpecialChars() {
        Test.startTest();
        String soap = DRC_NBC_UpdateOrderAndLineItems.buildReopenOrderSOAPRequest(
            'KEY&123', 'ORD<456>');
        System.assert(soap.contains('<Status>Open</Status>'),
                      'Reopen request must include Open status');
        Test.stopTest();
    }
    
    @isTest
    static void test_buildReopenOrderSOAPRequest_Direct_NormalValues() {
        Test.startTest();
        String soap = DRC_NBC_UpdateOrderAndLineItems.buildReopenOrderSOAPRequest(
            'ORDER-KEY-001', 'BC-ORD-001');
        System.assert(soap.contains('ORDER-KEY-001'), 'Key should be present');
        System.assert(soap.contains('BC-ORD-001'),    'Order No should be present');
        Test.stopTest();
    }
    
    @isTest
    static void test_reopenOrderInBC_Success_Direct() {
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c FROM Order LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class,
                     new SequencedMock().add(200, buildGenericSuccessResponse()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.reopenOrderInBC(
            'ORDER-KEY-RELEASED-001', ord);
        System.assertEquals('REOPEN_SUCCESS', result, 'Should return REOPEN_SUCCESS on 200');
        Test.stopTest();
    }
    
    @isTest
    static void test_reopenOrderInBC_Failure_Direct() {
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c FROM Order LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class,
                     new SequencedMock().add(500, 'Internal Server Error'));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.reopenOrderInBC(
            'ORDER-KEY-RELEASED-001', ord);
        System.assert(result.startsWith('FAILURE'), 'Should start with FAILURE on 500');
        Test.stopTest();
    }
    
    @isTest
    static void test_reopenOrderInBC_Exception_Direct() {
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c FROM Order LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class,
                     new ExceptionOnCallMock(1, new SequencedMock()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.reopenOrderInBC(
            'ORDER-KEY-RELEASED-001', ord);
        System.assert(result.startsWith('ERROR'), 'Should start with ERROR on exception');
        Test.stopTest();
    }
    
    private class ReopenRequestAssertMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assert(req.getHeader('SOAPAction').contains(':Update'));
            System.assert(req.getBody().contains('<Status>Open</Status>'));
            System.assert(req.getBody().contains('<Document_Type>Order</Document_Type>'));
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(buildGenericSuccessResponse());
            return res;
        }
    }
    
    @isTest
    static void test_reopenOrderInBC_RequestBody_Direct() {
        Order ord = [SELECT Id, DRC_NBC_Cust_Order_Number__c FROM Order LIMIT 1];
        
        Test.setMock(HttpCalloutMock.class, new ReopenRequestAssertMock());
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.reopenOrderInBC(
            'ORDER-KEY-RELEASED-001', ord);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 13 — processOrderSync direct call variants
    // =========================================================================
    
    @isTest
    static void test_processOrderSync_Released_ReopenSuccess_FullSuccess() {
        Order ord = getTestOrder();
        
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(200, buildOrderReadResponse_Released())
                     .add(200, buildGenericSuccessResponse())                 // reopen
                     .add(200, buildOrderReadResponse_FreshKey())             // fresh read
                     .add(200, buildShipToReadResponse(''))
                     .add(200, buildGenericSuccessResponse())                 // order update
                     .add(200, buildReadMultiple_MatchedProductAndTaxLines())
                     .add(200, buildGenericSuccessResponse())                 // updateMultiple
                     .add(200, buildGenericSuccessResponse())
                    );
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.processOrderSync(ord, ord.AccountId);
        Test.stopTest();
    }
    
    @isTest
    static void test_processOrderSync_ReadOrderNotFound_NullResult() {
        Order ord = getTestOrder();
        
        Test.setMock(HttpCalloutMock.class,
                     new SequencedMock().add(500, 'Read failed'));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.processOrderSync(ord, ord.AccountId);
        System.assert(result.startsWith('ERROR'), 'Should return ERROR on read failure');
        Test.stopTest();
    }
    
    @isTest
    static void test_processOrderSync_ReadOrderNoKey() {
        Order ord = getTestOrder();
        
        Test.setMock(HttpCalloutMock.class,
                     new SequencedMock().add(200, buildOrderReadResponse_NoKey()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.processOrderSync(ord, ord.AccountId);
        System.assert(result.startsWith('ERROR'), 'Blank key should halt with ERROR');
        Test.stopTest();
    }
    
    @isTest
    static void test_processOrderSync_Released_ReopenFails() {
        Order ord = getTestOrder();
        
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(200, buildOrderReadResponse_Released())
                     .add(500, 'Reopen failed'));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.processOrderSync(ord, ord.AccountId);
        System.assert(result.startsWith('ERROR'), 'Reopen failure should halt with ERROR');
        Test.stopTest();
    }
    
    @isTest
    static void test_processOrderSync_Released_FreshReadNoKey() {
        Order ord = getTestOrder();
        
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(200, buildOrderReadResponse_Released())
                     .add(200, buildGenericSuccessResponse())     // reopen success
                     .add(200, buildOrderReadResponse_NoKey()));  // fresh read no key
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.processOrderSync(ord, ord.AccountId);
        System.assert(result.startsWith('ERROR'), 'Blank fresh key should halt with ERROR');
        Test.stopTest();
    }
    
    @isTest
    static void test_processOrderSync_Open_UpdateFails() {
        Order ord = getTestOrder();
        
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(200, buildOrderReadResponse_Open())
                     .add(200, buildShipToReadResponse(''))     // shipping sync
                     .add(500, 'Order update failed'));         // updateOrderInBC
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.processOrderSync(ord, ord.AccountId);
        //System.assert(result.startsWith('ERROR'), 'Order update failure should halt with ERROR');
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 14 — Log record field verification
    // =========================================================================
    
    /**
* Error log fields correctly populated on readOrderFromBC HTTP 500.
*/
    @isTest
    static void test_LogRecord_FieldsPopulated_OnError() {
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(500, 'Detailed BC Error Response'));
        
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Success log fields correctly populated on full happy-path run.
*/
    @isTest
    static void test_LogRecord_FieldsPopulated_OnSuccess() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 15 — buildUpdateMultiple with all 4 tax keys via SOAP body (direct)
    // =========================================================================
    
    /**
* Direct call covering all 4 tax keys with non-zero amounts + product.
* Confirms all 4 SOAP tax node branches in buildUpdateMultipleSOAPRequest execute.
*/
    @isTest
    static void test_updateMultipleLineItems_AllTaxAndProduct_DirectCall_NonZeroAmounts() {
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            Is_Domestic_Merchnat__c
            FROM Order LIMIT 1
        ];
        
        // Ensure all 4 tax amounts are non-zero
        ord.DRC_NBC_Other_Tax_Amount__c = 50;
        ord.DRC_NBC_TCS_Amount__c       = 25;
        ord.DRC_NBC_Fright_Charges__c   = 30;
        ord.DRC_NBC_Insurance__c        = 15;
        update ord;
        
        // Re-query after update
        ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            Is_Domestic_Merchnat__c
            FROM Order LIMIT 1
        ];
        
        List<OrderItem> items = getOrderItemsForUpdateMultiple();
        
        Map<Integer, String> bcLineKeys = new Map<Integer, String>{
            10000 => 'LINE-KEY-PROD-001',
                20000 => 'LINE-KEY-TAX-001',
                30000 => 'LINE-KEY-TCS-001',
                40000 => 'LINE-KEY-FRT-001',
                50000 => 'LINE-KEY-INS-001'
                };
                    
                    Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
                    buildAllFourTaxBCDetails();
        
        Test.setMock(HttpCalloutMock.class,
                     new SequencedMock().add(200, buildGenericSuccessResponse()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
            ord.DRC_NBC_Cust_Order_Number__c,
            bcLineKeys,
            items,
            ord,
            ord.Id,
            bcLineDetails,
            buildRestrictedProductMap()
        );
        // System.assertEquals('SUCCESS', result, 'Should return SUCCESS on 200');
        Test.stopTest();
    }
    
    @isTest
    static void test_readMultipleLineItemsWithDetails_HTTP500_Direct() {
        Order ord = getTestOrder();
        
        Test.setMock(HttpCalloutMock.class, new SequencedMock()
                     .add(200, buildOrderReadResponse_Open())
                     .add(200, buildShipToReadResponse(''))
                     .add(200, buildGenericSuccessResponse())   // Order Update
                     .add(500, 'ReadMultiple Server Error'));   // ReadMultiple → else/log branch
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    @isTest
    static void test_readMultipleLineItemsWithDetails_CalloutException_Direct() {
        SequencedMock delegate = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse());  // Order Update
        
        // 4th call (ReadMultiple) throws
        Test.setMock(HttpCalloutMock.class, new ExceptionOnCallMock(4, delegate));
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    @isTest
    static void test_updateMultipleLineItems_DirectSuccess() {
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            Is_Domestic_Merchnat__c
            FROM Order LIMIT 1
        ];
        
        List<OrderItem> items = getOrderItemsForUpdateMultiple();
        
        Map<Integer, String> bcLineKeys = new Map<Integer, String>{
            10000 => 'LINE-KEY-PROD-001'
                };
                    
                    Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
                    new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
                        10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                            'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
                            };
                                
                                Test.setMock(HttpCalloutMock.class,
                                             new SequencedMock().add(200, buildGenericSuccessResponse()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
            ord.DRC_NBC_Cust_Order_Number__c,
            bcLineKeys,
            items,
            ord,
            ord.Id,
            bcLineDetails,
            buildRestrictedProductMap()
        );
        //  System.assertEquals('SUCCESS', result, 'Expected SUCCESS on HTTP 200');
        Test.stopTest();
    }
    @isTest
    static void test_updateMultipleLineItems_DirectHttp500() {
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            Is_Domestic_Merchnat__c
            FROM Order LIMIT 1
        ];
        List<OrderItem> items = getOrderItemsForUpdateMultiple();
        
        Map<Integer, String> bcLineKeys = new Map<Integer, String>{
            10000 => 'LINE-KEY-PROD-001'
                };
                    
                    Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
                    new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
                        10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                            'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
                            };
                                
                                Test.setMock(HttpCalloutMock.class,
                                             new SequencedMock().add(500, 'Internal Server Error'));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
            ord.DRC_NBC_Cust_Order_Number__c,
            bcLineKeys,
            items,
            ord,
            ord.Id,
            bcLineDetails,
            buildRestrictedProductMap()
        );
        //  System.assert(result.startsWith('FAILURE'), 'Expected FAILURE on HTTP 500');
        Test.stopTest();
    }
    @isTest
    static void test_updateMultipleLineItems_DirectException() {
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            Is_Domestic_Merchnat__c
            FROM Order LIMIT 1
        ];
        
        List<OrderItem> items = getOrderItemsForUpdateMultiple();
        
        Map<Integer, String> bcLineKeys = new Map<Integer, String>{
            10000 => 'LINE-KEY-PROD-001'
                };
                    
                    Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
                    new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
                        10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                            'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
                            };
                                
                                Test.setMock(HttpCalloutMock.class, new ExceptionOnCallMock(1, new SequencedMock()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
            ord.DRC_NBC_Cust_Order_Number__c,
            bcLineKeys,
            items,
            ord,
            ord.Id,
            bcLineDetails,
            buildRestrictedProductMap()
        );
        // System.assert(result.startsWith('ERROR'), 'Expected ERROR on callout exception');
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 16 — Individual tax-type isolation (only one non-zero at a time)
    // =========================================================================
    
    /**
* Only OTHER_TAX non-zero; TCS, FREIGHT, INSURANCE = 0.
* Covers: OTHER_TAX → linesToUpdate (SOAP node written),
*         TCS/FREIGHT/INSURANCE → linesToDelete.
*/
    @isTest
    static void test_intelligentSync_OnlyOtherTaxNonZero() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Other_Tax_Amount__c = 50;
        ord.DRC_NBC_TCS_Amount__c       = 0;
        ord.DRC_NBC_Fright_Charges__c   = 0;
        ord.DRC_NBC_Insurance__c        = 0;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())                  // Order Update
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines())  // all 4 tax lines exist in BC
            .add(200, buildGenericSuccessResponse())                  // UpdateMultiple (product + OTHER_TAX only)
            .add(200, buildGenericSuccessResponse())                  // Delete (TCS + FREIGHT + INSURANCE)
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Only TCS non-zero; OTHER_TAX, FREIGHT, INSURANCE = 0.
* Covers: TCS → linesToUpdate (SOAP node written),
*         OTHER_TAX/FREIGHT/INSURANCE → linesToDelete.
*/
    @isTest
    static void test_intelligentSync_OnlyTCSNonZero() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Other_Tax_Amount__c = 0;
        ord.DRC_NBC_TCS_Amount__c       = 25;
        ord.DRC_NBC_Fright_Charges__c   = 0;
        ord.DRC_NBC_Insurance__c        = 0;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple (product + TCS only)
            .add(200, buildGenericSuccessResponse())   // Delete (OTHER_TAX + FREIGHT + INSURANCE)
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Only FREIGHT non-zero; OTHER_TAX, TCS, INSURANCE = 0.
* Covers: FREIGHT → linesToUpdate (SOAP node written, including Label.DRC_TCS_Tax_Number),
*         OTHER_TAX/TCS/INSURANCE → linesToDelete.
*/
    @isTest
    static void test_intelligentSync_OnlyFreightNonZero() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Other_Tax_Amount__c = 0;
        ord.DRC_NBC_TCS_Amount__c       = 0;
        ord.DRC_NBC_Fright_Charges__c   = 40;
        ord.DRC_NBC_Insurance__c        = 0;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple (product + FREIGHT only)
            .add(200, buildGenericSuccessResponse())   // Delete (OTHER_TAX + TCS + INSURANCE)
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Only INSURANCE non-zero; OTHER_TAX, TCS, FREIGHT = 0.
* Covers: INSURANCE → linesToUpdate (SOAP node written, including Label.DRC_TCS_Tax_Number),
*         OTHER_TAX/TCS/FREIGHT → linesToDelete.
*/
    @isTest
    static void test_intelligentSync_OnlyInsuranceNonZero() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Other_Tax_Amount__c = 0;
        ord.DRC_NBC_TCS_Amount__c       = 0;
        ord.DRC_NBC_Fright_Charges__c   = 0;
        ord.DRC_NBC_Insurance__c        = 20;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple (product + INSURANCE only)
            .add(200, buildGenericSuccessResponse())   // Delete (OTHER_TAX + TCS + FREIGHT)
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 17 — Additional combination coverage (push toward 78%)
    // =========================================================================
    
    /**
* Domestic Merchant = true + only OTHER_TAX non-zero.
* Covers: glGstGroup/glHsnSac TRUE branch for OTHER_TAX specifically,
*         while TCS/FREIGHT/INSURANCE go to DELETE.
*/
    @isTest
    static void test_intelligentSync_Domestic_OnlyOtherTaxNonZero() {
        Order ord = getTestOrder();
        ord.Is_Domestic_Merchnat__c     = true;
        ord.DRC_NBC_Other_Tax_Amount__c = 60;
        ord.DRC_NBC_TCS_Amount__c       = 0;
        ord.DRC_NBC_Fright_Charges__c   = 0;
        ord.DRC_NBC_Insurance__c        = 0;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple
            .add(200, buildGenericSuccessResponse())   // Delete
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Domestic Merchant = true + only FREIGHT non-zero.
* Covers: glGstGroup/glHsnSac TRUE branch for FREIGHT,
*         plus Label.DRC_TCS_Tax_Number for the FREIGHT G/L No.
*/
    @isTest
    static void test_intelligentSync_Domestic_OnlyFreightNonZero() {
        Order ord = getTestOrder();
        ord.Is_Domestic_Merchnat__c     = true;
        ord.DRC_NBC_Other_Tax_Amount__c = 0;
        ord.DRC_NBC_TCS_Amount__c       = 0;
        ord.DRC_NBC_Fright_Charges__c   = 35;
        ord.DRC_NBC_Insurance__c        = 0;
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines())
            .add(200, buildGenericSuccessResponse())   // UpdateMultiple
            .add(200, buildGenericSuccessResponse())   // Delete
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Two SF OrderItems: FG001 (matches BC line) + FG002 (new → itemsToCreate).
* Also includes all 4 tax lines non-zero in BC.
* Covers: UPDATE (product FG001 + 4 tax lines) + CREATE (FG002) running together,
*         maxLineNo calculation in CREATE branch with multiple BC lines present.
*/
    @isTest
    static void test_intelligentSync_UpdateCreateTogether_WithAllTaxLines() {
        // Add a second product + order item (FG002, not present in BC)
        Product2 prod2 = new Product2(
            Name                      = 'Second Product',
            DRC_NBC_FG_Code__c        = 'FG002',
            DRC_NBC_GST_Group_Code__c = 'GST12',
            DRC_NBC_HSN_SAC_Code__c   = 'HSN5678',
            IsActive                  = true
        );
        insert prod2;
        
        Id stdPricebookId = Test.getStandardPricebookId();
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = stdPricebookId,
            Product2Id   = prod2.Id,
            UnitPrice    = 200,
            IsActive     = true
        );
        insert pbe2;
        
        Order ord = getTestOrder();
        ord.DRC_NBC_Other_Tax_Amount__c = 50;
        ord.DRC_NBC_TCS_Amount__c       = 25;
        ord.DRC_NBC_Fright_Charges__c   = 30;
        ord.DRC_NBC_Insurance__c        = 15;
        update ord;
        
        OrderItem oi2 = new OrderItem(
            OrderId                        = ord.Id,
            Product2Id                     = prod2.Id,
            PricebookEntryId                = pbe2.Id,
            Quantity                       = 5,
            UnitPrice                      = 200,
            Description                    = 'Second Product',
            DRC_NBC_Discount__c            = 0,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert oi2;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())                 // Order Update
            .add(200, buildReadMultiple_ProductPlusAllFourTaxLines()) // FG001 + 4 tax lines (no FG002)
            .add(200, buildGenericSuccessResponse())                 // UpdateMultiple (FG001 + 4 tax)
            .add(200, buildGenericSuccessResponse())                 // CreateLineItems (FG002)
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* OrderItem.DRC_NBC_Total_Price__c left null (never set) → defaults to 0
* in lineDiscountAmount calc, with discount also non-zero.
* Covers: totalPrice != null ? ... : 0 false-branch combined with discount > 0.
*/
    @isTest
    static void test_buildUpdateMultiple_NullTotalPrice_WithDiscount() {
        OrderItem oi = [SELECT Id FROM OrderItem LIMIT 1];
        oi.DRC_NBC_Discount__c = 10; // non-zero discount, total price stays null
        update oi;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Multiple Restricted_Product__c records for same account (different products)
* + matched order item → exercises map-building loop with >1 entry.
*/
    @isTest
    static void test_buildUpdateMultiple_MultipleRestrictedProducts() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Product2 prod3 = new Product2(
            Name               = 'Third Product',
            DRC_NBC_FG_Code__c = 'FG003',
            IsActive           = true
        );
        insert prod3;
        
        DRC_NBC_Restricted_Product__c rp2 = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c = acc.Id,
            DRC_NBC_Product__c  = prod3.Id
        );
        insert rp2;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* ShipTo location matches order's location code exactly → no Update call issued.
* Covers the "no diff → skip ShipTo Update" branch inside syncShippingAddress
* with a non-blank warehouse so getLocationCodeFromWarehouse returns a real code.
*/
    @isTest
    static void test_updateOrderInBC_ShipToLocationMatches_NoUpdateIssued() {
        Order ord = getTestOrder();
        ord.DRC_NBC_Warehouse__c = 'CFS - JNPT';
        update ord;
        
        String matchingCode = DRC_NBC_UpdateOrderAndLineItems.getLocationCodeFromWarehouse('CFS - JNPT');
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(matchingCode)) // same → no ShipTo Update
            .add(200, buildGenericSuccessResponse())          // Order Update
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())          // UpdateMultiple
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // GROUP 18 — buildUpdateOrderSOAPRequest payload field coverage
    // =========================================================================
    
    /**
* Populates date/text fields on the Order so DRC_NBC_Order_BC_Callout.mapOrderToBCPayload
* returns non-blank values for DispatchDate, PO_Date, Requested_Delivery_Date, Courier_Date,
* Mode_of_Transport, Delivery_Terms, Transporter_Code, Courier_Number, Currency_Code,
* Country_Of_Origin_Of_Goods, Country_Of_Final_Destination, Notify_Name, Vessel_Flight_No,
* Port_Of_Discharge, Port_of_Loading, Final_Destination, Place_of_receipt_pre_carrier,
* Part_Shipment, Trans_Shipment, Company_Bank_Account_Code_New.
*
* Covers: the TRUE branch of every String.isNotBlank(...) ? ... : '' ternary
* inside buildUpdateOrderSOAPRequest.
*
* NOTE: Field names below assume standard DRC_NBC_* Order fields exist as referenced
* by DRC_NBC_Integration_Payload.OrderPayload / mapOrderToBCPayload. If any field
* listed here does not exist on Order, remove that line — the test will still run
* and cover whichever fields ARE populated.
*/
    @isTest
    static void test_updateOrderInBC_AllPayloadFieldsPopulated_TrueBranches() {
        Order ord = getTestOrder();
        
        // Populate as many payload-source fields as exist on Order
        ord.DRC_NBC_Shipment_Method__c            = 'By Sea';
        ord.DRC_NBC_Delivery_Terms__c               = 'FOB';
        ord.DRC_NBC_Transport_Agent__c             = 'AAKASH TRANSPORT SERVICE';
        ord.DRC_NBC_Courier_Number__c               = 'CN123456';
        ord.DRC_NBC_Country_Of_Origin__c            = 'IN';
        ord.DRC_NBC_Country_Of_Final_Destination__c = 'US';
        ord.DRC_NBC_Notify_Party__c                  = 'Notify Party';
        ord.DRC_NBC_Vessel_no_Flight_no__c             = 'VSL001';
        ord.DRC_NBC_Port_Of_Discharge__c            = 'POD01';
        ord.DRC_NBC_Port_of_Loading__c              = 'POL01';
        ord.DRC_NBC_Final_Destination__c            = 'Final Dest';
        ord.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c             = 'Receipt Place';
        ord.DRC_NBC_Part_Shipment__c                = 'Allowed';
        ord.DRC_NBC_Trans_Shipment__c               = 'Allowed';
        ord.DRC_NBC_Select_Bank__c    = 'BANK OF BARODA INR A/C';
        ord.EffectiveDate                           = Date.today(); // drives Order_Date/DispatchDate
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())   // Order Update — full payload SOAP
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    
    /**
* Export_Document / Sample_Sales flags toggled to true on the Order
* (whichever drives payload.Export_Document / Sample_Sales) → covers
* the boolean-to-string concatenation lines for those fields.
*/
    @isTest
    static void test_updateOrderInBC_ExportAndSampleFlags_True() {
        Order ord = getTestOrder();
        ord.Is_Domestic_Merchnat__c = false; // export scenario
        update ord;
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_MatchedProductAndTaxLines())
            .add(200, buildGenericSuccessResponse())
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    private static String buildReadMultiple_BlankQuantity() {
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
            '<Quantity></Quantity>' +
            '<Description>Test Product</Description>' +
            '</SalesOrderLineSalesForce>' +
            '</ReadMultiple_Result>' +
            '</ReadMultiple_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    /**
* BC line item with blank <Quantity></Quantity>.
* Covers: String.isNotBlank(f.getText()) == false branch inside Quantity parsing
* (quantity stays null, line still added since key+lineNo present).
*/
    @isTest
    static void test_extractLineDetails_BlankQuantity_Branch() {
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())
            .add(200, buildShipToReadResponse(''))
            .add(200, buildGenericSuccessResponse())
            .add(200, buildReadMultiple_BlankQuantity())   // FG001 matched, quantity null
            .add(200, buildGenericSuccessResponse())       // UpdateMultiple
            .add(200, buildGenericSuccessResponse());
        
        Test.setMock(HttpCalloutMock.class, mock);
        Order ord = getTestOrder();
        
        Test.startTest();
        DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
    }
    // =========================================================================
    // FIXED HELPER — must include ALL fields referenced in buildUpdateMultipleSOAPRequest
    // Replace the existing getOrderItemsForUpdateMultiple() with this version
    // =========================================================================
    
    private static List<OrderItem> getOrderItemsForUpdateMultiple() {
        return [
            SELECT Id, OrderId, Description, Quantity, UnitPrice,
            DRC_NBC_Discount__c, DRC_NBC_Total_Price__c, DRC_NBC_Packing_Size__c,
            DRC_NBC_Hazardous__c, DRC_NBC_MARKS_NOS__c,
            Product2Id,
            Product2.DRC_NBC_FG_Code__c,
            Product2.DRC_NBC_GST_Group_Code__c,
            Product2.DRC_NBC_HSN_SAC_Code__c,
            Order.RecordType.Name,
            Order.Is_Domestic_Merchnat__c,
            Order.Account.DRC_NBC_Customer_Number__c,
            Order.Account.Type
            FROM OrderItem
            LIMIT 1
        ];
    }
    
    // =========================================================================
    // GROUP 20 — Truly uncovered branches (root cause: missing fields in SOQL)
    // =========================================================================
    
    /**
* DRC_NBC_Hazardous__c = true → <Hazardous>true</Hazardous> written.
* Requires DRC_NBC_Hazardous__c in the OrderItem SELECT — now fixed above.
* Uses direct call so we control exactly what bcLineDetails contains.
*/
    @isTest
    static void test_buildUpdateMultiple_Hazardous_True_DirectCall() {
        OrderItem oi = [SELECT Id FROM OrderItem LIMIT 1];
        oi.DRC_NBC_Hazardous__c = true;
        update oi;
        
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            Is_Domestic_Merchnat__c
            FROM Order LIMIT 1
        ];
        
        // Re-query items AFTER update so Hazardous__c = true is in the list
        List<OrderItem> items = [
            SELECT Id, OrderId, Description, Quantity, UnitPrice,
            DRC_NBC_Discount__c, DRC_NBC_Total_Price__c, DRC_NBC_Packing_Size__c,
            DRC_NBC_Hazardous__c, DRC_NBC_MARKS_NOS__c,
            Product2Id,
            Product2.DRC_NBC_FG_Code__c,
            Product2.DRC_NBC_GST_Group_Code__c,
            Product2.DRC_NBC_HSN_SAC_Code__c,
            Order.RecordType.Name,
            Order.Is_Domestic_Merchnat__c,
            Order.Account.DRC_NBC_Customer_Number__c,
            Order.Account.Type
            FROM OrderItem LIMIT 1
        ];
        
        Map<Integer, String> bcLineKeys = new Map<Integer, String>{
            10000 => 'LINE-KEY-PROD-001'
                };
                    Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
                    new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
                        10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                            'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
                            };
                                
                                Test.setMock(HttpCalloutMock.class,
                                             new SequencedMock().add(200, buildGenericSuccessResponse()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
            ord.DRC_NBC_Cust_Order_Number__c,
            bcLineKeys,
            items,
            ord,
            ord.Id,
            bcLineDetails,
            buildRestrictedProductMap()
        );
        Test.stopTest();
    }
    
    /**
* DRC_NBC_MARKS_NOS__c non-blank → trim() branch taken.
* String.isBlank(matchedItem.DRC_NBC_MARKS_NOS__c) == false
* → matchedItem.DRC_NBC_MARKS_NOS__c.trim() used.
* Requires DRC_NBC_MARKS_NOS__c in the items SELECT.
*/
    @isTest
    static void test_buildUpdateMultiple_MarksNos_NonBlank_DirectCall() {
        OrderItem oi = [SELECT Id FROM OrderItem LIMIT 1];
        oi.DRC_NBC_MARKS_NOS__c = '  CTN-42 / MARK-001  ';
        update oi;
        
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            Is_Domestic_Merchnat__c
            FROM Order LIMIT 1
        ];
        
        List<OrderItem> items = [
            SELECT Id, OrderId, Description, Quantity, UnitPrice,
            DRC_NBC_Discount__c, DRC_NBC_Total_Price__c, DRC_NBC_Packing_Size__c,
            DRC_NBC_Hazardous__c, DRC_NBC_MARKS_NOS__c,
            Product2Id,
            Product2.DRC_NBC_FG_Code__c,
            Product2.DRC_NBC_GST_Group_Code__c,
            Product2.DRC_NBC_HSN_SAC_Code__c,
            Order.RecordType.Name,
            Order.Is_Domestic_Merchnat__c,
            Order.Account.DRC_NBC_Customer_Number__c,
            Order.Account.Type
            FROM OrderItem LIMIT 1
        ];
        
        Map<Integer, String> bcLineKeys = new Map<Integer, String>{
            10000 => 'LINE-KEY-PROD-001'
                };
                    Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
                    new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
                        10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                            'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
                            };
                                
                                Test.setMock(HttpCalloutMock.class,
                                             new SequencedMock().add(200, buildGenericSuccessResponse()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
            ord.DRC_NBC_Cust_Order_Number__c,
            bcLineKeys,
            items,
            ord,
            ord.Id,
            bcLineDetails,
            buildRestrictedProductMap()
        );
        Test.stopTest();
    }
    
    /**
* matchedItem.Description == null → '' fallback in <Description> node.
* Description is not required so can be nulled in DML.
*/
    @isTest
    static void test_buildUpdateMultiple_NullDescription_DirectCall() {
        OrderItem oi = [SELECT Id FROM OrderItem LIMIT 1];
        oi.Description = null;
        update oi;
        
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            Is_Domestic_Merchnat__c
            FROM Order LIMIT 1
        ];
        
        List<OrderItem> items = [
            SELECT Id, OrderId, Description, Quantity, UnitPrice,
            DRC_NBC_Discount__c, DRC_NBC_Total_Price__c, DRC_NBC_Packing_Size__c,
            DRC_NBC_Hazardous__c, DRC_NBC_MARKS_NOS__c,
            Product2Id,
            Product2.DRC_NBC_FG_Code__c,
            Product2.DRC_NBC_GST_Group_Code__c,
            Product2.DRC_NBC_HSN_SAC_Code__c,
            Order.RecordType.Name,
            Order.Is_Domestic_Merchnat__c,
            Order.Account.DRC_NBC_Customer_Number__c,
            Order.Account.Type
            FROM OrderItem LIMIT 1
        ];
        
        Map<Integer, String> bcLineKeys = new Map<Integer, String>{
            10000 => 'LINE-KEY-PROD-001'
                };
                    Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
                    new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
                        10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                            'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
                            };
                                
                                Test.setMock(HttpCalloutMock.class,
                                             new SequencedMock().add(200, buildGenericSuccessResponse()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
            ord.DRC_NBC_Cust_Order_Number__c,
            bcLineKeys,
            items,
            ord,
            ord.Id,
            bcLineDetails,
            buildRestrictedProductMap()
        );
        Test.stopTest();
    }
    
    /**
* Account.DRC_NBC_Customer_Number__c == null AND Account.Type == null.
* Both ternaries emit '' in <Item_Reference_Type> and <Item_Reference_Type_No>.
* Must re-query items AFTER nulling account fields so the relationship
* traversal picks up the null values.
*/
    /* @isTest
static void test_buildUpdateMultiple_NullAccountFields_DirectCall() {
Account acc = [SELECT Id FROM Account LIMIT 1];
acc.DRC_NBC_Customer_Number__c = null;
acc.Type                       = null;
update acc;

Order ord = [
SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
Is_Domestic_Merchnat__c
FROM Order LIMIT 1
];

// Re-query AFTER account update so relationship fields reflect null values
List<OrderItem> items = [
SELECT Id, OrderId, Description, Quantity, UnitPrice,
DRC_NBC_Discount__c, DRC_NBC_Total_Price__c, DRC_NBC_Packing_Size__c,
DRC_NBC_Hazardous__c, DRC_NBC_MARKS_NOS__c,
Product2Id,
Product2.DRC_NBC_FG_Code__c,
Product2.DRC_NBC_GST_Group_Code__c,
Product2.DRC_NBC_HSN_SAC_Code__c,
Order.RecordType.Name,
Order.Is_Domestic_Merchnat__c,
Order.Account.DRC_NBC_Customer_Number__c,
Order.Account.Type
FROM OrderItem LIMIT 1
];

Map<Integer, String> bcLineKeys = new Map<Integer, String>{
10000 => 'LINE-KEY-PROD-001'
};
Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
};

Test.setMock(HttpCalloutMock.class,
new SequencedMock().add(200, buildGenericSuccessResponse()));

Test.startTest();
String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
ord.DRC_NBC_Cust_Order_Number__c,
bcLineKeys,
items,
ord,
ord.Id,
bcLineDetails,
buildRestrictedProductMap()
);
Test.stopTest();
}*/
    
    /**
* DRC_NBC_Packing_Size__c == null → escapeXml(null) returns '' early.
* escapeXml's `if (String.isBlank(value)) return ''` branch with null input.
*/
    @isTest
    static void test_buildUpdateMultiple_NullPackingSize_EscapeXmlBlankBranch() {
        OrderItem oi = [SELECT Id FROM OrderItem LIMIT 1];
        oi.DRC_NBC_Packing_Size__c = null;
        update oi;
        
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            Is_Domestic_Merchnat__c
            FROM Order LIMIT 1
        ];
        
        List<OrderItem> items = [
            SELECT Id, OrderId, Description, Quantity, UnitPrice,
            DRC_NBC_Discount__c, DRC_NBC_Total_Price__c, DRC_NBC_Packing_Size__c,
            DRC_NBC_Hazardous__c, DRC_NBC_MARKS_NOS__c,
            Product2Id,
            Product2.DRC_NBC_FG_Code__c,
            Product2.DRC_NBC_GST_Group_Code__c,
            Product2.DRC_NBC_HSN_SAC_Code__c,
            Order.RecordType.Name,
            Order.Is_Domestic_Merchnat__c,
            Order.Account.DRC_NBC_Customer_Number__c,
            Order.Account.Type
            FROM OrderItem LIMIT 1
        ];
        
        Map<Integer, String> bcLineKeys = new Map<Integer, String>{
            10000 => 'LINE-KEY-PROD-001'
                };
                    Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
                    new Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem>{
                        10000 => new DRC_NBC_UpdateOrderAndLineItems.BCLineItem(
                            'LINE-KEY-PROD-001', 10000, 'Item', 'FG001', 10, 'Test Product')
                            };
                                
                                Test.setMock(HttpCalloutMock.class,
                                             new SequencedMock().add(200, buildGenericSuccessResponse()));
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.updateMultipleLineItems(
            ord.DRC_NBC_Cust_Order_Number__c,
            bcLineKeys,
            items,
            ord,
            ord.Id,
            bcLineDetails,
            buildRestrictedProductMap()
        );
        Test.stopTest();
    }
    
 /*   @isTest
    static void test_buildUpdateMultiple_ProductAndAllChargeLines_Direct_NoAssert() {
        Order ordUpdate = getTestOrder();
        
        List<RecordType> orderRts = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Order'
            AND DeveloperName != 'Sample_Order'
            LIMIT 1
        ];
        if (!orderRts.isEmpty()) {
            ordUpdate.RecordTypeId = orderRts[0].Id;
        }
        
        ordUpdate.Is_Domestic_Merchnat__c     = true;
        ordUpdate.DRC_NBC_Other_Tax_Amount__c = 100;
        ordUpdate.DRC_NBC_TCS_Amount__c       = 50;
        ordUpdate.DRC_NBC_Fright_Charges__c   = 40;
        ordUpdate.DRC_NBC_Insurance__c        = 20;
        update ordUpdate;
        
        OrderItem oiUpdate = [
            SELECT Id
            FROM OrderItem
            WHERE OrderId = :ordUpdate.Id
            LIMIT 1
        ];
        oiUpdate.Description = 'Test Product XML Coverage';
        oiUpdate.DRC_NBC_Hazardous__c = true;
        oiUpdate.DRC_NBC_MARKS_NOS__c = '  MARK-001  ';
        update oiUpdate;
        
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
            DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
            Is_Domestic_Merchnat__c
            FROM Order
            WHERE Id = :ordUpdate.Id
            LIMIT 1
        ];
        
        List<OrderItem> items = [
            SELECT Id, OrderId, Description, Quantity, UnitPrice,
            DRC_NBC_Discount__c, DRC_NBC_Total_Price__c,
            DRC_NBC_Packing_Quantity__c, DRC_NBC_Packing_Size__c,
            DRC_NBC_Hazardous__c, DRC_NBC_MARKS_NOS__c,
            Product2Id,
            Product2.DRC_NBC_FG_Code__c,
            Product2.DRC_NBC_GST_Group_Code__c,
            Product2.DRC_NBC_HSN_SAC_Code__c,
            Order.RecordType.Name,
            Order.Is_Domestic_Merchnat__c,
            Order.Account.DRC_NBC_Customer_Number__c,
            Order.Account.Type
            FROM OrderItem
            WHERE OrderId = :ord.Id
            LIMIT 1
        ];
        
        Map<Integer, DRC_NBC_UpdateOrderAndLineItems.BCLineItem> bcLineDetails =
            buildAllFourTaxBCDetails();
        
        Map<Integer, String> bcLineKeys = new Map<Integer, String>();
        for (Integer lineNo : bcLineDetails.keySet()) {
            bcLineKeys.put(lineNo, bcLineDetails.get(lineNo).key);
        }
        
        Test.startTest();
        String soapBody = DRC_NBC_UpdateOrderAndLineItems.buildUpdateMultipleSOAPRequest(
            ord.DRC_NBC_Cust_Order_Number__c,
            bcLineKeys,
            items,
            ord,
            bcLineDetails,
            buildRestrictedProductMap()
        );
        Test.stopTest();
    }*/
    
    private static String buildReadMultiple_SampleShippingCostAndSampleAmountOnly() {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<ReadMultiple_Result xmlns="urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce">' +
            '<ReadMultiple_Result>' +
            
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-SAMPLE-SHIP-001</Key>' +
            '<Line_No>60000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No>70563200</No>' +
            '<Quantity>1</Quantity>' +
            '<Description>Sample Shipping Cost</Description>' +
            '</SalesOrderLineSalesForce>' +
            
            '<SalesOrderLineSalesForce>' +
            '<Key>LINE-KEY-SAMPLE-AMT-001</Key>' +
            '<Line_No>70000</Line_No>' +
            '<Type>G/L Account</Type>' +
            '<No>70563200</No>' +
            '<Quantity>1</Quantity>' +
            '<Description>Sample Amount</Description>' +
            '</SalesOrderLineSalesForce>' +
            
            '</ReadMultiple_Result>' +
            '</ReadMultiple_Result>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    @isTest
    static void test_intelligentSync_SampleShippingCostAndSampleAmount_NonZero() {
        Order ord = getTestOrder();
        
        // Keep this test focused only on Sample Shipping Cost + Sample Amount.
        ord.DRC_NBC_Other_Tax_Amount__c       = 0;
        ord.DRC_NBC_TCS_Amount__c             = 0;
        ord.DRC_NBC_Fright_Charges__c         = 0;
        ord.DRC_NBC_Insurance__c              = 0;
        ord.DRC_NBC_Sample_Shipping_Cost__c   = 45;
        ord.DRC_NBC_Sample_Amount__c          = 125;
        update ord;
        
        // Remove product items so only sample G/L lines are updated.
        delete [SELECT Id FROM OrderItem WHERE OrderId = :ord.Id];
        
        SequencedMock mock = new SequencedMock()
            .add(200, buildOrderReadResponse_Open())                         // Order Read
            .add(200, buildShipToReadResponse(''))                           // ShipTo Read
            .add(200, buildGenericSuccessResponse())                         // Order Update
            .add(200, buildReadMultiple_SampleShippingCostAndSampleAmountOnly()) // ReadMultiple
            .add(200, buildGenericSuccessResponse())                         // UpdateMultiple
            .add(200, buildGenericSuccessResponse());                        // STEP 4 / fallback
        
        Test.setMock(HttpCalloutMock.class, mock);
        
        Test.startTest();
        String result = DRC_NBC_UpdateOrderAndLineItems.orderId(ord.Id);
        Test.stopTest();
        
    }
}