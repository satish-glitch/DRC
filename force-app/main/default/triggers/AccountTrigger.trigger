trigger AccountTrigger on Account (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(
                Trigger.new,
                Trigger.oldMap
            );
        }
    }
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            AccountTriggerHandler.manageAccountTeamMembers(
                Trigger.new,
                Trigger.oldMap
            );
        }
    }
}