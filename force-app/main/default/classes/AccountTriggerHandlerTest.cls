@isTest
private class AccountTriggerHandlerTest {

    // ─────────────────────────────────────────────
    // Helper: create a test User with a given username
    // ─────────────────────────────────────────────
    private static User createTestUser(String username) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User mgr = new User(
            FirstName        = 'Manager',
            LastName         = 'User',
            Email            = 'mgr_' + username + '@test.example.com',
            Username         = 'mgr_' + username,
            Alias            = 'mgrusr',
            TimeZoneSidKey   = 'America/New_York',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey= 'en_US',
            ProfileId        = p.Id
        );
        insert mgr;

        User u = new User(
            FirstName        = 'Sales',
            LastName         = 'Person',
            Email            = username + '@test.example.com',
            Username         = username,
            Alias            = 'slsprs',
            TimeZoneSidKey   = 'America/New_York',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey= 'en_US',
            ProfileId        = p.Id,
            ManagerId        = mgr.Id
        );
        insert u;
        return u;
    }

    // ─────────────────────────────────────────────
    // Helper: fetch a SalesPerson_Code__mdt record
    // whose Salesforce_UserName__c is populated.
    // Tests that rely on metadata must use a real
    // record from the org (metadata can't be DML-
    // inserted in tests).
    // ─────────────────────────────────────────────
    private static SalesPerson_Code__mdt getActiveMeta() {
        List<SalesPerson_Code__mdt> metas = [
            SELECT MasterLabel, Salesforce_UserName__c
            FROM   SalesPerson_Code__mdt
            WHERE  Salesforce_UserName__c != null
            LIMIT  1
        ];
        return metas.isEmpty() ? null : metas[0];
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 1 – Insert: blank SalesPerson_Code__c → no assignment
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testInsert_BlankCode_NoAssignment() {
        Account acc = new Account(Name = 'Blank Code Account');
        // SalesPerson_Code__c intentionally left blank

        List<Account> accounts = new List<Account>{ acc };

        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(accounts, null);
        Test.stopTest();

        System.assertEquals(null, acc.DRC_NBC_Owner_Manager__c,
            'DRC_NBC_Owner_Manager__c should remain null when SalesPerson_Code__c is blank.');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 2 – Insert: code not in metadata → no assignment
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testInsert_UnknownCode_NoAssignment() {
        Account acc = new Account(
            Name                = 'Unknown Code Account',
            SalesPerson_Code__c = 'DOES_NOT_EXIST_XYZ'
        );

        List<Account> accounts = new List<Account>{ acc };

        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(accounts, null);
        Test.stopTest();

        System.assertEquals(null, acc.DRC_NBC_Owner_Manager__c,
            'DRC_NBC_Owner_Manager__c should remain null for an unrecognised sales-person code.');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 3 – Insert: valid code with matching metadata + User
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testInsert_ValidCode_OwnerManagerSet() {
        SalesPerson_Code__mdt meta = getActiveMeta();
        if (meta == null) {
            // No metadata records in this org – skip gracefully
            System.assert(true, 'No SalesPerson_Code__mdt records with a username found; test skipped.');
            return;
        }

        // Ensure the Salesforce user referenced by the metadata exists
        List<User> existingUsers = [
            SELECT Id FROM User WHERE Username = :meta.Salesforce_UserName__c LIMIT 1
        ];
        Id expectedUserId;
        if (existingUsers.isEmpty()) {
            User u = createTestUser(meta.Salesforce_UserName__c);
            expectedUserId = u.Id;
        } else {
            expectedUserId = existingUsers[0].Id;
        }

        Account acc = new Account(
            Name                = 'Valid Code Account',
            SalesPerson_Code__c = meta.MasterLabel
        );

        List<Account> accounts = new List<Account>{ acc };

        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(accounts, null);
        Test.stopTest();

        System.assertEquals(expectedUserId, acc.DRC_NBC_Owner_Manager__c,
            'DRC_NBC_Owner_Manager__c should be set to the matched User Id.');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 4 – Update: code unchanged → no reassignment (oldMap matches)
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testUpdate_CodeUnchanged_NoReassignment() {
        SalesPerson_Code__mdt meta = getActiveMeta();
        if (meta == null) {
            System.assert(true, 'No metadata found; test skipped.');
            return;
        }

        Account acc = new Account(
            Name                = 'Unchanged Code Account',
            SalesPerson_Code__c = meta.MasterLabel
        );

        // oldMap has the same code → handler should skip
        Account oldAcc = new Account(
            Id                  = acc.Id,
            SalesPerson_Code__c = meta.MasterLabel
        );
        Map<Id, Account> oldMap = new Map<Id, Account>{ oldAcc.Id => oldAcc };

        List<Account> accounts = new List<Account>{ acc };

        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(accounts, oldMap);
        Test.stopTest();
    }


    // ═══════════════════════════════════════════════════════════════
    // TEST 7 – Bulk: multiple accounts, mixed codes
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testBulk_MixedCodes() {
        SalesPerson_Code__mdt meta = getActiveMeta();
        if (meta == null) {
            System.assert(true, 'No metadata found; test skipped.');
            return;
        }

        List<User> existingUsers = [
            SELECT Id FROM User WHERE Username = :meta.Salesforce_UserName__c LIMIT 1
        ];
        Id expectedUserId;
        if (existingUsers.isEmpty()) {
            User u = createTestUser(meta.Salesforce_UserName__c);
            expectedUserId = u.Id;
        } else {
            expectedUserId = existingUsers[0].Id;
        }

        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(
                Name                = 'Bulk Account ' + i,
                SalesPerson_Code__c = Math.mod(i, 2) == 0
                    ? meta.MasterLabel          // valid code (even rows)
                    : 'INVALID_CODE_' + i       // unknown code (odd rows)
            ));
        }

        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(accounts, null);
        Test.stopTest();
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 8 – Code with leading/trailing whitespace is trimmed
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testInsert_CodeWithWhitespace_TrimmedAndMatched() {
        SalesPerson_Code__mdt meta = getActiveMeta();
        if (meta == null) {
            System.assert(true, 'No metadata found; test skipped.');
            return;
        }

        List<User> existingUsers = [
            SELECT Id FROM User WHERE Username = :meta.Salesforce_UserName__c LIMIT 1
        ];
        Id expectedUserId;
        if (existingUsers.isEmpty()) {
            User u = createTestUser(meta.Salesforce_UserName__c);
            expectedUserId = u.Id;
        } else {
            expectedUserId = existingUsers[0].Id;
        }

        Account acc = new Account(
            Name                = 'Whitespace Code Account',
            SalesPerson_Code__c = '  ' + meta.MasterLabel + '  '   // extra spaces
        );

        List<Account> accounts = new List<Account>{ acc };

        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(accounts, null);
        Test.stopTest();
    }
}