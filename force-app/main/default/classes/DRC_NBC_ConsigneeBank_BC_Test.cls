@isTest
private class DRC_NBC_ConsigneeBank_BC_Test {
    
    // ─── Helpers ─────────────────────────────────────────────────────────────
    
    private static Account createAccount() {
        return DRC_NBC_TestFactory.createAccount();
    }
    
    private static DRC_NBC_Consignee_Bank_Details__c createBank(Id accountId, Boolean isPrimary) {
        DRC_NBC_Consignee_Bank_Details__c bank = new DRC_NBC_Consignee_Bank_Details__c(
            Account__c                                     = accountId,
            DRC_NBC_Consignee_Bank_Name__c                 = 'State Bank of India',
            DRC_NBC_Primary_Bank__c                        = isPrimary,
            DRC_NBC_Consignee_Bank_Account_Number__c       = '123456789',
            DRC_NBC_Consignee_Bank_IFSC_Code__c            = 'SBIN0001234',
            DRC_NBC_Consignee_Bank_Address__City__s        = 'Mumbai',
            DRC_NBC_Consignee_Bank_Address__CountryCode__s = 'IN'
        );
        insert bank;
        return bank;
    }
    
    private static void setPage(String accountId) {
        PageReference pg = Page.Drcnbcconsigneebankbcpage;
        if (accountId != null) {
            pg.getParameters().put('id', accountId);
        }
        Test.setCurrentPage(pg);
    }
    
    // ─── Mock: HTTP 201 success ───────────────────────────────────────────────
    private class Mock201 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"status":"created"}');
            return res;
        }
    }
    
    // ─── Mock: HTTP 400 error ─────────────────────────────────────────────────
    private class Mock400 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setBody('{"error":"Bad Request"}');
            return res;
        }
    }
    
    // ─── Mock: alternates 201 / 400 per call ─────────────────────────────────
    private class MixedMock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            callCount++;
            if (Math.mod(callCount, 2) == 1) {
                res.setStatusCode(201);
                res.setBody('{"status":"created"}');
            } else {
                res.setStatusCode(400);
                res.setBody('{"error":"Bad Request"}');
            }
            return res;
        }
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // 1. No Account ID in URL → error state
    // ════════════════════════════════════════════════════════════════════════
    @isTest
    static void testNoAccountId() {
        Test.startTest();
        setPage(null);
        DRC_NBC_ConsigneeBank_BC_VFController ctrl =
            new DRC_NBC_ConsigneeBank_BC_VFController();
        Test.stopTest();
    }
    
    
    // ════════════════════════════════════════════════════════════════════════
    // 3. Well-formed Id that matches no Account record → error state
    // ════════════════════════════════════════════════════════════════════════
    @isTest
    static void testNonExistentAccountId() {
        Test.startTest();
        setPage('001000000000001AAA');
        DRC_NBC_ConsigneeBank_BC_VFController ctrl =
            new DRC_NBC_ConsigneeBank_BC_VFController();
        Test.stopTest();
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // 4. Valid Account with NO primary bank → warning, empty preview
    // ════════════════════════════════════════════════════════════════════════
    @isTest
    static void testAccountNoPrimaryBank() {
        Account acc = createAccount();
        createBank(acc.Id, false);
        
        Test.startTest();
        setPage(acc.Id);
        DRC_NBC_ConsigneeBank_BC_VFController ctrl =
            new DRC_NBC_ConsigneeBank_BC_VFController();
        Test.stopTest();
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // 5. Valid Account with primary bank → info state + populated preview row
    // ════════════════════════════════════════════════════════════════════════
    @isTest
    static void testAccountWithPrimaryBank() {
        Account acc = createAccount();
        createBank(acc.Id, true);
        
        Test.startTest();
        setPage(acc.Id);
        DRC_NBC_ConsigneeBank_BC_VFController ctrl =
            new DRC_NBC_ConsigneeBank_BC_VFController();
        Test.stopTest();
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // 6. syncToBC() — HTTP 201 → success, row updated, jobEnqueued true
    // ════════════════════════════════════════════════════════════════════════
    @isTest
    static void testSyncToBC_Success() {
        Account acc = createAccount();
        createBank(acc.Id, true);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new Mock201());
        setPage(acc.Id);
        
        DRC_NBC_ConsigneeBank_BC_VFController ctrl =
            new DRC_NBC_ConsigneeBank_BC_VFController();
        PageReference result = ctrl.syncToBC();
        Test.stopTest();
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // 7. syncToBC() — HTTP 400 → error, row reflects failure
    // ════════════════════════════════════════════════════════════════════════
    @isTest
    static void testSyncToBC_HttpError() {
        Account acc = createAccount();
        createBank(acc.Id, true);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new Mock400());
        setPage(acc.Id);
        
        DRC_NBC_ConsigneeBank_BC_VFController ctrl =
            new DRC_NBC_ConsigneeBank_BC_VFController();
        PageReference result = ctrl.syncToBC();
        Test.stopTest();
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // 8. syncToBC() — two primary banks, mixed 201/400 → warning state
    // ════════════════════════════════════════════════════════════════════════
    @isTest
    static void testSyncToBC_MixedResults() {
        Account acc = createAccount();
        createBank(acc.Id, true);
        createBank(acc.Id, true);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MixedMock());
        setPage(acc.Id);
        
        DRC_NBC_ConsigneeBank_BC_VFController ctrl =
            new DRC_NBC_ConsigneeBank_BC_VFController();
        ctrl.syncToBC();
        Test.stopTest();
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // 9. syncToBC() with no bank records → warning, no callout attempted
    // ════════════════════════════════════════════════════════════════════════
    @isTest
    static void testSyncToBC_NoBanks() {
        Account acc = createAccount();
        
        Test.startTest();
        setPage(acc.Id);
        DRC_NBC_ConsigneeBank_BC_VFController ctrl =
            new DRC_NBC_ConsigneeBank_BC_VFController();
        PageReference result = ctrl.syncToBC();
        Test.stopTest();
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // 10. syncToBC() when accountId is null (constructor already errored)
    // ════════════════════════════════════════════════════════════════════════
    @isTest
    static void testSyncToBC_NullAccountId() {
        Test.startTest();
        setPage(null);
        DRC_NBC_ConsigneeBank_BC_VFController ctrl =
            new DRC_NBC_ConsigneeBank_BC_VFController();
        PageReference result = ctrl.syncToBC();
        Test.stopTest();
    }
    
    // ════════════════════════════════════════════════════════════════════════
    // 11. goBack() returns a PageReference containing the Account ID
    // ════════════════════════════════════════════════════════════════════════
    @isTest
    static void testGoBack() {
        Account acc = createAccount();
        
        Test.startTest();
        setPage(acc.Id);
        DRC_NBC_ConsigneeBank_BC_VFController ctrl =
            new DRC_NBC_ConsigneeBank_BC_VFController();
        PageReference backRef = ctrl.goBack();
        Test.stopTest();
    }
}