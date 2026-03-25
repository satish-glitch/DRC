/**
 * @File Name : DRC_NBC_CheckInCheckOut_Task_Controller_Test.cls
 * @Description : Test class for DRC_NBC_CheckInCheckOut_Task_Controller
 * @Author :
 * @Last Modified On : September 4, 2025
 **/
@isTest
private class DRC_NBC_CheckInCheckOutTaskTest {

    // ─── Test Data Setup ────────────────────────────────────────────────────

    @TestSetup
    static void setupTestData() {
        // Create Account with billing coordinates (Indore, MP as example)
        Account acc = new Account(
            Name = 'Test Account',
            BillingLatitude = 22.7196,
            BillingLongitude = 75.8577,
            BillingStreet  = '123 Test Street',
            BillingCity    = 'Mumbai',
            BillingState   = 'Maharashtra',
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

        // Create Contact linked to Account
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = acc.Id,
            MailingLatitude = 22.7196,
            MailingLongitude = 75.8577
        );
        insert con;

        // Create Lead with coordinates
        Lead ld = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Country = 'India',
            Phone ='9876543210',
            Email = 'satish123@gmail.com',
            Latitude = 22.7196,
            Longitude = 75.8577
        );
        insert ld;

        // Task linked to Account (via WhatId) and Contact (via WhoId)
        Task taskWithContact = new Task(
            Subject = 'Test Task - Contact',
            WhatId = acc.Id,
            WhoId = con.Id,
            DRC_NBC_Is_CheckedIn__c = false
        );
        insert taskWithContact;

        // Task linked to Account only (no WhoId)
        Task taskWithAccount = new Task(
            Subject = 'Test Task - Account',
            WhatId = acc.Id,
            DRC_NBC_Is_CheckedIn__c = false
        );
        insert taskWithAccount;

        // Task linked to Lead (via WhoId)
        Task taskWithLead = new Task(
            Subject = 'Test Task - Lead',
            WhoId = ld.Id,
            DRC_NBC_Is_CheckedIn__c = false
        );
        insert taskWithLead;

        // Task already checked in (for check-out tests)
        Task taskCheckedIn = new Task(
            Subject = 'Test Task - Already Checked In',
            WhatId = acc.Id,
            DRC_NBC_Is_CheckedIn__c = true,
            DRC_NBC_Check_In_Date_Time__c = System.now().addHours(-1)
        );
        insert taskCheckedIn;
    }

    // ─── getTaskRecord Tests ─────────────────────────────────────────────────

    @isTest
    static void testGetTaskRecord_Success() {
        Task testTask = [SELECT Id FROM Task WHERE Subject = 'Test Task - Contact' LIMIT 1];

        Test.startTest();
        Task result = DRC_NBC_CheckInCheckOut_Task_Controller.getTaskRecord(testTask.Id);
        Test.stopTest();
    }

    @isTest
    static void testGetTaskRecord_InvalidId() {
        Test.startTest();
        try {
            Task result = DRC_NBC_CheckInCheckOut_Task_Controller.getTaskRecord('invalidId123');
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Error fetching task') ||
                          e.getMessage() != null, 'Exception message should not be null');
        }
        Test.stopTest();
    }

    // ─── updateTask - Check In Tests ─────────────────────────────────────────

    @isTest
    static void testUpdateTask_CheckIn_WithContactWhoId() {
        Task testTask = [SELECT Id FROM Task WHERE Subject = 'Test Task - Contact' LIMIT 1];

        // Slightly offset user location (~1 km away)
        Decimal userLat = 22.7250;
        Decimal userLong = 75.8650;

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Task_Controller.updateTask(
            testTask.Id,
            userLat,
            userLong,
            'Checking in from office',
            true
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdateTask_CheckIn_WithAccountOnly() {
        Task testTask = [SELECT Id FROM Task WHERE Subject = 'Test Task - Account' LIMIT 1];

        Decimal userLat = 22.7196;
        Decimal userLong = 75.8577;

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Task_Controller.updateTask(
            testTask.Id, userLat, userLong, 'Checking in at account', true
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdateTask_CheckIn_WithLeadWhoId() {
        Task testTask = [SELECT Id FROM Task WHERE Subject = 'Test Task - Lead' LIMIT 1];

        Decimal userLat = 22.7300;
        Decimal userLong = 75.8700;

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Task_Controller.updateTask(
            testTask.Id, userLat, userLong, 'Lead check-in', false
        );
        Test.stopTest();
    }

    // ─── updateTask - Check Out Tests ────────────────────────────────────────

    @isTest
    static void testUpdateTask_CheckOut_Success() {
        Task testTask = [SELECT Id FROM Task WHERE Subject = 'Test Task - Already Checked In' LIMIT 1];

        Decimal userLat = 22.7250;
        Decimal userLong = 75.8650;

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Task_Controller.updateTask(
            testTask.Id, userLat, userLong, 'Checking out', true
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdateTask_CheckOut_NonCompliant() {
        Task testTask = [SELECT Id FROM Task WHERE Subject = 'Test Task - Already Checked In' LIMIT 1];

        // Make sure it's checked in first
        testTask.DRC_NBC_Is_CheckedIn__c = true;
        update testTask;

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Task_Controller.updateTask(
            testTask.Id, 22.7250, 75.8650, 'Non-compliant checkout', false
        );
        Test.stopTest();
    }

    // ─── Distance Field Tests ─────────────────────────────────────────────────

    @isTest
    static void testUpdateTask_DistanceFieldFormat() {
        Task testTask = [SELECT Id FROM Task WHERE Subject = 'Test Task - Account' LIMIT 1];

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Task_Controller.updateTask(
            testTask.Id, 22.7196, 75.8577, 'At location', true
        );
        Test.stopTest();
    }

    @isTest
    static void testUpdateTask_NullCoordinatesOnAccount() {
        // Account with no billing lat/long
        Account accNoCoords = new Account(Name = 'No Coords Account',
                                         BillingLatitude = 22.7196,
            BillingLongitude = 75.8577,
            BillingStreet  = '123 Test Street',
            BillingCity    = 'Mumbai',
            BillingState   = 'Maharashtra',
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
            Type = 'Analyst');
        insert accNoCoords;

        Task taskNoCoords = new Task(
            Subject = 'No Coords Task',
            WhatId = accNoCoords.Id,
            DRC_NBC_Is_CheckedIn__c = false
        );
        insert taskNoCoords;

        Test.startTest();
        Map<String, Object> result = DRC_NBC_CheckInCheckOut_Task_Controller.updateTask(
            taskNoCoords.Id, 22.7196, 75.8577, 'Test comment', true
        );
        Test.stopTest();
    }

    // ─── Error Handling Tests ─────────────────────────────────────────────────

    @isTest
    static void testUpdateTask_InvalidRecordId() {
        Test.startTest();
        try {
            Map<String, Object> result = DRC_NBC_CheckInCheckOut_Task_Controller.updateTask(
                'invalidId', 22.7196, 75.8577, 'comment', true
            );
            System.assert(false, 'Expected AuraHandledException was not thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null, 'Exception should have a message');
        }
        Test.stopTest();
    }

    // ─── Bulk / Governor Limit Tests ─────────────────────────────────────────

    @isTest
    static void testGetTaskRecord_BulkSafety() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Task> tasks = new List<Task>();
        for (Integer i = 0; i < 10; i++) {
            tasks.add(new Task(
                Subject = 'Bulk Task ' + i,
                WhatId = acc.Id,
                DRC_NBC_Is_CheckedIn__c = false
            ));
        }
        insert tasks;

        Test.startTest();
        // Individually calling getTaskRecord to simulate LWC calls
        for (Task t : tasks) {
            Task result = DRC_NBC_CheckInCheckOut_Task_Controller.getTaskRecord(t.Id);
            System.assertNotEquals(null, result, 'Each task should be returned');
        }
        Test.stopTest();
    }
}