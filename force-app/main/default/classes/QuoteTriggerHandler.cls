public class QuoteTriggerHandler {
    
    public static void updateQuoteOwnerManagerFromAccount(List<Quote> newQuotes) {
        
        // Step 1: Collect all OpportunityIds from the new Quotes
        Set<Id> opportunityIds = new Set<Id>();
        for (Quote qt : newQuotes) {
            if (qt.OpportunityId != null) {
                opportunityIds.add(qt.OpportunityId);
            }
        }
        if (opportunityIds.isEmpty()) return;
        
        // Step 2: Get AccountId from each Opportunity
        Map<Id, Id> oppToAccountMap = new Map<Id, Id>();
        Set<Id> accountIds = new Set<Id>();
        
        for (Opportunity opp : [
            SELECT Id, AccountId
            FROM Opportunity
            WHERE Id IN :opportunityIds
            AND AccountId != null          // filter in SOQL — avoids null check later
        ]) {
            oppToAccountMap.put(opp.Id, opp.AccountId);
            accountIds.add(opp.AccountId);
        }
        if (accountIds.isEmpty()) return;
        
        // Step 3: Get Account Manager field from each Account
        Map<Id, Account> accountMap = new Map<Id, Account>([
            SELECT Id, DRC_NBC_Owner_Manager__c
            FROM Account
            WHERE Id IN :accountIds
            AND DRC_NBC_Owner_Manager__c != null   // only care about accounts with a manager
        ]);
        if (accountMap.isEmpty()) return;
        
        // Step 4: Compare and collect Quotes that need updating
        List<Quote> quotesToUpdate = new List<Quote>();
        
        for (Quote qt : newQuotes) {
            if (qt.OpportunityId == null) continue;
            
            Id accountId = oppToAccountMap.get(qt.OpportunityId);
            if (accountId == null) continue;
            
            Account acc = accountMap.get(accountId);
            if (acc == null) continue;
            
            // Only update if Quote manager doesn't already match Account manager
            if (qt.DRC_Account_Owner_Manager__c != acc.DRC_NBC_Owner_Manager__c) {
                quotesToUpdate.add(new Quote(
                    Id = qt.Id,
                    DRC_Account_Owner_Manager__c = acc.DRC_NBC_Owner_Manager__c
                ));
            }
        }
        
        // Step 5: Bulk update
        if (!quotesToUpdate.isEmpty()) {
            update quotesToUpdate;
        }
    }
}