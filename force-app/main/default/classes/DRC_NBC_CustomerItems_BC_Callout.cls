public class DRC_NBC_CustomerItems_BC_Callout {
    
    // Fetch all restricted products for the account
    public static List<DRC_NBC_Restricted_Product__c> getRestrictedProducts(Id accountId) {
        return [
            SELECT Id,
            DRC_NBC_Customer__c,
            Name,
            DRC_NBC_Product__c,
            DRC_NBC_Product__r.Name,
            DRC_NBC_Product__r.DRC_NBC_FG_Code__c,
            DRC_NBC_Customer_s_Product_code__c
            FROM DRC_NBC_Restricted_Product__c
            WHERE DRC_NBC_Customer__c = :accountId
        ];
    }
    
    // Map a single restricted product record to payload
    public static DRC_NBC_Integration_Payload.CustomerItemPayload mapToPayload(
        DRC_NBC_Restricted_Product__c rp,
        String customerNumber) {
            
            DRC_NBC_Integration_Payload.CustomerItemPayload payload =
                new DRC_NBC_Integration_Payload.CustomerItemPayload();
            
            payload.Cust_No            = customerNumber;
            payload.Item_No            = rp.DRC_NBC_Product__r.DRC_NBC_FG_Code__c;
            //   payload.Item_Description   = rp.DRC_NBC_Product__r.Name;
            payload.UOM                = 'KGS';
            payload.Unit_Price         = 0;
            payload.Quantity_Month     = 0;
            payload.Amount             = 0;
            payload.Remarks            = rp.DRC_NBC_Customer_s_Product_code__c;
            
            return payload;
        }
    
    // Get the custom setting / named credential config
    // Uses the same utility as the Account callout for consistency
    public static String getEndpoint() {
        return DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_Customer_Items_Endpoint__c;
    }
}