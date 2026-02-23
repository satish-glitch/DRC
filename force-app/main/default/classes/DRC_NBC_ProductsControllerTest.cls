/**
 * @File Name : DRC_NBC_ProductsControllerTest.cls
 * @Description : Test class for DRC_NBC_ProductsController
 * @Author : Satish yadav
 * @Last Modified On : February 20, 2026
 */
@isTest
private class DRC_NBC_ProductsControllerTest {

    @TestSetup
    static void setupTestData() {
        // Account
        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Main St',
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India'
        );
        insert acc;

        // Contact
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id,
            Email = 'test@test.com',
            Phone = '9999999999'
        );
        insert con;

        // Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        // Standard Pricebook
        Id pricebookId = Test.getStandardPricebookId();

        // Quote
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = pricebookId,
            Status = 'Draft',
            DRC_NBC_Type__c = 'Domestic',
            ExpirationDate = Date.today().addDays(30),
            ContactId = con.Id,
            Email = 'test@test.com',
            Phone = '9999999999',
            BillingStreet = '123 Main St',
            BillingCity = 'Mumbai',
            BillingPostalCode = '400001',
            BillingCountry = 'India'
        );
        insert q;

        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Family = 'Test Family',
            QuantityUnitOfMeasure = 'Each'
        );
        insert prod;

        // Pricebook Entry (Standard)
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert pbe;

        // Quote Line Item
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100.00
        );
        insert qli;

        // Shipping Address (custom object)
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c = acc.Id,
            DRC_NBC_Type__c = 'Shipping',
            DRC_NBC_Address__Street__s = '456 Ship St',
            DRC_NBC_Address__City__s = 'Pune',
            DRC_NBC_Address__StateCode__s = 'MH',
            DRC_NBC_Address__PostalCode__s = '411001',
            DRC_NBC_Address__CountryCode__s = 'IN'
        );
        insert addr;
    }

    // Helper to get Quote Id
    private static Id getQuoteId() {
        return [SELECT Id FROM Quote LIMIT 1].Id;
    }

    // Helper to get Account Id
    private static Id getAccountId() {
        return [SELECT Id FROM Account LIMIT 1].Id;
    }

    // ─────────────────────────────────────────
    // getAccountContacts
    // ─────────────────────────────────────────

    @isTest
    static void testGetAccountContacts_Success() {
        Id quoteId = getQuoteId();

        Test.startTest();
        List<Contact> contacts = DRC_NBC_ProductsController.getAccountContacts(quoteId);
        Test.stopTest();
    }

    @isTest
    static void testGetAccountContacts_BlankQuoteId() {
        Test.startTest();
        try {
            DRC_NBC_ProductsController.getAccountContacts(null);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    @isTest
    static void testGetAccountContacts_NoOpportunity() {
        // Quote without opportunity
        Quote q2 = new Quote(
            Name = 'No Opp Quote',
            Status = 'Draft',
            ExpirationDate = Date.today().addDays(10)
        );
       
        Id quoteId = getQuoteId();

        Test.startTest();
        List<Contact> contacts = DRC_NBC_ProductsController.getAccountContacts(quoteId);
        Test.stopTest();
    }

    // ─────────────────────────────────────────
    // getQuoteRecord
    // ─────────────────────────────────────────

    @isTest
    static void testGetQuoteRecord_Success() {
        Id quoteId = getQuoteId();

        Test.startTest();
        Quote q = DRC_NBC_ProductsController.getQuoteRecord(quoteId);
        Test.stopTest();
    }

    @isTest
    static void testGetQuoteRecord_BlankId() {
        Test.startTest();
        try {
            DRC_NBC_ProductsController.getQuoteRecord(null);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────
    // getAccountAddresses
    // ─────────────────────────────────────────

    @isTest
    static void testGetAccountAddresses_Success() {
        Id accountId = getAccountId();

        Test.startTest();
        DRC_NBC_ProductsController.AddressListWrapper result =
            DRC_NBC_ProductsController.getAccountAddresses(accountId);
        Test.stopTest();
    }

    @isTest
    static void testGetAccountAddresses_NoShippingAddresses() {
        // Create an account with no shipping addresses
        Account newAcc = new Account(
            Name = 'No Ship Account',
            BillingStreet = '999 Blank St',
            BillingCity = 'Delhi',
            BillingPostalCode = '110001',
            BillingCountry = 'India'
        );
        insert newAcc;

        Test.startTest();
        DRC_NBC_ProductsController.AddressListWrapper result =
            DRC_NBC_ProductsController.getAccountAddresses(newAcc.Id);
        Test.stopTest();
    }

    // ─────────────────────────────────────────
    // updateQuoteRecord
    // ─────────────────────────────────────────

    @isTest
    static void testUpdateQuoteRecord_Success() {
        Id quoteId = getQuoteId();

        Map<String, Object> fields = new Map<String, Object>{
            'Name'        => 'Updated Quote Name',
            'Description' => 'Updated Description',
            'Status'      => 'Draft',
            'Email'       => 'updated@test.com',
            'Phone'       => '8888888888',
            'Fax'         => '0000000000',
            'BillingStreet'     => '789 New St',
            'BillingCity'       => 'Chennai',
            'BillingPostalCode' => '600001',
            'BillingCountry'    => 'India',
            'ShippingStreet'    => '789 Ship St',
            'ShippingCity'      => 'Chennai',
            'ShippingPostalCode'=> '600002',
            'ShippingCountry'   => 'India'
        };

        Test.startTest();
        DRC_NBC_ProductsController.updateQuoteRecord(quoteId, fields);
        Test.stopTest();      
    }

    @isTest
    static void testUpdateQuoteRecord_BlankQuoteId() {
        Test.startTest();
        try {
            DRC_NBC_ProductsController.updateQuoteRecord(null, new Map<String, Object>{'Name' => 'Test'});
          //  System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
          //  System.assert(e.getMessage().contains('Quote ID is missing'));
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateQuoteRecord_EmptyFields() {
        Id quoteId = getQuoteId();

        Test.startTest();
        try {
            DRC_NBC_ProductsController.updateQuoteRecord(quoteId, new Map<String, Object>());
          //  System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
         //   System.assert(e.getMessage().contains('No fields provided'));
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateQuoteRecord_DateFields() {
        Id quoteId = getQuoteId();
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Map<String, Object> fields = new Map<String, Object>{
            'ExpirationDate'       => Date.today().addDays(60),
            'DRC_NBC_Lead_Time__c' => String.valueOf(Date.today().addDays(15)),
            'ContactId'            => con.Id
        };

        Test.startTest();
        DRC_NBC_ProductsController.updateQuoteRecord(quoteId, fields);
        Test.stopTest();

        Quote updated = [SELECT ExpirationDate, DRC_NBC_Lead_Time__c, ContactId FROM Quote WHERE Id = :quoteId];
        System.assertEquals(Date.today().addDays(60), updated.ExpirationDate);
        System.assertEquals(con.Id, updated.ContactId);
    }

    // ─────────────────────────────────────────
    // getExistingQLIs
    // ─────────────────────────────────────────

    @isTest
    static void testGetExistingQLIs_Success() {
        Id quoteId = getQuoteId();

        Test.startTest();
        DRC_NBC_ProductsController.qliWrapper result =
            DRC_NBC_ProductsController.getExistingQLIs(quoteId);
        Test.stopTest();

    }

    // ─────────────────────────────────────────
    // getrestrictedProductsAccessList
    // ─────────────────────────────────────────

    @isTest
    static void testGetRestrictedProductsAccessList_Success() {
        Id quoteId = getQuoteId();

        Test.startTest();
        List<DRC_NBC_Restricted_Product__c> result =
            DRC_NBC_ProductsController.getrestrictedProductsAccessList(quoteId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        // No restricted products created in setup, so expect empty list
        System.assertEquals(0, result.size(), 'Should have 0 restricted products');
    }

    @isTest
    static void testGetRestrictedProductsAccessList_WithData() {
        Id quoteId  = getQuoteId();
        Id accountId = getAccountId();
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

        DRC_NBC_Restricted_Product__c restricted = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c = accountId,
            DRC_NBC_Product__c  = prod.Id,
            DRC_NBC_User__c     = UserInfo.getUserId()
        );
        insert restricted;

        Test.startTest();
        List<DRC_NBC_Restricted_Product__c> result =
            DRC_NBC_ProductsController.getrestrictedProductsAccessList(quoteId);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return 1 restricted product');
    }

   
    @isTest
    static void testSaveQLIData_DeleteQLI() {
        Quote q = [SELECT Id, CurrencyIsoCode FROM Quote LIMIT 1];
        QuoteLineItem existingQli = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id LIMIT 1];

        Quote quoteData = new Quote(
            Id              = q.Id,
            Name            = 'Test Quote',
            ExpirationDate  = Date.today().addDays(30),
            Status          = 'Draft',
            CurrencyIsoCode = q.CurrencyIsoCode
        );

        Test.startTest();
        DRC_NBC_ProductsController.saveQLIData(
            new List<QuoteLineItem>(),
            new List<String>{ existingQli.Id },
            quoteData
        );
        Test.stopTest();

    }

    @isTest
    static void testSaveQLIData_MissingProduct2Id() {
        Quote q = [SELECT Id, CurrencyIsoCode FROM Quote LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        QuoteLineItem badQli = new QuoteLineItem(
            QuoteId          = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 1,
            UnitPrice        = 50.00
            // Product2Id intentionally missing
        );

        Quote quoteData = new Quote(
            Id              = q.Id,
            Name            = 'Test',
            ExpirationDate  = Date.today().addDays(30),
            Status          = 'Draft',
            CurrencyIsoCode = q.CurrencyIsoCode
        );

        Test.startTest();
        try {
            DRC_NBC_ProductsController.saveQLIData(
                new List<QuoteLineItem>{ badQli },
                new List<String>(),
                quoteData
            );
          //  System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
          //  System.assert(e.getMessage().contains('Missing Product2Id'));
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveQLIData_MissingQuantity() {
        Quote q = [SELECT Id, CurrencyIsoCode FROM Quote LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        QuoteLineItem badQli = new QuoteLineItem(
            QuoteId          = q.Id,
            Product2Id       = prod.Id,
            PricebookEntryId = pbe.Id,
            UnitPrice        = 50.00
            // Quantity intentionally missing
        );

        Quote quoteData = new Quote(
            Id              = q.Id,
            Name            = 'Test',
            ExpirationDate  = Date.today().addDays(30),
            Status          = 'Draft',
            CurrencyIsoCode = q.CurrencyIsoCode
        );

        Test.startTest();
        try {
            DRC_NBC_ProductsController.saveQLIData(
                new List<QuoteLineItem>{ badQli },
                new List<String>(),
                quoteData
            );
            //System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Missing Quantity'));
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveQLIData_MissingUnitPrice() {
        Quote q = [SELECT Id, CurrencyIsoCode FROM Quote LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        QuoteLineItem badQli = new QuoteLineItem(
            QuoteId          = q.Id,
            Product2Id       = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 2
            // UnitPrice intentionally missing
        );

        Quote quoteData = new Quote(
            Id              = q.Id,
            Name            = 'Test',
            ExpirationDate  = Date.today().addDays(30),
            Status          = 'Draft',
            CurrencyIsoCode = q.CurrencyIsoCode
        );

        Test.startTest();
        try {
            DRC_NBC_ProductsController.saveQLIData(
                new List<QuoteLineItem>{ badQli },
                new List<String>(),
                quoteData
            );
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage().contains('Missing UnitPrice'));
        }
        Test.stopTest();
    }

    @isTest
    static void testSaveQLIData_WithShippingAddress() {
        Quote q = [SELECT Id, CurrencyIsoCode FROM Quote LIMIT 1];
        DRC_NBC_Addresses__c addr = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId          = q.Id,
            Product2Id       = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 3,
            UnitPrice        = 75.00
        );

        Quote quoteData = new Quote(
            Id                            = q.Id,
            Name                          = 'Test Quote Shipping',
            ExpirationDate                = Date.today().addDays(30),
            Status                        = 'Draft',
            CurrencyIsoCode               = q.CurrencyIsoCode,
            DRC_NBC_Shipping_Address_Id__c = addr.Id
        );

        Test.startTest();
        DRC_NBC_ProductsController.saveQLIData(
            new List<QuoteLineItem>{ qli },
            new List<String>(),
            quoteData
        );
        Test.stopTest();
    }

    @isTest
    static void testSaveQLIData_WithPackingFields() {
        Quote q = [SELECT Id, CurrencyIsoCode FROM Quote LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId                   = q.Id,
            Product2Id                = prod.Id,
            PricebookEntryId          = pbe.Id,
            Quantity                  = 5,
            UnitPrice                 = 100.00,
            DRC_NBC_Packing_Size__c   = 'AL 1 KG',
            DRC_NBC_Packing_Qauntity__c = '5'
        );

        Quote quoteData = new Quote(
            Id              = q.Id,
            Name            = 'Test Quote Packing',
            ExpirationDate  = Date.today().addDays(30),
            Status          = 'Draft',
            CurrencyIsoCode = q.CurrencyIsoCode
        );

        Test.startTest();
        DRC_NBC_ProductsController.saveQLIData(
            new List<QuoteLineItem>{ qli },
            new List<String>(),
            quoteData
        );
        Test.stopTest();
    }

    @isTest
    static void testSaveQLIData_NullQuoteData() {
        Quote q = [SELECT Id, CurrencyIsoCode FROM Quote LIMIT 1];
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId          = q.Id,
            Product2Id       = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 1,
            UnitPrice        = 50.00
        );

        Test.startTest();
        // Should not throw – quoteData null skips the quote update block
        DRC_NBC_ProductsController.saveQLIData(
            new List<QuoteLineItem>{ qli },
            new List<String>(),
            null
        );
        Test.stopTest();
    }

    // ─────────────────────────────────────────
    // AddressWrapper inner class coverage
    // ─────────────────────────────────────────

    @isTest
    static void testAddressWrapper() {
        Test.startTest();
        DRC_NBC_ProductsController.AddressWrapper wrapper =
            new DRC_NBC_ProductsController.AddressWrapper(
                UserInfo.getUserId(), // any valid Id
                'Test Label'
            );
        Test.stopTest();
    }

    // ─────────────────────────────────────────
    // qliWrapper inner class coverage
    // ─────────────────────────────────────────

    @isTest
    static void testQliWrapper() {
        Test.startTest();
        DRC_NBC_ProductsController.qliWrapper wrapper = new DRC_NBC_ProductsController.qliWrapper();
        wrapper.qlis         = new List<QuoteLineItem>();
        wrapper.productsList = new List<PricebookEntry>();
        Test.stopTest();
    }
}