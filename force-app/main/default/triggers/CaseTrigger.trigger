trigger CaseTrigger on Case (before update) {
    if (Trigger.isBefore && Trigger.isUpdate) {
        CaseTriggerHandler.validateFilesBeforeCaseClose(Trigger.new, Trigger.oldMap);
    }
}