trigger QuoteTrigger on Quote (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        QuoteTriggerHandler.updateQuoteOwnerManagerFromAccount(Trigger.new);
    }
}