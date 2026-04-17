@isTest
private class DRC_NBC_ProductsControllerTest {
    
    @TestSetup
    static void setupTestData() {
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
        
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id,
            Email = 'test@test.com',
            Phone = '9999999999'
        );
        insert con;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        Id standardPricebookId = Test.getStandardPricebookId();
        
        Quote q = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = standardPricebookId,
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
        
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Family = 'Test Family',
            QuantityUnitOfMeasure = 'Each',
            Description = 'Test Product Description'
        );
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        insert pbe;
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = prod.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 5,
            UnitPrice = 100,
            DRC_NBC_Packing_Size__c = 'AL 1 KG',
            DRC_NBC_Packing_Qauntity__c = '5'
        );
        insert qli;
        
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
        
        // New setup required for updated controller
        List<DRC_NBC_Packing_Details__c> packingDetails = new List<DRC_NBC_Packing_Details__c>{
            new DRC_NBC_Packing_Details__c(
                Product__c = prod.Id,
                DRC_NBC_Packing_Size__c = 'AL 1 KG',
                DRC_NBC_Packing_Qauntity__c = '5'
            ),
                new DRC_NBC_Packing_Details__c(
                    Product__c = prod.Id,
                    DRC_NBC_Packing_Size__c = 'AL 5 KG',
                    DRC_NBC_Packing_Qauntity__c = '10'
                )
                };
                    insert packingDetails;
    }
    
    private static Id getQuoteId() {
        return [SELECT Id FROM Quote LIMIT 1].Id;
    }
    
    private static Id getAccountId() {
        return [SELECT Id FROM Account LIMIT 1].Id;
    }
    
    private static Id getProductId() {
        return [SELECT Id FROM Product2 LIMIT 1].Id;
    }
    
    private static Id getPricebookEntryId() {
        return [SELECT Id FROM PricebookEntry LIMIT 1].Id;
    }
    
    private static Id getShippingAddressId() {
        return [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1].Id;
    }
    
    @isTest
    static void testGetAccountContacts_Success() {
        Test.startTest();
        List<Contact> contacts = DRC_NBC_ProductsController.getAccountContacts(getQuoteId());
        Test.stopTest();
        
        System.assertEquals(1, contacts.size());
        System.assertEquals('test@test.com', contacts[0].Email);
    }
    
    @isTest
    static void testGetAccountContacts_BlankQuoteId() {
        Boolean isThrown = false;
        
        Test.startTest();
        try {
            DRC_NBC_ProductsController.getAccountContacts(null);
        } catch (AuraHandledException e) {
            isThrown = true;
            // System.assert(e.getMessage().contains('Quote ID is required.'));
        }
        Test.stopTest();
        
        System.assertEquals(true, isThrown);
    }
    
    @isTest
    static void testGetQuoteRecord_Success() {
        Test.startTest();
        Quote q = DRC_NBC_ProductsController.getQuoteRecord(getQuoteId());
        Test.stopTest();
        
        System.assertNotEquals(null, q);
        System.assertEquals('Draft', q.Status);
    }
    
    @isTest
    static void testGetQuoteRecord_BlankId() {
        Boolean isThrown = false;
        
        Test.startTest();
        try {
            DRC_NBC_ProductsController.getQuoteRecord(null);
        } catch (AuraHandledException e) {
            isThrown = true;
            //  System.assert(e.getMessage().contains('Quote ID is required.'));
        }
        Test.stopTest();
        
        System.assertEquals(true, isThrown);
    }
    
    @isTest
    static void testGetAccountAddresses_Success() {
        Test.startTest();
        DRC_NBC_ProductsController.AddressListWrapper result =
            DRC_NBC_ProductsController.getAccountAddresses(getAccountId());
        Test.stopTest();
        
        System.assertEquals(1, result.billingAddresses.size());
        System.assertEquals(1, result.shippingAddresses.size());
    }
    
    @isTest
    static void testGetAccountAddresses_NoShippingAddresses() {
        Account newAcc = new Account(
            Name = 'Test Account 2',
            DRC_NBC_Customer_Number__c = 'CUST67890',
            CurrencyIsoCode = 'USD',
            Phone = '9876543210',
            AccountNumber = 'A456',
            DRC_NBC_PAN_No__c = 'BNZPY1234K',
            DRC_NBC_GST_Number__c = '29BNZPY1234K1ZX',
            DRC_NBC_Payment_Term_Code__c = 'PDC90',
            DRC_NBC_Account_Email_Email__c = 'demo456@example.com',
            BillingStreet = '456 Park Avenue',
            BillingCity = 'Mumbai',
            BillingCountry = 'India',
            BillingCountryCode = 'IN',
            BillingPostalCode = '400001',
            BillingState = 'Karnataka',
            BillingStateCode = 'KA',
            DRC_NBC_Volume__c = 120,
            DRC_NBC_Credit_Limit__c = 987654321,
            DRC_NBC_Value__c = 1500,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1234567890123456',
            DRC_NBC_Consignee_Bank_Address__c = 'MG Road, Bengaluru',
            DRC_NBC_Consignee_Bank_IFSC_Code__c = 'SBIN0001234',
            DRC_NBC_Consignee_Bank_Name__c = 'State Bank of India',
            Industry = 'Chemicals Construction',
            Type = 'Analyst'
        );
        insert newAcc;
        
        Test.startTest();
        DRC_NBC_ProductsController.AddressListWrapper result =
            DRC_NBC_ProductsController.getAccountAddresses(newAcc.Id);
        Test.stopTest();
        
        System.assertEquals(1, result.billingAddresses.size());
        System.assertEquals(0, result.shippingAddresses.size());
    }
    
    @isTest
    static void testUpdateQuoteRecord_Success() {
        Map<String, Object> fields = new Map<String, Object>{
            'Name' => 'Updated Quote Name',
                'Description' => 'Updated Description',
                'Status' => 'Draft',
                'Email' => 'updated@test.com',
                'Phone' => '8888888888',
                'Fax' => '0000000000',
                'BillingStreet' => '789 New St',
                'BillingCity' => 'Chennai',
                'BillingPostalCode' => '600001',
                'BillingCountry' => 'India',
                'ShippingStreet' => '789 Ship St',
                'ShippingCity' => 'Chennai',
                'ShippingPostalCode' => '600002',
                'ShippingCountry' => 'India'
                };
                    
                    Test.startTest();
        DRC_NBC_ProductsController.updateQuoteRecord(getQuoteId(), fields);
        Test.stopTest();
        
        Quote updatedQuote = [
            SELECT Name, Description, Email, Phone, Fax, BillingCity, ShippingCity
            FROM Quote
            WHERE Id = :getQuoteId()
        ];
        
        System.assertEquals('Updated Quote Name', updatedQuote.Name);
        System.assertEquals('Updated Description', updatedQuote.Description);
        System.assertEquals('updated@test.com', updatedQuote.Email);
        System.assertEquals('Chennai', updatedQuote.BillingCity);
        System.assertEquals('Chennai', updatedQuote.ShippingCity);
    }
    
    @isTest
    static void testUpdateQuoteRecord_BlankQuoteId() {
        Boolean isThrown = false;
        
        Test.startTest();
        try {
            DRC_NBC_ProductsController.updateQuoteRecord(
                null,
                new Map<String, Object>{ 'Name' => 'Test' }
            );
        } catch (AuraHandledException e) {
            isThrown = true;
            // System.assert(e.getMessage().contains('Quote ID is missing.'));
        }
        Test.stopTest();
        
        System.assertEquals(true, isThrown);
    }
    
    @isTest
    static void testUpdateQuoteRecord_EmptyFields() {
        Boolean isThrown = false;
        
        Test.startTest();
        try {
            DRC_NBC_ProductsController.updateQuoteRecord(getQuoteId(), new Map<String, Object>());
        } catch (AuraHandledException e) {
            isThrown = true;
            // System.assert(e.getMessage().contains('No fields provided to update.'));
        }
        Test.stopTest();
        
        System.assertEquals(true, isThrown);
    }
    
    @isTest
    static void testUpdateQuoteRecord_DateFields() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];
        
        Map<String, Object> fields = new Map<String, Object>{
            'ExpirationDate' => Date.today().addDays(60),
                'DRC_NBC_Lead_Time__c' => String.valueOf(Date.today().addDays(15)),
                'ContactId' => con.Id
                };
                    
                    Test.startTest();
        DRC_NBC_ProductsController.updateQuoteRecord(getQuoteId(), fields);
        Test.stopTest();
        
        Quote updatedQuote = [
            SELECT ExpirationDate, DRC_NBC_Lead_Time__c, ContactId
            FROM Quote
            WHERE Id = :getQuoteId()
        ];
        
        System.assertEquals(Date.today().addDays(60), updatedQuote.ExpirationDate);
        System.assertEquals(Date.today().addDays(15), updatedQuote.DRC_NBC_Lead_Time__c);
        System.assertEquals(con.Id, updatedQuote.ContactId);
    }
    
    
    @isTest
    static void testGetRestrictedProductsAccessList_NoData() {
        Test.startTest();
        List<DRC_NBC_Restricted_Product__c> result =
            DRC_NBC_ProductsController.getrestrictedProductsAccessList(getQuoteId());
        Test.stopTest();
    }
    
    @isTest
    static void testGetRestrictedProductsAccessList_WithData() {
        DRC_NBC_Restricted_Product__c restricted = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c = getAccountId(),
            DRC_NBC_Product__c = getProductId(),
            DRC_NBC_User__c = UserInfo.getUserId()
        );
        insert restricted;
        
        Test.startTest();
        List<DRC_NBC_Restricted_Product__c> result =
            DRC_NBC_ProductsController.getrestrictedProductsAccessList(getQuoteId());
        Test.stopTest();
    }
    
    @isTest
    static void testSaveQLIData_DeleteQLI() {
        Quote q = [SELECT Id, CurrencyIsoCode FROM Quote LIMIT 1];
        QuoteLineItem existingQli = [SELECT Id FROM QuoteLineItem WHERE QuoteId = :q.Id LIMIT 1];
        
        Quote quoteData = new Quote(
            Id = q.Id,
            Name = 'Test Quote',
            ExpirationDate = Date.today().addDays(30),
            Status = 'Draft',
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
    static void testSaveQLIData_WithShippingAddressAndPacking() {
        Quote q = [SELECT Id, CurrencyIsoCode FROM Quote LIMIT 1];
        Id productId = getProductId();
        Id pbeId = getPricebookEntryId();
        Id shippingAddressId = getShippingAddressId();
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = productId,
            PricebookEntryId = pbeId,
            Quantity = 3,
            UnitPrice = 75,
            DRC_NBC_Packing_Size__c = 'AL 5 KG',
            DRC_NBC_Packing_Qauntity__c = '10'
        );
        
        Quote quoteData = new Quote(
            Id = q.Id,
            Name = 'Test Quote Shipping',
            ExpirationDate = Date.today().addDays(30),
            Status = 'Draft',
            CurrencyIsoCode = q.CurrencyIsoCode,
            DRC_NBC_Shipping_Address_Id__c = shippingAddressId
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
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = getProductId(),
            PricebookEntryId = getPricebookEntryId(),
            Quantity = 5,
            UnitPrice = 100,
            DRC_NBC_Packing_Size__c = 'AL 1 KG',
            DRC_NBC_Packing_Qauntity__c = '5'
        );
        
        Quote quoteData = new Quote(
            Id = q.Id,
            Name = 'Test Quote Packing',
            ExpirationDate = Date.today().addDays(30),
            Status = 'Draft',
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
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            Product2Id = getProductId(),
            PricebookEntryId = getPricebookEntryId(),
            Quantity = 1,
            UnitPrice = 50
        );
        
        Test.startTest();
        DRC_NBC_ProductsController.saveQLIData(
            new List<QuoteLineItem>{ qli },
            new List<String>(),
            null
        );
        Test.stopTest();
    }
    
    // saveQLIData catches Exception and does not rethrow,
    // so this test only validates that invalid input is handled without failing the test.
    @isTest
    static void testSaveQLIData_InvalidInputHandledInternally() {
        Quote q = [SELECT Id, CurrencyIsoCode FROM Quote LIMIT 1];
        
        Integer beforeCount = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :q.Id];
        
        QuoteLineItem badQli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = getPricebookEntryId(),
            Quantity = 1,
            UnitPrice = 50
        );
        
        Quote quoteData = new Quote(
            Id = q.Id,
            Name = 'Test',
            ExpirationDate = Date.today().addDays(30),
            Status = 'Draft',
            CurrencyIsoCode = q.CurrencyIsoCode
        );
        
        Test.startTest();
        DRC_NBC_ProductsController.saveQLIData(
            new List<QuoteLineItem>{ badQli },
            new List<String>(),
            quoteData
        );
        Test.stopTest();
        
        Integer afterCount = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :q.Id];
        System.assertEquals(beforeCount, afterCount);
    }
    
    @isTest
    static void testAddressWrapper() {
        Test.startTest();
        DRC_NBC_ProductsController.AddressWrapper wrapper =
            new DRC_NBC_ProductsController.AddressWrapper(UserInfo.getUserId(), 'Test Label');
        Test.stopTest();
    }
    
    @isTest
    static void testQliWrapper() {
        Test.startTest();
        DRC_NBC_ProductsController.qliWrapper wrapper =
            new DRC_NBC_ProductsController.qliWrapper();
        wrapper.qlis = new List<QuoteLineItem>();
        wrapper.productsList = new List<PricebookEntry>();
        wrapper.packingDetailsMap =
            new Map<Id, List<DRC_NBC_ProductsController.PackingDetailWrapper>>();
        Test.stopTest();
    }
    
    @isTest
    static void testGetExistingQLIs_BaseCoverage() {
        Id quoteId = getQuoteId();
        Id productId = getProductId();
        
        Test.startTest();
        DRC_NBC_ProductsController.qliWrapper result =
            DRC_NBC_ProductsController.getExistingQLIs(quoteId);
        Test.stopTest();
    }
  
    @isTest
    static void testGetExistingQLIs_WithRestrictedProducts_CoversRestrictedBranch() {
        Id quoteId = getQuoteId();
        Id accountId = getAccountId();
        Id productId = getProductId();
        
        insert new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c = accountId,
            DRC_NBC_Product__c = productId,
            DRC_NBC_User__c = UserInfo.getUserId()
        );
        
        Test.startTest();
        DRC_NBC_ProductsController.qliWrapper result =
            DRC_NBC_ProductsController.getExistingQLIs(quoteId);
        Test.stopTest();
    }
}