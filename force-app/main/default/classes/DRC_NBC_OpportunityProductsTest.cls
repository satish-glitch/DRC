@IsTest
private class DRC_NBC_OpportunityProductsTest {

    @TestSetup
    static void setupData() {
        Id stdPricebookId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPricebookId, IsActive = true);

        Pricebook2 customPb = new Pricebook2(
            Name = 'Custom PB',
            IsActive = true
        );
        insert customPb;

        Account a = new Account(
            Name = 'Test Account DRC',
            DRC_NBC_Customer_Number__c = 'CustDOM/2526-00014',
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
        insert a;

        Product2 p1 = new Product2(
            Name = 'Alpha Chem',
            IsActive = true,
            QuantityUnitOfMeasure = 'kg',
            DRC_NBC_FG_Code__c = 'FG001',
            DRC_NBC_HSN_SAC_Code__c = 'HSN1'
        );
        Product2 p2 = new Product2(
            Name = 'Beta Solution',
            IsActive = true,
            QuantityUnitOfMeasure = 'ltr',
            DRC_NBC_FG_Code__c = 'FG002',
            DRC_NBC_HSN_SAC_Code__c = 'HSN2'
        );
        Product2 p3 = new Product2(
            Name = 'Gamma Allowed',
            IsActive = true,
            QuantityUnitOfMeasure = 'kg',
            DRC_NBC_FG_Code__c = 'FG003',
            DRC_NBC_HSN_SAC_Code__c = 'HSN3'
        );
        Product2 p4 = new Product2(
            Name = 'Delta Blocked',
            IsActive = true,
            QuantityUnitOfMeasure = 'kg',
            DRC_NBC_FG_Code__c = 'FG004',
            DRC_NBC_HSN_SAC_Code__c = 'HSN4'
        );
        insert new List<Product2>{ p1, p2, p3, p4 };

        String curr = UserInfo.getDefaultCurrency();

        insert new List<PricebookEntry>{
            new PricebookEntry(
                Pricebook2Id = stdPricebookId,
                Product2Id = p1.Id,
                UnitPrice = 100,
                IsActive = true,
                CurrencyIsoCode = curr
            ),
            new PricebookEntry(
                Pricebook2Id = stdPricebookId,
                Product2Id = p2.Id,
                UnitPrice = 200,
                IsActive = true,
                CurrencyIsoCode = curr
            ),
            new PricebookEntry(
                Pricebook2Id = stdPricebookId,
                Product2Id = p3.Id,
                UnitPrice = 150,
                IsActive = true,
                CurrencyIsoCode = curr
            ),
            new PricebookEntry(
                Pricebook2Id = stdPricebookId,
                Product2Id = p4.Id,
                UnitPrice = 175,
                IsActive = true,
                CurrencyIsoCode = curr
            )
        };

        insert new List<PricebookEntry>{
            new PricebookEntry(
                Pricebook2Id = customPb.Id,
                Product2Id = p1.Id,
                UnitPrice = 101,
                IsActive = true,
                CurrencyIsoCode = curr
            ),
            new PricebookEntry(
                Pricebook2Id = customPb.Id,
                Product2Id = p2.Id,
                UnitPrice = 201,
                IsActive = true,
                CurrencyIsoCode = curr
            )
        };

        insert new List<DRC_NBC_Packing_Details__c>{
            new DRC_NBC_Packing_Details__c(
                Product__c = p1.Id,
                DRC_NBC_Packing_Size__c = '10kg',
                DRC_NBC_Packing_Qauntity__c = '1'
            ),
            new DRC_NBC_Packing_Details__c(
                Product__c = p1.Id,
                DRC_NBC_Packing_Size__c = '20kg',
                DRC_NBC_Packing_Qauntity__c = '2'
            ),
            new DRC_NBC_Packing_Details__c(
                Product__c = p2.Id,
                DRC_NBC_Packing_Size__c = '5ltr',
                DRC_NBC_Packing_Qauntity__c = '1'
            )
        };
    }

    private static Id getStdPbId() {
        return [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
    }

    private static Id getCustomPbId() {
        return [SELECT Id FROM Pricebook2 WHERE Name = 'Custom PB' LIMIT 1].Id;
    }

    private static Account getAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Test Account DRC' LIMIT 1];
    }

    private static Product2 getProduct(String nameVal) {
        return [SELECT Id FROM Product2 WHERE Name = :nameVal LIMIT 1];
    }

    private static PricebookEntry getStdPbe(Id productId) {
        Id stdId = getStdPbId();
        return [
            SELECT Id, UnitPrice, Product2Id
            FROM PricebookEntry
            WHERE Product2Id = :productId
              AND Pricebook2Id = :stdId
            LIMIT 1
        ];
    }

    private static PricebookEntry getCustomPbe(Id productId) {
        Id pbId = getCustomPbId();
        return [
            SELECT Id, UnitPrice, Product2Id
            FROM PricebookEntry
            WHERE Product2Id = :productId
              AND Pricebook2Id = :pbId
            LIMIT 1
        ];
    }

    private static Opportunity createOpp(Id accountId, Id pricebookId) {
        Opportunity o = new Opportunity(
            Name = 'Opp ' + String.valueOf(Datetime.now().getTime()),
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(7),
            CurrencyIsoCode = UserInfo.getDefaultCurrency()
        );
        if (pricebookId != null) {
            o.Pricebook2Id = pricebookId;
        }
        insert o;
        return o;
    }

    @IsTest
    static void test_getExistingOLIs_whenPricebookNull() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, null);

        Test.startTest();
        DRC_NBC_OpportunityProductsController.getExistingOLIs(o.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_getExistingOLIs_whenStandardPricebookExists() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getStdPbId());

        Product2 p1 = getProduct('Alpha Chem');
        PricebookEntry pbe = getStdPbe(p1.Id);

        insert new OpportunityLineItem(
            OpportunityId = o.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = p1.Id,
            Quantity = 2,
            UnitPrice = 100,
            Description = 'Test OLI',
            DRC_NBC_Packing_Size__c = '10kg',
            DRC_NBC_Packing_Qauntity__c = '1'
        );

        Test.startTest();
        DRC_NBC_OpportunityProductsController.getExistingOLIs(o.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_getExistingOLIs_whenCustomPricebookNoOLIs() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getCustomPbId());

        Test.startTest();
        DRC_NBC_OpportunityProductsController.getExistingOLIs(o.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_getExistingOLIs_whenCustomPricebookWithOLIs() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getCustomPbId());

        Product2 p1 = getProduct('Alpha Chem');
        PricebookEntry pbe = getCustomPbe(p1.Id);

        insert new OpportunityLineItem(
            OpportunityId = o.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = p1.Id,
            Quantity = 1,
            UnitPrice = 101
        );

        Test.startTest();
        DRC_NBC_OpportunityProductsController.getExistingOLIs(o.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_getExistingOLIs_nullOpportunityId() {
        Test.startTest();
        try {
            DRC_NBC_OpportunityProductsController.getExistingOLIs(null);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void test_searchProducts_blankSearchTerm() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getStdPbId());

        Test.startTest();
        DRC_NBC_OpportunityProductsController.searchProducts('', o.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_searchProducts_nullOpportunityId() {
        Test.startTest();
        try {
            DRC_NBC_OpportunityProductsController.searchProducts('Alpha', null);
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void test_searchProducts_standardPricebook_noRestrictions() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getStdPbId());

        Test.startTest();
        DRC_NBC_OpportunityProductsController.searchProducts('Alpha', o.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_searchProducts_fallbackToStandardWhenOppPricebookNull() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, null);

        Test.startTest();
        DRC_NBC_OpportunityProductsController.searchProducts('Beta', o.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_searchProducts_withRestrictions() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getStdPbId());
        Product2 allowedProd = getProduct('Gamma Allowed');

        insert new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c = a.Id,
            DRC_NBC_Product__c = allowedProd.Id,
            DRC_NBC_User__c = UserInfo.getUserId()
        );

        Test.startTest();
        DRC_NBC_OpportunityProductsController.searchProducts('Gamma', o.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_saveOLIData_insertRecords() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getStdPbId());

        Product2 p1 = getProduct('Alpha Chem');
        Product2 p2 = getProduct('Beta Solution');
        PricebookEntry pbe1 = getStdPbe(p1.Id);
        PricebookEntry pbe2 = getStdPbe(p2.Id);

        List<OpportunityLineItem> toSave = new List<OpportunityLineItem>{
            new OpportunityLineItem(
                Product2Id = p1.Id,
                Quantity = 3,
                UnitPrice = 100,
                PricebookEntryId = pbe1.Id,
                DRC_NBC_Unit_Of_Measurement__c = 'kg',
                DRC_NBC_Packing_Size__c = '10kg',
                DRC_NBC_Packing_Qauntity__c = '1'
            ),
            new OpportunityLineItem(
                Product2Id = p2.Id,
                Quantity = 1,
                UnitPrice = 200,
                PricebookEntryId = pbe2.Id
            )
        };

        Test.startTest();
        DRC_NBC_OpportunityProductsController.saveOLIData(toSave, new List<String>(), o.Id);
        Test.stopTest();
    }

    @IsTest
    static void test_saveOLIData_updateAndDelete() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getStdPbId());

        Product2 p1 = getProduct('Alpha Chem');
        Product2 p2 = getProduct('Beta Solution');
        PricebookEntry pbe1 = getStdPbe(p1.Id);
        PricebookEntry pbe2 = getStdPbe(p2.Id);

        OpportunityLineItem oli1 = new OpportunityLineItem(
            OpportunityId = o.Id,
            Product2Id = p1.Id,
            Quantity = 2,
            UnitPrice = 100,
            PricebookEntryId = pbe1.Id
        );
        OpportunityLineItem oli2 = new OpportunityLineItem(
            OpportunityId = o.Id,
            Product2Id = p2.Id,
            Quantity = 1,
            UnitPrice = 200,
            PricebookEntryId = pbe2.Id
        );
        insert new List<OpportunityLineItem>{ oli1, oli2 };

        OpportunityLineItem updateOli = new OpportunityLineItem(
            Id = oli1.Id,
            Product2Id = p1.Id,
            Quantity = 5,
            UnitPrice = 111,
            PricebookEntryId = pbe1.Id,
            Description = 'Updated line'
        );

        Test.startTest();
        DRC_NBC_OpportunityProductsController.saveOLIData(
            new List<OpportunityLineItem>{ updateOli },
            new List<String>{ oli2.Id },
            o.Id
        );
        Test.stopTest();
    }

    @IsTest
    static void test_saveOLIData_missingProduct2Id() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getStdPbId());

        OpportunityLineItem badLine = new OpportunityLineItem(
            Quantity = 1,
            UnitPrice = 10
        );

        Test.startTest();
        try {
            DRC_NBC_OpportunityProductsController.saveOLIData(
                new List<OpportunityLineItem>{ badLine },
                null,
                o.Id
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void test_saveOLIData_zeroQuantity() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getStdPbId());
        Product2 p1 = getProduct('Alpha Chem');

        OpportunityLineItem badLine = new OpportunityLineItem(
            Product2Id = p1.Id,
            Quantity = 0,
            UnitPrice = 10
        );

        Test.startTest();
        try {
            DRC_NBC_OpportunityProductsController.saveOLIData(
                new List<OpportunityLineItem>{ badLine },
                null,
                o.Id
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void test_saveOLIData_missingUnitPrice() {
        Account a = getAccount();
        Opportunity o = createOpp(a.Id, getStdPbId());
        Product2 p1 = getProduct('Alpha Chem');

        OpportunityLineItem badLine = new OpportunityLineItem(
            Product2Id = p1.Id,
            Quantity = 1
        );

        Test.startTest();
        try {
            DRC_NBC_OpportunityProductsController.saveOLIData(
                new List<OpportunityLineItem>{ badLine },
                null,
                o.Id
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void test_saveOLIData_blankOpportunityId() {
        Test.startTest();
        try {
            DRC_NBC_OpportunityProductsController.saveOLIData(
                new List<OpportunityLineItem>(),
                null,
                null
            );
        } catch (Exception e) {
        }
        Test.stopTest();
    }

    @IsTest
    static void test_wrapperConstructors() {
        Test.startTest();

        DRC_NBC_OpportunityProductsController.PackingDetailWrapper pdw =
            new DRC_NBC_OpportunityProductsController.PackingDetailWrapper('10kg', '1');

        DRC_NBC_OpportunityProductsController.ProductWrapper pw =
            new DRC_NBC_OpportunityProductsController.ProductWrapper(
                null,
                getProduct('Alpha Chem').Id,
                'Alpha Chem',
                'FG001',
                'HSN1',
                'kg',
                'Demo',
                100,
                new List<DRC_NBC_OpportunityProductsController.PackingDetailWrapper>{ pdw }
            );

        DRC_NBC_OpportunityProductsController.OLIWrapper ow =
            new DRC_NBC_OpportunityProductsController.OLIWrapper();
        ow.olis = new List<OpportunityLineItem>();
        ow.packingDetailsMap =
            new Map<Id, List<DRC_NBC_OpportunityProductsController.PackingDetailWrapper>>();

        Test.stopTest();
    }
}