public class DRC_NBC_Order_BC_Callout implements Database.AllowsCallouts {
    
    public Id orderId;
    //public Id accountId;
    
    /* public DRC_NBC_Order_BC_Callout(Id orderId) {
this.orderId = orderId;
}*/
    
    public static String executeCallout(Id orderId) {
        try {
            Order order = getOrderDetails(orderId);
            Id accountId = order.AccountId;
            //  Check if already synced
            if (order.DRC_NBC_Order_Sync_To_BC__c) {
                Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(orderId));
                System.debug('Order BC Result → SKIPPED: Order already synced. Order Product callout enqueued.');
                return 'Order BC Result → SKIPPED: Order already synced. Order Product callout enqueued.';
            }
            
            List<DRC_NBC_Addresses__c> addresses = new List<DRC_NBC_Addresses__c>();
            if (order.DRC_NBC_Shipping_Address__c != null) {
                addresses = [
                    SELECT Id, DRC_NBC_Ship_To_Code__c
                    FROM DRC_NBC_Addresses__c
                    WHERE Id = :order.DRC_NBC_Shipping_Address__c
                    AND DRC_NBC_Type__c = 'Shipping'
                    AND DRC_NBC_Order__c = :orderId
                    ORDER BY CreatedDate ASC
                    LIMIT 1
                ];
            }
            
            Boolean needsShipToCode = !addresses.isEmpty() && String.isBlank(addresses[0].DRC_NBC_Ship_To_Code__c);
            Boolean needsOrderNumber = String.isBlank(order.DRC_NBC_Cust_Order_Number__c);
            
            // If ANY DML is needed, exit and chain to DML handler
            if (needsShipToCode || needsOrderNumber) {
                System.debug('DML needed - Ship-To Code: ' + needsShipToCode + ', Order Number: ' + needsOrderNumber);
                System.enqueueJob(new DRC_NBC_Order_DML_Handler(orderId, needsShipToCode, needsOrderNumber));
                System.debug('Order BC Result → Chained to DML handler for generation(s)');
                return 'Order BC Result → Chained to DML handler for generation(s)';
            }
            
            System.debug('No DML needed - chaining to Callout Handler');
            System.enqueueJob(new DRC_NBC_Order_Callout_Handler(orderId));
            return 'Order BC Result → Callout enqueued';
            
        } catch (Exception e) {
            //logError(e.getMessage() + ' | Stack: ' + e.getStackTraceString());
            return 'ERROR: ' + e.getMessage();
        }
    }
    
    
    public static Order getOrderDetails(Id orderId) {
        return [
            SELECT 
            	Id, 
                Name, 
                AccountId,
                EffectiveDate,
                OrderNumber, 
                PoDate,
                PoNumber,
                DRC_NBC_Location_Code__c,
                ShipToContactId,
                DRC_NBC_Cust_Order_Number__c, 
                Status,
                DRC_NBC_Payment_Terms__c,
                RecordType.Name,
                ShippingCountryCode, 
                DRC_NBC_Inco_Terms__c,
                CreatedDate,
                Account.Name,
                ShippingCity, 
                ShippingCountry,
                DRC_NBC_Order_Sync_To_BC__c,
                ShippingPostalCode, 
                ShippingStreet, 
                DRC_NBC_Shipping_Address__c,
                Account.DRC_NBC_Posted_To_BC__c, 
                Account.DRC_NBC_Customer_Number__c,
                DRC_NBC_Grand_Total__c,
                Account.BillingStreet,
                Account.BillingPostalCode,
                Account.DRC_NBC_BC_Approval_Status__c,
                Account.BillingCity, 
                CurrencyIsoCode,
                DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c
            FROM
            	Order
            WHERE 
            	Id = :orderId
            LIMIT 1
        ];
    }
    
    public static DRC_NBC_Integration_Payload.OrderPayload mapOrderToBCPayload(Order ord) {
        // Fetch Warehouse Location Metadata
        Warehouse_Location_Code__mdt warehouseMeta;
        String warehouseLabel = ord.DRC_NBC_Location_Code__c;
        String locationType = 'Warehouse Location';
        
        List<Warehouse_Location_Code__mdt> metaList = [
            SELECT MasterLabel, DRC_NBC_Code__c, DRC_NBC_Type__c 
            FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel = :warehouseLabel 
            AND DRC_NBC_Type__c = :locationType
            LIMIT 1
        ];
        
        if (!metaList.isEmpty()) {
            warehouseMeta = metaList[0];
            System.debug('Fetched Metadata Code: ' + warehouseMeta.DRC_NBC_Code__c);
        } else {
            System.debug('No matching metadata found for Label: ' + warehouseLabel);
        }
        
        // Fetch Inco Terms Metadata
        Warehouse_Location_Code__mdt incoTermsMeta;
        String incoTermsLabel = ord.DRC_NBC_Inco_Terms__c;
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
        
        Boolean sampleSales = (ord.RecordType != null && ord.RecordType.Name == 'Sample_Order');
        
        Boolean SalesforceOrderCreated = false;
        
        DRC_NBC_Integration_Payload.OrderPayload payload = new DRC_NBC_Integration_Payload.OrderPayload();
        payload.Document_Type = 'Order';
        payload.No = String.isNotBlank(ord.DRC_NBC_Cust_Order_Number__c) ? 
            ord.DRC_NBC_Cust_Order_Number__c : '';
        payload.Sell_to_Customer_No = ord.Account.DRC_NBC_Customer_Number__c;
        payload.Sell_to_Customer_Name = ord.Account.Name;
        payload.Sell_to_Address = String.isNotBlank(ord.Account.BillingStreet) ? ord.Account.BillingStreet : '';
        payload.Sell_to_Address_2 = '';
        payload.Sell_to_Post_Code = String.isNotBlank(ord.Account.BillingPostalCode) ? 
            ord.Account.BillingPostalCode : '';
        payload.Sell_to_City = String.isNotBlank(ord.Account.BillingCity) ? ord.Account.BillingCity : '';
        payload.Order_Date = ord.EffectiveDate != null ? String.valueOf(ord.EffectiveDate) : '';
        payload.Status = 'Open';
        payload.Sample_Sales = sampleSales;
        payload.Payment_Terms_Code = String.isNotBlank(ord.DRC_NBC_Payment_Terms__c) ? 
            ord.DRC_NBC_Payment_Terms__c : '';
        /*   payload.Ship_to_GST_Customer_Type = '';
payload.Ship_to_GST_Reg_No = '';*/
        payload.Shipment_Method_Code = (incoTermsMeta != null && 
                                        String.isNotBlank(incoTermsMeta.DRC_NBC_Code__c)) ? 
            incoTermsMeta.DRC_NBC_Code__c : '';
        payload.Location_Code = (warehouseMeta != null && 
                                 String.isNotBlank(warehouseMeta.DRC_NBC_Code__c)) ? 
            warehouseMeta.DRC_NBC_Code__c : '';           
        payload.Salesperson_Code = ord.ShipToContactId;
        payload.Salesforce_So_No = String.valueOf(ord.Id);
        payload.External_Document_No = String.isNotBlank(ord.PoNumber) ? 
            String.valueOf(ord.PoNumber) : '';
        payload.Salesforce_Order_Amount = ord.DRC_NBC_Grand_Total__c != null
            ?ord.DRC_NBC_Grand_Total__c
            : 0.00;
        payload.Salesforce_Order_Created = SalesforceOrderCreated;
        payload.Currency_Code = Ord.CurrencyIsoCode;
        
        
        // Initialize shipping fields
        payload.Ship_to_Code = '';
        payload.Ship_to_Name = '';
        payload.Ship_to_Name_2 = '';
        payload.Ship_to_Address = '';
        payload.Ship_to_Address_2 = '';
        payload.Ship_to_Post_Code = '';
        payload.Ship_to_Country_Region_Code = '';
        
        // Populate shipping address if available
        if (ord.DRC_NBC_Shipping_Address__c != null) {
            List<DRC_NBC_Addresses__c> addresses = [
                SELECT DRC_NBC_Address__Street__s, DRC_NBC_Address__City__s, 
                DRC_NBC_Address__PostalCode__s, DRC_NBC_Address__CountryCode__s, 
                DRC_NBC_Address__StateCode__s, DRC_NBC_GST_Number__c, 
                DRC_NBC_Ship_To_Code__c, Name
                FROM DRC_NBC_Addresses__c
                WHERE Id = :ord.DRC_NBC_Shipping_Address__c
                AND DRC_NBC_Order__c = :ord.Id
                ORDER BY CreatedDate ASC
                LIMIT 1
            ];
            
            if (!addresses.isEmpty()) {
                DRC_NBC_Addresses__c address = addresses[0];
                
                payload.Ship_to_Code = String.isNotBlank(address.DRC_NBC_Ship_To_Code__c) ? 
                    address.DRC_NBC_Ship_To_Code__c : '';
                payload.Ship_to_Name = ord.Account != null && String.isNotBlank(ord.Account.Name) ? 
                    ord.Account.Name : '';
                payload.Ship_to_Name_2 = '';
                
                // Compose full address
                String fullAddress = '';
                if (String.isNotBlank(address.DRC_NBC_Address__Street__s))
                    fullAddress += address.DRC_NBC_Address__Street__s + ', ';
                if (String.isNotBlank(address.DRC_NBC_Address__City__s))
                    fullAddress += address.DRC_NBC_Address__City__s + ', ';
                if (String.isNotBlank(address.DRC_NBC_Address__StateCode__s))
                    fullAddress += address.DRC_NBC_Address__StateCode__s + ', ';
                if (String.isNotBlank(address.DRC_NBC_Address__PostalCode__s))
                    fullAddress += address.DRC_NBC_Address__PostalCode__s + ', ';
                if (String.isNotBlank(address.DRC_NBC_Address__CountryCode__s))
                    fullAddress += address.DRC_NBC_Address__CountryCode__s;
                
                fullAddress = fullAddress.trim();
                if (fullAddress.endsWith(',')) {
                    fullAddress = fullAddress.substring(0, fullAddress.length() - 1);
                }
                
                // Split address into two fields (100 char limit each)
                if (fullAddress.length() > 99) {
                    payload.Ship_to_Address = fullAddress.substring(0, 99);
                    payload.Ship_to_Address_2 = fullAddress.length() > 149 ? 
                        fullAddress.substring(99, 149) : fullAddress.substring(99);
                } else {
                    payload.Ship_to_Address = fullAddress;
                    payload.Ship_to_Address_2 = '';
                }
                
                payload.Ship_to_Post_Code = String.isNotBlank(address.DRC_NBC_Address__PostalCode__s) ? 
                    address.DRC_NBC_Address__PostalCode__s : '';
                String countryCode = address.DRC_NBC_Address__CountryCode__s != null 
                    ? address.DRC_NBC_Address__CountryCode__s.trim().toUpperCase()
                    : '';
                
                if (countryCode == 'IN' || countryCode == 'IND' || countryCode == 'INDIA') {
                    payload.Ship_to_Country_Region_Code = 'IND';
                } else {
                    payload.Ship_to_Country_Region_Code = countryCode;
                }
            }
        }
        
        return payload;
    }
    
    private void logError(String errorMsg) {
        DRC_NBC_API_Log_Handler.createApiLog(
            'DRC_NBC_Order_BC_Callout',
            null, null, 'Queueable',
            errorMsg, null, null,
            'Error', orderId
        );
    }
}