/**
* @File Name : DRC_NBC_LineItemCreator.cls
* @Description : Handles Creation of Line Items in Business Central using SOAP CreateMultiple
* @Author : Satish Yadav 
* @Last Modified On : April 22, 2026
**/
public class DRC_NBC_LineItemCreator {
    
    private static DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();
    private static final String BC_LINE_ITEM_ENDPOINT   = bcSettings.DRC_NBC_BC_Line_Item_Endpoint__c;
    private static final String SOAP_LINE_NAMESPACE     = bcSettings.DRC_NBC_SOAP_Line_Namespace__c;
    private static final String GST_CREDIT_VALUE        = bcSettings.DRC_NBC_GST_Credit_Value__c;
    private static final String BC_USERNAME             = bcSettings.DRC_NBC_Username__c;
    private static final String BC_PASSWORD             = bcSettings.DRC_NBC_Password__c;
    
    public static String createLineItemsAtLineNumber(String bcOrderNo, List<OrderItem> orderItems,
                                                     Order ord, Integer startingLineNo) {
                                                         System.debug('*** CREATE Line Items at Line Number Started ***');
                                                         System.debug('BC Order Number: ' + bcOrderNo);
                                                         System.debug('Starting Line Number: ' + startingLineNo);
                                                         for (OrderItem itemOrder : orderItems) {
                                                             System.debug('Item Id: ' + itemOrder.Id);
                                                             System.debug('FG Code: ' + itemOrder.Product2.DRC_NBC_FG_Code__c);
                                                             System.debug('HSN SAC Code: ' + itemOrder.Product2.DRC_NBC_HSN_SAC_Code__c);
                                                             System.debug('GST Group Code: ' + itemOrder.Product2.DRC_NBC_GST_Group_Code__c);
                                                         }
                                                         
                                                         if (orderItems == null || orderItems.isEmpty()) {
                                                             System.debug('No product items to create');
                                                             return 'NO_ITEMS_TO_CREATE';
                                                         }
                                                         
                                                         try {
                                                             String requestBody = buildCreateMultipleSOAPRequest(bcOrderNo, orderItems, startingLineNo, ord);
                                                             String bcLocationCode = DRC_NBC_UpdateOrderAndLineItems.buildReadSOAPRequest(bcOrderNo);
                                                             
                                                             System.debug('========== LOCATION CODE CHECK (Before Line Create) ==========');
                                                        
                                                             System.debug('BC Order Location  : ' + (String.isBlank(bcLocationCode) ? '[EMPTY/NOT FOUND]' : bcLocationCode));
                                                            
                                                             
                                                             
                                                             HttpRequest req = new HttpRequest();
                                                             req.setEndpoint(BC_LINE_ITEM_ENDPOINT);
                                                             req.setMethod('POST');
                                                             req.setHeader('Content-Type', 'text/xml; charset=utf-8');
                                                             req.setHeader('SOAPAction', SOAP_LINE_NAMESPACE + ':CreateMultiple');
                                                             req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(
                                                                 Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD)
                                                             ));
                                                             System.debug(LoggingLevel.ERROR, 'SOAP Payload before callout: ' + requestBody);
                                                             debugLongString('SOAP Payload before callout', requestBody);
                                                             
                                                             req.setBody(requestBody);
                                                             req.setTimeout(120000);
                                                             
                                                             HttpResponse response = new Http().send(req); // ← CALLOUT
                                                             
                                                             System.debug('CreateMultiple Response Status: ' + response.getStatusCode());
                                                             
                                                             if (response.getStatusCode() == 200) {
                                                                 // ✅ No log here — in the middle of process
                                                                 // Final SUCCESS log written by intelligentLineItemSync after all steps pass
                                                                 System.debug('Line Items Created Successfully');
                                                                 return 'SUCCESS';
                                                                 
                                                             } else {
                                                                 // ✅ ERROR log — safe because caller (intelligentLineItemSync)
                                                                 // stops immediately after seeing FAILURE, no more callouts follow
                                                                 System.debug('ERROR: CreateMultiple failed - ' + response.getStatusCode());
                                                                 System.debug('Response Body: ' + response.getBody());
                                                                 DRC_NBC_API_Log_Handler.createApiLog(
                                                                     BC_LINE_ITEM_ENDPOINT,
                                                                     requestBody,
                                                                     response.getBody(),
                                                                     'createLineItemsAtLineNumber',
                                                                     'CreateMultiple failed: ' + response.getStatusCode(),
                                                                     response.getStatusCode(),
                                                                     null,
                                                                     'ERROR',
                                                                     ord.Id
                                                                 );
                                                                 return 'FAILURE: ' + response.getStatusCode();
                                                             }
                                                             
                                                         } catch (Exception ex) {
                                                             System.debug('*** CreateMultiple Exception: ' + ex.getMessage());
                                                             // ✅ ERROR log — exception means no more callouts, safe to DML
                                                             DRC_NBC_API_Log_Handler.createApiLog(
                                                                 BC_LINE_ITEM_ENDPOINT,
                                                                 null,
                                                                 null,
                                                                 'createLineItemsAtLineNumber',
                                                                 ex.getMessage(),
                                                                 null,
                                                                 ex.getStackTraceString(),
                                                                 'ERROR',
                                                                 ord.Id
                                                             );
                                                             return 'ERROR: ' + ex.getMessage();
                                                         }
                                                     }
    
    // ── Legacy method — kept for backward compatibility ───────────────────
    public static String createLineItems(String bcOrderNo, List<OrderItem> orderItems,
                                         Order ord, Integer startingLineCounter) {
                                             return createLineItemsAtLineNumber(bcOrderNo, orderItems, ord, startingLineCounter * 10000);
                                         }
    
    private static String buildCreateMultipleSOAPRequest(String bcOrderNo, List<OrderItem> orderItems,
                                                         Integer startingLineNo, Order ord) {
                                                             String locationCode = '';
                                                             if (ord != null && ord.DRC_NBC_Shipping_Address__r != null &&
                                                                 String.isNotBlank(ord.DRC_NBC_Warehouse__c)) {
                                                                     
                                                                     List<Warehouse_Location_Code__mdt> metaList = [
                                                                         SELECT DRC_NBC_Code__c FROM Warehouse_Location_Code__mdt
                                                                         WHERE MasterLabel = :ord.DRC_NBC_Warehouse__c
                                                                         AND DRC_NBC_Type__c = 'Warehouse Location'
                                                                         LIMIT 1
                                                                     ];
                                                                     if (!metaList.isEmpty()) {
                                                                         locationCode = metaList[0].DRC_NBC_Code__c;
                                                                         System.debug('Location_Code from metadata: ' + locationCode);
                                                                     }
                                                                 }
                                                             
                                                             String soapBody =
                                                                 '<?xml version="1.0" encoding="utf-8"?>' +
                                                                 '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                                                                 '<soap:Body>' +
                                                                 '<CreateMultiple xmlns="' + SOAP_LINE_NAMESPACE + '">' +
                                                                 '<SalesOrderLineSalesForce_List>';
                                                             
                                                             Integer currentLineNo = startingLineNo;
                                                             
                                                             for (OrderItem item : orderItems) {
                                                                 System.debug('Creating line at: ' + currentLineNo);
                                                                 System.debug('Item Id: ' + item.Id);
                                                                 System.debug('FG Code: ' + item.Product2.DRC_NBC_FG_Code__c);
                                                                 System.debug('HSN SAC Code: ' + item.Product2.DRC_NBC_HSN_SAC_Code__c);
                                                                 System.debug('GST Group Code: ' + item.Product2.DRC_NBC_GST_Group_Code__c);
                                                                 
                                                                 Boolean isSampleOrder      = item.Order.RecordType.Name == 'Sample_Order';
                                                                 Decimal discountPercent    = item.DRC_NBC_Discount__c != null ? item.DRC_NBC_Discount__c : 0;
                                                                 Decimal totalPrice         = item.DRC_NBC_Total_Price__c != null ? item.DRC_NBC_Total_Price__c : 0;
                                                                 Decimal lineDiscountAmount = (totalPrice * discountPercent) / 100;
                                                                 
                                                                 if (isSampleOrder) {
                                                                     totalPrice         = 0;
                                                                     lineDiscountAmount = 0;
                                                                 }
                                                                 
                                                                 soapBody +=
                                                                     '<SalesOrderLineSalesForce>' +
                                                                     '<Document_Type>Order</Document_Type>' +
                                                                     '<Document_No>' + escapeXml(bcOrderNo) + '</Document_No>' +
                                                                     '<Line_No>' + currentLineNo + '</Line_No>' +
                                                                     '<Type>Item</Type>' +
                                                                     '<No>' + escapeXml(item.Product2.DRC_NBC_FG_Code__c) + '</No>' +
                                                                     '<Customer_item_no>'      + escapeXml(item.Product2.DRC_NBC_FG_Code__c) + '</Customer_item_no>' +
                                                                     '<Description>' + escapeXml(item.Description != null ? item.Description : '') + '</Description>' +
                                                                     '<Location_Code>' + escapeXml(locationCode) + '</Location_Code>' +
                                                                     '<Quantity>' + (item.Quantity != null ? item.Quantity : 0) + '</Quantity>' +
                                                                     '<Unit_of_Measure_Code>KGS</Unit_of_Measure_Code>' +
                                                                     '<Unit_Price>' + (isSampleOrder ? 0 : (item.UnitPrice != null ? item.UnitPrice : 0)) + '</Unit_Price>' +
                                                                     '<Line_Amount>' + totalPrice + '</Line_Amount>' +
                                                                     '<Line_Discount_Percent>' + discountPercent + '</Line_Discount_Percent>' +
                                                                     '<Line_Discount_Amount>' + lineDiscountAmount + '</Line_Discount_Amount>' +
                                                                     '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                                                                     '<GST_Credit>' + GST_CREDIT_VALUE + '</GST_Credit>' +
                                                                     '<GST_Group_Code>' + escapeXml(item.Product2.DRC_NBC_GST_Group_Code__c) + '</GST_Group_Code>' +
                                                                     '<HSN_SAC_Code>' + escapeXml(item.Product2.DRC_NBC_HSN_SAC_Code__c) + '</HSN_SAC_Code>' +
                                                                     '<No_of_Pkg_for_Qty>' + (item.DRC_NBC_Packing_Quantity__c != null ? String.valueOf(item.Quantity) : '0') + '</No_of_Pkg_for_Qty>' +
                                                                     '<Packing_Details>' + escapeXml(item.DRC_NBC_Packing_Size__c != null ? item.DRC_NBC_Packing_Size__c : '') + '</Packing_Details>' +
                                                                     '</SalesOrderLineSalesForce>';
                                                                 
                                                                 currentLineNo += 10000;
                                                             }
                                                             
                                                             soapBody +=
                                                                 '</SalesOrderLineSalesForce_List>' +
                                                                 '</CreateMultiple>' +
                                                                 '</soap:Body>' +
                                                                 '</soap:Envelope>';
                                                             
                                                             return soapBody;
                                                         }
    
    private static String escapeXml(String value) {
        if (String.isBlank(value)) return '';
        return value.escapeXml();
    }
    private static void debugLongString(String label, String text) {
        if (String.isBlank(text)) {
            System.debug(LoggingLevel.ERROR, label + ': [EMPTY]');
            return;
        }
        
        Integer chunkSize = 3000;
        Integer len = text.length();
        
        for (Integer i = 0; i < len; i += chunkSize) {
            Integer endIdx = Math.min(i + chunkSize, len);
            System.debug(LoggingLevel.ERROR,
                         label + ' [' + i + '-' + (endIdx - 1) + ']: ' + text.substring(i, endIdx)
                        );
        }
    }
}