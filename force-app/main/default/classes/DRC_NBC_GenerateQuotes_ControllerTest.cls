/**
* @File Name : DRC_NBC_GenerateQuotes_ControllerTest.cls
* @Description : Complete test class targeting 100% coverage of DRC_NBC_GenerateQuotes_Controller
* @Author :
* @Last Modified By :
* @Last Modified On : February 20, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 16, 2025 |   | Initial Version
* 1.1 | February 16, 2026 |   | Enhanced coverage to 90%+
* 1.2 | February 20, 2026 |   | Added tests for all remaining uncovered branches
*                              |   - Shipping compound field != null branch
*                              |   - Billing fallback from Account branch
*                              |   - 'Unknown Product' null-name fallback branch
*                              |   - realQuoteLineItems.isEmpty() rollback branch
*                              |   - All inner class constructors
**/
@isTest
public class DRC_NBC_GenerateQuotes_ControllerTest {

    // ─── Test Setup ───────────────────────────────────────────────────────────

    @testSetup
    static void setupTestData() {
        // Account with complete billing address
        Account acc = new Account(
            Name               = 'Test Account',
            BillingStreet      = '123 Test St',
            BillingCity        = 'Mumbai',
            BillingState       = 'Maharashtra',
            BillingPostalCode  = '400001',
            BillingCountry     = 'India',
            BillingCountryCode = 'IN',
            DRC_NBC_Special_Instructions__c = 'Handle with care'
        );
        insert acc;

        // Contact WITH email
        Contact con = new Contact(
            FirstName = 'John', LastName = 'Doe',
            Email = 'john.doe@example.com',
            Phone = '1234567890', Fax = '1234567890',
            AccountId = acc.Id
        );
        insert con;

        // Contact WITHOUT email (for negative testing)
        Contact conNoEmail = new Contact(
            FirstName = 'Jane', LastName = 'Smith',
            AccountId = acc.Id
        );
        insert conNoEmail;

        // DRC Pricebook
        Pricebook2 pb = new Pricebook2(
            Name = 'DRC PriceBook',
            IsActive = true,
            DRC_NBC_External_Id__c = 'DRC001'
        );
        insert pb;

        // Products
        List<Product2> products = new List<Product2>();
        Product2 prod1 = new Product2(
            Name = 'Test Product 1', IsActive = true,
            DRC_NBC_FG_Code__c = 'FG001',
            DRC_NBC_HSN_SAC_Code__c = 'HSN001',
            QuantityUnitOfMeasure = 'KGS',
            DRC_NBC_Packing_Size__c = '25KG;50KG'
        );
        products.add(prod1);

        Product2 prod2 = new Product2(
            Name = 'Test Product 2', IsActive = true,
            DRC_NBC_FG_Code__c = 'FG002',
            DRC_NBC_HSN_SAC_Code__c = 'HSN002',
            QuantityUnitOfMeasure = 'LTR',
            DRC_NBC_Packing_Size__c = '10L;20L'
        );
        products.add(prod2);
        insert products;

        // Restricted Product record
        DRC_NBC_Restricted_Product__c restrictedProd = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Product__c  = prod1.Id,
            DRC_NBC_Customer__c = acc.Id
        );
        insert restrictedProd;

        // Standard PricebookEntries (required before custom PBEs)
        Id standardPBId = Test.getStandardPricebookId();
        List<PricebookEntry> standardPBEs = new List<PricebookEntry>();
        for (Product2 prod : products) {
            standardPBEs.add(new PricebookEntry(
                Pricebook2Id = standardPBId,
                Product2Id   = prod.Id,
                UnitPrice    = 100,
                IsActive     = true
            ));
        }
        insert standardPBEs;

        // DRC PricebookEntries
        List<PricebookEntry> customPBEs = new List<PricebookEntry>();
        for (Product2 prod : products) {
            customPBEs.add(new PricebookEntry(
                Pricebook2Id     = pb.Id,
                Product2Id       = prod.Id,
                UnitPrice        = 100,
                IsActive         = true,
                UseStandardPrice = false,
                CurrencyIsoCode  = 'INR'
            ));
        }
        insert customPBEs;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name            = 'Test Opportunity',
            StageName       = 'Prospecting',
            CloseDate       = Date.today().addDays(10),
            AccountId       = acc.Id,
            CurrencyIsoCode = 'INR',
            Pricebook2Id    = pb.Id
        );
        insert opp;

        // Shipping address WITH all sub-fields (compound field will be non-null)
        DRC_NBC_Addresses__c address = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c              = acc.Id,
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Address__Street__s      = '456 Ship Lane',
            DRC_NBC_Address__City__s        = 'Mumbai',
            DRC_NBC_Address__PostalCode__s  = '400002',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Warehouse__c            = 'CFS - JNPT'
        );
        insert address;
    }

    // ─── Helper to build a LineItemWrapper ───────────────────────────────────

    private static DRC_NBC_GenerateQuotes_Controller.LineItemWrapper makeItem(
            Id prod2Id, Id pbeId, Integer qty, Decimal price,
            String packSize, String packQty) {
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item =
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id       = prod2Id;
        item.PricebookEntryId = pbeId;
        item.Quantity         = qty;
        item.UnitPrice        = price;
        item.PackingSize      = packSize;
        item.PackingQuantity  = packQty;
        return item;
    }

    // ─── getQuoteMdtDetails ───────────────────────────────────────────────────

    @isTest
    static void testGetQuoteMdtDetails() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        DRC_NBC_GenerateQuotes_Controller.QuoteWrapper result =
            DRC_NBC_GenerateQuotes_Controller.getQuoteMdtDetails(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
        System.assertEquals('INR', result.oppCurrency);
    }

    // ─── getOpportunityContacts ───────────────────────────────────────────────

    @isTest
    static void testGetOpportunityContacts() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Contact> contacts =
            DRC_NBC_GenerateQuotes_Controller.getOpportunityContacts(opp.Id);
        Test.stopTest();
        System.assert(!contacts.isEmpty(), 'Should return contacts');
    }

    @isTest
    static void testGetOpportunityContacts_NullId() {
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.getOpportunityContacts(null);
            System.assert(false, 'Should throw');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ─── getAccountBillingAddress ─────────────────────────────────────────────

    @isTest
    static void testGetAccountBillingAddress() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        DRC_NBC_GenerateQuotes_Controller.AccountAddressWrapper billing =
            DRC_NBC_GenerateQuotes_Controller.getAccountBillingAddress(opp.Id);
        Test.stopTest();
        System.assertNotEquals(null, billing);
        System.assertEquals('123 Test St', billing.street);
    }

    @isTest
    static void testGetAccountBillingAddress_NullId() {
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.getAccountBillingAddress(null);
            System.assert(false, 'Should throw');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ─── getAccountAddresses ──────────────────────────────────────────────────

    @isTest
    static void testGetAccountAddresses() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<DRC_NBC_Addresses__c> shipping =
            DRC_NBC_GenerateQuotes_Controller.getAccountAddresses(opp.Id);
        Test.stopTest();
        System.assertEquals(1, shipping.size());
    }

    @isTest
    static void testGetAccountAddresses_NullId() {
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.getAccountAddresses(null);
            System.assert(false, 'Should throw');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ─── searchProducts ───────────────────────────────────────────────────────

    @isTest
    static void testSearchProducts_WithRestriction() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<DRC_NBC_GenerateQuotes_Controller.ProductWrapper> products =
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test Product', 'INR', acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, products);
    }

    @isTest
    static void testSearchProducts_WithoutRestriction() {
        Test.startTest();
        List<DRC_NBC_GenerateQuotes_Controller.ProductWrapper> products =
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', 'INR', null);
        Test.stopTest();
        System.assertNotEquals(null, products);
    }

    @isTest
    static void testSearchProducts_BlankCurrency() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', '', acc.Id);
            System.assert(false, 'Should throw');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Currency'));
        }
        Test.stopTest();
    }

    @isTest
    static void testSearchProducts_NullCurrency() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', null, acc.Id);
            System.assert(false, 'Should throw');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ─── createQuoteWithLines – core success paths ────────────────────────────

    /**
     * SUCCESS + shipping compound field populated (DRC_NBC_Address__c != null)
     * + billing fallback from Account (BillingStreet left blank on quote).
     * Covers TWO previously-uncovered branches in one test.
     */
    @isTest
    static void testCreateQuote_ShippingCompoundPopulated_BillingFallback() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con     = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        // Use the address created in setupTestData (has all sub-fields → compound != null)
        DRC_NBC_Addresses__c address = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        Product2 prod   = [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name           = 'Compound Shipping + Billing Fallback',
            ExpirationDate = Date.today().addDays(30),
            CurrencyIsoCode = 'INR',
            ContactId      = con.Id,
            DRC_NBC_Shipping_Address_Id__c = address.Id
            // BillingStreet intentionally blank → triggers Account billing fallback
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 3, 100, '25KG', '10')
            }
        );
        Test.stopTest();

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(true, (Boolean) resMap.get('success'),
            'Should succeed. Error: ' + resMap.get('error'));

        Quote created = [SELECT ShippingStreet, ShippingCity, BillingStreet
                         FROM Quote WHERE Id = :String.valueOf(resMap.get('quoteId')) LIMIT 1];
        System.assertEquals('456 Ship Lane', created.ShippingStreet,
            'ShippingStreet must be set from address record');
        System.assertEquals('123 Test St', created.BillingStreet,
            'BillingStreet must fall back to Account');

        QuoteLineItem qli = [SELECT DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Qauntity__c
                             FROM QuoteLineItem WHERE QuoteId = :created.Id LIMIT 1];
        System.assertEquals('25KG', qli.DRC_NBC_Packing_Size__c);
        System.assertEquals('10',   qli.DRC_NBC_Packing_Qauntity__c);
    }

    /**
     * Covers the existing main success scenario (packing info, explicit billing).
     */
    @isTest
    static void testCreateQuoteWithLinesSuccess() {
        Opportunity opp    = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con        = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        DRC_NBC_Addresses__c address = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name = 'Test Quote', ExpirationDate = Date.today().addDays(30),
            DRC_NBC_Payemnt_Term__c = 'Advance', DRC_NBC_Inco_terms__c = 'FOB',
            DRC_NBC_Type__c = 'Domestic', CurrencyIsoCode = 'INR',
            ContactId = con.Id,
            BillingStreet = '999 Explicit St', BillingCity = 'Pune',
            BillingPostalCode = '411001', BillingCountry = 'India', BillingCountryCode = 'IN',
            DRC_NBC_Shipping_Address_Id__c = address.Id
        );

        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item =
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id; item.PricebookEntryId = pbe.Id;
        item.Quantity = 5; item.UnitPrice = 100;
        item.Description = 'Test Item'; item.CurrencyIsoCode = 'INR';
        item.QuantityUnitOfMeasure = 'KGS';
        item.PackingSize = '25KG'; item.PackingQuantity = '40';

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item }
        );
        Test.stopTest();

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(true, (Boolean) resMap.get('success'),
            'Error: ' + resMap.get('error'));
    }

    // ─── createQuoteWithLines – billing fallback alone (no shipping address) ──

    @isTest
    static void testCreateQuote_BillingFallback_NoShippingAddress() {
        Opportunity opp    = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con        = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name = 'Billing Fallback No Ship', ExpirationDate = Date.today().addDays(30),
            CurrencyIsoCode = 'INR', ContactId = con.Id
            // BillingStreet blank, no DRC_NBC_Shipping_Address_Id__c
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 1, 100, null, null)
            }
        );
        Test.stopTest();

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(true, (Boolean) resMap.get('success'),
            'Error: ' + resMap.get('error'));
        Quote created = [SELECT BillingStreet FROM Quote
                         WHERE Id = :String.valueOf(resMap.get('quoteId')) LIMIT 1];
        System.assertEquals('123 Test St', created.BillingStreet,
            'BillingStreet should fall back to Account billing address');
    }

    // ─── createQuoteWithLines – 'Unknown Product' fallback name ──────────────

    /**
     * Passes a fake Product2Id (no matching record) with no PricebookEntryId.
     * productIdToName.get() returns null → 'Unknown Product' label used in error.
     */
    @isTest
    static void testCreateQuote_MissingPBE_UnknownProductName() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con     = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        Quote quote = new Quote(
            Name = 'Unknown Product Test', ExpirationDate = Date.today().addDays(30),
            CurrencyIsoCode = 'INR', ContactId = con.Id
        );

        // Fake Product2Id — exists in schema but not in the org → not in productIdToName map
        Id fakeProductId = '01t000000000001AAA';

        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item =
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id       = fakeProductId;
        item.PricebookEntryId = null;   // No fallback PBE either
        item.Quantity         = 1;
        item.UnitPrice        = 10;

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item }
        );
        Test.stopTest();

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(false, (Boolean) resMap.get('success'));
        System.assert(
            ((String) resMap.get('error')).contains('Unknown Product'),
            'Error should contain "Unknown Product", got: ' + resMap.get('error')
        );
    }

    // ─── createQuoteWithLines – realQuoteLineItems.isEmpty() rollback ─────────

    /**
     * All wrappers have Product2Id = null → every item hits `continue`.
     * missingPricebookProducts stays empty too → reaches the isEmpty() branch
     * and returns 'No valid products to create quote line items.'
     */
    @isTest
    static void testCreateQuote_AllNullProduct2Ids_EmptyQLIList() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con     = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        Quote quote = new Quote(
            Name = 'All Null Product2Id Test', ExpirationDate = Date.today().addDays(30),
            CurrencyIsoCode = 'INR', ContactId = con.Id
        );

        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper nullItem =
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        nullItem.Product2Id = null;
        nullItem.Quantity   = 1;
        nullItem.UnitPrice  = 50;

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ nullItem }
        );
        Test.stopTest();

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(false, (Boolean) resMap.get('success'));
        System.assert(
            ((String) resMap.get('error')).contains('No valid products'),
            'Error should say "No valid products", got: ' + resMap.get('error')
        );
    }

    // ─── createQuoteWithLines – no line items ─────────────────────────────────

    @isTest
    static void testCreateQuoteWithNoLineItems() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con     = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        Quote quote = new Quote(
            Name = 'Empty Quote', ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id, CurrencyIsoCode = 'INR'
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>()
        );
        Test.stopTest();

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(false, (Boolean) resMap.get('success'));
        System.assert(((String) resMap.get('error')).contains('No products selected'));
    }

    // ─── createQuoteWithLines – contact without email ─────────────────────────

    @isTest
    static void testCreateQuoteWithContactNoEmail() {
        Opportunity opp    = [SELECT Id FROM Opportunity LIMIT 1];
        Contact conNoEmail = [SELECT Id FROM Contact WHERE Email = null LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name = 'No Email Quote', ExpirationDate = Date.today().addDays(30),
            ContactId = conNoEmail.Id, CurrencyIsoCode = 'INR'
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 1, 100, null, null)
            }
        );
        Test.stopTest();
    }

    // ─── createQuoteWithLines – opportunity without pricebook ─────────────────

    @isTest
    static void testCreateQuoteOppWithoutPricebook() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity oppNoPB = new Opportunity(
            Name = 'No PB Opp', StageName = 'Prospecting',
            CloseDate = Date.today().addDays(5),
            AccountId = acc.Id, CurrencyIsoCode = 'INR'
        );
        insert oppNoPB;

        Contact con    = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod  = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name = 'No PB Quote', ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id, CurrencyIsoCode = 'INR'
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            oppNoPB.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 1, 100, null, null)
            }
        );
        Test.stopTest();
    }

    // ─── createQuoteWithLines – missing pricebook entry (known product name) ──

    @isTest
    static void testCreateQuoteWithMissingPricebookEntry() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con     = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        // Product exists but has NO DRC pricebook entry
        Product2 prodNoPBE = new Product2(Name = 'No PBE Product', IsActive = true);
        insert prodNoPBE;
        // Only standard PBE (no DRC PBE) so productIdToName will have the name
        insert new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = prodNoPBE.Id,
            UnitPrice    = 50, IsActive = true
        );

        Quote quote = new Quote(
            Name = 'Bad Quote', ExpirationDate = Date.today().addDays(10),
            ContactId = con.Id, CurrencyIsoCode = 'INR'
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prodNoPBE.Id, null, 1, 10, null, null)
            }
        );
        Test.stopTest();
    }

    // ─── createQuoteWithLines – fallback PBE from LWC ────────────────────────

    @isTest
    static void testCreateQuoteWithFallbackPBE() {
        Opportunity opp    = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con        = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name = 'Fallback PBE Quote', ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id, CurrencyIsoCode = 'INR'
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 1, 100, null, null)
            }
        );
        Test.stopTest();
    }

    // ─── createQuoteWithLines – mixed null / valid Product2Ids ───────────────

    @isTest
    static void testCreateQuoteWithNullProduct2Id() {
        Opportunity opp    = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con        = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name = 'Mixed Quote', ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id, CurrencyIsoCode = 'INR'
        );

        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper nullItem =
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        nullItem.Product2Id = null; nullItem.Quantity = 1; nullItem.UnitPrice = 50;

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 1, 100, null, null),
                nullItem
            }
        );
        Test.stopTest();
    }

    // ─── createQuoteWithLines – shipping address without compound field ────────

    @isTest
    static void testCreateQuoteWithShippingAddressNoCompound() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con     = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Account acc     = [SELECT Id FROM Account LIMIT 1];
        Product2 prod   = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        DRC_NBC_Addresses__c addrNoCompound = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c = acc.Id,
            DRC_NBC_Type__c    = 'Shipping',
            DRC_NBC_Warehouse__c = 'CFS - JNPT'
        );
        insert addrNoCompound;

        Quote quote = new Quote(
            Name = 'No Compound Addr Quote', ExpirationDate = Date.today().addDays(30),
            CurrencyIsoCode = 'INR', ContactId = con.Id,
            DRC_NBC_Shipping_Address_Id__c = addrNoCompound.Id
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 1, 100, null, null)
            }
        );
        Test.stopTest();
    }

    // ─── createQuoteWithLines – explicit billing (no fallback needed) ─────────

    @isTest
    static void testCreateQuoteWithExistingBillingAddress() {
        Opportunity opp    = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con        = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name = 'Quote with Billing', ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id, CurrencyIsoCode = 'INR',
            BillingStreet = '999 Custom Billing St', BillingCity = 'Delhi',
            BillingState = 'Delhi', BillingPostalCode = '110001',
            BillingCountry = 'India', BillingCountryCode = 'IN'
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 1, 100, null, null)
            }
        );
        Test.stopTest();
    }

    // ─── createQuoteWithLines – zero quantity (defaults to 1) ─────────────────

    @isTest
    static void testCreateQuoteWithZeroQuantity() {
        Opportunity opp    = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con        = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name = 'Zero Qty Quote', ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id, CurrencyIsoCode = 'INR'
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 0, 100, null, null)
            }
        );
        Test.stopTest();

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(true, (Boolean) resMap.get('success'),
            'Error: ' + resMap.get('error'));
        QuoteLineItem qli = [SELECT Quantity FROM QuoteLineItem
                             WHERE QuoteId = :String.valueOf(resMap.get('quoteId')) LIMIT 1];
        System.assertEquals(1, qli.Quantity, 'Zero qty should default to 1');
    }

    // ─── createQuoteWithLines – packing size only ─────────────────────────────

    @isTest
    static void testCreateQuoteWithOnlyPackingSize() {
        Opportunity opp    = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con        = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id,
            new Quote(Name = 'Only Size', ExpirationDate = Date.today().addDays(30),
                      ContactId = con.Id, CurrencyIsoCode = 'INR'),
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 5, 100, '25KG', null)
            }
        );
        Test.stopTest();

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(true, (Boolean) resMap.get('success'),
            'Error: ' + resMap.get('error'));
    }

    // ─── createQuoteWithLines – packing quantity only ─────────────────────────

    @isTest
    static void testCreateQuoteWithOnlyPackingQuantity() {
        Opportunity opp    = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con        = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id,
            new Quote(Name = 'Only Qty', ExpirationDate = Date.today().addDays(30),
                      ContactId = con.Id, CurrencyIsoCode = 'INR'),
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 5, 100, null, '40')
            }
        );
        Test.stopTest();

        Map<String, Object> resMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(true, (Boolean) resMap.get('success'),
            'Error: ' + resMap.get('error'));
    }


    // ─── Inner class constructors ─────────────────────────────────────────────

    @isTest
    static void testInnerClassConstructors() {
        Test.startTest();

        // QuoteWrapper
        DRC_NBC_GenerateQuotes_Controller.QuoteWrapper qw =
            new DRC_NBC_GenerateQuotes_Controller.QuoteWrapper();
        qw.oppCurrency = 'USD';
        qw.accountSpecialInstruction = 'Fragile';


        // AccountAddressWrapper
        DRC_NBC_GenerateQuotes_Controller.AccountAddressWrapper aw =
            new DRC_NBC_GenerateQuotes_Controller.AccountAddressWrapper(
                'Street', 'City', 'State', '123456', 'Country', 'CC'
            );
        System.assertEquals('Street',  aw.street);
        System.assertEquals('City',    aw.city);
        System.assertEquals('State',   aw.state);
        System.assertEquals('123456',  aw.postalCode);
        System.assertEquals('Country', aw.country);
        System.assertEquals('CC',      aw.countryCode);

        // ProductWrapper
        DRC_NBC_GenerateQuotes_Controller.ProductWrapper pw =
            new DRC_NBC_GenerateQuotes_Controller.ProductWrapper(
                null, null, 'My Product', 99.00, 'FG001', 'HSN001', 'KGS', '25KG'
            );
        System.assertEquals('My Product', pw.Name);
        System.assertEquals(99.00,        pw.UnitPrice);
        System.assertEquals('25KG',       pw.PackingSizes);
        System.assertEquals('FG001',      pw.FGCode);
        System.assertEquals('HSN001',     pw.HSNCode);

        // LineItemWrapper
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper li =
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        li.PackingSize     = '50KG';
        li.PackingQuantity = '20';
      

        Test.stopTest();
    }
}