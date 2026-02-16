public class DRC_NBC_OrderRejectionHelper {
    @AuraEnabled(cacheable=true)
    public static List<String> getRejectionReasons() {
        List<String> picklistValues = new List<String>();
        Schema.DescribeFieldResult fieldResult = Order.DRC_NBC_Rejection_Reason1__c.getDescribe();
        List<Schema.PicklistEntry> values = fieldResult.getPicklistValues();

        for (Schema.PicklistEntry entry : values) {
            if (entry.isActive()) {
                picklistValues.add(entry.getLabel());
            }
        }
        return picklistValues;
    }

}