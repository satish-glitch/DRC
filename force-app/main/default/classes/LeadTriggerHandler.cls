public class LeadTriggerHandler {

    public static void handleAfterInsert(List<Lead> newLeads) {
        Set<Id> leadIds = new Set<Id>();
        for (Lead l : newLeads) {
            if (l.Id != null) {
                leadIds.add(l.Id);
            }
        }

        // Fetch related Lead Products
        Map<Id, List<DRC_NBC_Lead_Product__c>> leadToProductsMap = new Map<Id, List<DRC_NBC_Lead_Product__c>>();
        for (DRC_NBC_Lead_Product__c lp : [
            SELECT Name, DRC_NBC_Lead__c
            FROM DRC_NBC_Lead_Product__c
            WHERE DRC_NBC_Lead__c IN :leadIds
        ]) {
            if (!leadToProductsMap.containsKey(lp.DRC_NBC_Lead__c)) {
                leadToProductsMap.put(lp.DRC_NBC_Lead__c, new List<DRC_NBC_Lead_Product__c>());
            }
            leadToProductsMap.get(lp.DRC_NBC_Lead__c).add(lp);
        }

        List<Lead> leadsToUpdate = new List<Lead>();

        for (Lead l : newLeads) {
            if (leadToProductsMap.containsKey(l.Id)) {
                List<DRC_NBC_Lead_Product__c> products = leadToProductsMap.get(l.Id);
                List<String> productNames = new List<String>();

                for (DRC_NBC_Lead_Product__c product : products) {
                    productNames.add(product.Name);
                }

                String joined = String.join(productNames, ';');
                Lead updatedLead = new Lead(
                    Id = l.Id,
                    DRC_NBC_Interested_Chemistry__c = joined
                );
                leadsToUpdate.add(updatedLead);
            }
        }

        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }
    }
}