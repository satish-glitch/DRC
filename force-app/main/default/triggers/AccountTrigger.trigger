trigger AccountTrigger on Account (before insert, before update) {
    if (Trigger.isBefore && (Trigger.isInsert || Trigger.isUpdate)) {
        AccountTriggerHandler.updateOwnerManagerFromSalesPersonCode(
            Trigger.new,
            Trigger.oldMap
        );
    }
}