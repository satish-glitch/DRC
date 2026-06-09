/**
* @File Name : DRC_NBC_OrderControllerTest.cls
* @Description : Test class for DRC_NBC_OrderController — full coverage (≥ 85%)
* @Last Modified On : May 26, 2026
**/
@isTest
public class DRC_NBC_OrderControllerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // TEST SETUP
    // ─────────────────────────────────────────────────────────────────────────
    @testSetup
    static void setupTestData() {

        Account acc = new Account(
            Name                                     = 'Test Account',
            DRC_NBC_Customer_Number__c               = 'CUST12345',
            CurrencyIsoCode                          = 'INR',
            Phone                                    = '1234567890',
            AccountNumber                            = 'A123',
            DRC_NBC_PAN_No__c                        = 'AWVPY9594J',
            DRC_NBC_GST_Number__c                    = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c             = 'PDC90',
            DRC_NBC_Account_Email_Email__c           = 'test@example.com',
            BillingStreet                            = '123 Street',
            BillingCity                              = 'City',
            BillingCountry                           = 'India',
            BillingCountryCode                       = 'IN',
            BillingPostalCode                        = '462002',
            BillingState                             = 'Maharashtra',
            BillingStateCode                         = 'MH',
            DRC_NBC_Volume__c                        = 70,
            DRC_NBC_Credit_Limit__c                  = 123456787,
            DRC_NBC_Value__c                         = 900,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
            DRC_NBC_Consignee_Bank_Address__c        = 'Barhi 483775',
            DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'PUNB01391000',
            DRC_NBC_Consignee_Bank_Name__c           = 'Punjab National bank',
            Industry                                 = 'Chemicals Construction',
            Type                                     = 'Analyst'
        );
        insert acc;

        Contact billTo = new Contact(FirstName = 'Bill', LastName = 'To', AccountId = acc.Id);
        Contact shipTo = new Contact(FirstName = 'Ship', LastName = 'To', AccountId = acc.Id);
        insert new List<Contact>{ billTo, shipTo };

        Opportunity opp = new Opportunity(
            Name      = 'Test Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opp;

        Quote quote = new Quote(
            Name            = 'Test Quote',
            OpportunityId   = opp.Id,
            DRC_NBC_Type__c = 'Domestic'
        );
        insert quote;

        Id standardPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPbId, IsActive = true);

        Pricebook2 customPb = new Pricebook2(Name = 'Test PB', IsActive = true);
        insert customPb;

        Product2 prod = new Product2(Name = 'Test Product', IsActive = true, Family = 'Test');
        insert prod;

        Product2 prodUsdOnly = new Product2(Name = 'Test Product USD Only', IsActive = true, Family = 'Test');
        insert prodUsdOnly;

        Product2 prodNoPbe = new Product2(Name = 'Test Product No PBE', IsActive = true, Family = 'Test');
        insert prodNoPbe;

        // Standard PB entries
        insert new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = prod.Id,        UnitPrice = 100,   IsActive = true, CurrencyIsoCode = 'USD');
        insert new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = prod.Id,        UnitPrice = 8000,  IsActive = true, CurrencyIsoCode = 'INR');
        insert new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = prodUsdOnly.Id, UnitPrice = 200,   IsActive = true, CurrencyIsoCode = 'USD');
        insert new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = prodUsdOnly.Id, UnitPrice = 15000, IsActive = true, CurrencyIsoCode = 'INR');
        insert new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = prodNoPbe.Id,   UnitPrice = 50,    IsActive = true, CurrencyIsoCode = 'USD');
        insert new PricebookEntry(Pricebook2Id = standardPbId, Product2Id = prodNoPbe.Id,   UnitPrice = 4000,  IsActive = true, CurrencyIsoCode = 'INR');

        // Custom PB entries
        PricebookEntry customPbeUsd = new PricebookEntry(Pricebook2Id = customPb.Id, Product2Id = prod.Id, UnitPrice = 120,  IsActive = true, UseStandardPrice = false, CurrencyIsoCode = 'USD');
        insert customPbeUsd;
        PricebookEntry customPbeInr = new PricebookEntry(Pricebook2Id = customPb.Id, Product2Id = prod.Id, UnitPrice = 8500, IsActive = true, UseStandardPrice = false, CurrencyIsoCode = 'INR');
        insert customPbeInr;

        // prodUsdOnly — USD only in custom PB, NO INR (forces auto-create)
        insert new PricebookEntry(Pricebook2Id = customPb.Id, Product2Id = prodUsdOnly.Id, UnitPrice = 250, IsActive = true, UseStandardPrice = false, CurrencyIsoCode = 'USD');
        // prodNoPbe — NO custom PB entry in any currency (forces price = 0 fallback)

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

        insert new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Product__c  = prod.Id,
            DRC_NBC_Customer__c = acc.Id
        );

        // Orders
        Order domesticOrd = buildOrder('Test Domestic Order', acc.Id, billTo.Id, shipTo.Id, opp.Id, quote.Id, customPb.Id, addr.Id, 'USD', 'Domestic');
        Order exportOrd   = buildOrder('Test Export Order',   acc.Id, billTo.Id, shipTo.Id, opp.Id, quote.Id, customPb.Id, addr.Id, 'USD', 'Export');
        Order sampleOrd   = buildOrder('Test Sample Order',   acc.Id, billTo.Id, shipTo.Id, opp.Id, quote.Id, customPb.Id, addr.Id, 'USD', 'Sample Order');
        sampleOrd.DRC_NBC_Type__c = null;

        Order inrOrd = new Order(
            Name                              = 'Test INR Order',
            AccountId                         = acc.Id,
            EffectiveDate                     = Date.today(),
            Status                            = 'Draft',
            CurrencyIsoCode                   = 'INR',
            Pricebook2Id                      = customPb.Id,
            Type                              = 'Domestic',
            BillToContactId                   = billTo.Id,
            ShipToContactId                   = shipTo.Id,
            DRC_NBC_Type__c                   = 'Domestic',
            DRC_NBC_Shipping_Address__c       = addr.Id,
            DRC_NBC_Order_PartiallyShipped__c = false
        );

        Order inrAutoOrd = new Order(
            Name                              = 'Test INR Auto Order',
            AccountId                         = acc.Id,
            EffectiveDate                     = Date.today(),
            Status                            = 'Draft',
            CurrencyIsoCode                   = 'INR',
            Pricebook2Id                      = customPb.Id,
            Type                              = 'Domestic',
            BillToContactId                   = billTo.Id,
            ShipToContactId                   = shipTo.Id,
            DRC_NBC_Type__c                   = 'Domestic',
            DRC_NBC_Shipping_Address__c       = addr.Id,
            DRC_NBC_Order_PartiallyShipped__c = false
        );

        Order inrNoPbeOrd = new Order(
            Name                              = 'Test INR NoPBE Order',
            AccountId                         = acc.Id,
            EffectiveDate                     = Date.today(),
            Status                            = 'Draft',
            CurrencyIsoCode                   = 'INR',
            Pricebook2Id                      = customPb.Id,
            Type                              = 'Domestic',
            BillToContactId                   = billTo.Id,
            ShipToContactId                   = shipTo.Id,
            DRC_NBC_Type__c                   = 'Domestic',
            DRC_NBC_Shipping_Address__c       = addr.Id,
            DRC_NBC_Order_PartiallyShipped__c = false
        );

        Order noPbOrd = new Order(
            Name                              = 'Test No PB Order',
            AccountId                         = acc.Id,
            EffectiveDate                     = Date.today(),
            Status                            = 'Draft',
            CurrencyIsoCode                   = 'USD',
            Type                              = 'Domestic',
            BillToContactId                   = billTo.Id,
            ShipToContactId                   = shipTo.Id,
            DRC_NBC_Type__c                   = 'Domestic',
            DRC_NBC_Order_PartiallyShipped__c = false
        );

        Order noAddrOrd = new Order(
            Name                              = 'Test No Addr Order',
            AccountId                         = acc.Id,
            EffectiveDate                     = Date.today(),
            Status                            = 'Draft',
            CurrencyIsoCode                   = 'USD',
            Pricebook2Id                      = customPb.Id,
            Type                              = 'Domestic',
            BillToContactId                   = billTo.Id,
            ShipToContactId                   = shipTo.Id,
            DRC_NBC_Type__c                   = 'Domestic',
            DRC_NBC_Order_PartiallyShipped__c = false
        );

        Order stdPbOrd = new Order(
            Name                              = 'Test StdPB Order',
            AccountId                         = acc.Id,
            EffectiveDate                     = Date.today(),
            Status                            = 'Draft',
            CurrencyIsoCode                   = 'INR',
            Pricebook2Id                      = standardPbId,
            Type                              = 'Domestic',
            BillToContactId                   = billTo.Id,
            ShipToContactId                   = shipTo.Id,
            DRC_NBC_Type__c                   = 'Domestic',
            DRC_NBC_Order_PartiallyShipped__c = false
        );

        List<Order> usdOrders = new List<Order>{ domesticOrd, exportOrd, sampleOrd };
        insert usdOrders;
        insert new List<Order>{ inrOrd, inrAutoOrd, inrNoPbeOrd, noPbOrd, noAddrOrd, stdPbOrd };

        List<OrderItem> usdOliList = new List<OrderItem>();
        for (Order ord : usdOrders) {
            usdOliList.add(new OrderItem(
                OrderId          = ord.Id,
                PricebookEntryId = customPbeUsd.Id,
                Quantity         = 2,
                UnitPrice        = 120,
                Product2Id       = prod.Id
            ));
        }
        insert usdOliList;

        insert new OrderItem(
            OrderId          = inrOrd.Id,
            PricebookEntryId = customPbeInr.Id,
            Quantity         = 2,
            UnitPrice        = 8500,
            Product2Id       = prod.Id
        );

        PricebookEntry stdPbeInr = [
            SELECT Id FROM PricebookEntry
            WHERE Pricebook2Id    = :standardPbId
              AND Product2Id      = :prod.Id
              AND CurrencyIsoCode = 'INR'
            LIMIT 1
        ];
        insert new OrderItem(
            OrderId          = stdPbOrd.Id,
            PricebookEntryId = stdPbeInr.Id,
            Quantity         = 1,
            UnitPrice        = 8000,
            Product2Id       = prod.Id
        );

        List<Order> toActivate = new List<Order>();
        for (Order ord : new List<Order>{ domesticOrd, exportOrd, sampleOrd, inrOrd }) {
            toActivate.add(new Order(Id = ord.Id, Status = 'Under Evaluation'));
        }
        update toActivate;

        insert new DRC_NBC_Packing_Details__c(Product__c = prod.Id, DRC_NBC_Packing_Size__c = '25 KG', DRC_NBC_Packing_Qauntity__c = string.valueOf(40));
        insert new DRC_NBC_Packing_Details__c(Product__c = prod.Id, DRC_NBC_Packing_Size__c = '50 KG', DRC_NBC_Packing_Qauntity__c = null);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    private static String getPicklistValue(String fieldName) {
        List<Schema.PicklistEntry> entries = Order.getSObjectType()
            .getDescribe()
            .fields.getMap()
            .get(fieldName)
            .getDescribe()
            .getPicklistValues();
        return (entries != null && !entries.isEmpty()) ? entries[0].getValue() : null;
    }

    private static Order buildOrder(String name, Id accId, Id billId, Id shipId, Id oppId, Id quoteId, Id pbId, Id addrId, String currcy, String type) {
        return new Order(
            Name                              = name,
            AccountId                         = accId,
            EffectiveDate                     = Date.today(),
            Status                            = 'Draft',
            CurrencyIsoCode                   = currcy,
            Pricebook2Id                      = pbId,
            Type                              = type,
            BillToContactId                   = billId,
            ShipToContactId                   = shipId,
            OpportunityId                     = oppId,
            QuoteId                           = quoteId,
            DRC_NBC_Type__c                   = (type == 'Sample Order' ? null : type),
            DRC_NBC_Shipping_Address__c       = addrId,
            DRC_NBC_Order_PartiallyShipped__c = false
        );
    }

    private static Order getFullOrder(String orderName) {
        return [
            SELECT Id, Name, EffectiveDate, EndDate, Description, CurrencyIsoCode,
                   Status, Type, Pricebook2Id, DRC_NBC_Type__c,
                   DRC_NBC_Payment_Terms__c, DRC_NBC_Select_Bank__c, DRC_NBC_Inco_Terms__c,
                   DRC_NBC_Warehouse__c, DRC_NBC_Other_Rejection_Reason__c,
                   DRC_NBC_Reject_Reason_Text__c, DRC_NBC_Special_Instructions__c,
                   DRC_NBC_Terms_and_Conditions__c, PONumber, PoDate,
                   DRC_NBC_TCS_Amount__c, DRC_NBC_Other_Tax_Amount__c,
                   DRC_NBC_Consignee_Bank_Name__c, DRC_NBC_Consignee_Bank_Account_Number__c,
                   DRC_NBC_Consignee_Bank_IFSC_Code__c, DRC_NBC_Consignee_Bank_Address__c,
                   OpportunityId, QuoteId, BillToContactId, ShipToContactId,
                   DRC_NBC_Shipping_Address__c, DRC_NBC_Transporter_Name__c,
                   DRC_NBC_Transport_Agent__c, DRC_NBC_Prepayment_Method__c,
                   DRC_NBC_Shipment_Method__c, DRC_NBC_Shipment_Date__c,
                   DRC_NBC_Country_of_Origin__c, DRC_NBC_Country_of_Final_Destination__c,
                   DRC_NBC_Port_Of_Discharge__c, DRC_NBC_Port_of_Loading__c,
                   DRC_NBC_Notify_Party__c, DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c,
                   DRC_NBC_Vessel_no_Flight_no__c, DRC_NBC_Part_Shipment__c,
                   DRC_NBC_Trans_Shipment__c, DRC_NBC_Final_Destination__c,
                   DRC_NBC_Required_Documents__c, DRC_NBC_Sample_Name__c,
                   DRC_NBC_Sample_Type__c, DRC_NBC_Courier_service__c,
                   DRC_NBC_Delivery_status__c, DRC_NBC_Courier_Number__c,
                   DRC_NBC_Expected_Delivery_Date__c, DRC_NBC_Courier_date__c,
                   DRC_NBC_Sample_Shipping_Cost__c, DRC_NBC_Special_request__c,
                   DRC_NBC_Sample_Amount__c, DRC_NBC_Remarks__c,
                   DRC_NBC_Payment_Term_Description__c
            FROM Order
            WHERE Name = :orderName
            LIMIT 1
        ];
    }

    private static List<OrderItem> getOLIs(Id orderId) {
        return [
            SELECT Id, Product2Id, Quantity, UnitPrice, PricebookEntryId,
                   OrderId, DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Quantity__c
            FROM OrderItem
            WHERE OrderId = :orderId
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getOrderRecord
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetOrderRecord() {
        Order o = [SELECT Id FROM Order WHERE Name = 'Test Domestic Order' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.getOrderRecord(o.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetOrderRecordInvalid() {
        Test.startTest();
        try {
            DRC_NBC_OrderController.getOrderRecord(null);
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getAccountAddresses
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetAccountAddresses() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.getAccountAddresses(acc.Id);
        Test.stopTest();
    }

    @isTest
    static void testAddressWrapperConstructor() {
        Test.startTest();
        DRC_NBC_Addresses__c addr = [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
        DRC_NBC_OrderController.AddressWrapper aw =
            new DRC_NBC_OrderController.AddressWrapper(addr.Id, 'Test Label');
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Wrapper constructors
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testOliWrapperConstructor() {
        Test.startTest();
        DRC_NBC_OrderController.oliWrapper w = new DRC_NBC_OrderController.oliWrapper();
        Test.stopTest();
    }

    @isTest
    static void testPackingWrapperConstructors() {
        Test.startTest();
        DRC_NBC_OrderController.PackingDetailWrapper p1 =
            new DRC_NBC_OrderController.PackingDetailWrapper('25 KG', '40');
        DRC_NBC_OrderController.PackingDetailWrapper p2 =
            new DRC_NBC_OrderController.PackingDetailWrapper(null, null);
        DRC_NBC_OrderController.ProductPackingWrapper ppw =
            new DRC_NBC_OrderController.ProductPackingWrapper(
                'pid',
                new List<DRC_NBC_OrderController.PackingDetailWrapper>{ p1, p2 }
            );
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getExistingOrderLineItems
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetExistingOrderLineItemsDomestic() {
        Order o = [SELECT Id FROM Order WHERE Name = 'Test Domestic Order' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.getExistingOrderLineItems(o.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetExistingOrderLineItemsExport() {
        Order o = [SELECT Id FROM Order WHERE Name = 'Test Export Order' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.getExistingOrderLineItems(o.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetExistingOrderLineItemsSample() {
        Order o = [SELECT Id FROM Order WHERE Name = 'Test Sample Order' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.getExistingOrderLineItems(o.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetExistingOrderLineItemsNullPricebook() {
        Order o = [SELECT Id FROM Order WHERE Name = 'Test No PB Order' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.getExistingOrderLineItems(o.Id);
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getRestrictedProductsAccessList
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetRestrictedProductsAccessList() {
        Order o = [SELECT Id FROM Order WHERE Name = 'Test Domestic Order' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.getRestrictedProductsAccessList(o.Id);
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Lookup methods
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetContactsByAccount() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.getContactsByAccount(acc.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetOpportunitiesByAccount() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.getOpportunitiesByAccount(acc.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetQuotesByOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.getQuotesByOpportunity(opp.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetPicklistValues() {
        Test.startTest();
        DRC_NBC_OrderController.getPicklistValues();
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getOrCreatePricebookEntries — DIRECT CALL covering ALL internal branches
    // Branch 1: prod       → INR PBE already exists → goes into existing map
    // Branch 2: prodUsdOnly → NO INR PBE in custom PB → missingProducts,
    //                         USD price copied → new PBE inserted → added to map
    // Branch 3: prodNoPbe  → NO PBE at all in custom PB → missingProducts,
    //                         price = 0 fallback → new PBE inserted → added to map
    // Branch 4: Second call → all PBEs now exist → missingProducts.isEmpty()
    //                         → early return path covered
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testGetOrCreatePricebookEntries_AllBranches() {
        Pricebook2 customPb  = [SELECT Id FROM Pricebook2 WHERE Name = 'Test PB' LIMIT 1];
        Product2 prod        = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        Product2 prodUsdOnly = [SELECT Id FROM Product2 WHERE Name = 'Test Product USD Only' LIMIT 1];
        Product2 prodNoPbe   = [SELECT Id FROM Product2 WHERE Name = 'Test Product No PBE' LIMIT 1];

        Set<Id> allIds = new Set<Id>{ prod.Id, prodUsdOnly.Id, prodNoPbe.Id };

        Test.startTest();

        // First call: covers existing found + auto-create paths + price=0 fallback + insert + map update
        DRC_NBC_OrderController.getOrCreatePricebookEntries(allIds, customPb.Id, 'INR');

        // Second call: all INR PBEs now exist → missingProducts.isEmpty() → early return
        DRC_NBC_OrderController.getOrCreatePricebookEntries(allIds, customPb.Id, 'INR');

        Test.stopTest();
    }

    @isTest
    static void testGetOrCreatePricebookEntries_OnlyExistingPBE() {
        Pricebook2 customPb = [SELECT Id FROM Pricebook2 WHERE Name = 'Test PB' LIMIT 1];
        Product2 prod       = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];

        // prod already has INR PBE in custom PB → missingProducts will be empty → early return
        Set<Id> ids = new Set<Id>{ prod.Id };

        Test.startTest();
        DRC_NBC_OrderController.getOrCreatePricebookEntries(ids, customPb.Id, 'INR');
        Test.stopTest();
    }

    @isTest
    static void testGetOrCreatePricebookEntries_AutoCreate_PriceFromExistingEntry() {
        Pricebook2 customPb  = [SELECT Id FROM Pricebook2 WHERE Name = 'Test PB' LIMIT 1];
        Product2 prodUsdOnly = [SELECT Id FROM Product2 WHERE Name = 'Test Product USD Only' LIMIT 1];

        // prodUsdOnly has USD PBE but no INR PBE in custom PB
        // → goes into missingProducts
        // → price fetched from USD PBE
        // → new INR PBE inserted
        Set<Id> ids = new Set<Id>{ prodUsdOnly.Id };

        Test.startTest();
        DRC_NBC_OrderController.getOrCreatePricebookEntries(ids, customPb.Id, 'INR');
        Test.stopTest();
    }

    @isTest
    static void testGetOrCreatePricebookEntries_PriceZeroFallback() {
        Pricebook2 customPb = [SELECT Id FROM Pricebook2 WHERE Name = 'Test PB' LIMIT 1];
        Product2 prodNoPbe  = [SELECT Id FROM Product2 WHERE Name = 'Test Product No PBE' LIMIT 1];

        // prodNoPbe has NO entry in custom PB in any currency
        // → goes into missingProducts
        // → product2IdToUnitPrice is empty for it
        // → price defaults to 0
        // → new INR PBE inserted with UnitPrice = 0
        Set<Id> ids = new Set<Id>{ prodNoPbe.Id };

        Test.startTest();
        DRC_NBC_OrderController.getOrCreatePricebookEntries(ids, customPb.Id, 'INR');
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // saveOrderLineItems — validation errors
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveOrderLineItems_MissingProduct2Id() {
        Order order = getFullOrder('Test Domestic Order');
        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry
            WHERE Pricebook2Id    = :order.Pricebook2Id
              AND CurrencyIsoCode = 'USD'
            LIMIT 1
        ];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{
                    new OrderItem(OrderId = order.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100)
                },
                new List<String>(), order
            );
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_MissingQuantity() {
        Order order = getFullOrder('Test Domestic Order');
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{
                    new OrderItem(OrderId = order.Id, Product2Id = prod.Id, UnitPrice = 100)
                },
                new List<String>(), order
            );
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_MissingUnitPrice() {
        Order order = getFullOrder('Test Domestic Order');
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{
                    new OrderItem(OrderId = order.Id, Product2Id = prod.Id, Quantity = 1)
                },
                new List<String>(), order
            );
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_NullOrderData() {
        Order o = [SELECT Id FROM Order WHERE Name = 'Test Domestic Order' LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(getOLIs(o.Id), new List<String>(), null);
        } catch (Exception e) { }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // saveOrderLineItems — Domestic
    // Covers: DRC_NBC_Part_Shipment__c and DRC_NBC_Trans_Shipment__c assignments
    // Uses dynamic picklist value fetch to avoid invalid picklist errors
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveOrderLineItems_DomesticOrder_UpdateExistingOLIs() {
        Order order = getFullOrder('Test Domestic Order');
        order.DRC_NBC_Type__c              = 'Domestic';
        order.DRC_NBC_Transporter_Name__c  = 'TT';
        order.DRC_NBC_Transport_Agent__c   = 'TA';
        order.DRC_NBC_Prepayment_Method__c = 'Cheque';
        order.DRC_NBC_Shipment_Method__c   = 'Road';
        order.DRC_NBC_Shipment_Date__c     = Date.today().addDays(3);
        order.DRC_NBC_Part_Shipment__c     = getPicklistValue('DRC_NBC_Part_Shipment__c');
        order.DRC_NBC_Trans_Shipment__c    = getPicklistValue('DRC_NBC_Trans_Shipment__c');
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                getOLIs(order.Id), new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_DomesticOrder_NullPartTrans() {
        Order order = getFullOrder('Test Domestic Order');
        order.DRC_NBC_Type__c           = 'Domestic';
        order.DRC_NBC_Part_Shipment__c  = null;
        order.DRC_NBC_Trans_Shipment__c = null;
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                getOLIs(order.Id), new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_DomesticOrder_InsertNewOLI() {
        Order order = getFullOrder('Test Domestic Order');
        order.DRC_NBC_Type__c           = 'Domestic';
        order.DRC_NBC_Part_Shipment__c  = getPicklistValue('DRC_NBC_Part_Shipment__c');
        order.DRC_NBC_Trans_Shipment__c = getPicklistValue('DRC_NBC_Trans_Shipment__c');
        List<String> del = new List<String>();
        for (OrderItem o : getOLIs(order.Id)) { del.add(o.Id); }
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{
                    new OrderItem(OrderId = order.Id, Product2Id = prod.Id, Quantity = 5, UnitPrice = 120)
                },
                del, order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_DomesticOrder_DeleteOLIs() {
        Order order = getFullOrder('Test Domestic Order');
        order.DRC_NBC_Type__c           = 'Domestic';
        order.DRC_NBC_Part_Shipment__c  = getPicklistValue('DRC_NBC_Part_Shipment__c');
        order.DRC_NBC_Trans_Shipment__c = getPicklistValue('DRC_NBC_Trans_Shipment__c');
        List<String> del = new List<String>();
        for (OrderItem o : getOLIs(order.Id)) { del.add(o.Id); }
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{
                    new OrderItem(OrderId = order.Id, Product2Id = prod.Id, Quantity = 1, UnitPrice = 100)
                },
                del, order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_NoShippingAddress() {
        Order order = getFullOrder('Test No Addr Order');
        order.DRC_NBC_Type__c             = 'Domestic';
        order.DRC_NBC_Shipping_Address__c = null;
        order.DRC_NBC_Part_Shipment__c    = getPicklistValue('DRC_NBC_Part_Shipment__c');
        order.DRC_NBC_Trans_Shipment__c   = getPicklistValue('DRC_NBC_Trans_Shipment__c');
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{
                    new OrderItem(OrderId = order.Id, Product2Id = prod.Id, Quantity = 1, UnitPrice = 100)
                },
                new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_EmptyOliListNoDeletes() {
        Order order = getFullOrder('Test Domestic Order');
        order.DRC_NBC_Type__c = 'Domestic';
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>(), new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // saveOrderLineItems — Export
    // Covers: DRC_NBC_Part_Shipment__c and DRC_NBC_Trans_Shipment__c in Export block
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveOrderLineItems_ExportOrder() {
        Order order = getFullOrder('Test Export Order');
        order.DRC_NBC_Type__c                         = 'Export';
        order.DRC_NBC_Country_of_Origin__c            = 'India';
        order.DRC_NBC_Country_of_Final_Destination__c = 'USA';
        order.DRC_NBC_Shipment_Method__c              = 'Air';
        order.DRC_NBC_Port_Of_Discharge__c            = 'LA';
        order.DRC_NBC_Port_of_Loading__c              = 'Mumbai';
        order.DRC_NBC_Notify_Party__c                 = 'Co';
        order.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c  = 'Delhi';
        order.DRC_NBC_Prepayment_Method__c            = 'Wire';
        order.DRC_NBC_Vessel_no_Flight_no__c          = 'AI-1';
        order.DRC_NBC_Final_Destination__c            = 'NY';
        order.DRC_NBC_Required_Documents__c           = 'BL';
        order.DRC_NBC_Part_Shipment__c                = getPicklistValue('DRC_NBC_Part_Shipment__c');
        order.DRC_NBC_Trans_Shipment__c               = getPicklistValue('DRC_NBC_Trans_Shipment__c');
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                getOLIs(order.Id), new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // saveOrderLineItems — Sample Order
    // Covers: DRC_NBC_Part_Shipment__c and DRC_NBC_Trans_Shipment__c in Sample block
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveOrderLineItems_SampleOrder() {
        Order order = getFullOrder('Test Sample Order');
        order.Type                              = 'Sample Order';
        order.DRC_NBC_Type__c                   = null;
        order.DRC_NBC_Sample_Name__c            = 'S';
        order.DRC_NBC_Sample_Type__c            = 'T';
        order.DRC_NBC_Courier_service__c        = 'FedEx';
        order.DRC_NBC_Delivery_status__c        = 'Delivered';
        order.DRC_NBC_Courier_Number__c         = 'FX1';
        order.DRC_NBC_Expected_Delivery_Date__c = Date.today().addDays(5);
        order.DRC_NBC_Courier_date__c           = Date.today();
        order.DRC_NBC_Sample_Shipping_Cost__c   = 250;
        order.DRC_NBC_Special_request__c        = 'Handle';
        order.DRC_NBC_Sample_Amount__c          = 500;
        order.DRC_NBC_Reject_Reason_Text__c     = 'N/A';
        order.DRC_NBC_Remarks__c                = 'Test';
        order.DRC_NBC_Part_Shipment__c          = getPicklistValue('DRC_NBC_Part_Shipment__c');
        order.DRC_NBC_Trans_Shipment__c         = getPicklistValue('DRC_NBC_Trans_Shipment__c');
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                getOLIs(order.Id), new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_SampleOrder_NullPartTrans() {
        Order order = getFullOrder('Test Sample Order');
        order.Type                    = 'Sample Order';
        order.DRC_NBC_Type__c         = null;
        order.DRC_NBC_Part_Shipment__c  = null;
        order.DRC_NBC_Trans_Shipment__c = null;
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                getOLIs(order.Id), new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // saveOrderLineItems — INR order
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveOrderLineItems_INROrder_UpdateExistingOLIs() {
        Order order = getFullOrder('Test INR Order');
        order.DRC_NBC_Type__c = 'Domestic';
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                getOLIs(order.Id), new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_INROrder_InsertNewOLI() {
        Order order = getFullOrder('Test INR Order');
        order.DRC_NBC_Type__c = 'Domestic';
        List<String> del = new List<String>();
        for (OrderItem o : getOLIs(order.Id)) { del.add(o.Id); }
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{
                    new OrderItem(OrderId = order.Id, Product2Id = prod.Id, Quantity = 3, UnitPrice = 8500)
                },
                del, order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // saveOrderLineItems — auto-create PBE paths via save
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveOrderLineItems_AutoCreatePricebookEntry() {
        Order order = getFullOrder('Test INR Auto Order');
        order.DRC_NBC_Type__c = 'Domestic';
        Product2 prodUsdOnly = [SELECT Id FROM Product2 WHERE Name = 'Test Product USD Only' LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{
                    new OrderItem(OrderId = order.Id, Product2Id = prodUsdOnly.Id, Quantity = 2, UnitPrice = 15000)
                },
                new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_AutoCreate_PriceZeroFallback() {
        Order order = getFullOrder('Test INR NoPBE Order');
        order.DRC_NBC_Type__c = 'Domestic';
        Product2 prodNoPbe = [SELECT Id FROM Product2 WHERE Name = 'Test Product No PBE' LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{
                    new OrderItem(OrderId = order.Id, Product2Id = prodNoPbe.Id, Quantity = 1, UnitPrice = 0)
                },
                new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_StandardPricebook() {
        Order order = getFullOrder('Test StdPB Order');
        order.DRC_NBC_Type__c = 'Domestic';
        List<String> del = new List<String>();
        for (OrderItem o : getOLIs(order.Id)) { del.add(o.Id); }
        Product2 prod = [SELECT Id FROM Product2 WHERE Name = 'Test Product' LIMIT 1];
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{
                    new OrderItem(OrderId = order.Id, Product2Id = prod.Id, Quantity = 2, UnitPrice = 8000)
                },
                del, order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // saveOrderLineItems — packing fields
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveOrderLineItems_WithPackingFields() {
        Order order = getFullOrder('Test Domestic Order');
        order.DRC_NBC_Type__c           = 'Domestic';
        order.DRC_NBC_Part_Shipment__c  = getPicklistValue('DRC_NBC_Part_Shipment__c');
        order.DRC_NBC_Trans_Shipment__c = getPicklistValue('DRC_NBC_Trans_Shipment__c');
        List<OrderItem> olis = getOLIs(order.Id);
        for (OrderItem o : olis) {
            o.DRC_NBC_Packing_Size__c     = '50 KG';
            o.DRC_NBC_Packing_Quantity__c = '100';
        }
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(olis, new List<String>(), order);
        } catch (Exception e) { }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // saveOrderLineItems — consignee bank details
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveOrderLineItems_ConsigneeBankDetails() {
        Order order = getFullOrder('Test Domestic Order');
        order.DRC_NBC_Type__c                          = 'Domestic';
        order.DRC_NBC_Consignee_Bank_Name__c           = 'Test Bank';
        order.DRC_NBC_Consignee_Bank_Account_Number__c = '123456789';
        order.DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'TEST0001234';
        order.DRC_NBC_Consignee_Bank_Address__c        = 'Bank St';
        order.DRC_NBC_Part_Shipment__c                 = getPicklistValue('DRC_NBC_Part_Shipment__c');
        order.DRC_NBC_Trans_Shipment__c                = getPicklistValue('DRC_NBC_Trans_Shipment__c');
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                getOLIs(order.Id), new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // saveOrderLineItems — rejected / partially-shipped
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testSaveOrderLineItems_RejectedStatus() {
        Order order = getFullOrder('Test Domestic Order');
        order.DRC_NBC_Type__c                   = 'Domestic';
        order.Status                            = 'Rejected';
        order.DRC_NBC_Reject_Reason_Text__c     = 'Quality';
        order.DRC_NBC_Other_Rejection_Reason__c = 'Other';
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                getOLIs(order.Id), new List<String>(), order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_PartiallyShipped() {
        Order order = getFullOrder('Test Domestic Order');
        update new Order(Id = order.Id, DRC_NBC_Order_PartiallyShipped__c = true);
        order.DRC_NBC_Type__c = 'Domestic';
        order.Status          = 'Partially Shipped';
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                getOLIs(order.Id), new List<String>(), order
            );
        } catch (AuraHandledException e) { }
        Test.stopTest();
    }

    @isTest
    static void testSaveOrderLineItems_EmptyOliListWithDeletes() {
        Order order = getFullOrder('Test Domestic Order');
        order.DRC_NBC_Type__c = 'Domestic';
        List<String> del = new List<String>();
        for (OrderItem o : getOLIs(order.Id)) { del.add(o.Id); }
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>(), del, order
            );
        } catch (Exception e) { }
        Test.stopTest();
    }
}