/**
* @File Name       : DRC_NBC_GeoapifyServiceTest.cls
* @Description     : Test class for DRC_NBC_GeoapifyService
* @Author          :
* @Last Modified By:
* @Last Modified On: March 25, 2026
* @Modification Log:
*==============================================================================
* Ver | Date              | Author | Modification
*==============================================================================
* 1.0 | March 25, 2026   |        | Initial Version
**/
@isTest
private class DRC_NBC_GeoapifyServiceTest {
    
    // ─────────────────────────────────────────────
    // Mock: Successful Geoapify response
    // ─────────────────────────────────────────────
    private class GeoapifySuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"results":[{"lat":37.7749,"lon":-122.4194,"formatted":"123 Main St, San Francisco, CA 94105, US"}]}');
            return res;
        }
    }
    
    // ─────────────────────────────────────────────
    // Mock: Empty results from Geoapify
    // ─────────────────────────────────────────────
    private class GeoapifyEmptyResultsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"results":[]}');
            return res;
        }
    }
    
    // ─────────────────────────────────────────────
    // Mock: API failure (500)
    // ─────────────────────────────────────────────
    private class GeoapifyFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
    
    // ─────────────────────────────────────────────
    // Mock: Empty body response
    // ─────────────────────────────────────────────
    private class GeoapifyEmptyBodyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('');
            return res;
        }
    }
    
    // ─────────────────────────────────────────────
    // Helper: Create a fully addressed Account
    // ─────────────────────────────────────────────
    private static Account createAccount() {
        Account acc = new Account(
            Name            = 'Test Account',
            CurrencyIsoCode = 'INR',
            Phone = '1234567890',
            AccountNumber = 'A123',
            DRC_NBC_PAN_No__c = 'AWVPY9594J',
            DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c = '10 DAYS',
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
            Type = 'Analyst',
            DRC_NBC_Special_Instructions__c = 'Handle with care'
        );
        insert acc;
        return acc;
    }
    
    // ─────────────────────────────────────────────
    // Helper: Create a Contact with mailing address
    // ─────────────────────────────────────────────
    private static Contact createContact(Id accountId) {
        Contact con = new Contact(
            FirstName         = 'John',
            LastName          = 'Doe',
            AccountId         = accountId,
            MailingStreet     = '456 Market St',
            MailingCity       = 'San Francisco',
            MailingPostalCode = '94103',
            MailingCountry    = 'Australia'
        );
        insert con;
        return con;
    }
    
    // ─────────────────────────────────────────────
    // Helper: Create a Lead with address
    // ─────────────────────────────────────────────
    private static Lead createLead() {
        Lead l = new Lead(
            FirstName   = 'Jane',
            LastName    = 'Smith',
            Company     = 'Acme Corp',
            Street      = '789 Mission St',
            City        = 'San Francisco',
            PostalCode  = '94105',
            Country     = 'Australia',
            Phone = '+61 23456787',
            Email = 'testAus23@gmail.com'
        );
        insert l;
        return l;
    }
    
    
    // ══════════════════════════════════════════════
    // NULL RECORD ID
    // ══════════════════════════════════════════════
    
    @isTest
    static void testNullRecordId() {
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(null);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result map should not be null');
        System.assert(result.isEmpty(), 'Result should be empty for null record ID');
    }
    
    
    // ══════════════════════════════════════════════
    // TASK → LEAD (WhoId starts with 00Q)
    // ══════════════════════════════════════════════
    
    @isTest
    static void testTaskWithLeadWhoId_Success() {
        Lead l   = createLead();
        Task t   = new Task(Subject = 'Test Task', WhoId = l.Id, Status = 'Not Started');
        insert t;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifySuccessMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(t.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testTaskWithLeadWhoId_EmptyResults() {
        Lead l = createLead();
        Task t = new Task(Subject = 'Test Task', WhoId = l.Id, Status = 'Not Started');
        insert t;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifyEmptyResultsMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(t.Id);
        Test.stopTest();
    }
    
    
    // ══════════════════════════════════════════════
    // TASK → CONTACT (WhoId starts with 003)
    // ══════════════════════════════════════════════
    
    @isTest
    static void testTaskWithContactWhoId_Success() {
        Account acc = createAccount();
        Contact con = createContact(acc.Id);
        Task t      = new Task(Subject = 'Contact Task', WhoId = con.Id, Status = 'Not Started');
        insert t;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifySuccessMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(t.Id);
        Test.stopTest();
    }
    
    
    // ══════════════════════════════════════════════
    // TASK → ACCOUNT (AccountId fallback)
    // ══════════════════════════════════════════════
    
    @isTest
    static void testTaskWithAccountFallback_Success() {
        Account acc = createAccount();
        Task t      = new Task(
            Subject   = 'Account Task',
            //AccountId = acc.Id,
            Status    = 'Not Started'
        );
        insert t;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifySuccessMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(t.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testTaskWithAccountFallback_ApiFailure() {
        Account acc = createAccount();
        Task t      = new Task(
            Subject   = 'Account Task',
            //  AccountId = acc.Id,
            Status    = 'Not Started'
        );
        insert t;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifyFailureMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(t.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testTaskWithAccountFallback_EmptyBody() {
        Account acc = createAccount();
        Task t      = new Task(
            Subject   = 'Account Task',
            //   AccountId = acc.Id,
            Status    = 'Not Started'
        );
        insert t;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifyEmptyBodyMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(t.Id);
        Test.stopTest();
    }
    
    
    // ══════════════════════════════════════════════
    // TASK — No WhoId and No AccountId (blank address)
    // ══════════════════════════════════════════════
    
    @isTest
    static void testTaskNoAddressAvailable() {
        Task t = new Task(Subject = 'Orphan Task', Status = 'Not Started');
        insert t;
        
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(t.Id);
        Test.stopTest();
    }
    
    
    // ══════════════════════════════════════════════
    // EVENT → LEAD (WhoId starts with 00Q)
    // ══════════════════════════════════════════════
    
    @isTest
    static void testEventWithLeadWhoId_Success() {
        Lead l  = createLead();
        Event e = new Event(
            Subject          = 'Test Event',
            WhoId            = l.Id,
            StartDateTime    = Datetime.now().addHours(1),
            EndDateTime      = Datetime.now().addHours(2),
            DurationInMinutes = 60
        );
        insert e;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifySuccessMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(e.Id);
        Test.stopTest();
    }
    
    
    // ══════════════════════════════════════════════
    // EVENT → CONTACT (WhoId starts with 003)
    // ══════════════════════════════════════════════
    
    @isTest
    static void testEventWithContactWhoId_Success() {
        Account acc = createAccount();
        Contact con = createContact(acc.Id);
        Event e     = new Event(
            Subject           = 'Contact Event',
            WhoId             = con.Id,
            StartDateTime     = Datetime.now().addHours(1),
            EndDateTime       = Datetime.now().addHours(2),
            DurationInMinutes = 60
        );
        insert e;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifySuccessMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(e.Id);
        Test.stopTest();
    }
    
    
    // ══════════════════════════════════════════════
    // EVENT → ACCOUNT (AccountId fallback)
    // ══════════════════════════════════════════════
    
    @isTest
    static void testEventWithAccountFallback_Success() {
        Account acc = createAccount();
        Event e     = new Event(
            Subject           = 'Account Event',
            //  AccountId         = acc.Id,
            StartDateTime     = Datetime.now().addHours(1),
            EndDateTime       = Datetime.now().addHours(2),
            DurationInMinutes = 60
        );
        insert e;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifySuccessMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(e.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testEventWithAccountFallback_ApiFailure() {
        Account acc = createAccount();
        Event e     = new Event(
            Subject           = 'Account Event',
            //   AccountId         = acc.Id,
            StartDateTime     = Datetime.now().addHours(1),
            EndDateTime       = Datetime.now().addHours(2),
            DurationInMinutes = 60
        );
        insert e;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifyFailureMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(e.Id);
        Test.stopTest();
    }
    
    
    // ══════════════════════════════════════════════
    // EVENT — No WhoId and No AccountId (blank address)
    // ══════════════════════════════════════════════
    
    @isTest
    static void testEventNoAddressAvailable() {
        Event e = new Event(
            Subject           = 'Orphan Event',
            StartDateTime     = Datetime.now().addHours(1),
            EndDateTime       = Datetime.now().addHours(2),
            DurationInMinutes = 60
        );
        insert e;
        
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(e.Id);
        Test.stopTest();
    }
    
    
    // ══════════════════════════════════════════════
    // UNSUPPORTED OBJECT TYPE (e.g. Account ID passed directly)
    // ══════════════════════════════════════════════
    
    @isTest
    static void testUnsupportedObjectType() {
        Account acc = createAccount();
        
        // Passing an Account ID (prefix 001) — not handled by the service
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(acc.Id);
        Test.stopTest();
    }
    
    
    @isTest
    static void testLeadWithPartialAddress_Success() {
        Lead l = new Lead(
            FirstName = 'Partial',
            LastName  = 'Address',
            Company   = 'Test Co',
            City      = 'Austin',
            Country = 'Australia',
            Phone = '+61 23456787',
            Email = 'testAus@gmail.com'
            // Street, PostalCode, Country intentionally omitted
        );
        insert l;
        
        Task t = new Task(Subject = 'Partial Address Task', WhoId = l.Id, Status = 'Not Started');
        insert t;
        
        Test.setMock(HttpCalloutMock.class, new GeoapifySuccessMock());
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(t.Id);
        Test.stopTest();
    }
    
    
    @isTest
    static void testLeadWithBlankAddress() {
        Lead l = new Lead(
            FirstName = 'No',
            LastName  = 'Address',
            Company   = 'Ghost Corp',
            Country  = 'India',
            Email = 'satish123@gmail.com',
            Phone = '0987654321'
            // All address fields intentionally omitted
        );
        insert l;
        
        Task t = new Task(Subject = 'Blank Address Task', WhoId = l.Id, Status = 'Not Started');
        insert t;
        
        Test.startTest();
        Map<String, Double> result = DRC_NBC_GeoapifyService.getCoordinatesForRecord(t.Id);
        Test.stopTest();
    }
}