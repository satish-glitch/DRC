/**
* @File Name : DRC_NBC_GenerateSampleOrderTest.cls
* @Description : Complete test class targeting 100% coverage of
*                DRC_NBC_Generate_Sample_Order_Controller
* @Author :   Satish Yadav
* @Last Modified On : March 2026
* @Modification Log :
*==============================================================================
* Ver | Date        | Author | Modification
*==============================================================================
* 1.0 | March 2026  |        | Initial Version – full coverage
**/
@isTest
public class DRC_NBC_GenerateSampleOrderTest {
    
    @testSetup
    static void setupTestData() {
        
        Account acc = new Account(
            Name                                     = 'Test Account',
            BillingStreet                            = '123 Test St',
            BillingCity                              = 'Mumbai',
            BillingState                             = 'Maharashtra',
            BillingPostalCode                        = '400001',
            BillingCountry                           = 'India',
            BillingCountryCode                       = 'IN',
            DRC_NBC_Payment_Term_Code__c             = '100',
            DRC_NBC_Consignee_Bank_Name__c           = 'Test Bank',
            DRC_NBC_Consignee_Bank_Account_Number__c = 'ACC123456',
            DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'IFSC0001',
            DRC_NBC_Consignee_Bank_Address__c        = '1 Bank St, Mumbai'
        );
        insert acc;
        
        // ── Contact WITH email ────────────────────────────────────────────────
        Contact conWithEmail = new Contact(
            FirstName = 'John', LastName = 'Doe',
            Email     = 'john.doe@example.com',
            AccountId = acc.Id
        );
        insert conWithEmail;
        
        // ── Contact WITHOUT email (covers early-return email-validation branch) ─
        Contact conNoEmail = new Contact(
            FirstName = 'Jane', LastName = 'Smith',
            AccountId = acc.Id
            // Email intentionally omitted
        );
        insert conNoEmail;
        
        // ── DRC Pricebook ─────────────────────────────────────────────────────
        Pricebook2 drcPb = new Pricebook2(
            Name                   = 'DRC PriceBook',
            IsActive               = true,
            DRC_NBC_External_Id__c = 'DRC001'
        );
        insert drcPb;
        
        // ── Products ──────────────────────────────────────────────────────────
        Product2 prod1 = new Product2(
            Name                    = 'Sample Product 1',
            IsActive                = true,
            DRC_NBC_FG_Code__c      = 'FG001',
            DRC_NBC_HSN_SAC_Code__c = 'HSN001',
            QuantityUnitOfMeasure   = 'KGS'
        );
        insert prod1;
        
        Product2 prod2 = new Product2(
            Name                    = 'Sample Product 2',
            IsActive                = true,
            DRC_NBC_FG_Code__c      = 'FG002',
            DRC_NBC_HSN_SAC_Code__c = 'HSN002',
            QuantityUnitOfMeasure   = 'KGS'
        );
        insert prod2;
        
        // ── Packing Details ───────────────────────────────────────────────────
        // prod1: two records with non-null qty (covers non-null qtyStr branch
        //        and the containsKey existing-key append branch on second insert)
        insert new DRC_NBC_Packing_Details__c(
            Product__c                  = prod1.Id,
            DRC_NBC_Packing_Size__c     = '25KG',
            DRC_NBC_Packing_Qauntity__c = String.valueOf(40)
        );
        insert new DRC_NBC_Packing_Details__c(
            Product__c                  = prod1.Id,
            DRC_NBC_Packing_Size__c     = '50KG',
            DRC_NBC_Packing_Qauntity__c = String.valueOf(20)
        );
        // prod2: one record with NULL qty (covers qtyStr = '' branch)
        insert new DRC_NBC_Packing_Details__c(
            Product__c              = prod2.Id,
            DRC_NBC_Packing_Size__c = '20L'
            // DRC_NBC_Packing_Qauntity__c intentionally null
        );
        
        // ── Restricted Products (covers allowedProductIds branch) ─────────────
        insert new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Product__c  = prod1.Id,
            DRC_NBC_Customer__c = acc.Id
        );
        
        // ── Standard PBEs (required before custom PBEs) ───────────────────────
        Id stdPbId = Test.getStandardPricebookId();
        insert new List<PricebookEntry>{
            new PricebookEntry(
                Pricebook2Id = stdPbId, Product2Id = prod1.Id,
                UnitPrice = 100, IsActive = true
            ),
                new PricebookEntry(
                    Pricebook2Id = stdPbId, Product2Id = prod2.Id,
                    UnitPrice = 200, IsActive = true
                )
                };
                    
                    // ── DRC PBEs ──────────────────────────────────────────────────────────
                    insert new List<PricebookEntry>{
                        new PricebookEntry(
                            Pricebook2Id = drcPb.Id, Product2Id = prod1.Id,
                            UnitPrice = 100, IsActive = true,
                            UseStandardPrice = false, CurrencyIsoCode = 'INR'
                        ),
                            new PricebookEntry(
                                Pricebook2Id = drcPb.Id, Product2Id = prod2.Id,
                                UnitPrice = 200, IsActive = true,
                                UseStandardPrice = false, CurrencyIsoCode = 'INR'
                            )
                            };
                                
                                // ── Opportunity linked to DRC pricebook ───────────────────────────────
                                Opportunity opp = new Opportunity(
                                    Name            = 'Test Opportunity',
                                    StageName       = 'Prospecting',
                                    CloseDate       = Date.today().addDays(10),
                                    AccountId       = acc.Id,
                                    CurrencyIsoCode = 'INR',
                                    Pricebook2Id    = drcPb.Id
                                );
        insert opp;
        
        // ── Shipping Address (compound sub-fields for address tests) ──────────
        insert new DRC_NBC_Addresses__c(
            DRC_NBC_Account__c              = acc.Id,
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Address__Street__s      = '456 Ship Lane',
            DRC_NBC_Address__City__s        = 'Pune',
            DRC_NBC_Address__PostalCode__s  = '411001',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Warehouse__c            = 'CFS - JNPT'
        );
    }
    
    // =========================================================================
    // QUERY HELPERS
    // =========================================================================
    
    private static Opportunity getOpp() {
        return [SELECT Id, AccountId FROM Opportunity LIMIT 1];
    }
    
    private static Contact getConEmail() {
        return [SELECT Id FROM Contact WHERE Email != null LIMIT 1];
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
    
    private static PricebookEntry getDrcPbe(Id prod2Id) {
        return [SELECT Id FROM PricebookEntry
                WHERE Product2Id = :prod2Id
                AND Pricebook2.Name = 'DRC PriceBook' LIMIT 1];
    }
    
    private static DRC_NBC_Addresses__c getShipAddr() {
        return [SELECT Id FROM DRC_NBC_Addresses__c LIMIT 1];
    }
    
    // ── Builds a minimal OrderItemWrapper ─────────────────────────────────────
    private static DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper makeItem(
        Id prod2Id, Decimal qty, Decimal price,
        String packSize, Decimal packQty, String uom) {
            DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper w =
                new DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper();
            w.Product2Id            = prod2Id;
            w.Quantity              = qty;
            w.UnitPrice             = price;
            w.PackingSize           = packSize;
            w.PackingQuantity       = packQty;
            w.QuantityUnitOfMeasure = uom;
            return w;
        }
    
    // ── Builds a base Order sObject ───────────────────────────────────────────
    private static Order buildOrder(Id accountId, Id billContactId,
                                    Id shipContactId, Id shipAddrId,
                                    String status, Boolean nullDate) {
                                        Order ord = new Order();
                                        ord.AccountId       = accountId;
                                        ord.Pricebook2Id    = Test.getStandardPricebookId();
                                        ord.CurrencyIsoCode = 'INR';
                                        ord.Status          = status != null ? status : 'Draft';
                                        ord.EffectiveDate   = nullDate ? null : Date.today();
                                        if (billContactId != null) ord.BillToContactId = billContactId;
                                        if (shipContactId != null) ord.ShipToContactId = shipContactId;
                                        if (shipAddrId    != null) ord.DRC_NBC_Shipping_Address__c = shipAddrId;
                                        return ord;
                                    }
    
    // =========================================================================
    // getOrderRecordTypes
    // =========================================================================
    
    @isTest
    static void testGetOrderRecordTypes() {
        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_Generate_Sample_Order_Controller.getOrderRecordTypes();
        Test.stopTest();
    }
    
    // =========================================================================
    // getOpportunityContacts
    // =========================================================================
    
    /** Covers: SOQL returns contacts, list returned normally */
    @isTest
    static void testGetOpportunityContacts_Success() {
        Test.startTest();
        List<Contact> contacts =
            DRC_NBC_Generate_Sample_Order_Controller.getOpportunityContacts(getOpp().Id);
        Test.stopTest();
    }
    
    /** Covers: null oppId → SOQL throws → AuraHandledException catch block */
    @isTest
    static void testGetOpportunityContacts_NullId() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.getOpportunityContacts(null);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
    
    // =========================================================================
    // getAccountPaymentTerms
    // =========================================================================
    
    @isTest
    static void testGetAccountPaymentTerms() {
        Test.startTest();
        String result =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountPaymentTerms(getOpp().Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // getOpportunityCurrency
    // =========================================================================
    
    @isTest
    static void testGetOpportunityCurrency() {
        Test.startTest();
        String result =
            DRC_NBC_Generate_Sample_Order_Controller.getOpportunityCurrency(getOpp().Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // getAllProducts
    // =========================================================================
    
    /**
* Covers: PBE loop → ProductWrapper constructor
*         buildPackingDetailsList:
*           - !tempMap.containsKey() → TRUE → new list created
*           - containsKey() → TRUE (second pd for prod1) → existing list appended
*           - DRC_NBC_Packing_Qauntity__c != null → String.valueOf() branch
*           - DRC_NBC_Packing_Qauntity__c == null → qtyStr = '' branch (prod2)
*         ProductSearchResult constructor
*/
    @isTest
    static void testGetAllProducts() {
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.ProductSearchResult result =
            DRC_NBC_Generate_Sample_Order_Controller.getAllProducts(getOpp().Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // searchProducts
    // =========================================================================
    
    /**
* Covers: allowedProductIds NOT empty → restricted SOQL branch
*         seenProductIds dedup (first occurrence → added, subsequent → skipped)
*         buildPackingDetailsList with non-null packing qty
*/
    @isTest
    static void testSearchProducts_WithRestriction() {
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.ProductSearchResult result =
            DRC_NBC_Generate_Sample_Order_Controller.searchProducts(
                'Sample Product 1', 'INR', getOpp().Id);
        Test.stopTest();
    }
    
    /**
* Covers: allowedProductIds empty → unrestricted SOQL branch
*         buildPackingDetailsList with null qty (prod2) → qtyStr = ''
*/
    @isTest
    static void testSearchProducts_WithoutRestriction() {
        // Account with no restricted products → allowedProductIds stays empty
        Account accFree = new Account(Name = 'Free Account');
        insert accFree;
        
        Opportunity oppFree = new Opportunity(
            Name            = 'Free Opp',
            StageName       = 'Prospecting',
            CloseDate       = Date.today().addDays(5),
            AccountId       = accFree.Id,
            CurrencyIsoCode = 'INR',
            Pricebook2Id    = Test.getStandardPricebookId()
        );
        insert oppFree;
        
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.ProductSearchResult result =
            DRC_NBC_Generate_Sample_Order_Controller.searchProducts(
                'Sample', 'INR', oppFree.Id);
        Test.stopTest();
    }
    
    /**
* Covers: searchProducts with prod1 keyword → seenProductIds dedup runs
*         specifically with the no-restriction path returning multiple rows
*/
    @isTest
    static void testSearchProducts_WithoutRestriction_MultipleProducts() {
        Account accFree = new Account(Name = 'Free Account 2');
        insert accFree;
        
        Opportunity oppFree = new Opportunity(
            Name            = 'Free Opp 2',
            StageName       = 'Prospecting',
            CloseDate       = Date.today().addDays(5),
            AccountId       = accFree.Id,
            CurrencyIsoCode = 'INR',
            Pricebook2Id    = Test.getStandardPricebookId()
        );
        insert oppFree;
        
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.ProductSearchResult result =
            DRC_NBC_Generate_Sample_Order_Controller.searchProducts(
                'Sample Product 2', 'INR', oppFree.Id);
        Test.stopTest();
    }
    
    /** Covers: String.isBlank(currencyIsoCode) → AuraHandledException */
    @isTest
    static void testSearchProducts_BlankCurrency() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.searchProducts(
                'Sample', '', getOpp().Id);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
    
    /** Covers: null currencyIsoCode → isBlank → AuraHandledException */
    @isTest
    static void testSearchProducts_NullCurrency() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.searchProducts(
                'Sample', null, getOpp().Id);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
    
    // =========================================================================
    // getAccountBillingAddress
    // =========================================================================
    
    /** Covers: happy path → AccountAddressWrapper constructor */
    @isTest
    static void testGetAccountBillingAddress_Success() {
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.AccountAddressWrapper result =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBillingAddress(getOpp().Id);
        Test.stopTest();
    }
    
    /** Covers: null oppId → exception → AuraHandledException catch block */
    @isTest
    static void testGetAccountBillingAddress_NullId() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBillingAddress(null);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
    
    // =========================================================================
    // getAccountAddresses
    // =========================================================================
    
    @isTest
    static void testGetAccountAddresses() {
        Test.startTest();
        List<DRC_NBC_Addresses__c> result =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountAddresses(getOpp().Id);
        Test.stopTest();
    }
    
    // =========================================================================
    // getAccountBankDetails
    // =========================================================================
    
    /** Covers: happy path → AccountBankDetailsWrapper constructor */
    @isTest
    static void testGetAccountBankDetails_Success() {
        Test.startTest();
        DRC_NBC_Generate_Sample_Order_Controller.AccountBankDetailsWrapper result =
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBankDetails(getOpp().Id);
        Test.stopTest();
    }
    
    /** Covers: null oppId → exception → AuraHandledException catch block */
    @isTest
    static void testGetAccountBankDetails_NullId() {
        Test.startTest();
        try {
            DRC_NBC_Generate_Sample_Order_Controller.getAccountBankDetails(null);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }
    
    // =========================================================================
    // createSampleOrder – EARLY RETURNS (before DML)
    // =========================================================================
    
    /** Covers: orderItems == null → 'No products selected' */
    @isTest
    static void testCreateSampleOrder_NullItems() {
        Opportunity opp = getOpp();
        Order ord = buildOrder(opp.AccountId, null, null, null, 'Draft', false);
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord, null, opp.Id);
        Test.stopTest();
    }
    
    /** Covers: orderItems.isEmpty() → 'No products selected' */
    @isTest
    static void testCreateSampleOrder_EmptyItems() {
        Opportunity opp = getOpp();
        Order ord = buildOrder(opp.AccountId, null, null, null, 'Draft', false);
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>(),
            opp.Id);
        Test.stopTest();
    }
    
    /**
* Covers: contacts loop → String.isBlank(con.Email) → TRUE
*         → early return 'Please provide email for …'
*         BillToContactId set to contact without email
*/
    @isTest
    static void testCreateSampleOrder_BillToContact_NoEmail() {
        Opportunity opp = getOpp();
        Contact noEmail = getConNoEmail();
        Product2 prod   = getProd1();
        
        Order ord = buildOrder(opp.AccountId, noEmail.Id, null, null, 'Draft', false);
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{
                makeItem(prod.Id, 1, 100, null, null, 'KGS')
                    },
            opp.Id);
        Test.stopTest();
    }
    
    /**
* Covers: ShipToContactId set to contact without email
*         → same contacts loop early-return path
*/
    @isTest
    static void testCreateSampleOrder_ShipToContact_NoEmail() {
        Opportunity opp = getOpp();
        Contact noEmail = getConNoEmail();
        Product2 prod   = getProd1();
        
        Order ord = buildOrder(opp.AccountId, null, noEmail.Id, null, 'Draft', false);
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{
                makeItem(prod.Id, 1, 100, null, null, 'KGS')
                    },
            opp.Id);
        Test.stopTest();
    }
    
   
    @isTest
    static void testCreateSampleOrder_FullSuccess_PricebookUpdate_ShippingUpdate() {
        Opportunity opp     = getOpp();
        Contact con         = getConEmail();
        Product2 prod       = getProd1();
        DRC_NBC_Addresses__c shipAddr = getShipAddr();
        
        // Set opp to standard pricebook → controller triggers the pricebook update branch
        Opportunity oppUpd = [SELECT Id FROM Opportunity WHERE Id = :opp.Id];
        oppUpd.Pricebook2Id = Test.getStandardPricebookId();
        update oppUpd;
        
        Order ord = buildOrder(opp.AccountId, con.Id, null, shipAddr.Id, 'Requested', false);
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{
                makeItem(prod.Id, 5, 100, '25KG', 40, 'KGS')
                    },
            opp.Id);
        Test.stopTest();
    }
   
    @isTest
    static void testCreateSampleOrder_NoPricebookUpdate_NullDefaults_NoShipping() {
        Opportunity opp = getOpp();
        Contact con     = getConEmail();
        Product2 prod   = getProd1();
        
        // Build order with null EffectiveDate, Status, CurrencyIsoCode
        Order ord = new Order();
        ord.AccountId       = opp.AccountId;
        ord.Pricebook2Id    = Test.getStandardPricebookId();
        ord.EffectiveDate   = null;   // → Date.today() fallback
        ord.Status          = null;   // → 'Requested' fallback
        ord.CurrencyIsoCode = null;   // → opp.CurrencyIsoCode fallback
        ord.BillToContactId = con.Id;
        // DRC_NBC_Shipping_Address__c intentionally null
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{
                makeItem(prod.Id, 3, 100, '25KG', null, 'KGS')  // PackingQuantity null
                    },
            opp.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testCreateSampleOrder_MultipleProducts_BothContacts() {
        Opportunity opp  = getOpp();
        Contact con      = getConEmail();
        Product2 prod1   = getProd1();
        Product2 prod2   = getProd2();
        
        // Second contact with email
        Contact con2 = new Contact(
            FirstName = 'Bob', LastName = 'Jones',
            Email     = 'bob.jones@example.com',
            AccountId = opp.AccountId
        );
        insert con2;
        
        Order ord = buildOrder(opp.AccountId, con.Id, con2.Id, null, 'Draft', false);
        
        Test.startTest();
        String result = DRC_NBC_Generate_Sample_Order_Controller.createSampleOrder(
            ord,
            new List<DRC_NBC_Generate_Sample_Order_Controller.OrderItemWrapper>{
                makeItem(prod1.Id, 2, 100, null, null, 'KGS'),
                    makeItem(prod2.Id, 3, 200, null, null, 'LTR')
                    },
            opp.Id);
        Test.stopTest();
    }
}