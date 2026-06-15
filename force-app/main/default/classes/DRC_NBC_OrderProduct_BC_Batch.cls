public class DRC_NBC_OrderProduct_BC_Batch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    
    private Id orderId;
    Public String locationCode;
    
    public DRC_NBC_OrderProduct_BC_Batch(Id orderId) {
        this.orderId = orderId;
        System.debug('=== BATCH INITIALIZED ===');
        System.debug('Order ID: ' + orderId);
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        System.debug('=== BATCH START METHOD ===');
        return Database.getQueryLocator([
            SELECT Id,
            OrderId,
            DRC_NBC_Hazardous__c,
            DRC_NBC_MARKS_NOS__c,
            Order.DRC_NBC_Fright_Charges__c,
            Order.DRC_NBC_Insurance__c,
            Description,
            Product2Id,
            Quantity,
            UnitPrice,
            DRC_NBC_Discount__c,
            Order.DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
            Order.DRC_NBC_Record_Type_Name__c,
            Order.DRC_NBC_TCS_Amount__c,
            Order.DRC_NBC_Other_Tax_Amount__c,
            Order.DRC_NBC_Sample_Shipping_Cost__c,
            Order.DRC_NBC_Sample_Amount__c,
            Order.Is_Domestic_Merchnat__c,
            DRC_NBC_Total_Price__c,
            Order.DRC_NBC_Cust_Order_Number__c,
            Order.AccountId,
            Order.Account.DRC_NBC_Customer_Number__c,
            Order.Account.Type,
            Order.RecordType.Name,
            Order.DRC_NBC_Warehouse__c,
            Product2.DRC_NBC_FG_Code__c,
            Product2.DRC_NBC_GST_Group_Code__c,
            Product2.DRC_NBC_HSN_SAC_Code__c,
            DRC_NBC_Unit_Of_Measurement__c,
            DRC_NBC_Packing_Quantity__c,
            DRC_NBC_Packing_Size__c
            FROM OrderItem
            WHERE OrderId = :orderId
            ORDER BY CreatedDate ASC
        ]);
    }
    
    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        System.debug('=======================================================');
        System.debug('=== BATCH EXECUTE METHOD - START ===');
        System.debug('=======================================================');
        
        if (scope.isEmpty()) {
            System.debug('Scope is empty. Exiting.');
            return;
        }
        
        System.debug('Total OrderItems in current scope: ' + scope.size());
        
        // ==========================================================
        //  BUILD RESTRICTED PRODUCT MAP (Product2Id → Name)
        // ==========================================================
        Map<Id, String> restrictedProductMap = new Map<Id, String>();
        try {
            Id accountId = ((OrderItem) scope[0]).Order.AccountId;
            System.debug('Building Restricted Product Map for AccountId: ' + accountId);
            for (DRC_NBC_Restricted_Product__c rp : [
                SELECT Name, DRC_NBC_Product__c
                FROM DRC_NBC_Restricted_Product__c
                WHERE DRC_NBC_Customer__c = :accountId
            ]) {
                restrictedProductMap.put(rp.DRC_NBC_Product__c, rp.Name);
            }
            System.debug('Restricted Product Map built. Size: ' + restrictedProductMap.size());
            System.debug('Restricted Product Map: ' + restrictedProductMap);
        } catch (Exception ex) {
            System.debug('!!! ERROR building Restricted Product Map: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
        }
        
        List<Map<String, Object>> requestList = new List<Map<String, Object>>();
        Integer lineCounter = 1;
        Integer requestCounter = 1;
        
        Order relatedOrder;
        
        System.debug('--- Processing Order Items ---');
        for (SObject sObj : scope) {
            OrderItem item = (OrderItem) sObj;
            
            System.debug('>>> Processing OrderItem #' + lineCounter);
            System.debug('OrderItem ID: ' + item.Id);
            System.debug('Product Name/FG Code: ' + item.Product2.DRC_NBC_FG_Code__c);
            System.debug('Quantity: ' + item.Quantity);
            System.debug('Unit Price: ' + item.UnitPrice);
            System.debug('Total Price: ' + item.DRC_NBC_Total_Price__c);
            System.debug('Discount %: ' + item.DRC_NBC_Discount__c);
            
            if (relatedOrder == null) {
                relatedOrder = item.Order;
                System.debug('Stored Order Reference:');
                System.debug('  - Order ID: ' + relatedOrder.Id);
                System.debug('  - Customer Order Number: ' + relatedOrder.DRC_NBC_Cust_Order_Number__c);
                System.debug('  - Record Type: ' + relatedOrder.RecordType.Name);
                System.debug('  - TCS Amount: ' + relatedOrder.DRC_NBC_TCS_Amount__c);
                System.debug('  - Other Tax Amount: ' + relatedOrder.DRC_NBC_Other_Tax_Amount__c);
                System.debug('  - Sample Shipping Cost: ' + relatedOrder.DRC_NBC_Sample_Shipping_Cost__c);
                System.debug('  - Sample Amount: ' + relatedOrder.DRC_NBC_Sample_Amount__c);
            }
            
            Integer lineNo = (lineCounter++) * 10000;
            
            try {
                DRC_NBC_Integration_Payload.OrderLinePayload payload = mapOrderItemToPayload(item, lineNo, restrictedProductMap);
                
                System.debug('--- ITEM PAYLOAD CREATED ---');
                System.debug(JSON.serializePretty(payload));
                
                Map<String, Object> requestBlock = new Map<String, Object>();
                requestBlock.put('method', 'POST');
                requestBlock.put('id', 'r' + requestCounter);
                requestBlock.put('url', System.Label.DRC_UAT);
                
                Map<String, String> headers = new Map<String, String>{
                    'Content-Type' => 'application/json'
                        };
                            requestBlock.put('headers', headers);
                requestBlock.put('body', payload);
                
                System.debug('--- REQUEST BLOCK #' + requestCounter + ' ---');
                System.debug(JSON.serializePretty(requestBlock));
                
                requestList.add(requestBlock);
                requestCounter++;
                
            } catch (Exception ex) {
                System.debug('!!! ERROR mapping OrderItem ' + item.Id + ': ' + ex.getMessage());
                System.debug('Stack Trace: ' + ex.getStackTraceString());
                logError(ex.getMessage(), item.Id, null, null);
            }
        }
        
        // ==========================================================
        //  ADD OTHER TAX LINE (G/L Account)
        // ==========================================================
        System.debug('--- Checking for Other Tax Line ---');
        try {
            if (relatedOrder != null) {
                Decimal otherTaxAmount = relatedOrder.DRC_NBC_Other_Tax_Amount__c;
                System.debug('Other Tax Amount from Order: ' + otherTaxAmount);
                
                if (otherTaxAmount != null && otherTaxAmount != 0) {
                    Integer otherTaxLineNo = (lineCounter++) * 10000;
                    System.debug('Creating Other Tax Line with Line No: ' + otherTaxLineNo);
                    
                    DRC_NBC_Integration_Payload.OrderLinePayload otherTaxPayload =
                        mapOtherTaxToPayload(relatedOrder, otherTaxAmount, otherTaxLineNo);
                    
                    System.debug('--- OTHER TAX PAYLOAD CREATED ---');
                    System.debug(JSON.serializePretty(otherTaxPayload));
                    
                    Map<String, Object> requestBlock = new Map<String, Object>();
                    requestBlock.put('method', 'POST');
                    requestBlock.put('id', 'r' + requestCounter);
                    requestBlock.put('url', System.Label.DRC_UAT);
                    
                    Map<String, String> headers = new Map<String, String>{
                        'Content-Type' => 'application/json'
                            };
                                requestBlock.put('headers', headers);
                    requestBlock.put('body', otherTaxPayload);
                    
                    System.debug('--- OTHER TAX REQUEST BLOCK #' + requestCounter + ' ---');
                    System.debug(JSON.serializePretty(requestBlock));
                    
                    requestList.add(requestBlock);
                    requestCounter++;
                    
                    System.debug('✓ Successfully added Other Tax G/L Account Line. Amount=' + otherTaxAmount + ', Line No=' + otherTaxLineNo);
                } else {
                    System.debug('No Other Tax Amount to add (null or zero)');
                }
            } else {
                System.debug('!!! No related Order found for Other Tax line');
            }
        } catch (Exception ex) {
            System.debug('!!! ERROR adding Other Tax line: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            logError('Other Tax Line Error: ' + ex.getMessage(), orderId, null, null);
        }
        
        // ==========================================================
        //  ADD TCS AMOUNT LINE (G/L Account)
        // ==========================================================
        System.debug('--- Checking for TCS Amount Line ---');
        try {
            if (relatedOrder != null) {
                Decimal tcsAmount = relatedOrder.DRC_NBC_TCS_Amount__c;
                System.debug('TCS Amount from Order: ' + tcsAmount);
                
                if (tcsAmount != null && tcsAmount != 0) {
                    Integer tcsLineNo = (lineCounter++) * 10000;
                    System.debug('Creating TCS Amount Line with Line No: ' + tcsLineNo);
                    
                    DRC_NBC_Integration_Payload.OrderLinePayload tcsPayload =
                        mapTCSToPayload(relatedOrder, tcsAmount, tcsLineNo);
                    
                    System.debug('--- TCS AMOUNT PAYLOAD CREATED ---');
                    System.debug(JSON.serializePretty(tcsPayload));
                    
                    Map<String, Object> requestBlock = new Map<String, Object>();
                    requestBlock.put('method', 'POST');
                    requestBlock.put('id', 'r' + requestCounter);
                    requestBlock.put('url', System.Label.DRC_UAT);
                    
                    Map<String, String> headers = new Map<String, String>{
                        'Content-Type' => 'application/json'
                            };
                                requestBlock.put('headers', headers);
                    requestBlock.put('body', tcsPayload);
                    
                    System.debug('--- TCS AMOUNT REQUEST BLOCK #' + requestCounter + ' ---');
                    System.debug(JSON.serializePretty(requestBlock));
                    
                    requestList.add(requestBlock);
                    requestCounter++;
                    
                    System.debug('✓ Successfully added TCS Amount G/L Account Line. Amount=' + tcsAmount + ', Line No=' + tcsLineNo);
                } else {
                    System.debug('No TCS Amount to add (null or zero)');
                }
            } else {
                System.debug('!!! No related Order found for TCS Amount line');
            }
        } catch (Exception ex) {
            System.debug('!!! ERROR adding TCS Amount line: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            logError('TCS Amount Line Error: ' + ex.getMessage(), orderId, null, null);
        }
        
        // ==========================================================
        //  ADD FREIGHT CHARGES LINE (G/L Account)
        // ==========================================================
        System.debug('--- Checking for Freight Charges Line ---');
        try {
            if (relatedOrder != null) {
                Decimal freightCharges = relatedOrder.DRC_NBC_Fright_Charges__c;
                System.debug('Freight Charges from Order: ' + freightCharges);
                
                if (freightCharges != null && freightCharges != 0) {
                    Integer freightLineNo = (lineCounter++) * 10000;
                    System.debug('Creating Freight Charges Line with Line No: ' + freightLineNo);
                    
                    DRC_NBC_Integration_Payload.OrderLinePayload freightPayload =
                        mapFreightChargesToPayload(relatedOrder, freightCharges, freightLineNo);
                    
                    System.debug('--- FREIGHT CHARGES PAYLOAD CREATED ---');
                    System.debug(JSON.serializePretty(freightPayload));
                    
                    Map<String, Object> requestBlock = new Map<String, Object>();
                    requestBlock.put('method', 'POST');
                    requestBlock.put('id', 'r' + requestCounter);
                    requestBlock.put('url', System.Label.DRC_UAT);
                    
                    Map<String, String> headers = new Map<String, String>{
                        'Content-Type' => 'application/json'
                            };
                                requestBlock.put('headers', headers);
                    requestBlock.put('body', freightPayload);
                    
                    System.debug('--- FREIGHT CHARGES REQUEST BLOCK #' + requestCounter + ' ---');
                    System.debug(JSON.serializePretty(requestBlock));
                    
                    requestList.add(requestBlock);
                    requestCounter++;
                    
                    System.debug('✓ Successfully added Freight Charges G/L Account Line. Amount=' + freightCharges + ', Line No=' + freightLineNo);
                } else {
                    System.debug('No Freight Charges to add (null or zero)');
                }
            } else {
                System.debug('!!! No related Order found for Freight Charges line');
            }
        } catch (Exception ex) {
            System.debug('!!! ERROR adding Freight Charges line: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            logError('Freight Charges Line Error: ' + ex.getMessage(), orderId, null, null);
        }
        
        // ==========================================================
        //  ADD INSURANCE LINE (G/L Account)
        // ==========================================================
        System.debug('--- Checking for Insurance Line ---');
        try {
            if (relatedOrder != null) {
                Decimal insuranceAmount = relatedOrder.DRC_NBC_Insurance__c;
                System.debug('Insurance from Order: ' + insuranceAmount);
                
                if (insuranceAmount != null && insuranceAmount != 0) {
                    Integer insuranceLineNo = (lineCounter++) * 10000;
                    System.debug('Creating Insurance Line with Line No: ' + insuranceLineNo);
                    
                    DRC_NBC_Integration_Payload.OrderLinePayload insurancePayload =
                        mapInsuranceToPayload(relatedOrder, insuranceAmount, insuranceLineNo);
                    
                    System.debug('--- INSURANCE PAYLOAD CREATED ---');
                    System.debug(JSON.serializePretty(insurancePayload));
                    
                    Map<String, Object> requestBlock = new Map<String, Object>();
                    requestBlock.put('method', 'POST');
                    requestBlock.put('id', 'r' + requestCounter);
                    requestBlock.put('url', System.Label.DRC_UAT);
                    
                    Map<String, String> headers = new Map<String, String>{
                        'Content-Type' => 'application/json'
                            };
                                requestBlock.put('headers', headers);
                    requestBlock.put('body', insurancePayload);
                    
                    System.debug('--- INSURANCE REQUEST BLOCK #' + requestCounter + ' ---');
                    System.debug(JSON.serializePretty(requestBlock));
                    
                    requestList.add(requestBlock);
                    requestCounter++;
                    
                    System.debug('✓ Successfully added Insurance G/L Account Line. Amount=' + insuranceAmount + ', Line No=' + insuranceLineNo);
                } else {
                    System.debug('No Insurance to add (null or zero)');
                }
            } else {
                System.debug('!!! No related Order found for Insurance line');
            }
        } catch (Exception ex) {
            System.debug('!!! ERROR adding Insurance line: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            logError('Insurance Line Error: ' + ex.getMessage(), orderId, null, null);
        }
        
        // ==========================================================
        //  ADD SAMPLE SHIPPING COST LINE (G/L Account) - Only for Sample Orders
        // ==========================================================
        System.debug('--- Checking for Sample Shipping Cost Line ---');
        try {
            if (relatedOrder != null && relatedOrder.RecordType.Name == 'Sample_Order') {
                Decimal sampleShippingCost = relatedOrder.DRC_NBC_Sample_Shipping_Cost__c;
                System.debug('Sample Shipping Cost from Order: ' + sampleShippingCost);
                
                if (sampleShippingCost != null && sampleShippingCost != 0) {
                    Integer sampleShippingLineNo = (lineCounter++) * 10000;
                    System.debug('Creating Sample Shipping Cost Line with Line No: ' + sampleShippingLineNo);
                    
                    DRC_NBC_Integration_Payload.OrderLinePayload sampleShippingPayload =
                        mapSampleShippingCostToPayload(relatedOrder, sampleShippingCost, sampleShippingLineNo);
                    
                    System.debug('--- SAMPLE SHIPPING COST PAYLOAD CREATED ---');
                    System.debug(JSON.serializePretty(sampleShippingPayload));
                    
                    Map<String, Object> requestBlock = new Map<String, Object>();
                    requestBlock.put('method', 'POST');
                    requestBlock.put('id', 'r' + requestCounter);
                    requestBlock.put('url', System.Label.DRC_UAT);
                    
                    Map<String, String> headers = new Map<String, String>{
                        'Content-Type' => 'application/json'
                            };
                                requestBlock.put('headers', headers);
                    requestBlock.put('body', sampleShippingPayload);
                    
                    System.debug('--- SAMPLE SHIPPING COST REQUEST BLOCK #' + requestCounter + ' ---');
                    System.debug(JSON.serializePretty(requestBlock));
                    
                    requestList.add(requestBlock);
                    requestCounter++;
                    
                    System.debug('✓ Successfully added Sample Shipping Cost G/L Account Line. Amount=' + sampleShippingCost + ', Line No=' + sampleShippingLineNo);
                } else {
                    System.debug('No Sample Shipping Cost to add (null or zero)');
                }
            } else {
                System.debug('Skipping Sample Shipping Cost Line - Not a Sample Order or no related Order');
            }
        } catch (Exception ex) {
            System.debug('!!! ERROR adding Sample Shipping Cost line: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            logError('Sample Shipping Cost Line Error: ' + ex.getMessage(), orderId, null, null);
        }
        
        // ==========================================================
        //  ADD SAMPLE AMOUNT LINE (G/L Account) - Only for Sample Orders
        // ==========================================================
        System.debug('--- Checking for Sample Amount Line ---');
        try {
            if (relatedOrder != null && relatedOrder.RecordType.Name == 'Sample_Order') {
                Decimal sampleAmount = relatedOrder.DRC_NBC_Sample_Amount__c;
                System.debug('Sample Amount from Order: ' + sampleAmount);
                
                if (sampleAmount != null && sampleAmount != 0) {
                    Integer sampleAmountLineNo = (lineCounter++) * 10000;
                    System.debug('Creating Sample Amount Line with Line No: ' + sampleAmountLineNo);
                    
                    DRC_NBC_Integration_Payload.OrderLinePayload sampleAmountPayload =
                        mapSampleAmountToPayload(relatedOrder, sampleAmount, sampleAmountLineNo);
                    
                    System.debug('--- SAMPLE AMOUNT PAYLOAD CREATED ---');
                    System.debug(JSON.serializePretty(sampleAmountPayload));
                    
                    Map<String, Object> requestBlock = new Map<String, Object>();
                    requestBlock.put('method', 'POST');
                    requestBlock.put('id', 'r' + requestCounter);
                    requestBlock.put('url', System.Label.DRC_UAT);
                    
                    Map<String, String> headers = new Map<String, String>{
                        'Content-Type' => 'application/json'
                            };
                                requestBlock.put('headers', headers);
                    requestBlock.put('body', sampleAmountPayload);
                    
                    System.debug('--- SAMPLE AMOUNT REQUEST BLOCK #' + requestCounter + ' ---');
                    System.debug(JSON.serializePretty(requestBlock));
                    
                    requestList.add(requestBlock);
                    requestCounter++;
                    
                    System.debug('✓ Successfully added Sample Amount G/L Account Line. Amount=' + sampleAmount + ', Line No=' + sampleAmountLineNo);
                } else {
                    System.debug('No Sample Amount to add (null or zero)');
                }
            } else {
                System.debug('Skipping Sample Amount Line - Not a Sample Order or no related Order');
            }
        } catch (Exception ex) {
            System.debug('!!! ERROR adding Sample Amount line: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            logError('Sample Amount Line Error: ' + ex.getMessage(), orderId, null, null);
        }
        
        // ==========================================================
        // FINAL CALL OUT
        // ==========================================================
        System.debug('=======================================================');
        System.debug('--- Preparing Final Callout ---');
        System.debug('Total Request Blocks: ' + requestList.size());
        System.debug('Final Line Counter Value: ' + lineCounter);
        
        if (!requestList.isEmpty()) {
            Map<String, Object> payloadWrapper = new Map<String, Object>{
                'requests' => requestList
                    };
                        
                        String jsonBody = JSON.serialize(payloadWrapper, true);
            
            System.debug('=======================================================');
            System.debug('=== COMPLETE PAYLOAD WRAPPER ===');
            System.debug('=======================================================');
            System.debug(JSON.serializePretty(payloadWrapper));
            System.debug('=======================================================');
            System.debug('=== RAW JSON BODY (for HTTP Request) ===');
            System.debug('=======================================================');
            System.debug(jsonBody);
            System.debug('=======================================================');
            System.debug('JSON Body Length: ' + jsonBody.length() + ' characters');
            
            String baseEndpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_SendOrderLineEndpoint__c;
            String fullEndpoint = DRC_NBC_BC_Callout_Utility.getOrderProductFullEndpoint(baseEndpoint);
            
            System.debug('Base Endpoint: ' + baseEndpoint);
            System.debug('Full Endpoint: ' + fullEndpoint);
            
            try {
                System.debug('--- Initiating HTTP Callout ---');
                DRC_NBC_OrderProduct_BC_Integration integration = new DRC_NBC_OrderProduct_BC_Integration(
                    fullEndpoint,
                    'POST',
                    jsonBody,
                    orderId
                );
                
                HttpResponse response = integration.executeAndReturnResponse();
                
                System.debug('=== HTTP RESPONSE ===');
                if (response != null) {
                    System.debug('Status Code: ' + response.getStatusCode());
                    System.debug('Status: ' + response.getStatus());
                    System.debug('Response Body:');
                    System.debug(response.getBody());
                    
                    if (response.getStatusCode() == 200) {
                        System.debug('✓✓✓ OrderItems synced successfully for OrderId: ' + orderId);
                        DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
                        logSuccess('OrderItems synced successfully', orderId, response, jsonBody);
                    } else {
                        System.debug('!!! Sync failed for OrderId: ' + orderId);
                        logError('Callout failed with status: ' + response.getStatusCode(), orderId, response, jsonBody);
                    }
                } else {
                    System.debug('!!! Response is NULL');
                    logError('HTTP Response is null', orderId, null, jsonBody);
                }
                
            } catch (Exception ex) {
                System.debug('!!! ERROR during callout: ' + ex.getMessage());
                System.debug('Stack Trace: ' + ex.getStackTraceString());
                logError(ex.getMessage(), orderId, null, jsonBody);
            }
        } else {
            System.debug('!!! Request list is empty, skipping callout');
        }
        
        System.debug('=======================================================');
        System.debug('=== BATCH EXECUTE METHOD - END ===');
        System.debug('=======================================================');
    }
    
    public void finish(Database.BatchableContext BC) {
        System.debug('=======================================================');
        System.debug('=== BATCH FINISH METHOD ===');
        System.debug('All OrderItems processed for Order: ' + orderId);
        System.debug('=======================================================');
    }
    
    // ==========================================================
    // EXISTING ITEM PAYLOAD MAPPER
    // ==========================================================
    private DRC_NBC_Integration_Payload.OrderLinePayload mapOrderItemToPayload(
        OrderItem item, Integer lineNo, Map<Id, String> restrictedProductMap
    ) {
        System.debug('  >> Mapping OrderItem to Payload (Line No: ' + lineNo + ')');
        
        String warehouseLabel = item.Order.DRC_NBC_Warehouse__c;
        System.debug('  Warehouse Label: ' + warehouseLabel);
        List<Warehouse_Location_Code__mdt> metaList = [
            SELECT DRC_NBC_Code__c
            FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel = :warehouseLabel AND DRC_NBC_Type__c = 'Warehouse Location'
            LIMIT 1
        ];
        
        if (!metaList.isEmpty()) {
            locationCode = metaList[0].DRC_NBC_Code__c;
            System.debug('  Location Code (from metadata): ' + locationCode);
        } else {
            System.debug('  !!! No Location Code found for warehouse: ' + warehouseLabel);
            locationCode = '';
        }
        
        Boolean isSampleOrder = item.Order.RecordType.Name == 'Sample_Order';
        System.debug('  Is Sample Order: ' + isSampleOrder);
        
        Decimal discountPercent = item.DRC_NBC_Discount__c != null ? item.DRC_NBC_Discount__c : 0;
        Decimal totalPrice = item.DRC_NBC_Total_Price__c != null ? item.DRC_NBC_Total_Price__c : 0;
        Decimal lineDiscountAmount = (totalPrice * discountPercent) / 100;
        
        System.debug('  Discount Percent: ' + discountPercent);
        System.debug('  Total Price (before sample check): ' + totalPrice);
        System.debug('  Line Discount Amount (calculated): ' + lineDiscountAmount);
        
        if (isSampleOrder) {
            totalPrice = 0;
            lineDiscountAmount = 0;
            System.debug('  Sample Order detected - Total Price and Discount set to 0');
        }
        
        // Resolve Item_Reference_No from Restricted Product map
        String itemReferenceNo = restrictedProductMap.containsKey(item.Product2Id)
            ? restrictedProductMap.get(item.Product2Id)
            : '';
        System.debug('  Item Reference No (Restricted Product Name): ' + itemReferenceNo);
        
        DRC_NBC_Integration_Payload.OrderLinePayload payload = new DRC_NBC_Integration_Payload.OrderLinePayload();
        payload.Document_Type = 'Order';
        payload.Document_No = item.Order.DRC_NBC_Cust_Order_Number__c;
        payload.Line_No = lineNo;
        payload.Type = 'Item';
        payload.No = item.Product2.DRC_NBC_FG_Code__c;
        payload.Customer_item_no = item.Product2.DRC_NBC_FG_Code__c;
        payload.Description = item.Description != null ? item.Description : '';
        payload.Location_Code = locationCode;
        payload.Quantity = item.Quantity != null ? item.Quantity : 0;
        payload.Unit_of_Measure_Code = 'KGS';
        payload.Unit_Price = isSampleOrder ? 0 : (item.UnitPrice != null ? item.UnitPrice : 0);
            payload.Line_Amount = totalPrice;
        payload.Line_Discount_Percent = discountPercent;
        payload.Line_Discount_Amount = lineDiscountAmount;
        payload.Inv_Discount_Amount = lineDiscountAmount;
        if( Item.Order.Is_Domestic_Merchnat__c) {
            payload.GST_Group_Code = label.Merchnat_GST_Group_Code;
        }
        else{
            payload.HSN_SAC_Code = item.Product2.DRC_NBC_HSN_SAC_Code__c;
            payload.GST_Group_Code = String.isNotBlank(item.Product2.DRC_NBC_GST_Group_Code__c) ? item.Product2.DRC_NBC_GST_Group_Code__c : '';
        }
        
        payload.GST_Credit = 'Availment';
        payload.Packing_Details = String.isNotBlank(item.DRC_NBC_Packing_Size__c) ? item.DRC_NBC_Packing_Size__c : '';
        Decimal packingQty = String.isNotBlank(item.DRC_NBC_Packing_Quantity__c) 
            ? Decimal.valueOf(item.DRC_NBC_Packing_Quantity__c)
            : 0;
        payload.No_of_Pkg_for_Qty = packingQty > 0
            ? item.Quantity / packingQty
            : item.Quantity;
        payload.Hazardous = item.DRC_NBC_Hazardous__c;
        payload.MarkNosContainerNos = String.isBlank(item.DRC_NBC_MARKS_NOS__c)
            ? ''
            : item.DRC_NBC_MARKS_NOS__c.trim();
        payload.Item_Reference_No = itemReferenceNo;
        payload.Item_Reference_Type = item.Order.Account.Type;
        payload.Item_Reference_Type_No = item.Order.Account.DRC_NBC_Customer_Number__c;
        payload.Item_Reference_Unit_of_Measure = 'KGS';
        
        System.debug('  << Payload mapping complete');
        return payload;
    }
    
    // ==========================================================
    //  OTHER TAX PAYLOAD (G/L Account)
    // ==========================================================
    private DRC_NBC_Integration_Payload.OrderLinePayload mapOtherTaxToPayload(
        Order ord, Decimal otherTaxAmount, Integer lineNo
    ) {
        System.debug('  >> Mapping Other Tax to Payload (Line No: ' + lineNo + ')');
        
        DRC_NBC_Integration_Payload.OrderLinePayload payload = new DRC_NBC_Integration_Payload.OrderLinePayload();
        payload.Document_Type = 'Order';
        payload.Document_No = ord.DRC_NBC_Cust_Order_Number__c;
        payload.Line_No = lineNo;
        payload.Type = 'G/L Account';
        payload.No = label.DRC_Other_Tax_Number;
        payload.Customer_item_no = '';
        payload.Description = 'Other Tax Amount';
        payload.Location_Code = locationCode;
        payload.Quantity = 1;
        payload.Unit_of_Measure_Code = 'KGS';
        payload.Unit_Price = otherTaxAmount;
        payload.Line_Amount = otherTaxAmount;
        payload.Line_Discount_Percent = 0;
        payload.Line_Discount_Amount = 0;
        payload.Inv_Discount_Amount = 0;
        if( ord.Is_Domestic_Merchnat__c  == true) {
            payload.GST_Group_Code = label.Merchnat_GST_Group_Code;
        }
        else{
            payload.HSN_SAC_Code = '';
            payload.GST_Group_Code = '';
        }
        
        payload.GST_Credit = 'Availment';
        payload.Packing_Details = '';
        payload.No_of_Pkg_for_Qty = 1;
        payload.Hazardous = false;
        payload.MarkNosContainerNos = '';
        payload.Item_Reference_No = '';
        payload.Item_Reference_Type = '';
        payload.Item_Reference_Type_No = '';
        payload.Item_Reference_Unit_of_Measure = 'KGS';
        
        
        System.debug('  << Other Tax payload mapping complete');
        return payload;
    }
    
    // ==========================================================
    //  TCS AMOUNT PAYLOAD (G/L Account)
    // ==========================================================
    private DRC_NBC_Integration_Payload.OrderLinePayload mapTCSToPayload(
        Order ord, Decimal tcsAmount, Integer lineNo
    ) {
        System.debug('  >> Mapping TCS Amount to Payload (Line No: ' + lineNo + ')');
        
        DRC_NBC_Integration_Payload.OrderLinePayload payload = new DRC_NBC_Integration_Payload.OrderLinePayload();
        payload.Document_Type = 'Order';
        payload.Document_No = ord.DRC_NBC_Cust_Order_Number__c;
        payload.Line_No = lineNo;
        payload.Type = 'G/L Account';
        payload.No = label.DRC_TCS_Tax_Number;
        payload.Customer_item_no = '';
        payload.Description = 'TCS Amount';
        payload.Location_Code = locationCode;
        payload.Quantity = 1;
        payload.Unit_of_Measure_Code = 'KGS';
        payload.Unit_Price = tcsAmount;
        payload.Line_Amount = tcsAmount;
        payload.Line_Discount_Percent = 0;
        payload.Line_Discount_Amount = 0;
        payload.Inv_Discount_Amount = 0;
        if( ord.Is_Domestic_Merchnat__c  == true) {
            payload.GST_Group_Code = label.Merchnat_GST_Group_Code;
        }
        else{
            payload.HSN_SAC_Code = '';
            payload.GST_Group_Code = '';
        }
        payload.GST_Credit = 'Availment';
        payload.Packing_Details = '';
        payload.No_of_Pkg_for_Qty = 1;
        payload.Hazardous = false;
        payload.MarkNosContainerNos = '';
        payload.Item_Reference_No = '';
        payload.Item_Reference_Type = '';
        payload.Item_Reference_Type_No = '';
        payload.Item_Reference_Unit_of_Measure = 'KGS';
        
        System.debug('  << TCS Amount payload mapping complete');
        return payload;
    }
    
    // ==========================================================
    //  FREIGHT CHARGES PAYLOAD (G/L Account)
    // ==========================================================
    private DRC_NBC_Integration_Payload.OrderLinePayload mapFreightChargesToPayload(
        Order ord, Decimal freightCharges, Integer lineNo
    ) {
        System.debug('  >> Mapping Freight Charges to Payload (Line No: ' + lineNo + ')');
        
        DRC_NBC_Integration_Payload.OrderLinePayload payload = new DRC_NBC_Integration_Payload.OrderLinePayload();
        payload.Document_Type = 'Order';
        payload.Document_No = ord.DRC_NBC_Cust_Order_Number__c;
        payload.Line_No = lineNo;
        payload.Type = 'G/L Account';
        payload.No = Label.DRC_TCS_Tax_Number;
        payload.Customer_item_no = '';
        payload.Description = 'Freight Charges';
        payload.Location_Code = locationCode;
        payload.Quantity = 1;
        payload.Unit_of_Measure_Code = 'KGS';
        payload.Unit_Price = freightCharges;
        payload.Line_Amount = freightCharges;
        payload.Line_Discount_Percent = 0;
        payload.Line_Discount_Amount = 0;
        payload.Inv_Discount_Amount = 0;
        if( ord.Is_Domestic_Merchnat__c  == true) {
            payload.GST_Group_Code = label.Merchnat_GST_Group_Code;
        }
        else{
            payload.HSN_SAC_Code = '';
            payload.GST_Group_Code = '';
        }
        payload.GST_Credit = 'Availment';
        payload.Packing_Details = '';
        payload.No_of_Pkg_for_Qty = 1;
        payload.Hazardous = false;
        payload.MarkNosContainerNos = '';
        payload.Item_Reference_No = '';
        payload.Item_Reference_Type = '';
        payload.Item_Reference_Type_No = '';
        payload.Item_Reference_Unit_of_Measure = 'KGS';
        
        System.debug('  << Freight Charges payload mapping complete');
        return payload;
    }
    
    // ==========================================================
    //  INSURANCE PAYLOAD (G/L Account)
    // ==========================================================
    private DRC_NBC_Integration_Payload.OrderLinePayload mapInsuranceToPayload(
        Order ord, Decimal insuranceAmount, Integer lineNo
    ) {
        System.debug('  >> Mapping Insurance to Payload (Line No: ' + lineNo + ')');
        
        DRC_NBC_Integration_Payload.OrderLinePayload payload = new DRC_NBC_Integration_Payload.OrderLinePayload();
        payload.Document_Type = 'Order';
        payload.Document_No = ord.DRC_NBC_Cust_Order_Number__c;
        payload.Line_No = lineNo;
        payload.Type = 'G/L Account';
        payload.No = Label.DRC_TCS_Tax_Number;
        payload.Customer_item_no = '';
        payload.Description = 'Insurance';
        payload.Location_Code = locationCode;
        payload.Quantity = 1;
        payload.Unit_of_Measure_Code = 'KGS';
        payload.Unit_Price = insuranceAmount;
        payload.Line_Amount = insuranceAmount;
        payload.Line_Discount_Percent = 0;
        payload.Line_Discount_Amount = 0;
        payload.Inv_Discount_Amount = 0;
        if( ord.Is_Domestic_Merchnat__c  == true) {
            payload.GST_Group_Code = label.Merchnat_GST_Group_Code;
        }
        else{
            payload.HSN_SAC_Code = '';
            payload.GST_Group_Code = '';
        }
        payload.GST_Credit = 'Availment';
        payload.Packing_Details = '';
        payload.No_of_Pkg_for_Qty = 1;
        payload.Hazardous = false;
        payload.MarkNosContainerNos = '';
        payload.Item_Reference_No = '';
        payload.Item_Reference_Type = '';
        payload.Item_Reference_Type_No = '';
        payload.Item_Reference_Unit_of_Measure = 'KGS';
        
        System.debug('  << Insurance payload mapping complete');
        return payload;
    }
    
    // ==========================================================
    //  SAMPLE SHIPPING COST PAYLOAD (G/L Account)
    // ==========================================================
    public DRC_NBC_Integration_Payload.OrderLinePayload mapSampleShippingCostToPayload(
        Order ord, Decimal sampleShippingCost, Integer lineNo
    ) {
        System.debug('  >> Mapping Sample Shipping Cost to Payload (Line No: ' + lineNo + ')');
        System.debug('  Sample Shipping Cost: ' + sampleShippingCost);
        System.debug('  Location Code: ' + locationCode);
        
        DRC_NBC_Integration_Payload.OrderLinePayload payload = new DRC_NBC_Integration_Payload.OrderLinePayload();
        payload.Document_Type = 'Order';
        payload.Document_No = ord.DRC_NBC_Cust_Order_Number__c;
        payload.Line_No = lineNo;
        payload.Type = 'G/L Account';
        payload.No = label.DRC_TCS_Tax_Number;
        payload.Customer_item_no = '';
        payload.Description = 'Sample Shipping Cost';
        payload.Location_Code = locationCode;
        payload.Quantity = 1;
        payload.Unit_of_Measure_Code = 'KGS';
        payload.Unit_Price = sampleShippingCost;
        payload.Line_Amount = sampleShippingCost;
        payload.Line_Discount_Percent = 0;
        payload.Line_Discount_Amount = 0;
        payload.Inv_Discount_Amount = 0;
        if( ord.Is_Domestic_Merchnat__c  == true) {
            payload.GST_Group_Code = label.Merchnat_GST_Group_Code;
        }
        else{
            payload.HSN_SAC_Code = '';
            payload.GST_Group_Code = '';
        }
        payload.GST_Credit = 'Availment';
        payload.Packing_Details = '';
        payload.No_of_Pkg_for_Qty = 1;
        payload.Hazardous = false;
        payload.MarkNosContainerNos = '';
        payload.Item_Reference_No = '';
        payload.Item_Reference_Type = '';
        payload.Item_Reference_Type_No = '';
        payload.Item_Reference_Unit_of_Measure = 'KGS';
        
        System.debug('  << Sample Shipping Cost payload mapping complete');
        return payload;
    }
    
    // ==========================================================
    //  SAMPLE AMOUNT PAYLOAD (G/L Account)
    // ==========================================================
    public DRC_NBC_Integration_Payload.OrderLinePayload mapSampleAmountToPayload(
        Order ord, Decimal sampleAmount, Integer lineNo
    ) {
        System.debug('  >> Mapping Sample Amount to Payload (Line No: ' + lineNo + ')');
        System.debug('  Sample Amount: ' + sampleAmount);
        System.debug('  Location Code: ' + locationCode);
        
        DRC_NBC_Integration_Payload.OrderLinePayload payload = new DRC_NBC_Integration_Payload.OrderLinePayload();
        payload.Document_Type = 'Order';
        payload.Document_No = ord.DRC_NBC_Cust_Order_Number__c;
        payload.Line_No = lineNo;
        payload.Type = 'G/L Account';
        payload.No = label.DRC_TCS_Tax_Number;
        payload.Customer_item_no = '';
        payload.Description = 'Sample Amount';
        payload.Location_Code = locationCode;
        payload.Quantity = 1;
        payload.Unit_of_Measure_Code = 'KGS';
        payload.Unit_Price = sampleAmount;
        payload.Line_Amount = sampleAmount;
        payload.Line_Discount_Percent = 0;
        payload.Line_Discount_Amount = 0;
        payload.Inv_Discount_Amount = 0;
        if( ord.Is_Domestic_Merchnat__c  == true) {
            payload.GST_Group_Code = label.Merchnat_GST_Group_Code;
        }
        else{
            payload.HSN_SAC_Code = '';
            payload.GST_Group_Code = '';
        }
        payload.GST_Credit = 'Availment';
        payload.Packing_Details = '';
        payload.No_of_Pkg_for_Qty = 1;
        payload.Hazardous = false;
        payload.MarkNosContainerNos = '';
        payload.Item_Reference_No = '';
        payload.Item_Reference_Type = '';
        payload.Item_Reference_Type_No = '';
        payload.Item_Reference_Unit_of_Measure = 'KGS';
        
        System.debug('  << Sample Amount payload mapping complete');
        return payload;
    }
    
    // ==========================================================
    // API LOGGING METHODS
    // ==========================================================
    private void logSuccess(String message, Id orderItemId, HttpResponse response, String requestBody) {
        System.debug('  *** Logging Success ***');
        DRC_NBC_API_Log_Handler.createApiLog(
            'DRC_NBC_OrderProduct_BC_Batch',
            requestBody,
            response.getBody(),
            'POST',
            message,
            response.getStatusCode(),
            null,
            'Success',
            orderId
        );
    }
    
    private void logError(String errorMsg, Id orderItemId, HttpResponse response, String requestBody) {
        System.debug('  *** Logging Error ***');
        System.debug('  Error Message: ' + errorMsg);
        DRC_NBC_API_Log_Handler.createApiLog(
            'DRC_NBC_OrderProduct_BC_Batch',
            requestBody,
            response != null ? response.getBody() : null,
            'POST',
            errorMsg,
            response != null ? response.getStatusCode() : null,
            null,
            'Error',
            orderId
        );
    }
}