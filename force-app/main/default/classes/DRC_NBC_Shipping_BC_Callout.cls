public class DRC_NBC_Shipping_BC_Callout implements Queueable, Database.AllowsCallouts {
    
    private Id accountId;
    private Id orderId;
    
    public DRC_NBC_Shipping_BC_Callout(Id accountId, Id orderId) {
        this.accountId = accountId;
        this.orderId = orderId;
    }
    
    public void execute(QueueableContext context) {
        try {
            // This queueable is now simplified - only for standalone shipping callouts
            // Order processing handles shipping callout internally
            String result = processShipping(accountId, orderId);
            System.debug('Shipping BC Result → ' + result);
            
        } catch (Exception e) {
            logError(e.getMessage());
        }
    }
    
    /**
* Static method to process shipping callout
* Can be called from Queueable or directly
*/
    public static String processShipping(Id accountId, Id orderId) {
        try {
            DRC_NBC_Integration_Payload.ShipToPayload payload = 
                getShippingPayload(accountId, orderId);
            
            if (payload == null) {
                return 'FAILURE: No shipping addresses found.'; 
            }
            
            String jsonBody = JSON.serialize(payload, true);
            String endpoint = DRC_NBC_BC_Callout_Utility.getConfig()
                .DRC_NBC_Shipping_Address_Endpoint__c;
            DRC_NBC_Shipping_BC_Integration integration = new DRC_NBC_Shipping_BC_Integration(
                endpoint, 'POST', jsonBody, accountId
            );
            HttpResponse response = integration.executeAndReturnResponse();
            
            if (response != null && (response.getStatusCode() == 200 || 
                                     response.getStatusCode() == 201)) {
                                         return 'SUCCESS: HTTP ' + response.getStatusCode();
                                     } else {
                                         return 'FAILURE: HTTP ' + (response != null ? 
                                                                    String.valueOf(response.getStatusCode()) : 'NO_RESPONSE');
                                     }
            
        } catch (Exception e) {
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Shipping_BC_Callout',
                null, null, 'Static Method',
                e.getMessage(), null, e.getStackTraceString(),
                'Error', accountId
            );
            return 'FAILURE: ' + e.getMessage();
        }
    }
    
    /**
* Get shipping payload for callout
* Public static so it can be called from Order BC Callout
*/
    public static DRC_NBC_Integration_Payload.ShipToPayload getShippingPayload(
        Id accountId, Id orderId
    ) {
        Order ord = [
            SELECT Id, Name, DRC_NBC_Shipping_Address__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        
        DRC_NBC_Integration_Payload.ShipToPayload payload = null;
        
        List<Account> accounts = [
            SELECT Id, Name, Phone, DRC_NBC_Customer_Number__c,
            (
                SELECT Id, DRC_NBC_Address__Street__s, DRC_NBC_Address__City__s,
                DRC_NBC_Address__CountryCode__s, DRC_NBC_Address__PostalCode__s,
                DRC_NBC_GST_Number__c, DRC_NBC_Address__StateCode__s, DRC_Inco_Term__c,
                DRC_NBC_Warehouse__c, DRC_NBC_Type__c, DRC_NBC_Ship_To_Code__c, DRC_Shipping_Gst_Customer_Type__c,
                DRC_NBC_Order__c
                FROM Address__r
                WHERE DRC_NBC_Type__c = 'Shipping'
                AND Id = :ord.DRC_NBC_Shipping_Address__c
                ORDER BY CreatedDate ASC
                LIMIT 1
            )
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        
        if (accounts.isEmpty() || accounts[0].Address__r == null || 
            accounts[0].Address__r.isEmpty()) {
                System.debug('No shipping address found for Account: ' + accountId + 
                             ', Order: ' + orderId);
                return null;
            }
        
        Account acc = accounts[0];
        DRC_NBC_Addresses__c addr = acc.Address__r[0];
        
        payload = new DRC_NBC_Integration_Payload.ShipToPayload();
        payload.CustomerNo = acc.DRC_NBC_Customer_Number__c;
        payload.ShiptoCode = addr.DRC_NBC_Ship_To_Code__c;
        /*If (payload.ShiptoCode == null) {
AggregateResult result = [
SELECT MAX(DRC_NBC_Ship_To_Code__c) maxSeq
FROM DRC_NBC_Addresses__c
WHERE DRC_NBC_Type__c = 'Shipping'
];

String maxSeqStr = (String) result.get('maxSeq');
Integer currentMax = String.isBlank(maxSeqStr) ? 0 : Integer.valueOf(maxSeqStr);
currentMax++;

payload.ShiptoCode = String.valueOf(currentMax);
System.debug('Shipto code >>> '+  currentMax);

}*/
        System.debug('Shipto code >>> '+  payload.ShiptoCode);
        payload.Name = acc.Name;
        
        // Address split (100 char limit per field)
        String street = addr.DRC_NBC_Address__Street__s;
        if (!String.isBlank(street)) {
            if (street.length() > 100) {
                payload.ShippingAddress  = street.substring(0, 100);
                String streetRemainder   = street.substring(100);
                payload.ShippingAddress2 = streetRemainder.length() > 100 
                    ? streetRemainder.substring(0, 100) 
                    : streetRemainder;
            } else {
                payload.ShippingAddress  = street;
                payload.ShippingAddress2 = addr.DRC_NBC_Address__City__s;
            }
        } else {
            payload.ShippingAddress = '';
            payload.ShippingAddress2 = '';
        }
        
        payload.ShippingCity = addr.DRC_NBC_Address__City__s;
        payload.State = addr.DRC_NBC_Address__StateCode__s;
        payload.ShippingPostCode = addr.DRC_NBC_Address__PostalCode__s;
        if (addr.DRC_NBC_Address__CountryCode__s == 'IN'){
            payload.ShippingCountry = 'IND';
        }
        else{
            payload.ShippingCountry = addr.DRC_NBC_Address__CountryCode__s;
        }
        
        payload.ShippingPhoneNo = acc.Phone;
        payload.ShippingGSTRegistrationNo = addr.DRC_NBC_GST_Number__c;
        payload.Ship_to_GST_Customer_Type  = addr.DRC_Shipping_Gst_Customer_Type__c;
        
        // Warehouse metadata lookup
        String warehouseLabel = addr.DRC_NBC_Warehouse__c;
        String locationType = 'Warehouse Location';
        
        List<Warehouse_Location_Code__mdt> metaList = [
            SELECT MasterLabel, DRC_NBC_Code__c, DRC_NBC_Type__c
            FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel = :warehouseLabel 
            AND DRC_NBC_Type__c = :locationType
            LIMIT 1
        ];
        
        if (!metaList.isEmpty()) {
            payload.Location_Code = metaList[0].DRC_NBC_Code__c;
        } else {
            System.debug('No metadata found for Warehouse: ' + warehouseLabel);
            payload.Location_Code = null;
        }
        
        // Fetch Inco Terms Metadata
        Warehouse_Location_Code__mdt incoTermsMeta;
        String incoTermsLabel = addr.DRC_Inco_Term__c;
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
        payload.Shipment_Method_Code = !incoTermsList.isEmpty()
            ? incoTermsList[0].DRC_NBC_Code__c
            : null;
        return payload;
    }
    
    private void logError(String errorMsg) {
        DRC_NBC_API_Log_Handler.createApiLog(
            'DRC_NBC_Shipping_BC_Callout',
            null, null, 'Queueable',
            errorMsg, null, null,
            'Error', accountId
        );
    }
}