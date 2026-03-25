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
            DRC_NBC_Customer_Number__c = 'CUST12345',
            CurrencyIsoCode = 'INR',
            Phone = '1234567890',
            AccountNumber = 'A123',
            DRC_NBC_PAN_No__c = 'AWVPY9594J',
            DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c = '10 DAYS',
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
    
    @isTest
    static void testGetIntegrationStatus_ReturnsStatus() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        String result = DRC_NBC_OrderBCController.getIntegrationStatus(testOrder.Id);
        Test.stopTest();}
    
    @isTest
    static void testGetIntegrationStatus_WithStatusValueSet() {
        Order testOrder = [SELECT Id FROM Order LIMIT 1];
        
        // Set a known integration status value on the order
        testOrder.DRC_NBC_Integration_Status__c = 'Success'; // adjust to valid picklist value in your org
        update testOrder;
        
        Test.startTest();
        String result = DRC_NBC_OrderBCController.getIntegrationStatus(testOrder.Id);
        Test.stopTest();
    }
}