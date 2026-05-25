public with sharing class DRC_NBC_ConsigneeBank_ActionController {
    
    @AuraEnabled
    public static String updateAccountManager(Id recordId) {

        if (recordId == null) {
            throw new AuraHandledException('Account Id is missing.');
        }

        if (recordId.getSObjectType() != Account.SObjectType) {
            throw new AuraHandledException('This action can be used only on Account records.');
        }

        Account acc = [
            SELECT Id,
                   Name,
                   DRC_NBC_Customer_Number__c,
                   SalesPerson_Code__c
            FROM Account
            WHERE Id = :recordId
            LIMIT 1
        ];

        if (String.isBlank(acc.DRC_NBC_Customer_Number__c)) {
            throw new AuraHandledException('Account has no BC Customer Number.');
        }

        if (String.isBlank(acc.SalesPerson_Code__c)) {
            throw new AuraHandledException('SalesPerson Code is blank on Account.');
        }

        System.enqueueJob(
            new DRC_NBC_Account_SOAP_Queueable(acc.Id)
        );

        return 'Account Manager update started successfully.';
    }

    @AuraEnabled
    public static DRC_NBC_API_Log__c getLatestLog(Id recordId, String afterDateTime) {
        if (recordId == null) {
            return null;
        }

        if (recordId.getSObjectType() != Account.SObjectType) {
            throw new AuraHandledException('This action can be used only on Account records.');
        }

        DateTime filterDt = String.isNotBlank(afterDateTime)
            ? (DateTime) JSON.deserialize('"' + afterDateTime + '"', DateTime.class)
            : System.now().addMinutes(-2);

        List<DRC_NBC_API_Log__c> logs = [
            SELECT Id,
                   Name,
                   DRC_NBC_Log_Type__c,
                   DRC_NBC_Response_Body__c,
                   DRC_NBC_Timestamp__c,
                   DRC_NBC_Error_Message__c,
                   DRC_NBC_Created_Updated_SF_Id__c
            FROM DRC_NBC_API_Log__c
            WHERE DRC_NBC_Created_Updated_SF_Id__c = :recordId
            AND DRC_NBC_Timestamp__c >= :filterDt
            AND CreatedById = :UserInfo.getUserId()
            ORDER BY DRC_NBC_Timestamp__c DESC
            LIMIT 1
        ];

        return logs.isEmpty() ? null : logs[0];
    }
}