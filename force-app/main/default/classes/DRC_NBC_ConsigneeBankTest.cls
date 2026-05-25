@isTest
public class DRC_NBC_ConsigneeBankTest {
    
    // =========================================================================
    // TEST DATA SETUP
    // =========================================================================
    
    @TestSetup
    static void setupTestData() {
        // Custom Setting
        DRC_NBC_BC_Integration__c config = new DRC_NBC_BC_Integration__c(
            SetupOwnerId             = UserInfo.getOrganizationId(),
            Account_SOAP_Endpoint__c = 'https://mock-bc-endpoint.com/soap',
            Account_SOAP_NS__c       = 'http://schemas.xmlsoap.org/soap/envelope/',
            Account_BC_NS__c         = 'urn:microsoft-dynamics-schemas/page/customersalesforce',
            DRC_NBC_Username__c      = 'testuser',
            DRC_NBC_Password__c      = 'testpass',
            DRC_NBC_SalesPerson_Code__c = 'Ajitva'
        );
        insert config;
        
        Account acc = DRC_NBC_TestFactory.createAccount();
    }
    
    // =========================================================================
    // HELPER — fetch account from DB
    // =========================================================================
    
    private static Account getAccount() {
        return [
            SELECT Id,
            Name,
            DRC_NBC_Customer_Number__c,
            SalesPerson_Code__c
            FROM   Account
            LIMIT  1
        ];
    }
    
   
    // =========================================================================
    // updateAccountManager — null recordId
    // =========================================================================
    
    @isTest
    static void testUpdateAccountManager_NullId() {
        String errorMessage;
        
        Test.startTest();
        try {
            DRC_NBC_ConsigneeBank_ActionController.updateAccountManager(null);
        } catch (AuraHandledException e) {
            errorMessage = e.getMessage();
        }
        Test.stopTest();

    }
    
    // =========================================================================
    // updateAccountManager — wrong SObject type (Contact instead of Account)
    // =========================================================================
    
    @isTest
    static void testUpdateAccountManager_WrongSObjectType() {
        Contact con = new Contact(LastName = 'TestContact');
        insert con;
        
        String errorMessage;
        
        Test.startTest();
        try {
            DRC_NBC_ConsigneeBank_ActionController.updateAccountManager(con.Id);
        } catch (AuraHandledException e) {
            errorMessage = e.getMessage();
        }
        Test.stopTest();
    }
    
    // =========================================================================
    // updateAccountManager — blank Customer Number
    // =========================================================================
    
    @isTest
    static void testUpdateAccountManager_BlankCustomerNumber() {
        Account acc = getAccount();
        acc.DRC_NBC_Customer_Number__c = null;
        update acc;
        
        String errorMessage;
        
        Test.startTest();
        try {
            DRC_NBC_ConsigneeBank_ActionController.updateAccountManager(acc.Id);
        } catch (AuraHandledException e) {
            errorMessage = e.getMessage();
        }
        Test.stopTest();
    }
    
    // =========================================================================
    // updateAccountManager — blank SalesPerson Code
    // =========================================================================
    
    @isTest
    static void testUpdateAccountManager_BlankSalesPersonCode() {
        Account acc = getAccount();
        acc.SalesPerson_Code__c = null;
        update acc;
        
        String errorMessage;
        
        Test.startTest();
        try {
            DRC_NBC_ConsigneeBank_ActionController.updateAccountManager(acc.Id);
        } catch (AuraHandledException e) {
            errorMessage = e.getMessage();
        }
        Test.stopTest();
    }
    
    // =========================================================================
    // getLatestLog — null recordId returns null
    // =========================================================================
    
    @isTest
    static void testGetLatestLog_NullId() {
        Test.startTest();
        DRC_NBC_API_Log__c result =
            DRC_NBC_ConsigneeBank_ActionController.getLatestLog(null, null);
        Test.stopTest();
    }
    
    // =========================================================================
    // getLatestLog — wrong SObject type throws exception
    // =========================================================================
    
    @isTest
    static void testGetLatestLog_WrongSObjectType() {
        Contact con = new Contact(LastName = 'LogContact');
        insert con;
        
        String errorMessage;
        
        Test.startTest();
        try {
            DRC_NBC_ConsigneeBank_ActionController.getLatestLog(con.Id, null);
        } catch (AuraHandledException e) {
            errorMessage = e.getMessage();
        }
        Test.stopTest();
    }
    
    // =========================================================================
    // getLatestLog — valid Account with no logs returns null
    // =========================================================================
    
    @isTest
    static void testGetLatestLog_NoLogsReturnsNull() {
        Account acc = getAccount();
        
        Test.startTest();
        DRC_NBC_API_Log__c result =
            DRC_NBC_ConsigneeBank_ActionController.getLatestLog(acc.Id, null);
        Test.stopTest();
    }
}