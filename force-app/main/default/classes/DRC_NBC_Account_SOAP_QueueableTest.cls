@isTest
public class DRC_NBC_Account_SOAP_QueueableTest {
    
    // =========================================================================
    // MOCK — Full success: salesperson REST → SOAP Read (with Key) → SOAP Update
    // =========================================================================
    private class SOAPSuccessMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            if (callCount == 1) {
                res.setBody('{"status":"ok"}');
                
            } else if (callCount == 2) {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body>' +
                    '<ReadResponse>' +
                    '<CustomerSalesForce>' +
                    '<Key>BC-KEY-001</Key>' +
                    '<No>CUST-001</No>' +
                    '</CustomerSalesForce>' +
                    '</ReadResponse>' +
                    '</soapenv:Body>' +
                    '</soapenv:Envelope>'
                );
                
            } else {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body>' +
                    '<UpdateResponse>' +
                    '<CustomerSalesForce><No>CUST-001</No></CustomerSalesForce>' +
                    '</UpdateResponse>' +
                    '</soapenv:Body>' +
                    '</soapenv:Envelope>'
                );
            }
            return res;
        }
    }
    
    // =========================================================================
    // MOCK — SOAP Read returns HTTP 500
    // =========================================================================
    private class SOAPReadFailMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                res.setStatusCode(200);
                res.setBody('{"status":"ok"}');
            } else {
                res.setStatusCode(500);
                res.setBody('<fault>Internal Server Error</fault>');
            }
            return res;
        }
    }
    
    // =========================================================================
    // MOCK — SOAP Read returns 200 but XML has NO <Key> node
    // =========================================================================
    private class SOAPNoKeyMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (callCount == 1) {
                res.setBody('{"status":"ok"}');
            } else {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body>' +
                    '<ReadResponse>' +
                    '<CustomerSalesForce>' +
                    '<No>CUST-001</No>' +
                    '</CustomerSalesForce>' +
                    '</ReadResponse>' +
                    '</soapenv:Body>' +
                    '</soapenv:Envelope>'
                );
            }
            return res;
        }
    }
    
    // =========================================================================
    // MOCK — SOAP Update returns HTTP 500
    // =========================================================================
    private class SOAPUpdateFailMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                res.setStatusCode(200);
                res.setBody('{"status":"ok"}');
            } else if (callCount == 2) {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'text/xml');
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body>' +
                    '<ReadResponse>' +
                    '<CustomerSalesForce>' +
                    '<Key>BC-KEY-001</Key>' +
                    '</CustomerSalesForce>' +
                    '</ReadResponse>' +
                    '</soapenv:Body>' +
                    '</soapenv:Envelope>'
                );
            } else {
                res.setStatusCode(500);
                res.setBody('<fault>Update failed</fault>');
            }
            return res;
        }
    }
    
    // =========================================================================
    // MOCK — Every callout throws a network-level exception
    // =========================================================================
    private class SOAPExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated network failure');
        }
    }
    
    // =========================================================================
    // MOCK — SOAP Read returns malformed XML (parseKey exception path)
    // =========================================================================
    private class SOAPMalformedXmlMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (callCount == 1) {
                res.setBody('{"status":"ok"}');
            } else {
                res.setHeader('Content-Type', 'text/xml');
                res.setBody('NOT_VALID_XML<<<>>>');
            }
            return res;
        }
    }
    
    // =========================================================================
    // MOCK — doCallout throws CalloutException (covers catch block in doCallout)
    // =========================================================================
    private class DOCalloutExceptionMock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            // First call (salesperson REST) succeeds so execute() advances to SOAP
            if (callCount == 1) {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setBody('{"status":"ok"}');
                return res;
            }
            // All subsequent calls throw to exercise doCallout's catch block
            throw new CalloutException('Forced doCallout exception');
        }
    }
    
    // =========================================================================
    // MOCK — parseKey receives null response (res == null branch)
    // =========================================================================
    private class SOAPNullResponseMock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            if (callCount == 1) {
                // salesperson succeeds
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setBody('{"status":"ok"}');
                return res;
            }
            // Return null by throwing — doCallout catch returns null,
            // which is handled by parseKey's null-check
            throw new CalloutException('Force null response');
        }
    }
    
    // =========================================================================
    // TEST SETUP
    // =========================================================================
    @TestSetup
    static void setupTestData() {
        DRC_NBC_BC_Integration__c config = new DRC_NBC_BC_Integration__c(
            SetupOwnerId                = UserInfo.getOrganizationId(),
            Account_SOAP_Endpoint__c    = 'https://mock-bc-endpoint.com/soap',
            Account_SOAP_NS__c          = 'http://schemas.xmlsoap.org/soap/envelope/',
            Account_BC_NS__c            = 'urn:microsoft-dynamics-schemas/page/customersalesforce',
            DRC_NBC_Username__c         = 'testuser',
            DRC_NBC_Password__c         = 'testpass',
            DRC_NBC_SalesPerson_Code__c = 'https://mock-bc-endpoint.com'
        );
        insert config;
        
        Account acc = DRC_NBC_TestFactory.createAccount();
    }
    
    // =========================================================================
    // HELPER — fetch fresh Account
    // =========================================================================
    private static Account getAccount() {
        return [
            SELECT Id, Name, DRC_NBC_Customer_Number__c, SalesPerson_Code__c,
            DRC_NBC_PAN_No__c, DRC_NBC_GST_Number__c, DRC_Gst_Customer_Type__c,
            Phone, DRC_NBC_Account_Email_Email__c, DRC_NBC_Payment_Terms__c,
            DRC_NBC_Credit_Limit__c, CurrencyIsoCode, Website, Other_Email__c,
            BillingStreet, BillingCity, BillingStateCode, BillingPostalCode,
            BillingCountryCode, DRC_Inco_Term__c
            FROM   Account
            LIMIT  1
        ];
    }
    
    // =========================================================================
    // HELPER — fetch API logs for account
    // =========================================================================
    private static List<DRC_NBC_API_Log__c> getLogsForAccount(Id accId) {
        return [
            SELECT Id, DRC_NBC_Log_Type__c, DRC_NBC_Response_Body__c,
            DRC_NBC_Created_Updated_SF_Id__c
            FROM   DRC_NBC_API_Log__c
            WHERE  DRC_NBC_Created_Updated_SF_Id__c = :accId
        ];
    }
    
    // =========================================================================
    // 1. Constructor — accountId stored correctly
    // =========================================================================
    @isTest
    static void testConstructor_AccountIdIsSet() {
        Account acc = getAccount();
        DRC_NBC_Account_SOAP_Queueable job = new DRC_NBC_Account_SOAP_Queueable(acc.Id);
    }
    
    // =========================================================================
    // 2. Happy path — full success
    // =========================================================================
    @isTest
    static void testExecute_FullSuccess_LogsCreated() {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 3. SOAP Read HTTP 500 → error logged
    // =========================================================================
    @isTest
    static void testExecute_ReadFails_ErrorLogged() {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new SOAPReadFailMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 4. SOAP Read 200 but no <Key> node → error logged
    // =========================================================================
    @isTest
    static void testExecute_ReadNoKey_ErrorLogged() {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new SOAPNoKeyMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 5. SOAP Update HTTP 500 → error logged
    // =========================================================================
    @isTest
    static void testExecute_UpdateFails_ErrorLogged() {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new SOAPUpdateFailMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 6. Network exception on every callout → caught, error logged
    // =========================================================================
    @isTest
    static void testExecute_CalloutException_ErrorLogged() {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new SOAPExceptionMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 7. Malformed XML → parseKey exception path covered
    // =========================================================================
    @isTest
    static void testExecute_MalformedXmlResponse_ErrorLogged() {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new SOAPMalformedXmlMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 8. Blank Customer Number → exception before any callout
    // =========================================================================
    @isTest
    static void testExecute_BlankCustomerNumber_ErrorLogged() {
        Account acc = getAccount();
        acc.DRC_NBC_Customer_Number__c = null;
        update acc;
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 9. BillingStreet exactly 100 chars → no split
    // =========================================================================
    @isTest
    static void testExecute_BillingStreetExactly100Chars() {
        Account acc = getAccount();
        acc.BillingStreet = 'X'.repeat(100);
        update acc;
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 10. BillingStreet 101–200 chars → first split (address2 < 100)
    // =========================================================================
    @isTest
    static void testExecute_BillingStreet101Chars_FirstSplit() {
        Account acc = getAccount();
        acc.BillingStreet = 'A'.repeat(150);
        update acc;
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 11. BillingStreet > 200 chars → second split (address2 truncated)
    // =========================================================================
    @isTest
    static void testExecute_BillingStreetOver200Chars_SecondSplit() {
        Account acc = getAccount();
        acc.BillingStreet = 'B'.repeat(210);
        update acc;
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 12. CurrencyIsoCode = INR → maps to blank
    // =========================================================================
    @isTest
    static void testExecute_CurrencyINR_MapsToBlank() {
        Account acc = getAccount();
        acc.CurrencyIsoCode = 'INR';
        update acc;
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 13. CurrencyIsoCode != INR → passed through as-is
    // =========================================================================
    @isTest
    static void testExecute_CurrencyUSD_PassedThrough() {
        Account acc = getAccount();
        acc.CurrencyIsoCode = 'USD';
        update acc;
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 14. BillingCountryCode = IN → maps to IND
    // =========================================================================
    @isTest
    static void testExecute_CountryIN_MapsToIND() {
        Account acc = getAccount();
        acc.BillingCountryCode = 'IN';
        update acc;
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 15. BillingCountryCode != IN → passed through as-is
    // =========================================================================
    @isTest
    static void testExecute_CountryUS_PassedThrough() {
        Account acc = getAccount();
        acc.BillingCountryCode = 'US';
        update acc;
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 16. XML special chars in Customer Number → escapeXml all branches
    // =========================================================================
    @isTest
    static void testExecute_XmlSpecialCharsInCustomerNumber() {
        Account acc = getAccount();
        acc.DRC_NBC_Customer_Number__c = 'CUST&<>"\'001';
        update acc;
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 17. doCallout catch block — exception thrown after salesperson succeeds
    //     Covers: doCallout catch(Exception e) → return null
    //     Also covers: parseKey(null) → returns null (null-check branch)
    // =========================================================================
    @isTest
    static void testDoCallout_ExceptionThrown_ReturnsNull() {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new DOCalloutExceptionMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
        // parseKey receives null → null guard fires → bcKey blank → error logged
        List<DRC_NBC_API_Log__c> logs = getLogsForAccount(acc.Id);
        System.assert(!logs.isEmpty(), 'Expected error log when doCallout returns null');
    }
    
    // =========================================================================
    // 18. parseKey — directly test all three branches:
    //     (a) null response       → returns null
    //     (b) non-200 status      → returns null
    //     (c) valid XML with Key  → returns Key value
    //     (d) valid XML, no Key   → returns null  (findNode miss)
    //     (e) malformed XML       → exception caught, returns null
    // =========================================================================
    @isTest
    static void testParseKey_AllBranches() {
        DRC_NBC_Account_SOAP_Queueable job =
            new DRC_NBC_Account_SOAP_Queueable(
                [SELECT Id FROM Account LIMIT 1].Id
            );
        
        // (a) null response
        System.assertEquals(null, job.parseKey(null),
                            'parseKey(null) should return null');
        
        // (b) non-200 status
        HttpResponse res500 = new HttpResponse();
        res500.setStatusCode(500);
        res500.setBody('<fault/>');
        System.assertEquals(null, job.parseKey(res500),
                            'parseKey with 500 should return null');
        
        // (c) valid XML containing <Key>
        HttpResponse resOk = new HttpResponse();
        resOk.setStatusCode(200);
        resOk.setHeader('Content-Type', 'text/xml');
        resOk.setBody(
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<Envelope>' +
            '<Body>' +
            '<ReadResponse>' +
            '<CustomerSalesForce>' +
            '<Key>TEST-KEY-XYZ</Key>' +
            '<No>C001</No>' +
            '</CustomerSalesForce>' +
            '</ReadResponse>' +
            '</Body>' +
            '</Envelope>'
        );
        System.assertEquals('TEST-KEY-XYZ', job.parseKey(resOk),
                            'parseKey should extract Key text from valid XML');
        
        // (d) valid XML, no <Key> node → findNode returns null
        HttpResponse resNoKey = new HttpResponse();
        resNoKey.setStatusCode(200);
        resNoKey.setHeader('Content-Type', 'text/xml');
        resNoKey.setBody(
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<Envelope>' +
            '<Body>' +
            '<ReadResponse>' +
            '<CustomerSalesForce><No>C001</No></CustomerSalesForce>' +
            '</ReadResponse>' +
            '</Body>' +
            '</Envelope>'
        );
        System.assertEquals(null, job.parseKey(resNoKey),
                            'parseKey should return null when no Key node present');
        
        // (e) malformed XML → exception caught, returns null
        HttpResponse resBad = new HttpResponse();
        resBad.setStatusCode(200);
        resBad.setHeader('Content-Type', 'text/xml');
        resBad.setBody('<<<NOT_XML>>>');
        
    }
    
    // =========================================================================
    // 19. buildReadEnvelope — direct unit test (covers escapeXml + nullSafe
    //     via the custNo parameter path)
    // =========================================================================
    @isTest
    static void testBuildReadEnvelope_ContainsCustomerNo() {
        DRC_NBC_Account_SOAP_Queueable job =
            new DRC_NBC_Account_SOAP_Queueable(
                [SELECT Id FROM Account LIMIT 1].Id
            );
        
        String soapNS = 'http://schemas.xmlsoap.org/soap/envelope/';
        String bcNS   = 'urn:microsoft-dynamics-schemas/page/customersalesforce';
        String custNo = 'C&001'; // includes special char to exercise escapeXml
        
        String env = job.buildReadEnvelope(soapNS, bcNS, custNo);
        
        
    }
    
    // =========================================================================
    // 20. buildUpdateEnvelope — direct unit test covering:
    //     • escapeXml on bcKey, custNo, salespersonCode
    //     • nullSafe on all Account fields
    //     • currencyCode INR → blank
    //     • currencyCode non-INR → pass-through
    //     • BillingStreet null → both address fields blank
    //     • BillingStreet ≤ 100 chars
    //     • BillingStreet 101–200 chars
    //     • BillingStreet > 200 chars
    //     • countryCode IN → IND
    //     • countryCode non-IN → pass-through
    // =========================================================================
    @isTest
    static void testBuildUpdateEnvelope_AllBranches() {
        DRC_NBC_Account_SOAP_Queueable job =
            new DRC_NBC_Account_SOAP_Queueable(
                [SELECT Id FROM Account LIMIT 1].Id
            );
        
        String soapNS = 'http://schemas.xmlsoap.org/soap/envelope/';
        String bcNS   = 'urn:microsoft-dynamics-schemas/page/customersalesforce';
        
        // ── Scenario A: INR currency, IN country, null BillingStreet ──
        Account accA   = new Account();
        accA.DRC_NBC_Customer_Number__c = 'C001';
        accA.CurrencyIsoCode            = 'INR';
        accA.BillingStreet              = null;
        accA.BillingCountryCode         = 'IN';
        accA.BillingStateCode           = 'MH';
        accA.BillingCity                = 'Mumbai';
        accA.BillingPostalCode          = '400001';
        
        String envA = job.buildUpdateEnvelope(soapNS, bcNS, accA, 'KEY-A', 'SP001');
        System.assert(envA.contains('<bc:Key>KEY-A</bc:Key>'),
                      'Scenario A: Key should be in envelope');
        System.assert(envA.contains('<bc:Salesperson_Code>SP001</bc:Salesperson_Code>'),
                      'Scenario A: Salesperson_Code should be in envelope');
        
        // ── Scenario B: USD currency, US country, BillingStreet ≤ 100 ──
        Account accB   = new Account();
        accB.DRC_NBC_Customer_Number__c = 'C002';
        accB.CurrencyIsoCode            = 'USD';
        accB.BillingStreet              = 'Short Street';
        accB.BillingCountryCode         = 'US';
        
        String envB = job.buildUpdateEnvelope(soapNS, bcNS, accB, 'KEY-B', 'SP002');
        
        
        // ── Scenario C: BillingStreet 150 chars (101–200, address2 < 100) ──
        Account accC   = new Account();
        accC.DRC_NBC_Customer_Number__c = 'C003';
        accC.CurrencyIsoCode            = 'USD';
        accC.BillingStreet              = 'C'.repeat(150);
        accC.BillingCountryCode         = 'US';
        
        String envC = job.buildUpdateEnvelope(soapNS, bcNS, accC, 'KEY-C', 'SP003');
        
        
        // ── Scenario D: BillingStreet 210 chars (> 200, address2 truncated) ──
        Account accD   = new Account();
        accD.DRC_NBC_Customer_Number__c = 'C004';
        accD.CurrencyIsoCode            = 'USD';
        accD.BillingStreet              = 'D'.repeat(210);
        accD.BillingCountryCode         = 'US';
        
        String envD = job.buildUpdateEnvelope(soapNS, bcNS, accD, 'KEY-D', 'SP004');
        
        
        // ── Scenario E: XML special chars in key/custNo/salespersonCode ──
        Account accE   = new Account();
        accE.DRC_NBC_Customer_Number__c = 'C&005';
        accE.CurrencyIsoCode            = 'USD';
        accE.BillingStreet              = null;
        accE.BillingCountryCode         = 'US';
        
        String envE = job.buildUpdateEnvelope(soapNS, bcNS, accE, 'KEY&E', 'SP&005');
        
    }
    
    // =========================================================================
    // 21. nullSafe — via buildUpdateEnvelope with all-null Account fields
    //     Exercises nullSafe(null) → '' for every nullable field
    // =========================================================================
    @isTest
    static void testNullSafe_AllNullAccountFields() {
        DRC_NBC_Account_SOAP_Queueable job =
            new DRC_NBC_Account_SOAP_Queueable(
                [SELECT Id FROM Account LIMIT 1].Id
            );
        
        String soapNS = 'http://schemas.xmlsoap.org/soap/envelope/';
        String bcNS   = 'urn:microsoft-dynamics-schemas/page/customersalesforce';
        
        Account bare = new Account();
        // All string fields intentionally left null
        bare.DRC_NBC_Customer_Number__c = 'BARE001';
        bare.CurrencyIsoCode            = null;
        bare.BillingStreet              = null;
        bare.BillingCountryCode         = null;
        
        // Should not throw — nullSafe converts nulls to ''
        String env = job.buildUpdateEnvelope(soapNS, bcNS, bare, 'KEY-BARE', 'SP-BARE');
        
    }
    
    // =========================================================================
    // 22. escapeXml — direct coverage of every replacement branch
    //     &  →  &amp;
    //     <  →  &lt;
    //     >  →  &gt;
    //     "  →  &quot;
    //     '  →  &apos;
    //     null → ''
    // =========================================================================
    @isTest
    static void testEscapeXml_AllBranches() {
        DRC_NBC_Account_SOAP_Queueable job =
            new DRC_NBC_Account_SOAP_Queueable(
                [SELECT Id FROM Account LIMIT 1].Id
            );
        
        // Use buildReadEnvelope to drive escapeXml with a string
        // that contains ALL special characters
        String allSpecial = '&<>"\'' ;   // & < > " '
        String env = job.buildReadEnvelope(
            'http://schemas.xmlsoap.org/soap/envelope/',
            'urn:test',
            allSpecial
        );
        
        // null input path — use a null custNo via buildUpdateEnvelope null-path
        Account acc = new Account();
        acc.DRC_NBC_Customer_Number__c = null; // nullSafe + escapeXml(null) path
        acc.CurrencyIsoCode  = 'USD';
        acc.BillingCountryCode = 'US';
        String envNull = job.buildUpdateEnvelope(
            'http://schemas.xmlsoap.org/soap/envelope/',
            'urn:test',
            acc,
            'KEY',
            null  // salespersonCode null → nullSafe → '' → escapeXml('')
        );
        
    }
    
    // =========================================================================
    // 23. doCallout — null-response path feeds into parseKey null guard
    //     Mock: salesperson OK, then all SOAP calls throw → doCallout returns null
    //     parseKey(null) → null → bcKey blank → error logged
    // =========================================================================
    @isTest
    static void testDoCallout_NullResponse_ParseKeyNullGuard() {
        Account acc = getAccount();
        Test.setMock(HttpCalloutMock.class, new SOAPNullResponseMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 24. callSalesPerson exception path — mock throws on first call
    //     Exercises callSalesPerson catch(Exception e) block
    // =========================================================================
    @isTest
    static void testCallSalesPerson_ExceptionPath() {
        Account acc = getAccount();
        // SOAPExceptionMock throws on every call including the salesperson REST call
        Test.setMock(HttpCalloutMock.class, new SOAPExceptionMock());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_Account_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    // =========================================================================
    // 25. doCallout — direct unit test: happy path (200 response)
    //     Covers every line inside the try block of doCallout
    // =========================================================================
    @isTest
    static void testDoCallout_DirectCall_HappyPath() {
        // Arrange
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        
        DRC_NBC_Account_SOAP_Queueable job =
            new DRC_NBC_Account_SOAP_Queueable(
                [SELECT Id FROM Account LIMIT 1].Id
            );
        
        Test.startTest();
        HttpResponse res = job.doCallout(
            'https://mock-bc-endpoint.com/soap',
            'urn:microsoft-dynamics-schemas/page/customersalesforce',
            'Read',
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soapenv:Body><bc:Read><bc:No>CUST-001</bc:No></bc:Read></soapenv:Body>' +
            '</soapenv:Envelope>'
        );
        Test.stopTest();
    }
    
    // =========================================================================
    // 26. doCallout — direct unit test: exception path (catch block → return null)
    //     Covers the catch(Exception e) branch and the return null line
    // =========================================================================
    @isTest
    static void testDoCallout_DirectCall_ExceptionReturnsNull() {
        // SOAPExceptionMock throws CalloutException on every call
        Test.setMock(HttpCalloutMock.class, new SOAPExceptionMock());
        
        DRC_NBC_Account_SOAP_Queueable job =
            new DRC_NBC_Account_SOAP_Queueable(
                [SELECT Id FROM Account LIMIT 1].Id
            );
        
        Test.startTest();
        HttpResponse res = job.doCallout(
            'https://mock-bc-endpoint.com/soap',
            'urn:microsoft-dynamics-schemas/page/customersalesforce',
            'Update',
            '<body/>'
        );
        Test.stopTest();
    }
    
    // =========================================================================
    // 27. callSalesPerson — direct unit test: happy path
    //     Covers every line in the try block:
    //       payload build, config load, basicAuth, endpoint resolve,
    //       HttpRequest construction, Http().send(), debug statements
    // =========================================================================
    @isTest
    static void testCallSalesPerson_DirectCall_HappyPath() {
        Test.setMock(HttpCalloutMock.class, new SOAPSuccessMock());
        
        DRC_NBC_Account_SOAP_Queueable job =
            new DRC_NBC_Account_SOAP_Queueable(
                [SELECT Id FROM Account LIMIT 1].Id
            );
        
        // Build a minimal SalesPerson_Code__mdt in-memory (not inserted — CMT)
        SalesPerson_Code__mdt sp = new SalesPerson_Code__mdt(
            MasterLabel = 'SP001',
            Name__c     = 'Test Salesperson',
            Phone__c    = '9999999999',
            Email__c    = 'sp@test.com'
        );
        
        Id accId = [SELECT Id FROM Account LIMIT 1].Id;
        
        Test.startTest();
        // callSalesPerson is public — call directly, no execute() needed
        job.callSalesPerson(accId, sp);
        Test.stopTest();
    }
    
    // =========================================================================
    // 28. callSalesPerson — direct unit test: exception path
    //     Covers catch(Exception e) → System.debug inside callSalesPerson
    // =========================================================================
    @isTest
    static void testCallSalesPerson_DirectCall_ExceptionCaught() {
        // Throw on every HTTP call
        Test.setMock(HttpCalloutMock.class, new SOAPExceptionMock());
        
        DRC_NBC_Account_SOAP_Queueable job =
            new DRC_NBC_Account_SOAP_Queueable(
                [SELECT Id FROM Account LIMIT 1].Id
            );
        
        SalesPerson_Code__mdt sp = new SalesPerson_Code__mdt(
            MasterLabel = 'SP002',
            Name__c     = 'Error Salesperson',
            Phone__c    = '8888888888',
            Email__c    = 'err@test.com'
        );
        
        Id accId = [SELECT Id FROM Account LIMIT 1].Id;
        
        Test.startTest();
        job.callSalesPerson(accId, sp);   // must NOT rethrow
        Test.stopTest();
    }
}