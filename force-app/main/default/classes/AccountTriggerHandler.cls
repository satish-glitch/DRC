public class AccountTriggerHandler {

    // ─────────────────────────────────────────────────────────────
    // BEFORE INSERT / UPDATE
    // Populate DRC_NBC_Owner_Manager__c from SalesPerson_Code__c
    // ─────────────────────────────────────────────────────────────
    public static void updateOwnerManagerFromSalesPersonCode(
        List<Account> newAccounts,
        Map<Id, Account> oldMap
    ) {
        Set<String> salesPersonCodes = new Set<String>();
        for (Account acc : newAccounts) {
            if (String.isBlank(acc.SalesPerson_Code__c)) continue;
            String newCode = acc.SalesPerson_Code__c.trim();
            if (oldMap == null) {
                salesPersonCodes.add(newCode);
            } else {
                Account oldAcc = oldMap.get(acc.Id);
                String oldCode = (oldAcc != null && !String.isBlank(oldAcc.SalesPerson_Code__c))
                    ? oldAcc.SalesPerson_Code__c.trim() : null;
                if (oldCode == null || newCode != oldCode) {
                    salesPersonCodes.add(newCode);
                }
            }
        }
        if (salesPersonCodes.isEmpty()) return;

        Map<String, SalesPerson_Code__mdt> codeToMetadataMap = new Map<String, SalesPerson_Code__mdt>();
        for (SalesPerson_Code__mdt spMeta : [
            SELECT MasterLabel, Name__c, Email__c, Phone__c, Salesforce_UserName__c
            FROM   SalesPerson_Code__mdt
            WHERE  Name__c IN :salesPersonCodes
        ]) {
            codeToMetadataMap.put(spMeta.Name__c, spMeta);
        }
        if (codeToMetadataMap.isEmpty()) return;

        Set<String> usernames = new Set<String>();
        for (SalesPerson_Code__mdt spMeta : codeToMetadataMap.values()) {
            if (String.isNotBlank(spMeta.Salesforce_UserName__c)) {
                usernames.add(spMeta.Salesforce_UserName__c.trim());
            }
        }
        if (usernames.isEmpty()) return;

        Map<String, User> usernameToUserMap = new Map<String, User>();
        for (User usr : [
            SELECT Id, Name, Username, ManagerId
            FROM   User
            WHERE  Username IN :usernames
            AND    IsActive  = true
        ]) {
            usernameToUserMap.put(usr.Username, usr);
        }

        for (Account acc : newAccounts) {
            if (String.isBlank(acc.SalesPerson_Code__c)) continue;
            String code = acc.SalesPerson_Code__c.trim();
            if (!codeToMetadataMap.containsKey(code)) continue;
            SalesPerson_Code__mdt spMeta = codeToMetadataMap.get(code);
            if (String.isBlank(spMeta.Salesforce_UserName__c)) continue;
            User mappedUser = usernameToUserMap.get(spMeta.Salesforce_UserName__c.trim());
            if (mappedUser == null) continue;
            acc.DRC_NBC_Owner_Manager__c = mappedUser.Id;
        }
    }

    // ─────────────────────────────────────────────────────────────
    // AFTER INSERT / UPDATE
    // Add/replace Account Team Member for the Owner Manager
    // Role = Sales Manager | R/W on Account, Contact, Opportunity, Case
    // ─────────────────────────────────────────────────────────────
    public static void manageAccountTeamMembers(
        List<Account> newAccounts,
        Map<Id, Account> oldMap
    ) {
        // ── 1. Collect accounts where DRC_NBC_Owner_Manager__c is set
        //       and has changed (or is new on insert) ─────────────────
        Map<Id, Id> accountIdToNewManager   = new Map<Id, Id>();  // accountId → new managerId
        Map<Id, Id> accountIdToOldManager   = new Map<Id, Id>();  // accountId → old managerId (update only)

        for (Account acc : newAccounts) {
            if (acc.DRC_NBC_Owner_Manager__c == null) continue;

            if (oldMap == null) {
                // INSERT — no old manager exists
                accountIdToNewManager.put(acc.Id, acc.DRC_NBC_Owner_Manager__c);
            } else {
                Account oldAcc = oldMap.get(acc.Id);
                Id oldMgr = (oldAcc != null) ? oldAcc.DRC_NBC_Owner_Manager__c : null;
                Id newMgr = acc.DRC_NBC_Owner_Manager__c;

                if (oldMgr != newMgr) {
                    accountIdToNewManager.put(acc.Id, newMgr);
                    if (oldMgr != null) {
                        accountIdToOldManager.put(acc.Id, oldMgr);
                    }
                }
            }
        }
        if (accountIdToNewManager.isEmpty()) return;

        // ── 2. Find existing AccountTeamMember records for the old managers
        //       so we can delete them ─────────────────────────────────────
        List<AccountTeamMember> toDelete = new List<AccountTeamMember>();

        if (!accountIdToOldManager.isEmpty()) {
            // Build a set of (accountId + userId) pairs to match precisely
            Set<Id> involvedAccountIds = accountIdToOldManager.keySet();
            Set<Id> oldManagerIds      = new Set<Id>(accountIdToOldManager.values());

            for (AccountTeamMember atm : [
                SELECT Id, AccountId, UserId
                FROM   AccountTeamMember
                WHERE  AccountId IN :involvedAccountIds
                AND    UserId    IN :oldManagerIds
            ]) {
                // Only delete the record that matches the specific account ↔ old-manager pair
                Id expectedOldMgr = accountIdToOldManager.get(atm.AccountId);
                if (expectedOldMgr != null && expectedOldMgr == atm.UserId) {
                    toDelete.add(atm);
                }
            }
        }

        // ── 3. Also check if the NEW manager is already on the team
        //       (skip insert if already present, avoid duplicate error) ──
        Set<Id> newManagerIds    = new Set<Id>(accountIdToNewManager.values());
        Set<Id> accountsToAdd    = new Set<Id>(accountIdToNewManager.keySet());
        Set<String> existingKeys = new Set<String>(); // 'accountId|userId'

        for (AccountTeamMember atm : [
            SELECT Id, AccountId, UserId
            FROM   AccountTeamMember
            WHERE  AccountId IN :accountsToAdd
            AND    UserId    IN :newManagerIds
        ]) {
            existingKeys.add(atm.AccountId + '|' + atm.UserId);
        }

        // ── 4. Build new AccountTeamMember records ────────────────────
        List<AccountTeamMember> toInsert = new List<AccountTeamMember>();

        for (Id accId : accountIdToNewManager.keySet()) {
            Id newMgr = accountIdToNewManager.get(accId);
            String key = accId + '|' + newMgr;
            if (existingKeys.contains(key)) continue; // already exists — skip

            toInsert.add(new AccountTeamMember(
                AccountId               = accId,
                UserId                  = newMgr,
                TeamMemberRole          = 'Sales Manager',      // ← your exact picklist value
                AccountAccessLevel      = 'Edit',
                ContactAccessLevel      = 'Edit',
                OpportunityAccessLevel  = 'Edit',
                CaseAccessLevel         = 'Edit'
            ));
        }

        // ── 5. DML — delete old, insert new ──────────────────────────
        if (!toDelete.isEmpty()) {
            delete toDelete;
        }
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }
    }
}