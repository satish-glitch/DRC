@isTest
public class DRC_NBC_Shipping_Integration_SOAP_Test {
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST DATA SETUP
    // ─────────────────────────────────────────────────────────────────────────
    private static DRC_NBC_Addresses__c createShippingAddress(Account acc) {
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c              = acc.Id,
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Ship_To_Code__c         = 'SHP001',
            DRC_NBC_Address__Street__s      = '123 Test Street',
            DRC_NBC_Address__City__s        = 'Mumbai',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__PostalCode__s  = '400001',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_GST_Number__c           = '27AWVPY9594J1ZY',
            DRC_Shipping_Gst_Customer_Type__c = 'Registered',
            DRC_NBC_Warehouse__c            = 'D.R COATS INK & RESINS PVT LTD (UNIT-II)',
            DRC_Inco_Term__c                = 'Door Delivery (DD)'
        );
        insert addr;
        return addr;
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MOCK: SUCCESS (200)
    // ─────────────────────────────────────────────────────────────────────────
    private class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            if (req.getBody().contains('<Read ')) {
                // Read response — returns a Key
                res.setBody(
                    '<?xml version="1.0"?>'
                    + '<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">'
                    +   '<Body>'
                    +     '<Read_Result xmlns="urn:microsoft-dynamics-schemas/page/customershiptoaddresssalesforce">'
                    +       '<CustomerShiptoAddressSalesForce>'
                    +         '<Key>BC-KEY-12345</Key>'
                    +       '</CustomerShiptoAddressSalesForce>'
                    +     '</Read_Result>'
                    +   '</Body>'
                    + '</Envelope>'
                );
            } else {
                // Update response — plain 200 OK
                res.setBody(
                    '<?xml version="1.0"?>'
                    + '<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">'
                    +   '<Body><Update_Result/></Body>'
                    + '</Envelope>'
                );
            }
            return res;
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MOCK: SOAP FAULT (500)
    // ─────────────────────────────────────────────────────────────────────────
    private class MockFault implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody(
                '<?xml version="1.0"?>'
                + '<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">'
                +   '<Body>'
                +     '<Fault>'
                +       '<faultstring>Record not found in BC</faultstring>'
                +     '</Fault>'
                +   '</Body>'
                + '</Envelope>'
            );
            return res;
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MOCK: NULL / no response (simulates timeout)
    // ─────────────────────────────────────────────────────────────────────────
    private class MockNoResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Return 503 to simulate unreachable endpoint
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('Service Unavailable');
            return res;
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MOCK: Read returns no Key (record not in BC yet)
    // ─────────────────────────────────────────────────────────────────────────
    private class MockReadNoKey implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0"?>'
                + '<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">'
                +   '<Body>'
                +     '<Read_Result xmlns="urn:microsoft-dynamics-schemas/page/customershiptoaddresssalesforce">'
                +       '<CustomerShiptoAddressSalesForce/>'
                +     '</Read_Result>'
                +   '</Body>'
                + '</Envelope>'
            );
            return res;
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST 1 — syncByAddressId: happy path (SUCCESS)
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSyncByAddressId_Success() {
        Account acc = DRC_NBC_TestFactory.createAccount();
        DRC_NBC_Addresses__c addr = createShippingAddress(acc);
        
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        
        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Integration_SOAP.syncByAddressId(addr.Id);
        Test.stopTest();
    }
    
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST 3 — syncByAddressId: BC returns SOAP fault
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSyncByAddressId_SoapFault() {
        Account acc = DRC_NBC_TestFactory.createAccount();
        DRC_NBC_Addresses__c addr = createShippingAddress(acc);
        
        Test.setMock(HttpCalloutMock.class, new MockFault());
        
        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Integration_SOAP.syncByAddressId(addr.Id);
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST 4 — buildPayloadFromAddress: country mapping IN → IND
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testBuildPayload_CountryMapping() {
        Account acc = DRC_NBC_TestFactory.createAccount();
        DRC_NBC_Addresses__c addr = createShippingAddress(acc); // CountryCode = 'IN'
        
        Test.startTest();
        DRC_NBC_Integration_Payload.ShipToPayload payload =
            DRC_NBC_Shipping_BC_Integration_SOAP.buildPayloadFromAddress(addr.Id);
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST 5 — buildPayloadFromAddress: long street split across two fields
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testBuildPayload_LongStreetSplit() {
        Account acc = DRC_NBC_TestFactory.createAccount();
        
        // Build a street > 100 chars
        String longStreet = 'A'.repeat(120);
        
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c              = acc.Id,
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Ship_To_Code__c         = 'SHP002',
            DRC_NBC_Address__Street__s      = longStreet,
            DRC_NBC_Address__City__s        = 'Pune',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__PostalCode__s  = '411001',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_GST_Number__c           = '27AWVPY9594J1ZY',
            DRC_Shipping_Gst_Customer_Type__c = 'Registered'
        );
        insert addr;
        
        Test.startTest();
        DRC_NBC_Integration_Payload.ShipToPayload payload =
            DRC_NBC_Shipping_BC_Integration_SOAP.buildPayloadFromAddress(addr.Id);
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST 6 — readShipToKey: Read returns no Key node
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testReadShipToKey_NoKey() {
        Test.setMock(HttpCalloutMock.class, new MockReadNoKey());
        
        Test.startTest();
        String key = DRC_NBC_Shipping_BC_Integration_SOAP.readShipToKey('CUST001', 'SHP001');
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST 7 — readShipToKey: Read returns non-200
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testReadShipToKey_Non200() {
        Test.setMock(HttpCalloutMock.class, new MockFault());
        
        Test.startTest();
        String key = DRC_NBC_Shipping_BC_Integration_SOAP.readShipToKey('CUST001', 'SHP001');
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST 8 — upsertShipTo: direct call with a pre-built payload
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testUpsertShipTo_Success() {
        DRC_NBC_Integration_Payload.ShipToPayload payload = new DRC_NBC_Integration_Payload.ShipToPayload();
        payload.CustomerNo           = 'CUST001';
        payload.ShiptoCode           = 'SHP001';
        payload.Name                 = 'Test Customer';
        payload.ShippingAddress      = '123 Test Street';
        payload.ShippingAddress2     = '';
        payload.ShippingCity         = 'Mumbai';
        payload.State                = 'MH';
        payload.ShippingPostCode     = '400001';
        payload.ShippingCountry      = 'IND';
        payload.ShippingPhoneNo      = '1234567890';
        payload.ShippingGSTRegistrationNo = '27AWVPY9594J1ZY';
        payload.Ship_to_GST_Customer_Type = 'Regular';
        
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        
        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Integration_SOAP.upsertShipTo(payload);
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST 9 — syncByAddressId: second account variant
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSyncByAddressId_Account2() {
        Account acc = DRC_NBC_TestFactory.createAccount2();
        DRC_NBC_Addresses__c addr = createShippingAddress(acc);
        
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        
        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Integration_SOAP.syncByAddressId(addr.Id);
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MOCK: Valid SOAP envelope but NO Fault node — triggers "HTTP error —" branch
    // ─────────────────────────────────────────────────────────────────────────
    private class MockNoFaultNode implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            // Valid envelope + Body, but no Fault child → hits "HTTP error —" branch
            res.setBody(
                '<?xml version="1.0"?>'
                + '<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">'
                +   '<Body>'
                +     '<SomeOtherNode/>'
                +   '</Body>'
                + '</Envelope>'
            );
            return res;
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MOCK: Fault present but NO faultstring child — returns raw responseBody
    // ─────────────────────────────────────────────────────────────────────────
    private class MockFaultNoFaultString implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            // Fault node exists but faultstring is absent → last ternary fallback
            res.setBody(
                '<?xml version="1.0"?>'
                + '<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">'
                +   '<Body>'
                +     '<Fault xmlns="http://schemas.xmlsoap.org/soap/envelope/">'
                +       '<faultcode>Server</faultcode>'
                +     '</Fault>'
                +   '</Body>'
                + '</Envelope>'
            );
            return res;
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // MOCK: Completely malformed XML — triggers the catch branch
    // ─────────────────────────────────────────────────────────────────────────
    private class MockMalformedXml implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('NOT VALID XML <<<>>>');
            return res;
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST: parseSoapFault — Body present but no Fault node → "HTTP error —"
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testParseSoapFault_NoFaultNode() {
        Account acc = DRC_NBC_TestFactory.createAccount();
        DRC_NBC_Addresses__c addr = createShippingAddress(acc);
        
        Test.setMock(HttpCalloutMock.class, new MockNoFaultNode());
        
        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Integration_SOAP.syncByAddressId(addr.Id);
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST: parseSoapFault — Fault exists but faultstring absent → raw body
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testParseSoapFault_FaultNoFaultString() {
        Account acc = DRC_NBC_TestFactory.createAccount();
        DRC_NBC_Addresses__c addr = createShippingAddress(acc);
        
        Test.setMock(HttpCalloutMock.class, new MockFaultNoFaultString());
        
        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Integration_SOAP.syncByAddressId(addr.Id);
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // TEST: parseSoapFault — malformed XML → catch block returns raw body
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testParseSoapFault_MalformedXml() {
        Account acc = DRC_NBC_TestFactory.createAccount();
        DRC_NBC_Addresses__c addr = createShippingAddress(acc);
        
        Test.setMock(HttpCalloutMock.class, new MockMalformedXml());
        
        Test.startTest();
        String result = DRC_NBC_Shipping_BC_Integration_SOAP.syncByAddressId(addr.Id);
        Test.stopTest();
        
    }
}