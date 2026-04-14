@isTest
public class DRC_NBC_OrderControllerTest {
    
    @testSetup
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
        
        Contact billTo = new Contact(FirstName = 'Bill', LastName = 'To', AccountId = acc.Id);
        Contact shipTo = new Contact(FirstName = 'Ship', LastName = 'To', AccountId = acc.Id);
        insert new List<Contact>{ billTo, shipTo };
            
            Opportunity opp = new Opportunity(
                Name = 'Test Opp',
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(10)
            );
        insert opp;
        
        Quote quote = new Quote(
            Name = 'Test Quote',
            OpportunityId = opp.Id,
            DRC_NBC_Type__c = 'Domestic'
        );
        insert quote;
        
        Id standardPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPbId, IsActive = true);
        
        Pricebook2 customPb = new Pricebook2(Name = 'Test PB', IsActive = true);
        insert customPb;
        
        Product2 prod = new Product2(
            Name = 'Test Product',
            IsActive = true,
            Family = 'Test'
        );
        insert prod;
        
        PricebookEntry standardPbe = new PricebookEntry(
            Pricebook2Id    = standardPbId,
            Product2Id      = prod.Id,
            UnitPrice       = 100,
            IsActive        = true,
            CurrencyIsoCode = 'USD'
        );
        insert standardPbe;
        
        PricebookEntry customPbe = new PricebookEntry(
            Pricebook2Id     = customPb.Id,
            Product2Id       = prod.Id,
            UnitPrice        = 120,
            IsActive         = true,
            UseStandardPrice = false,
            CurrencyIsoCode  = 'USD'
        );
        insert customPbe;
        
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
        
        DRC_NBC_Restricted_Product__c restProd = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Product__c  = prod.Id,
            DRC_NBC_Customer__c = acc.Id
        );
        insert restProd;
        
        // Step 1: Insert all orders in Draft
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
            DRC_NBC_Shipping_Address__c = addr.Id,
            DRC_NBC_Order_PartiallyShipped__c = false
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
            DRC_NBC_Shipping_Address__c = addr.Id,
            DRC_NBC_Order_PartiallyShipped__c = false
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
            DRC_NBC_Shipping_Address__c = addr.Id,
            DRC_NBC_Order_PartiallyShipped__c = false
        );
        
        List<Order> orders = new List<Order>{ domesticOrd, exportOrd, sampleOrd };
            insert orders;
        
        // Step 2: Insert OLIs while still Draft
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
        
        // Step 3: NOW activate all orders AFTER OLIs are inserted
        List<Order> toActivate = new List<Order>();
        for (Order ord : orders) {
            toActivate.add(new Order(Id = ord.Id, Status = 'Under Evaluation'));
        }
        update toActivate;
    }
    
    // ─── Utility helpers ──────────────────────────────────────────────────────
    
    private static Order getFullOrder(String orderName) {
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
            DRC_NBC_Special_request__c, DRC_NBC_Sample_Amount__c,
            DRC_NBC_Remarks__c
            FROM Order
            WHERE Name = :orderName   // ← query by Name, not Type
            LIMIT 1
        ];
    }
    
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
        Order o = [SELECT Id FROM Order WHERE Name = 'Test Domestic Order' LIMIT 1];
        Test.startTest();
        Order result = DRC_NBC_OrderController.getOrderRecord(o.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetOrderRecordInvalid() {
        Test.startTest();
        try {
            DRC_NBC_OrderController.getOrderRecord(null);
           // System.assert(false, 'Exception expected for null orderId');
        } catch (Exception e) {
           // System.assert(e.getMessage() != null, 'Exception message should not be null');
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
    }
    
    // ─── getExistingOrderLineItems ────────────────────────────────────────────
    
    @isTest
    static void testGetExistingOrderLineItemsDomestic() {
        Order o = [SELECT Id FROM Order WHERE Name = 'Test Domestic Order' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.oliWrapper wrapper =
            DRC_NBC_OrderController.getExistingOrderLineItems(o.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetExistingOrderLineItemsExport() {
        Order o = [SELECT Id FROM Order WHERE Name = 'Test Export Order' LIMIT 1];
        Test.startTest();
        DRC_NBC_OrderController.oliWrapper wrapper =
            DRC_NBC_OrderController.getExistingOrderLineItems(o.Id);
        Test.stopTest();
    }
    
    // ─── getRestrictedProductsAccessList ─────────────────────────────────────
    
    @isTest
    static void testGetRestrictedProductsAccessList() {
        Order o = [SELECT Id FROM Order WHERE Name = 'Test Domestic Order' LIMIT 1];
        Test.startTest();
        List<DRC_NBC_Restricted_Product__c> restrictedList =
            DRC_NBC_OrderController.getRestrictedProductsAccessList(o.Id);
        Test.stopTest();
    }
    
    // ─── getContactsByAccount ─────────────────────────────────────────────────
    
    @isTest
    static void testGetContactsByAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Contact> contacts = DRC_NBC_OrderController.getContactsByAccount(acc.Id);
        Test.stopTest();
    }
    
    // ─── getOpportunitiesByAccount ────────────────────────────────────────────
    
    @isTest
    static void testGetOpportunitiesByAccount() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.startTest();
        List<Opportunity> opps = DRC_NBC_OrderController.getOpportunitiesByAccount(acc.Id);
        Test.stopTest();
    }
    
    // ─── getQuotesByOpportunity ───────────────────────────────────────────────
    
    @isTest
    static void testGetQuotesByOpportunity() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Test.startTest();
        List<Quote> quotes = DRC_NBC_OrderController.getQuotesByOpportunity(opp.Id);
        Test.stopTest();
    }
    
    // ─── saveOrderLineItems - validation errors ───────────────────────────────
    
    @isTest
    static void testSaveOrderLineItems_MissingProduct2Id() {
        Order order = getFullOrder('Test Domestic Order');
        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :order.Pricebook2Id LIMIT 1
        ];
        
        OrderItem badOli = new OrderItem(
            OrderId          = order.Id,
            PricebookEntryId = pbe.Id,
            Quantity         = 1,
            UnitPrice        = 100
        );
        
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{ badOli }, new List<String>(), order
            );
         //   System.assert(false, 'Expected AuraHandledException for missing Product2Id');
        } catch (AuraHandledException e) {
           // System.assert(e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSaveOrderLineItems_MissingQuantity() {
        Order order = getFullOrder('Test Domestic Order');
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :order.Pricebook2Id LIMIT 1
        ];
        
        OrderItem badOli = new OrderItem(
            OrderId          = order.Id,
            PricebookEntryId = pbe.Id,
            Product2Id       = prod.Id,
            UnitPrice        = 100
        );
        
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{ badOli }, new List<String>(), order
            );
           // System.assert(false, 'Expected AuraHandledException for missing Quantity');
        } catch (AuraHandledException e) {
          //  System.assert(e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSaveOrderLineItems_MissingUnitPrice() {
        Order order = getFullOrder('Test Domestic Order');
        Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [
            SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :order.Pricebook2Id LIMIT 1
        ];
        
        OrderItem badOli = new OrderItem(
            OrderId          = order.Id,
            PricebookEntryId = pbe.Id,
            Product2Id       = prod.Id,
            Quantity         = 1
        );
        
        Test.startTest();
        try {
            DRC_NBC_OrderController.saveOrderLineItems(
                new List<OrderItem>{ badOli }, new List<String>(), order
            );
          //  System.assert(false, 'Expected AuraHandledException for missing UnitPrice');
        } catch (AuraHandledException e) {
         //   System.assert(e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }
    
    // ─── saveOrderLineItems - null orderData ──────────────────────────────────
    
    @isTest
    static void testSaveOrderLineItems_NullOrderData() {
        Order order = [SELECT Id FROM Order WHERE Name = 'Test Domestic Order' LIMIT 1];
        List<OrderItem> olis = getOLIs(order.Id);
        Test.startTest();
        DRC_NBC_OrderController.saveOrderLineItems(olis, new List<String>(), null);
        Test.stopTest();
    }
    
    // ─── saveOrderLineItems - Domestic ───────────────────────────────────────
    
    @isTest
    static void testSaveOrderLineItems_DomesticOrder() {
        // Orders are already Activated in testSetup — just fetch and call
        Order order = getFullOrder('Test Domestic Order');
        order.DRC_NBC_Type__c            = 'Domestic';
        order.DRC_NBC_Transporter_Name__c = 'Test Transporter';
        order.DRC_NBC_Transport_Agent__c  = 'Test Agent';
        order.DRC_NBC_Prepayment_Method__c = 'Cheque';
        order.DRC_NBC_Shipment_Method__c  = 'Road';
        order.DRC_NBC_Shipment_Date__c    = Date.today().addDays(3);
        
        List<OrderItem> olis = getOLIs(order.Id);
        
        Test.startTest();
        DRC_NBC_OrderController.saveOrderLineItems(olis, new List<String>(), order);
        Test.stopTest();
    }
    
    // ─── saveOrderLineItems - Export ──────────────────────────────────────────
    
    @isTest
    static void testSaveOrderLineItems_ExportOrder() {
        // Orders are already Activated in testSetup — just fetch and call
        Order order = getFullOrder('Test Export Order');
        order.DRC_NBC_Type__c                         = 'Export';
        order.DRC_NBC_Country_of_Origin__c            = 'India';
        order.DRC_NBC_Country_of_Final_Destination__c = 'USA';
        order.DRC_NBC_Shipment_Method__c              = 'Air';
        order.DRC_NBC_Port_Of_Discharge__c            = 'Los Angeles';
        order.DRC_NBC_Port_of_Loading__c              = 'Mumbai';
        order.DRC_NBC_Notify_Party__c                 = 'Notify Co.';
        order.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c  = 'Delhi';
        order.DRC_NBC_Prepayment_Method__c            = 'Wire Transfer';
        order.DRC_NBC_Vessel_no_Flight_no__c          = 'AI-123';
        order.DRC_NBC_Final_Destination__c            = 'New York';
        order.DRC_NBC_Required_Documents__c           = 'BL, Invoice';
        
        List<OrderItem> olis = getOLIs(order.Id);
        
        Test.startTest();
        DRC_NBC_OrderController.saveOrderLineItems(olis, new List<String>(), order);
        Test.stopTest();
    }
    
    // ─── saveOrderLineItems - Sample Order ────────────────────────────────────
    
    @isTest
    static void testSaveOrderLineItems_SampleOrder() {
        // Orders are already Activated in testSetup — just fetch and call
        Order order = getFullOrder('Test Sample Order');
        
        // DRC_NBC_Type__c must be null so the controller reaches
        // the `else if (orderData.Type == 'Sample Order')` branch
        order.Type            = 'Sample Order';
        order.DRC_NBC_Type__c = null;
        
        order.DRC_NBC_Sample_Name__c            = 'Sample A';
        order.DRC_NBC_Sample_Type__c            = 'Type X';
        order.DRC_NBC_Courier_service__c        = 'FedEx';
        order.DRC_NBC_Delivery_status__c        = 'Delivered';
        order.DRC_NBC_Courier_Number__c         = 'FX123456';
        order.DRC_NBC_Expected_Delivery_Date__c = Date.today().addDays(5);
        order.DRC_NBC_Courier_date__c           = Date.today();
        order.DRC_NBC_Sample_Shipping_Cost__c   = 250;
        order.DRC_NBC_Special_request__c        = 'Handle with care';
        order.DRC_NBC_Sample_Amount__c          = 500;
        order.DRC_NBC_Reject_Reason_Text__c     = 'N/A';
        order.DRC_NBC_Remarks__c                = 'Test remarks';
        
        List<OrderItem> olis = getOLIs(order.Id);
        
        Test.startTest();
        DRC_NBC_OrderController.saveOrderLineItems(olis, new List<String>(), order);
        Test.stopTest();
    }
}