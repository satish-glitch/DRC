/**
* @File Name : DRC_NBC_LineItemCreator.cls
* @Description : Handles Creation of Line Items in Business Central using SOAP CreateMultiple
* @Author : Satish Yadav 
* @Last Modified On : February 06, 2026
**/
public class DRC_NBC_LineItemCreator {
    
    // Custom Setting Instance
    private static DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();
    
    // BC Endpoints from Custom Setting
    private static final String BC_LINE_ITEM_ENDPOINT = bcSettings.DRC_NBC_BC_Line_Item_Endpoint__c;
    private static final String SOAP_LINE_NAMESPACE = bcSettings.DRC_NBC_SOAP_Line_Namespace__c;
    private static final String GST_CREDIT_VALUE = bcSettings.DRC_NBC_GST_Credit_Value__c;
    
    // Authentication credentials from Custom Setting
    private static final String BC_USERNAME = bcSettings.DRC_NBC_Username__c;
    private static final String BC_PASSWORD = bcSettings.DRC_NBC_Password__c;
    
    /**
     * Create multiple line items in Business Central at specific line number
     * 
     * @param bcOrderNo - Business Central Order Number
     * @param orderItems - List of new OrderItems to create (PRODUCTS ONLY)
     * @param ord - Order record (tax amounts NOT used in CREATE)
     * @param startingLineNo - Explicit starting line number (e.g., 30000, 40000)
     *                         Each subsequent item increments by 10000
     * @return Result message
     */
    public static String createLineItemsAtLineNumber(String bcOrderNo, List<OrderItem> orderItems, 
                                                     Order ord, Integer startingLineNo) {
        System.debug('*** CREATE Line Items at Line Number Started ***');
        System.debug('BC Order Number: ' + bcOrderNo);
        System.debug('Number of PRODUCT items to create: ' + orderItems.size());
        System.debug('Starting Line Number: ' + startingLineNo);
        System.debug('Line numbers will be: ' + startingLineNo + ', ' + (startingLineNo + 10000) + ', ' + (startingLineNo + 20000) + '...');
        
        if (orderItems == null || orderItems.isEmpty()) {
            System.debug('No product items to create');
            return 'NO_ITEMS_TO_CREATE';
        }
        
        try {
            // Build CreateMultiple SOAP Request
            String requestBody = buildCreateMultipleSOAPRequest(bcOrderNo, orderItems, startingLineNo, ord);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_LINE_ITEM_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_LINE_NAMESPACE + ':CreateMultiple');
            
            // Add Basic Authentication
            Blob headerValue = Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD);
            String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
            req.setHeader('Authorization', authorizationHeader);
            
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse response = http.send(req);
            
            System.debug('CreateMultiple Response Status: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                System.debug('Line Items Created Successfully');
                return 'SUCCESS';
            } else {
                System.debug('ERROR: CreateMultiple failed - ' + response.getStatusCode());
                System.debug('Response Body: ' + response.getBody());
                return 'FAILURE: ' + response.getStatusCode();
            }
            
        } catch (Exception ex) {
            System.debug('*** CreateMultiple Exception ***');
            System.debug('Exception: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    /**
     * LEGACY METHOD - Kept for backward compatibility
     * Converts counter-based approach to explicit line number
     */
    public static String createLineItems(String bcOrderNo, List<OrderItem> orderItems, 
                                        Order ord, Integer startingLineCounter) {
        // Convert counter to actual line number (counter * 10000)
        Integer startingLineNo = startingLineCounter * 10000;
        return createLineItemsAtLineNumber(bcOrderNo, orderItems, ord, startingLineNo);
    }
    
    /**
     * Build CreateMultiple SOAP Request
     * 
     * LINE NUMBER LOGIC:
     * - Starts at provided startingLineNo (e.g., 30000)
     * - Each item: currentLineNo, then currentLineNo += 10000
     * - Result: Creates at 30000, 40000, 50000, etc.
     */
    private static String buildCreateMultipleSOAPRequest(String bcOrderNo, List<OrderItem> orderItems, 
                                                         Integer startingLineNo, Order ord) {
        // Get Location Code from Warehouse metadata (ONCE, outside loop)
        String locationCode = '';
        if (ord != null && ord.DRC_NBC_Shipping_Address__r != null && 
            String.isNotBlank(ord.DRC_NBC_Warehouse__c)) {
            
            String warehouseLabel = ord.DRC_NBC_Warehouse__c;
            List<Warehouse_Location_Code__mdt> metaList = [
                SELECT DRC_NBC_Code__c FROM Warehouse_Location_Code__mdt
                WHERE MasterLabel = :warehouseLabel AND DRC_NBC_Type__c = 'Warehouse Location'
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
        
        // Create PRODUCT items only
        for (OrderItem item : orderItems) {
            System.debug('Creating line at: ' + currentLineNo);
            
            Boolean isSampleOrder = item.Order.RecordType.Name == 'Sample_Order';
            Decimal discountPercent = item.DRC_NBC_Discount__c != null ? item.DRC_NBC_Discount__c : 0;
            Decimal totalPrice = item.DRC_NBC_Total_Price__c != null ? item.DRC_NBC_Total_Price__c : 0;
            Decimal lineDiscountAmount = (totalPrice * discountPercent) / 100;
            
            if (isSampleOrder) {
                totalPrice = 0;
                lineDiscountAmount = 0;
            }
            
            soapBody += 
                '<SalesOrderLineSalesForce>' +
                '<Document_Type>Order</Document_Type>' +
                '<Document_No>' + escapeXml(bcOrderNo) + '</Document_No>' +
                '<Line_No>' + currentLineNo + '</Line_No>' +
                '<Type>Item</Type>' +
                '<No>' + escapeXml(item.Product2.DRC_NBC_FG_Code__c) + '</No>' +
                '<Description>' + escapeXml(item.Description != null ? item.Description : '') + '</Description>' +
                '<Location_Code>' + escapeXml(locationCode) + '</Location_Code>' +
                '<Quantity>' + (item.Quantity != null ? item.Quantity : 0) + '</Quantity>' +
                '<Unit_of_Measure_Code>' + escapeXml(item.DRC_NBC_Unit_Of_Measurement__c) + '</Unit_of_Measure_Code>' +
                '<Unit_Price>' + (isSampleOrder ? 0 : (item.UnitPrice != null ? item.UnitPrice : 0)) + '</Unit_Price>' +
                '<Line_Amount>' + totalPrice + '</Line_Amount>' +
                '<Line_Discount_Percent>' + discountPercent + '</Line_Discount_Percent>' +
                '<Line_Discount_Amount>' + lineDiscountAmount + '</Line_Discount_Amount>' +
                '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                '<GST_Credit>' + GST_CREDIT_VALUE + '</GST_Credit>' +
                '<GST_Group_Code>' + escapeXml(item.Product2.DRC_NBC_GST_Group_Code__c) + '</GST_Group_Code>' +
                '<HSN_SAC_Code>' + escapeXml(item.Product2.DRC_NBC_HSN_SAC_Code__c) + '</HSN_SAC_Code>' +
                '</SalesOrderLineSalesForce>';
            
            currentLineNo += 10000; // Increment by 10000 for next item
        }
        
        soapBody +=
            '</SalesOrderLineSalesForce_List>' +
            '</CreateMultiple>' +
            '</soap:Body>' +
            '</soap:Envelope>';
        
        return soapBody;
    }
    
    /**
     * Helper: Escape XML
     */
    private static String escapeXml(String value) {
        if (String.isBlank(value)) return '';
        return value.escapeXml();
    }
}