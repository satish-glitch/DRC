public class DRC_NBC_ConsigneeBankTriggerHelper {

    public static void afterInsert(List<DRC_NBC_Consignee_Bank_Details__c> newList) {

        Set<Id> accountIds = new Set<Id>();

        for (DRC_NBC_Consignee_Bank_Details__c bank : newList) {
            if (
                bank.Account__c != null &&
                bank.DRC_NBC_Primary_Bank__c == true
            ) {
                accountIds.add(bank.Account__c);
            }
        }

        if (accountIds.isEmpty()) {
            return;
        }

        // Fetch only Accounts where Posted To BC is true
        Set<Id> accountIdsToSync = new Set<Id>();

        for (Account acc : [
            SELECT Id, DRC_NBC_Posted_To_bc__c
            FROM Account
            WHERE Id IN :accountIds
            AND DRC_NBC_Posted_To_bc__c = true
        ]) {
            accountIdsToSync.add(acc.Id);
        }

        if (accountIdsToSync.isEmpty()) {
            return;
        }

        for (Id accountId : accountIdsToSync) {
            System.enqueueJob(
                new DRC_NBC_ConsigneeBank_Callout_Queueable(null, accountId)
            );
        }
    }
}