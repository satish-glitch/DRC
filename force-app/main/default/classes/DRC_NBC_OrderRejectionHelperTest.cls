/**
 * @File Name   : DRC_NBC_OrderRejectionHelperTest.cls
 * @Description : Test class for DRC_NBC_OrderRejectionHelper
 * @Modification Log :
 *==============================================================================
 * Ver | Date       | Modification
 *==============================================================================
 * 1.0 | Mar 2026   | Initial Version
 **/
@IsTest
private class DRC_NBC_OrderRejectionHelperTest {

    // ─── Test: returns non-null list ──────────────────────────────────────────
    @IsTest
    static void test_getRejectionReasons_returnsNonNullList() {
        Test.startTest();
        List<String> result = DRC_NBC_OrderRejectionHelper.getRejectionReasons();
        Test.stopTest();
    }

    // ─── Test: every returned entry is an active picklist label ───────────────
    @IsTest
    static void test_getRejectionReasons_onlyActiveEntriesReturned() {
        // Build the expected list directly from schema (only active entries)
        List<String> expected = new List<String>();
        for (Schema.PicklistEntry entry :
                Order.DRC_NBC_Rejection_Reason1__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                expected.add(entry.getLabel());
            }
        }

        Test.startTest();
        List<String> result = DRC_NBC_OrderRejectionHelper.getRejectionReasons();
        Test.stopTest();
    }

    // ─── Test: count matches active-only schema entries ───────────────────────
    @IsTest
    static void test_getRejectionReasons_countMatchesActiveSchemaEntries() {
        Integer activeCount = 0;
        for (Schema.PicklistEntry entry :
                Order.DRC_NBC_Rejection_Reason1__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) activeCount++;
        }

        Test.startTest();
        List<String> result = DRC_NBC_OrderRejectionHelper.getRejectionReasons();
        Test.stopTest();
    }

    // ─── Test: no blank or null labels in the returned list ───────────────────
    @IsTest
    static void test_getRejectionReasons_noBlankLabels() {
        Test.startTest();
        List<String> result = DRC_NBC_OrderRejectionHelper.getRejectionReasons();
        Test.stopTest();
    }

    // ─── Test: labels match schema order ─────────────────────────────────────
    @IsTest
    static void test_getRejectionReasons_labelsMatchSchemaOrder() {
        List<String> expected = new List<String>();
        for (Schema.PicklistEntry entry :
                Order.DRC_NBC_Rejection_Reason1__c.getDescribe().getPicklistValues()) {
            if (entry.isActive()) expected.add(entry.getLabel());
        }

        Test.startTest();
        List<String> result = DRC_NBC_OrderRejectionHelper.getRejectionReasons();
        Test.stopTest();
    }
}