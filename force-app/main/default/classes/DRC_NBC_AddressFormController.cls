/**
* @File Name : DRC_NBC_AddressFormController .cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : November 27, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 27, 2025 |   | Initial Version
**/

public class DRC_NBC_AddressFormController  {
	

    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValues() {
        Map<String, List<String>> result = new Map<String, List<String>>();
        
        result.put('typeOptions', getValues('DRC_NBC_Addresses__c', 'DRC_NBC_Type__c'));
        result.put('countryOptions', getValues('DRC_NBC_Addresses__c', 'DRC_NBC_Address__CountryCode__s'));
        result.put('stateOptions', getValues('DRC_NBC_Addresses__c', 'DRC_NBC_Address__StateCode__s'));

        return result;
    }

    private static List<String> getValues(String objApi, String fieldApi) {

    Schema.DescribeFieldResult d = 
        Schema.getGlobalDescribe()
              .get(objApi)         // object e.g. DRC_NBC_Addresses__c
              .getDescribe()       
              .fields.getMap()
              .get(fieldApi)       // field e.g. Country__c
              .getDescribe();

    List<String> values = new List<String>();
    for (Schema.PicklistEntry p : d.getPicklistValues()) {
        values.add(p.getValue());
    }
    return values;
}


    @AuraEnabled
    public static Id createAddress(DRC_NBC_Addresses__c addr) {
        insert addr;
        return addr.Id;
    }

}