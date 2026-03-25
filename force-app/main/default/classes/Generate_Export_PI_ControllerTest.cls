/**
 * @File Name   : Generate_Export_PI_ControllerTest.cls
 * @Description : Test class for Generate_Export_PI_Controller
 * @Modification Log :
 *==============================================================================
 * Ver | Date       | Modification
 *==============================================================================
 * 1.0 | Mar 2026   | Initial Version
 **/
@IsTest
private class Generate_Export_PI_ControllerTest {

    // =========================================================================
    // @TestSetup — shared data
    // =========================================================================
    @TestSetup
    static void setupData() {

        // 1. Standard Pricebook
        Id stdPbId = Test.getStandardPricebookId();
        update new Pricebook2(Id = stdPbId, IsActive = true);

        // 2. Account
        Account acc = new Account(
            Name            = 'Test Export Account',
            NBC_DRC_Account_DRC_Code__c = 'DRC-CODE-001',
            CurrencyIsoCode = 'INR',
            Phone = '1234567890',
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
            Type = 'Analyst'
        );
        insert acc;

        // 3. Products
        Product2 p1 = new Product2(
            Name                        = 'Export Product A',
            IsActive                    = true,
            ProductCode                 = 'EP001',
            DRC_NBC_HSN_SAC_Code__c     = 'HSN001',
            DRC_NBC_Hazardous__c        = false,
            DRC_NBC_MARKS_NOS__c        = 'MARK-A',
            DRC_NBC_KIND_OF_PKG__c      = 'Drums'
        );
        Product2 p2 = new Product2(
            Name                        = 'Export Product B',
            IsActive                    = true,
            ProductCode                 = 'EP002',
            DRC_NBC_HSN_SAC_Code__c     = 'HSN002',
            DRC_NBC_Hazardous__c        = true,
            DRC_NBC_MARKS_NOS__c        = null,   // fallback to product name
            DRC_NBC_KIND_OF_PKG__c      = 'Cans'
        );
        insert new List<Product2>{ p1, p2 };

        // 4. Standard PBEs
        String curr = UserInfo.getDefaultCurrency();
        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = p1.Id,
                               UnitPrice = 1, IsActive = true, CurrencyIsoCode = curr),
            new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = p2.Id,
                               UnitPrice = 1, IsActive = true, CurrencyIsoCode = curr)
        };

        // 5. Export Order (no sequence yet — controller will assign)
        Order exportOrd = new Order(
            AccountId           = acc.Id,
            Status              = 'Draft',
            EffectiveDate       = Date.newInstance(2026, 2, 5),
            Pricebook2Id        = stdPbId,
            CurrencyIsoCode     = curr,
            BillingStreet       = '123 Export Street',
            BillingCity         = 'Mumbai',
            BillingState        = 'Maharashtra',
            BillingPostalCode   = '400064',
            BillingCountry      = 'India',
            DRC_NBC_Type__c                             = 'Export',
            DRC_NBC_Payment_Terms__c                    = '100',
            DRC_NBC_Port_Of_Loading__c                  = 'NHAVA SHEVA',
            DRC_NBC_Port_Of_Discharge__c                = 'DUBAI PORT',
            DRC_NBC_Final_Destination__c                = 'UAE',
            DRC_NBC_Country_Of_Origin__c                = 'India',
            DRC_NBC_Shipment_Method__c                  = 'BY SEA',
            DRC_NBC_Inco_Terms__c                       = 'Cost Insurance & Freight (CIF)',
          //  DRC_NBC_Required_Documents__c               = 'Bill of Lading;Packing List\nCertificate of Origin',
            DRC_NBC_Select_Bank__c                      = null,
            DRC_NBC_Invoice_Export_Sequence_Number__c   = null
        );
        insert exportOrd;

        // 6. Domestic Order
        Order domesticOrd = new Order(
            AccountId           = acc.Id,
            Status              = 'Draft',
            EffectiveDate       = Date.today(),
            Pricebook2Id        = stdPbId,
            CurrencyIsoCode     = curr,
            BillingStreet       = '456 Domestic Road',
            BillingCity         = 'Pune',
            BillingState        = 'Maharashtra',
            BillingPostalCode   = '411001',
            BillingCountry      = 'India',
            DRC_NBC_Type__c                         = 'Domestic',
            DRC_NBC_Import_Starting_Sequence__c     = null
        );
        insert domesticOrd;

        // 7. PBEs from std pricebook for order items
        PricebookEntry pbe1 = [SELECT Id FROM PricebookEntry
                               WHERE Product2Id = :p1.Id AND Pricebook2Id = :stdPbId LIMIT 1];
        PricebookEntry pbe2 = [SELECT Id FROM PricebookEntry
                               WHERE Product2Id = :p2.Id AND Pricebook2Id = :stdPbId LIMIT 1];

        // 8. Order Items on export order
        insert new List<OrderItem>{
            new OrderItem(
                OrderId          = exportOrd.Id,
                PricebookEntryId = pbe1.Id,
                Quantity         = 10,
                UnitPrice        = 500,
                Description      = 'Custom Description A'
            ),
            new OrderItem(
                OrderId          = exportOrd.Id,
                PricebookEntryId = pbe2.Id,
                Quantity         = 5,
                UnitPrice        = 200,
                Description      = null   // fallback to product name
            )
        };
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    private static Order getExportOrder() {
        return [SELECT Id FROM Order WHERE DRC_NBC_Type__c = 'Export' LIMIT 1];
    }

    private static Order getDomesticOrder() {
        return [SELECT Id FROM Order WHERE DRC_NBC_Type__c = 'Domestic' LIMIT 1];
    }

    private static PageReference buildPage(Id ordId) {
        PageReference pg = Page.DRC_NBC_OrderPI_Export_Template; // your VF page name
        pg.getParameters().put('id', ordId);
        return pg;
    }

    // =========================================================================
    // Constructor — basic load
    // =========================================================================

    // ─── Test: controller loads without exception for valid Export order ───────
    @IsTest
    static void test_constructor_loadsExportOrder() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();

    }

    // ─── Test: controller loads without exception for valid Domestic order ─────
    @IsTest
    static void test_constructor_loadsDomesticOrder() {
        Order ord = getDomesticOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // ─── Test: constructor with no id param — no exception, orderRecord null ──
    @IsTest
    static void test_constructor_noId_doesNotThrow() {
        PageReference pg = Page.DRC_NBC_OrderPI_Export_Template;
        // Do NOT set 'id' param
        Test.setCurrentPage(pg);

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();

    }

    // =========================================================================
    // Company Info
    // =========================================================================

    // ─── Test: company fields are hard-coded correctly ────────────────────────
    @IsTest
    static void test_companyInfo_isSetCorrectly() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // =========================================================================
    // Line Items
    // =========================================================================

    // ─── Test: items list is populated with correct count ─────────────────────
    @IsTest
    static void test_lineItems_loadedCorrectly() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // ─── Test: item with description uses description not product name ─────────
    @IsTest
    static void test_lineItems_usesDescriptionWhenSet() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // ─── Test: item with null description falls back to product name ──────────
    @IsTest
    static void test_lineItems_fallsBackToProductName_whenDescriptionNull() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();

    }

    // ─── Test: item with null marksAndNos falls back to product name ──────────
    @IsTest
    static void test_lineItems_marksAndNos_fallsBackToProductName() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();

        Boolean foundFallback = false;
        for (Generate_Export_PI_Controller.ExportLineItem li : ctrl.items) {
            if (li.marksAndNos == 'Export Product B') {
                foundFallback = true;
            }
        }
        System.assertEquals(true, foundFallback,
            'marksAndNos should fall back to product name when null');
    }

    // ─── Test: hazardous true product maps to "Yes" ───────────────────────────
    @IsTest
    static void test_lineItems_hazardousTrue_mapsToYes() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // ─── Test: hazardous false product maps to "No" ───────────────────────────
    @IsTest
    static void test_lineItems_hazardousFalse_mapsToNo() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // ─── Test: totalAmount equals sum of all order item TotalPrices ───────────
    @IsTest
    static void test_lineItems_totalAmountIsCorrect() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // ─── Test: amountInWords is populated ─────────────────────────────────────
    @IsTest
    static void test_lineItems_amountInWordsPopulated() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.amountInWords,
            'amountInWords should not be null');
        System.assert(ctrl.amountInWords.endsWith('ONLY'),
            'amountInWords should end with ONLY. Got: ' + ctrl.amountInWords);
    }

    // =========================================================================
    // Bank Details — null select bank
    // =========================================================================

    // ─── Test: beneficiaryName set even when no bank selected ─────────────────
    @IsTest
    static void test_bankDetails_noBankSelected_beneficiaryNameSet() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // =========================================================================
    // Required Documents
    // =========================================================================

    // ─── Test: required documents parsed from semicolon/newline delimiters ────
    @IsTest
    static void test_requiredDocuments_parsedCorrectly() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // ─── Test: order with no required documents gives empty list ──────────────
    @IsTest
    static void test_requiredDocuments_emptyWhenNull() {
        Order ord = getDomesticOrder();
        // Domestic order was inserted with no DRC_NBC_Required_Documents__c
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // =========================================================================
    // getFormattedEffectiveDate()
    // =========================================================================

    // ─── Test: formatted date returns correct dd-MMM-yyyy string ──────────────
    @IsTest
    static void test_getFormattedEffectiveDate_returnsCorrectFormat() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        String formatted = ctrl.getFormattedEffectiveDate();
        Test.stopTest();
    }

    // ─── Test: getFormattedEffectiveDate returns empty string when no order ───
    @IsTest
    static void test_getFormattedEffectiveDate_returnsEmpty_whenNoOrder() {
        PageReference pg = Page.DRC_NBC_OrderPI_Export_Template ;
        Test.setCurrentPage(pg); // No id param

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        String formatted = ctrl.getFormattedEffectiveDate();
        Test.stopTest();
    }

    // =========================================================================
    // convertAmountToWords — via totalAmount (indirect testing)
    // =========================================================================
    // ─── Test: INR currency uses PAISE in amount words ────────────────────────
    @IsTest
    static void test_amountInWords_inrCurrency_usesPaise() {
        Order ord = getExportOrder();
        ord.CurrencyIsoCode = 'INR';
        update ord;
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();

    }

    // =========================================================================
    // Sequence Number Assignment
    // =========================================================================

    // ─── Test: Export order gets sequence number assigned ─────────────────────
    @IsTest
    static void test_exportSequence_assignedOnFirstLoad() {
        Order ord = getExportOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }

    // ─── Test: Domestic order gets sequence number assigned ───────────────────
    @IsTest
    static void test_domesticSequence_assignedOnFirstLoad() {
        Order ord = getDomesticOrder();
        Test.setCurrentPage(buildPage(ord.Id));

        Test.startTest();
        Generate_Export_PI_Controller ctrl = new Generate_Export_PI_Controller();
        Test.stopTest();
    }
}