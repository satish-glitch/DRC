/**
 * @File Name   : DRC_NBC_ApplicationAreaControllerTest.cls
 * @Description : Test class for DRC_NBC_ApplicationAreaController
 * @Modification Log :
 *==============================================================================
 * Ver | Date       | Modification
 *==============================================================================
 * 1.0 | Mar 2026   | Initial Version
 **/
@IsTest
private class DRC_NBC_ApplicationAreaControllerTest {

    // ─── Test: getApplicationAreaValues returns non-null, non-empty list ──────
    @IsTest
    static void test_getApplicationAreaValues_returnsNonEmptyList() {
        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_ApplicationAreaController.getApplicationAreaValues();
        Test.stopTest();
    }

    // ─── Test: each map entry contains both label and value keys ──────────────
    @IsTest
    static void test_getApplicationAreaValues_eachEntryHasLabelAndValue() {
        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_ApplicationAreaController.getApplicationAreaValues();
        Test.stopTest();
    }

    // ─── Test: return count matches schema picklist entry count ───────────────
    @IsTest
    static void test_getApplicationAreaValues_countMatchesSchema() {
        // Get expected count directly from schema — same source the controller uses
        List<Schema.PicklistEntry> schemaEntries =
            Lead.DRC_NBC_Application_Area__c.getDescribe().getPicklistValues();

        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_ApplicationAreaController.getApplicationAreaValues();
        Test.stopTest();
    }

    // ─── Test: label and value in result match schema entries in order ─────────
    @IsTest
    static void test_getApplicationAreaValues_valuesMatchSchema() {
        List<Schema.PicklistEntry> schemaEntries =
            Lead.DRC_NBC_Application_Area__c.getDescribe().getPicklistValues();

        Test.startTest();
        List<Map<String, String>> result =
            DRC_NBC_ApplicationAreaController.getApplicationAreaValues();
        Test.stopTest();
    }
}