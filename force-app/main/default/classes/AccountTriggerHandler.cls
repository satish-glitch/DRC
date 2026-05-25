public class AccountTriggerHandler {

    public static void updateOwnerManagerFromSalesPersonCode(
        List<Account> newAccounts,
        Map<Id, Account> oldMap
    ) {
        Set<String> salesPersonCodes = new Set<String>();

        for (Account acc : newAccounts) {
            if (String.isBlank(acc.SalesPerson_Code__c)) {
                continue;
            }

            Boolean shouldProcess = false;

            if (oldMap == null) {
                shouldProcess = true;
            } else {
                Account oldAcc = oldMap.get(acc.Id);

                if (oldAcc == null || acc.SalesPerson_Code__c != oldAcc.SalesPerson_Code__c) {
                    shouldProcess = true;
                }
            }

            if (shouldProcess) {
                salesPersonCodes.add(acc.SalesPerson_Code__c.trim());
            }
        }

        if (salesPersonCodes.isEmpty()) {
            return;
        }

        Map<String, SalesPerson_Code__mdt> codeToMetadataMap =
            new Map<String, SalesPerson_Code__mdt>();

        for (SalesPerson_Code__mdt spMeta : [
            SELECT MasterLabel,
                   Email__c,
                   Name__c,
                   Phone__c,
                   Salesforce_UserName__c
            FROM SalesPerson_Code__mdt
            WHERE MasterLabel IN :salesPersonCodes
        ]) {
            codeToMetadataMap.put(spMeta.MasterLabel, spMeta);
        }

        Set<String> usernames = new Set<String>();

        for (SalesPerson_Code__mdt spMeta : codeToMetadataMap.values()) {
            if (String.isNotBlank(spMeta.Salesforce_UserName__c)) {
                usernames.add(spMeta.Salesforce_UserName__c.trim());
            }
        }

        if (usernames.isEmpty()) {
            return;
        }

        Map<String, User> usernameToUserMap = new Map<String, User>();

        for (User usr : [
            SELECT Id,
                   Name,
                   Username,
                   ManagerId
            FROM User
            WHERE Username IN :usernames
        ]) {
            usernameToUserMap.put(usr.Username, usr);
        }

        for (Account acc : newAccounts) {
            if (String.isBlank(acc.SalesPerson_Code__c)) {
                continue;
            }

            String code = acc.SalesPerson_Code__c.trim();

            if (!codeToMetadataMap.containsKey(code)) {
                continue;
            }

            SalesPerson_Code__mdt spMeta = codeToMetadataMap.get(code);

            if (String.isBlank(spMeta.Salesforce_UserName__c)) {
                continue;
            }

            User mappedUser = usernameToUserMap.get(spMeta.Salesforce_UserName__c.trim());

            if (mappedUser == null) {
                continue;
            }

            acc.DRC_NBC_Owner_Manager__c = mappedUser.Id;
        }
    }
}