public with sharing class DRC_NBC_QuoteSyncHandler {

    public static void updateSyncedQuoteId(List<Quote> newQuotes, Map<Id, Quote> oldMap) {
        Map<Id, Id> oppToQuoteMap = new Map<Id, Id>();

        for (Quote q : newQuotes) {
            Quote oldQ = oldMap.get(q.Id);

            if (
                q.OpportunityId != null &&
                q.Status == 'Accepted' &&
                oldQ.Status != 'Accepted'
            ) {
                oppToQuoteMap.put(q.OpportunityId, q.Id);
            }
        }

        if (oppToQuoteMap.isEmpty()) {
            return;
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        for (Id oppId : oppToQuoteMap.keySet()) {
            oppsToUpdate.add(new Opportunity(
                Id = oppId,
                SyncedQuoteId = oppToQuoteMap.get(oppId)
            ));
        }

        update oppsToUpdate;
    }
}