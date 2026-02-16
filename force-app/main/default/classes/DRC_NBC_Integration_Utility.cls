public with sharing class DRC_NBC_Integration_Utility {
    
    public static DRC_NBC_Integration_Payload.productWithPriceBookPayloadLst validateProductSyncPayload(String payload) {
        List<PriceBookEntry> priceBookEntries = [
            SELECT Id, DRC_NBC_External_Id__c 
            FROM PriceBookEntry 
            WHERE DRC_NBC_External_Id__c != null 
            LIMIT 50000
        ];
        
        List<String> priceBookExistingExternalId = new List<String>();
        if (String.isBlank(payload)) {
            throw new DRC_NBC_CustomException('Payload cannot be null or empty');
        }
        
        DRC_NBC_Integration_Payload.productWithPriceBookPayloadLst requestData;
        try {
            requestData = (DRC_NBC_Integration_Payload.productWithPriceBookPayloadLst)
                JSON.deserialize(payload, DRC_NBC_Integration_Payload.productWithPriceBookPayloadLst.class);
        } catch (Exception e) {
            throw new DRC_NBC_CustomException('Invalid JSON format: ' + e.getMessage());
        }
        
        for (PriceBookEntry priceBookEntry : priceBookEntries) {
            priceBookExistingExternalId.add(priceBookEntry.DRC_NBC_External_Id__c);
        }
        
        List<PriceBook2> priceBooks = [SELECT Id, DRC_NBC_External_Id__c FROM PriceBook2 LIMIT 50000];
        for (PriceBook2 pb : priceBooks) {
            priceBookExistingExternalId.add(pb.DRC_NBC_External_Id__c);
        }
        
        List<String> productCodes = new List<String>();
        List<Product2> products = [SELECT DRC_NBC_FG_Code__c FROM Product2 WHERE DRC_NBC_FG_Code__c != null LIMIT 50000];
        for (Product2 p : products) {
            productCodes.add(p.DRC_NBC_FG_Code__c);
        }
        
        for (DRC_NBC_Integration_Payload.productWithPriceBookPayload currentPayload : requestData.products) {
            if (String.isBlank(currentPayload.product.FGCode)) {
                throw new DRC_NBC_CustomException('FGCode cannot be null or empty');
            } else {
                if(productCodes.contains(currentPayload.product.FGCode)) {
                    
                }
                else {
                    for (DRC_NBC_Integration_Payload.priceBook pb : currentPayload.priceBook) {
                        if (String.isBlank(pb.bookEntryExternalId)) {
                            throw new DRC_NBC_CustomException('bookEntryExternalId cannot be null or empty');
                        } else if (priceBookExistingExternalId.contains(pb.bookEntryExternalId)) {
                            throw new DRC_NBC_CustomException('bookEntryExternalId already exists. Please provide unique ID');
                        }
                    }
                }
            }
        }
        return requestData;
    } 
    
    public static DRC_NBC_Integration_Payload.OrderStatusPayload validateOrderStatusPayload(String payload) {
        if (String.isBlank(payload)) {
            throw new DRC_NBC_CustomException('Payload cannot be null or empty');
        }
        
        DRC_NBC_Integration_Payload.OrderStatusPayload orderPayload;
        try {
            orderPayload = (DRC_NBC_Integration_Payload.OrderStatusPayload)
                JSON.deserialize(payload, DRC_NBC_Integration_Payload.OrderStatusPayload.class);
        } catch (Exception e) {
            throw new DRC_NBC_CustomException('Invalid JSON format: ' + e.getMessage());
        }
        
        if (String.isBlank(orderPayload.orderId)) {
            throw new DRC_NBC_CustomException('Order ID is mandatory in payload');
        }
        if (String.isBlank(orderPayload.status)) {
            throw new DRC_NBC_CustomException('Order Status is mandatory in payload');
        }
        
        if (orderPayload.expectedDeliveryDate != null) {
            try {
                Date.valueOf(orderPayload.expectedDeliveryDate);
            } catch (Exception e) {
                throw new DRC_NBC_CustomException('Invalid expectedDeliveryDate format. Use yyyy-MM-dd');
            }
        }
        
        return orderPayload;
    }
    
    public static DRC_NBC_Integration_Payload.invoiceSyncPayload validateInvoiceSyncPayload(String payload) {
        if (String.isBlank(payload)) {
            throw new DRC_NBC_CustomException('Payload cannot be null or empty');
        }        
        DRC_NBC_Integration_Payload.invoiceSyncPayload invoicePayload;
        
        try {
            invoicePayload = (DRC_NBC_Integration_Payload.invoiceSyncPayload)
                JSON.deserialize(payload, DRC_NBC_Integration_Payload.invoiceSyncPayload.class);
        } catch (Exception e) {
            throw new DRC_NBC_CustomException('Invalid JSON format: ' + e.getMessage());
        }
        
        if (String.isBlank(invoicePayload.InvoiceNumber)) {
            throw new DRC_NBC_CustomException('InvoiceNumber is mandatory in payload');
        }
        if (String.isBlank(invoicePayload.OrderNumber)) {
            throw new DRC_NBC_CustomException('OrderNumber is mandatory in payload');
        }
        
        if (invoicePayload.InvoiceDate != null) {
            try {
                Date.valueOf(invoicePayload.InvoiceDate);
            } catch (Exception e) {
                throw new DRC_NBC_CustomException('Invalid InvoiceDate format. Use yyyy-MM-dd');
            }
        }
        
      /*  if (invoicePayload.AcknowledgementDate != null) {
            try {
                DateTime.valueOf(invoicePayload.AcknowledgementDate.format());
            } catch (Exception e) {
                throw new DRC_NBC_CustomException('Invalid AcknowledgementDate format. Use ISO datetime format');
            }
        }*/
        
        return invoicePayload;
    }
    
}