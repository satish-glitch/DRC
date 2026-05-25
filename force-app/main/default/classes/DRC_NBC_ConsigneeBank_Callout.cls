public class DRC_NBC_ConsigneeBank_Callout {
    
    // ✅ Removed LIMIT 1 — fetch ALL bank records for the Account
    public static List<DRC_NBC_Consignee_Bank_Details__c> getBankDetails(Id accountId) {
        return [
            SELECT Id,
            Account__c,
            DRC_NBC_Consignee_Bank_Name__c,
            Name,
            DRC_NBC_Primary_Bank__c,
            DRC_NBC_Consignee_Bank_Account_Number__c,
            DRC_NBC_Consignee_Bank_IFSC_Code__c,
            DRC_NBC_Consignee_Bank_Full_Address__c,
            DRC_NBC_Consignee_Bank_Address__City__s,
            DRC_NBC_Consignee_Bank_Address__PostalCode__s,
            DRC_NBC_Consignee_Bank_Address__CountryCode__s,
            DRC_NBC_Consignee_Bank_Address__Street__s,
            DRC_NBC_Consignee_Bank_Address__StateCode__s
            FROM DRC_NBC_Consignee_Bank_Details__c
            WHERE Account__c = :accountId
            AND DRC_NBC_Primary_Bank__c = true
        ];
    }
    
    // Fetch Account — only Customer Number needed for payload
    public static Account getAccountDetails(Id accountId) {
        return [
            SELECT Id,
            DRC_NBC_Customer_Number__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }
    
    // Map single Consignee Bank Detail record to payload
    public static DRC_NBC_Integration_Payload.ConsigneeBankPayload mapToPayload(
        Account acc,
        DRC_NBC_Consignee_Bank_Details__c bankDetail) {
            
            DRC_NBC_Integration_Payload.ConsigneeBankPayload payload =
                new DRC_NBC_Integration_Payload.ConsigneeBankPayload();
            
            payload.Customer_No     = acc.DRC_NBC_Customer_Number__c;
            payload.Code            = bankDetail.Name;
            payload.Name            = String.isNotBlank(bankDetail.DRC_NBC_Consignee_Bank_Name__c)
                ? bankDetail.DRC_NBC_Consignee_Bank_Name__c : '';
            payload.Bank_Account_No = String.isNotBlank(bankDetail.DRC_NBC_Consignee_Bank_Account_Number__c)
                ? bankDetail.DRC_NBC_Consignee_Bank_Account_Number__c : '';
            payload.City            = String.isNotBlank(bankDetail.DRC_NBC_Consignee_Bank_Address__City__s)
                ? bankDetail.DRC_NBC_Consignee_Bank_Address__City__s : '';
            payload.Post_Code       = String.isNotBlank(bankDetail.DRC_NBC_Consignee_Bank_Address__PostalCode__s)
                ? bankDetail.DRC_NBC_Consignee_Bank_Address__PostalCode__s : '';
            
            if (String.isNotBlank(bankDetail.DRC_NBC_Consignee_Bank_Address__CountryCode__s)) {
                payload.Country_Region_Code =
                    bankDetail.DRC_NBC_Consignee_Bank_Address__CountryCode__s == 'IN'
                    ? 'IND'
                    : bankDetail.DRC_NBC_Consignee_Bank_Address__CountryCode__s;
            } else {
                payload.Country_Region_Code = '';
            }
            
            // Formula full address — split at 99 chars into Address and Address_2
            String fullAddress = bankDetail.DRC_NBC_Consignee_Bank_Full_Address__c;
            if (String.isNotBlank(fullAddress)) {
                if (fullAddress.length() > 99) {
                    payload.Address   = fullAddress.substring(0, 99);
                    payload.Address_2 = fullAddress.substring(99);
                } else {
                    payload.Address   = fullAddress;
                    payload.Address_2 = '';
                }
            } else {
                payload.Address   = '';
                payload.Address_2 = '';
            }
            
            payload.Bank_Branch_No = '';
            payload.Contact        = '';
            payload.E_Mail         = '';
            payload.Phone_No       = '';
            payload.SWIFT_Code     = String.isNotBlank(bankDetail.DRC_NBC_Consignee_Bank_IFSC_Code__c)
                ? bankDetail.DRC_NBC_Consignee_Bank_IFSC_Code__c : '';
            
            return payload;
        }
    
    // Get endpoint from custom setting
    public static String getEndpoint() {
        return DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_Consignee_Bank_Endpoint__c;
    }
}