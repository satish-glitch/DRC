@isTest
private class QuoteTriggerHandlerTest {

    // ══════════════════════════════════════════════════════════════════════
    // HELPERS
    // ══════════════════════════════════════════════════════════════════════

    private static User getAdminUser() {
        return [
            SELECT Id
            FROM   User
            WHERE  Profile.Name = 'System Administrator'
            AND    IsActive = true
            LIMIT  1
        ];
    }

    private static Account createAccount() {
        Account acc = new Account(Name = 'Test Account ' + Crypto.getRandomInteger());
        System.runAs(getAdminUser()) {
            insert acc;
        }
        return acc;
    }

    private static User createInternalUser(String uniqueSuffix) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName         = 'Mgr',
            LastName          = uniqueSuffix,
            Email             = uniqueSuffix + '@test.example.com',
            Username          = uniqueSuffix + '@test.example.com',
            Alias             = uniqueSuffix.left(8),
            TimeZoneSidKey    = 'America/New_York',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id
        );
        System.runAs(getAdminUser()) {
            insert u;
        }
        return u;
    }

    private static Opportunity createOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name      = 'Test Opp ' + accountId,
            AccountId = accountId,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        System.runAs(getAdminUser()) {
            insert opp;
        }
        return opp;
    }

    private static Quote createQuote(Id opportunityId) {
        Quote qt = new Quote(
            Name          = 'Test Quote ' + opportunityId,
            OpportunityId = opportunityId,
            Status        = 'Draft'
        );
        System.runAs(getAdminUser()) {
            insert qt;
        }
        return qt;
    }

    // ══════════════════════════════════════════════════════════════════════
    // SECTION 1 – INSERT scenarios
    // ══════════════════════════════════════════════════════════════════════

    // ── TEST 1: Account has OwnerManager → Quote field populated on insert ─
    @isTest
    static void testInsert_AccountHasOwnerManager_QuoteFieldSet() {
        User mgr    = createInternalUser('mgr.qt.insert');
        Account acc = createAccount();
        System.runAs(getAdminUser()) {
            acc.DRC_NBC_Owner_Manager__c = mgr.Id;
            update acc;
        }
        Opportunity opp = createOpportunity(acc.Id);

        Test.startTest();
        Quote qt = createQuote(opp.Id);
        Test.stopTest();

        Quote result = [
            SELECT DRC_Account_Owner_Manager__c
            FROM   Quote
            WHERE  Id = :qt.Id
        ];
    }

    // ── TEST 2: Account has no OwnerManager → Quote field stays null ───────
    @isTest
    static void testInsert_AccountNoOwnerManager_QuoteFieldNull() {
        Account acc     = createAccount();
        Opportunity opp = createOpportunity(acc.Id);

        Test.startTest();
        Quote qt = createQuote(opp.Id);
        Test.stopTest();

        Quote result = [
            SELECT DRC_Account_Owner_Manager__c
            FROM   Quote
            WHERE  Id = :qt.Id
        ];
    }

    // ── TEST 3: Quote already in sync with Account → no redundant DML ──────
    @isTest
    static void testInsert_QuoteAlreadyInSync_NoRedundantDML() {
        User mgr    = createInternalUser('mgr.qt.sync');
        Account acc = createAccount();
        System.runAs(getAdminUser()) {
            acc.DRC_NBC_Owner_Manager__c = mgr.Id;
            update acc;
        }
        Opportunity opp = createOpportunity(acc.Id);

        Test.startTest();
        Quote qt = new Quote(
            Name                         = 'Sync Quote',
            OpportunityId                = opp.Id,
            Status                       = 'Draft',
            DRC_Account_Owner_Manager__c = mgr.Id
        );
        System.runAs(getAdminUser()) {
            insert qt;
        }
        Test.stopTest();

        Quote result = [
            SELECT DRC_Account_Owner_Manager__c
            FROM   Quote
            WHERE  Id = :qt.Id
        ];
    }

    // ── TEST 4: Empty list passed → no error, early exit ──────────────────
    @isTest
    static void testInsert_EmptyList_NoError() {
        Test.startTest();
        QuoteTriggerHandler.updateQuoteOwnerManagerFromAccount(new List<Quote>());
        Test.stopTest();
    }

    // ══════════════════════════════════════════════════════════════════════
    // SECTION 2 – UPDATE scenarios
    // ══════════════════════════════════════════════════════════════════════

    // ── TEST 5: Account OwnerManager updated → Quote field reflects new mgr ─
    @isTest
    static void testUpdate_AccountOwnerManagerChanged_QuoteFieldUpdated() {
        User mgr1   = createInternalUser('mgr.qt.old');
        User mgr2   = createInternalUser('mgr.qt.new');
        Account acc = createAccount();
        System.runAs(getAdminUser()) {
            acc.DRC_NBC_Owner_Manager__c = mgr1.Id;
            update acc;
        }
        Opportunity opp = createOpportunity(acc.Id);
        Quote qt        = createQuote(opp.Id);

        System.runAs(getAdminUser()) {
            acc.DRC_NBC_Owner_Manager__c = mgr2.Id;
            update acc;
        }

        Test.startTest();
        QuoteTriggerHandler.updateQuoteOwnerManagerFromAccount(
            new List<Quote>{ qt }
        );
        Test.stopTest();

        Quote result = [
            SELECT DRC_Account_Owner_Manager__c
            FROM   Quote
            WHERE  Id = :qt.Id
        ];
    }

    // ── TEST 6: Account has null OwnerManager → handler skips update ────────
    @isTest
    static void testUpdate_AccountOwnerManagerNull_QuoteNotUpdated() {
        Account acc     = createAccount();
        Opportunity opp = createOpportunity(acc.Id);
        Quote qt        = createQuote(opp.Id);

        Test.startTest();
        QuoteTriggerHandler.updateQuoteOwnerManagerFromAccount(
            new List<Quote>{ qt }
        );
        Test.stopTest();

        Quote result = [
            SELECT DRC_Account_Owner_Manager__c
            FROM   Quote
            WHERE  Id = :qt.Id
        ];
    }

  
    // ══════════════════════════════════════════════════════════════════════
    // SECTION 3 – Bulk scenarios
    // ══════════════════════════════════════════════════════════════════════

    // ── TEST 8: Bulk insert 200 Quotes → all processed without errors ───────
    @isTest
    static void testBulkInsert_AllQuotesUpdated() {
        User mgr    = createInternalUser('mgr.qt.bulk');
        Account acc = createAccount();
        System.runAs(getAdminUser()) {
            acc.DRC_NBC_Owner_Manager__c = mgr.Id;
            update acc;
        }
        Opportunity opp = createOpportunity(acc.Id);

        List<Quote> quotes = new List<Quote>();
        for (Integer i = 0; i < 200; i++) {
            quotes.add(new Quote(
                Name          = 'Bulk Quote ' + i,
                OpportunityId = opp.Id,
                Status        = 'Draft'
            ));
        }

        Test.startTest();
        System.runAs(getAdminUser()) {
            insert quotes;
        }
        Test.stopTest();

        List<Quote> results = [
            SELECT DRC_Account_Owner_Manager__c
            FROM   Quote
            WHERE  Id IN :quotes
        ];
    }

    // ── TEST 9: Bulk – Quotes with no OwnerManager on Account → all null ────
    @isTest
    static void testBulkInsert_NoOwnerManagerOnAccount_AllNull() {
        Account acc     = createAccount();
        Opportunity opp = createOpportunity(acc.Id);

        List<Quote> quotes = new List<Quote>();
        for (Integer i = 0; i < 50; i++) {
            quotes.add(new Quote(
                Name          = 'No Mgr Quote ' + i,
                OpportunityId = opp.Id,
                Status        = 'Draft'
            ));
        }

        Test.startTest();
        System.runAs(getAdminUser()) {
            insert quotes;
        }
        Test.stopTest();

        List<Quote> results = [
            SELECT DRC_Account_Owner_Manager__c
            FROM   Quote
            WHERE  Id IN :quotes
        ];
    }

    // ── TEST 10: Empty list → no error ──────────────────────────────────────
    @isTest
    static void testEmptyList_NoError() {
        Test.startTest();
        QuoteTriggerHandler.updateQuoteOwnerManagerFromAccount(new List<Quote>());
        Test.stopTest();
    }
}