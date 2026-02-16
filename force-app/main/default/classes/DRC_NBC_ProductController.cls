/**
* @File Name : DRC_NBC_ProductController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : September 4, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 4, 2025 |   | Initial Version
**/

public without sharing class DRC_NBC_ProductController {
	/* @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEventProductNames() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<Product2> activeProducts = [
            SELECT
                Id,
                Name
            FROM
                Product2
            WHERE
                IsActive = true
                AND
                DRC_NBC_Is_Restricted__c = false
                AND
                DRC_NBC_Show_On_Event__c = true
            ORDER BY Name
        ];
        for (Product2 p : activeProducts) {
            options.add(new Map<String, String>{
                'label' => p.Name,
                'value' => p.Id
            });
        }
        return options;
    }*/

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEventProductNames() {
        List<Map<String, String>> options = new List<Map<String, String>>();

        // Describe the Lead.DRC_NBC_Interested_Chemistry__c field
        Schema.DescribeFieldResult fieldResult = Lead.DRC_NBC_Interested_Chemistry__c.getDescribe();

        // Get picklist values
        List<Schema.PicklistEntry> picklistValues = fieldResult.getPicklistValues();

        // Add picklist entries to options list
        for (Schema.PicklistEntry entry : picklistValues) {
            options.add(new Map<String, String>{
                'label' => entry.getLabel(),
                'value' => entry.getValue()
            });
        }

        return options;
    }


}