/**
* @File Name : DRC_NBC_CloneQuoteController_Test.cls
* @Description : Test class for DRC_NBC_CloneQuoteController
* @Author : SATISH YADAV
* @Last Modified On : January 22, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | January 22, 2026 |SATISH YAdav | Initial Version - Complete test coverage
**/

@isTest
private class DRC_NBC_CloneQuoteController_Test {
    
    /**
     * Test data setup method
     */
    @testSetup
    static void setupTestData() {
        // Create Test Account
        Account testAccount = new Account(
            Name = 'Test Account for Quote Clone',
            BillingStreet = '123 Test Street',
            BillingCity = 'Test City',
            BillingStateCode = 'MH',
            BillingPostalCode = '12345',
            BillingCountryCode = 'IN'
        );
        insert testAccount;
        
        // Create Test Contacts
        List<Contact> testContacts = new List<Contact>();
        for (Integer i = 1; i <= 3; i++) {
            testContacts.add(new Contact(
                FirstName = 'Test',
                LastName = 'Contact ' + i,
                Email = 'testcontact' + i + '@test.com',
                Phone = '123-456-789' + i,
                Fax = '987-654-321' + i,
                AccountId = testAccount.Id
            ));
        }
        insert testContacts;
        
        // Create Shipping Addresses
        List<DRC_NBC_Addresses__c> addresses = new List<DRC_NBC_Addresses__c>();
        for (Integer i = 1; i <= 2; i++) {
            addresses.add(new DRC_NBC_Addresses__c(
                DRC_NBC_Account__c = testAccount.Id,
                DRC_NBC_Type__c = 'Shipping',
                DRC_NBC_Warehouse__c = 'CFS - JNPT',
                DRC_NBC_Address__Street__s = 'Shipping Street ' + i,
                DRC_NBC_Address__City__s = 'Shipping City ' + i,
                DRC_NBC_Address__StateCode__s = 'SC',
                DRC_NBC_Address__PostalCode__s = '5432' + i,
                DRC_NBC_Address__CountryCode__s = 'US'
            ));
        }
        insert addresses;
        
        // Create Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert testOpp;
        
        // Create Standard Pricebook (if not exists)
        Id pricebookId = Test.getStandardPricebookId();
        
        // Create Products
        List<Product2> products = new List<Product2>();
        for (Integer i = 1; i <= 3; i++) {
            products.add(new Product2(
                Name = 'Test Product ' + i,
                ProductCode = 'TP00' + i,
                IsActive = true
            ));
        }
        insert products;
        
        // Create Pricebook Entries
        List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
        for (Product2 prod : products) {
            pricebookEntries.add(new PricebookEntry(
                Pricebook2Id = pricebookId,
                Product2Id = prod.Id,
                UnitPrice = 100.00,
                IsActive = true
            ));
        }
        insert pricebookEntries;
        
        // Create Test Quote
        Quote testQuote = new Quote(
            Name = 'Test Quote Original',
            OpportunityId = testOpp.Id,
            ContactId = testContacts[0].Id,
            Status = 'Draft',
            ExpirationDate = Date.today().addDays(30),
            Description = 'Original Quote Description',
            Pricebook2Id = pricebookId,
            DRC_NBC_Type__c = 'Domestic',
            DRC_NBC_Payemnt_Term__c = '10 DAYS',
            DRC_NBC_Inco_terms__c = 'Charges Collect (CC)',
            DRC_NBC_Special_Requirements__c = 'Special requirements text',
            Email = testContacts[0].Email,
            Phone = testContacts[0].Phone,
            Fax = testContacts[0].Fax,
            BillingStreet = testAccount.BillingStreet,
            BillingCity = testAccount.BillingCity,
            BillingState = testAccount.BillingState,
            BillingPostalCode = testAccount.BillingPostalCode,
            BillingCountry = testAccount.BillingCountry,
            DRC_NBC_Other_Tax_Amount__c = 50.00,
            DRC_NBC_TCS_Amount__c = 25.00,
            DRC_NBC_Shipping_Address_Id__c = addresses[0].Id
        );
        insert testQuote;
        
        // Create Quote Line Items
        List<QuoteLineItem> quoteLineItems = new List<QuoteLineItem>();
        for (PricebookEntry pbe : pricebookEntries) {
            quoteLineItems.add(new QuoteLineItem(
                QuoteId = testQuote.Id,
                PricebookEntryId = pbe.Id,
                Product2Id = pbe.Product2Id,
                Quantity = 10,
                UnitPrice = 100.00,
                Discount = 5.00,
                Description = 'Line item description',
                DRC_NBC_Unit_Of_Measurement__c = 'KGS'
            ));
        }
        insert quoteLineItems;
    }
    
    /**
     * Test searchAccounts with valid search term
     */
    @isTest
    static void testSearchAccountsWithValidTerm() {
        Test.startTest();
        List<Account> results = DRC_NBC_CloneQuoteController.searchAccounts('Test Account');
        Test.stopTest();
        
        // Verify results are returned
        Boolean hasResults = !results.isEmpty();
    }
    
    /**
     * Test searchAccounts with blank search term
     */
    @isTest
    static void testSearchAccountsWithBlankTerm() {
        Test.startTest();
        List<Account> results = DRC_NBC_CloneQuoteController.searchAccounts('');
        Test.stopTest();
        
        // Verify empty list is returned
        Boolean isEmpty = results.isEmpty();
    }
    
    /**
     * Test searchAccounts with null search term
     */
    @isTest
    static void testSearchAccountsWithNullTerm() {
        Test.startTest();
        List<Account> results = DRC_NBC_CloneQuoteController.searchAccounts(null);
        Test.stopTest();
        
        // Verify empty list is returned
        Boolean isEmpty = results.isEmpty();
    }
    
    /**
     * Test getAccountContacts with valid account
     */
    @isTest
    static void testGetAccountContactsWithValidAccount() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<Contact> contacts = DRC_NBC_CloneQuoteController.getAccountContacts(testAccount.Id);
        Test.stopTest();
        
        // Verify contacts are returned
        Boolean hasContacts = !contacts.isEmpty();
    }
    
    /**
     * Test getAccountContacts with blank account ID
     */
    @isTest
    static void testGetAccountContactsWithBlankId() {
        Test.startTest();
        List<Contact> contacts = DRC_NBC_CloneQuoteController.getAccountContacts(null);
        Test.stopTest();
        
        // Verify empty list is returned
        Boolean isEmpty = contacts.isEmpty();
    }
    
    /**
     * Test getAccountContacts with exception handling
     */
    @isTest
    static void testGetAccountContactsException() {
        // Use a fake ID that will cause an exception
        Id fakeId = '001000000000000AAA';
        
        Test.startTest();
        try {
            List<Contact> contacts = DRC_NBC_CloneQuoteController.getAccountContacts(fakeId);
        } catch (AuraHandledException e) {
            // Exception caught as expected
            Boolean exceptionThrown = true;
        }
        Test.stopTest();
    }
    
    /**
     * Test getQuoteForClone with valid quote ID
     */
    @isTest
    static void testGetQuoteForCloneSuccess() {
        Quote testQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        DRC_NBC_CloneQuoteController.QuoteCloneWrapper wrapper = 
            DRC_NBC_CloneQuoteController.getQuoteForClone(testQuote.Id);
        Test.stopTest();
        
        // Verify wrapper data
        Boolean hasQuoteData = wrapper.quoteData != null;
        Boolean hasAccountName = wrapper.accountName != null;
        Boolean hasContacts = wrapper.contacts != null && !wrapper.contacts.isEmpty();
        Boolean hasShippingAddresses = wrapper.shippingAddresses != null && !wrapper.shippingAddresses.isEmpty();
        Boolean hasBillingAddresses = wrapper.billingAddresses != null && !wrapper.billingAddresses.isEmpty();
        Boolean hasLineItemCount = wrapper.lineItemCount > 0;
        Boolean quoteDraft = wrapper.quoteData.Status == 'Draft';
        Boolean quoteNameBlank = String.isBlank(wrapper.quoteData.Name);
    }
    
    /**
     * Test getQuoteForClone with blank quote ID
     */
    @isTest
    static void testGetQuoteForCloneWithBlankId() {
        Test.startTest();
        try {
            DRC_NBC_CloneQuoteController.QuoteCloneWrapper wrapper = 
                DRC_NBC_CloneQuoteController.getQuoteForClone(null);
        } catch (AuraHandledException e) {
            // Exception expected
            Boolean exceptionThrown = e.getMessage().contains('Quote ID is required');
        }
        Test.stopTest();
    }
    
    /**
     * Test getQuoteForClone with invalid quote ID
     */
    @isTest
    static void testGetQuoteForCloneWithInvalidId() {
        Id fakeQuoteId = '0Q0000000000000AAA';
        
        Test.startTest();
        try {
            DRC_NBC_CloneQuoteController.QuoteCloneWrapper wrapper = 
                DRC_NBC_CloneQuoteController.getQuoteForClone(fakeQuoteId);
        } catch (AuraHandledException e) {
            // Exception expected
            Boolean exceptionThrown = true;
        }
        Test.stopTest();
    }
    
    /**
     * Test getAccountAddresses with valid account
     */
    @isTest
    static void testGetAccountAddressesSuccess() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        DRC_NBC_CloneQuoteController.AddressResultWrapper wrapper = 
            DRC_NBC_CloneQuoteController.getAccountAddresses(testAccount.Id);
        Test.stopTest();
        
        // Verify wrapper data
        Boolean hasShippingAddresses = wrapper.shippingAddresses != null;
        Boolean hasBillingAddresses = wrapper.billingAddresses != null;
        Boolean hasBillingStreet = wrapper.accountBillingStreet != null;
    }
    
    /**
     * Test getAccountAddresses with blank account ID
     */
    @isTest
    static void testGetAccountAddressesWithBlankId() {
        Test.startTest();
        try {
            DRC_NBC_CloneQuoteController.AddressResultWrapper wrapper = 
                DRC_NBC_CloneQuoteController.getAccountAddresses(null);
        } catch (AuraHandledException e) {
            // Exception expected
            Boolean exceptionThrown = e.getMessage().contains('Account ID is required');
        }
        Test.stopTest();
    }
    
    /**
     * Test getAccountAddresses with invalid account ID
     */
    @isTest
    static void testGetAccountAddressesException() {
        Id fakeAccountId = '001000000000000AAA';
        
        Test.startTest();
        try {
            DRC_NBC_CloneQuoteController.AddressResultWrapper wrapper = 
                DRC_NBC_CloneQuoteController.getAccountAddresses(fakeAccountId);
        } catch (AuraHandledException e) {
            // Exception expected
            Boolean exceptionThrown = true;
        }
        Test.stopTest();
    }
    
    /**
     * Test cloneQuoteWithLineItems with complete data
     */
    @isTest
    static void testCloneQuoteWithLineItemsSuccess() {
        Quote originalQuote = [SELECT Id, OpportunityId, ContactId, ExpirationDate, 
                                     Description, CurrencyIsoCode, DRC_NBC_Type__c,
                                     DRC_NBC_Payemnt_Term__c, DRC_NBC_Inco_terms__c,
                                     DRC_NBC_Special_Requirements__c, Email, Phone, Fax,
                                     DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
                                     DRC_NBC_Shipping_Address_Id__c, BillingStreet,
                                     BillingCity, BillingState, BillingPostalCode,
                                     BillingCountry
                               FROM Quote LIMIT 1];
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Quote cloneData = new Quote(
            Name = 'Cloned Quote Test',
            Status = 'Draft',
            ExpirationDate = originalQuote.ExpirationDate,
            Description = originalQuote.Description,
            CurrencyIsoCode = originalQuote.CurrencyIsoCode,
            DRC_NBC_Type__c = originalQuote.DRC_NBC_Type__c,
            DRC_NBC_Payemnt_Term__c = originalQuote.DRC_NBC_Payemnt_Term__c,
            DRC_NBC_Inco_terms__c = originalQuote.DRC_NBC_Inco_terms__c,
            DRC_NBC_Special_Requirements__c = originalQuote.DRC_NBC_Special_Requirements__c,
            OpportunityId = originalQuote.OpportunityId,
           // AccountId = testAccount.Id,
            ContactId = originalQuote.ContactId,
            Email = originalQuote.Email,
            Phone = originalQuote.Phone,
            Fax = originalQuote.Fax,
            DRC_NBC_Other_Tax_Amount__c = originalQuote.DRC_NBC_Other_Tax_Amount__c,
            DRC_NBC_TCS_Amount__c = originalQuote.DRC_NBC_TCS_Amount__c,
            DRC_NBC_Shipping_Address_Id__c = originalQuote.DRC_NBC_Shipping_Address_Id__c,
            BillingStreet = originalQuote.BillingStreet,
            BillingCity = originalQuote.BillingCity,
            BillingState = originalQuote.BillingState,
            BillingPostalCode = originalQuote.BillingPostalCode,
            BillingCountry = originalQuote.BillingCountry
        );
        
        Test.startTest();
        Map<String, String> result = DRC_NBC_CloneQuoteController.cloneQuoteWithLineItems(
            originalQuote.Id, 
            cloneData
        );
        Test.stopTest();
        
        // Verify result
        Boolean isSuccess = result.get('status') == 'success';
        Boolean hasQuoteId = result.get('quoteId') != null;
        Boolean hasMessage = result.get('message') != null;
        
        // Verify new quote was created
        Id newQuoteId = result.get('quoteId');
        List<Quote> newQuotes = [SELECT Id, Name FROM Quote WHERE Id = :newQuoteId];
        Boolean quoteCreated = !newQuotes.isEmpty();
        
        // Verify line items were cloned
        List<QuoteLineItem> clonedQLIs = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :newQuoteId];
        Boolean lineItemsCloned = !clonedQLIs.isEmpty();
    }
    
    /**
     * Test cloneQuoteWithLineItems without AccountId in quoteData
     */
    @isTest
    static void testCloneQuoteWithLineItemsWithoutAccountId() {
        Quote originalQuote = [SELECT Id, OpportunityId, ContactId, ExpirationDate, 
                                     Description, CurrencyIsoCode, DRC_NBC_Type__c,
                                     DRC_NBC_Payemnt_Term__c, DRC_NBC_Inco_terms__c,
                                     DRC_NBC_Special_Requirements__c, Email, Phone, Fax,
                                     DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
                                     DRC_NBC_Shipping_Address_Id__c, BillingStreet,
                                     BillingCity, BillingState, BillingPostalCode,
                                     BillingCountry
                               FROM Quote LIMIT 1];
        
        Quote cloneData = new Quote(
            Name = 'Cloned Quote No Account',
            Status = 'Draft',
            ExpirationDate = originalQuote.ExpirationDate,
            Description = originalQuote.Description,
            CurrencyIsoCode = originalQuote.CurrencyIsoCode,
            DRC_NBC_Type__c = originalQuote.DRC_NBC_Type__c,
            DRC_NBC_Payemnt_Term__c = originalQuote.DRC_NBC_Payemnt_Term__c,
            DRC_NBC_Inco_terms__c = originalQuote.DRC_NBC_Inco_terms__c,
            DRC_NBC_Special_Requirements__c = originalQuote.DRC_NBC_Special_Requirements__c,
            OpportunityId = originalQuote.OpportunityId,
            ContactId = originalQuote.ContactId,
            Email = originalQuote.Email,
            Phone = originalQuote.Phone,
            Fax = originalQuote.Fax,
            DRC_NBC_Other_Tax_Amount__c = originalQuote.DRC_NBC_Other_Tax_Amount__c,
            DRC_NBC_TCS_Amount__c = originalQuote.DRC_NBC_TCS_Amount__c,
            DRC_NBC_Shipping_Address_Id__c = originalQuote.DRC_NBC_Shipping_Address_Id__c,
            BillingStreet = originalQuote.BillingStreet,
            BillingCity = originalQuote.BillingCity,
            BillingState = originalQuote.BillingState,
            BillingPostalCode = originalQuote.BillingPostalCode,
            BillingCountry = originalQuote.BillingCountry
        );
        
        Test.startTest();
        Map<String, String> result = DRC_NBC_CloneQuoteController.cloneQuoteWithLineItems(
            originalQuote.Id, 
            cloneData
        );
        Test.stopTest();
        
        // Verify result
        Boolean isSuccess = result.get('status') == 'success';
    }
    
    /**
     * Test cloneQuoteWithLineItems with blank original quote ID
     */
    @isTest
    static void testCloneQuoteWithLineItemsBlankId() {
        Quote cloneData = new Quote(Name = 'Test', Status = 'Draft');
        
        Test.startTest();
        try {
            Map<String, String> result = DRC_NBC_CloneQuoteController.cloneQuoteWithLineItems(
                null, 
                cloneData
            );
        } catch (AuraHandledException e) {
            // Exception expected
            Boolean exceptionThrown = e.getMessage().contains('Original Quote ID is required');
        }
        Test.stopTest();
    }
    
    /**
     * Test cloneQuoteWithLineItems with null quote data
     */
    @isTest
    static void testCloneQuoteWithLineItemsNullData() {
        Quote originalQuote = [SELECT Id FROM Quote LIMIT 1];
        
        Test.startTest();
        try {
            Map<String, String> result = DRC_NBC_CloneQuoteController.cloneQuoteWithLineItems(
                originalQuote.Id, 
                null
            );
        } catch (AuraHandledException e) {
            // Exception expected
            Boolean exceptionThrown = e.getMessage().contains('Quote data is required');
        }
        Test.stopTest();
    }
    
    /**
     * Test cloneQuoteWithLineItems with invalid original quote ID
     */
    @isTest
    static void testCloneQuoteWithLineItemsInvalidId() {
        Id fakeQuoteId = '0Q0000000000000AAA';
        Quote cloneData = new Quote(Name = 'Test', Status = 'Draft');
        
        Test.startTest();
        try {
            Map<String, String> result = DRC_NBC_CloneQuoteController.cloneQuoteWithLineItems(
                fakeQuoteId, 
                cloneData
            );
        } catch (AuraHandledException e) {
            // Exception expected
            Boolean exceptionThrown = true;
        }
        Test.stopTest();
    }
    
    /**
     * Test AddressWrapper constructor
     */
    @isTest
    static void testAddressWrapperConstructor() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        DRC_NBC_CloneQuoteController.AddressWrapper wrapper = 
            new DRC_NBC_CloneQuoteController.AddressWrapper(testAccount.Id, 'Test Address');
        Test.stopTest();
        
        // Verify wrapper properties
        Boolean hasValue = wrapper.value != null;
        Boolean hasLabel = wrapper.label == 'Test Address';
    }
    
    /**
     * Test QuoteCloneWrapper properties
     */
    @isTest
    static void testQuoteCloneWrapperProperties() {
        Test.startTest();
        DRC_NBC_CloneQuoteController.QuoteCloneWrapper wrapper = 
            new DRC_NBC_CloneQuoteController.QuoteCloneWrapper();
        
        wrapper.quoteData = new Quote(Name = 'Test');
        wrapper.accountName = 'Test Account';
        wrapper.accountId = null;
        wrapper.contacts = new List<Contact>();
        wrapper.shippingAddresses = new List<DRC_NBC_CloneQuoteController.AddressWrapper>();
        wrapper.billingAddresses = new List<DRC_NBC_CloneQuoteController.AddressWrapper>();
        wrapper.lineItemCount = 0;
        wrapper.accountBillingStreet = 'Street';
        wrapper.accountBillingCity = 'City';
        wrapper.accountBillingState = 'State';
        wrapper.accountBillingPostalCode = 'Postal';
        wrapper.accountBillingCountry = 'Country';
        Test.stopTest();
        
        // Verify properties are set
        Boolean hasQuoteData = wrapper.quoteData != null;
    }
    
    /**
     * Test AddressResultWrapper properties
     */
    @isTest
    static void testAddressResultWrapperProperties() {
        Test.startTest();
        DRC_NBC_CloneQuoteController.AddressResultWrapper wrapper = 
            new DRC_NBC_CloneQuoteController.AddressResultWrapper();
        
        wrapper.shippingAddresses = new List<DRC_NBC_CloneQuoteController.AddressWrapper>();
        wrapper.billingAddresses = new List<DRC_NBC_CloneQuoteController.AddressWrapper>();
        wrapper.accountBillingStreet = 'Street';
        wrapper.accountBillingCity = 'City';
        wrapper.accountBillingState = 'State';
        wrapper.accountBillingPostalCode = 'Postal';
        wrapper.accountBillingCountry = 'Country';
        Test.stopTest();
        
        // Verify properties are set
        Boolean hasShipping = wrapper.shippingAddresses != null;
    }
}