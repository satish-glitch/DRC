trigger QuoteTrigger on Quote (after update) {
    DRC_NBC_QuoteSyncHandler.updateSyncedQuoteId(Trigger.new, Trigger.oldMap);
}