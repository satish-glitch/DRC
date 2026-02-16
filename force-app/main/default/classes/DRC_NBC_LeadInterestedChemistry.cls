public with sharing class DRC_NBC_LeadInterestedChemistry {

    public class InputWrapper {
        @InvocableVariable(required=true)
        public Id leadId;

        @InvocableVariable(required=true)
        public String chosenValues; // Semicolon-separated string from Flow
    }

    @InvocableMethod(label='Update Lead Chemistry Field'
                     description='Updates the Interested_Chemistry__c multi-picklist field on Lead based on user selection from Flow')
    public static void updateLeadChemistry(List<InputWrapper> inputs) {
        if (inputs == null || inputs.isEmpty()) return;

        Set<Id> leadIds = new Set<Id>();
        Map<Id, String> selectedMap = new Map<Id, String>();

        for (InputWrapper input : inputs) {
            if (input.leadId != null) {
                leadIds.add(input.leadId);
                selectedMap.put(input.leadId, input.chosenValues);
            }
        }

        if (leadIds.isEmpty()) return;

        List<Lead> leadsToUpdate = [
            SELECT Id, DRC_NBC_Interested_Chemistry__c
            FROM Lead
            WHERE Id IN :leadIds
        ];

        for (Lead ld : leadsToUpdate) {
            String selectedFromFlow = selectedMap.get(ld.Id);

            // Convert semicolon string to clean Set
            Set<String> selectedSet = new Set<String>();
            if (!String.isBlank(selectedFromFlow)) {
                for (String val : selectedFromFlow.split(';')) {
                    if (!String.isBlank(val)) selectedSet.add(val.trim());
                }
            }

            // Final formatted value to store
            ld.DRC_NBC_Interested_Chemistry__c = String.join(new List<String>(selectedSet), ';');
        }

        if (!leadsToUpdate.isEmpty()) {
            try {
                update leadsToUpdate;
            } catch (Exception e) {
                System.debug(' Error updating Lead: ' + e.getMessage());
            }
        }
    }
}