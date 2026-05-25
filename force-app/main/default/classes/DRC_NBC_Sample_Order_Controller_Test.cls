@isTest
private class DRC_NBC_Sample_Order_Controller_Test {
    
    // ─── Test Data Setup ──────────────────────────────────────────────────────
    
    @testSetup
    static void setupTestData() {
        // Account
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
        
        // Contact with email
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Contact',
            Email     = 'test.contact@example.com',
            AccountId = acc.Id
        );
        insert con;
        
        // Contact without email
        Contact conNoEmail = new Contact(
            FirstName = 'No',
            LastName  = 'Email',
            AccountId = acc.Id
        );
        insert conNoEmail;
        
        // DRC PriceBook
        Pricebook2 drcPb = new Pricebook2(
            Name                   = 'DRC PriceBook',
            IsActive               = true,
            DRC_NBC_External_Id__c = 'DRC001'
        );
        insert drcPb;
        
        // Product
        Product2 prod = new Product2(
            Name                        = 'Test Product Alpha',
            IsActive                    = true,
            DRC_NBC_FG_Code__c          = 'FG001',
            DRC_NBC_HSN_SAC_Code__c     = 'HSN001',
            QuantityUnitOfMeasure       = 'KG',
            DRC_NBC_Packing_Size__c     = 'AL 1 KG'
        );
        insert prod;
        
        // Standard PricebookEntry
        Id stdPbId = Test.getStandardPricebookId();
        PricebookEntry stdPbe = new PricebookEntry(
            Pricebook2Id = stdPbId,
            Product2Id   = prod.Id,
            UnitPrice    = 100,
            IsActive     = true
        );
        insert stdPbe;
        
        // DRC PricebookEntry
        PricebookEntry drcPbe = new PricebookEntry(
            Pricebook2Id    = drcPb.Id,
            Product2Id      = prod.Id,
            UnitPrice       = 150,
            IsActive        = true,
            CurrencyIsoCode = 'INR'
        );
        insert drcPbe;
        
        // Opportunity linked to DRC pricebook
        Opportunity opp = new Opportunity(
            Name            = 'Test Opportunity',
            AccountId       = acc.Id,
            StageName       = 'Prospecting',
            CloseDate       = Date.today().addDays(30),
            Pricebook2Id    = drcPb.Id,
            CurrencyIsoCode = 'INR'
        );
        insert opp;
        
        // Shipping Address
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c           = acc.Id,
            DRC_NBC_Type__c              = 'Shipping',
            DRC_NBC_Address__Street__s   = 'Ship Street',
            DRC_NBC_Address__City__s     = 'Mumbai',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__PostalCode__s  = '400002',
            DRC_NBC_Address__CountryCode__s = 'IN'
        );
        insert addr;
    }
    
    // ─── Helpers ──────────────────────────────────────────────────────────────
    
    private static Opportunity getOpp() {
        return [SELECT Id, AccountId, Pricebook2Id, CurrencyIsoCode FROM Opportunity LIMIT 1];
    }
    
    private static Account getAccount() {
        return [SELECT Id FROM Account LIMIT 1];
    }
    
    private static Product2 getProduct() {
        return [SELECT Id FROM Product2 LIMIT 1];
    }
    
    private static PricebookEntry getDrcPbe() {
        Pricebook2 drcPb = [SELECT Id FROM Pricebook2 WHERE Name = 'DRC PriceBook' LIMIT 1];
        return [SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2Id = :drcPb.Id LIMIT 1];
    }
    
    private static DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper buildOrderItemWrapper(
        Id product2Id, Id pbeId, Decimal qty, Decimal price
    ) {
        DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper w =
            new DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper();
        w.Product2Id            = product2Id;
        w.PriceBookEntryId      = pbeId;
        w.Quantity              = qty;
        w.UnitPrice             = price;
        w.Description           = 'Test description';
        w.CurrencyIsoCode       = 'INR';
        w.QuantityUnitOfMeasure = 'KG';
        w.PackingSize           = '10 KG';
        w.PackingQuantity       = 5;
        return w;
    }
    
    private static Order buildOrderObj(Id accountId, Id contactId, Date effectiveDate) {
        Order ord = new Order(
            AccountId       = accountId,
            Status          = 'Draft',
            EffectiveDate   = effectiveDate != null ? effectiveDate : Date.today(),
            BillToContactId = contactId,
            ShipToContactId = contactId,
            CurrencyIsoCode = 'INR'
        );
        return ord;
    }
    
    // ─── getOrderRecordTypes ──────────────────────────────────────────────────
    
    @isTest
    static void test_getOrderRecordTypes() {
        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_Generate_Sample_Order_Controller.getOrderRecordTypes();
        Test.stopTest();
    }
    
    // ─── getOpportunityContacts ───────────────────────────────────────────────
    
    @isTest
    static void test_getOpportunityContacts_Success() {
        Opportunity opp = getOpp();
        
        Test.startTest();
        List<Contact> contacts =
            DRC_NBC_Generate_Sample_Order_Controller.getOpportunityContacts(opp.Id);
        Test.stopTest();
    }
    
    // ─── getAccountPaymentTerms ───────────────────────────────────────────────
    
    // ─── getAccountPaymentInfo ────────────────────────────────────────────────
    
    @isTest
    static void test_getAccountPaymentInfo() {
        Opportunity opp = getOpp();
        
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.AccountPaymentInfoWrapper result =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountPaymentInfo(opp.Id);
        Test.stopTest();
    }
    
    // ─── getOpportunityCurrency ───────────────────────────────────────────────
    
    @isTest
    static void test_getOpportunityCurrency() {
        Opportunity opp = getOpp();
        
        Test.startTest();
        String currencies = DRC_NBC_Generate_Sample_Order_Controller.getOpportunityCurrency(opp.Id);
        Test.stopTest();
    }
    
    // ─── getAllProducts ───────────────────────────────────────────────────────
    
    @isTest
    static void test_getAllProducts() {
        Opportunity opp = getOpp();
        
        Test.startTest();
        // getAllProducts now returns ProductSearchResult, not List<ProductWrapper>
        DRC_NBC_Generate_Sample_Order_Controller.ProductSearchResult result =
            DRC_NBC_Generate_Sample_Order_Controller.getAllProducts(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.products, 'Products list should not be null');
    }
    
    // ─── ProductWrapper constructor ───────────────────────────────────────────
    
    @isTest
    static void test_ProductWrapper_Constructor() {
        PricebookEntry pbe = getDrcPbe();
        
        Test.startTest();
        // ProductWrapper constructor now takes 7 args (PackingSize removed)
        DRC_NBC_Generate_Sample_Order_Controller.ProductWrapper pw =
            new DRC_NBC_Generate_Sample_Order_Controller.ProductWrapper(
                pbe.Id, pbe.Product2Id, 'Test Product', 'FG001', 'HSN001', 200, 'KG'
            );
        Test.stopTest();
        
        System.assertEquals('Test Product', pw.Name);
        System.assertEquals('FG001', pw.FGCode);
    }
    
    
    @isTest
    static void test_searchProducts_WithRestrictions() {
        Opportunity opp  = getOpp();
        Account     acc  = getAccount();
        Product2    prod = getProduct();
        
        // Create a product restriction for this account
        DRC_NBC_Restricted_Product__c restriction = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c = acc.Id,
            DRC_NBC_Product__c  = prod.Id
        );
        insert restriction;
        
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.ProductSearchResult result =
            DRC_NBC_Generate_Sample_Order_Controller.searchProducts('Alpha', 'INR', opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    
    
    
    // ─── getAccountBillingAddress ─────────────────────────────────────────────
    
    @isTest
    static void test_getAccountBillingAddress_Success() {
        Opportunity opp = getOpp();
        
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.AccountAddressWrapper wrapper =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBillingAddress(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assertEquals('123 Street', wrapper.street);
        System.assertEquals('City', wrapper.city);
    }
    
    @isTest
    static void test_getAccountBillingAddress_InvalidOppId() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBillingAddress('006000000000001AAA');
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }
    
    // ─── AccountAddressWrapper ────────────────────────────────────────────────
    
    @isTest
    static void test_AccountAddressWrapper_Constructor() {
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.AccountAddressWrapper w =
            new DRC_NBC_Generate_Sample_Order_Controller.AccountAddressWrapper(
                'Street', 'City', 'State', '12345', 'Country', 'CC'
            );
        Test.stopTest();
        
        System.assertEquals('Street', w.street);
        System.assertEquals('City', w.city);
        System.assertEquals('12345', w.postalCode);
    }
    
    // ─── getAccountAddresses ──────────────────────────────────────────────────
    
    @isTest
    static void test_getAccountAddresses() {
        Opportunity opp = getOpp();
        
        Test.startTest();
        List<DRC_NBC_Addresses__c> addresses =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountAddresses(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, addresses);
        System.assertEquals(1, addresses.size(), 'Should return the one shipping address');
    }
    
    // ─── getAccountBankDetails ────────────────────────────────────────────────
    
    @isTest
    static void test_getAccountBankDetails_Success() {
        Opportunity opp = getOpp();
        
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.AccountBankDetailsWrapper wrapper =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBankDetails(opp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, wrapper);
        System.assertEquals('Punjab National bank', wrapper.bankName);
        System.assertEquals('PUNB01391000', wrapper.ifscCode);
    }
    
    @isTest
    static void test_AccountBankDetailsWrapper_Constructor() {
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.AccountBankDetailsWrapper w =
            new DRC_NBC_Generate_Sample_Order_Controller.AccountBankDetailsWrapper(
                'MyBank', 'ACC001', 'MYBN0001234', '1 Bank Road', 'Ajit Phadke'
            );
        Test.stopTest();
        
        
    }
    
    // ─── createSampleOrder ────────────────────────────────────────────────────
    
    /**
* Covers: Happy path → order and order items created successfully
*/
    @isTest
    static void test_createSampleOrder_Success() {
        Opportunity    opp = getOpp();
        Account        acc = getAccount();
        PricebookEntry pbe = getDrcPbe();
        Contact        con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        
        Order ord = buildOrderObj(acc.Id, con.Id, Date.today());
        
        DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper item =
            buildOrderItemWrapper(pbe.Product2Id, pbe.Id, 5, 150);
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{ item },
            opp.Id
        );
        Test.stopTest();
        
    }
    
    /**
* Covers: No order items → returns error without inserting
*/
    @isTest
    static void test_createSampleOrder_NoItems() {
        Opportunity opp = getOpp();
        Account     acc = getAccount();
        Contact     con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        
        Order ord = buildOrderObj(acc.Id, con.Id, Date.today());
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>(),
            opp.Id
        );
        Test.stopTest();
        
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(false, parsed.get('success'), 'Should fail with no items');
        System.assert(((String) parsed.get('error')).contains('No products selected'),
                      'Error should mention no products');
    }
    
    /**
* Covers: Null order items list → returns error
*/
    @isTest
    static void test_createSampleOrder_NullItems() {
        Opportunity opp = getOpp();
        Account     acc = getAccount();
        Contact     con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        
        Order ord = buildOrderObj(acc.Id, con.Id, Date.today());
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord, null, opp.Id
        );
        Test.stopTest();
        
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(false, parsed.get('success'), 'Should fail with null items');
    }
    
    /**
* Covers: Contact without email → returns error with contact name
*/
    @isTest
    static void test_createSampleOrder_ContactWithNoEmail() {
        Opportunity    opp        = getOpp();
        Account        acc        = getAccount();
        PricebookEntry pbe        = getDrcPbe();
        Contact        conNoEmail = [SELECT Id, Name FROM Contact WHERE Email = null LIMIT 1];
        
        Order ord = buildOrderObj(acc.Id, conNoEmail.Id, Date.today());
        
        DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper item =
            buildOrderItemWrapper(pbe.Product2Id, pbe.Id, 2, 100);
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{ item },
            opp.Id
        );
        Test.stopTest();
        
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(false, parsed.get('success'), 'Should fail due to missing contact email');
        System.assert(((String) parsed.get('error')).containsIgnoreCase('email'),
                      'Error should mention email');
    }
    
    /**
* Covers: OrderItem with null Product2Id → item is skipped
* → no valid items → rollback and error
*/
    @isTest
    static void test_createSampleOrder_NullProduct2Id() {
        Opportunity opp = getOpp();
        Account     acc = getAccount();
        Contact     con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        
        Order ord = buildOrderObj(acc.Id, con.Id, Date.today());
        
        DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper item =
            new DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper();
        item.Product2Id = null;
        item.Quantity   = 1;
        item.UnitPrice  = 100;
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{ item },
            opp.Id
        );
        Test.stopTest();
        
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assertEquals(false, parsed.get('success'), 'Should fail when all Product2Ids are null');
    }
    
    /**
* Covers: Product not in pricebook → missingPricebookProducts → rollback
*/
    @isTest
    static void test_createSampleOrder_MissingPricebookEntry() {
        Opportunity opp = getOpp();
        Account     acc = getAccount();
        Contact     con = [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
        
        // Product with no DRC PricebookEntry
        Product2 newProd = new Product2(Name = 'Orphan Product', IsActive = true);
        insert newProd;
        
        Order ord = buildOrderObj(acc.Id, con.Id, Date.today());
        
        DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper item =
            buildOrderItemWrapper(newProd.Id, null, 1, 50);
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{ item },
            opp.Id
        );
        Test.stopTest();
    }
}