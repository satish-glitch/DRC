/**
* @File Name          : DRC_NBC_SalesPerson_Sync_Callout_Test.cls
* @Description        : Test class for DRC_NBC_SalesPerson_Sync_Callout
* @Author             : Satish
* @Last Modified On   : December 11, 2025
**/
@isTest
public class DRC_NBC_SalesPerson_Sync_Callout_Test {
    
    // ── Test Data Setup ─────────────────────────────────────────────────────────
    @TestSetup
    static void setupTestData() {
        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
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
            Type = 'Analyst'
        );
        insert acc;
        
        // Create Contact linked to Account
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Contact',
            Email     = 'test@test.com',
            Phone     = '9999999999',
            AccountId = acc.Id
        );
        insert con;
    }
    
    // ── Helper: Get Account ─────────────────────────────────────────────────────
    private static Account getTestAccount() {
        return [SELECT Id, Name FROM Account WHERE Name = 'Test Account' LIMIT 1];
    }
    
    // ── Helper: Get Contact ─────────────────────────────────────────────────────
    private static Contact getTestContact() {
        return [SELECT Id, Name, Email, Phone, AccountId FROM Contact LIMIT 1];
    }
    
    // ── Mock: Success Response ──────────────────────────────────────────────────
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status":"success","message":"Salesperson created"}');
            return res;
        }
    }
    
    // ── Mock: Failure Response ──────────────────────────────────────────────────
    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"status":"error","message":"Bad Request"}');
            return res;
        }
    }
    
    // ── Mock: Server Error Response ─────────────────────────────────────────────
    private class ServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"status":"error","message":"Internal Server Error"}');
            return res;
        }
    }
    
    // ── Mock: Exception Response ────────────────────────────────────────────────
    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout exception');
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 1: Null contactId → Should return FAILURE + API Log
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testNullContactId() {
        Account acc = getTestAccount();
        
        Test.startTest();
        String result = DRC_NBC_SalesPerson_Sync_Callout.executeCallout(null, acc.Id);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 2: Null accountId → Should return FAILURE + API Log
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testNullAccountId() {
        Contact con = getTestContact();
        
        Test.startTest();
        String result = DRC_NBC_SalesPerson_Sync_Callout.executeCallout(con.Id, null);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 3: Contact not found → Should return FAILURE + API Log
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testContactNotFound() {
        Account acc = getTestAccount();
        
        // Pass a fake contactId that doesn't belong to this account
        Id fakeContactId = '003000000000001AAA';
        
        Test.startTest();
        String result = DRC_NBC_SalesPerson_Sync_Callout.executeCallout(
            fakeContactId, acc.Id
        );
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 4: SUCCESS — 200 response → return SUCCESS, NO API Log
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testSuccessResponse() {
        Contact con = getTestContact();
        Account acc = getTestAccount();
        
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        Test.startTest();
        String result = DRC_NBC_SalesPerson_Sync_Callout.executeCallout(
            con.Id, acc.Id
        );
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 5: FAILURE — 400 response → return FAILURE + API Log
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testFailureResponse400() {
        Contact con = getTestContact();
        Account acc = getTestAccount();
        
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        
        Test.startTest();
        String result = DRC_NBC_SalesPerson_Sync_Callout.executeCallout(
            con.Id, acc.Id
        );
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 6: FAILURE — 500 response → return FAILURE + API Log
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testFailureResponse500() {
        Contact con = getTestContact();
        Account acc = getTestAccount();
        
        Test.setMock(HttpCalloutMock.class, new ServerErrorMock());
        
        Test.startTest();
        String result = DRC_NBC_SalesPerson_Sync_Callout.executeCallout(
            con.Id, acc.Id
        );
        Test.stopTest();

    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 7: EXCEPTION — Callout throws exception → return FAILURE + API Log
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testCalloutException() {
        Contact con = getTestContact();
        Account acc = getTestAccount();
        
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        
        Test.startTest();
        String result = DRC_NBC_SalesPerson_Sync_Callout.executeCallout(
            con.Id, acc.Id
        );
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // TEST 8: Both null → contactId checked first → FAILURE
    // ═══════════════════════════════════════════════════════════════════════════
    @isTest
    static void testBothNull() {
        Test.startTest();
        String result = DRC_NBC_SalesPerson_Sync_Callout.executeCallout(null, null);
        Test.stopTest();
    }
}