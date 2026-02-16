/**
* @File Name : DRC_NBC_OrderBCController.cls
* @Description : Apex controller to trigger order integration with BC
* @Author : Satish
* @TestClass : DRC_NBC_OrderBCControllerTest
* @Last Modified On : January 02, 2026
**/
public with sharing class DRC_NBC_OrderBCController {
    
    @AuraEnabled
    public static String triggerBCIntegration(Id orderId) {
        String result;
        if (orderId == null) {
            return 'ERROR: Order Id is required.';
        }
        
        try {
            // Call BC integration synchronously
             Order ord = [
                SELECT Id, AccountId, Account.DRC_NBC_Posted_To_BC__c, DRC_NBC_Order_Sync_To_BC__c,
                       Account.DRC_NBC_BC_Approval_Status__c
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
            if (ord.Account.DRC_NBC_Posted_To_BC__c == false || ord.Account.DRC_NBC_BC_Approval_Status__c == false) {
                System.debug('Call Account Integration');
                result = DRC_NBC_Account_BC_Callout.executeCallout(orderId);
               
            }

            if (ord.Account.DRC_NBC_Posted_To_BC__c == true && ord.Account.DRC_NBC_BC_Approval_Status__c == true && ord.DRC_NBC_Order_Sync_To_BC__c == false) {
                System.debug('Call Order Integration');
                result = DRC_NBC_Order_BC_Callout.executeCallout(orderId);
            }

            if (ord.DRC_NBC_Order_Sync_To_BC__c == true && ord.Account.DRC_NBC_BC_Approval_Status__c == true) {
                System.debug('Call Order Integration');
                result = DRC_NBC_UpdateOrderAndLineItems.orderId(orderId);
            }
            return result;
        } catch (Exception ex) {
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Account getAccountDetails(Id orderId) {
        if (orderId == null) {
            throw new AuraHandledException('Order Id is required.');
        }
        
        Order ord = [
            SELECT Id, AccountId
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        
        if (ord.AccountId == null) {
            throw new AuraHandledException('No related Account found for this Order.');
        }
        
        Account acc = [
            SELECT Id, Name, DRC_NBC_Customer_Number__c
            FROM Account
            WHERE Id = :ord.AccountId
            LIMIT 1
        ];
        
        return acc;
    }

    @AuraEnabled(cacheable=true)
    public static String getIntegrationStatus(Id orderId) {
        Order ord = [SELECT DRC_NBC_Integration_Status__c FROM Order WHERE Id = :orderId];
        return ord.DRC_NBC_Integration_Status__c;
    }

}