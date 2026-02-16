/**
* @File Name : DRC_NBC_BC_Callout_Utility.cls
* @Description : Utility class for handling DRC NBC Business Central API callouts using Named Credentials.
* @Author : Satish
* @Last Modified On : November 12, 2025
**/

public class DRC_NBC_BC_Callout_Utility {
    
    /**
* Returns the integration configuration (custom metadata).
*/
    /*public static DRC_NBC_BC_Integration__c getConfig() {
if (isSandbox()) {
return DRC_NBC_BC_Integration__c.getInstance(System.label.DRC_NBC_Sandbox);
} else {
return DRC_NBC_BC_Integration__c.getInstance(System.label.DRC_NBC_Production);
}
}*/
    
    public static DRC_NBC_BC_Integration__c getConfig() {
        String targetEnv = isSandbox() ? System.label.DRC_NBC_Sandbox : System.label.DRC_NBC_Production;
        
        DRC_NBC_BC_Integration__c setting = [
            SELECT Name__c, DRC_NBC_Comapny_Name__c,DRC_NBC_Endpoint__c,
            	DRC_NBC_SendOrderEndpoint__c, DRC_NBC_Shipping_Address_Endpoint__c,
            	DRC_NBC_Token_Generated_Time__c, DRC_NBC_SendOrderLineEndpoint__c, DRC_NBC_SalesPerson_Code__c
            FROM DRC_NBC_BC_Integration__c
            WHERE Name__c = :targetEnv
            LIMIT 1
        ];
        
        return setting;
    }
    
    
    /**
* Builds the full endpoint URL using Named Credentials.
*/
    public static String getFullEndpoint(String endpointPath) {
        DRC_NBC_BC_Integration__c config = getConfig();
        String companyName = config.DRC_NBC_Comapny_Name__c;
        
        // Wrap company name in single quotes, then URL encode the whole thing
        String quotedCompanyName = '\'' + companyName + '\'';
        String encodedCompanyName = EncodingUtil.urlEncode(quotedCompanyName, 'UTF-8').replace('+', '%20');
        
        return 'callout:DRC_NBC_BC_Account_Integration/Company(' + encodedCompanyName + ')/' + endpointPath;
        
        
    }
    
     public static String getOrderProductFullEndpoint(String endpointPath) {
        DRC_NBC_BC_Integration__c config = getConfig();
       /* String companyName = config.DRC_NBC_Comapny_Name__c;
        
        // Wrap company name in single quotes, then URL encode the whole thing
        String quotedCompanyName = '\'' + companyName + '\'';
        String encodedCompanyName = EncodingUtil.urlEncode(quotedCompanyName, 'UTF-8').replace('+', '%20');*/
        
        return 'callout:DRC_NBC_BC_Account_Integration/' + endpointPath;
        
        
    }
    
    
    /**
* Sets necessary headers for Business Central API.
*/
    public static void prepareRequest(HttpRequest req) {
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
    }
    
    /**
* Checks whether the current org is a Sandbox or Production.
*/
    public static Boolean isSandbox() {
        return [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
    }
    
    /**
* Utility to trim large JSON payloads to avoid exceeding Salesforce log or callout limits.
*/
    public static String trimPayload(String text) {
        if (String.isBlank(text)) return text;
        return (text.length() > 131072) ? text.substring(0, 131072) : text;
    }
    
    public static DRC_NBC_Integration_Payload.BCResponse parseResponse(String responseBody) {
        if (String.isBlank(responseBody)) return null;
        return (DRC_NBC_Integration_Payload.BCResponse)
            JSON.deserialize(responseBody, DRC_NBC_Integration_Payload.BCResponse.class);
    }
    
    public static Boolean isTokenExpired() {
        DRC_NBC_BC_Integration__c credential = getConfig();
        if (credential.DRC_NBC_Token_Generated_Time__c == null) {
            return true;
        }
        Long diffInMinutes = (System.now().getTime() - credential.DRC_NBC_Token_Generated_Time__c.getTime()) / (1000 * 60);
        return diffInMinutes > 29;
    }
}