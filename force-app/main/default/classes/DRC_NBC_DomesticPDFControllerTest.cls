/**
* @File Name : DRC_NBC_DomesticQuotationPDFControllerTest.cls
* @Description : Test class for DRC_NBC_DomesticQuotationPDFController
*/
@isTest
private class DRC_NBC_DomesticPDFControllerTest {
    
    // ─── Test Data Setup ──────────────────────────────────────────────────────
    
    @TestSetup
    static void setupTestData() {
        // Account
        Account acc = new Account(
            Name = 'Test Account',
            AccountNumber = 'CUST001',
            NBC_DRC_Account_DRC_Code__c = 'DRC-CODE-001',
            CurrencyIsoCode = 'INR',
            Phone = '1234567890',
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
            Type = 'Analyst'
        );
        insert acc;
        
        // Contact
        Contact con = new Contact(
            FirstName  = 'Test',
            LastName   = 'Contact',
            AccountId  = acc.Id
        );
        insert con;
        
        // Opportunity (required to create Quote)
        Opportunity opp = new Opportunity(
            Name            = 'Test Opportunity',
            AccountId       = acc.Id,
            StageName       = 'Prospecting',
            CloseDate       = Date.today().addDays(30)
        );
        insert opp;
        
        // Product
        Product2 prod = new Product2(
            Name                        = 'Test Product',
            IsActive                    = true,
            QuantityUnitOfMeasure       = 'KG',
            DRC_NBC_HSN_SAC_Code__c     = 'HSN001',
            DRC_NBC_KIND_OF_PKG__c      = 'Box',
            Description                 = 'Test product description'
        );
        insert prod;
        
        // Pricebook entry
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 500,
            IsActive     = true
        );
        insert pbe;
        
        // Domestic Quote — no sequence number yet → triggers assignQuoteSequenceNumber Domestic path
        Quote domesticQuote = new Quote(
            Name                                    = 'Domestic Test Quote',
            OpportunityId                           = opp.Id,
            Pricebook2Id                            = stdPbId,
            ContactId                               = con.Id,
            Status                                  = 'Draft',
            ExpirationDate                          = Date.today().addDays(30),
            BillingStreet                           = '123 Test Street',
            BillingCity                             = 'Indore',
            BillingState                            = 'Madhya Pradesh',
            BillingCountry                          = 'India',
            BillingPostalCode                       = '452001',
            ShippingStreet                          = '456 Ship Street',
            ShippingCity                            = 'Mumbai',
            ShippingState                           = 'Maharashtra',
            ShippingPostalCode                      = '400001',
            ShippingCountry                         = 'India',
            CurrencyISOCode                         = 'INR',
            DRC_NBC_Type__c                         = 'Domestic',
            DRC_NBC_Payemnt_Term__c                 = '100',
            DRC_NBC_Inco_terms__c                   = 'Cost Insurance & Freight (CIF)',
            DRC_NBC_Other_Tax_Amount__c             = 50,
            DRC_NBC_TCS_Amount__c                   = 25,
            DRC_NBC_Special_Requirements__c         = 'Requirement one. Requirement two. Requirement three.',
            DRC_NBC_Import_Starting_Sequence__c     = null
        );
        insert domesticQuote;
        
        // Quote Line Item for Domestic Quote
        QuoteLineItem qliDomestic = new QuoteLineItem(
            QuoteId         = domesticQuote.Id,
            Product2Id      = prod.Id,
            PricebookEntryId= pbe.Id,
            Quantity        = 2,
            UnitPrice       = 500,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert qliDomestic;
        
        // Export Quote — no sequence number yet → triggers assignQuoteSequenceNumber Export path
        Quote exportQuote = new Quote(
            Name                                        = 'Export Test Quote',
            OpportunityId                               = opp.Id,
            Pricebook2Id                                = stdPbId,
            ContactId                                   = con.Id,
            Status                                      = 'Draft',
            ExpirationDate                              = Date.today().addDays(30),
            BillingStreet                               = '123 Test Street',
            BillingCity                                 = 'Indore',
            BillingState                                = 'Madhya Pradesh',
            BillingCountry                              = 'India',
            BillingPostalCode                           = '452001',
            ShippingStreet                              = '789 Export Street',
            ShippingCity                                = 'Chennai',
            ShippingState                               = 'Tamil Nadu',
            ShippingPostalCode                          = '600001',
            ShippingCountry                             = 'India',
            CurrencyISOCode                             = 'INR',
            DRC_NBC_Type__c                             = 'Export',
            DRC_NBC_Payemnt_Term__c                     = '100',
            DRC_NBC_Inco_terms__c                       = 'Cost Insurance & Freight (CIF)',
            DRC_NBC_Other_Tax_Amount__c                 = 30,
            DRC_NBC_TCS_Amount__c                       = 10,
            DRC_NBC_Special_Requirements__c             = 'Export requirement one. Export requirement two.',
            DRC_NBC_Invoice_Export_Sequence_Number__c   = null
        );
        insert exportQuote;
        
        // Quote Line Item for Export Quote
        QuoteLineItem qliExport = new QuoteLineItem(
            QuoteId         = exportQuote.Id,
            Product2Id      = prod.Id,
            PricebookEntryId= pbe.Id,
            Quantity        = 2,
            UnitPrice       = 500,
            DRC_NBC_Unit_Of_Measurement__c = 'KGS'
        );
        insert qliExport;
        
        // Domestic Quote — sequence already set → assignQuoteSequenceNumber returns null
        Quote domesticQuoteSeqSet = new Quote(
            Name                                    = 'Domestic Quote Seq Set',
            OpportunityId                           = opp.Id,
            Pricebook2Id                            = stdPbId,
            ContactId                               = con.Id,
            Status                                  = 'Draft',
            ExpirationDate                          = Date.today().addDays(30),
            BillingStreet                           = '123 Test Street',
            BillingCity                             = 'Indore',
            BillingState                            = 'Madhya Pradesh',
            BillingCountry                          = 'India',
            BillingPostalCode                       = '452001',
            ShippingStreet                          = '456 Ship Street',
            ShippingCity                            = 'Mumbai',
            ShippingState                           = 'Maharashtra',
            ShippingPostalCode                      = '400001',
            ShippingCountry                         = 'India',
            CurrencyISOCode                         = 'INR',
            DRC_NBC_Type__c                         = 'Domestic',
            DRC_NBC_Payemnt_Term__c                 = '100',
            DRC_NBC_Inco_terms__c                   = 'Cost Insurance & Freight (CIF)',
            DRC_NBC_Other_Tax_Amount__c             = 0,
            DRC_NBC_TCS_Amount__c                   = 0,
            DRC_NBC_Special_Requirements__c         = null,  // null → covers blank specialInstructions path
            DRC_NBC_Import_Starting_Sequence__c     = 999    // already set → assignQuoteSequenceNumber returns null
        );
        insert domesticQuoteSeqSet;
        
        // Export Quote — sequence already set → assignQuoteSequenceNumber returns null
        Quote exportQuoteSeqSet = new Quote(
            Name                                        = 'Export Quote Seq Set',
            OpportunityId                               = opp.Id,
            Pricebook2Id                                = stdPbId,
            ContactId                                   = con.Id,
            Status                                      = 'Draft',
            ExpirationDate                              = Date.today().addDays(30),
            BillingStreet                               = '123 Test Street',
            BillingCity                                 = 'Indore',
            BillingState                                = 'Madhya Pradesh',
            BillingCountry                              = 'India',
            BillingPostalCode                           = '452001',
            ShippingStreet                              = '789 Export Street',
            ShippingCity                                = 'Chennai',
            ShippingState                               = 'Tamil Nadu',
            ShippingPostalCode                          = '600001',
            ShippingCountry                             = 'India',
            CurrencyISOCode                             = 'INR',
            DRC_NBC_Type__c                             = 'Export',
            DRC_NBC_Payemnt_Term__c                     = '100',
            DRC_NBC_Inco_terms__c                       = 'Cost Insurance & Freight (CIF)',
            DRC_NBC_Other_Tax_Amount__c                 = 0,
            DRC_NBC_TCS_Amount__c                       = 0,
            DRC_NBC_Special_Requirements__c             = null,   // null → covers blank path
            DRC_NBC_Invoice_Export_Sequence_Number__c   = 999     // already set → returns null
        );
        insert exportQuoteSeqSet;
    }
    
    // ── Helpers ───────────────────────────────────────────────────────────────
    
    private static Quote getDomesticQuote() {
        return [SELECT Id FROM Quote WHERE Name = 'Domestic Test Quote' LIMIT 1];
    }
    
    private static Quote getExportQuote() {
        return [SELECT Id FROM Quote WHERE Name = 'Export Test Quote' LIMIT 1];
    }
    
    private static Quote getDomesticQuoteSeqSet() {
        return [SELECT Id FROM Quote WHERE Name = 'Domestic Quote Seq Set' LIMIT 1];
    }
    
    private static Quote getExportQuoteSeqSet() {
        return [SELECT Id FROM Quote WHERE Name = 'Export Quote Seq Set' LIMIT 1];
    }
    
    private static ApexPages.StandardController buildController(Id quoteId) {
        Quote q = new Quote(Id = quoteId);
        return new ApexPages.StandardController(q);
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Test 1 — Domestic Quote, no sequence set
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testConstructor_DomesticQuote_NoSequence() {
        Quote q = getDomesticQuote();
        
        Test.startTest();
        ApexPages.StandardController sc = buildController(q.Id);
        DRC_NBC_DomesticQuotationPDFController ctrl =
            new DRC_NBC_DomesticQuotationPDFController(sc);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Test 2 — Export Quote, no sequence set
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testConstructor_ExportQuote_NoSequence() {
        Quote q = getExportQuote();
        
        Test.startTest();
        ApexPages.StandardController sc = buildController(q.Id);
        DRC_NBC_DomesticQuotationPDFController ctrl =
            new DRC_NBC_DomesticQuotationPDFController(sc);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Test 3 — Domestic Quote, sequence already set
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testConstructor_DomesticQuote_SequenceAlreadySet_NullSpecialReq() {
        Quote q = getDomesticQuoteSeqSet();
        
        Test.startTest();
        ApexPages.StandardController sc = buildController(q.Id);
        DRC_NBC_DomesticQuotationPDFController ctrl =
            new DRC_NBC_DomesticQuotationPDFController(sc);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Test 4 — Export Quote, sequence already set
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testConstructor_ExportQuote_SequenceAlreadySet_NullSpecialReq() {
        Quote q = getExportQuoteSeqSet();
        
        Test.startTest();
        ApexPages.StandardController sc = buildController(q.Id);
        DRC_NBC_DomesticQuotationPDFController ctrl =
            new DRC_NBC_DomesticQuotationPDFController(sc);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Test 5 — getFormattedDate with a valid Date
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testGetFormattedDate_NonNullDate() {
        Quote q = getDomesticQuote();
        
        Test.startTest();
        ApexPages.StandardController sc = buildController(q.Id);
        DRC_NBC_DomesticQuotationPDFController ctrl =
            new DRC_NBC_DomesticQuotationPDFController(sc);
        String result = ctrl.getFormattedDate(Date.today());
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Test 6 — getFormattedDate with null
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testGetFormattedDate_NullDate() {
        Quote q = getDomesticQuote();
        
        Test.startTest();
        ApexPages.StandardController sc = buildController(q.Id);
        DRC_NBC_DomesticQuotationPDFController ctrl =
            new DRC_NBC_DomesticQuotationPDFController(sc);
        String result = ctrl.getFormattedDate(null);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Test 7 — calculateAmounts with all null tax fields
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testCalculateAmounts_AllNullTaxFields() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();
        
        Quote nullTaxQuote = new Quote(
            Name                                    = 'Null Tax Quote',
            OpportunityId                           = opp.Id,
            Pricebook2Id                            = stdPbId,
            ContactId                               = con.Id,
            Status                                  = 'Draft',
            ExpirationDate                          = Date.today().addDays(30),
            BillingStreet                           = '123 Test Street',
            BillingCity                             = 'Indore',
            BillingState                            = 'Madhya Pradesh',
            BillingCountry                          = 'India',
            BillingPostalCode                       = '452001',
            CurrencyISOCode                         = 'INR',
            DRC_NBC_Type__c                         = 'Domestic',
            DRC_NBC_Payemnt_Term__c                 = '100',
            DRC_NBC_Inco_terms__c                   = 'Cost Insurance & Freight (CIF)',
            DRC_NBC_Other_Tax_Amount__c             = null,
            DRC_NBC_TCS_Amount__c                   = null,
            DRC_NBC_Special_Requirements__c         = null,
            DRC_NBC_Import_Starting_Sequence__c     = 1000
        );
        insert nullTaxQuote;
        
        Test.startTest();
        ApexPages.StandardController sc = buildController(nullTaxQuote.Id);
        DRC_NBC_DomesticQuotationPDFController ctrl =
            new DRC_NBC_DomesticQuotationPDFController(sc);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Test 8 — Special Requirements with newline and carriage return characters
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testSpecialRequirements_WithNewlinesAndCarriageReturns() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();
        
        Quote newlineQuote = new Quote(
            Name                                    = 'Newline Special Req Quote',
            OpportunityId                           = opp.Id,
            Pricebook2Id                            = stdPbId,
            ContactId                               = con.Id,
            Status                                  = 'Draft',
            ExpirationDate                          = Date.today().addDays(30),
            BillingStreet                           = '123 Test Street',
            BillingCity                             = 'Indore',
            BillingState                            = 'Madhya Pradesh',
            BillingCountry                          = 'India',
            BillingPostalCode                       = '452001',
            CurrencyISOCode                         = 'INR',
            DRC_NBC_Type__c                         = 'Domestic',
            DRC_NBC_Payemnt_Term__c                 = '100',
            DRC_NBC_Inco_terms__c                   = 'Cost Insurance & Freight (CIF)',
            DRC_NBC_Other_Tax_Amount__c             = 0,
            DRC_NBC_TCS_Amount__c                   = 0,
            DRC_NBC_Special_Requirements__c         = 'Line one\nLine two\rLine three. Final point.',
            DRC_NBC_Import_Starting_Sequence__c     = 1001
        );
        insert newlineQuote;
        
        Test.startTest();
        ApexPages.StandardController sc = buildController(newlineQuote.Id);
        DRC_NBC_DomesticQuotationPDFController ctrl =
            new DRC_NBC_DomesticQuotationPDFController(sc);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Test 9 — Domestic Quote with multiple line items
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testCalculateAmounts_MultipleLineItems() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id LIMIT 1];
        
        Quote multiLineQuote = new Quote(
            Name                                    = 'Multi Line Quote',
            OpportunityId                           = opp.Id,
            Pricebook2Id                            = stdPbId,
            ContactId                               = con.Id,
            Status                                  = 'Draft',
            ExpirationDate                          = Date.today().addDays(30),
            BillingStreet                           = '123 Test Street',
            BillingCity                             = 'Indore',
            BillingState                            = 'Madhya Pradesh',
            BillingCountry                          = 'India',
            BillingPostalCode                       = '452001',
            CurrencyISOCode                         = 'INR',
            DRC_NBC_Type__c                         = 'Domestic',
            DRC_NBC_Payemnt_Term__c                 = '100',
            DRC_NBC_Inco_terms__c                   = 'Cost Insurance & Freight (CIF)',
            DRC_NBC_Other_Tax_Amount__c             = 20,
            DRC_NBC_TCS_Amount__c                   = 10,
            DRC_NBC_Special_Requirements__c         = 'Req A. Req B.',
            DRC_NBC_Import_Starting_Sequence__c     = 1002
        );
        insert multiLineQuote;
        
        // Two line items → subtotal loop iterates twice
        insert new List<QuoteLineItem>{
            new QuoteLineItem(
                QuoteId          = multiLineQuote.Id,
                Product2Id       = prod.Id,
                PricebookEntryId = pbe.Id,
                Quantity         = 2,
                UnitPrice        = 500,
                DRC_NBC_Unit_Of_Measurement__c = 'KGS'
            ),
                new QuoteLineItem(
                    QuoteId          = multiLineQuote.Id,
                    Product2Id       = prod.Id,
                    PricebookEntryId = pbe.Id,
                    Quantity         = 1,
                    UnitPrice        = 500,
                    DRC_NBC_Unit_Of_Measurement__c = 'KGS'
                )
                };
                    
        Test.startTest();
        ApexPages.StandardController sc = buildController(multiLineQuote.Id);
        DRC_NBC_DomesticQuotationPDFController ctrl =
            new DRC_NBC_DomesticQuotationPDFController(sc);
        Test.stopTest();
    }
}