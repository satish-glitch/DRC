// Test Class - DRC_NBC_Invoice_Sync_WebService_Test

@RestResource(urlMapping = '/InvoiceSync/*')
global without sharing class DRC_NBC_Invoice_Sync_WebService {
    
    @HttpPost
    global static void syncInvoices() {
        Savepoint sp;
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        try {
            sp = Database.setSavePoint();
            String body = req.requestBody.toString();
            // Deserialize and validate payload
            DRC_NBC_Integration_Payload.invoiceSyncPayload payload = DRC_NBC_Integration_Utility.validateInvoiceSyncPayload(body);
            System.debug('Payload validated');
            DRC_NBC_Invoice__c invoiceRecord;
            // Try to find existing invoice by DRC_NBC_Invoice_Number__c
            List<DRC_NBC_Invoice__c> existingInvoices = [
                SELECT Id FROM DRC_NBC_Invoice__c
                WHERE DRC_NBC_Invoice_Number__c = :payload.InvoiceNumber
                LIMIT 1
            ];
            if (!existingInvoices.isEmpty()) {
                invoiceRecord = existingInvoices[0];
            } else {
                invoiceRecord = new DRC_NBC_Invoice__c();
            }
            // Populate fields  
            invoiceRecord.DRC_NBC_Invoice_Number__c           = payload.InvoiceNumber;
            invoiceRecord.DRC_NBC_Invoice_Date__c             = payload.InvoiceDate;
            invoiceRecord.DRC_NBC_Order_Number__c           =   payload.OrderNumber;
            invoiceRecord.DRC_NBC_External_Document_Number__c = payload.ExternalDocumentNumber;
            invoiceRecord.DRC_NBC_IRN_Number__c               = payload.IRNNumber;
            invoiceRecord.DRC_NBC_Acknowledgement_Number__c   = payload.AcknowledgementNumber;
            invoiceRecord.DRC_NBC_Acknowledgement_Date1__c     = payload.AcknowledgementDate;
            invoiceRecord.DRC_NBC_EWay_Bill_Number__c         = payload.EWayBillNumber;
            invoiceRecord.DRC_NBC_Vehicle_Number__c           = payload.VehicleNumber;
            invoiceRecord.DRC_NBC_Payment_Terms__c            = payload.PaymentTerms;
            invoiceRecord.DRC_NBC_Delivery_Location__c        = payload.DeliveryLocation;
            invoiceRecord.DRC_NBC_Shipping_Customer_Name__c   = payload.ShippingCustomerName;
            invoiceRecord.DRC_NBC_Shipping_Address__c         = payload.ShippingAddress;
            invoiceRecord.DRC_NBC_Shipping_GST_Number__c      = payload.ShippingGSTNumber;
            invoiceRecord.DRC_NBC_Shipping_State__c           = payload.ShippingState;
            invoiceRecord.DRC_NBC_Shipping_State_Code__c      = payload.ShippingStateCode;
            if (!String.isBlank(payload.OrderNumber)) {
                List<Order> matchedOrders = [
                    SELECT Id, DRC_NBC_Cust_Order_Number__c 
                    FROM Order 
                    WHERE DRC_NBC_Cust_Order_Number__c = :payload.OrderNumber 
                    LIMIT 1
                ];
                
                if (!matchedOrders.isEmpty()) {
                    invoiceRecord.DRC_NBC_Order__c = matchedOrders[0].Id;
                } else {
                    System.debug('No matching Order found for OrderNumber: ' + payload.OrderNumber);
                }
            }
            
            
            // Insert or update invoice
            if (invoiceRecord.Id == null) {
                if (!String.isBlank(payload.ShippingDRCCode)) {
                    List<Account> matchingAccounts = [
                        SELECT Id, Name, DRC_NBC_Customer_Number__c
                        FROM Account
                        WHERE DRC_NBC_Customer_Number__c = :payload.ShippingDRCCode
                        LIMIT 1
                    ];
                    if (!matchingAccounts.isEmpty()) {
                        Account matchedAccount = matchingAccounts[0];
                        invoiceRecord.DRC_NBC_Shipped_To_DRC_Customer_Code__c =  matchedAccount.Id;
                        invoiceRecord.DRC_NBC_Account__c = matchedAccount.Id;
                        System.debug('Matched Account: ' + matchedAccount.Name);
                    } else {
                        System.debug('No Account found with DRC_NBC_Customer_Number__c = ' + payload.ShippingDRCCode);
                    }
                }
                insert invoiceRecord;
            } else {
                update invoiceRecord;
            }
            // Now handle line items
            List<DRC_NBC_Invoice_Line_Item__c> lineItemsToUpsert = new List<DRC_NBC_Invoice_Line_Item__c>();
            Map<String, DRC_NBC_Invoice_Line_Item__c> productCodeToLineItemMap = new Map<String, DRC_NBC_Invoice_Line_Item__c>();
            
            if (payload.lineItems != null && !payload.lineItems.isEmpty()) {
                // 1. Extract product codes from payload
                Set<String> productCodes = new Set<String>();
                for (DRC_NBC_Integration_Payload.invoiceLineItem li : payload.lineItems) {
                    if (!String.isBlank(li.ProductCode)) {
                        productCodes.add(li.ProductCode);
                    }
                }
                
                // 2. Query Product2 records by ProductCode
                Map<String, Product2> productMap = new Map<String, Product2>();
                if (!productCodes.isEmpty()) {
                    for (Product2 p : [
                        SELECT Id, ProductCode
                        FROM Product2
                        WHERE ProductCode IN :productCodes
                    ]) {
                        productMap.put(p.ProductCode, p);
                    }
                }
                
                // 3. Query existing line items for this invoice and product codes
                Map<String, DRC_NBC_Invoice_Line_Item__c> existingLineItemMap = new Map<String, DRC_NBC_Invoice_Line_Item__c>();
                if (!productCodes.isEmpty()) {
                    for (DRC_NBC_Invoice_Line_Item__c existing : [
                        SELECT Id, DRC_NBC_Product__r.ProductCode
                        FROM DRC_NBC_Invoice_Line_Item__c
                        WHERE DRC_NBC_Invoice_Number__c = :invoiceRecord.Id
                        AND DRC_NBC_Product__r.ProductCode IN :productCodes
                    ]) {
                        existingLineItemMap.put(existing.DRC_NBC_Product__r.ProductCode, existing);
                    }
                }
                
                // 4. Build line items for insert/update
                for (DRC_NBC_Integration_Payload.invoiceLineItem li : payload.lineItems) {
                    if (String.isBlank(li.ProductCode)) continue;
                    
                    Product2 matchedProduct = productMap.get(li.ProductCode);
                    if (matchedProduct == null) {
                        System.debug('No Product2 found for ProductCode: ' + li.ProductCode);
                        continue;
                    }
                    
                    DRC_NBC_Invoice_Line_Item__c lineItem;
                    if (existingLineItemMap.containsKey(li.ProductCode)) {
                        lineItem = existingLineItemMap.get(li.ProductCode); // update
                    } else {
                        lineItem = new DRC_NBC_Invoice_Line_Item__c(); // insert
                        lineItem.DRC_NBC_Invoice_Number__c = invoiceRecord.Id;
                        lineItem.DRC_NBC_Product__c = matchedProduct.Id;
                    }
                    
                    // Common fields to update/set
                    lineItem.DRC_NBC_Amount__c = li.Amount;
                    lineItem.DRC_NBC_Product_Code__c = li.ProductCode;
                    
                    lineItemsToUpsert.add(lineItem);
                    productCodeToLineItemMap.put(li.ProductCode, lineItem);
                }
                
                // 5. Upsert line items first
                if (!lineItemsToUpsert.isEmpty()) {
                    upsert lineItemsToUpsert;
                }
                
                // 6. Now handle Invoice Lot records
                List<DRC_NBC_Invoice_Lot__c> invoiceLotsToUpsert = new List<DRC_NBC_Invoice_Lot__c>();
                
                // Query existing Invoice Lot records for these line items
                Set<Id> lineItemIds = new Set<Id>();
                for (DRC_NBC_Invoice_Line_Item__c li : lineItemsToUpsert) {
                    lineItemIds.add(li.Id);
                }
                
                Map<String, DRC_NBC_Invoice_Lot__c> existingLotMap = new Map<String, DRC_NBC_Invoice_Lot__c>();
                if (!lineItemIds.isEmpty()) {
                    for (DRC_NBC_Invoice_Lot__c existingLot : [
                        SELECT Id, DRC_NBC_Invoice_Line_Item__c, DRC_NBC_Lot_Number__c
                        FROM DRC_NBC_Invoice_Lot__c
                        WHERE DRC_NBC_Invoice_Line_Item__c IN :lineItemIds
                    ]) {
                        String key = existingLot.DRC_NBC_Invoice_Line_Item__c + '_' + existingLot.DRC_NBC_Lot_Number__c;
                        existingLotMap.put(key, existingLot);
                    }
                }
                
                // Create or update Invoice Lot records from lotDetails
                for (DRC_NBC_Integration_Payload.invoiceLineItem li : payload.lineItems) {
                    if (String.isBlank(li.ProductCode)) continue;
                    if (li.lotDetails == null || li.lotDetails.isEmpty()) continue;
                    
                    DRC_NBC_Invoice_Line_Item__c lineItem = productCodeToLineItemMap.get(li.ProductCode);
                    if (lineItem == null || lineItem.Id == null) continue;
                    
                    // Get the Product2 ID for this line item
                    Product2 matchedProduct = productMap.get(li.ProductCode);
                    if (matchedProduct == null) continue;
                    
                    for (DRC_NBC_Integration_Payload.lotDetail ld : li.lotDetails) {
                        if (String.isBlank(ld.lot)) continue;
                        
                        String lotKey = lineItem.Id + '_' + ld.lot;
                        DRC_NBC_Invoice_Lot__c invoiceLot;
                        
                        if (existingLotMap.containsKey(lotKey)) {
                            invoiceLot = existingLotMap.get(lotKey); // update
                        } else {
                            invoiceLot = new DRC_NBC_Invoice_Lot__c(); // insert
                            invoiceLot.DRC_NBC_Invoice_Line_Item__c = lineItem.Id;
                            invoiceLot.DRC_NBC_Lot_Number__c = ld.lot;
                            invoiceLot.DRC_NBC_Product__c = matchedProduct.Id; // Add Product lookup
                            invoiceLot.DRC_NBC_Invoice__c = invoiceRecord.Id; // Add Invoice lookup
                        }
                        
                        // Set/update quantity
                        invoiceLot.DRC_NBC_Lot_Quantity__c = string.valueOf(ld.quantity);
                        invoiceLotsToUpsert.add(invoiceLot);
                    }
                }
                
                // 7. Upsert Invoice Lot records
                if (!invoiceLotsToUpsert.isEmpty()) {
                    upsert invoiceLotsToUpsert;
                }
            }
            
            res.statusCode = 201;
            res.responseBody = Blob.valueOf('Invoice ' + payload.InvoiceNumber + ' and line items synced successfully.');
            DRC_NBC_API_Log_Handler.createApiLog('/InvoiceSync', body, res.responseBody?.toString(), 'POST', null, res.statusCode, null, 'Success', null);
            
        } catch (Exception e) {
            Database.rollback(sp);
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                '/InvoiceSync', req.requestBody.toString(), null, 'POST',
                e.getMessage(), 500, e.getStackTraceString(), 'Error', null
            );
        }
    }
    
    @TestVisible
    private static String formatLotNo(String rawLotNo) {
        if (String.isBlank(rawLotNo)) return null;
        List<String> lotNumbers = new List<String>();
        Integer index = 1;
        
        for (String part : rawLotNo.split(',')) {
            part = part.trim();
            if (!String.isBlank(part)) {
                String lotNumber = part.split(' - Qty')[0].trim();
                lotNumbers.add(index + '. ' + lotNumber);
                index++;
            }
        }
        
        return String.join(lotNumbers, '\n');
    }
    
    @TestVisible
    private static String formatLotQuantity(String rawLotNo) {
        if (String.isBlank(rawLotNo)) return null;
        List<String> lotQuantities = new List<String>();
        Integer index = 1;
        
        for (String part : rawLotNo.split(',')) {
            part = part.trim();
            if (!String.isBlank(part)) {
                // Extract the quantity part after 'Qty :'
                if (part.contains('Qty')) {
                    String[] qtyParts = part.split('Qty\\s*:\\s*');
                    if (qtyParts.size() > 1) {
                        String qty = qtyParts[1].replaceAll(',', '').trim();
                        lotQuantities.add(index + '. ' + qty);
                        index++;
                    }
                }
            }
        }
        
        return String.join(lotQuantities, '\n');
    }
}