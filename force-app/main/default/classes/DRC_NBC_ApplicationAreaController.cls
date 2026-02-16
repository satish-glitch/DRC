/**
* @File Name : DRC_NBC_ApplicationAreaController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : November 18, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 18, 2025 |   | Initial Version
**/

public class DRC_NBC_ApplicationAreaController {
	@AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getApplicationAreaValues() {

        List<Map<String, String>> options = new List<Map<String, String>>();

        // Describe Multi-Select Picklist Field
        Schema.DescribeFieldResult fieldResult =
            Lead.DRC_NBC_Application_Area__c.getDescribe();

        // Extract picklist values
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            options.add(new Map<String, String>{
                'label' => entry.getLabel(),
                'value' => entry.getValue()
            });
        }

        return options;
    }
}