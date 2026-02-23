@isTest
public class DRC_NBC_Generate_Order_ControllerTest {

    // ─── @testSetup: Create all shared data once ──────────────────────────────
    @testSetup
    static void setupTestData() {
        // Account with billing address
        Account acc = new Account(
            Name               = 'Test Account',
            BillingStreet      = '123 Main St',
            BillingCity        = 'Mumbai',
            BillingState       = 'Maharashtra',
            BillingPostalCode  = '400001',
            BillingCountry     = 'India',
            BillingCountryCode = 'IN',
            DRC_NBC_Consignee_Bank_Name__c           = 'Test Bank',
            DRC_NBC_Consignee_Bank_Account_Number__c = '1234567890',
            DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'TEST0001234',
            DRC_NBC_Consignee_Bank_Address__c        = 'Bank Street, Mumbai'
        );
        insert acc;

        // Contacts (with emails so createOrder validation passes)
        Contact billTo = new Contact(
            FirstName   = 'Bill',
            LastName    = 'To',
            AccountId   = acc.Id,
            Email       = 'billto@test.com'
        );
        Contact shipTo = new Contact(
            FirstName   = 'Ship',
            LastName    = 'To',
            AccountId   = acc.Id,
            Email       = 'shipto@test.com'
        );
        insert new List<Contact>{ billTo, shipTo };

        // Opportunity
        Opportunity opp = new Opportunity(
            Name        = 'Test Opp',
            AccountId   = acc.Id,
            StageName   = 'Prospecting',
            CloseDate   = Date.today().addDays(30),
            CurrencyIsoCode = 'USD'
        );
        insert opp;

        // Pricebook
        Id standardPbId = Test.getStandardPricebookId();

        // Product
        Product2 prod = new Product2(
            Name                    = 'Test Product',
            IsActive                = true,
            Family                  = 'Test',
            QuantityUnitOfMeasure   = 'Each',
            DRC_NBC_FG_Code__c      = 'FG001',
            DRC_NBC_HSN_SAC_Code__c = 'HSN001'
        );
        insert prod;

        // Standard PricebookEntry
        PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id    = standardPbId,
            Product2Id      = prod.Id,
            UnitPrice       = 100,
            IsActive        = true,
            CurrencyIsoCode = 'USD'
        );
        insert standardPbe;

        // Quote
        Quote quote = new Quote(
            Name                    = 'Test Quote',
            OpportunityId           = opp.Id,
            DRC_NBC_Type__c         = 'Domestic',
            DRC_NBC_Payemnt_Term__c = '100',
            DRC_NBC_Inco_terms__c   = 'Charges Collect (CC)',
            DRC_NBC_TCS_Amount__c   = 100,
            DRC_NBC_Other_Tax_Amount__c = 50,
            Pricebook2Id            = standardPbId,
            Status                  = 'Draft'
        );
        insert quote;

        // QuoteLineItem
        QuoteLineItem qli = new QuoteLineItem(
            QuoteId             = quote.Id,
            Product2Id          = prod.Id,
            PricebookEntryId    = standardPbe.Id,
            Quantity            = 5,
            UnitPrice           = 100,
            Description         = 'Test QLI',
            DRC_NBC_Packing_Size__c     = 'AL 1 KG',
            DRC_NBC_Packing_Qauntity__c = '2'
        );
        insert qli;

        // Shipping Address
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c              = acc.Id,
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Address__Street__s      = '456 Ship St',
            DRC_NBC_Address__City__s        = 'Pune',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__PostalCode__s  = '411001',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Warehouse__c            = 'CFS - JNPT'
        );
        insert addr;
    }

    // ─── Utility: build a test Order object ───────────────────────────────────
    private static Order buildTestOrder(
        Id accountId, Id pricebookId, Id billToId, Id shipToId,
        Id opportunityId, Id shippingAddrId
    ) {
        Order ord = new Order(
            AccountId               = accountId,
            EffectiveDate           = Date.today(),
            Status                  = 'Draft',
            CurrencyIsoCode         = 'USD',
            Pricebook2Id            = pricebookId,
            Type                    = 'Domestic',
            BillToContactId         = billToId,
            ShipToContactId         = shipToId,
            DRC_NBC_Type__c         = 'Domestic',
            DRC_NBC_Shipping_Address__c = shippingAddrId
        );
        return ord;
    }

    // ─── Utility: build DRC_NBC_OrderItemWrapper ──────────────────────────────
    private static DRC_NBC_OrderItemWrapper buildOrderItemWrapper(
        Id product2Id, Id pbeId, Decimal qty, Decimal price
    ) {
        DRC_NBC_OrderItemWrapper w = new DRC_NBC_OrderItemWrapper();
        w.Product2Id        = product2Id;
        w.PriceBookEntryId  = pbeId;
        w.Quantity          = qty;
        w.UnitPrice         = price;
        w.Description       = 'Test Item';
        w.UOM               = 'Each';
        w.DRC_NBC_Packing_Size     = 'AL 1 KG';
        w.DRC_NBC_Packing_Quantity = '2';
        return w;
    }

    // ─── getOrderRecordTypes ──────────────────────────────────────────────────

    @isTest
    static void testGetOrderRecordTypes() {
        Test.startTest();
        List<DRC_NBC_Generate_Order_Controller.OptionsWrapper> result =
            DRC_NBC_Generate_Order_Controller.getOrderRecordTypes();
        Test.stopTest();
        // Master record type is excluded; result may be empty in test orgs with only Master
        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // ─── getOrderTypes ────────────────────────────────────────────────────────

    @isTest
    static void testGetOrderTypes() {
        Test.startTest();
        List<DRC_NBC_Generate_Order_Controller.OptionsWrapper> result =
            DRC_NBC_Generate_Order_Controller.getOrderTypes();
        Test.stopTest();
        System.assertNotEquals(null, result, 'Order types should not be null');
        System.assert(!result.isEmpty(), 'Order types picklist should have values');
    }

    // ─── getDefaultValues ─────────────────────────────────────────────────────

    @isTest
    static void testGetDefaultValues() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        DRC_NBC_Generate_Order_Controller.OrderDefaults defaults =
            DRC_NBC_Generate_Order_Controller.getDefaultValues(quote.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetDefaultValuesInvalidQuote() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Order_Controller.getDefaultValues('invalidId000000');
            System.assert(false, 'Exception expected for invalid quote ID');
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage(), 'Exception message should exist');
        }
        Test.stopTest();
    }

    // ─── makeOrderWrapper / getRelatedQLIS ────────────────────────────────────

    @isTest
    static void testMakeOrderWrapper() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        List<DRC_NBC_OrderItemWrapper> items =
            DRC_NBC_Generate_Order_Controller.makeOrderWrapper(quote.Id);
        Test.stopTest();
    }

    @isTest
    static void testMakeOrderWrapperNoQLIs() {
        // Quote with no line items
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Id standardPbId = Test.getStandardPricebookId();
        Quote emptyQuote = new Quote(
            Name          = 'Empty Quote',
            OpportunityId = opp.Id,
            Status        = 'Draft',
            Pricebook2Id  = standardPbId,
            DRC_NBC_Type__c = 'Domestic'
        );
        insert emptyQuote;

        Test.startTest();
    }

    // ─── makePicklistOptions ──────────────────────────────────────────────────

    @isTest
    static void testMakePicklistOptions() {
        Test.startTest();
        DRC_NBC_Generate_Order_Controller.PicklistOptionsWrapper result =
            DRC_NBC_Generate_Order_Controller.makePicklistOptions();
        Test.stopTest();
    }

    // ─── createOrder - Success ────────────────────────────────────────────────

    @isTest
    static void testCreateOrderSuccess() {
        Account acc      = [SELECT Id FROM Account LIMIT 1];
        Quote quote      = [SELECT Id, Pricebook2Id FROM Quote LIMIT 1];
        Contact billTo   = [SELECT Id FROM Contact WHERE FirstName = 'Bill' LIMIT 1];
        Contact shipTo   = [SELECT Id FROM Contact WHERE FirstName = 'Ship' LIMIT 1];
        Product2 prod    = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :Test.getStandardPricebookId() LIMIT 1];
        DRC_NBC_Addresses__c addr = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];

        Order orderObj = buildTestOrder(acc.Id, quote.Pricebook2Id, billTo.Id, shipTo.Id, null, addr.Id);

        DRC_NBC_OrderItemWrapper w = buildOrderItemWrapper(prod.Id, pbe.Id, 3, 100);

        Test.startTest();
        String resultJson = DRC_NBC_Generate_Order_Controller.createOrder(
            orderObj, new List<DRC_NBC_OrderItemWrapper>{ w }, quote.Id
        );
        Test.stopTest();
    }

    // ─── createOrder - Missing email on contact ───────────────────────────────

    @isTest
    static void testCreateOrderMissingEmail() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Quote quote = [SELECT Id, Pricebook2Id FROM Quote LIMIT 1];
        DRC_NBC_Addresses__c addr = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];

        // Create contacts WITHOUT emails
        Contact noEmailBill = new Contact(FirstName = 'NoEmail', LastName = 'Bill', AccountId = acc.Id);
        Contact noEmailShip = new Contact(FirstName = 'NoEmail', LastName = 'Ship', AccountId = acc.Id);
        insert new List<Contact>{ noEmailBill, noEmailShip };

        Order orderObj = buildTestOrder(acc.Id, quote.Pricebook2Id, noEmailBill.Id, noEmailShip.Id, null, addr.Id);
        Product2 prod  = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];
        DRC_NBC_OrderItemWrapper w = buildOrderItemWrapper(prod.Id, pbe.Id, 1, 100);

        Test.startTest();
        String resultJson = DRC_NBC_Generate_Order_Controller.createOrder(
            orderObj, new List<DRC_NBC_OrderItemWrapper>{ w }, quote.Id
        );
        Test.stopTest();
    }

    // ─── createOrder - Missing PricebookEntry ─────────────────────────────────

    @isTest
    static void testCreateOrderMissingPricebookEntry() {
        Account acc    = [SELECT Id FROM Account LIMIT 1];
        Quote quote    = [SELECT Id, Pricebook2Id FROM Quote LIMIT 1];
        Contact billTo = [SELECT Id FROM Contact WHERE FirstName = 'Bill' LIMIT 1];
        Contact shipTo = [SELECT Id FROM Contact WHERE FirstName = 'Ship' LIMIT 1];
        Product2 prod  = [SELECT Id FROM Product2 LIMIT 1];
        DRC_NBC_Addresses__c addr = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];

        Order orderObj = buildTestOrder(acc.Id, quote.Pricebook2Id, billTo.Id, shipTo.Id, null, addr.Id);

        // Wrapper with no PricebookEntryId — forces missing PBE branch
        DRC_NBC_OrderItemWrapper w = new DRC_NBC_OrderItemWrapper();
        w.Product2Id       = prod.Id;
        w.PriceBookEntryId = null; // intentionally blank
        w.Quantity         = 1;
        w.UnitPrice        = 100;
        w.Description      = 'Missing PBE item';
        w.UOM              = 'Each';

        // Use a custom pricebook that has no PBE for the product
        Pricebook2 emptyPb = new Pricebook2(Name = 'Empty PB', IsActive = true);
        insert emptyPb;
        orderObj.Pricebook2Id = emptyPb.Id;

        Test.startTest();
        String resultJson = DRC_NBC_Generate_Order_Controller.createOrder(
            orderObj, new List<DRC_NBC_OrderItemWrapper>{ w }, quote.Id
        );
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resultJson);
        System.assertEquals(false, result.get('success'), 'Should fail due to missing PBE');
        System.assert(
            ((String) result.get('error')).contains('Missing PricebookEntry') ||
            ((String) result.get('error')).contains('No valid Order Items'),
            'Error should mention missing PBE or no valid items: ' + result.get('error')
        );
    }

    // ─── createOrder - Empty order items list ─────────────────────────────────

    @isTest
    static void testCreateOrderNoValidItems() {
        Account acc    = [SELECT Id FROM Account LIMIT 1];
        Quote quote    = [SELECT Id, Pricebook2Id FROM Quote LIMIT 1];
        Contact billTo = [SELECT Id FROM Contact WHERE FirstName = 'Bill' LIMIT 1];
        Contact shipTo = [SELECT Id FROM Contact WHERE FirstName = 'Ship' LIMIT 1];
        DRC_NBC_Addresses__c addr = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];

        Order orderObj = buildTestOrder(acc.Id, quote.Pricebook2Id, billTo.Id, shipTo.Id, null, addr.Id);

        // Wrapper with blank Product2Id — gets skipped → no valid items
        DRC_NBC_OrderItemWrapper w = new DRC_NBC_OrderItemWrapper();
        w.Product2Id = '';
        w.Quantity   = 1;
        w.UnitPrice  = 100;

        Test.startTest();
        String resultJson = DRC_NBC_Generate_Order_Controller.createOrder(
            orderObj, new List<DRC_NBC_OrderItemWrapper>{ w }, quote.Id
        );
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resultJson);
        System.assertEquals(false, result.get('success'), 'Should fail with no valid items');
        System.assert(
            ((String) result.get('error')).contains('No valid Order Items'),
            'Error should mention no valid items: ' + result.get('error')
        );
    }

    // ─── createOrder - No shipping address (null branch) ─────────────────────

    @isTest
    static void testCreateOrderNoShippingAddress() {
        Account acc    = [SELECT Id FROM Account LIMIT 1];
        Quote quote    = [SELECT Id, Pricebook2Id FROM Quote LIMIT 1];
        Contact billTo = [SELECT Id FROM Contact WHERE FirstName = 'Bill' LIMIT 1];
        Contact shipTo = [SELECT Id FROM Contact WHERE FirstName = 'Ship' LIMIT 1];
        Product2 prod  = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :Test.getStandardPricebookId() LIMIT 1];

        // Order with no shipping address
        Order orderObj = buildTestOrder(acc.Id, quote.Pricebook2Id, billTo.Id, shipTo.Id, null, null);
        orderObj.DRC_NBC_Shipping_Address__c = null;

        DRC_NBC_OrderItemWrapper w = buildOrderItemWrapper(prod.Id, pbe.Id, 2, 100);

        Test.startTest();
        String resultJson = DRC_NBC_Generate_Order_Controller.createOrder(
            orderObj, new List<DRC_NBC_OrderItemWrapper>{ w }, quote.Id
        );
        Test.stopTest();
    }

    // ─── fieldPicklistValue ───────────────────────────────────────────────────

    @isTest
    static void testFieldPicklistValue() {
        Test.startTest();
        // Test via getOrderTypes which internally calls fieldPicklistValue on DRC_NBC_Type__c
        List<DRC_NBC_Generate_Order_Controller.OptionsWrapper> options =
            DRC_NBC_Generate_Order_Controller.getOrderTypes();
        Test.stopTest();
    }

    // ─── getRelatedQLIS ───────────────────────────────────────────────────────

    @isTest
    static void testGetRelatedQLIS() {
        Quote quote = [SELECT Id FROM Quote LIMIT 1];
        Test.startTest();
        List<QuoteLineItem> qlis = DRC_NBC_Generate_Order_Controller.getRelatedQLIS(quote.Id);
        Test.stopTest();
    }
}