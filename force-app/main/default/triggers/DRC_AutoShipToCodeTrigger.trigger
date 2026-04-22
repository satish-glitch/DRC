trigger DRC_AutoShipToCodeTrigger on DRC_NBC_Addresses__c (after insert) {
    DRC_NBC_ShipToCodeGenerator.assignShipToCodeSync(Trigger.new);
}