trigger DRC_NBC_ConsigneeBankTrigger on DRC_NBC_Consignee_Bank_Details__c
    (after insert) {

    if (Trigger.isAfter && Trigger.isInsert) {
        DRC_NBC_ConsigneeBankTriggerHelper.afterInsert(Trigger.new);
    }
}