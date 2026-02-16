public class DRC_NBC_Account_BC_Callout implements Database.AllowsCallouts {
    
    public static String executeCallout(Id OrderId) {
         Id accountId;
        // This method is now just a wrapper for the queueable
        if (OrderId == null) {
            return 'FAILURE: Order Id is required';
        }
        
        try {
            Order orderRecord = [
                SELECT Id, AccountId
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
            accountId = orderRecord.AccountId;
            Account acc = getAccountDetails(accountId);
            System.enqueueJob(new DRC_NBC_Account_BC_Callout_Queueable(orderId));
            return 'Account Sync SUCCESS';
        } catch (Exception e) {
            return 'FAILURE: ' + e.getMessage();
        }
    }
    
    // Make this public so Queueable can access it
    public static Account getAccountDetails(Id accId) {
        return [
            SELECT Id, Name, DRC_NBC_PAN_No__c, DRC_NBC_Payment_Term_Code__c, DRC_NBC_Customer_Number__c,DRC_NBC_BC_Approval_Status__c,
            CurrencyIsoCode, Phone, AccountNumber, DRC_NBC_Account_Email_Email__c,
            BillingCity, BillingCountry, BillingCountryCode, BillingPostalCode,
            BillingState, BillingStateCode, BillingStreet, DRC_NBC_GST_Number__c,
            (SELECT Id, DRC_NBC_Address__Street__s, DRC_NBC_Address__City__s,
             DRC_NBC_Address__StateCode__s, DRC_NBC_Address__PostalCode__s,
             DRC_NBC_Address__CountryCode__s, DRC_NBC_GST_Number__c, DRC_NBC_Type__c
             FROM Address__r)
            FROM Account
            WHERE Id = :accId
            LIMIT 1 
        ];
    }
    
    // Make this public so Queueable can access it
    public static DRC_NBC_Integration_Payload.CustomerPayload mapAccountToPayload(Account acc) {
        DRC_NBC_Integration_Payload.CustomerPayload payload = new DRC_NBC_Integration_Payload.CustomerPayload();
        payload.No = acc.DRC_NBC_Customer_Number__c;
        payload.Name = acc.Name;
        payload.Currency_Code = acc.CurrencyIsoCode;
        payload.P_A_N_No = acc.DRC_NBC_PAN_No__c;
        payload.GST_Registration_No = acc.DRC_NBC_GST_Number__c;
        payload.Phone_No = acc.Phone;
        payload.Mobile_Phone_No = '';
        payload.E_Mail = acc.DRC_NBC_Account_Email_Email__c;
        payload.Payment_Terms_Code = acc.DRC_NBC_Payment_Term_Code__c;
        payload.Address = acc.BillingStreet;
        payload.Address_2 = '';
        payload.City = acc.BillingCity;
        payload.State_Code = acc.BillingStateCode;
        payload.Post_Code = acc.BillingPostalCode;
        payload.Country_Region_Code = 'IND';
        payload.Shipment_Method_Code = '';
        payload.Approval_Status = 'Open';
        return payload;
    }
    
    @future
    public static void updatePostedStatus(Id accountId) {
        try {
            Account acc = [
                SELECT Id, DRC_NBC_Posted_To_bc__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            acc.DRC_NBC_Posted_To_bc__c = true;
            update acc;
        } catch (Exception ex) {
            System.debug('Future method failed to update Order: ' + ex.getMessage());
        }
    }
}