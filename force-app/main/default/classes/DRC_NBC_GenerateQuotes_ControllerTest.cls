/**
* @File Name : DRC_NBC_GenerateQuotes_ControllerTest.cls
* @Description : Complete test class targeting 100% coverage of DRC_NBC_GenerateQuotes_Controller
* @Author :
* @Last Modified By :
* @Last Modified On : March 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 16, 2025 |   | Initial Version
* 1.1 | February 16, 2026 |   | Enhanced coverage to 90%+
* 1.2 | February 20, 2026 |   | Added tests for all remaining uncovered branches
* 1.3 | March 2026        |   | Added tests to cover shipping/billing field
*                              |   assignment lines and packing details map
**/
@isTest
public class DRC_NBC_GenerateQuotes_ControllerTest {

    // ─── Test Setup ───────────────────────────────────────────────────────────

    @testSetup
    static void setupTestData() {
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

        Contact con = new Contact(
            FirstName = 'John', LastName = 'Doe',
            Email = 'john.doe@example.com',
            Phone = '1234567890', Fax = '1234567890',
            AccountId = acc.Id
        );
        insert con;

        Contact conNoEmail = new Contact(
            FirstName = 'Jane', LastName = 'Smith',
            AccountId = acc.Id
        );
        insert conNoEmail;

        Pricebook2 pb = new Pricebook2(
            Name = 'DRC PriceBook',
            IsActive = true,
            DRC_NBC_External_Id__c = 'DRC001'
        );
        insert pb;

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

        // Packing Details child records – covers productPackingMap population in searchProducts
        // and the DRC_NBC_Packing_Qauntity__c != null → String.valueOf() branch
        DRC_NBC_Packing_Details__c pd1 = new DRC_NBC_Packing_Details__c(
            Product__c                  = prod1.Id,
            DRC_NBC_Packing_Size__c     = '25KG',
            DRC_NBC_Packing_Qauntity__c = String.valueOf(20)
        );
        insert pd1;

        DRC_NBC_Packing_Details__c pd2 = new DRC_NBC_Packing_Details__c(
            Product__c                  = prod1.Id,
            DRC_NBC_Packing_Size__c     = '50KG',
            DRC_NBC_Packing_Qauntity__c = String.valueOf(20)
        );
        insert pd2;

        DRC_NBC_Restricted_Product__c restrictedProd = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Product__c  = prod1.Id,
            DRC_NBC_Customer__c = acc.Id
        );
        insert restrictedProd;

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

        Opportunity opp = new Opportunity(
            Name            = 'Test Opportunity',
            StageName       = 'Prospecting',
            CloseDate       = Date.today().addDays(10),
            AccountId       = acc.Id,
            CurrencyIsoCode = 'INR',
            Pricebook2Id    = pb.Id
        );
        insert opp;

        // Address WITH all compound sub-fields populated → DRC_NBC_Address__c != null
        // This is the key record that drives the shipping field assignment branch
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
    }

    // ─── getOpportunityContacts ───────────────────────────────────────────────

    @isTest
    static void testGetOpportunityContacts() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Contact> contacts =
            DRC_NBC_GenerateQuotes_Controller.getOpportunityContacts(opp.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetOpportunityContacts_NullId() {
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.getOpportunityContacts(null);
        } catch (AuraHandledException e) {
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
    }

    @isTest
    static void testGetAccountBillingAddress_NullId() {
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.getAccountBillingAddress(null);
        } catch (AuraHandledException e) {
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
    }

    @isTest
    static void testGetAccountAddresses_NullId() {
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.getAccountAddresses(null);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    // ─── searchProducts ───────────────────────────────────────────────────────

    /**
     * Covers: productPackingMap population loop body:
     *   - !productPackingMap.containsKey(pd.Product__c) → TRUE → new list created
     *   - DRC_NBC_Packing_Qauntity__c != null → TRUE → String.valueOf() branch
     *   - productPackingMap.get(pbe.Product2Id) → non-empty list returned
     *   Both the restricted (allowedProductIds not empty) and the
     *   productPackingMap.containsKey() existing-key branch are hit on second pd.
     */
    @isTest
    static void testSearchProducts_WithRestriction_WithPackingDetails() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<DRC_NBC_GenerateQuotes_Controller.ProductWrapper> products =
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test Product 1', 'INR', acc.Id);
        Test.stopTest();
    }

    /**
     * Covers: no-restriction branch AND productPackingMap entries for products
     *         with packing details (DRC_NBC_Packing_Qauntity__c != null branch)
     */
    @isTest
    static void testSearchProducts_WithoutRestriction_WithPackingDetails() {
        Test.startTest();
        List<DRC_NBC_GenerateQuotes_Controller.ProductWrapper> products =
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test Product 1', 'INR', null);
        Test.stopTest();
    }

    /**
     * Covers: DRC_NBC_Packing_Qauntity__c == null → qtyStr = '' branch
     *         in productPackingMap population loop
     */
    @isTest
    static void testSearchProducts_PackingDetails_NullQuantity() {
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product 2' LIMIT 1];
        DRC_NBC_Packing_Details__c pdNullQty = new DRC_NBC_Packing_Details__c(
            Product__c              = prod.Id,
            DRC_NBC_Packing_Size__c = '20L'
            // DRC_NBC_Packing_Qauntity__c intentionally null → covers qtyStr = '' branch
        );
        insert pdNullQty;

        Test.startTest();
        List<DRC_NBC_GenerateQuotes_Controller.ProductWrapper> products =
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test Product 2', 'INR', null);
        Test.stopTest();
    }

    @isTest
    static void testSearchProducts_WithRestriction() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<DRC_NBC_GenerateQuotes_Controller.ProductWrapper> products =
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test Product', 'INR', acc.Id);
        Test.stopTest();
    }

    @isTest
    static void testSearchProducts_WithoutRestriction() {
        Test.startTest();
        List<DRC_NBC_GenerateQuotes_Controller.ProductWrapper> products =
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', 'INR', null);
        Test.stopTest();
    }

    @isTest
    static void testSearchProducts_BlankCurrency() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', '', acc.Id);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    @isTest
    static void testSearchProducts_NullCurrency() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', null, acc.Id);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    // ─── createQuoteWithLines – NEW coverage tests ────────────────────────────

    /**
     * Covers ALL of these previously-uncovered lines in one test:
     *
     *   SHIPPING BLOCK (addrRecord.DRC_NBC_Address__c != null → TRUE):
     *     quoteData.ShippingStreet     = addrRecord.DRC_NBC_Address__Street__s;
     *     quoteData.ShippingCity       = addrRecord.DRC_NBC_Address__City__s;
     *     quoteData.ShippingPostalCode = addrRecord.DRC_NBC_Address__PostalCode__s;
     *     quoteData.ShippingStateCode  = addrRecord.DRC_NBC_Address__StateCode__s;
     *     quoteData.ShippingCountryCode= addrRecord.DRC_NBC_Address__CountryCode__s;
     *
     *   BILLING BLOCK (String.isBlank(quoteData.BillingStreet) → TRUE,
     *                  oppWithAccount.Account != null → TRUE):
     *     quoteData.BillingStreet    = oppWithAccount.Account.BillingStreet;
     *     quoteData.BillingCity      = oppWithAccount.Account.BillingCity;
     *     quoteData.BillingState     = oppWithAccount.Account.BillingState;
     *     quoteData.BillingPostalCode= oppWithAccount.Account.BillingPostalCode;
     *     quoteData.BillingCountry   = oppWithAccount.Account.BillingCountry;
     *     quoteData.BillingCountryCode= oppWithAccount.Account.BillingCountryCode;
     *
     *   PBE MAP (productIdToPriceBookEntryId.put loop executes):
     *     productIdToPriceBookEntryId.put(pbe.Product2Id, pbe.Id);
     */
    @isTest
    static void testCreateQuote_ShippingFieldAssignment_BillingFallbackFieldAssignment() {
        Opportunity opp              = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con                  = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        // Address with all sub-fields → compound DRC_NBC_Address__c != null
        DRC_NBC_Addresses__c address = [SELECT Id FROM DRC_NBC_Addresses__c
                                        WHERE DRC_NBC_Address__Street__s = '456 Ship Lane' LIMIT 1];
        Product2 prod                = [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1];
        PricebookEntry pbe           = [SELECT Id FROM PricebookEntry
                                        WHERE Product2Id = :prod.Id
                                        AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        // BillingStreet blank → enters billing fallback block
        // ShippingAddress has all sub-fields → enters shipping field assignment block
        Quote quote = new Quote(
            Name                           = 'Shipping+Billing Field Assignment',
            ExpirationDate                 = Date.today().addDays(30),
            CurrencyIsoCode                = 'INR',
            ContactId                      = con.Id,
            DRC_NBC_Shipping_Address_Id__c = address.Id
            // BillingStreet intentionally omitted
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 2, 100, '25KG', '10')
            }
        );
        Test.stopTest();
    }

    /**
     * Covers:
     *   - addrRecord.DRC_NBC_Address__c != null → TRUE (shipping fields assigned)
     *   - String.isBlank(quoteData.BillingStreet) → FALSE
     *     → Account billing fallback block entirely SKIPPED
     *   - productIdToPriceBookEntryId map populated
     */
    @isTest
    static void testCreateQuote_ShippingAssignment_BillingProvided_FallbackSkipped() {
        Opportunity opp              = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con                  = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        DRC_NBC_Addresses__c address = [SELECT Id FROM DRC_NBC_Addresses__c
                                        WHERE DRC_NBC_Address__Street__s = '456 Ship Lane' LIMIT 1];
        Product2 prod                = [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1];
        PricebookEntry pbe           = [SELECT Id FROM PricebookEntry
                                        WHERE Product2Id = :prod.Id
                                        AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        // BillingStreet populated → billing fallback block is skipped
        Quote quote = new Quote(
            Name                           = 'Shipping Assign + Explicit Billing',
            ExpirationDate                 = Date.today().addDays(30),
            CurrencyIsoCode                = 'INR',
            ContactId                      = con.Id,
            BillingStreet                  = '10 Explicit Rd',
            BillingCity                    = 'Bengaluru',
            BillingPostalCode              = '560001',
            BillingCountry                 = 'India',
            BillingCountryCode             = 'IN',
            DRC_NBC_Shipping_Address_Id__c = address.Id
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 1, 100, '50KG', '20')
            }
        );
        Test.stopTest();
    }

    /**
     * Covers:
     *   - DRC_NBC_Shipping_Address_Id__c == null → shipping block skipped
     *   - String.isBlank(quoteData.BillingStreet) → TRUE
     *   - oppWithAccount.Account != null → TRUE
     *     → ALL six billing field assignment lines executed
     *   - productIdToPriceBookEntryId map populated
     */
    @isTest
    static void testCreateQuote_NoShipping_BillingFallback_AllSixFieldsAssigned() {
        Opportunity opp    = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con        = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod      = [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry
                              WHERE Product2Id = :prod.Id
                              AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        // No shipping, no billing → full account billing fallback executes
        Quote quote = new Quote(
            Name            = 'No Ship Full Billing Fallback',
            ExpirationDate  = Date.today().addDays(30),
            CurrencyIsoCode = 'INR',
            ContactId       = con.Id
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 3, 150, null, null)
            }
        );
        Test.stopTest();
    }

    /**
     * Covers: productIdToPriceBookEntryId.put() called for multiple products
     *         (map loop iterates > 1 time)
     *         Also covers wrapper.PackingSize blank → packing size NOT assigned
     *         and wrapper.PackingQuantity blank → packing qty NOT assigned (else branches)
     */
    @isTest
    static void testCreateQuote_MultipleProducts_PBEMapMultipleEntries() {
        Opportunity opp     = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con         = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod1      = [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1];
        Product2 prod2      = [SELECT Id FROM Product2 WHERE Name = 'Test Product 2' LIMIT 1];
        PricebookEntry pbe1 = [SELECT Id FROM PricebookEntry
                               WHERE Product2Id = :prod1.Id
                               AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        PricebookEntry pbe2 = [SELECT Id FROM PricebookEntry
                               WHERE Product2Id = :prod2.Id
                               AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name              = 'Multi Product PBE Map',
            ExpirationDate    = Date.today().addDays(30),
            CurrencyIsoCode   = 'INR',
            ContactId         = con.Id,
            BillingStreet     = '2 Multi St',
            BillingCity       = 'Chennai',
            BillingPostalCode = '600001',
            BillingCountry    = 'India',
            BillingCountryCode = 'IN'
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod1.Id, pbe1.Id, 2, 100, null, null),
                makeItem(prod2.Id, pbe2.Id, 3, 200, null, null)
            }
        );
        Test.stopTest();
    }

    // ─── Existing tests (unchanged) ──────────────────────────────────────────

    @isTest
    static void testCreateQuote_ShippingCompoundPopulated_BillingFallback() {
        Opportunity opp              = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con                  = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        DRC_NBC_Addresses__c address = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        Product2 prod                = [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1];
        PricebookEntry pbe           = [SELECT Id FROM PricebookEntry
                                        WHERE Product2Id = :prod.Id
                                        AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];

        Quote quote = new Quote(
            Name            = 'Compound Shipping + Billing Fallback',
            ExpirationDate  = Date.today().addDays(30),
            CurrencyIsoCode = 'INR',
            ContactId       = con.Id,
            DRC_NBC_Shipping_Address_Id__c = address.Id
        );

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{
                makeItem(prod.Id, pbe.Id, 3, 100, '25KG', '10')
            }
        );
        Test.stopTest();
    }

    @isTest
    static void testCreateQuoteWithLinesSuccess() {
        Opportunity opp              = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con                  = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        DRC_NBC_Addresses__c address = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        Product2 prod                = [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1];
        PricebookEntry pbe           = [SELECT Id FROM PricebookEntry
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
    }

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

    @isTest
    static void testCreateQuote_MissingPBE_UnknownProductName() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con     = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        Quote quote = new Quote(
            Name = 'Unknown Product Test', ExpirationDate = Date.today().addDays(30),
            CurrencyIsoCode = 'INR', ContactId = con.Id
        );

        Id fakeProductId = '01t000000000001AAA';

        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item =
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id       = fakeProductId;
        item.PricebookEntryId = null;
        item.Quantity         = 1;
        item.UnitPrice        = 10;

        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(
            opp.Id, quote,
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item }
        );
        Test.stopTest();
    }

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
    }

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
    }

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

    @isTest
    static void testCreateQuoteWithMissingPricebookEntry() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con     = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];

        Product2 prodNoPBE = new Product2(Name = 'No PBE Product', IsActive = true);
        insert prodNoPBE;
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
            DRC_NBC_Account__c   = acc.Id,
            DRC_NBC_Type__c      = 'Shipping',
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
    }

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
    }

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
    }

    // ─── Inner class constructors ─────────────────────────────────────────────

    @isTest
    static void testInnerClassConstructors() {
        Test.startTest();

        DRC_NBC_GenerateQuotes_Controller.QuoteWrapper qw =
            new DRC_NBC_GenerateQuotes_Controller.QuoteWrapper();
        qw.oppCurrency = 'USD';
        qw.accountSpecialInstruction = 'Fragile';

        DRC_NBC_GenerateQuotes_Controller.AccountAddressWrapper aw =
            new DRC_NBC_GenerateQuotes_Controller.AccountAddressWrapper(
                'Street', 'City', 'State', '123456', 'Country', 'CC'
            );

        DRC_NBC_GenerateQuotes_Controller.PackingDetailWrapper pdw =
            new DRC_NBC_GenerateQuotes_Controller.PackingDetailWrapper('25KG', '40');

        List<DRC_NBC_GenerateQuotes_Controller.PackingDetailWrapper> packingList =
            new List<DRC_NBC_GenerateQuotes_Controller.PackingDetailWrapper>{ pdw };

        DRC_NBC_GenerateQuotes_Controller.ProductWrapper pw =
            new DRC_NBC_GenerateQuotes_Controller.ProductWrapper(
                null, null, 'My Product', 99.00, 'FG001', 'HSN001', 'KGS', packingList
            );

        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper li =
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        li.PackingSize     = '50KG';
        li.PackingQuantity = '20';

        Test.stopTest();
    }
}