@isTest
public class DRC_NBC_OrderControllerTest {
    
    private static void setupTestData(String orderType) {
        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        // Create Contacts
        Contact billTo = new Contact(FirstName = 'Bill', LastName = 'To', AccountId = acc.Id);
        Contact shipTo = new Contact(FirstName = 'Ship', LastName = 'To', AccountId = acc.Id);
        insert new List<Contact>{billTo, shipTo};
            
            // Create Opportunity & Quote
            Opportunity opp = new Opportunity(Name = 'Test Opp', AccountId = acc.Id, StageName = 'Prospecting', CloseDate = Date.today().addDays(10));
        insert opp;
        
        Quote quote = new Quote(Name = 'Test Quote', OpportunityId = opp.Id, DRC_NBC_Type__c = 'Domestic');
        insert quote;
        
        Id standardPbId = Test.getStandardPricebookId();        
        
        
        // Create custom Pricebook
        Pricebook2 customPb = new Pricebook2(
            Name = 'Test PB',
            IsActive = true
        );
        insert customPb;
        
        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Family = 'Test'
        );
        insert prod;
        // Create Standard PricebookEntry
        PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id = prod.Id,
            UnitPrice = 100,
            IsActive = true
        );
        
        // Multi-currency orgs may require this:
        if (Test.isRunningTest() && Schema.sObjectType.PricebookEntry.fields.CurrencyIsoCode.isCreateable()) {
            standardPbe.put('CurrencyIsoCode', 'USD'); // Avoid FIELD_INTEGRITY_EXCEPTION
        }
        
        insert standardPbe;
        
        
        
        PricebookEntry customPbe = new PricebookEntry(
            Pricebook2Id = customPb.Id,
            Product2Id = prod.Id,
            UnitPrice = 120,
            IsActive = true,
            UseStandardPrice = false,
            CurrencyIsoCode = 'USD' 
        );
        insert customPbe;
        
        
        
        // Create DRC_NBC_Addresses__c
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            // Name = 'Shipping Address',
            DRC_NBC_Account__c = acc.Id,
            DRC_NBC_Type__c = 'Shipping',
            DRC_NBC_Address__Street__s = '123 Main St',
            DRC_NBC_Address__City__s = 'City',
            DRC_NBC_Address__StateCode__s = 'MH',
            DRC_NBC_Address__PostalCode__s = '12345',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Warehouse__c = 'CFS - JNPT'
        );
        insert addr;
        
        // Create Restricted Product
        DRC_NBC_Restricted_Product__c restProd = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Product__c = prod.Id,
            DRC_NBC_Customer__c = acc.Id
        );
        insert restProd;
        
        // Create Order
        Order ord = new Order(
            Name = 'Test Order',
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            CurrencyIsoCode = 'USD',
            Pricebook2Id = customPb.Id, 
            Type = orderType,
            BillToContactId = billTo.Id,
            ShipToContactId = shipTo.Id,
            OpportunityId = opp.Id,
            QuoteId = quote.Id,
            DRC_NBC_Type__c = orderType == 'Sample Order' ? null : orderType,
            DRC_NBC_Shipping_Address__c = addr.Id
        );
        insert ord;
        
        // Create OrderItem
        OrderItem oli = new OrderItem(
            OrderId = ord.Id,
            PricebookEntryId = customPbe.Id,
            Quantity = 2,
            UnitPrice = 100,
            Product2Id = prod.Id
        );
        insert oli;
    }
    
    @isTest
    static void testGetOrderRecord() {
        setupTestData('Domestic');
        Order o = [SELECT Id FROM Order LIMIT 1];
        Test.startTest();
        Order result = DRC_NBC_OrderController.getOrderRecord(o.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetOrderRecordInvalid() {
        Test.startTest();
        try {
            DRC_NBC_OrderController.getOrderRecord(null);
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Order ID is required'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetAccountAddresses() {
        setupTestData('Export');
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<DRC_NBC_OrderController.AddressWrapper> addresses = DRC_NBC_OrderController.getAccountAddresses(acc.Id);
        Test.stopTest();
        System.assert(!addresses.isEmpty());
    }
    
    @isTest
    static void testGetExistingOrderLineItems() {
        setupTestData('Export');
        Order o = [SELECT Id FROM Order WHERE Type = 'Export' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.oliWrapper wrapper = DRC_NBC_OrderController.getExistingOrderLineItems(o.Id);
        Test.stopTest();
        System.assert(wrapper.olis.size() > 0);
        System.assert(wrapper.productsList.size() > 0);
    }
    
    /* @isTest
static void testGetRestrictedProductsAccessList() {
setupTestData('Export');
Order o = [SELECT Id FROM Order LIMIT 1];
Test.startTest();
List<DRC_NBC_Restricted_Product__c> list = DRC_NBC_OrderController.getRestrictedProductsAccessList(o.Id);
Test.stopTest();
System.assertEquals(1, list.size());
}*/
    
    @isTest
    static void testGetContactsByAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Contact> contacts = DRC_NBC_OrderController.getContactsByAccount(acc.Id);
        Test.stopTest();
        System.assert(!contacts.isEmpty());
    }
    
    @isTest
    static void testGetOpportunitiesByAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Opportunity> opps = DRC_NBC_OrderController.getOpportunitiesByAccount(acc.Id);
        Test.stopTest();
        System.assert(!opps.isEmpty());
    }
    
    @isTest
    static void testGetQuotesByOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Quote> quotes = DRC_NBC_OrderController.getQuotesByOpportunity(opp.Id);
        Test.stopTest();
        System.assert(!quotes.isEmpty());
    }
    
    @isTest
    static void testSaveOrderLineItemsDomestic() {
        setupTestData('Domestic');
        Order order = [SELECT Id, Pricebook2Id FROM Order WHERE Type = 'Domestic' LIMIT 1];
        List<OrderItem> olis = [SELECT Id, Product2Id, Quantity, UnitPrice, PricebookEntryId, OrderId FROM OrderItem WHERE OrderId = :order.Id];
        Test.startTest();
        DRC_NBC_OrderController.saveOrderLineItems(olis, new List<String>(), order);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveOrderLineItemsExport() {
        setupTestData('Export');
        Order order = [SELECT Id, Pricebook2Id FROM Order WHERE Type = 'Export' LIMIT 1];
        List<OrderItem> olis = [SELECT Id, Product2Id, Quantity, UnitPrice, PricebookEntryId, OrderId FROM OrderItem WHERE OrderId = :order.Id];
        Test.startTest();
        DRC_NBC_OrderController.saveOrderLineItems(olis, new List<String>(), order);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveOrderLineItemsSample() {
        setupTestData('Sample Order');
        Order order = [SELECT Id, Pricebook2Id FROM Order WHERE Type = 'Sample Order' LIMIT 1];
        List<OrderItem> olis = [SELECT Id, Product2Id, Quantity, UnitPrice, PricebookEntryId, OrderId FROM OrderItem WHERE OrderId = :order.Id];
        Test.startTest();
        DRC_NBC_OrderController.saveOrderLineItems(olis, new List<String>(), order);
        Test.stopTest();
    }
    
    @isTest
    static void testSaveOrderLineItems_DeleteItems() {
        setupTestData('Domestic');
        Order order = [SELECT Id FROM Order WHERE Type = 'Domestic' LIMIT 1];
        List<OrderItem> olis = [SELECT Id, Product2Id, Quantity, UnitPrice, PricebookEntryId, OrderId FROM OrderItem WHERE OrderId = :order.Id];
        List<String> idsToDelete = new List<String>{olis[0].Id};
            Test.startTest();
        DRC_NBC_OrderController.saveOrderLineItems(new List<OrderItem>(), idsToDelete, order);
        Test.stopTest();
    }
}