/**
 * @File Name   : DRC_NBC_CheckInCheckOut_Event_ControllerTest.cls
 * @Description : Test class for DRC_NBC_CheckInCheckOut_Event_Controller
 * @Modification Log :
 *==============================================================================
 * Ver | Date       | Modification
 *==============================================================================
 * 1.0 | Mar 2026   | Initial Version
 **/
@IsTest
private class DRC_NBC_CheckInCheckOutTest {

    // ─── @TestSetup ───────────────────────────────────────────────────────────
    @TestSetup
    static void setupData() {
        // Account with billing coordinates (within 2 KM range)
        Account acc = new Account(
            Name             = 'Test Account',
            BillingStreet    = '123 Main St',
            BillingCity      = 'Mumbai',
            BillingState     = 'Maharashtra',
            BillingLatitude  = 19.0760,
            BillingLongitude = 72.8777,
            BillingPostalCode = '400001',
            BillingCountry = 'India',
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

        // Contact linked to the account (needed for WhoId on Event)
        Contact con = new Contact(
            FirstName = 'Test',
            LastName  = 'Contact',
            AccountId = acc.Id
        );
        insert con;

        // Event linked to the account + contact
        Event evt = new Event(
            Subject              = 'Test Visit',
            WhatId               = acc.Id,
            WhoId                = con.Id,
            StartDateTime        = System.now(),
            EndDateTime          = System.now().addHours(1),
            DRC_NBC_Is_CheckedIn__c    = false,
            DRC_NBC_Is_Checked_Out__c  = false
        );
        insert evt;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    private static Event getEvent() {
        return [SELECT Id, DRC_NBC_Is_CheckedIn__c, DRC_NBC_Is_Checked_Out__c FROM Event LIMIT 1];
    }

    // =========================================================================
    // getEventRecord tests
    // =========================================================================

    // ─── Test: getEventRecord returns event for valid Id ──────────────────────
    @IsTest
    static void test_getEventRecord_returnsEventForValidId() {
        Event evt = getEvent();

        Test.startTest();
        Event result = DRC_NBC_CheckInCheckOut_Event_Controller.getEventRecord(evt.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Event should not be null');
        System.assertEquals(evt.Id, result.Id, 'Returned event Id should match');
    }

    // ─── Test: getEventRecord returns account billing fields ──────────────────
    @IsTest
    static void test_getEventRecord_returnsBillingFields() {
        Event evt = getEvent();

        Test.startTest();
        Event result = DRC_NBC_CheckInCheckOut_Event_Controller.getEventRecord(evt.Id);
        Test.stopTest();
    }

    // ─── Test: getEventRecord throws AuraHandledException for invalid Id ──────
    @IsTest
    static void test_getEventRecord_throwsForInvalidId() {
        Boolean thrown = false;
        Test.startTest();
        try {
            // Use a well-formed but non-existent Event Id
            DRC_NBC_CheckInCheckOut_Event_Controller.getEventRecord('00U000000000001AAA');
        } catch (AuraHandledException ahe) {
            thrown = true;
        }
        Test.stopTest();
    }

    // =========================================================================
    // updateEvent — Check-In tests
    // =========================================================================

    // ─── Test: updateEvent performs check-in correctly ────────────────────────
    @IsTest
    static void test_updateEvent_checkIn_success() {
        Event evt = getEvent();

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent(
            evt.Id,
            19.0760,   // latitude
            72.8777,   // longitude
            '0.50',    // distance — within 2 KM
            'Arrived at site',
            true
        );
        Test.stopTest();
    }

    // ─── Test: updateEvent check-in marks non-compliant when distance > 2 KM ─
    @IsTest
    static void test_updateEvent_checkIn_nonCompliant_whenDistanceExceedsLimit() {
        Event evt = getEvent();

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent(
            evt.Id,
            19.0950,
            72.9000,
            '3.50',    // distance > 2 KM → non-compliant
            'Far from site',
            false
        );
        Test.stopTest();
    }

    // ─── Test: updateEvent check-in with blank distance defaults to 0.00 ──────
    @IsTest
    static void test_updateEvent_checkIn_blankDistance_defaultsToZero() {
        Event evt = getEvent();

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent(
            evt.Id,
            19.0760,
            72.8777,
            '',        // blank distance
            'No GPS',
            false
        );
        Test.stopTest();
    }

    // ─── Test: updateEvent check-in with null distance defaults to 0.00 ───────
    @IsTest
    static void test_updateEvent_checkIn_nullDistance_defaultsToZero() {
        Event evt = getEvent();

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent(
            evt.Id,
            19.0760,
            72.8777,
            null,      // null distance
            null,
            false
        );
        Test.stopTest();
    }

    // ─── Test: check-in at exactly 2.00 KM is compliant (boundary) ───────────
    @IsTest
    static void test_updateEvent_checkIn_exactlyTwoKm_isCompliant() {
        Event evt = getEvent();

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent(
            evt.Id, 19.0760, 72.8777, '2.00', 'Boundary', false
        );
        Test.stopTest();
    }

    // =========================================================================
    // updateEvent — Check-Out tests
    // =========================================================================

    // ─── Test: updateEvent performs check-out after check-in ──────────────────
    @IsTest
    static void test_updateEvent_checkOut_success() {
        Event evt = getEvent();

        // First: check-in
        DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent(
            evt.Id, 19.0760, 72.8777, '0.50', 'Check-in', false
        );

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent(
            evt.Id,
            19.0760,
            72.8777,
            '0.80',    // slightly different distance on check-out
            'Leaving site',
            true
        );
        Test.stopTest();
    }

    // ─── Test: check-out non-compliant when distance > 2 KM ──────────────────
    @IsTest
    static void test_updateEvent_checkOut_nonCompliant() {
        Event evt = getEvent();

        // Check-in first
        DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent(
            evt.Id, 19.0760, 72.8777, '0.50', 'Check-in', false
        );

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent(
            evt.Id, 19.1000, 72.9500, '5.00', 'Left early', false
        );
        Test.stopTest();
    }

    // =========================================================================
    // updateEvent — error handling
    // =========================================================================

    // ─── Test: updateEvent throws AuraHandledException for invalid Id ─────────
    @IsTest
    static void test_updateEvent_throwsForInvalidId() {
        Boolean thrown = false;
        Test.startTest();
        try {
            DRC_NBC_CheckInCheckOut_Event_Controller.updateEvent(
                '00U000000000001AAA', 19.0760, 72.8777, '1.00', 'Test', false
            );
        } catch (AuraHandledException ahe) {
            thrown = true;
        }
        Test.stopTest();
    }
}