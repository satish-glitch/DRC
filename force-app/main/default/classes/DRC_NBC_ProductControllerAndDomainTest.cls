/**
 * @File Name   : DRC_NBC_ProductControllerAndDomainTest.cls
 * @Description : Test class for DRC_NBC_ProductController and DRC_NBC_Product_Domain
 * @Modification Log :
 *==============================================================================
 * Ver | Date       | Modification
 *==============================================================================
 * 1.0 | Mar 2026   | Initial Version
 **/
@IsTest
private class DRC_NBC_ProductControllerAndDomainTest {

    // =========================================================================
    // @TestSetup — shared product data
    // =========================================================================
    @TestSetup
    static void setupData() {
        insert new List<Product2>{
            new Product2(
                Name                    = 'Product Alpha',
                IsActive                = true,
                DRC_NBC_Product_Code__c = 'PC001'
            ),
            new Product2(
                Name                    = 'Product Beta',
                IsActive                = true,
                DRC_NBC_Product_Code__c = 'PC002'
            ),
            new Product2(
                Name                    = 'Product Gamma',
                IsActive                = true,
                DRC_NBC_Product_Code__c = 'PC003'
            )
        };
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    private static Product2 getProduct(String name) {
        return [SELECT Id, Name, DRC_NBC_Product_Code__c FROM Product2 WHERE Name = :name LIMIT 1];
    }

    // =========================================================================
    // DRC_NBC_ProductController — getEventProductNames()
    // =========================================================================

    // ─── Test: returns non-null, non-empty list ───────────────────────────────
    @IsTest
    static void test_getEventProductNames_returnsNonEmptyList() {
        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_ProductController.getEventProductNames();
        Test.stopTest();
    }

    // ─── Test: every entry has both label and value keys ─────────────────────
    @IsTest
    static void test_getEventProductNames_eachEntryHasLabelAndValue() {
        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_ProductController.getEventProductNames();
        Test.stopTest();
    }

    // ─── Test: count matches schema picklist count ────────────────────────────
    @IsTest
    static void test_getEventProductNames_countMatchesSchema() {
        List<Schema.PicklistEntry> schemaEntries =
            Lead.DRC_NBC_Interested_Chemistry__c.getDescribe().getPicklistValues();

        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_ProductController.getEventProductNames();
        Test.stopTest();
    }

    // ─── Test: label and value match schema entries in order ─────────────────
    @IsTest
    static void test_getEventProductNames_valuesMatchSchema() {
        List<Schema.PicklistEntry> schemaEntries =
            Lead.DRC_NBC_Interested_Chemistry__c.getDescribe().getPicklistValues();

        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_ProductController.getEventProductNames();
        Test.stopTest();
    }

    // =========================================================================
    // DRC_NBC_Product_Domain — getProductByProductCodes()
    // =========================================================================

    // ─── Test: returns map with matching products for given codes ─────────────
    @IsTest
    static void test_getProductByProductCodes_returnsMatchingProducts() {
        Test.startTest();
        Map<Id, Product2> result =
            DRC_NBC_Product_Domain.getProductByProductCodes(
                new Set<String>{ 'PC001', 'PC002' }
            );
        Test.stopTest();
    }

    // ─── Test: returns empty map for codes that don't exist ──────────────────
    @IsTest
    static void test_getProductByProductCodes_returnsEmptyMap_forUnknownCodes() {
        Test.startTest();
        Map<Id, Product2> result =
            DRC_NBC_Product_Domain.getProductByProductCodes(
                new Set<String>{ 'UNKNOWN001', 'UNKNOWN002' }
            );
        Test.stopTest();
    }

    // ─── Test: returns empty map for empty code set ───────────────────────────
    @IsTest
    static void test_getProductByProductCodes_returnsEmptyMap_forEmptySet() {
        Test.startTest();
        Map<Id, Product2> result =
            DRC_NBC_Product_Domain.getProductByProductCodes(new Set<String>());
        Test.stopTest();

    }

    // ─── Test: map keys are Product2 Ids ─────────────────────────────────────
    @IsTest
    static void test_getProductByProductCodes_mapKeyIsProductId() {
        Product2 p1 = getProduct('Product Alpha');

        Test.startTest();
        Map<Id, Product2> result =
            DRC_NBC_Product_Domain.getProductByProductCodes(new Set<String>{ 'PC001' });
        Test.stopTest();
    }

    // ─── Test: returns single product for single matching code ────────────────
    @IsTest
    static void test_getProductByProductCodes_singleCode_returnsSingleProduct() {
        Test.startTest();
        Map<Id, Product2> result =
            DRC_NBC_Product_Domain.getProductByProductCodes(new Set<String>{ 'PC003' });
        Test.stopTest();
    }

    // ─── Test: returns all three products when all codes passed ──────────────
    @IsTest
    static void test_getProductByProductCodes_allCodes_returnsAllProducts() {
        Test.startTest();
        Map<Id, Product2> result =
            DRC_NBC_Product_Domain.getProductByProductCodes(
                new Set<String>{ 'PC001', 'PC002', 'PC003' }
            );
        Test.stopTest();
    }

    // =========================================================================
    // DRC_NBC_Product_Domain — getProductGroupByCode()
    // =========================================================================

    // ─── Test: returns map keyed by product code ──────────────────────────────
    @IsTest
    static void test_getProductGroupByCode_returnsCodeKeyedMap() {
        Test.startTest();
        Map<String, Product2> result =
            DRC_NBC_Product_Domain.getProductGroupByCode(
                new Set<String>{ 'PC001', 'PC002' }
            );
        Test.stopTest();
    }

    // ─── Test: each map value has the correct product code ───────────────────
    @IsTest
    static void test_getProductGroupByCode_valuesHaveCorrectCodes() {
        Test.startTest();
        Map<String, Product2> result =
            DRC_NBC_Product_Domain.getProductGroupByCode(
                new Set<String>{ 'PC001', 'PC002', 'PC003' }
            );
        Test.stopTest();
    }

    // ─── Test: returns empty map for unknown codes ────────────────────────────
    @IsTest
    static void test_getProductGroupByCode_returnsEmptyMap_forUnknownCodes() {
        Test.startTest();
        Map<String, Product2> result =
            DRC_NBC_Product_Domain.getProductGroupByCode(
                new Set<String>{ 'NOPE001' }
            );
        Test.stopTest();
    }

    // ─── Test: returns empty map for empty input set ──────────────────────────
    @IsTest
    static void test_getProductGroupByCode_returnsEmptyMap_forEmptySet() {
        Test.startTest();
        Map<String, Product2> result =
            DRC_NBC_Product_Domain.getProductGroupByCode(new Set<String>());
        Test.stopTest();
    }

    // ─── Test: product Name field is populated on returned values ─────────────
    @IsTest
    static void test_getProductGroupByCode_productNamePopulated() {
        Test.startTest();
        Map<String, Product2> result =
            DRC_NBC_Product_Domain.getProductGroupByCode(new Set<String>{ 'PC001' });
        Test.stopTest();
    }

    // ─── Test: all 3 codes returns 3 entries with correct names ──────────────
    @IsTest
    static void test_getProductGroupByCode_allCodes_returnsAllWithNames() {
        Test.startTest();
        Map<String, Product2> result =
            DRC_NBC_Product_Domain.getProductGroupByCode(
                new Set<String>{ 'PC001', 'PC002', 'PC003' }
            );
        Test.stopTest();
    }
}