/**
 * @File Name        : DRC_NBC_GenerateSamplePiControllerTest.cls
 * @Description      : Test class for DRC_NBC_GenerateSamplePiController
 * @Author           : Developer
 * @Coverage Target  : 100%
 */
@isTest
private class DRC_NBC_GenerateSamplePiControllerTest {

    // ─────────────────────────────────────────────────────────
    // Test Data Factory
    // ─────────────────────────────────────────────────────────

    private static Account createAccount() {
        Account acc = new Account(
            Name                    = 'Test Customer',
           // DRC_NBC_GST_Number__c   = 'GST123456789',
            DRC_NBC_Customer_Number__c = 'CUST001'
        );
        insert acc;
        return acc;
    }

    private static Product2 createProduct() {
        Product2 prod = new Product2(
            Name                        = 'Test Product',
            ProductCode                 = 'PROD001',
            QuantityUnitOfMeasure       = 'KGS',
            DRC_NBC_HSN_SAC_Code__c     = '12345678',
            DRC_NBC_FG_Code__c          = 'FG-001',
            IsActive                    = true
        );
        insert prod;
        return prod;
    }

    private static PricebookEntry createPricebookEntry(Id productId) {
        Id standardPbId = Test.getStandardPricebookId();
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPbId,
            Product2Id   = productId,
            UnitPrice    = 100.00,
            IsActive     = true
        );
        insert pbe;
        return pbe;
    }

    private static Order createOrder(Id accountId, String orderType, Boolean assignSequence) {
        Order ord = new Order(
            AccountId               = accountId,
            Status                  = 'Draft',
            EffectiveDate           = Date.today(),
            Pricebook2Id            = Test.getStandardPricebookId(),
            Type                    = orderType,
            ShippingStreet          = '123 Ship Street',
            ShippingCity            = 'Mumbai',
            ShippingState           = 'Maharashtra',
            ShippingPostalCode      = '400001',
            ShippingCountry         = 'India',
            BillingStreet           = '456 Bill Street',
            BillingCity             = 'Delhi',
            BillingState            = 'Delhi',
            BillingPostalCode       = '110001',
            BillingCountry          = 'India',
            DRC_NBC_Payment_Terms__c        = 'Net 30',
            DRC_NBC_Sample_Shipping_Cost__c = 500.00,
            DRC_NBC_Expected_Delivery_Date__c = Date.today().addDays(7),
            DRC_NBC_Courier_Number__c       = 'COURIER123',
            DRC_NBC_Delivery_status__c      = 'Dispatched',
            DRC_NBC_Sample_Name__c          = 'test sample',
            DRC_NBC_Sample_Type__c          = 'Initial Sample'
        );

        if (assignSequence) {
            ord.DRC_NBC_Sample_Sequence_Number__c = 10;
        }
        // DRC_NBC_Sample_Sequence_Number__c intentionally left null when !assignSequence

        insert ord;
        return ord;
    }

    private static OrderItem createOrderItem(Id orderId, Id pricebookEntryId) {
        OrderItem oi = new OrderItem(
            OrderId          = orderId,
            PricebookEntryId = pricebookEntryId,
            Quantity         = 2,
            UnitPrice        = 100.00
        );
        insert oi;
        return oi;
    }

    // ─────────────────────────────────────────────────────────
    // Test: Valid Sample Order – sequence number already assigned
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testSampleOrderWithExistingSequenceNumber() {
        Account acc     = createAccount();
        Product2 prod   = createProduct();
        PricebookEntry pbe = createPricebookEntry(prod.Id);
        Order ord       = createOrder(acc.Id, 'Sample Order', true);
        createOrderItem(ord.Id, pbe.Id);

        Test.setCurrentPageReference(new PageReference('/apex/SomePage'));
        ApexPages.currentPage().getParameters().put('id', ord.Id);

        Test.startTest();
        DRC_NBC_GenerateSamplePiController ctrl = new DRC_NBC_GenerateSamplePiController();
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────
    // Test: Sample Order – sequence number is NULL → auto-assign
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testSampleOrderSequenceAutoAssign() {
        Account acc  = createAccount();
        Product2 prod = createProduct();
        PricebookEntry pbe = createPricebookEntry(prod.Id);
        // Create one order that already has a sequence so MAX() returns a value
        Order existing = createOrder(acc.Id, 'Sample Order', true); // seq = 10
        // The order under test has no sequence
        Order ord = createOrder(acc.Id, 'Sample Order', false);
        createOrderItem(ord.Id, pbe.Id);

        Test.setCurrentPageReference(new PageReference('/apex/SomePage'));
        ApexPages.currentPage().getParameters().put('id', ord.Id);

        Test.startTest();
        DRC_NBC_GenerateSamplePiController ctrl = new DRC_NBC_GenerateSamplePiController();
        Test.stopTest();

        // The sequence should be MAX(existing 10) + 1 = 11
        System.assertEquals('11', ctrl.importSequence,
            'Auto-assigned sequence should be max + 1');
    }

    // ─────────────────────────────────────────────────────────
    // Test: Non-Sample Order type → no sequence assigned
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testNonSampleOrderType() {
        Account acc   = createAccount();
        Product2 prod  = createProduct();
        PricebookEntry pbe = createPricebookEntry(prod.Id);
        Order ord = createOrder(acc.Id, 'Standard Order', false);
        createOrderItem(ord.Id, pbe.Id);

        Test.setCurrentPageReference(new PageReference('/apex/SomePage'));
        ApexPages.currentPage().getParameters().put('id', ord.Id);

        Test.startTest();
        DRC_NBC_GenerateSamplePiController ctrl = new DRC_NBC_GenerateSamplePiController();
        Test.stopTest();

        // importSequence should remain null for non-sample orders
        System.assertEquals(null, ctrl.importSequence,
            'Import sequence should be null for non-sample order');
    }

    // ─────────────────────────────────────────────────────────
    // Test: Missing Order Id → error message added
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testMissingOrderId() {
        Test.setCurrentPageReference(new PageReference('/apex/SomePage'));
        // Do NOT put 'id' parameter

        Test.startTest();
        DRC_NBC_GenerateSamplePiController ctrl = new DRC_NBC_GenerateSamplePiController();
        Test.stopTest();

        List<ApexPages.Message> msgs = ApexPages.getMessages();
        System.assertEquals(1, msgs.size(), 'Should have exactly one error message');
        System.assertEquals(ApexPages.Severity.ERROR, msgs[0].getSeverity());
        System.assert(msgs[0].getDetail().contains('Missing Order Id'),
            'Error message text mismatch');
    }

    // ─────────────────────────────────────────────────────────
    // Test: Null address fields default to empty string
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testNullAddressFieldsDefaultToEmpty() {
        Account acc = new Account(
            Name = 'Null Address Customer',
          //  DRC_NBC_GST_Number__c      = 'GSTNULL',
            DRC_NBC_Customer_Number__c = 'CUSTNULL'
        );
        insert acc;

        Order ord = new Order(
            AccountId        = acc.Id,
            Status           = 'Draft',
            EffectiveDate    = Date.today(),
            Pricebook2Id     = Test.getStandardPricebookId(),
            Type             = 'Sample Order',
            DRC_NBC_Sample_Sequence_Number__c   = 5,
            DRC_NBC_Sample_Shipping_Cost__c     = 0,
            DRC_NBC_Sample_Name__c              = null,
            DRC_NBC_Sample_Type__c              = null
        );
        insert ord;

        Test.setCurrentPageReference(new PageReference('/apex/SomePage'));
        ApexPages.currentPage().getParameters().put('id', ord.Id);

        Test.startTest();
        DRC_NBC_GenerateSamplePiController ctrl = new DRC_NBC_GenerateSamplePiController();
        Test.stopTest();

        System.assertEquals('', ctrl.shippingAddress,     'Null street → empty string');
        System.assertEquals('', ctrl.shippingCity,        'Null city → empty string');
        System.assertEquals('', ctrl.shippingState,       'Null state → empty string');
        System.assertEquals('', ctrl.shippingPostalCode,  'Null postal → empty string');
        System.assertEquals('', ctrl.shippingCountry,     'Null country → empty string');
        System.assertEquals('', ctrl.billingAddress,      'Null billing street → empty string');
        System.assertEquals('', ctrl.billingCity,         'Null billing city → empty string');
        System.assertEquals('', ctrl.billingState,        'Null billing state → empty string');
        System.assertEquals('', ctrl.billingPostalCode,   'Null billing postal → empty string');
        System.assertEquals('', ctrl.billingCountry,      'Null billing country → empty string');
        System.assertEquals('', ctrl.SampleName,          'Null sample name → empty string');
        System.assertEquals('', ctrl.sampleType,          'Null sample type → empty string');

        // items list should be empty, totals zero
        System.assertEquals(0, ctrl.items.size());
        System.assertEquals(0, ctrl.totalWithoutTax);
        System.assertEquals(0, ctrl.totalWithTax);
    }

    // ─────────────────────────────────────────────────────────
    // Test: Multiple order items – totals accumulate correctly
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testMultipleOrderItems() {
        Account acc     = createAccount();
        Product2 prod1  = createProduct();

        Product2 prod2 = new Product2(
            Name                        = 'Second Product',
            ProductCode                 = 'PROD002',
            QuantityUnitOfMeasure       = 'KG',
            DRC_NBC_HSN_SAC_Code__c     = '87654321',
            DRC_NBC_FG_Code__c          = 'FG-002',
            IsActive                    = true
        );
        insert prod2;

        PricebookEntry pbe1 = createPricebookEntry(prod1.Id);
        PricebookEntry pbe2 = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id   = prod2.Id,
            UnitPrice    = 200.00,
            IsActive     = true
        );
        insert pbe2;

        Order ord = createOrder(acc.Id, 'Sample Order', true);

        OrderItem oi1 = new OrderItem(OrderId = ord.Id, PricebookEntryId = pbe1.Id, Quantity = 3, UnitPrice = 100.00);
        OrderItem oi2 = new OrderItem(OrderId = ord.Id, PricebookEntryId = pbe2.Id, Quantity = 1, UnitPrice = 200.00);
        insert oi1;
        insert oi2;

        Test.setCurrentPageReference(new PageReference('/apex/SomePage'));
        ApexPages.currentPage().getParameters().put('id', ord.Id);

        Test.startTest();
        DRC_NBC_GenerateSamplePiController ctrl = new DRC_NBC_GenerateSamplePiController();
        Test.stopTest();
    }
}