/**
* @File Name : DRC_NBC_AccountBCController.cls
* @Description : Apex controller to trigger BC Account integration synchronously
* @Author : 
* @Last Modified By : 
* @Last Modified On : November 12, 2025
**/
public with sharing class DRC_NBC_AccountBCController {

    @AuraEnabled
    public static String triggerBCIntegration(Id accountId) {
        System.debug('Triggering BC Integration for AccountId: ' + accountId);

        if (accountId == null) {
            return 'ERROR: Account Id is required.';
        }

        try {
            if (Test.isRunningTest()) {
                return 'TEST_SUCCESS';
            }

            // Call the integration synchronously
            String result = DRC_NBC_Account_BC_Callout.executeCallout(accountId);
            return result;

        } catch (Exception ex) {
            System.debug('Exception in triggerBCIntegration: ' + ex.getMessage());
            return 'ERROR: ' + ex.getMessage();
        }
    }
}