@isTest
private class DRC_NBC_CustomerItems_Combined_Test {
    
    // =========================================================================
    // MOCK CALLOUT CLASSES — must be named inner classes in Apex
    // =========================================================================
    private class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body>' +
                '<ReadMultipleResult>' +
                '<CustomerItemListSF>' +
                '<Key>KEY001</Key>' +
                '<Item_No>FG-100</Item_No>' +
                '</CustomerItemListSF>' +
                '</ReadMultipleResult>' +
                '</soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }
    
    private class MockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('<Fault><faultstring>Internal Server Error</faultstring></Fault>');
            return res;
        }
    }
    
    private class MockEmptyRead implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soapenv:Body><ReadMultipleResult/></soapenv:Body>' +
                '</soapenv:Envelope>'
            );
            return res;
        }
    }
    
    // =========================================================================
    // HELPERS
    // =========================================================================
    private static void insertCustomSetting() {
        DRC_NBC_BC_Integration__c cs = new DRC_NBC_BC_Integration__c();
        cs.CustomerItemSOAPEndpoint__c = 'https://mock.endpoint.com/soap';
        cs.Customeritems_SOAP_NS__c    = 'http://schemas.xmlsoap.org/soap/envelope/';
        cs.Customer_BC_NS__c           = 'urn:microsoft-dynamics-schemas/page/customersalesforce';
        cs.DRC_NBC_Username__c         = 'testuser';
        cs.DRC_NBC_Password__c         = 'testpass';
        upsert cs;
    }
    
    private static Account insertAccount(String name, String custNo) {
        // Create Account
        Account acc = DRC_NBC_TestFactory.createAccount();
        return acc;
        
    }
    
    // ── Inserts a Restricted Product via the lookup relationship ──────────────
    // DRC_NBC_Product__c may not exist as standalone — we go through
    // DRC_NBC_Restricted_Product__c with the FG code on the product lookup
    private static void insertRestrictedProduct(Id accountId, String fgCode, String custProdCode) {
        DRC_NBC_Restricted_Product__c rp = new DRC_NBC_Restricted_Product__c();
        rp.DRC_NBC_Customer__c               = accountId;
        rp.DRC_NBC_Customer_s_Product_code__c = custProdCode;
        
        // Only set the lookup if FG code is non-blank
        // The product record must exist for the lookup — create it first
        if (String.isNotBlank(fgCode)) {
            Product2 prod = new Product2();
            prod.DRC_NBC_FG_Code__c = fgCode;
            prod.Name = 'Test 1';
            insert prod;
            rp.DRC_NBC_Product__c = prod.Id;
        }
        
        insert rp;
    }
    
    private static void insertApiLog(Id accountId, String method, String logType, Integer code) {
        DRC_NBC_API_Log__c log = new DRC_NBC_API_Log__c();
        log.DRC_NBC_Method_Name__c           = method;
        log.DRC_NBC_Log_Type__c              = logType;
        log.DRC_NBC_Timestamp__c             = DateTime.now();
        log.DRC_NBC_Created_Updated_SF_Id__c = accountId;
        log.DRC_NBC_Endpoint__c              = 'https://mock.endpoint.com/soap';
        log.DRC_NBC_Status_Code__c           = code;
        insert log;
    }
    
    private static DRC_NBC_CustomerItems_StatusCtrl buildCtrl(Id accId) {
        PageReference pg = Page.DRC_NBC_CustomerItems_Status;
        pg.getParameters().put('id', accId);
        Test.setCurrentPage(pg);
        return new DRC_NBC_CustomerItems_StatusCtrl();
    }
    
    // =========================================================================
    // CTRL TESTS
    // =========================================================================
    
    @isTest
    static void testCtrl_Constructor_ValidAccount() {
        Account acc = insertAccount('Ctrl Valid', 'CUST-C01');
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_Constructor_NoId() {
        PageReference pg = Page.DRC_NBC_CustomerItems_Status;
        Test.setCurrentPage(pg);
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = new DRC_NBC_CustomerItems_StatusCtrl();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_OnLoad_EnqueuesJob() {
        insertCustomSetting();
        Account acc = insertAccount('OnLoad Account', 'CUST-C02');
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        ctrl.onLoad();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_OnLoad_NoAccountId() {
        PageReference pg = Page.DRC_NBC_CustomerItems_Status;
        Test.setCurrentPage(pg);
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = new DRC_NBC_CustomerItems_StatusCtrl();
        ctrl.onLoad();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_CheckResults_AllSuccess() {
        Account acc = insertAccount('All Success', 'CUST-C03');
        insertApiLog(acc.Id, 'ReadMultiple',   'Success', 200);
        insertApiLog(acc.Id, 'CreateMultiple', 'Success', 200);
        insertApiLog(acc.Id, 'UpdateMultiple', 'Success', 200);
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        ctrl.checkResults();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_CheckResults_AllFailed() {
        Account acc = insertAccount('All Failed', 'CUST-C04');
        insertApiLog(acc.Id, 'ReadMultiple',   'Error', 500);
        insertApiLog(acc.Id, 'CreateMultiple', 'Error', 500);
        insertApiLog(acc.Id, 'UpdateMultiple', 'Error', 500);
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        ctrl.checkResults();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_CheckResults_OnlyRead() {
        Account acc = insertAccount('Only Read', 'CUST-C05');
        insertApiLog(acc.Id, 'ReadMultiple', 'Success', 200);
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        ctrl.checkResults();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_CheckResults_OnlyCreate() {
        Account acc = insertAccount('Only Create', 'CUST-C06');
        insertApiLog(acc.Id, 'CreateMultiple', 'Success', 200);
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        ctrl.checkResults();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_CheckResults_OnlyUpdateFailed() {
        Account acc = insertAccount('Only Update Failed', 'CUST-C07');
        insertApiLog(acc.Id, 'UpdateMultiple', 'Error', 500);
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        ctrl.checkResults();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_CheckResults_NoLogs() {
        Account acc = insertAccount('No Logs', 'CUST-C08');
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        ctrl.checkResults();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_CheckResults_StaleLogs() {
        Account acc = insertAccount('Stale Logs', 'CUST-C09');
        DRC_NBC_API_Log__c stale = new DRC_NBC_API_Log__c();
        stale.DRC_NBC_Method_Name__c           = 'ReadMultiple';
        stale.DRC_NBC_Log_Type__c              = 'Success';
        stale.DRC_NBC_Timestamp__c             = DateTime.now().addMinutes(-10);
        stale.DRC_NBC_Created_Updated_SF_Id__c = acc.Id;
        stale.DRC_NBC_Endpoint__c              = 'https://mock.endpoint.com';
        stale.DRC_NBC_Status_Code__c           = 200;
        insert stale;
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        ctrl.checkResults();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_GoBack() {
        Account acc = insertAccount('GoBack', 'CUST-C10');
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        ctrl.goBack();
        Test.stopTest();
    }
    
    @isTest
    static void testCtrl_FullFlow() {
        insertCustomSetting();
        Account acc = insertAccount('Full Flow', 'CUST-C11');
        insertApiLog(acc.Id, 'ReadMultiple',   'Success', 200);
        insertApiLog(acc.Id, 'CreateMultiple', 'Success', 200);
        insertApiLog(acc.Id, 'UpdateMultiple', 'Error',   500);
        Test.startTest();
        DRC_NBC_CustomerItems_StatusCtrl ctrl = buildCtrl(acc.Id);
        ctrl.onLoad();
        ctrl.checkResults();
        ctrl.goBack();
        Test.stopTest();
    }
    
    // =========================================================================
    // QUEUEABLE TESTS
    // =========================================================================
    
    @isTest
    static void testQueueable_CreateAndUpdate() {
        insertCustomSetting();
        Account acc = insertAccount('Q Create Update', 'CUST-Q01');
        insertRestrictedProduct(acc.Id, 'FG-100', 'CP-001'); // FG-100 exists in BC → Update
        insertRestrictedProduct(acc.Id, 'FG-200', 'CP-002'); // FG-200 new → Create
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_CustomerItems_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    @isTest
    static void testQueueable_ErrorCallout() {
        insertCustomSetting();
        Account acc = insertAccount('Q Error', 'CUST-Q02');
        insertRestrictedProduct(acc.Id, 'FG-300', 'CP-003');
        Test.setMock(HttpCalloutMock.class, new MockError());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_CustomerItems_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    @isTest
    static void testQueueable_NoProducts() {
        insertCustomSetting();
        Account acc = insertAccount('Q No Products', 'CUST-Q03');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_CustomerItems_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    @isTest
    static void testQueueable_EmptyReadMultiple_AllCreate() {
        insertCustomSetting();
        Account acc = insertAccount('Q All Create', 'CUST-Q04');
        insertRestrictedProduct(acc.Id, 'FG-401', 'CP-401');
        insertRestrictedProduct(acc.Id, 'FG-402', 'CP-402');
        Test.setMock(HttpCalloutMock.class, new MockEmptyRead());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_CustomerItems_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    @isTest
    static void testQueueable_ErrorCallout_LogsError() {
        insertCustomSetting();
        Account acc = insertAccount('Q Logs Error', 'CUST-Q05');
        insertRestrictedProduct(acc.Id, 'FG-500', 'CP-500');
        Test.setMock(HttpCalloutMock.class, new MockError());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_CustomerItems_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
    
    @isTest
    static void testQueueable_MultipleProducts_AllUpdate() {
        insertCustomSetting();
        Account acc = insertAccount('Q All Update', 'CUST-Q06');
        // All 3 FG codes exist in MockSuccess response via FG-100
        // Others go to Create since mock only returns FG-100
        insertRestrictedProduct(acc.Id, 'FG-100', 'CP-601');
        insertRestrictedProduct(acc.Id, 'FG-601', 'CP-602');
        insertRestrictedProduct(acc.Id, 'FG-602', 'CP-603');
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        System.enqueueJob(new DRC_NBC_CustomerItems_SOAP_Queueable(acc.Id));
        Test.stopTest();
    }
}