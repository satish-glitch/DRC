/**
 * @class CaseTriggerHandler
 * This class contains the handler logic for the CaseTrigger. Specifically, it implements
 * a validation rule that prevents a Case from being closed if the custom checkbox field 
 * `DRC_NBC_CAPA_File_Uploaded__c` is checked (true) but no file has been uploaded 
 * to the Case via the standard Files related list (ContentDocumentLink).
 *
 * @author Satish Yadav
 * @date   2025-09-16
 */


public class CaseTriggerHandler {
    public static void validateFilesBeforeCaseClose(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        Set<Id> caseIdsToCheck = new Set<Id>();
        for (Case c : newCases) {
            Case oldCase = oldCaseMap.get(c.Id);
            if ( c.DRC_NBC_CAPA_File_Uploaded__c == true && c.Status == 'Closed' && oldCase.Status != 'Closed' ) {
                caseIdsToCheck.add(c.Id);
            }
        }

        if (caseIdsToCheck.isEmpty()) return;
        Map<Id, Integer> caseToFileCount = new Map<Id, Integer>();
        for (ContentDocumentLink cdl : [SELECT LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId IN :caseIdsToCheck ]) {
            Id caseId = cdl.LinkedEntityId;
            if (!caseToFileCount.containsKey(caseId)) {
                caseToFileCount.put(caseId, 1);
            } else {
                caseToFileCount.put(caseId, caseToFileCount.get(caseId) + 1);
            }
        }
        for (Case c : newCases) {
            if (
                caseIdsToCheck.contains(c.Id) &&
                (!caseToFileCount.containsKey(c.Id) || caseToFileCount.get(c.Id) == 0)
            ) {
                c.addError('You must upload at least one file before closing the case when CAFA is checked.');
            }
        }
    }
}