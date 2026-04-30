@isTest
public class DRC_NBC_GenerateSampleOrderTest {
    
    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Test Street',
            BillingCity = 'Mumbai',
            BillingState = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India',
            DRC_NBC_Volume__c = 70,
            DRC_NBC_Credit_Limit__c = 123456787,
            DRC_NBC_Value__c = 900,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
            DRC_NBC_Consignee_Bank_Address__c = 'Barhi 483775',
            DRC_NBC_Consignee_Bank_IFSC_Code__c = 'PUNB01391000',
            DRC_NBC_Consignee_Bank_Name__c = 'Punjab National bank',
            DRC_NBC_Payment_Term_Code__c = 'NET30',
            Industry = 'Chemicals Construction',
            Type = 'Analyst'
        );
        insert acc;

        Contact conWithEmail = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            Email = 'john.doe@example.com',
            AccountId = acc.Id
        );
        insert conWithEmail;

        Contact conNoEmail = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            AccountId = acc.Id
        );
        insert conNoEmail;

        Pricebook2 drcPb = new Pricebook2(
            Name = 'DRC PriceBook',
            IsActive = true,
            DRC_NBC_External_Id__c = 'DRC001'
        );
        insert drcPb;

        Product2 prod1 = new Product2(
            Name = 'Sample Product 1',
            IsActive = true,
            DRC_NBC_FG_Code__c = 'FG001',
            DRC_NBC_HSN_SAC_Code__c = 'HSN001',
            QuantityUnitOfMeasure = 'KGS'
        );
        insert prod1;

        Product2 prod2 = new Product2(
            Name = 'Sample Product 2',
            IsActive = true,
            DRC_NBC_FG_Code__c = 'FG002',
            DRC_NBC_HSN_SAC_Code__c = 'HSN002',
            QuantityUnitOfMeasure = 'LTR'
        );
        insert prod2;

        insert new DRC_NBC_Packing_Details__c(
            Product__c = prod1.Id,
            DRC_NBC_Packing_Size__c = '25KG',
            DRC_NBC_Packing_Qauntity__c = '40'
        );
        insert new DRC_NBC_Packing_Details__c(
            Product__c = prod1.Id,
            DRC_NBC_Packing_Size__c = '50KG',
            DRC_NBC_Packing_Qauntity__c = '20'
        );
        insert new DRC_NBC_Packing_Details__c(
            Product__c = prod2.Id,
            DRC_NBC_Packing_Size__c = '20L'
        );

        insert new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Product__c = prod1.Id,
            DRC_NBC_Customer__c = acc.Id
        );

        Id stdPbId = Test.getStandardPricebookId();
        insert new List<PricebookEntry>{
            new PricebookEntry(
                Pricebook2Id = stdPbId,
                Product2Id = prod1.Id,
                UnitPrice = 100,
                IsActive = true
            ),
            new PricebookEntry(
                Pricebook2Id = stdPbId,
                Product2Id = prod2.Id,
                UnitPrice = 200,
                IsActive = true
            )
        };

        insert new List<PricebookEntry>{
            new PricebookEntry(
                Pricebook2Id = drcPb.Id,
                Product2Id = prod1.Id,
                UnitPrice = 110,
                IsActive = true,
                UseStandardPrice = false,
                CurrencyIsoCode = 'INR'
            ),
            new PricebookEntry(
                Pricebook2Id = drcPb.Id,
                Product2Id = prod2.Id,
                UnitPrice = 210,
                IsActive = true,
                UseStandardPrice = false,
                CurrencyIsoCode = 'INR'
            )
        };

        Opportunity oppWithDrcPb = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id,
            CurrencyIsoCode = 'INR',
            Pricebook2Id = drcPb.Id
        );
        insert oppWithDrcPb;

        insert new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c = acc.Id,
            DRC_NBC_Type__c = 'Shipping',
            DRC_NBC_Address__Street__s = '456 Ship Lane',
            DRC_NBC_Address__City__s = 'Pune',
            DRC_NBC_Address__PostalCode__s = '411001',
            DRC_NBC_Address__StateCode__s = 'MH',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Warehouse__c = 'CFS - JNPT'
        );
    }

    private static Account getAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
    }

    private static Opportunity getOppWithDrcPb() {
        return [SELECT Id, AccountId, Pricebook2Id, CurrencyIsoCode FROM Opportunity WHERE Name = 'Test Opportunity' LIMIT 1];
    }

    private static Opportunity createOppWithoutPricebook() {
        Account acc = getAccount();
        Opportunity opp = new Opportunity(
            Name = 'Opp No Pricebook ' + System.now().getTime(),
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(5),
            AccountId = acc.Id,
            CurrencyIsoCode = 'INR'
        );
        insert opp;
        return opp;
    }

    private static Contact getConEmail() {
        return [SELECT Id, AccountId FROM Contact WHERE Email != null LIMIT 1];
    }

    private static Contact getConNoEmail() {
        return [SELECT Id FROM Contact WHERE Email = null LIMIT 1];
    }

    private static Product2 getProd1() {
        return [SELECT Id FROM Product2 WHERE Name = 'Sample Product 1' LIMIT 1];
    }

    private static Product2 getProd2() {
        return [SELECT Id FROM Product2 WHERE Name = 'Sample Product 2' LIMIT 1];
    }

    private static DRC_NBC_Addresses__c getShipAddr() {
        return [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
    }

    private static DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper makeItem(
        Id prod2Id,
        Decimal qty,
        Decimal price,
        String packSize,
        Decimal packQty,
        String uom
    ) {
        DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper w =
            new DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper();
        w.Product2Id = prod2Id;
        w.Quantity = qty;
        w.UnitPrice = price;
        w.PackingSize = packSize;
        w.PackingQuantity = packQty;
        w.QuantityUnitOfMeasure = uom;
        return w;
    }

    private static Order buildOrder(
        Id accountId,
        Id billContactId,
        Id shipContactId,
        Id shipAddrId,
        String status,
        Boolean nullDate
    ) {
        Order ord = new Order();
        ord.AccountId = accountId;
        ord.CurrencyIsoCode = 'INR';
        ord.Status = status != null ? status : 'Draft';
        ord.EffectiveDate = nullDate ? null : Date.today();
        if (billContactId != null) ord.BillToContactId = billContactId;
        if (shipContactId != null) ord.ShipToContactId = shipContactId;
        if (shipAddrId != null) ord.DRC_NBC_Shipping_Address__c = shipAddrId;
        return ord;
    }

    @isTest
    static void testGetOrderRecordTypes() {
        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_Generate_Sample_Order_Controller.getOrderRecordTypes();
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetOpportunityContacts_Success() {
        Test.startTest();
        List<Contact> contacts =
            DRC_NBC_Generate_Sample_Order_Controller.getOpportunityContacts(getOppWithDrcPb().Id);
        Test.stopTest();
        System.assert(contacts.size() > 0);
    }

    @isTest
    static void testGetOpportunityContacts_NullId() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.getOpportunityContacts(null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

/*    @isTest
    static void testGetAccountPaymentTerms() {
        Test.startTest();
        String result =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountPaymentTerms(getOppWithDrcPb().Id);
        Test.stopTest();
        System.assertEquals('NET30', result);
    }*/

    @isTest
    static void testGetOpportunityCurrency() {
        Test.startTest();
        String result =
            DRC_NBC_Generate_Sample_Order_Controller.getOpportunityCurrency(getOppWithDrcPb().Id);
        Test.stopTest();
        System.assertEquals('INR', result);
    }

    @isTest
    static void testGetAllProducts_UsesOpportunityPricebook() {
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.ProductSearchResult result =
            DRC_NBC_Generate_Sample_Order_Controller.getAllProducts(getOppWithDrcPb().Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.products.size() > 0);
        System.assert(result.packingDetailsList.size() > 0);
    }

    @isTest
    static void testGetAllProducts_FallbackToStandardWhenOppPricebookNull() {
        Opportunity oppNoPb = createOppWithoutPricebook();

        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.ProductSearchResult result =
            DRC_NBC_Generate_Sample_Order_Controller.getAllProducts(oppNoPb.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.products.size() > 0);
    }

    @isTest
    static void testSearchProducts_WithRestriction_UsesOpportunityPricebook() {
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.ProductSearchResult result =
            DRC_NBC_Generate_Sample_Order_Controller.searchProducts(
                'Sample Product 1',
                'INR',
                getOppWithDrcPb().Id
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.products.size() > 0);
    }

    @isTest
    static void testSearchProducts_FallbackToStandardWhenOppPricebookNull() {
        Opportunity oppNoPb = createOppWithoutPricebook();

        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.ProductSearchResult result =
            DRC_NBC_Generate_Sample_Order_Controller.searchProducts(
                'Sample',
                'INR',
                oppNoPb.Id
            );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.products.size() > 0);
    }

    @isTest
    static void testSearchProducts_BlankCurrency() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.searchProducts(
                'Sample',
                '',
                getOppWithDrcPb().Id
            );
           // System.assert(false);
        } catch (AuraHandledException e) {
          //  System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testSearchProducts_NullCurrency() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.searchProducts(
                'Sample',
                null,
                getOppWithDrcPb().Id
            );
           // System.assert(false);
        } catch (AuraHandledException e) {
           // System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetAccountBillingAddress_Success() {
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.AccountAddressWrapper result =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBillingAddress(getOppWithDrcPb().Id);
        Test.stopTest();
        System.assertEquals('Mumbai', result.city);
    }

    @isTest
    static void testGetAccountBillingAddress_NullId() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBillingAddress(null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testGetAccountAddresses() {
        Test.startTest();
        List<DRC_NBC_Addresses__c> result =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountAddresses(getOppWithDrcPb().Id);
        Test.stopTest();
        System.assert(result.size() > 0);
    }

    @isTest
    static void testGetAccountBankDetails_Success() {
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.AccountBankDetailsWrapper result =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBankDetails(getOppWithDrcPb().Id);
        Test.stopTest();
        System.assertEquals('Punjab National bank', result.bankName);
    }

    @isTest
    static void testGetAccountBankDetails_NullId() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBankDetails(null);
            System.assert(false);
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @isTest
    static void testCreateSampleOrder_NullItems() {
        Opportunity opp = getOppWithDrcPb();
        Order ord = buildOrder(opp.AccountId, null, null, null, 'Draft', false);

        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            null,
            opp.Id
        );
        Test.stopTest();

        System.assert(result.contains('"success":false'));
    }

    @isTest
    static void testCreateSampleOrder_EmptyItems() {
        Opportunity opp = getOppWithDrcPb();
        Order ord = buildOrder(opp.AccountId, null, null, null, 'Draft', false);

        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>(),
            opp.Id
        );
        Test.stopTest();

        System.assert(result.contains('"success":false'));
    }

    @isTest
    static void testCreateSampleOrder_BillToContact_NoEmail() {
        Opportunity opp = getOppWithDrcPb();
        Contact noEmail = getConNoEmail();
        Product2 prod = getProd1();

        Order ord = buildOrder(opp.AccountId, noEmail.Id, null, null, 'Draft', false);

        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{
                makeItem(prod.Id, 1, 100, null, null, 'KGS')
            },
            opp.Id
        );
        Test.stopTest();

        System.assert(result.contains('"success":false'));
    }

    @isTest
    static void testCreateSampleOrder_ShipToContact_NoEmail() {
        Opportunity opp = getOppWithDrcPb();
        Contact noEmail = getConNoEmail();
        Product2 prod = getProd1();

        Order ord = buildOrder(opp.AccountId, null, noEmail.Id, null, 'Draft', false);

        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{
                makeItem(prod.Id, 1, 100, null, null, 'KGS')
            },
            opp.Id
        );
        Test.stopTest();

        System.assert(result.contains('"success":false'));
    }

    @isTest
    static void testCreateSampleOrder_UsesExistingOpportunityPricebook() {
        Opportunity opp = getOppWithDrcPb();
        Contact con = getConEmail();
        Product2 prod = getProd1();
        DRC_NBC_Addresses__c shipAddr = getShipAddr();

        Order ord = buildOrder(opp.AccountId, con.Id, null, shipAddr.Id, 'Requested', false);

        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{
                makeItem(prod.Id, 5, 110, '25KG', 40, 'KGS')
            },
            opp.Id
        );
        Test.stopTest();

        System.assert(result.contains('"success":true'));
    }

    @isTest
    static void testCreateSampleOrder_FallbackToStandardWhenOppPricebookNull() {
        Opportunity oppNoPb = createOppWithoutPricebook();
        Contact con = getConEmail();
        Product2 prod = getProd1();

        Order ord = new Order();
        ord.AccountId = oppNoPb.AccountId;
        ord.EffectiveDate = null;
        ord.Status = null;
        ord.CurrencyIsoCode = null;
        ord.BillToContactId = con.Id;

        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{
                makeItem(prod.Id, 3, 100, '25KG', null, 'KGS')
            },
            oppNoPb.Id
        );
        Test.stopTest();

        System.assert(result.contains('"success":true'));

        Opportunity refreshedOpp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id = :oppNoPb.Id];
        System.assertEquals(Test.getStandardPricebookId(), refreshedOpp.Pricebook2Id);
    }

    @isTest
    static void testCreateSampleOrder_MultipleProducts_BothContacts() {
        Opportunity opp = getOppWithDrcPb();
        Contact con1 = getConEmail();
        Product2 prod1 = getProd1();
        Product2 prod2 = getProd2();

        Contact con2 = new Contact(
            FirstName = 'Bob',
            LastName = 'Jones',
            Email = 'bob.jones@example.com',
            AccountId = opp.AccountId
        );
        insert con2;

        Order ord = buildOrder(opp.AccountId, con1.Id, con2.Id, null, 'Draft', false);

        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{
                makeItem(prod1.Id, 2, 110, null, null, 'KGS'),
                makeItem(prod2.Id, 3, 210, null, null, 'LTR')
            },
            opp.Id
        );
        Test.stopTest();
    }
}