public class DRC_NBC_Account_BC_Callout implements Database.AllowsCallouts {
    
    public static String executeCallout(Id OrderId) {
        Id accountId;
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
            
            // ✅ Enqueue SalesPersonCode FIRST — it will chain to Account sync after
            System.enqueueJob(new DRC_NBC_SalesPersonCode_Callout(orderId));
            return 'Account Sync SUCCESS';
            
        } catch (Exception e) {
            return 'FAILURE: ' + e.getMessage();
        }
    }
    
    // Make this public so Queueable can access it
    public static Account getAccountDetails(Id accId) {
        return [
            SELECT Id, Name, DRC_NBC_PAN_No__c, Type, Website, DRC_NBC_Credit_Limit__c, Other_Email__c,Description, DRC_NBC_Special_Instructions__c, 
            DRC_NBC_Payment_Term_Code__c, DRC_NBC_Customer_Number__c,DRC_NBC_BC_Approval_Status__c,Industry,
            CurrencyIsoCode, Phone, AccountNumber, DRC_NBC_Account_Email_Email__c, DRC_NBC_Payment_Terms__c,SalesPerson_Code__c,
            BillingCity, BillingCountry, BillingCountryCode, BillingPostalCode, DRC_Inco_Term__c, DRC_Gst_Customer_Type__c,
            BillingState, BillingStateCode, BillingStreet, DRC_NBC_GST_Number__c,DRC_NBC_Transport_Agent__c, 
            (SELECT Id, DRC_NBC_Address__Street__s, DRC_NBC_Address__City__s, 
             DRC_NBC_Address__StateCode__s, DRC_NBC_Address__PostalCode__s, DRC_Inco_Term__c, DRC_Shipping_Gst_Customer_Type__c,
             DRC_NBC_Address__CountryCode__s, DRC_NBC_GST_Number__c, DRC_NBC_Type__c
             FROM Address__r)
            FROM Account
            WHERE Id = :accId
            LIMIT 1 
        ];
    }
    
    // Make this public so Queueable can access it
    public static DRC_NBC_Integration_Payload.CustomerPayload mapAccountToPayload(Account acc) {
        
        // Fetch Inco Terms Metadata
        Warehouse_Location_Code__mdt incoTermsMeta;
        String incoTermsLabel = acc.DRC_Inco_Term__c;
        String termType = 'Inco Terms';
        
        List<Warehouse_Location_Code__mdt> incoTermsList = [
            SELECT MasterLabel, DRC_NBC_Code__c, DRC_NBC_Type__c 
            FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel = :incoTermsLabel 
            AND DRC_NBC_Type__c = :termType
            LIMIT 1
        ];
        
        if (!incoTermsList.isEmpty()) {
            incoTermsMeta = incoTermsList[0];
            System.debug('Fetched Inco Terms Metadata Code: ' + incoTermsMeta.DRC_NBC_Code__c);
        } else {
            System.debug('No matching Inco Terms metadata found for Label: ' + incoTermsLabel);
        }
        List<SalesPerson_Code__mdt> mdtRecords = [
            SELECT MasterLabel, Name__c, Phone__c, Email__c
            FROM SalesPerson_Code__mdt
            WHERE Name__c = :acc.SalesPerson_Code__c
            LIMIT 1
        ];
        SalesPerson_Code__mdt spMdt = mdtRecords.isEmpty() ? null : mdtRecords[0];
        
        
        String transporterCode;
        if (String.isNotBlank(acc.DRC_NBC_Transport_Agent__c)) {
            List<DRC_NBC_Shipping_Agent_Master__mdt> shippingAgentList = [
                SELECT MasterLabel, DRC_NBC_Shipping_Agent_Full_Name__c
                FROM DRC_NBC_Shipping_Agent_Master__mdt
                WHERE DRC_NBC_Shipping_Agent_Full_Name__c = :acc.DRC_NBC_Transport_Agent__c
                LIMIT 1
            ];
            
            if (!shippingAgentList.isEmpty()) {
                transporterCode = shippingAgentList[0].MasterLabel;
            }
        }
        
        DRC_NBC_Integration_Payload.CustomerPayload payload = new DRC_NBC_Integration_Payload.CustomerPayload();
        payload.No = acc.DRC_NBC_Customer_Number__c;
        payload.Name = acc.Name;
        If(acc.CurrencyIsoCode == 'INR') {
            payload.Currency_Code = '';
        }
        else{
            payload.Currency_Code = acc.CurrencyIsoCode;
        }
        payload.P_A_N_No = acc.DRC_NBC_PAN_No__c;
        payload.GST_Registration_No = acc.DRC_NBC_GST_Number__c;
        payload.GST_Customer_Type = acc.DRC_Gst_Customer_Type__c;
        payload.Phone_No = acc.Phone;
        payload.Mobile_Phone_No = '';
        payload.Credit_Limit_LCY = acc.DRC_NBC_Credit_Limit__c != null
            ? Integer.valueOf(acc.DRC_NBC_Credit_Limit__c)
            : 0;
        
        payload.Home_Page = String.isNotBlank(acc.Website)
            ? acc.Website
            : '';
        
        payload.Business_type = String.isNotBlank(acc.Industry)
            ? acc.Industry
            : '';
        payload.Transporter_Code = String.isBlank(transporterCode) 
            ? '' 
            : transporterCode; 
        // payload.Transporter_Code = '';
        
        
        payload.Other_E_Mail = String.isNotBlank(acc.Other_Email__c)
            ? acc.Other_Email__c
            : '';
        payload.Salesperson_Code = (spMdt != null && String.isNotBlank(spMdt.MasterLabel))
            ? spMdt.MasterLabel
            : '';
        payload.E_Mail = acc.DRC_NBC_Account_Email_Email__c;
        payload.Payment_Terms_Code = acc.DRC_NBC_Payment_Terms__c;
        // payload.Payment_Terms_Code = '10 DAYS';
        String billingStreet = acc.BillingStreet;
        
      /*  if (String.isNotBlank(billingStreet)) {
            if (billingStreet.length() > 100) {
                payload.Address = billingStreet.substring(0, 100);
                
                String remainingAddress = billingStreet.substring(100);
                payload.Address_2 = remainingAddress.length() > 100
                    ? remainingAddress.substring(0, 100)
                    : remainingAddress;
            }*/
        if (String.isNotBlank(billingStreet)) {
            if (billingStreet.length() > 100) {
                
                String first100Chars = billingStreet.substring(0, 100);
                Integer commaIndex = first100Chars.lastIndexOf(',');
                
                Integer splitIndex;
                
                if (commaIndex > -1) {
                    // Split after last comma before 100 chars
                    splitIndex = commaIndex + 1;
                } else {
                    // No comma found, split at 100 chars
                    splitIndex = 100;
                }
                
                payload.Address = billingStreet.substring(0, splitIndex).trim();
                
                String remainingAddress = billingStreet.substring(splitIndex).trim();
                
                payload.Address_2 = remainingAddress.length() > 100
                    ? remainingAddress.substring(0, 49)
                    : remainingAddress;
                
            }else {
                payload.Address = billingStreet;
                payload.Address_2 = acc.BillingCity;
            }
        } else {
            payload.Address = '';
            payload.Address_2 = '';
        }
        payload.City = acc.BillingCity;
        payload.State_Code = acc.BillingStateCode;
        payload.Post_Code = acc.BillingPostalCode;
        if (acc.BillingCountryCode == 'IN') {
            payload.Country_Region_Code = 'IND';
        } else {
            payload.Country_Region_Code = acc.BillingCountryCode;
        }
        payload.Shipment_Method_Code = (incoTermsMeta != null && 
                                        String.isNotBlank(incoTermsMeta.DRC_NBC_Code__c)) ? 
            incoTermsMeta.DRC_NBC_Code__c : '';
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