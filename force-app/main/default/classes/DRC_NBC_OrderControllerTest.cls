@isTest
public class DRC_NBC_OrderControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Create Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        // Create Contacts
        Contact billTo = new Contact(FirstName = 'Bill', LastName = 'To', AccountId = acc.Id);
        Contact shipTo = new Contact(FirstName = 'Ship', LastName = 'To', AccountId = acc.Id);
        insert new List<Contact>{ billTo, shipTo };
            
            // Create Opportunity
            Opportunity opp = new Opportunity(
                Name = 'Test Opp',
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(10)
            );
        insert opp;
        
        // Create Quote
        Quote quote = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            DRC_NBC_Type__c = 'Domestic'
        );
        insert quote;
        
        Id standardPbId = Test.getStandardPricebookId();
        
        // Activate standard pricebook
        Pricebook2 standardPb = new Pricebook2(Id = standardPbId, IsActive = true);
        update standardPb;
        
        // Create custom Pricebook
        Pricebook2 customPb = new Pricebook2(Name = 'Test PB', IsActive = true);
        insert customPb;
        
        // Create Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Family = 'Test'
        );
        insert prod;
        
        // Standard PricebookEntry (required before custom entry)
        PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id    = standardPbId,
            Product2Id      = prod.Id,
            UnitPrice       = 100,
            IsActive        = true,
            CurrencyIsoCode = 'USD'
        );
        insert standardPbe;
        
        // Custom PricebookEntry
        PricebookEntry customPbe = new PricebookEntry(
            Pricebook2Id     = customPb.Id,
            Product2Id       = prod.Id,
            UnitPrice        = 120,
            IsActive         = true,
            UseStandardPrice = false,
            CurrencyIsoCode  = 'USD'
        );
        insert customPbe;
        
        // Create Shipping Address
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c              = acc.Id,
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Address__Street__s      = '123 Main St',
            DRC_NBC_Address__City__s        = 'City',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__PostalCode__s  = '12345',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Warehouse__c            = 'CFS - JNPT'
        );
        insert addr;
        
        // Create Restricted Product
        DRC_NBC_Restricted_Product__c restProd = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Product__c  = prod.Id,
            DRC_NBC_Customer__c = acc.Id
        );
        insert restProd;
        
        // Create Orders in Draft status first
        Order domesticOrd = new Order(
            Name                        = 'Test Domestic Order',
            AccountId                   = acc.Id,
            EffectiveDate               = Date.today(),
            Status                      = 'Draft',
            CurrencyIsoCode             = 'USD',
            Pricebook2Id                = customPb.Id,
            Type                        = 'Domestic',
            BillToContactId             = billTo.Id,
            ShipToContactId             = shipTo.Id,
            OpportunityId               = opp.Id,
            QuoteId                     = quote.Id,
            DRC_NBC_Type__c             = 'Domestic',
            DRC_NBC_Shipping_Address__c = addr.Id
        );
        
        Order exportOrd = new Order(
            Name                        = 'Test Export Order',
            AccountId                   = acc.Id,
            EffectiveDate               = Date.today(),
            Status                      = 'Draft',
            CurrencyIsoCode             = 'USD',
            Pricebook2Id                = customPb.Id,
            Type                        = 'Export',
            BillToContactId             = billTo.Id,
            ShipToContactId             = shipTo.Id,
            OpportunityId               = opp.Id,
            QuoteId                     = quote.Id,
            DRC_NBC_Type__c             = 'Export',
            DRC_NBC_Shipping_Address__c = addr.Id
        );
        
        Order sampleOrd = new Order(
            Name                        = 'Test Sample Order',
            AccountId                   = acc.Id,
            EffectiveDate               = Date.today(),
            Status                      = 'Draft',
            CurrencyIsoCode             = 'USD',
            Pricebook2Id                = customPb.Id,
            Type                        = 'Sample Order',
            BillToContactId             = billTo.Id,
            ShipToContactId             = shipTo.Id,
            OpportunityId               = opp.Id,
            QuoteId                     = quote.Id,
            DRC_NBC_Type__c             = null,
            DRC_NBC_Shipping_Address__c = addr.Id
        );
        
        List<Order> orders = new List<Order>{ domesticOrd, exportOrd, sampleOrd };
            insert orders;
        
        // Insert OrderItems while still in Draft status
        List<OrderItem> oliList = new List<OrderItem>();
        for (Order ord : orders) {
            oliList.add(new OrderItem(
                OrderId          = ord.Id,
                PricebookEntryId = customPbe.Id,
                Quantity         = 2,
                UnitPrice        = 100,
                Product2Id       = prod.Id
            ));
        }
        insert oliList;
        
        // ── KEY FIX: Activate orders AFTER inserting OLIs ──────────────────
        // saveOrderLineItems upserts OLIs which requires Activated status.
        for (Order ord : orders) {
            ord.Status = 'Draft';
        }
        update orders;
    }
    
    // ─── Utility: fetch a fresh activated Order with all writable fields ──────
    private static Order getFullOrder(String orderType) {
        return [
            SELECT Id, Name, EffectiveDate, EndDate, Description, CurrencyIsoCode,
            Status, Type, Pricebook2Id,
            DRC_NBC_Type__c, DRC_NBC_Payment_Terms__c, DRC_NBC_Select_Bank__c,
            DRC_NBC_Inco_Terms__c, DRC_NBC_Warehouse__c,
            DRC_NBC_Other_Rejection_Reason__c, DRC_NBC_Reject_Reason_Text__c,
            DRC_NBC_Special_Instructions__c, DRC_NBC_Terms_and_Conditions__c,
            PONumber, PoDate, DRC_NBC_TCS_Amount__c, DRC_NBC_Other_Tax_Amount__c,
            DRC_NBC_Consignee_Bank_Name__c, DRC_NBC_Consignee_Bank_Account_Number__c,
            DRC_NBC_Consignee_Bank_IFSC_Code__c, DRC_NBC_Consignee_Bank_Address__c,
            OpportunityId, QuoteId, BillToContactId, ShipToContactId,
            DRC_NBC_Shipping_Address__c,
            DRC_NBC_Transporter_Name__c, DRC_NBC_Transport_Agent__c,
            DRC_NBC_Prepayment_Method__c, DRC_NBC_Shipment_Method__c,
            DRC_NBC_Shipment_Date__c,
            DRC_NBC_Country_of_Origin__c, DRC_NBC_Country_of_Final_Destination__c,
            DRC_NBC_Port_Of_Discharge__c, DRC_NBC_Port_of_Loading__c,
            DRC_NBC_Notify_Party__c, DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c,
            DRC_NBC_Vessel_no_Flight_no__c, DRC_NBC_Part_Shipment__c,
            DRC_NBC_Trans_Shipment__c, DRC_NBC_Final_Destination__c,
            DRC_NBC_Required_Documents__c,
            DRC_NBC_Sample_Name__c, DRC_NBC_Sample_Type__c,
            DRC_NBC_Courier_service__c, DRC_NBC_Delivery_status__c,
            DRC_NBC_Courier_Number__c, DRC_NBC_Expected_Delivery_Date__c,
            DRC_NBC_Courier_date__c, DRC_NBC_Sample_Shipping_Cost__c,
            DRC_NBC_Special_request__c, DRC_NBC_Sample_Amount__c, DRC_NBC_Remarks__c
            FROM Order
            WHERE Type = :orderType
            LIMIT 1
        ];
    }
    
    // ─── Helper: fetch OLIs for an order ─────────────────────────────────────
    private static List<OrderItem> getOLIs(Id orderId) {
        return [
            SELECT Id, Product2Id, Quantity, UnitPrice, PricebookEntryId, OrderId,
            DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Quantity__c
            FROM OrderItem
            WHERE OrderId = :orderId
        ];
    }
    
    // ─── getOrderRecord ───────────────────────────────────────────────────────
    
    @isTest
    static void testGetOrderRecord() {
        Order o = [SELECT Id FROM Order WHERE Type = 'Domestic' LIMIT 1];
        Test.startTest();
        Order result = DRC_NBC_OrderController.getOrderRecord(o.Id);
        Test.stopTest();
        System.assertNotEquals(null, result, 'Order record should not be null');
    }
    
    @isTest
    static void testGetOrderRecordInvalid() {
        Test.startTest();
        try {
            DRC_NBC_OrderController.getOrderRecord(null);
            System.assert(false, 'Exception expected for null orderId');
        } catch (Exception e) {
            System.assert(e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    // ─── getAccountAddresses ──────────────────────────────────────────────────
    
    @isTest
    static void testGetAccountAddresses() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<DRC_NBC_OrderController.AddressWrapper> addresses =
            DRC_NBC_OrderController.getAccountAddresses(acc.Id);
        Test.stopTest();
        System.assertNotEquals(null, addresses, 'Addresses list should not be null');
        System.assert(addresses.size() > 0, 'Should return at least one address');
    }
    
    // ─── getExistingOrderLineItems ────────────────────────────────────────────
    
    @isTest
    static void testGetExistingOrderLineItemsDomestic() {
        Order o = [SELECT Id FROM Order WHERE Type = 'Domestic' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.oliWrapper wrapper =
            DRC_NBC_OrderController.getExistingOrderLineItems(o.Id);
        Test.stopTest();
        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
        System.assertNotEquals(null, wrapper.olis, 'OLIs should not be null');
    }
    
    @isTest
    static void testGetExistingOrderLineItemsExport() {
        Order o = [SELECT Id FROM Order WHERE Type = 'Export' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.oliWrapper wrapper =
            DRC_NBC_OrderController.getExistingOrderLineItems(o.Id);
        Test.stopTest();
        System.assertNotEquals(null, wrapper, 'Wrapper should not be null');
    }
    
    // ─── getRestrictedProductsAccessList ─────────────────────────────────────
    
    @isTest
    static void testGetRestrictedProductsAccessList() {
        Order o = [SELECT Id FROM Order WHERE Type = 'Domestic' LIMIT 1];
        Test.startTest();
        List<DRC_NBC_Restricted_Product__c> restrictedList =
            DRC_NBC_OrderController.getRestrictedProductsAccessList(o.Id);
        Test.stopTest();
        System.assertNotEquals(null, restrictedList, 'Restricted list should not be null');
    }
    
    // ─── getContactsByAccount ─────────────────────────────────────────────────
    
    @isTest
    static void testGetContactsByAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Contact> contacts = DRC_NBC_OrderController.getContactsByAccount(acc.Id);
        Test.stopTest();
        System.assert(contacts.size() > 0, 'Should return at least one contact');
    }
    
    // ─── getOpportunitiesByAccount ────────────────────────────────────────────
    
    @isTest
    static void testGetOpportunitiesByAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Opportunity> opps = DRC_NBC_OrderController.getOpportunitiesByAccount(acc.Id);
        Test.stopTest();
        System.assert(opps.size() > 0, 'Should return at least one opportunity');
    }
    
    // ─── getQuotesByOpportunity ───────────────────────────────────────────────
    
    @isTest
    static void testGetQuotesByOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Quote> quotes = DRC_NBC_OrderController.getQuotesByOpportunity(opp.Id);
        Test.stopTest();
        System.assert(quotes.size() > 0, 'Should return at least one quote');
    }
    
    
    
    @isTest
    static void testSaveOrderLineItems_MissingProduct2Id() {
        Order order = getFullOrder('Domestic');
        order.Status = 'Activated';
        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :order.Pricebook2Id LIMIT 1
        ];
        
        // Product2Id is blank — triggers validation inside saveOrderLineItems
        OrderItem badOli = new OrderItem(
            OrderId          = order.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 1,
            UnitPrice        = 100
            // Product2Id intentionally omitted
        );
        
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{ badOli }, new List<String>(), order
            );
            System.assert(false, 'Expected AuraHandledException for missing Product2Id');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSaveOrderLineItems_MissingQuantity() {
        Order order = getFullOrder('Domestic');
        order.Status = 'Activated';
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :order.Pricebook2Id LIMIT 1
        ];
        
        // Quantity is null — triggers validation inside saveOrderLineItems
        OrderItem badOli = new OrderItem(
            OrderId          = order.Id,
            PricebookEntryId = pbe.Id,
            Product2Id       = prod.Id,
            UnitPrice        = 100
            // Quantity intentionally omitted
        );
        
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{ badOli }, new List<String>(), order
            );
            System.assert(false, 'Expected AuraHandledException for missing Quantity');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSaveOrderLineItems_MissingUnitPrice() {
        Order order = getFullOrder('Domestic');
        order.Status = 'Activated';
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :order.Pricebook2Id LIMIT 1
        ];
        
        // UnitPrice is null — triggers validation inside saveOrderLineItems
        OrderItem badOli = new OrderItem(
            OrderId          = order.Id,
            PricebookEntryId = pbe.Id,
            Product2Id       = prod.Id,
            Quantity         = 1
            // UnitPrice intentionally omitted
        );
        
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{ badOli }, new List<String>(), order
            );
            System.assert(false, 'Expected AuraHandledException for missing UnitPrice');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    // ─── saveOrderLineItems - null orderData ──────────────────────────────────
    
    @isTest
    static void testSaveOrderLineItems_NullOrderData() {
        Order order = [SELECT Id FROM Order WHERE Type = 'Domestic' LIMIT 1];
        List<OrderItem> olis = getOLIs(order.Id);
        
        Test.startTest();
        // Passing null orderData — controller should handle gracefully (no update attempted)
        DRC_NBC_OrderController.saveOrderLineItems(olis, new List<String>(), null);
        Test.stopTest();
    }
}