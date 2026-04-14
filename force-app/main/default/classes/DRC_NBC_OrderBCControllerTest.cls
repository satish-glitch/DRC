/**
* @File Name : DRC_NBC_OrderBCControllerTest.cls
* @Description : Test class for DRC_NBC_OrderBCController
* @Author : Satish
* @TestClass : DRC_NBC_OrderBCControllerTest
* @Last Modified On : April 08, 2026
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
    
    @isTest
    static void testGetAccountSyncStatus_Success() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        Boolean result = DRC_NBC_OrderBCController.getAccountSyncStatus(testOrder.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetAccountSyncStatus_PostedTrue() {
        Order testOrder = [SELECT Id, AccountId FROM Order LIMIT 1];
        
        // Set Posted_To_BC to true
        Account acc = [SELECT Id FROM Account WHERE Id = :testOrder.AccountId LIMIT 1];
        acc.DRC_NBC_Posted_To_BC__c = true;
        update acc;
        
        Test.startTest();
        Boolean result = DRC_NBC_OrderBCController.getAccountSyncStatus(testOrder.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetIntegrationStatus_ReturnsStatus() {
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
}