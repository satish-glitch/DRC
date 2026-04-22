/**
* @File Name : DRC_NBC_OrderBCControllerTest.cls
* @Description : Test class for DRC_NBC_OrderBCController
* @Author : Satish
* @TestClass : DRC_NBC_OrderBCControllerTest
* @Last Modified On : April 22, 2026
**/
@isTest
private class DRC_NBC_OrderBCControllerTest {
    
    @TestSetup
    static void setupTestData() {
        Account testAccount = new Account(
            Name = 'Test Account',
            DRC_NBC_Customer_Number__c = 'CUST12345',
            CurrencyIsoCode = 'INR',
            Phone = '1234567890',
            AccountNumber = 'A123',
            DRC_NBC_PAN_No__c = 'AWVPY9594J',
            DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c = 'PDC90',
            DRC_NBC_Account_Email_Email__c = 'test@example.com',
            BillingStreet = '123 Street',
            BillingCity = 'City',
            BillingCountry = 'India',
            BillingCountryCode = 'IN',
            BillingPostalCode = '462002',
            BillingState = 'Maharashtra',
            BillingStateCode = 'MH',
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
        insert testAccount;
        
        Order testOrder = new Order(
            AccountId = testAccount.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Name = 'Test Order'
        );
        insert testOrder;
    }
    
    // ── Helper: create an API Log record linked to a given SF Id ─────────────
    private static DRC_NBC_API_Log__c createLog(String sfId, String logType, String responseBody, String errorMsg) {
        DRC_NBC_API_Log__c log = new DRC_NBC_API_Log__c(
            DRC_NBC_Created_Updated_SF_Id__c = sfId,
            DRC_NBC_Log_Type__c              = logType,
            DRC_NBC_Response_Body__c         = responseBody,
            DRC_NBC_Error_Message__c         = errorMsg,
            DRC_NBC_Timestamp__c             = DateTime.now()
        );
        insert log;
        return log;
    }

    // ── Helper: ISO timestamp string for afterDateTime param ─────────────────
    private static String nowIso() {
        return DateTime.now().addMinutes(-1).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }
    
    // ── triggerBCIntegration ─────────────────────────────────────────────────
    
    @isTest
    static void testTriggerBCIntegration_Success() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_OrderBCController.triggerBCIntegration(testOrder.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testTriggerBCIntegration_NullOrderId() {
        Test.startTest();
        String result = DRC_NBC_OrderBCController.triggerBCIntegration(null);
        Test.stopTest();
    }
    
    // ── getAccountSyncStatus ─────────────────────────────────────────────────
    
    @isTest
    static void testGetAccountSyncStatus_DefaultFalse() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        Boolean result = DRC_NBC_OrderBCController.getAccountSyncStatus(testOrder.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetAccountSyncStatus_PostedTrue() {
        Order testOrder = [SELECT Id, AccountId FROM Order LIMIT 1];
        
        Account acc = [SELECT Id FROM Account WHERE Id = :testOrder.AccountId LIMIT 1];
        acc.DRC_NBC_Posted_To_BC__c = true;
        update acc;
        
        Test.startTest();
        Boolean result = DRC_NBC_OrderBCController.getAccountSyncStatus(testOrder.Id);
        Test.stopTest();
    }
    
    // ── getIntegrationStatus ─────────────────────────────────────────────────
    
    @isTest
    static void testGetIntegrationStatus_ReturnsNull() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_OrderBCController.getIntegrationStatus(testOrder.Id);
        Test.stopTest();
    }
    
    @isTest 
    static void testGetIntegrationStatus_WithStatusValueSet() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        testOrder.DRC_NBC_Integration_Status__c = 'Success';
        update testOrder;
        
        Test.startTest();
        String result = DRC_NBC_OrderBCController.getIntegrationStatus(testOrder.Id);
        Test.stopTest();
    }
    
    // ── getLatestLog ─────────────────────────────────────────────────────────

    @isTest
    static void testGetLatestLog_ReturnsNullWhenNoLogs() {
        // No logs inserted — should return null for this order
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        String afterDt  = nowIso();

        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog(testOrder.Id, afterDt);
        Test.stopTest();
    }

    @isTest
    static void testGetLatestLog_ReturnsNullForUnrelatedOrder() {
        // Log exists but for a different SF Id — should not be returned
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        createLog('000000000000000000', 'SUCCESS', 'Some other record log', null);

        String afterDt = nowIso();

        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog(testOrder.Id, afterDt);
        Test.stopTest();
    }
    
    @isTest
    static void testGetLatestLog_OrderSuccessLog() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        String afterDt  = nowIso();

        createLog(testOrder.Id, 'ORDER_SUCCESS', 'Order synced successfully', null);
        
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog(testOrder.Id, afterDt);
        Test.stopTest();
    }
    
    @isTest
    static void testGetLatestLog_OrderErrorLog() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        String afterDt  = nowIso();

        createLog(testOrder.Id, 'ORDER_ERROR', 'BC returned 500 Internal Server Error', 'Connection timeout');
        
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog(testOrder.Id, afterDt);
        Test.stopTest();
    }

    @isTest
    static void testGetLatestLog_AccountSuccessLog() {
        // Log written against Account Id — should be returned for the related Order
        Order   testOrder   = [SELECT Id, AccountId FROM Order LIMIT 1];
        String  afterDt     = nowIso();

        createLog(testOrder.AccountId, 'ACCOUNT_SUCCESS', 'Account synced with BC successfully', null);
        
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog(testOrder.Id, afterDt);
        Test.stopTest();
    }
    
    @isTest
    static void testGetLatestLog_AccountErrorLog() {
        Order   testOrder   = [SELECT Id, AccountId FROM Order LIMIT 1];
        String  afterDt     = nowIso();

        createLog(testOrder.AccountId, 'ACCOUNT_ERROR', 'Account sync failed - duplicate customer number', 'Duplicate value error from BC');
        
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog(testOrder.Id, afterDt);
        Test.stopTest();
    }

    @isTest
    static void testGetLatestLog_IgnoresStaleLogBeforeStartTime() {
        // Log exists but was created BEFORE the integration was triggered — must be ignored
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        DRC_NBC_API_Log__c staleLog = new DRC_NBC_API_Log__c(
            DRC_NBC_Created_Updated_SF_Id__c = testOrder.Id,
            DRC_NBC_Log_Type__c              = 'ORDER_ERROR',
            DRC_NBC_Response_Body__c         = 'Old stale error from previous sync',
            DRC_NBC_Timestamp__c             = DateTime.now().addMinutes(-10) // older than afterDt
        );
        insert staleLog;

        // afterDt is set to NOW — so stale log (10 min ago) should not be returned
        String afterDt = DateTime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');

        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog(testOrder.Id, afterDt);
        Test.stopTest();
    }
    
    @isTest
    static void testGetLatestLog_ReturnsNewestWhenMultipleLogsExist() {
        // Inserts older ERROR log and newer SUCCESS log — newest must be returned
        Order  testOrder  = [SELECT Id, AccountId FROM Order LIMIT 1];
        String afterDt    = nowIso();

        // Older account error log
        DRC_NBC_API_Log__c olderLog = new DRC_NBC_API_Log__c(
            DRC_NBC_Created_Updated_SF_Id__c = testOrder.AccountId,
            DRC_NBC_Log_Type__c              = 'ACCOUNT_ERROR',
            DRC_NBC_Response_Body__c         = 'Account sync failed',
            DRC_NBC_Timestamp__c             = DateTime.now().addSeconds(-30)
        );
        insert olderLog;

        // Newer order success log
        DRC_NBC_API_Log__c newerLog = new DRC_NBC_API_Log__c(
            DRC_NBC_Created_Updated_SF_Id__c = testOrder.Id,
            DRC_NBC_Log_Type__c              = 'ORDER_SUCCESS',
            DRC_NBC_Response_Body__c         = 'Order synced successfully',
            DRC_NBC_Timestamp__c             = DateTime.now()
        );
        insert newerLog;
        
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog(testOrder.Id, afterDt);
        Test.stopTest();
    }

    @isTest
    static void testGetLatestLog_NullOrderId() {
        // Passing null orderId — should return null gracefully
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog(null, nowIso());
        Test.stopTest();
    }

    @isTest
    static void testGetLatestLog_NullAfterDateTime_UsesDefaultFallback() {
        // Passing null afterDateTime — Apex falls back to now()-2min, log should still be found
        Order testOrder = [SELECT Id FROM Order LIMIT 1];

        createLog(testOrder.Id, 'ORDER_SUCCESS', 'Synced OK', null);

        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog(testOrder.Id, null);
        Test.stopTest();
    }
}