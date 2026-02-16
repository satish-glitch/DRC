/**
* @File Name : DRC_NBC_OrderBCControllerTest.cls
* @Description : Test class for DRC_NBC_OrderBCController
* @Author : Satish
* @Last Modified On : January 02, 2026
**/
@isTest
private class DRC_NBC_OrderBCControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account',
            DRC_NBC_Customer_Number__c = 'CUST12345'
        );
        insert testAccount;
        
        // Create test Order
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
        // Retrieve test order
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
    static void testGetAccountDetails_Success() {
        // Retrieve test order
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        Account result = DRC_NBC_OrderBCController.getAccountDetails(testOrder.Id);
        Test.stopTest();
    }
    
    @isTest
    static void testGetAccountDetails_NullOrderId() {
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        
        Test.startTest();
        try {
            Account result = DRC_NBC_OrderBCController.getAccountDetails(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();
    }
    
   /* @isTest
    static void testGetAccountDetails_OrderWithoutAccount() {
        // Create an order without an account
        Order orderWithoutAccount = new Order(
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Name = 'Order Without Account'
        );
        insert orderWithoutAccount;
        
        Boolean exceptionThrown = false;
        String exceptionMessage = '';
        
        Test.startTest();
        try {
            Account result = DRC_NBC_OrderBCController.getAccountDetails(orderWithoutAccount.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            exceptionMessage = e.getMessage();
        }
        Test.stopTest();
    }*/
}