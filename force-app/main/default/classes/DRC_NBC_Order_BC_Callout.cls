public class DRC_NBC_Order_BC_Callout implements Database.AllowsCallouts {
    
    public Id orderId;
    public static String executeCallout(Id orderId) {
        try {
            Order order = getOrderDetails(orderId);
            Id accountId = order.AccountId;
            
            // Step 1: Check if already synced
            if (order.DRC_NBC_Order_Sync_To_BC__c) {
                Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(orderId));
                System.debug('Order BC Result → SKIPPED: Order already synced. Order Product callout enqueued.');
                return 'Order BC Result → SKIPPED: Order already synced. Order Product callout enqueued.';
            }
            
            // Step 2: Check ShipToContact exists in BC
            // if (order.ShipToContactId != null) {
            //     Boolean contactExistsInBC = checkSalespersonInBC(order.ShipToContactId);
            //     System.debug('Contact exists in BC: ' + contactExistsInBC);
            
            //     if (!contactExistsInBC) {
            //         // ✅ Call Synchronously — pass contactId & accountId directly
            //         // No re-query inside SalesPersonCode_Callout
            //         System.debug('Contact not in BC → Creating Synchronously...');
            
            //         String salesPersonResult = DRC_NBC_SalesPerson_Sync_Callout.executeCallout(
            //             order.ShipToContactId,  // ✅ directly from fetched Order
            //             order.AccountId         // ✅ directly from fetched Order
            //         );
            
            //         System.debug('SalesPerson Creation Result → ' + salesPersonResult);
            
            //         if (!salesPersonResult.equals('SUCCESS')) {
            //             // ❌ Contact creation failed → Abort Order sync
            //             System.debug('Contact creation FAILED → Aborting Order sync.');
            //             DRC_NBC_API_Log_Handler.createApiLog(
            //                 'DRC_NBC_Order_BC_Callout',
            //                 orderId, null, 'POST',
            //                 'Salesperson creation failed: ' + salesPersonResult,
            //                 null, null, 'Error', null
            //             );
            //             return 'ERROR: Salesperson creation failed → ' + salesPersonResult;
            //         }
            
            //         // ✅ Contact created successfully → continue Order sync below
            //         System.debug('Contact created in BC → Continuing Order sync...');
            
            //     } else {
            //         // ✅ Contact already exists in BC → continue directly
            //         System.debug('Contact already in BC → Continuing Order sync.');
            //     }
            // }
            
            // Step 3: Fetch Shipping Address
            // ✅ Reaches here in ALL cases:
            //    a) ShipToContactId is null
            //    b) Contact already existed in BC
            //    c) Contact just created synchronously
            List<DRC_NBC_Addresses__c> addresses = new List<DRC_NBC_Addresses__c>();
            if (order.DRC_NBC_Shipping_Address__c != null) {
                addresses = [
                    SELECT Id, DRC_NBC_Ship_To_Code__c
                    FROM DRC_NBC_Addresses__c
                    WHERE Id             = :order.DRC_NBC_Shipping_Address__c
                    AND DRC_NBC_Type__c  = 'Shipping'
                    ORDER BY CreatedDate ASC
                    LIMIT 1
                ];
            }
            
            Boolean needsShipToCode  = !addresses.isEmpty()
                && String.isBlank(addresses[0].DRC_NBC_Ship_To_Code__c);
            Boolean needsOrderNumber = String.isBlank(order.DRC_NBC_Cust_Order_Number__c);
            
            System.debug('needsShipToCode: '  + needsShipToCode
                         + ' | needsOrderNumber: ' + needsOrderNumber);
            
            // Step 4: Route based on what is needed
            if (needsShipToCode || needsOrderNumber) {
                System.debug('DML needed - Ship-To Code: ' + needsShipToCode
                             + ', Order Number: '             + needsOrderNumber);
                System.enqueueJob(
                    new DRC_NBC_Order_DML_Handler(orderId, needsShipToCode, needsOrderNumber)
                );
                System.debug('Order BC Result → Chained to DML handler for generation(s)');
                return 'Order BC Result → Chained to DML handler for generation(s)';
            }
            
            // Step 5: Everything ready → Send Order to BC
            System.debug('No DML needed → Chaining to Callout Handler.');
            System.enqueueJob(new DRC_NBC_Order_Callout_Handler(orderId));
            return 'Order BC Result → Callout enqueued.';
            
        } catch (Exception e) {
            System.debug('Exception in executeCallout: ' + e.getMessage());
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
            DRC_NBC_Warehouse__c,
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
            Is_Domestic_Merchnat__c,
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
            DRC_NBC_SalesPerson_Code__c,
            DRC_NBC_Record_Type_Name__c,
            DRC_NBC_Type__c,
            DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
            DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c,
            DRC_NBC_Transport_Agent__c, 
            DRC_NBC_Shipment_Date__c,
            DRC_NBC_Shipment_Method__c,
            DRC_NBC_Courier_Number__c,
            DRC_NBC_Expected_Delivery_Date__c,
            DRC_NBC_Courier_date__c,
            DRC_NBC_Courier_service__c,
            DRC_NBC_Special_request__c,
            DRC_NBC_Remarks__c,
            NBC_DRC_Dispatch_Date__c,
            DRC_NBC_Country_of_Origin__c,   
            DRC_NBC_Country_of_Final_Destination__c,
            DRC_NBC_Trans_Shipment__c,
            DRC_NBC_Part_Shipment__c,
            DRC_NBC_Port_Of_Discharge__c,
            DRC_NBC_Port_of_Loading__c,
            DRC_NBC_Final_Destination__c,
            DRC_NBC_Vessel_no_Flight_no__c,
            DRC_NBC_Notify_Party__c,
            DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c,
            DRC_NBC_Required_Documents__c,
            DRC_NBC_Final_Dispatch_Date__c,
            DRC_NBC_Select_Bank__c,
            DRC_NBC_Delivery_Terms__c
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
        String warehouseLabel = ord.DRC_NBC_Warehouse__c;
        String locationType = 'Warehouse Location';
        String locationcode  = '';
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
        
        Boolean sampleSales = (ord.RecordType != null && ord.DRC_NBC_Record_Type_Name__c == 'Sample Order');
        
        System.debug('Record type name is Sample >>> '  + sampleSales);
        
        Boolean SalesforceOrderCreated = false;
        
        DRC_NBC_Integration_Payload.OrderPayload payload = new DRC_NBC_Integration_Payload.OrderPayload();
        payload.Document_Type = 'Order';
        payload.No = String.isNotBlank(ord.DRC_NBC_Cust_Order_Number__c) ? ord.DRC_NBC_Cust_Order_Number__c : '';
        payload.Sell_to_Customer_No = ord.Account.DRC_NBC_Customer_Number__c;
        payload.Sell_to_Customer_Name = ord.Account.Name;
        String billingStreet = String.isNotBlank(ord.Account.BillingStreet)
            ? ord.Account.BillingStreet
            : '';
        
     /*   if (billingStreet.length() > 100) {
            payload.Sell_to_Address = billingStreet.substring(0, 100);
            payload.Sell_to_Address_2 = billingStreet.substring(100);
        } else {
            payload.Sell_to_Address = billingStreet;
            payload.Sell_to_Address_2 = '';
        }*/
      /*  if (billingStreet.length() > 100) {
            payload.Sell_to_Address   = billingStreet.substring(0, 100);
            String billRemainder      = billingStreet.substring(100);
            payload.Sell_to_Address_2 = billRemainder.length() > 100 
                ? billRemainder.substring(0, 100) 
                : billRemainder;
        } else {
            payload.Sell_to_Address   = billingStreet;
            payload.Sell_to_Address_2 = ord.Account.BillingCity;
        }*/
        
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
            payload.Sell_to_Address = billingStreet.substring(0, splitIndex).trim();
            String billRemainder = billingStreet.substring(splitIndex).trim();
            payload.Sell_to_Address_2 = billRemainder.length() > 100 
                ? billRemainder.substring(0, 49) 
                : billRemainder;
            
        } else {
            payload.Sell_to_Address   = billingStreet;
            payload.Sell_to_Address_2 = ord.Account.BillingCity;
        }
        payload.Sell_to_Post_Code = String.isNotBlank(ord.Account.BillingPostalCode) ? ord.Account.BillingPostalCode : '';
        payload.Sell_to_City = String.isNotBlank(ord.Account.BillingCity) ? ord.Account.BillingCity : '';
        payload.Order_Date = ord.EffectiveDate != null ? String.valueOf(ord.EffectiveDate) : '';
        payload.Status = 'Open';
        payload.Delivery_Terms = String.isNotBlank(ord.DRC_NBC_Delivery_Terms__c) ? ord.DRC_NBC_Delivery_Terms__c : '';
        payload.Sample_Sales = sampleSales;
        payload.Payment_Terms_Code = String.isNotBlank(ord.DRC_NBC_Payment_Terms__c) ? ord.DRC_NBC_Payment_Terms__c : '';
        //payload.Payment_Terms_Code = '10 Days';
        
        payload.Shipment_Method_Code = (incoTermsMeta != null && 
                                        String.isNotBlank(incoTermsMeta.DRC_NBC_Code__c)) ? 
            incoTermsMeta.DRC_NBC_Code__c : '';
        payload.Location_Code = (warehouseMeta != null && 
                                 String.isNotBlank(warehouseMeta.DRC_NBC_Code__c)) ? 
            warehouseMeta.DRC_NBC_Code__c : '';
        String salesPersonCode = '';
        System.debug('Order SalesPerson Code from Order: ' + ord.DRC_NBC_SalesPerson_Code__c);
        if (String.isNotBlank(ord.DRC_NBC_SalesPerson_Code__c)) {
            
            List<SalesPerson_Code__mdt> mdtRecords = [
                SELECT MasterLabel, Name__c, Phone__c, Email__c
                FROM SalesPerson_Code__mdt
                WHERE Name__c = :ord.DRC_NBC_SalesPerson_Code__c
                LIMIT 1
            ];
            
            if (!mdtRecords.isEmpty()) {
                salesPersonCode = mdtRecords[0].MasterLabel;
                System.debug('SalesPerson MasterLabel: ' + mdtRecords[0].MasterLabel);
                System.debug('SalesPerson Name__c / Code sent to Payload: ' + salesPersonCode);
                System.debug('SalesPerson Phone__c: ' + mdtRecords[0].Phone__c);
                System.debug('SalesPerson Email__c: ' + mdtRecords[0].Email__c);
            }
        }
        
        payload.Salesperson_Code = salesPersonCode;
        payload.Salesforce_So_No = ord.Id;
        payload.External_Document_No = String.isNotBlank(ord.PoNumber) ? 
            String.valueOf(ord.PoNumber) : '';
        payload.Salesforce_Order_Amount = ord.DRC_NBC_Grand_Total__c != null
            ?ord.DRC_NBC_Grand_Total__c
            : 0.00;
        payload.Salesforce_Order_Created = SalesforceOrderCreated;
        // Fetch Bank Metadata
        DRC_NBC_Bank_Master__mdt bankMeta;
        String selectedBankName = ord.DRC_NBC_Select_Bank__c;
        
        List<DRC_NBC_Bank_Master__mdt> bankMetaList = new List<DRC_NBC_Bank_Master__mdt>();
        
        if (String.isNotBlank(selectedBankName)) {
            bankMetaList = [
                SELECT Bank_Code__c, DRC_Name_Bank_Name__c
                FROM DRC_NBC_Bank_Master__mdt
                WHERE DRC_Name_Bank_Name__c = :selectedBankName
                LIMIT 1
            ];
        }
        
        if (!bankMetaList.isEmpty()) {
            bankMeta = bankMetaList[0];
            
            payload.Company_Bank_Account_Code_New = String.isNotBlank(bankMeta.Bank_Code__c)
                ? bankMeta.Bank_Code__c
                : '';
            
            System.debug('Fetched Bank Code: ' + payload.Company_Bank_Account_Code_New);
        } else {
            payload.Company_Bank_Account_Code_New = '';
            System.debug('No matching Bank metadata found for Bank Name: ' + selectedBankName);
        }
        
        // payload.Currency_Code = Ord.CurrencyIsoCode;
        If(Ord.CurrencyIsoCode == 'INR' && Ord.DRC_NBC_Type__c == 'Domestic') {
            payload.Currency_Code = '';
        }
        else{
            payload.Currency_Code = Ord.CurrencyIsoCode;
        }
        payload.Export_Document = 'Export'.equalsIgnoreCase(ord.DRC_NBC_Type__c);     
        // Added Payload For Domestic Extra Fields
        payload.PO_Date = Ord.PoDate == null ? '' : String.valueOf(Ord.PoDate);
        
        DRC_NBC_Shipping_Agent_Master__mdt shippingAgentMeta;
        if (
            ord.DRC_NBC_Type__c == 'Domestic' &&
            String.isNotBlank(ord.DRC_NBC_Transport_Agent__c)
        ) {
            List<DRC_NBC_Shipping_Agent_Master__mdt> shippingAgentList = [
                SELECT MasterLabel, DRC_NBC_Shipping_Agent_Full_Name__c
                FROM DRC_NBC_Shipping_Agent_Master__mdt
                WHERE DRC_NBC_Shipping_Agent_Full_Name__c = :ord.DRC_NBC_Transport_Agent__c
                LIMIT 1
            ];
            
            if (!shippingAgentList.isEmpty()) {
                shippingAgentMeta = shippingAgentList[0];
            }
        }
        payload.Transporter_Code = shippingAgentMeta != null 
            ? shippingAgentMeta.MasterLabel 
            : '';
        payload.Mode_of_Transport = String.isBlank(Ord.DRC_NBC_Shipment_Method__c) 
            ? '' 
            : Ord.DRC_NBC_Shipment_Method__c;
        
        if (Ord.DRC_NBC_Type__c == 'Domestic') {
            payload.DispatchDate = Ord.DRC_NBC_Shipment_Date__c == null 
                ? String.valueOf(Ord.DRC_NBC_Courier_date__c) 
                : String.valueOf(Ord.DRC_NBC_Shipment_Date__c);
        } else if (Ord.DRC_NBC_Type__c == 'Export') {
            payload.DispatchDate = Ord.NBC_DRC_Dispatch_Date__c == null 
                ? String.valueOf(Ord.DRC_NBC_Courier_date__c)
                : String.valueOf(Ord.NBC_DRC_Dispatch_Date__c);
        } else {
            payload.DispatchDate = String.valueOf(Ord.DRC_NBC_Courier_date__c);
        }
        
        // Added Payload For Sample Extra Fields
        // Added Payload For Sample Extra Fields
        payload.Requested_Delivery_Date = Ord.DRC_NBC_Expected_Delivery_Date__c != null
            ? String.valueOf(Ord.DRC_NBC_Expected_Delivery_Date__c)
            : (
                Ord.NBC_DRC_Dispatch_Date__c != null
                ? String.valueOf(Ord.NBC_DRC_Dispatch_Date__c)
                : (
                    Ord.DRC_NBC_Shipment_Date__c != null
                    ? String.valueOf(Ord.DRC_NBC_Shipment_Date__c)
                    : null
                )
            );
                
                payload.Courier_Date = Ord.DRC_NBC_Courier_date__c != null
                ? String.valueOf(Ord.DRC_NBC_Courier_date__c)
                : (
                    Ord.NBC_DRC_Dispatch_Date__c != null
                    ? String.valueOf(Ord.NBC_DRC_Dispatch_Date__c)
                    : (
                        Ord.DRC_NBC_Shipment_Date__c != null
                        ? String.valueOf(Ord.DRC_NBC_Shipment_Date__c)
                        : null
                    )
                );
                    // payload.Courier_Date = '2026-06-06';
                    // payload.Requested_Delivery_Date = '2026-06-06';
                    
                    payload.Courier_Number = String.isBlank(Ord.DRC_NBC_Courier_Number__c) 
                    ? '' 
                    : Ord.DRC_NBC_Courier_Number__c;
        
        // Added Payload For Export Extra Fields
        payload.Country_Of_Origin_Of_Goods = String.isBlank(Ord.DRC_NBC_Country_of_Origin__c) 
            ? '' 
            : Ord.DRC_NBC_Country_of_Origin__c;
        payload.Country_Of_Final_Destination = String.isBlank(Ord.DRC_NBC_Country_of_Final_Destination__c) 
            ? '' 
            : Ord.DRC_NBC_Country_of_Final_Destination__c;
        payload.Notify_Name = String.isBlank(Ord.DRC_NBC_Notify_Party__c) 
            ? '' 
            : Ord.DRC_NBC_Notify_Party__c;
        payload.Place_of_receipt_pre_carrier = String.isBlank(Ord.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c) 
            ? '' 
            : Ord.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c;
        payload.Vessel_Flight_No = String.isBlank(Ord.DRC_NBC_Vessel_no_Flight_no__c) 
            ? '' 
            : Ord.DRC_NBC_Vessel_no_Flight_no__c;
        payload.Part_Shipment = String.isBlank(Ord.DRC_NBC_Part_Shipment__c) 
            ? '' 
            : Ord.DRC_NBC_Part_Shipment__c;
        payload.Trans_Shipment = String.isBlank(Ord.DRC_NBC_Trans_Shipment__c) 
            ? '' 
            : Ord.DRC_NBC_Trans_Shipment__c;
      /*  payload.Part_Shipment = String.isBlank(Ord.DRC_NBC_Part_Shipment__c) 
            ? '' 
            : (Ord.DRC_NBC_Part_Shipment__c.equalsIgnoreCase('Allowed') ? ' Allowed' : ' Not Allowed');
                payload.Trans_Shipment = String.isBlank(Ord.DRC_NBC_Trans_Shipment__c) 
                ? '' 
                : (Ord.DRC_NBC_Trans_Shipment__c.equalsIgnoreCase('Allowed') ? ' Allowed' : ' Not Allowed');*/
        // Fetch Port Codes from Custom Metadata
        Map<String, String> portNameToCodeMap = new Map<String, String>();
        
        Set<String> portNames = new Set<String>();
        
        if (String.isNotBlank(ord.DRC_NBC_Port_Of_Discharge__c)) {
            portNames.add(ord.DRC_NBC_Port_Of_Discharge__c);
        }
        
        if (String.isNotBlank(ord.DRC_NBC_Port_of_Loading__c)) {
            portNames.add(ord.DRC_NBC_Port_of_Loading__c);
        }
        
        if (String.isNotBlank(ord.DRC_NBC_Final_Destination__c)) {
            portNames.add(ord.DRC_NBC_Final_Destination__c);
        }
        
        if (!portNames.isEmpty()) {
            List<DRC_NBC_Port_Of_Loading__mdt> portMetaList = [
                SELECT MasterLabel, Port_Name__c
                FROM DRC_NBC_Port_Of_Loading__mdt
                WHERE Port_Name__c IN :portNames
            ];
            
            for (DRC_NBC_Port_Of_Loading__mdt portMeta : portMetaList) {
                if (String.isNotBlank(portMeta.Port_Name__c)) {
                    portNameToCodeMap.put(portMeta.Port_Name__c, portMeta.MasterLabel);
                }
            }
        }
        /* payload.Port_Of_Discharge = String.isNotBlank(ord.DRC_NBC_Port_Of_Discharge__c) &&
portNameToCodeMap.containsKey(ord.DRC_NBC_Port_Of_Discharge__c)
? portNameToCodeMap.get(ord.DRC_NBC_Port_Of_Discharge__c)
: '';

payload.Port_of_Loading = String.isNotBlank(ord.DRC_NBC_Port_of_Loading__c) &&
portNameToCodeMap.containsKey(ord.DRC_NBC_Port_of_Loading__c)
? portNameToCodeMap.get(ord.DRC_NBC_Port_of_Loading__c)
: '';

payload.Final_Destination = String.isNotBlank(ord.DRC_NBC_Final_Destination__c) &&
portNameToCodeMap.containsKey(ord.DRC_NBC_Final_Destination__c)
? portNameToCodeMap.get(ord.DRC_NBC_Final_Destination__c)
: '';*/
        payload.Port_Of_Discharge = String.isBlank(ord.DRC_NBC_Port_Of_Discharge__c)
            ? ''
            : ord.DRC_NBC_Port_Of_Discharge__c;
        
        payload.Final_Destination = String.isBlank(ord.DRC_NBC_Final_Destination__c)
            ? ''
            : ord.DRC_NBC_Final_Destination__c;
        
        payload.Port_of_Loading = String.isBlank(ord.DRC_NBC_Port_of_Loading__c)
            ? ''
            : ord.DRC_NBC_Port_of_Loading__c;
        // Initialize shipping fields
        payload.Ship_to_Code = '';
        payload.Ship_to_Name = '';
        payload.Ship_to_Name_2 = '';
        payload.Ship_to_Address = '';
        payload.Ship_to_Address_2 = '';
        payload.Ship_to_Post_Code = '';
        payload.Ship_to_Country_Region_Code = '';
        //  payload.Ship_to_GST_Customer_Type = '';
        // payload.Ship_to_GST_Reg_No = '';
        
        // Populate shipping address if available
        // ✅ FIXED: Removed DRC_NBC_Order__c filter to allow address reuse across orders
        if (ord.DRC_NBC_Shipping_Address__c != null) {
            List<DRC_NBC_Addresses__c> addresses = [
                SELECT DRC_NBC_Address__Street__s, DRC_NBC_Address__City__s, 
                DRC_NBC_Address__PostalCode__s, DRC_NBC_Address__CountryCode__s, 
                DRC_NBC_Address__StateCode__s, DRC_NBC_GST_Number__c, DRC_Shipping_Gst_Customer_Type__c,
                DRC_NBC_Ship_To_Code__c, Name, DRC_Inco_Term__c
                FROM DRC_NBC_Addresses__c
                WHERE Id = :ord.DRC_NBC_Shipping_Address__c
                AND DRC_NBC_Type__c = 'Shipping'
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
                //payload.Ship_to_GST_Customer_Type = String.isBlank(address.DRC_Shipping_Gst_Customer_Type__c) ? '' : address.DRC_Shipping_Gst_Customer_Type__c;
                // payload.Ship_to_GST_Reg_No = String.isBlank(address.DRC_NBC_GST_Number__c) ? '' : address.DRC_NBC_GST_Number__c;
                
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
             /*   if (fullAddress.length() > 99) {
                    payload.Ship_to_Address = fullAddress.substring(0, 99);
                    payload.Ship_to_Address_2 = fullAddress.length() > 149 ? 
                        fullAddress.substring(99, 149) : fullAddress.substring(99);
                } else {
                    payload.Ship_to_Address = fullAddress;
                    payload.Ship_to_Address_2 = '';
                }*/
                
              /*  if (fullAddress.length() > 100) {
                    payload.Ship_to_Address   = fullAddress.substring(0, 100);
                    String shipRemainder      = fullAddress.substring(100);
                    payload.Ship_to_Address_2 = shipRemainder.length() > 100 
                        ? shipRemainder.substring(0, 100) 
                        : shipRemainder;
                } else {
                    payload.Ship_to_Address   = fullAddress;
                    payload.Ship_to_Address_2 =address.DRC_NBC_Address__City__s;
                }*/
                
                if (fullAddress.length() > 100) {
                    String first100Chars = fullAddress.substring(0, 100);
                    Integer commaIndex = first100Chars.lastIndexOf(',');
                    Integer splitIndex;
                    if (commaIndex > -1) {
                        // Split after last comma before 100 chars
                        splitIndex = commaIndex + 1;
                    } else {
                        // No comma found, split at 100 chars
                        splitIndex = 100;
                    }
                    payload.Ship_to_Address = fullAddress.substring(0, splitIndex).trim();
                    String shipRemainder = fullAddress.substring(splitIndex).trim();
                    payload.Ship_to_Address_2 = shipRemainder.length() > 100 
                        ? shipRemainder.substring(0, 49) 
                        : shipRemainder;
                    
                } else {
                    payload.Ship_to_Address   = fullAddress;
                    payload.Ship_to_Address_2 = address.DRC_NBC_Address__City__s;
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
                //payload.Ship_to_GST_Customer_Type = address.DRC_Shipping_Gst_Customer_Type__c;
                //  payload.Ship_to_GST_Reg_No = address.DRC_NBC_GST_Number__c;
                
                
            }
        } 
        
        return payload;
    }
/*  public static Boolean checkSalespersonInBC(Id contactId) {
        try {
        // Build SOAP XML envelope with ContactId as the Code
        String soapBody =
        '<?xml version="1.0" encoding="utf-8"?>' +
        '<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">' +
        '<Body>' +
        '<Read xmlns="urn:microsoft-dynamics-schemas/page/salespersonsalesforce">' +
        '<Code>' + String.valueOf(contactId) + '</Code>' +
        '</Read>' +
        '</Body>' +
        '</Envelope>';
        
        System.debug('SOAP Request Body: ' + soapBody);
        
        String endpoint = 'https://salesforceuat.drcresins.com:2023/DR_LiveSSL/WS/D.R.%20Coats%20live/Page/SalesPersonSalesForce';
        
        // ✅ Build Basic Auth header
        String username = 'Salesforce';
        String password = 'Admin@2026';
        String credentials = username + ':' + password;
        String encodedCredentials = EncodingUtil.base64Encode(Blob.valueOf(credentials));
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader('SOAPAction', '"urn:microsoft-dynamics-schemas/page/salespersonsalesforce:Read"');
        req.setHeader('Authorization', 'Basic ' + encodedCredentials); // ✅ Basic Auth header
        req.setBody(soapBody);
        req.setTimeout(30000);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('SOAP READ Response Status: ' + res.getStatusCode());
        System.debug('SOAP READ Response Body: ' + res.getBody());
        
        // ✅ If 200 OK → Contact exists in BC
        if (res.getStatusCode() == 200) {
        String responseBody = res.getBody();
        if (String.isNotBlank(responseBody) && responseBody.contains('<Code>')) {
        System.debug('Salesperson found in BC for ContactId: ' + contactId);
        return true;
        }
        }
        
        // 404 or any error → Contact does NOT exist in BC
        System.debug('Salesperson NOT found in BC for ContactId: ' + contactId);
        return false;
        
        } catch (Exception e) {
        System.debug('Exception in checkSalespersonInBC: ' + e.getMessage());
        System.debug('Stack: ' + e.getStackTraceString());
        return false;
        }
        }*/
            
    private void logError(String errorMsg) {
        DRC_NBC_API_Log_Handler.createApiLog(
            'DRC_NBC_Order_BC_Callout',
            null, null, 'Queueable',
            errorMsg, null, null,
            'Error', orderId
        );
    }
    
    public static String formatDate(Date d) {
        return d == null ? '' : String.valueOf(d);
    }
}