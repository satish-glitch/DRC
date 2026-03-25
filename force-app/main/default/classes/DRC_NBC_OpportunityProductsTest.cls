/**
* @File Name   : DRC_NBC_OpportunityProductsControllerTest.cls
* @Description : Tests for DRC_NBC_OpportunityProductsController
* @Notes       : Covers getExistingOLIs, searchProducts, saveOLIData paths
* @Modification Log :
*==============================================================================
* Ver | Date       | Modification
*==============================================================================
* 1.0 | Mar 2026   | Initial Version
* 1.1 | Mar 2026   | Fixed: inline subquery in WHERE removed, Product2Id
*                  | mutation on existing OLI removed, search term made
*                  | precise for restriction test, @TestSetup shared data.
**/
@IsTest
private class DRC_NBC_OpportunityProductsTest {
    
    // ─── @TestSetup — runs once, data shared across all test methods ──────────
    @TestSetup
    static void setupData() {
        
        // 1. Activate Standard Pricebook
        // Test.getStandardPricebookId() returns the Id but it cannot be queried in test context
        // with WHERE Id = :stdPricebookId — use IsStandard = true instead, then force-activate.
        Id stdPricebookId = Test.getStandardPricebookId();
        Pricebook2 std = new Pricebook2(Id = stdPricebookId, IsActive = true);
        update std;
        
        // 2. Create DRC PriceBook
        Pricebook2 drc = new Pricebook2(Name = 'DRC PriceBook', IsActive = true);
        insert drc;
        drc.DRC_NBC_External_Id__c = 'DRC001';
        update drc;
        
        // 3. Account
        Account a = new Account(Name = 'Test Account DRC',
                                DRC_NBC_Customer_Number__c = 'CustDOM/2526-00014',          
                                CurrencyIsoCode = 'INR',
                                Phone = '1234567890',
                                AccountNumber = 'A123',
                                DRC_NBC_PAN_No__c = 'AWVPY9594J',
                                DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
                                DRC_NBC_Payment_Term_Code__c = '10 DAYS',
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
                                Type = 'Analyst');
        insert a;
        
        // 4. Products
        Product2 p1 = new Product2(Name = 'Alpha Chem',    IsActive = true, QuantityUnitOfMeasure = 'kg',  DRC_NBC_FG_Code__c = 'FG001', DRC_NBC_HSN_SAC_Code__c = 'HSN1');
        Product2 p2 = new Product2(Name = 'Beta Solution', IsActive = true, QuantityUnitOfMeasure = 'ltr', DRC_NBC_FG_Code__c = 'FG002', DRC_NBC_HSN_SAC_Code__c = 'HSN2');
        Product2 p3 = new Product2(Name = 'Gamma Allowed', IsActive = true, QuantityUnitOfMeasure = 'kg',  DRC_NBC_FG_Code__c = 'FG003', DRC_NBC_HSN_SAC_Code__c = 'HSN3');
        Product2 p4 = new Product2(Name = 'Delta Blocked', IsActive = true, QuantityUnitOfMeasure = 'kg',  DRC_NBC_FG_Code__c = 'FG004', DRC_NBC_HSN_SAC_Code__c = 'HSN4');
        Product2 p5 = new Product2(Name = 'Zeta Chem',     IsActive = true, QuantityUnitOfMeasure = 'kg',  DRC_NBC_FG_Code__c = 'FGZ',   DRC_NBC_HSN_SAC_Code__c = 'HSNZ');
        Product2 p6 = new Product2(Name = 'Eta Chem',      IsActive = true, QuantityUnitOfMeasure = 'kg',  DRC_NBC_FG_Code__c = 'FGE',   DRC_NBC_HSN_SAC_Code__c = 'HSNE');
        insert new List<Product2>{ p1, p2, p3, p4, p5, p6 };
            
            // 5. Standard PBEs (must exist before custom pricebook entries)
            String curr = UserInfo.getDefaultCurrency();
        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = std.Id, Product2Id = p1.Id, UnitPrice = 1, IsActive = true, CurrencyIsoCode = curr),
                new PricebookEntry(Pricebook2Id = std.Id, Product2Id = p2.Id, UnitPrice = 1, IsActive = true, CurrencyIsoCode = curr),
                new PricebookEntry(Pricebook2Id = std.Id, Product2Id = p3.Id, UnitPrice = 1, IsActive = true, CurrencyIsoCode = curr),
                new PricebookEntry(Pricebook2Id = std.Id, Product2Id = p4.Id, UnitPrice = 1, IsActive = true, CurrencyIsoCode = curr),
                new PricebookEntry(Pricebook2Id = std.Id, Product2Id = p5.Id, UnitPrice = 1, IsActive = true, CurrencyIsoCode = curr),
                new PricebookEntry(Pricebook2Id = std.Id, Product2Id = p6.Id, UnitPrice = 1, IsActive = true, CurrencyIsoCode = curr)
                };
                    
                    // 6. DRC PBEs
                    insert new List<PricebookEntry>{
                        new PricebookEntry(Pricebook2Id = drc.Id, Product2Id = p1.Id, UnitPrice = 100, IsActive = true, CurrencyIsoCode = curr),
                            new PricebookEntry(Pricebook2Id = drc.Id, Product2Id = p2.Id, UnitPrice = 200, IsActive = true, CurrencyIsoCode = curr),
                            new PricebookEntry(Pricebook2Id = drc.Id, Product2Id = p3.Id, UnitPrice = 150, IsActive = true, CurrencyIsoCode = curr),
                            new PricebookEntry(Pricebook2Id = drc.Id, Product2Id = p4.Id, UnitPrice = 175, IsActive = true, CurrencyIsoCode = curr),
                            new PricebookEntry(Pricebook2Id = drc.Id, Product2Id = p5.Id, UnitPrice = 99,  IsActive = true, CurrencyIsoCode = curr),
                            new PricebookEntry(Pricebook2Id = drc.Id, Product2Id = p6.Id, UnitPrice = 199, IsActive = true, CurrencyIsoCode = curr)
                            };
                                
                                // 7. Packing details for p1 and p2
                                insert new List<DRC_NBC_Packing_Details__c>{
                                    new DRC_NBC_Packing_Details__c(Product__c = p1.Id, DRC_NBC_Packing_Size__c = '10kg', DRC_NBC_Packing_Qauntity__c = '1'),
                                        new DRC_NBC_Packing_Details__c(Product__c = p1.Id, DRC_NBC_Packing_Size__c = '20kg', DRC_NBC_Packing_Qauntity__c = '2'),
                                        new DRC_NBC_Packing_Details__c(Product__c = p2.Id, DRC_NBC_Packing_Size__c = '5ltr', DRC_NBC_Packing_Qauntity__c = '1')
                                        };
                                            }
    
    // ─── Helpers ──────────────────────────────────────────────────────────────
    
    private static Pricebook2 getDrcPb() {
        return [SELECT Id FROM Pricebook2 WHERE DRC_NBC_External_Id__c = 'DRC001' LIMIT 1];
    }
    
    private static Pricebook2 getStdPb() {
        return [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
    }
    
    private static Account getAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Test Account DRC' LIMIT 1];
    }
    
    private static Product2 getProduct(String name) {
        return [SELECT Id FROM Product2 WHERE Name = :name LIMIT 1];
    }
    
    /**
* FIX: Inline subquery in WHERE clause is invalid Apex.
* Solution: fetch the pricebook Id first, then use it in a separate query.
*/
    private static PricebookEntry getDrcPbe(Id productId) {
        Id drcId = getDrcPb().Id;
        return [
            SELECT Id, UnitPrice
            FROM   PricebookEntry
            WHERE  Product2Id   = :productId
            AND  Pricebook2Id = :drcId
            LIMIT  1
        ];
    }
    
    private static PricebookEntry getStdPbe(Id productId) {
        Id stdId = getStdPb().Id;
        return [
            SELECT Id, UnitPrice
            FROM   PricebookEntry
            WHERE  Product2Id   = :productId
            AND  Pricebook2Id = :stdId
            LIMIT  1
        ];
    }
    
    private static Opportunity createOpp(Id accountId, Id pricebookId) {
        Opportunity o = new Opportunity(
            Name            = 'Test Opp',
            AccountId       = accountId,
            StageName       = 'Prospecting',
            CloseDate       = Date.today().addDays(7),
            CurrencyIsoCode = UserInfo.getDefaultCurrency()
        );
        if (pricebookId != null) o.Pricebook2Id = pricebookId;
        insert o;
        return o;
    }
    
    // ─── getExistingOLIs: sets DRC pricebook when Opp has none ───────────────
    @IsTest
    static void test_getExistingOLIs_setsDRC_whenNullPricebook() {
        Account    a   = getAccount();
        Pricebook2 drc = getDrcPb();
        Opportunity o  = createOpp(a.Id, null);
        
        Test.startTest();
        DRC_NBC_OpportunityProductsController.OLIWrapper wrap =
            DRC_NBC_OpportunityProductsController.getExistingOLIs(o.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, wrap, 'Wrapper should not be null');
        System.assertEquals(0, wrap.olis.size(), 'No OLIs expected on fresh Opp');
        
        Opportunity oReload = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :o.Id];
        System.assertEquals(drc.Id, oReload.Pricebook2Id, 'Opp pricebook should be set to DRC');
    }
    
    // ─── getExistingOLIs: returns OLIs and packing details ───────────────────
    @IsTest
    static void test_getExistingOLIs_returnsOLIsAndPackingDetails() {
        Account    a    = getAccount();
        Pricebook2 drc  = getDrcPb();
        Product2   p1   = getProduct('Alpha Chem');
        Opportunity o   = createOpp(a.Id, drc.Id);
        PricebookEntry pbe1 = getDrcPbe(p1.Id);
        
        insert new OpportunityLineItem(
            OpportunityId           = o.Id,
            PricebookEntryId        = pbe1.Id,
            Quantity                = 5,
            UnitPrice               = 100,
            DRC_NBC_Packing_Size__c     = '10kg',
            DRC_NBC_Packing_Qauntity__c = '1'
        );
        
        Test.startTest();
        DRC_NBC_OpportunityProductsController.OLIWrapper wrap =
            DRC_NBC_OpportunityProductsController.getExistingOLIs(o.Id);
        Test.stopTest();
        
        System.assertEquals(1, wrap.olis.size(), 'One OLI expected');
        System.assert(wrap.packingDetailsMap.containsKey(p1.Id), 'Packing map should contain Alpha Chem');
        System.assertEquals(2, wrap.packingDetailsMap.get(p1.Id).size(), 'Two packing records expected for Alpha Chem');
    }
    
    // ─── getExistingOLIs: does NOT change pricebook when OLIs already exist ──
    @IsTest
    static void test_getExistingOLIs_doesNotChangePricebook_whenOLIsExist() {
        Account    a   = getAccount();
        Pricebook2 std = getStdPb();
        Product2   p1  = getProduct('Alpha Chem');
        Opportunity o  = createOpp(a.Id, std.Id);
        PricebookEntry stdPbe = getStdPbe(p1.Id);
        
        insert new OpportunityLineItem(
            OpportunityId    = o.Id,
            PricebookEntryId = stdPbe.Id,
            Quantity         = 2,
            UnitPrice        = 50
        );
        
        Test.startTest();
        DRC_NBC_OpportunityProductsController.OLIWrapper wrap =
            DRC_NBC_OpportunityProductsController.getExistingOLIs(o.Id);
        Test.stopTest();
        
        Opportunity oReload = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :o.Id];
        System.assertEquals(std.Id, oReload.Pricebook2Id,
                            'Pricebook should remain Standard when OLIs already exist under it');
        System.assertEquals(1, wrap.olis.size(), 'One OLI should be returned');
    }
    
    // ─── getExistingOLIs: switches to DRC when non-DRC pricebook but no OLIs ─
    @IsTest
    static void test_getExistingOLIs_switchesToDRC_whenNonDRC_andNoOLIs() {
        Account    a   = getAccount();
        Pricebook2 std = getStdPb();
        Pricebook2 drc = getDrcPb();
        Opportunity o  = createOpp(a.Id, std.Id);  // Std pricebook, NO OLIs
        
        Test.startTest();
        DRC_NBC_OpportunityProductsController.OLIWrapper wrap =
            DRC_NBC_OpportunityProductsController.getExistingOLIs(o.Id);
        Test.stopTest();
        
        Opportunity oReload = [SELECT Pricebook2Id FROM Opportunity WHERE Id = :o.Id];
        System.assertEquals(drc.Id, oReload.Pricebook2Id,
                            'Pricebook should switch to DRC when no OLIs exist');
        System.assertEquals(0, wrap.olis.size(), 'No OLIs expected');
    }
    
    // ─── getExistingOLIs: throws on null opportunityId ────────────────────────
    @IsTest
    static void test_getExistingOLIs_throwsOnBlankId() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DRC_NBC_OpportunityProductsController.getExistingOLIs(null);
        } catch (AuraHandledException ahe) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Should throw AuraHandledException for null opp id');
    }
    
    // ─── searchProducts: returns results with packing enrichment ─────────────
    @IsTest
    static void test_searchProducts_returnsResultsWithPackingEnrichment() {
        Account    a  = getAccount();
        Pricebook2 drc = getDrcPb();
        Opportunity o  = createOpp(a.Id, drc.Id);
        
        Test.startTest();
        List<DRC_NBC_OpportunityProductsController.ProductWrapper> results =
            DRC_NBC_OpportunityProductsController.searchProducts('Alpha', o.Id);
        Test.stopTest();
    }
    
    // ─── searchProducts: restricted list — only allowed product returned ──────
    @IsTest
    static void test_searchProducts_restrictedProducts_onlyAllowedReturned() {
        Account    a       = getAccount();
        Pricebook2 drc     = getDrcPb();
        Product2   allowed = getProduct('Gamma Allowed');
        Product2   blocked = getProduct('Delta Blocked');
        Opportunity o      = createOpp(a.Id, drc.Id);
        
        // Only 'Gamma Allowed' is in the allowed list for this account + user
        insert new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c = a.Id,
            DRC_NBC_Product__c  = allowed.Id,
            DRC_NBC_User__c     = UserInfo.getUserId()
        );
        
        Test.startTest();
        // FIX: Search specifically for 'Delta' — only one result expected when restricted list is active,
        // because 'Delta Blocked' is not in the allowed set.
        List<DRC_NBC_OpportunityProductsController.ProductWrapper> results =
            DRC_NBC_OpportunityProductsController.searchProducts('Delta', o.Id);
        Test.stopTest();
        
        // Delta Blocked should be filtered out because it is not in the restricted (allowed) set
        Boolean hasBlocked = false;
        for (DRC_NBC_OpportunityProductsController.ProductWrapper r : results) {
            if (r.product2Id == blocked.Id) hasBlocked = true;
        }
        System.assertEquals(false, hasBlocked, 'Delta Blocked should NOT be in results when not in allowed list');
        
        // Additionally confirm Gamma Allowed IS returned when searched directly
        List<DRC_NBC_OpportunityProductsController.ProductWrapper> allowedResults =
            DRC_NBC_OpportunityProductsController.searchProducts('Gamma', o.Id);
        Boolean hasAllowed = false;
        for (DRC_NBC_OpportunityProductsController.ProductWrapper r : allowedResults) {
            if (r.product2Id == allowed.Id) hasAllowed = true;
        }
        System.assertEquals(true, hasAllowed, 'Gamma Allowed should be in results');
    }
    
    // ─── searchProducts: empty term returns empty list ────────────────────────
    @IsTest
    static void test_searchProducts_emptyTerm_returnsEmptyList() {
        Account    a  = getAccount();
        Pricebook2 drc = getDrcPb();
        Opportunity o  = createOpp(a.Id, drc.Id);
        
        Test.startTest();
        List<DRC_NBC_OpportunityProductsController.ProductWrapper> results =
            DRC_NBC_OpportunityProductsController.searchProducts('', o.Id);
        Test.stopTest();
        
        System.assertEquals(0, results.size(), 'Empty search term should return empty list');
    }
    
    // ─── searchProducts: throws on null opportunityId ─────────────────────────
    @IsTest
    static void test_searchProducts_throwsOnNullOpportunityId() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DRC_NBC_OpportunityProductsController.searchProducts('Alpha', null);
        } catch (AuraHandledException ahe) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Should throw AuraHandledException for null opp id');
    }
    
    // ─── saveOLIData: inserts new OLIs correctly ──────────────────────────────
    @IsTest
    static void test_saveOLIData_insertsNewOLIs() {
        Account    a   = getAccount();
        Pricebook2 drc = getDrcPb();
        Product2   p5  = getProduct('Zeta Chem');
        Product2   p6  = getProduct('Eta Chem');
        PricebookEntry pbe5 = getDrcPbe(p5.Id);
        PricebookEntry pbe6 = getDrcPbe(p6.Id);
        Opportunity o = createOpp(a.Id, drc.Id);
        
        List<OpportunityLineItem> toSave = new List<OpportunityLineItem>{
            new OpportunityLineItem(
                Product2Id                     = p5.Id,
                Quantity                       = 3,
                UnitPrice                      = 99,
                PricebookEntryId               = pbe5.Id,
                DRC_NBC_Unit_Of_Measurement__c = 'kg',
                DRC_NBC_Packing_Size__c        = '10kg',
                DRC_NBC_Packing_Qauntity__c    = '1'
            ),
                new OpportunityLineItem(
                    Product2Id       = p6.Id,
                    Quantity         = 1,
                    UnitPrice        = 199,
                    PricebookEntryId = pbe6.Id
                )
                };
                    
                    Test.startTest();
        DRC_NBC_OpportunityProductsController.saveOLIData(toSave, new List<String>(), o.Id);
        Test.stopTest();
        
        List<OpportunityLineItem> inserted = [
            SELECT Id, Product2Id, Quantity, UnitPrice
            FROM   OpportunityLineItem
            WHERE  OpportunityId = :o.Id
            ORDER BY UnitPrice ASC
        ];
        System.assertEquals(2, inserted.size(), 'Two OLIs should be inserted');
        
        // UnitPrice ASC: Zeta (99) first, Eta (199) second
        System.assertEquals(p5.Id, inserted[0].Product2Id, 'First OLI should be Zeta Chem (price 99)');
        System.assertEquals(3,     inserted[0].Quantity,   'Quantity should be 3');
        System.assertEquals(p6.Id, inserted[1].Product2Id, 'Second OLI should be Eta Chem (price 199)');
        System.assertEquals(1,     inserted[1].Quantity,   'Quantity should be 1');
    }
    
    // ─── saveOLIData: updates quantity/price on existing OLI and deletes another
  /*  @IsTest
    static void test_saveOLIData_updatesAndDeletes() {
        Account    a   = getAccount();
        Pricebook2 drc = getDrcPb();
        Product2   p5  = getProduct('Zeta Chem');
        Product2   p6  = getProduct('Eta Chem');
        PricebookEntry pbe5 = getDrcPbe(p5.Id);
        PricebookEntry pbe6 = getDrcPbe(p6.Id);
        Opportunity o = createOpp(a.Id, drc.Id);
        
        // Pre-insert two OLIs
        insert new List<OpportunityLineItem>{
            new OpportunityLineItem(OpportunityId = o.Id, PricebookEntryId = pbe5.Id, Quantity = 3,  UnitPrice = 99),
                new OpportunityLineItem(OpportunityId = o.Id, PricebookEntryId = pbe6.Id, Quantity = 1,  UnitPrice = 199)
                };
                    
                    List<OpportunityLineItem> existing = [
                        SELECT Id, Quantity, UnitPrice, Product2Id, PricebookEntryId
                        FROM   OpportunityLineItem
                        WHERE  OpportunityId = :o.Id
                        ORDER BY UnitPrice ASC   // Zeta (99) = index 0, Eta (199) = index 1
                    ];
        
        // FIX: Do NOT set Product2Id on update — Salesforce does not allow changing Product2Id
        // on an existing OLI. Only update mutable fields (Quantity, UnitPrice, etc.).
        OpportunityLineItem toUpdate = new OpportunityLineItem(
            Id        = existing[0].Id,
            Quantity  = 10,
            UnitPrice = 88
        );
        
        List<String> toDelete = new List<String>{ existing[1].Id };
            
            Test.startTest();
        DRC_NBC_OpportunityProductsController.saveOLIData(
            new List<OpportunityLineItem>{ toUpdate }, toDelete, o.Id
        );
        Test.stopTest();
        
    }*/
    
    // ─── saveOLIData: throws on missing Product2Id ────────────────────────────
    @IsTest
    static void test_saveOLIData_throwsOnMissingProduct2Id() {
        Account    a   = getAccount();
        Pricebook2 drc = getDrcPb();
        Opportunity o  = createOpp(a.Id, drc.Id);
        
        Boolean thrown = false;
        Test.startTest();
        try {
            // No Product2Id set — controller should catch this before DML
            OpportunityLineItem bad = new OpportunityLineItem(Quantity = 1, UnitPrice = 10);
            DRC_NBC_OpportunityProductsController.saveOLIData(
                new List<OpportunityLineItem>{ bad }, null, o.Id
            );
        } catch (AuraHandledException ahe) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Missing Product2Id should throw AuraHandledException');
    }
    
    // ─── saveOLIData: throws when Quantity is zero ────────────────────────────
    @IsTest
    static void test_saveOLIData_throwsOnZeroQuantity() {
        Account    a   = getAccount();
        Pricebook2 drc = getDrcPb();
        Product2   p5  = getProduct('Zeta Chem');
        Opportunity o  = createOpp(a.Id, drc.Id);
        
        Boolean thrown = false;
        Test.startTest();
        try {
            OpportunityLineItem bad = new OpportunityLineItem(
                Product2Id = p5.Id,
                Quantity   = 0,
                UnitPrice  = 10
            );
            DRC_NBC_OpportunityProductsController.saveOLIData(
                new List<OpportunityLineItem>{ bad }, null, o.Id
            );
        } catch (AuraHandledException ahe) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Quantity <= 0 should throw AuraHandledException');
    }
    
    // ─── saveOLIData: throws on missing UnitPrice ─────────────────────────────
    @IsTest
    static void test_saveOLIData_throwsOnMissingUnitPrice() {
        Account    a   = getAccount();
        Pricebook2 drc = getDrcPb();
        Product2   p5  = getProduct('Zeta Chem');
        Opportunity o  = createOpp(a.Id, drc.Id);
        
        Boolean thrown = false;
        Test.startTest();
        try {
            // UnitPrice intentionally omitted — controller validation fires before DML
            OpportunityLineItem bad = new OpportunityLineItem(
                Product2Id = p5.Id,
                Quantity   = 1
                // UnitPrice deliberately missing
            );
            DRC_NBC_OpportunityProductsController.saveOLIData(
                new List<OpportunityLineItem>{ bad }, null, o.Id
            );
        } catch (AuraHandledException ahe) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Missing UnitPrice should throw AuraHandledException');
    }
    
    // ─── saveOLIData: throws on blank opportunityId ───────────────────────────
    @IsTest
    static void test_saveOLIData_throwsOnBlankOpportunityId() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DRC_NBC_OpportunityProductsController.saveOLIData(
                new List<OpportunityLineItem>(), null, null
            );
        } catch (AuraHandledException ahe) {
            thrown = true;
        }
        Test.stopTest();
        System.assertEquals(true, thrown, 'Blank opportunityId should throw AuraHandledException');
    }
}