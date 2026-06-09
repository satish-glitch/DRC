public class AccountTriggerHandler {
    
    // ─────────────────────────────────────────────────────────────
    // BEFORE INSERT / UPDATE
    // Populate DRC_NBC_Owner_Manager__c from SalesPerson_Code__c
    // ─────────────────────────────────────────────────────────────
    public static void updateOwnerManagerFromSalesPersonCode(
    List<Account> newAccounts,
        Map<Id, Account> oldMap
        ) {
            if (newAccounts == null || newAccounts.isEmpty()) {
                return;
            }
            
            Set<String> metadataKeys = new Set<String>();
            
            for (Account acc : newAccounts) {
                Account oldAcc = oldMap != null ? oldMap.get(acc.Id) : null;
                
                // Sales Person Code
                String newSalesCode = String.isNotBlank(acc.SalesPerson_Code__c)
                    ? acc.SalesPerson_Code__c.trim()
                    : null;
                
                String oldSalesCode = oldAcc != null && String.isNotBlank(oldAcc.SalesPerson_Code__c)
                    ? oldAcc.SalesPerson_Code__c.trim()
                    : null;
                
                if ((oldMap == null || newSalesCode != oldSalesCode) && String.isNotBlank(newSalesCode)) {
                    metadataKeys.add(newSalesCode);
                }
                
                // Highest Authority picklist value
                String newAuthorityName = String.isNotBlank(acc.DRC_NBC_Highest_Authority_For_Approval__c)
                    ? acc.DRC_NBC_Highest_Authority_For_Approval__c.trim()
                    : null;
                
                String oldAuthorityName = oldAcc != null && String.isNotBlank(oldAcc.DRC_NBC_Highest_Authority_For_Approval__c)
                    ? oldAcc.DRC_NBC_Highest_Authority_For_Approval__c.trim()
                    : null;
                
                if ((oldMap == null || newAuthorityName != oldAuthorityName) && String.isNotBlank(newAuthorityName)) {
                    metadataKeys.add(newAuthorityName);
                }
            }
            
            if (metadataKeys.isEmpty()) {
                return;
            }
            
            Map<String, SalesPerson_Code__mdt> keyToMetadataMap = new Map<String, SalesPerson_Code__mdt>();
            
            // Query 1: Match Account value with Name__c
            for (SalesPerson_Code__mdt spMeta : [
                SELECT MasterLabel,
                Name__c,
                Email__c,
                Phone__c,
                Salesforce_UserName__c
                FROM SalesPerson_Code__mdt
                WHERE Name__c IN :metadataKeys
            ]) {
                if (String.isNotBlank(spMeta.Name__c)) {
                    keyToMetadataMap.put(spMeta.Name__c.trim().toLowerCase(), spMeta);
                }
                
                if (String.isNotBlank(spMeta.MasterLabel)) {
                    keyToMetadataMap.put(spMeta.MasterLabel.trim().toLowerCase(), spMeta);
                }
            }
            
            // Query 2: Match Account value with MasterLabel
            for (SalesPerson_Code__mdt spMeta : [
                SELECT MasterLabel,
                Name__c,
                Email__c,
                Phone__c,
                Salesforce_UserName__c
                FROM SalesPerson_Code__mdt
                WHERE MasterLabel IN :metadataKeys
            ]) {
                if (String.isNotBlank(spMeta.Name__c)) {
                    keyToMetadataMap.put(spMeta.Name__c.trim().toLowerCase(), spMeta);
                }
                
                if (String.isNotBlank(spMeta.MasterLabel)) {
                    keyToMetadataMap.put(spMeta.MasterLabel.trim().toLowerCase(), spMeta);
                }
            }
            
            if (keyToMetadataMap.isEmpty()) {
                return;
            }
            
            Set<String> usernames = new Set<String>();
            
            for (SalesPerson_Code__mdt spMeta : keyToMetadataMap.values()) {
                if (String.isNotBlank(spMeta.Salesforce_UserName__c)) {
                    usernames.add(spMeta.Salesforce_UserName__c.trim());
                }
            }
            
            Map<String, User> usernameToUserMap = new Map<String, User>();
            
            if (!usernames.isEmpty()) {
                for (User usr : [
                    SELECT Id, Username
                    FROM User
                    WHERE Username IN :usernames
                    AND IsActive = true
                ]) {
                    usernameToUserMap.put(usr.Username.trim().toLowerCase(), usr);
                }
            }
            
            for (Account acc : newAccounts) {
                Account oldAcc = oldMap != null ? oldMap.get(acc.Id) : null;
                
                // ==================================================
                // 1. Update Owner Manager from SalesPerson_Code__c
                // ==================================================
                String newSalesCode = String.isNotBlank(acc.SalesPerson_Code__c)
                    ? acc.SalesPerson_Code__c.trim()
                    : null;
                
                String oldSalesCode = oldAcc != null && String.isNotBlank(oldAcc.SalesPerson_Code__c)
                    ? oldAcc.SalesPerson_Code__c.trim()
                    : null;
                
                Boolean salesCodeChanged = oldMap == null || newSalesCode != oldSalesCode;
                
                if (salesCodeChanged) {
                    if (String.isBlank(newSalesCode)) {
                        acc.DRC_NBC_Owner_Manager__c = null;
                    } else {
                        SalesPerson_Code__mdt salesMeta =
                            keyToMetadataMap.get(newSalesCode.toLowerCase());
                        
                        if (
                            salesMeta != null &&
                            String.isNotBlank(salesMeta.Salesforce_UserName__c)
                        ) {
                            User mappedUser = usernameToUserMap.get(
                                salesMeta.Salesforce_UserName__c.trim().toLowerCase()
                            );
                            
                            acc.DRC_NBC_Owner_Manager__c =
                                mappedUser != null ? mappedUser.Id : null;
                        } else {
                            acc.DRC_NBC_Owner_Manager__c = null;
                        }
                    }
                }
                
                // ==================================================
                // 2. Update Highest Authority User from picklist
                // ==================================================
                String newAuthorityName = String.isNotBlank(acc.DRC_NBC_Highest_Authority_For_Approval__c)
                    ? acc.DRC_NBC_Highest_Authority_For_Approval__c.trim()
                    : null;
                
                String oldAuthorityName = oldAcc != null && String.isNotBlank(oldAcc.DRC_NBC_Highest_Authority_For_Approval__c)
                    ? oldAcc.DRC_NBC_Highest_Authority_For_Approval__c.trim()
                    : null;
                
                Boolean authorityChanged = oldMap == null || newAuthorityName != oldAuthorityName;
                
                if (authorityChanged) {
                    if (String.isBlank(newAuthorityName)) {
                        acc.DRC_NBC_Highest_Authority_User__c = null;
                    } else {
                        SalesPerson_Code__mdt authorityMeta =
                            keyToMetadataMap.get(newAuthorityName.toLowerCase());
                        
                        if (
                            authorityMeta != null &&
                            String.isNotBlank(authorityMeta.Salesforce_UserName__c)
                        ) {
                            User authorityUser = usernameToUserMap.get(
                                authorityMeta.Salesforce_UserName__c.trim().toLowerCase()
                            );
                            
                            acc.DRC_NBC_Highest_Authority_User__c =
                                authorityUser != null ? authorityUser.Id : null;
                        } else {
                            acc.DRC_NBC_Highest_Authority_User__c = null;
                        }
                    }
                }
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