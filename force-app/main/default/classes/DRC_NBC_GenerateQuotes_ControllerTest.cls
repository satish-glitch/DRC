/**
* @File Name : DRC_NBC_GenerateQuotes_ControllerTest.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : November 16, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 16, 2025 |   | Initial Version
**/

@isTest
public class DRC_NBC_GenerateQuotes_ControllerTest {
    
    static testMethod void testCreateQuoteWithLines() {
        // Create Account
        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Test St',
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India',
            BillingCountryCode = 'IN' // Required due to country picklist
        );
        insert acc;
        
        // Create Contact
        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com',
            Phone = '1234567890',
            Fax = '1234567890',
            AccountId = acc.Id
        );
        insert con;
        
        // Create Pricebook
        Pricebook2 pb = new Pricebook2(
            Name = 'DRC PriceBook',
            IsActive = true,
            DRC_NBC_External_Id__c = 'DRC001'
        );
        insert pb;
        
        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            DRC_NBC_FG_Code__c = 'FG001',
            DRC_NBC_HSN_SAC_Code__c = 'HSN001',
            QuantityUnitOfMeasure = 'KGS'
        );
        insert prod;
        
        
        // Insert standard PricebookEntry using test method
        Id standardPBId = Test.getStandardPricebookId();
        PricebookEntry standardPBE = new PricebookEntry(
            Pricebook2Id = standardPBId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert standardPBE;
        
        // Now insert your custom Pricebook
        Pricebook2 pb1 = new Pricebook2(
            Name = 'DRC PriceBook',
            IsActive = true,
            DRC_NBC_External_Id__c = 'DRC001'
        );
        insert pb1;
        
        // Insert custom PricebookEntry
        PricebookEntry pbe1 = new PricebookEntry(
            Pricebook2Id = pb1.Id,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            UseStandardPrice = false,
            CurrencyIsoCode = 'INR'
        );
        insert pbe1;
        
        
        // Create PricebookEntry
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pb.Id,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true,
            UseStandardPrice = false,
            CurrencyIsoCode = 'INR'
        );
        insert pbe;
        
        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            CurrencyIsoCode = 'INR'
        );
        insert opp;
        
        // Create Custom Shipping Address
        DRC_NBC_Addresses__c address = new DRC_NBC_Addresses__c(
            // Name = 'Shipping Address',
            DRC_NBC_Account__c = acc.Id,
            DRC_NBC_Type__c = 'Shipping',
            DRC_NBC_Address__Street__s = '456 Ship Lane',
            DRC_NBC_Address__City__s = 'Mumbai',
            DRC_NBC_Address__PostalCode__s = '400002',
            DRC_NBC_Address__StateCode__s = 'MH',
            DRC_NBC_Address__CountryCode__s = 'IN'
        );
        insert address;
        
        // Call: getOpportunityContacts
        Test.startTest();
        List<Contact> contacts = DRC_NBC_GenerateQuotes_Controller.getOpportunityContacts(opp.Id);
        System.assert(!contacts.isEmpty(), 'Contacts should not be empty');
        
        // Call: getAccountBillingAddress
        DRC_NBC_GenerateQuotes_Controller.AccountAddressWrapper billing = 
            DRC_NBC_GenerateQuotes_Controller.getAccountBillingAddress(opp.Id);
        System.assertNotEquals(null, billing, 'Billing address should be returned');
        
        // Call: getAccountAddresses
        List<DRC_NBC_Addresses__c> shipping = 
            DRC_NBC_GenerateQuotes_Controller.getAccountAddresses(opp.Id);
        System.assert(!shipping.isEmpty(), 'Shipping addresses should not be empty');
        
        // Call: searchProducts
        List<DRC_NBC_GenerateQuotes_Controller.ProductWrapper> products =
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', 'INR');
        System.assertEquals(1, products.size(), 'Should return 1 product');
        
        // Prepare Quote and Line Items
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
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> lineItems = new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
            
            // Call: createQuoteWithLines
            String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, quote, lineItems);
        System.debug('Create Quote Result: ' + result);
        System.assert(result.contains('"success":true'), 'Quote creation should be successful');
        Test.stopTest();
    }
    
    // Negative scenario test
    static testMethod void testCreateQuoteWithMissingPricebookEntry() {
        Account acc = new Account(Name = 'No PB Account', BillingCountryCode = 'IN');
        insert acc;
        
        Opportunity opp = new Opportunity(Name = 'Missing PB Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(5), AccountId = acc.Id, CurrencyIsoCode = 'INR');
        insert opp;
        
        Quote q = new Quote(Name = 'Bad Quote', ExpirationDate = Date.today().addDays(10), CurrencyIsoCode = 'INR');
        
        DRC_NBC_GenerateQuotes_Controller.LineItemWrapper item = new DRC_NBC_GenerateQuotes_Controller.LineItemWrapper();
        item.Product2Id = '001000000000001'; // Invalid ID
        item.Quantity = 1;
        item.UnitPrice = 10;
        item.Description = 'Missing Entry';
        item.CurrencyIsoCode = 'INR';
        
        List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper> items = new List<DRC_NBC_GenerateQuotes_Controller.LineItemWrapper>{ item };
            
            Test.startTest();
        String result = DRC_NBC_GenerateQuotes_Controller.createQuoteWithLines(opp.Id, q, items);
        System.debug('Missing PBE result: ' + result);
        System.assert(result.contains('Missing PricebookEntries'), 'Should catch missing PBE');
        Test.stopTest();
    }
    
    static testMethod void testErrorScenarios() {
        Test.startTest();
        try {
            DRC_NBC_GenerateQuotes_Controller.getOpportunityContacts(null);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Error fetching contacts'));
        }
        
        try {
            DRC_NBC_GenerateQuotes_Controller.getAccountBillingAddress(null);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Error fetching billing address'));
        }
        
        try {
            DRC_NBC_GenerateQuotes_Controller.getAccountAddresses(null);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Error fetching addresses'));
        }
        
        try {
            DRC_NBC_GenerateQuotes_Controller.searchProducts('Test', null);
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Currency code is required'));
        }
        Test.stopTest();
    }
}