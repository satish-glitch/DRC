trigger DRC_NBC_CopyCompetitorOnLeadConversion on Lead (after update) {
    List<Id> DRC_NBC_ConvertedLeadIds = new List<Id>();
    Map<Id, Id> DRC_NBC_LeadToAccountMap = new Map<Id, Id>();

    //  Collect Lead IDs that were just converted
    for (Lead DRC_NBC_Lead : Trigger.new) {
        Lead DRC_NBC_OldLead = Trigger.oldMap.get(DRC_NBC_Lead.Id);

        if (DRC_NBC_Lead.IsConverted &&
            !DRC_NBC_OldLead.IsConverted &&
            DRC_NBC_Lead.ConvertedAccountId != null) {

            DRC_NBC_ConvertedLeadIds.add(DRC_NBC_Lead.Id);
            DRC_NBC_LeadToAccountMap.put(DRC_NBC_Lead.Id, DRC_NBC_Lead.ConvertedAccountId);
        }
    }

    // Query all competitors linked to the converted Leads
    List<DRC_NBC_Competitor__c> DRC_NBC_CompetitorsToUpdate = new List<DRC_NBC_Competitor__c>();

    if (!DRC_NBC_ConvertedLeadIds.isEmpty()) {
        List<DRC_NBC_Competitor__c> DRC_NBC_LeadCompetitors = [
            SELECT Id, DRC_NBC_Lead__c
            FROM DRC_NBC_Competitor__c
            WHERE DRC_NBC_Lead__c IN :DRC_NBC_ConvertedLeadIds
        ];

        //  Update each competitor with the corresponding Account ID
        for (DRC_NBC_Competitor__c DRC_NBC_Comp : DRC_NBC_LeadCompetitors) {
            Id DRC_NBC_ConvertedAccountId = DRC_NBC_LeadToAccountMap.get(DRC_NBC_Comp.DRC_NBC_Lead__c);
            DRC_NBC_Comp.DRC_NBC_Account__c = DRC_NBC_ConvertedAccountId;
            DRC_NBC_Comp.DRC_NBC_Lead__c = null; // Optional: Clear the Lead lookup
            DRC_NBC_CompetitorsToUpdate.add(DRC_NBC_Comp);
        }

        if (!DRC_NBC_CompetitorsToUpdate.isEmpty()) {
            update DRC_NBC_CompetitorsToUpdate;
        }
    }
}