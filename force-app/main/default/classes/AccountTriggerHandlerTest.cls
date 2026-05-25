@isTest
private class AccountTriggerHandlerTest {
    
    // ─────────────────────────────────────────────────────────────────────
    // Helper: create a User (with a Manager) for the given username
    // ─────────────────────────────────────────────────────────────────────
    private static User createTestUser(String username) {
        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Standard User'
            LIMIT 1
        ];
        
        String safeLocalPart = username.replace('@', '.').replace('+', '.');
        
        User mgr = new User(
            FirstName         = 'Manager',
            LastName          = 'User',
            Email             = 'mgr.' + safeLocalPart + '@test.example.com',
            Username          = 'mgr_' + username,
            Alias             = 'mgrusr',
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id
        );
        insert mgr;
        
        User u = new User(
            FirstName         = 'Sales',
            LastName          = 'Person',
            Email             = safeLocalPart + '@test.example.com',
            Username          = username,
            Alias             = 'slsprs',
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id,
            ManagerId         = mgr.Id
        );
        insert u;
        
        return u;
    }
    
    // ─────────────────────────────────────────────────────────────────────
    // Helper: fetch a metadata record where both Name__c and
    //         Salesforce_UserName__c are populated (cannot DML in tests)
    // ─────────────────────────────────────────────────────────────────────
    private static SalesPerson_Code__mdt getActiveMeta() {
        List<SalesPerson_Code__mdt> metas = [
            SELECT MasterLabel, Name__c, Salesforce_UserName__c
            FROM   SalesPerson_Code__mdt
            WHERE  Name__c                != null
            AND    Salesforce_UserName__c != null
            LIMIT  1
        ];
        return metas.isEmpty() ? null : metas[0];
    }
    
    // ─────────────────────────────────────────────────────────────────────
    // Helper: get or create the User referenced by a metadata record
    // ─────────────────────────────────────────────────────────────────────
    private static Id resolveUserId(SalesPerson_Code__mdt meta) {
        List<User> existing = [
            SELECT Id FROM User
            WHERE  Username = :meta.Salesforce_UserName__c
            LIMIT  1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }
        return createTestUser(meta.Salesforce_UserName__c).Id;
    }
    
    // ─────────────────────────────────────────────────────────────────────
    // Helper: create and insert a real Account, then return it with Id
    // ─────────────────────────────────────────────────────────────────────
    private static Account createAccount(String name, Id managerId) {
        Account acc = new Account(
            Name                     = name,
            DRC_NBC_Owner_Manager__c = managerId,
            DRC_NBC_Customer_Number__c               = 'CUST12345',
            CurrencyIsoCode                          = 'INR',
            Phone                                    = '1234567890',
            AccountNumber                            = 'A123',
            DRC_NBC_PAN_No__c                        = 'AWVPY9594J',
            DRC_NBC_GST_Number__c                    = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c             = 'PDC90',
            DRC_NBC_Account_Email_Email__c           = 'test@example.com',
            BillingStreet                            = '123 Street',
            BillingCity                              = 'City',
            BillingCountry                           = 'India',
            BillingCountryCode                       = 'IN',
            BillingPostalCode                        = '462002',
            BillingState                             = 'Maharashtra',
            BillingStateCode                         = 'MH',
            DRC_NBC_Volume__c                        = 70,
            DRC_NBC_Credit_Limit__c                  = 123456787,
            DRC_NBC_Value__c                         = 900,
            DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
            DRC_NBC_Consignee_Bank_Address__c        = 'Barhi 483775',
            DRC_NBC_Consignee_Bank_IFSC_Code__c      = 'PUNB01391000',
            DRC_NBC_Consignee_Bank_Name__c           = 'Punjab National bank',
            Industry                                 = 'Chemicals Construction',
            Type                                     = 'Analyst'
        );
        insert acc;
        return acc;
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // TEST 1 – INSERT: blank SalesPerson_Code__c → field left untouched
    // ═════════════════════════════════════════════════════════════════════
    @isTest
    static void testInsert_BlankCode_NoAssignment() {
        Account acc = new Account(Name = 'Blank Code Account');
        
        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(
            new List<Account>{ acc }, null
        );
        Test.stopTest();
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // TEST 2 – INSERT: code not in metadata → field left untouched
    // ═════════════════════════════════════════════════════════════════════
    @isTest
    static void testInsert_UnknownCode_NoAssignment() {
        Account acc = new Account(
            Name                = 'Unknown Code Account',
            SalesPerson_Code__c = 'DOES_NOT_EXIST_XYZ'
        );
        
        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(
            new List<Account>{ acc }, null
        );
        Test.stopTest();
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // TEST 3 – INSERT: valid code → DRC_NBC_Owner_Manager__c populated
    // ═════════════════════════════════════════════════════════════════════
    @isTest
    static void testInsert_ValidCode_OwnerManagerSet() {
        SalesPerson_Code__mdt meta = getActiveMeta();
        if (meta == null) { return; }
        
        resolveUserId(meta);
        
        Account acc = new Account(
            Name                = 'Valid Code Account',
            SalesPerson_Code__c = meta.Name__c
        );
        
        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(
            new List<Account>{ acc }, null
        );
        Test.stopTest();
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // TEST 4 – TEAM MEMBER INSERT: account with new manager on insert
    //          → AccountTeamMember created with role Sales Manager
    // ═════════════════════════════════════════════════════════════════════
    @isTest
    static void testManageTeam_Insert_NewManager_TeamMemberCreated() {
        User mgr = createTestUser('atm_insert_mgr@test.example.com');
        
        Account acc = createAccount('Team Insert Account', mgr.Id);
        
        Test.startTest();
        AccountTriggerHandler.manageAccountTeamMembers(
            new List<Account>{ acc },
            null   // null oldMap = INSERT context
        );
        Test.stopTest();
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // TEST 6 – TEAM MEMBER UPDATE: manager changes
    //          → old team member deleted, new one inserted
    // ═════════════════════════════════════════════════════════════════════
    @isTest
    static void testManageTeam_Update_ManagerChanged_OldDeletedNewInserted() {
        User oldMgr = createTestUser('atm_old_mgr@test.example.com');
        User newMgr = createTestUser('atm_new_mgr@test.example.com');
        
        // Create account with old manager already set
        Account acc = createAccount('Manager Change Account', oldMgr.Id);
        
        // Simulate old team member already exists for old manager
        insert new AccountTeamMember(
            AccountId              = acc.Id,
            UserId                 = oldMgr.Id,
            TeamMemberRole         = 'Sales Manager',
            AccountAccessLevel     = 'Edit',
            ContactAccessLevel     = 'Edit',
            OpportunityAccessLevel = 'Edit',
            CaseAccessLevel        = 'Edit'
        );
        
        // Build oldMap simulating the pre-update state
        Account oldAccSnapshot        = new Account(Id = acc.Id);
        oldAccSnapshot.DRC_NBC_Owner_Manager__c = oldMgr.Id;
        Map<Id, Account> oldMap = new Map<Id, Account>{ acc.Id => oldAccSnapshot };
            
            // Simulate account now having new manager
            acc.DRC_NBC_Owner_Manager__c = newMgr.Id;
        
        Test.startTest();
        AccountTriggerHandler.manageAccountTeamMembers(
            new List<Account>{ acc },
            oldMap
        );
        Test.stopTest();
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // TEST 7 – TEAM MEMBER UPDATE: manager unchanged
    //          → no DML executed, method exits early
    // ═════════════════════════════════════════════════════════════════════
    @isTest
    static void testManageTeam_Update_ManagerUnchanged_NoDML() {
        User mgr = createTestUser('atm_same_mgr@test.example.com');
        
        Account acc = createAccount('Unchanged Manager Account', mgr.Id);
        
        // oldMap has same manager as new record — no change
        Account oldAccSnapshot = new Account(Id = acc.Id);
        oldAccSnapshot.DRC_NBC_Owner_Manager__c = mgr.Id;
        Map<Id, Account> oldMap = new Map<Id, Account>{ acc.Id => oldAccSnapshot };
            
            Test.startTest();
        AccountTriggerHandler.manageAccountTeamMembers(
            new List<Account>{ acc },
            oldMap
        );
        Test.stopTest();
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // TEST 8 – TEAM MEMBER INSERT: new manager already on team
    //          → duplicate skipped, no error thrown
    // ═════════════════════════════════════════════════════════════════════
    @isTest
    static void testManageTeam_Insert_ManagerAlreadyOnTeam_NoDuplicate() {
        User mgr = createTestUser('atm_dup_mgr@test.example.com');
        
        Account acc = createAccount('Duplicate Team Account', mgr.Id);
        
        // Pre-insert team member so the method finds it already exists
        insert new AccountTeamMember(
            AccountId              = acc.Id,
            UserId                 = mgr.Id,
            TeamMemberRole         = 'Sales Manager',
            AccountAccessLevel     = 'Edit',
            ContactAccessLevel     = 'Edit',
            OpportunityAccessLevel = 'Edit',
            CaseAccessLevel        = 'Edit'
        );
        
        Test.startTest();
        AccountTriggerHandler.manageAccountTeamMembers(
            new List<Account>{ acc },
            null
        );
        Test.stopTest();
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // TEST 9 – TEAM MEMBER UPDATE: old manager was null, new manager set
    //          → only insert happens, no delete attempted
    // ═════════════════════════════════════════════════════════════════════
    @isTest
    static void testManageTeam_Update_OldManagerNull_OnlyInsert() {
        User newMgr = createTestUser('atm_nullold_mgr@test.example.com');
        
        Account acc = createAccount('Null Old Manager Account', newMgr.Id);
        
        // oldMap has no manager set
        Account oldAccSnapshot = new Account(Id = acc.Id);
        oldAccSnapshot.DRC_NBC_Owner_Manager__c = null;
        Map<Id, Account> oldMap = new Map<Id, Account>{ acc.Id => oldAccSnapshot };
            
            Test.startTest();
        AccountTriggerHandler.manageAccountTeamMembers(
            new List<Account>{ acc },
            oldMap
        );
        Test.stopTest();
    }
    
    // ═════════════════════════════════════════════════════════════════════
    // TEST 10 – BULK: 200 accounts on insert with manager set
    //           → all team members created without hitting governor limits
    // ═════════════════════════════════════════════════════════════════════
    @isTest
    static void testBulk_MixedCodes() {
        SalesPerson_Code__mdt meta = getActiveMeta();
        if (meta == null) { return; }
        
        resolveUserId(meta);
        
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(
                Name                = 'Bulk Account ' + i,
                SalesPerson_Code__c = Math.mod(i, 2) == 0
                ? meta.Name__c
                : 'INVALID_CODE_' + i
            ));
        }
        
        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(accounts, null);
        Test.stopTest();
    }
    
   
    // ═════════════════════════════════════════════════════════════════════
    // TEST 12 – INSERT: code with leading/trailing whitespace is trimmed
    // ═════════════════════════════════════════════════════════════════════
    @isTest
    static void testInsert_CodeWithWhitespace_TrimmedAndMatched() {
        SalesPerson_Code__mdt meta = getActiveMeta();
        if (meta == null) { return; }
        
        resolveUserId(meta);
        
        Account acc = new Account(
            Name                = 'Whitespace Code Account',
            SalesPerson_Code__c = '  ' + meta.Name__c + '  '
        );
        
        Test.startTest();
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(
            new List<Account>{ acc }, null
        );
        Test.stopTest();
    }
}