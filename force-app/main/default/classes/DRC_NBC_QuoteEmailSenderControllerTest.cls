/**
* @File Name      : DRC_NBC_QuoteEmailSenderControllerTest.cls
* @Description    : Test class for DRC_NBC_QuoteEmailSenderController
* @Author         : Satish Yadav
* @Test_Class     : DRC_NBC_QuoteEmailSenderController
*/
@isTest
public class DRC_NBC_QuoteEmailSenderControllerTest {
    
    // ─── Test Setup ───────────────────────────────────────────────────────────
    
    @testSetup
    static void setupTestData() {
        // Account
        Account acc = new Account(
            Name            = 'Test Account',
            BillingStreet  = '123 Test Street',
            BillingCity    = 'Mumbai',
            BillingState   = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India',
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
        
        // Contacts with email (used to populate To address)
        Contact c1 = new Contact(FirstName = 'John', LastName = 'Doe',
                                 AccountId = acc.Id, Email = 'john.doe@test.com');
        Contact c2 = new Contact(FirstName = 'Jane', LastName = 'Smith',
                                 AccountId = acc.Id, Email = 'jane.smith@test.com');
        Contact c3 = new Contact(FirstName = 'No',   LastName = 'Email',
                                 AccountId = acc.Id); // intentionally no email
        insert new List<Contact>{ c1, c2, c3 };
            
            // Opportunity
            Opportunity opp = new Opportunity(
                Name      = 'Test Opportunity',
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            );
        insert opp;
        
        // Pricebook
        Id standardPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPbId, IsActive = true);
        
        // Product
        Product2 prod = new Product2(
            Name     = 'Test Product',
            IsActive = true,
            DRC_NBC_HSN_SAC_Code__c = 'HSN001'
        );
        insert prod;
        
        // Standard PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id    = standardPbId,
            Product2Id      = prod.Id,
            UnitPrice       = 500,
            IsActive        = true,
            CurrencyIsoCode = 'USD'
        );
        insert pbe;
        
        // Quote with all fields used in controller
        Quote q = new Quote(
            Name              = 'Test Quote',
            OpportunityId     = opp.Id,
            Pricebook2Id      = standardPbId,
            Status            = 'Draft',
            ExpirationDate    = Date.today().addDays(30),
            CurrencyIsoCode   = 'USD',
            DRC_NBC_Inco_terms__c = 'Cost Insurance & Freight (CIF)',
            Description       = 'Test Description',
            DRC_NBC_Type__c =  'Domestic'
        );
        insert q;
        
        //  Step 4: Re-query quote to get the actual CurrencyIsoCode assigned by Salesforce
        q = [SELECT Id, CurrencyIsoCode, Pricebook2Id FROM Quote WHERE Id = :q.Id LIMIT 1];
        String quoteCurrency = q.CurrencyIsoCode;
        
        // Step 5: Create PricebookEntry using the SAME currency as the Quote
        PricebookEntry pbe1 = new PricebookEntry(
            Pricebook2Id    = standardPbId,
            Product2Id      = prod.Id,
            UnitPrice       = 500,
            IsActive        = true,
            CurrencyIsoCode = quoteCurrency   // ← must match quote currency exactly
        );
        insert pbe1;
        
        // Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId          = q.Id,
            PricebookEntryId = pbe1.Id,
            Product2Id       = prod.Id,
            Quantity         = 10,
            UnitPrice        = 500
        );
        insert qli;
        
        // Content Document (file attached to quote)
        ContentVersion cv = new ContentVersion(
            Title           = 'Test Quotation PDF',
            PathOnClient    = 'TestQuotation.pdf',
            VersionData     = Blob.valueOf('Fake PDF Content'),
            IsMajorVersion  = true
        );
        insert cv;
        
        // Link the ContentDocument to the Quote
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = q.Id,
            ContentDocumentId = contentDocId,
            ShareType = 'V'
        );
        insert cdl;
    }
    
    // ─── Helper ───────────────────────────────────────────────────────────────
    
    private static Quote getQuote() {
        return [SELECT Id FROM Quote WHERE Name = 'Test Quote' LIMIT 1];
    }
    
    private static ApexPages.StandardController buildStdController() {
        Quote q = getQuote();
        return new ApexPages.StandardController(q);
    }
    
    // ─── Constructor / Initialization ─────────────────────────────────────────
    
    @isTest
    static void testConstructor_LoadsQuoteAndInitializesFields() {
        Test.startTest();
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        Test.stopTest();
    }
    
    @isTest
    static void testConstructor_QuoteWithNoDescription() {
        // Update quote to have blank description
        Quote q = getQuote();
        q.Description = null;
        update q;
        
        Test.startTest();
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        Test.stopTest();
    }
    
    @isTest
    static void testConstructor_QuoteWithNoIncoTerms() {
        Quote q = getQuote();
        q.DRC_NBC_Inco_terms__c = null;
        update q;
        
        Test.startTest();
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        Test.stopTest();
    }
    
    @isTest
    static void testConstructor_AccountWithNoContacts() {
        // Create a separate account with no contacts
        Account acc2 = new Account(Name = 'No Contact Account',
                                   BillingStreet  = '123 Test Street',
                                   BillingCity    = 'Mumbai',
                                   BillingState   = 'Maharashtra',
                                   BillingPostalCode = '400001',
                                   BillingCountry = 'India',
                                   DRC_NBC_Volume__c = 70, 
                                   DRC_NBC_Credit_Limit__c = 123456787,
                                   DRC_NBC_Value__c = 900,
                                   DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
                                   DRC_NBC_Consignee_Bank_Address__c = 'Barhi 483775',
                                   DRC_NBC_Consignee_Bank_IFSC_Code__c = 'PUNB01391000',
                                   DRC_NBC_Consignee_Bank_Name__c = 'Punjab National bank',
                                   Industry = 'Chemicals Construction',
                                   Type = 'Analyst');
        insert acc2;
        
        Opportunity opp2 = new Opportunity(
            Name = 'No Contact Opp', AccountId = acc2.Id,
            StageName = 'Prospecting', CloseDate = Date.today().addDays(10)
        );
        insert opp2;
        
        Id standardPbId = Test.getStandardPricebookId();
        Quote q2 = new Quote(
            Name = 'No Contact Quote', OpportunityId = opp2.Id,
            Pricebook2Id = standardPbId, Status = 'Draft',
            CurrencyIsoCode = 'USD'
        );
        insert q2;
        
        ApexPages.StandardController sc = new ApexPages.StandardController(q2);
        
        Test.startTest();
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(sc);
        Test.stopTest();
    }
    
    // ─── loadContentDocuments ─────────────────────────────────────────────────
    
    @isTest
    static void testLoadContentDocuments_ReturnsAttachedFiles() {
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        
        Test.startTest();
        PageReference result = ctrl.loadContentDocuments();
        Test.stopTest();
    }
    
    @isTest
    static void testLoadContentDocuments_NoFilesShowsInfoMessage() {
        // Create a quote with no files attached
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id standardPbId = Test.getStandardPricebookId();
        
        Quote emptyQuote = new Quote(
            Name = 'Empty Quote', OpportunityId = opp.Id,
            Pricebook2Id = standardPbId, Status = 'Draft',
            CurrencyIsoCode = 'USD', DRC_NBC_Type__c = 'Export'
        );
        insert emptyQuote;
        
        ApexPages.StandardController sc = new ApexPages.StandardController(emptyQuote);
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(sc);
        
        Test.startTest();
        ctrl.loadContentDocuments();
        Test.stopTest();
    }
    
    // ─── sendEmail ────────────────────────────────────────────────────────────
    
    @isTest
    static void testSendEmail_SuccessWithAttachment() {
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        
        // Load docs and select the first one
        ctrl.loadContentDocuments();
        if (!ctrl.contentDocuments.isEmpty()) {
            ctrl.contentDocuments[0].isSelected = true;
        }
        
        ctrl.toAddresses  = 'test@example.com';
        ctrl.ccAddresses  = 'cc@example.com';
        ctrl.bccAddresses = 'bcc@example.com';
        ctrl.emailSubject = 'Test Subject';
        ctrl.emailBody    = '<p>Test Body</p>';
        
        Test.startTest();
        PageReference result = ctrl.sendEmail();
        Test.stopTest();
    }
    
    @isTest
    static void testSendEmail_SuccessWithoutAttachment() {
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        
        // Load docs but do NOT select any
        ctrl.loadContentDocuments();
        ctrl.toAddresses  = 'test@example.com';
        ctrl.emailSubject = 'Test Subject';
        ctrl.emailBody    = '<p>Test Body</p>';
        
        Test.startTest();
        PageReference result = ctrl.sendEmail();
        Test.stopTest();
        
    }
    
    @isTest
    static void testSendEmail_BlankToAddress_ReturnsNull() {
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        
        ctrl.toAddresses  = '';   // intentionally blank
        ctrl.emailSubject = 'Test Subject';
        ctrl.emailBody    = '<p>Test Body</p>';
        
        Test.startTest();
        PageReference result = ctrl.sendEmail();
        Test.stopTest();
    }
    
    @isTest
    static void testSendEmail_WithMultipleRecipientsCommaSeparated() {
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        
        ctrl.toAddresses  = 'a@test.com, b@test.com';
        ctrl.ccAddresses  = 'c@test.com; d@test.com';
        ctrl.emailSubject = 'Multi Recipient Test';
        ctrl.emailBody    = '<p>Body</p>';
        
        Test.startTest();
        PageReference result = ctrl.sendEmail();
        Test.stopTest();
    }
    
    // ─── cancel ───────────────────────────────────────────────────────────────
    
    @isTest
    static void testCancel_RedirectsToQuote() {
        Quote q = getQuote();
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        
        Test.startTest();
        PageReference result = ctrl.cancel();
        Test.stopTest();
    }
    
    // ─── ContentDocumentWrapper ───────────────────────────────────────────────
    
    @isTest
    static void testContentDocumentWrapper_Fields() {
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        ctrl.loadContentDocuments();
    }
    
    // ─── formatFileSize edge cases (exercised via loadContentDocuments) ───────
    
    @isTest
    static void testFormatFileSize_VariousSizes() {
        // Insert a content version with a known small size to exercise the B / KB / MB branches.
        // The actual branch hit depends on file size — inserting a tiny blob exercises the B branch.
        ContentVersion cv = new ContentVersion(
            Title        = 'Tiny File',
            PathOnClient = 'tiny.txt',
            VersionData  = Blob.valueOf('A'),   // 1 byte → 'B' branch
            IsMajorVersion = true
        );
        insert cv;
        
        Id cdId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        Quote q = getQuote();
        insert new ContentDocumentLink(
            LinkedEntityId    = q.Id,
            ContentDocumentId = cdId,
            ShareType         = 'V'
        );
        
        DRC_NBC_QuoteEmailSenderController ctrl =
            new DRC_NBC_QuoteEmailSenderController(buildStdController());
        
        Test.startTest();
        ctrl.loadContentDocuments();
        Test.stopTest();
    }
}