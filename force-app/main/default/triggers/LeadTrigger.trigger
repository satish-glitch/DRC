trigger LeadTrigger on Lead (after insert) {
    LeadTriggerHandler.handleAfterInsert(Trigger.new);
}