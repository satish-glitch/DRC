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
        Test.stopTest();    }
    
    // ── getIntegrationStatus ─────────────────────────────────────────────────
    
    @isTest
    static void testGetIntegrationStatus_ReturnsNull() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_OrderBCController.getIntegrationStatus(testOrder.Id);
        Test.stopTest();
        
        System.assertEquals(null, result, 'Integration status should be null when not set');
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
        // No logs inserted — should return null
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog();
        Test.stopTest();
    }
    
    @isTest
    static void testGetLatestLog_ReturnsLatestSuccessLog() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        // Insert an older log first, then a newer SUCCESS log
        DRC_NBC_API_Log__c olderLog = new DRC_NBC_API_Log__c(
            DRC_NBC_Created_Updated_SF_Id__c = testOrder.Id,
            DRC_NBC_Log_Type__c              = 'ERROR',
            DRC_NBC_Response_Body__c         = 'Old error response',
            DRC_NBC_Timestamp__c             = DateTime.now().addMinutes(-5)
        );
        insert olderLog;
        
        DRC_NBC_API_Log__c newerLog = new DRC_NBC_API_Log__c(
            DRC_NBC_Created_Updated_SF_Id__c = testOrder.Id,
            DRC_NBC_Log_Type__c              = 'SUCCESS',
            DRC_NBC_Response_Body__c         = 'Order synced successfully',
            DRC_NBC_Timestamp__c             = DateTime.now()
        );
        insert newerLog;
        
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog();
        Test.stopTest();
    }
    
    @isTest
    static void testGetLatestLog_ReturnsLatestErrorLog() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        DRC_NBC_API_Log__c errorLog = new DRC_NBC_API_Log__c(
            DRC_NBC_Created_Updated_SF_Id__c = testOrder.Id,
            DRC_NBC_Log_Type__c              = 'ERROR',
            DRC_NBC_Response_Body__c         = 'BC returned 500 Internal Server Error',
            DRC_NBC_Error_Message__c         = 'Connection timeout',
            DRC_NBC_Timestamp__c             = DateTime.now()
        );
        insert errorLog;
        
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog();
        Test.stopTest();
    }
    
    @isTest
    static void testGetLatestLog_AccountLog_Success() {
        // Simulate a log written for an Account (not an Order)
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        DRC_NBC_API_Log__c accountLog = new DRC_NBC_API_Log__c(
            DRC_NBC_Created_Updated_SF_Id__c = testAccount.Id,
            DRC_NBC_Log_Type__c              = 'SUCCESS',
            DRC_NBC_Response_Body__c         = 'Account synced with BC successfully',
            DRC_NBC_Timestamp__c             = DateTime.now()
        );
        insert accountLog;
        
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog();
        Test.stopTest();
    }
    
    @isTest
    static void testGetLatestLog_AccountLog_Error() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        DRC_NBC_API_Log__c accountLog = new DRC_NBC_API_Log__c(
            DRC_NBC_Created_Updated_SF_Id__c = testAccount.Id,
            DRC_NBC_Log_Type__c              = 'ERROR',
            DRC_NBC_Response_Body__c         = 'Account sync failed - duplicate customer number',
            DRC_NBC_Error_Message__c         = 'Duplicate value error from BC',
            DRC_NBC_Timestamp__c             = DateTime.now()
        );
        insert accountLog;
        
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog();
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetLatestLog_AlwaysReturnsNewest() {
        // Verifies ordering — inserts multiple logs, newest must be returned
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        List<DRC_NBC_API_Log__c> logs = new List<DRC_NBC_API_Log__c>{
            new DRC_NBC_API_Log__c(
                DRC_NBC_Created_Updated_SF_Id__c = testAccount.Id,
                DRC_NBC_Log_Type__c              = 'ERROR',
                DRC_NBC_Response_Body__c         = 'Oldest log',
                DRC_NBC_Timestamp__c             = DateTime.now().addMinutes(-10)
            ),
                new DRC_NBC_API_Log__c(
                    DRC_NBC_Created_Updated_SF_Id__c = testOrder.Id,
                    DRC_NBC_Log_Type__c              = 'SUCCESS',
                    DRC_NBC_Response_Body__c         = 'Middle log',
                    DRC_NBC_Timestamp__c             = DateTime.now().addMinutes(-5)
                ),
                new DRC_NBC_API_Log__c(
                    DRC_NBC_Created_Updated_SF_Id__c = testOrder.Id,
                    DRC_NBC_Log_Type__c              = 'SUCCESS',
                    DRC_NBC_Response_Body__c         = 'Newest log - should be returned',
                    DRC_NBC_Timestamp__c             = DateTime.now()
                )
                };
                    insert logs;
        
        Test.startTest();
        DRC_NBC_API_Log__c result = DRC_NBC_OrderBCController.getLatestLog();
        Test.stopTest();
    }
}