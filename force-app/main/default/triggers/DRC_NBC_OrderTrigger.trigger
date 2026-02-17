trigger DRC_NBC_OrderTrigger on Order (after insert, after update) {
    DRC_NBC_OrderTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
}