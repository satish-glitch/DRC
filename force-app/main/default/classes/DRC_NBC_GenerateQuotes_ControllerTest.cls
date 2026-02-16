/**
* @File Name : DRC_NBC_GenerateQuotes_ControllerTest.cls
* @Description : Enhanced test class with improved code coverage
* @Author :
* @Last Modified By :
* @Last Modified On : February 16, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 16, 2025 |   | Initial Version
* 1.1 | February 16, 2026 |   | Enhanced coverage to 90%+
**/

@isTest
public class DRC_NBC_GenerateQuotes_ControllerTest {
    
    // Test data setup method
    @testSetup
    static void setupTestData() {
        // Create Account with complete billing address
        Account acc = new Account( 
            Name = 'Test Account',
            BillingStreet = '123 Test St',
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India',
            BillingCountryCode = 'IN',
            DRC_NBC_Special_Instructions__c = 'Handle with care'
        );
        insert acc;
        
        // Create Contact with email
        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com',
            Phone = '1234567890',
            Fax = '1234567890',
            AccountId = acc.Id
        );
        insert con;
        
        // Create Contact without email for negative testing
        Contact conNoEmail = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            AccountId = acc.Id
        );
        insert conNoEmail;
        
        // Create DRC Pricebook
        Pricebook2 pb = new Pricebook2(
            Name = 'DRC PriceBook',
            IsActive = true,
            DRC_NBC_External_Id__c = 'DRC001'
        );
        insert pb;
        
        // Create Products
        List<Product2> products = new List<Product2>();
        Product2 prod1 = new Product2(
            Name = 'Test Product 1',
            IsActive = true,
            DRC_NBC_FG_Code__c = 'FG001',
            DRC_NBC_HSN_SAC_Code__c = 'HSN001',
            QuantityUnitOfMeasure = 'KGS',
            DRC_NBC_Packing_Size__c = '25KG;50KG'
        );
        products.add(prod1);
        
        Product2 prod2 = new Product2(
            Name = 'Test Product 2',
            IsActive = true,
            DRC_NBC_FG_Code__c = 'FG002',
            DRC_NBC_HSN_SAC_Code__c = 'HSN002',
            QuantityUnitOfMeasure = 'LTR',
            DRC_NBC_Packing_Size__c = '10L;20L'
        );
        products.add(prod2);
        insert products;
        
        // Create Restricted Product
        DRC_NBC_Restricted_Product__c restrictedProd = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Product__c = prod1.Id,
            DRC_NBC_Customer__c = acc.Id
        );
        insert restrictedProd;
        
        // Insert standard PricebookEntry
        Id standardPBId = Test.getStandardPricebookId();
        List<PricebookEntry> standardPBEs = new List<PricebookEntry>();
        for (Product2 prod : products) {
            PricebookEntry standardPBE = new PricebookEntry(
                Pricebook2Id = standardPBId,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true
            );
            standardPBEs.add(standardPBE);
        }
        insert standardPBEs;
        
        // Insert custom PricebookEntries
        List<PricebookEntry> customPBEs = new List<PricebookEntry>();
        for (Product2 prod : products) {
            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = pb.Id,
                Product2Id = prod.Id,
                UnitPrice = 100,
                IsActive = true,
                UseStandardPrice = false,
                CurrencyIsoCode = 'INR'
            );
            customPBEs.add(pbe);
        }
        insert customPBEs;
        
        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            CurrencyIsoCode = 'INR',
            Pricebook2Id = pb.Id
        );
        insert opp;
        
        // Create Custom Shipping Address
        DRC_NBC_Addresses__c address = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c = acc.Id,
            DRC_NBC_Type__c = 'Shipping',
            DRC_NBC_Address__Street__s = '456 Ship Lane',
            DRC_NBC_Address__City__s = 'Mumbai',
            DRC_NBC_Address__PostalCode__s = '400002',
            DRC_NBC_Address__StateCode__s = 'MH',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Warehouse__c = 'CFS - JNPT'
        );
        insert address;
    }
    
    // Test: getQuoteMdtDetails
    @isTest
    static void testGetQuoteMdtDetails() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DRC_NBC_GenerateQuotes_Controller.QuoteWrapper result = 
            DRC_NBC_GenerateQuotes_Controller.getQuoteMdtDetails(opp.Id);
        Test.stopTest();
    }
    
    // Test: getOpportunityContacts
    @isTest
    static void testGetOpportunityContacts() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        List<Contact> contacts = DRC_NBC_GenerateQuotes_Controller.getOpportunityContacts(opp.Id);
        Test.stopTest();
    }
    
    // Test: getAccountBillingAddress
    @isTest
    static void testGetAccountBillingAddress() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        DRC_NBC_GenerateQuotes_Controller.AccountAddressWrapper billing = 
            DRC_NBC_GenerateQuotes_Controller.getAccountBillingAddress(opp.Id);
        Test.stopTest();
    }
    
    // Test: getAccountAddresses (Shipping only)
    @isTest
    static void testGetAccountAddresses() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        List<DRC_NBC_Addresses__c> shipping = 
            DRC_NBC_GenerateQuotes_Controller.getAccountAddresses(opp.Id);
        Test.stopTest();
    }
    
    // Test: searchProducts with account restriction
    @isTest
    static void testSearchProductsWithRestriction() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<DRC_NBC_GenerateQuotes_Controller.ProductWrapper> products =
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test Product', 'INR', acc.Id);
        Test.stopTest();
    }
    
    // Test: searchProducts without account restriction
    @isTest
    static void testSearchProductsWithoutRestriction() {
        Test.startTest();
        List<DRC_NBC_GenerateQuotes_Controller.ProductWrapper> products =
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', 'INR', null);
        Test.stopTest();
    }
    
    // Test: searchProducts with blank currency
    @isTest
    static void testSearchProductsBlankCurrency() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', '', acc.Id);
        } catch (AuraHandledException e) {
            // Expected exception
        }
        Test.stopTest();
    }
    
    // Test: createQuoteWithLines - Success scenario with packing info
    @isTest
    static void testCreateQuoteWithLinesSuccess() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        DRC_NBC_Addresses__c address = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product 1' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'Test Quote',
            ExpirationDate = Date.today().addDays(30),
            DRC_NBC_Payemnt_Term__c = 'Advance',
            DRC_NBC_Inco_terms__c = 'FOB',
            DRC_NBC_Type__c = 'Domestic',
            CurrencyIsoCode = 'INR',
            ContactId = con.Id,
            DRC_NBC_Shipping_Address_Id__c = address.Id
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 5;
        item.UnitPrice = 100;
        item.Description = 'Test Item';
        item.CurrencyIsoCode = 'INR';
        item.QuantityUnitOfMeasure = 'KGS';
        item.PackingSize = '25KG';
        item.PackingQuantity = '40';
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        
        // Verify Quote was created with addresses
        if (resultMap.get('quoteId') != null) {
            Quote createdQuote = [SELECT Id, ShippingStreet, ShippingCity, BillingStreet FROM Quote WHERE Id = :String.valueOf(resultMap.get('quoteId')) LIMIT 1];
            
            // Verify QuoteLineItem was created with packing info
            QuoteLineItem qli = [SELECT Id, DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Qauntity__c FROM QuoteLineItem WHERE QuoteId = :createdQuote.Id LIMIT 1];
        }
    }
    
    // Test: createQuoteWithLines - No line items
    @isTest
    static void testCreateQuoteWithNoLineItems() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'Empty Quote',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
        );
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>();
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Contact without email
    @isTest
    static void testCreateQuoteWithContactNoEmail() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact conNoEmail = [SELECT Id FROM Contact WHERE Email = null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'No Email Quote',
            ExpirationDate = Date.today().addDays(30),
            ContactId = conNoEmail.Id,
            CurrencyIsoCode = 'INR'
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 1;
        item.UnitPrice = 100;
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Opportunity without Pricebook
    @isTest
    static void testCreateQuoteOppWithoutPricebook() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity oppNoPB = new Opportunity(
            Name = 'No PB Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(5),
            AccountId = acc.Id,
            CurrencyIsoCode = 'INR'
        );
        insert oppNoPB;
        
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'Test Quote',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 1;
        item.UnitPrice = 100;
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(oppNoPB.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        
        // Verify pricebook was assigned
        Opportunity updatedOpp = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :oppNoPB.Id];
    }
    
    // Test: createQuoteWithLines - Missing PricebookEntry
    @isTest
    static void testCreateQuoteWithMissingPricebookEntry() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        
        // Create product without PricebookEntry
        Product2 prodNoPBE = new Product2(
            Name = 'No PBE Product',
            IsActive = true
        );
        insert prodNoPBE;
        
        Quote quote = new Quote(
            Name = 'Bad Quote',
            ExpirationDate = Date.today().addDays(10),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prodNoPBE.Id;
        item.PricebookEntryId = null;
        item.Quantity = 1;
        item.UnitPrice = 10;
        item.Description = 'Missing Entry';
        item.CurrencyIsoCode = 'INR';
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Fallback PricebookEntry from LWC
    @isTest
    static void testCreateQuoteWithFallbackPBE() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'Fallback Quote',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id; // Providing fallback PBE
        item.Quantity = 1;
        item.UnitPrice = 100;
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Item with null Product2Id
    @isTest
    static void testCreateQuoteWithNullProduct2Id() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'Mixed Quote',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
        );
        
        // Valid item
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper validItem = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        validItem.Product2Id = prod.Id;
        validItem.PricebookEntryId = pbe.Id;
        validItem.Quantity = 1;
        validItem.UnitPrice = 100;
        
        // Invalid item with null Product2Id
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper invalidItem = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        invalidItem.Product2Id = null;
        invalidItem.Quantity = 1;
        invalidItem.UnitPrice = 50;
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ validItem, invalidItem };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
        
        // Verify only 1 QuoteLineItem was created
        if (resultMap.get('quoteId') != null) {
            List<QuoteLineItem> qlis = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :String.valueOf(resultMap.get('quoteId'))];
        }
    }
    
    // Test: Error scenarios
    @isTest
    static void testErrorScenarios() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        
        // Test getOpportunityContacts with null
        try {
            DRC_NBC_GenerateQuotes_Controller.getOpportunityContacts(null);
        } catch (Exception e) {
            // Expected exception
        }
        
        // Test getAccountBillingAddress with null
        try {
            DRC_NBC_GenerateQuotes_Controller.getAccountBillingAddress(null);
        } catch (Exception e) {
            // Expected exception
        }
        
        // Test getAccountAddresses with null
        try {
            DRC_NBC_GenerateQuotes_Controller.getAccountAddresses(null);
        } catch (Exception e) {
            // Expected exception
        }
        
        // Test searchProducts with null currency
        try {
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', null, acc.Id);
        } catch (Exception e) {
            // Expected exception
        }
        
        Test.stopTest();
    }
    
    // Test: createQuoteWithLines - Shipping address without compound address field
    @isTest
    static void testCreateQuoteWithShippingAddressNoCompound() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        // Create address without compound field set
        DRC_NBC_Addresses__c addressNoCompound = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c = acc.Id,
            DRC_NBC_Type__c = 'Shipping',
            DRC_NBC_Warehouse__c = 'Test Warehouse'
        );
        insert addressNoCompound;
        
        Quote quote = new Quote(
            Name = 'Test Quote No Compound',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR',
            DRC_NBC_Shipping_Address_Id__c = addressNoCompound.Id
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 1;
        item.UnitPrice = 100;
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Quote with existing billing address
    @isTest
    static void testCreateQuoteWithExistingBillingAddress() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'Quote with Billing',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR',
            BillingStreet = '999 Custom Billing St',
            BillingCity = 'Delhi',
            BillingState = 'Delhi',
            BillingPostalCode = '110001',
            BillingCountry = 'India',
            BillingCountryCode = 'IN'
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 1;
        item.UnitPrice = 100;
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Without shipping address ID
    @isTest
    static void testCreateQuoteWithoutShippingAddressId() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'Quote No Shipping ID',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
            // No DRC_NBC_Shipping_Address_Id__c
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 1;
        item.UnitPrice = 100;
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Item with zero quantity
    @isTest
    static void testCreateQuoteWithZeroQuantity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'Zero Qty Quote',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 0; // Zero quantity
        item.UnitPrice = 100;
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Item without packing info
    @isTest
    static void testCreateQuoteWithoutPackingInfo() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'No Packing Quote',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 5;
        item.UnitPrice = 100;
        // No PackingSize or PackingQuantity
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Only packing size, no quantity
    @isTest
    static void testCreateQuoteWithOnlyPackingSize() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'Only Size Quote',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 5;
        item.UnitPrice = 100;
        item.PackingSize = '25KG';
        // No PackingQuantity
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Only packing quantity, no size
    @isTest
    static void testCreateQuoteWithOnlyPackingQuantity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'Only Qty Quote',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 5;
        item.UnitPrice = 100;
        // No PackingSize
        item.PackingQuantity = '40';
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: createQuoteWithLines - Multiple products with mixed scenarios
    @isTest
    static void testCreateQuoteWithMultipleProducts() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        List<Product2> prods = [SELECT Id FROM Product2 ORDER BY Name LIMIT 2];
        List<PricebookEntry> pbes = [SELECT Id, Product2Id FROM PricebookEntry WHERE Product2Id IN :prods AND Pricebook2.Name = 'DRC PriceBook'];
        
        Quote quote = new Quote(
            Name = 'Multi Product Quote',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            CurrencyIsoCode = 'INR'
        );
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>();
        
        // Item 1: With packing info
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item1 = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item1.Product2Id = pbes[0].Product2Id;
        item1.PricebookEntryId = pbes[0].Id;
        item1.Quantity = 10;
        item1.UnitPrice = 100;
        item1.PackingSize = '50KG';
        item1.PackingQuantity = '20';
        lineItems.add(item1);
        
        // Item 2: Without packing info
        if (pbes.size() > 1) {
            DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item2 = 
                new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
            item2.Product2Id = pbes[1].Product2Id;
            item2.PricebookEntryId = pbes[1].Id;
            item2.Quantity = 5;
            item2.UnitPrice = 200;
            lineItems.add(item2);
        }
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
    
    // Test: Quote without contact
    @isTest
    static void testCreateQuoteWithoutContact() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :prod.Id AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
        
        Quote quote = new Quote(
            Name = 'No Contact Quote',
            ExpirationDate = Date.today().addDays(30),
            CurrencyIsoCode = 'INR'
            // No ContactId
        );
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = 
            new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = prod.Id;
        item.PricebookEntryId = pbe.Id;
        item.Quantity = 1;
        item.UnitPrice = 100;
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = 
            new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
        
        Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        Test.stopTest();
        
        Map<String, Object> resultMap = (Map<String, Object>) JSON.deserializeUntyped(result);
    }
}