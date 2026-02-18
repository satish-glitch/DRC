/**
* @File Name : DRC_NBC_UpdateOrderAndLineItems.cls
* @Description : Handles Order and Line Items sync with Business Central using SOAP
* @Author : Satish
* @Last Modified On : February 06, 2026
* * 1. Generate Ship-To Code (if missing)
* 2. Update Order in BC
* 3. UPDATE existing line items (matched products + existing taxes)
* 4. CREATE new line items (new products only - tax lines never created here)
* 5. DELETE unmatched PRODUCT line items ONLY
* 6. DELETE tax lines ONLY if amounts changed from non-zero to zero
**/
public class DRC_NBC_UpdateOrderAndLineItems {
    
    // Custom Setting Instance
    private static DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();
    
    // BC Endpoints from Custom Setting
    private static final String BC_ORDER_ENDPOINT = bcSettings.DRC_NBC_BC_Order_Endpoint__c;
    private static final String BC_LINE_ITEM_ENDPOINT = bcSettings.DRC_NBC_BC_Line_Item_Endpoint__c;
    private static final String SOAP_ORDER_NAMESPACE = bcSettings.DRC_NBC_SOAP_Order_Namespace__c;
    private static final String SOAP_LINE_NAMESPACE = bcSettings.DRC_NBC_SOAP_Line_Namespace__c;
    private static final String GST_CREDIT_VALUE = bcSettings.DRC_NBC_GST_Credit_Value__c;
    
    // Authentication credentials from Custom Setting
    private static final String BC_USERNAME = bcSettings.DRC_NBC_Username__c;
    private static final String BC_PASSWORD = bcSettings.DRC_NBC_Password__c;
    
    /**
* Wrapper class to hold BC Line Item details for intelligent matching
*/
    public class BCLineItem {
        public String key;
        public Integer lineNo;
        public String lineType;      // "Item" or "G/L Account"
        public String itemNo;         // FG Code for products
        public Decimal quantity;
        public String description;
        
        public BCLineItem(String k, Integer ln, String lt, String item, Decimal qty, String description) {
            this.key = k;
            this.lineNo = ln;
            this.lineType = lt;
            this.itemNo = item;
            this.quantity = qty;
            this.description = description;
        }
    }
    
    /**
* Main entry point - called from DRC_NBC_Order_BC_Callout
* Handles Ship-To Code generation if needed, then processes order sync
*/
    public static String orderId(Id orderRecordId) {
        System.debug('*** START: DRC_NBC_UpdateOrderAndLineItems.orderId ***');
        System.debug('Order Record ID: ' + orderRecordId);
        
        // Validate Custom Setting
        if (bcSettings == null || String.isBlank(BC_ORDER_ENDPOINT) || String.isBlank(BC_USERNAME)) {
            String errorMsg = 'ERROR: Business Central settings not configured. Please setup DRC_NBC_BC_Integration__c Custom Setting.';
            System.debug(errorMsg);
            return errorMsg;
        }
        
        String resultMessage = '';
        
        try {
            // Step 1: Get Order details
            System.debug('Step 1: Querying Order details...');
            Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(orderRecordId);
            Id accountId = ord.AccountId;
            
            System.debug('Order Number: ' + ord.OrderNumber);
            System.debug('BC Customer Order Number: ' + ord.DRC_NBC_Cust_Order_Number__c);
            System.debug('Customer Number: ' + ord.Account.DRC_NBC_Customer_Number__c);
            System.debug('Ship To Code: ' + ord.DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c);
            
            // Step 2: Check if Ship-To Code generation is needed
            if (String.isBlank(ord.DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c)) {
                System.debug('Ship-To Code is missing. Starting chained Queueable process...');
                
                // Chain TWO Queueables:
                // 1. Generate Ship-To Code (DML only)
                // 2. Execute Callouts (Shipping API + Order Sync)
                System.enqueueJob(new ShipToCodeGeneratorQueueable(orderRecordId, accountId));
                
                resultMessage = 'QUEUED: Ship-To Code generation started. Shipping and Order sync will follow.';
                System.debug(resultMessage);
                return resultMessage;
                
            } else {
                System.debug('Ship-To Code already present. Proceeding with Order sync.');
                // Process order sync directly
                resultMessage = processOrderSync(ord, accountId);
            }
            
        } catch (Exception ex) {
            System.debug('*** EXCEPTION in orderId ***');
            System.debug('Exception Type: ' + ex.getTypeName());
            System.debug('Exception Message: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            System.debug('Line Number: ' + ex.getLineNumber());
            
            resultMessage = 'ERROR: ' + ex.getMessage();
        }
        
        System.debug('*** END: DRC_NBC_UpdateOrderAndLineItems.orderId ***');
        return resultMessage;
    }
    
    /**
* QUEUEABLE 1: Generate Ship-To Code (DML ONLY)
*/
    public class ShipToCodeGeneratorQueueable implements Queueable {
        private Id orderRecordId;
        private Id accountId;
        
        public ShipToCodeGeneratorQueueable(Id orderRecordId, Id accountId) {
            this.orderRecordId = orderRecordId;
            this.accountId = accountId;
        }
        
        public void execute(QueueableContext context) {
            System.debug('*** ShipToCodeGeneratorQueueable Started ***');
            
            try {
                System.debug('Step 1: Generating Ship-To Code...');
                DRC_NBC_ShipToCodeGenerator.assignShipToCodeSync(orderRecordId);
                System.debug('Ship-To Code generated successfully');
                
                System.debug('Step 2: Chaining to CalloutQueueable...');
                System.enqueueJob(new ShippingAndOrderCalloutQueueable(orderRecordId, accountId));
                
            } catch (Exception ex) {
                System.debug('*** EXCEPTION in ShipToCodeGeneratorQueueable ***');
                System.debug('Exception Message: ' + ex.getMessage());
                System.debug('Stack Trace: ' + ex.getStackTraceString());
            }
        }
    }
    
    /**
* QUEUEABLE 2: Execute Shipping Callout + Order Sync (CALLOUTS ONLY)
*/
    public class ShippingAndOrderCalloutQueueable implements Queueable, Database.AllowsCallouts {
        private Id orderRecordId;
        private Id accountId;
        
        public ShippingAndOrderCalloutQueueable(Id orderRecordId, Id accountId) {
            this.orderRecordId = orderRecordId;
            this.accountId = accountId;
        }
        
        public void execute(QueueableContext context) {
            System.debug('*** ShippingAndOrderCalloutQueueable Started ***');
            
            try {
                System.debug('Step 1: Executing Shipping Callout...');
                String shippingResult = DRC_NBC_Shipping_BC_Callout.processShipping(accountId, orderRecordId);
                System.debug('Shipping Callout Result: ' + shippingResult);
                
                System.debug('Step 2: Re-querying Order with updated Ship-To Code...');
                Order ord = DRC_NBC_Order_BC_Callout.getOrderDetails(orderRecordId);
                
                System.debug('Step 3: Processing Order Sync...');
                String orderSyncResult = processOrderSync(ord, accountId);
                System.debug('Order Sync Result: ' + orderSyncResult);
                
            } catch (Exception ex) {
                System.debug('*** EXCEPTION in ShippingAndOrderCalloutQueueable ***');
                System.debug('Exception Message: ' + ex.getMessage());
                System.debug('Stack Trace: ' + ex.getStackTraceString());
            }
        }
    }
    
    /**
* Process Order Sync - Main orchestration method
* CORRECTED EXECUTION ORDER:
* 1. Read Order from BC (get Key)
* 2. Update Order in BC
* 3. Intelligent Line Item Sync (UPDATE → CREATE → DELETE)
*/
    public static String processOrderSync(Order ord, Id accountId) {
        String resultMessage = '';
        
        try {
            // Step 1: Read Order from BC to get Key
            System.debug('Step 1: Reading Order from BC...');
            String bcKey = readOrderFromBC(ord);
            
            if (String.isBlank(bcKey)) {
                System.debug('ERROR: Could not retrieve BC Key');
                resultMessage = 'ERROR: Order not found in BC.';
                return resultMessage;
            }
            
            System.debug('BC Key Retrieved: ' + bcKey);
            
            // Step 2: Update Order in BC
            System.debug('Step 2: Updating Order in BC...');
            String orderResult = updateOrderInBC(bcKey, ord, false);
            System.debug('Order Update Result: ' + orderResult);
            
            // Step 3: If order update successful, sync line items
            if (orderResult.contains('SUCCESS')) {
                System.debug('Step 3: Order updated - Syncing line items...');
                String lineItemResult = intelligentLineItemSync(ord.DRC_NBC_Cust_Order_Number__c, ord.Id);
                System.debug('Line Items Sync Result: ' + lineItemResult);
                resultMessage = orderResult + ' | ' + lineItemResult;
            } else {
                System.debug('Step 3: Order update failed - Skipping line items');
                resultMessage = orderResult;
            }
            
        } catch (Exception ex) {
            System.debug('*** EXCEPTION in processOrderSync ***');
            System.debug('Exception Message: ' + ex.getMessage());
            resultMessage = 'ERROR: ' + ex.getMessage();
        }
        
        return resultMessage;
    }
    
    /**
* Intelligent Line Item Sync
* 
* CORRECTED WORKFLOW:
* 1. UPDATE: Update all matched line items (matched products + existing tax lines with non-zero amounts)
* 2. CREATE: Create new product items at next available line number
* 3. DELETE: Delete unmatched PRODUCT items ONLY (tax lines preserved)
* 4. DELETE TAX: Delete tax lines ONLY if amount changed from non-zero to zero
*/
    private static String intelligentLineItemSync(String bcOrderNo, Id orderId) {
        System.debug('  *** Intelligent Line Item Sync Started ***');
        System.debug('  BC Order Number: ' + bcOrderNo);
        
        try {
            // Step 1: Get existing BC line items with full details
            Map<Integer, BCLineItem> bcLineDetails = readMultipleLineItemsWithDetails(bcOrderNo, orderId);
            
            // Step 2: Query Salesforce OrderItems
            List<OrderItem> orderItems = [
                SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice, DRC_NBC_Discount__c,
                Order.DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c, Order.DRC_NBC_TCS_Amount__c,
                Order.DRC_NBC_Other_Tax_Amount__c, DRC_NBC_Total_Price__c, Order.DRC_NBC_Cust_Order_Number__c,
                Order.Account.DRC_NBC_Customer_Number__c, Order.RecordType.Name, Product2.DRC_NBC_FG_Code__c,
                Product2.DRC_NBC_GST_Group_Code__c, Product2.DRC_NBC_HSN_SAC_Code__c, DRC_NBC_Unit_Of_Measurement__c,
                Order.DRC_NBC_Warehouse__c
                FROM OrderItem WHERE OrderId = :orderId ORDER BY CreatedDate ASC
            ];
            
            // Step 3: Get Order for Tax amounts
            Order ord = [
                SELECT DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c, DRC_NBC_Cust_Order_Number__c, 
                RecordType.Name, DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c, DRC_NBC_Warehouse__c
                FROM Order WHERE Id = :orderId LIMIT 1
            ];
            
            System.debug('  SF Product Items: ' + orderItems.size());
            System.debug('  BC Line Items: ' + (bcLineDetails != null ? bcLineDetails.size() : 0));
            
            // Separate BC lines into products and taxes
            List<BCLineItem> bcProductLines = new List<BCLineItem>();
            Map<String, BCLineItem> bcTaxLines = new Map<String, BCLineItem>(); // Key: "TCS" or "OTHER_TAX"
            
            if (bcLineDetails != null) {
                for (BCLineItem bcLine : bcLineDetails.values()) {
                    if (bcLine.lineType == 'Item') {
                        bcProductLines.add(bcLine);
                    } else {
                        // Tax line
                        if (bcLine.description != null && bcLine.description.contains('TCS')) {
                            bcTaxLines.put('TCS', bcLine);
                        } else if (bcLine.description != null && bcLine.description.contains('Other Tax')) {
                            bcTaxLines.put('OTHER_TAX', bcLine);
                        }
                    }
                }
            }
            
            System.debug('  BC Product Lines: ' + bcProductLines.size());
            System.debug('  BC Tax Lines: ' + bcTaxLines.size());
            
            // Match SF items with BC product lines - MATCH BY FG CODE ONLY
            Map<Integer, String> linesToUpdate = new Map<Integer, String>();
            Set<Integer> matchedBCLineNos = new Set<Integer>();
            Set<String> matchedSFFGCodes = new Set<String>();
            List<OrderItem> itemsToCreate = new List<OrderItem>();
            
            // Create a map of BC lines by FG Code for easier lookup
            Map<String, BCLineItem> bcLinesByFGCode = new Map<String, BCLineItem>();
            for (BCLineItem bcLine : bcProductLines) {
                if (String.isNotBlank(bcLine.itemNo)) {
                    bcLinesByFGCode.put(bcLine.itemNo, bcLine);
                }
            }
            
            for (OrderItem sfItem : orderItems) {
                String sfFGCode = sfItem.Product2.DRC_NBC_FG_Code__c;
                
                // Try to match with BC product line BY FG CODE ONLY
                if (bcLinesByFGCode.containsKey(sfFGCode)) {
                    BCLineItem bcLine = bcLinesByFGCode.get(sfFGCode);
                    
                    if (!matchedBCLineNos.contains(bcLine.lineNo)) {
                        linesToUpdate.put(bcLine.lineNo, bcLine.key);
                        matchedBCLineNos.add(bcLine.lineNo);
                        matchedSFFGCodes.add(sfFGCode);
                        System.debug('  MATCHED for UPDATE: Line ' + bcLine.lineNo + ', FG Code: ' + sfFGCode);
                    }
                } else {
                    // No BC line with this FG Code - CREATE new item
                    itemsToCreate.add(sfItem);
                    System.debug('  NEW ITEM to CREATE: ' + sfFGCode);
                }
            }
            
            // Add tax lines to update list if they exist in BC AND have non-zero amounts in SF
            if (bcTaxLines.containsKey('OTHER_TAX')) {
                if (ord.DRC_NBC_Other_Tax_Amount__c != null && ord.DRC_NBC_Other_Tax_Amount__c != 0) {
                    BCLineItem taxLine = bcTaxLines.get('OTHER_TAX');
                    linesToUpdate.put(taxLine.lineNo, taxLine.key);
                    System.debug('  OTHER TAX line added to UPDATE list (amount: ' + ord.DRC_NBC_Other_Tax_Amount__c + ')');
                }
            }
            if (bcTaxLines.containsKey('TCS')) {
                if (ord.DRC_NBC_TCS_Amount__c != null && ord.DRC_NBC_TCS_Amount__c != 0) {
                    BCLineItem taxLine = bcTaxLines.get('TCS');
                    linesToUpdate.put(taxLine.lineNo, taxLine.key);
                    System.debug('  TCS line added to UPDATE list (amount: ' + ord.DRC_NBC_TCS_Amount__c + ')');
                }
            }
            
            // Find unmatched BC PRODUCT lines to delete (EXCLUDE TAX LINES)
            Map<Integer, String> linesToDelete = new Map<Integer, String>();
            for (BCLineItem bcLine : bcProductLines) {
                if (!matchedBCLineNos.contains(bcLine.lineNo)) {
                    linesToDelete.put(bcLine.lineNo, bcLine.key);
                    System.debug('  UNMATCHED PRODUCT for DELETE: Line ' + bcLine.lineNo);
                }
            }
            
            // CRITICAL: Tax lines are ONLY deleted if their amount changed to ZERO
            // If tax exists in BC and SF still has non-zero amount, it stays (will be updated)
            if (bcTaxLines.containsKey('OTHER_TAX')) {
                if (ord.DRC_NBC_Other_Tax_Amount__c == null || ord.DRC_NBC_Other_Tax_Amount__c == 0) {
                    BCLineItem taxLine = bcTaxLines.get('OTHER_TAX');
                    linesToDelete.put(taxLine.lineNo, taxLine.key);
                    linesToUpdate.remove(taxLine.lineNo); // Remove from update list
                    System.debug('  OTHER TAX line marked for DELETE (amount changed to zero)');
                } else {
                    System.debug('  OTHER TAX line PRESERVED (amount: ' + ord.DRC_NBC_Other_Tax_Amount__c + ')');
                }
            }
            
            if (bcTaxLines.containsKey('TCS')) {
                if (ord.DRC_NBC_TCS_Amount__c == null || ord.DRC_NBC_TCS_Amount__c == 0) {
                    BCLineItem taxLine = bcTaxLines.get('TCS');
                    linesToDelete.put(taxLine.lineNo, taxLine.key);
                    linesToUpdate.remove(taxLine.lineNo); // Remove from update list
                    System.debug('  TCS line marked for DELETE (amount changed to zero)');
                } else {
                    System.debug('  TCS line PRESERVED (amount: ' + ord.DRC_NBC_TCS_Amount__c + ')');
                }
            }
            
            String resultMessage = '';
            
            // ====================================================================
            // STEP 1: UPDATE existing matched lines (products + taxes)
            // ====================================================================
            String updateResult = '';
            if (!linesToUpdate.isEmpty()) {
                System.debug('  STEP 1: Updating ' + linesToUpdate.size() + ' existing lines...');
                updateResult = updateMultipleLineItems(bcOrderNo, linesToUpdate, orderItems, ord, orderId, bcLineDetails);
                System.debug('  Update Result: ' + updateResult);
            }
            
            // ====================================================================
            // STEP 2: CREATE new product items (at next available line number)
            // ====================================================================
            String createResult = '';
            if (!itemsToCreate.isEmpty()) {
                // Calculate next available line number
                Integer maxLineNo = 0;
                if (bcLineDetails != null && !bcLineDetails.isEmpty()) {
                    for (Integer lineNo : bcLineDetails.keySet()) {
                        if (lineNo > maxLineNo) {
                            maxLineNo = lineNo;
                        }
                    }
                }
                
                // Next line starts at maxLineNo + 10000
                Integer nextLineNo = maxLineNo + 10000;
                System.debug('  STEP 2: Creating ' + itemsToCreate.size() + ' new items starting at line ' + nextLineNo);
                
                createResult = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
                    bcOrderNo, itemsToCreate, ord, nextLineNo
                );
                System.debug('  Create Result: ' + createResult);
            }
            
            // ====================================================================
            // STEP 3: DELETE unmatched lines (products + zeroed taxes)
            // ====================================================================
            String deleteResult = '';
            if (!linesToDelete.isEmpty()) {
                System.debug('  STEP 3: Deleting ' + linesToDelete.size() + ' unmatched/zeroed lines...');
                deleteResult = DRC_NBC_LineItemDeleter.deleteLineItems(linesToDelete);
                System.debug('  Delete Result: ' + deleteResult);
            }
            
            // Build result message
            resultMessage = 'UPDATE: ' + updateResult + ' | CREATE: ' + createResult + ' | DELETE: ' + deleteResult;
            return resultMessage;
            
        } catch (Exception ex) {
            System.debug('  *** Intelligent Sync Exception ***');
            System.debug('  Exception Message: ' + ex.getMessage());
            System.debug('  Stack Trace: ' + ex.getStackTraceString());
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    /**
* READ Operation - Get BC Key for Order
*/
    private static String readOrderFromBC(Order ord) {
        System.debug('  *** READ Order Operation Started ***');
        
        try {
            String requestBody = buildReadSOAPRequest(ord.DRC_NBC_Cust_Order_Number__c);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_ORDER_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_ORDER_NAMESPACE + ':Read');
            
            Blob headerValue = Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD);
            String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
            req.setHeader('Authorization', authorizationHeader);
            
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse response = http.send(req);
            
            System.debug('  Read Response Status Code: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                String key = extractKeyFromReadResponse(response.getBody());
                System.debug('  Key Extracted: ' + key);
                return key;
            } else {
                System.debug('  ERROR: Read failed with status: ' + response.getStatusCode());
                return null;
            }
            
        } catch (Exception ex) {
            System.debug('  *** READ Exception: ' + ex.getMessage());
            return null;
        }
    }
    
    /**
* UPDATE Order Operation
*/
    private static String updateOrderInBC(String bcKey, Order ord, Boolean updateSF) {
        System.debug('  *** UPDATE Order Operation Started ***');
        System.debug('  BC Key: ' + bcKey);
        
        try {
            DRC_NBC_Integration_Payload.OrderPayload payload = DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
            
            // Fetch Location_Code from metadata if not already set
            if (String.isNotBlank(ord.DRC_NBC_Warehouse__c)) {
                String warehouseLabel = ord.DRC_NBC_Warehouse__c;
                System.debug('Class DRC_NBC_UpdateOrderAndLineItems warehouseLabel>>>  '+ warehouseLabel);
                List<Warehouse_Location_Code__mdt> metaList = [
                    SELECT DRC_NBC_Code__c FROM Warehouse_Location_Code__mdt
                    WHERE MasterLabel = :warehouseLabel AND DRC_NBC_Type__c = 'Warehouse Location'
                    LIMIT 1
                ];
                if (!metaList.isEmpty()) {
                    payload.Location_Code = metaList[0].DRC_NBC_Code__c;
                    System.debug('  Location_Code from metadata: ' + payload.Location_Code);
                }
            }
            
            String requestBody = buildUpdateOrderSOAPRequest(bcKey, payload, ord);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_ORDER_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_ORDER_NAMESPACE + ':Update');
            
            Blob headerValue = Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD);
            String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
            req.setHeader('Authorization', authorizationHeader);
            
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse response = http.send(req);
            
            System.debug('  Update Response Status Code: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                System.debug('  Order Updated Successfully in BC');
                return 'ORDER_UPDATE_SUCCESS';
            } else {
                System.debug('  ERROR: Update failed - ' + response.getStatusCode());
                return 'FAILURE: ' + response.getStatusCode();
            }
            
        } catch (Exception ex) {
            System.debug('  *** UPDATE Exception: ' + ex.getMessage());
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    /**
* ReadMultiple - Get existing line items from BC WITH FULL DETAILS
*/
    private static Map<Integer, BCLineItem> readMultipleLineItemsWithDetails(String bcOrderNo, Id orderId) {
        System.debug('    *** ReadMultiple Line Items Started ***');
        
        Map<Integer, BCLineItem> lineDetailsMap = new Map<Integer, BCLineItem>();
        
        try {
            String requestBody = buildReadMultipleSOAPRequest(bcOrderNo);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_LINE_ITEM_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_LINE_NAMESPACE + ':ReadMultiple');
            
            Blob headerValue = Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD);
            String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
            req.setHeader('Authorization', authorizationHeader);
            
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse response = http.send(req);
            
            System.debug('    ReadMultiple Response Status: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                lineDetailsMap = extractLineDetailsFromReadMultiple(response.getBody());
                System.debug('    Extracted ' + lineDetailsMap.size() + ' line items');
                return lineDetailsMap;
            } else {
                System.debug('    ERROR: ReadMultiple failed - ' + response.getStatusCode());
                return null;
            }
            
        } catch (Exception ex) {
            System.debug('    *** ReadMultiple Exception: ' + ex.getMessage());
            return null;
        }
    }
    
    /**
* UpdateMultiple - Update line items in BC
* CORRECTED: Properly matches BC Keys with their corresponding items (products vs taxes)
*/
    private static String updateMultipleLineItems(String bcOrderNo, Map<Integer, String> bcLineKeys, 
                                                  List<OrderItem> orderItems, Order ord, Id orderId,
                                                  Map<Integer, BCLineItem> bcLineDetails) {
        System.debug('    *** UpdateMultiple Started ***');
        
        try {
            String requestBody = buildUpdateMultipleSOAPRequest(bcOrderNo, bcLineKeys, orderItems, ord, bcLineDetails);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_LINE_ITEM_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_LINE_NAMESPACE + ':UpdateMultiple');
            
            Blob headerValue = Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD);
            String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
            req.setHeader('Authorization', authorizationHeader);
            
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse response = http.send(req);
            
            System.debug('    UpdateMultiple Response Status: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                return 'SUCCESS';
            } else {
                System.debug('    Response Body: ' + response.getBody());
                return 'FAILURE: ' + response.getStatusCode();
            }
            
        } catch (Exception ex) {
            System.debug('    *** UpdateMultiple Exception: ' + ex.getMessage());
            System.debug('    Stack Trace: ' + ex.getStackTraceString());
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    // ========================================================================
    // SOAP REQUEST BUILDERS
    // ========================================================================
    
    private static String buildReadSOAPRequest(String bcOrderNumber) {
        return 
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read xmlns="' + SOAP_ORDER_NAMESPACE + '">' +
            '<No>' + escapeXml(bcOrderNumber) + '</No>' +
            '</Read>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    private static String buildUpdateOrderSOAPRequest(String bcKey, DRC_NBC_Integration_Payload.OrderPayload payload, Order ord) {
        return 
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Update xmlns="' + SOAP_ORDER_NAMESPACE + '">' +
            '<SalesOrderSalesForce>' +
            '<Key>' + escapeXml(bcKey) + '</Key>' +
            '<No>' + escapeXml(payload.No) + '</No>' +
            '<Sell_to_Customer_No>' + escapeXml(payload.Sell_to_Customer_No) + '</Sell_to_Customer_No>' +
            '<Sell_to_Customer_Name>' + escapeXml(payload.Sell_to_Customer_Name) + '</Sell_to_Customer_Name>' +
            '<Sell_to_Address>' + escapeXml(payload.Sell_to_Address) + '</Sell_to_Address>' +
            '<Sell_to_Address_2>' + escapeXml(payload.Sell_to_Address_2) + '</Sell_to_Address_2>' +
            '<Sell_to_City>' + escapeXml(payload.Sell_to_City) + '</Sell_to_City>' +
            '<Sell_to_Post_Code>' + escapeXml(payload.Sell_to_Post_Code) + '</Sell_to_Post_Code>' +
            '<Order_Date>' + escapeXml(payload.Order_Date) + '</Order_Date>' +
            '<External_Document_No>' + escapeXml(payload.External_Document_No) + '</External_Document_No>' +
            '<Salesperson_Code>' + escapeXml(payload.Salesperson_Code) + '</Salesperson_Code>' +
            '<Status>' + escapeXml(payload.Status) + '</Status>' +
            '<Location_Code>' + escapeXml(payload.Location_Code) + '</Location_Code>' +
            //'<Location_Code>CFS</Location_Code>' +
            '<Payment_Terms_Code>' + escapeXml(payload.Payment_Terms_Code) + '</Payment_Terms_Code>' +
            '<Shipment_Method_Code>' + escapeXml(payload.Shipment_Method_Code) + '</Shipment_Method_Code>' +
            '<Sample_Sales>' + payload.Sample_Sales + '</Sample_Sales>' +
            '<Salesforce_So_No>' + escapeXml(payload.Salesforce_So_No) + '</Salesforce_So_No>' +
            '<Ship_to_Code>' + escapeXml(payload.Ship_to_Code) + '</Ship_to_Code>' +
            '<Ship_to_Name>' + escapeXml(payload.Ship_to_Name) + '</Ship_to_Name>' +
            '<Ship_to_Name_2>' + escapeXml(payload.Ship_to_Name_2) + '</Ship_to_Name_2>' +
            '<Ship_to_Address>' + escapeXml(payload.Ship_to_Address) + '</Ship_to_Address>' +
            '<Ship_to_Address_2>' + escapeXml(payload.Ship_to_Address_2) + '</Ship_to_Address_2>' +
            '<Ship_to_Post_Code>' + escapeXml(payload.Ship_to_Post_Code) + '</Ship_to_Post_Code>' +
            '<Ship_to_Country_Region_Code>' + escapeXml(payload.Ship_to_Country_Region_Code) + '</Ship_to_Country_Region_Code>' +
            '<Salesforce_Order_Amount>' + payload.Salesforce_Order_Amount + '</Salesforce_Order_Amount>' +
            '<Salesforce_Order_Created>' + payload.Salesforce_Order_Created + '</Salesforce_Order_Created>' +
            '</SalesOrderSalesForce>' +
            '</Update>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    private static String buildReadMultipleSOAPRequest(String bcOrderNo) {
        return 
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<ReadMultiple xmlns="' + SOAP_LINE_NAMESPACE + '">' +
            '<filter>' +
            '<Field>Document_No</Field>' +
            '<Criteria>' + escapeXml(bcOrderNo) + '</Criteria>' +
            '</filter>' +
            '<setSize>100</setSize>' +
            '</ReadMultiple>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    /**
* Build UpdateMultiple SOAP Request
* CORRECTED: Properly matches BC Keys with their corresponding items (products vs taxes)
*/
    private static String buildUpdateMultipleSOAPRequest(String bcOrderNo, Map<Integer, String> bcLineKeys, 
                                                         List<OrderItem> orderItems, Order ord,
                                                         Map<Integer, BCLineItem> bcLineDetails) {
        System.debug('    *** buildUpdateMultipleSOAPRequest Started ***');
        System.debug('    BC Line Keys to Update: ' + bcLineKeys.keySet());
        
        String soapBody = 
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<UpdateMultiple xmlns="' + SOAP_LINE_NAMESPACE + '">' +
            '<SalesOrderLineSalesForce_List>';
        
        // Separate product keys from tax keys using bcLineDetails
        Map<Integer, String> productKeys = new Map<Integer, String>();
        Map<String, String> taxKeys = new Map<String, String>(); // Map: "TCS" or "OTHER_TAX" -> bcKey
        Map<String, Integer> taxLineNos = new Map<String, Integer>(); // Map: "TCS" or "OTHER_TAX" -> lineNo
        
        for (Integer lineNo : bcLineKeys.keySet()) {
            String bcKey = bcLineKeys.get(lineNo);
            BCLineItem bcLine = bcLineDetails.get(lineNo);
            
            if (bcLine != null) {
                if (bcLine.lineType == 'Item') {
                    productKeys.put(lineNo, bcKey);
                    System.debug('    Product Key: Line ' + lineNo + ' -> ' + bcKey);
                } else {
                    // Tax line
                    if (bcLine.description != null && bcLine.description.contains('TCS')) {
                        taxKeys.put('TCS', bcKey);
                        taxLineNos.put('TCS', lineNo);
                        System.debug('    TCS Key: Line ' + lineNo + ' -> ' + bcKey);
                    } else if (bcLine.description != null && bcLine.description.contains('Other Tax')) {
                        taxKeys.put('OTHER_TAX', bcKey);
                        taxLineNos.put('OTHER_TAX', lineNo);
                        System.debug('    Other Tax Key: Line ' + lineNo + ' -> ' + bcKey);
                    }
                }
            }
        }
        
        // Sort product line numbers to maintain order
        List<Integer> sortedProductLineNos = new List<Integer>(productKeys.keySet());
        sortedProductLineNos.sort();
        
        System.debug('    Sorted Product Lines: ' + sortedProductLineNos);
        System.debug('    Number of OrderItems: ' + orderItems.size());
        
        // Update Product Items - Match by FG Code ONLY (not quantity)
        Map<String, OrderItem> sfItemsByFGCode = new Map<String, OrderItem>();
        for (OrderItem item : orderItems) {
            String fgCode = item.Product2.DRC_NBC_FG_Code__c;
            sfItemsByFGCode.put(fgCode, item);
            System.debug('    SF Item mapped: ' + fgCode);
        }
        
        for (Integer lineNo : sortedProductLineNos) {
            String bcKey = productKeys.get(lineNo);
            BCLineItem bcLine = bcLineDetails.get(lineNo);
            
            if (bcLine == null) {
                System.debug('    WARNING: BC Line ' + lineNo + ' not found in details');
                continue;
            }
            
            // Find matching SF item by FG Code ONLY
            String fgCode = bcLine.itemNo;
            OrderItem matchedItem = sfItemsByFGCode.get(fgCode);
            
            if (matchedItem != null) {
                System.debug('    Updating Product Line ' + lineNo + ': ' + fgCode + ' (Qty: ' + matchedItem.Quantity + ')');
                
                Boolean isSampleOrder = matchedItem.Order.RecordType.Name == 'Sample_Order';
                Decimal discountPercent = matchedItem.DRC_NBC_Discount__c != null ? matchedItem.DRC_NBC_Discount__c : 0;
                Decimal totalPrice = matchedItem.DRC_NBC_Total_Price__c != null ? matchedItem.DRC_NBC_Total_Price__c : 0;
                Decimal lineDiscountAmount = (totalPrice * discountPercent) / 100;
                
                if (isSampleOrder) {
                    totalPrice = 0;
                    lineDiscountAmount = 0;
                }
                
                soapBody += 
                    '<SalesOrderLineSalesForce>' +
                    '<Key>' + escapeXml(bcKey) + '</Key>' +
                    '<Document_No>' + escapeXml(bcOrderNo) + '</Document_No>' +
                    '<Line_No>' + lineNo + '</Line_No>' +
                    '<No>' + escapeXml(matchedItem.Product2.DRC_NBC_FG_Code__c) + '</No>' +
                    '<Description>' + escapeXml(matchedItem.Description != null ? matchedItem.Description : '') + '</Description>' +
                    '<Quantity>' + (matchedItem.Quantity != null ? matchedItem.Quantity : 0) + '</Quantity>' +
                    '<Unit_of_Measure_Code>' + escapeXml(matchedItem.DRC_NBC_Unit_Of_Measurement__c) + '</Unit_of_Measure_Code>' +
                    '<Unit_Price>' + (isSampleOrder ? 0 : (matchedItem.UnitPrice != null ? matchedItem.UnitPrice : 0)) + '</Unit_Price>' +
                    '<Line_Amount>' + totalPrice + '</Line_Amount>' +
                    '<Line_Discount_Percent>' + discountPercent + '</Line_Discount_Percent>' +
                    '<Line_Discount_Amount>' + lineDiscountAmount + '</Line_Discount_Amount>' +
                    '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                    '<GST_Credit>' + GST_CREDIT_VALUE + '</GST_Credit>' +
                    '<GST_Group_Code>' + escapeXml(matchedItem.Product2.DRC_NBC_GST_Group_Code__c) + '</GST_Group_Code>' +
                    '<HSN_SAC_Code>' + escapeXml(matchedItem.Product2.DRC_NBC_HSN_SAC_Code__c) + '</HSN_SAC_Code>' +
                    '</SalesOrderLineSalesForce>';
            } else {
                System.debug('    WARNING: No matching SF item for BC Line ' + lineNo);
            }
        }
        
        // Update Other Tax Line (if exists and has non-zero amount)
        if (taxKeys.containsKey('OTHER_TAX') && 
            ord.DRC_NBC_Other_Tax_Amount__c != null && 
            ord.DRC_NBC_Other_Tax_Amount__c != 0) {
            
            String otherTaxKey = taxKeys.get('OTHER_TAX');
            Integer otherTaxLineNo = taxLineNos.get('OTHER_TAX');
            
            System.debug('    Updating Other Tax Line ' + otherTaxLineNo + ': ' + ord.DRC_NBC_Other_Tax_Amount__c);
            
            soapBody += 
                '<SalesOrderLineSalesForce>' +
                '<Key>' + escapeXml(otherTaxKey) + '</Key>' +
                '<Document_No>' + escapeXml(bcOrderNo) + '</Document_No>' +
                '<Line_No>' + otherTaxLineNo + '</Line_No>' +
                '<Description>Other Tax Amount</Description>' +
                '<Quantity>1</Quantity>' +
                '<Unit_Price>' + ord.DRC_NBC_Other_Tax_Amount__c + '</Unit_Price>' +
                '<Line_Amount>' + ord.DRC_NBC_Other_Tax_Amount__c + '</Line_Amount>' +
                '<Line_Discount_Percent>0</Line_Discount_Percent>' +
                '<Line_Discount_Amount>0</Line_Discount_Amount>' +
                '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                '<GST_Credit>_blank_</GST_Credit>' +
                '</SalesOrderLineSalesForce>';
        }
        
        // Update TCS Amount Line (if exists and has non-zero amount)
        if (taxKeys.containsKey('TCS') && 
            ord.DRC_NBC_TCS_Amount__c != null && 
            ord.DRC_NBC_TCS_Amount__c != 0) {
            
            String tcsKey = taxKeys.get('TCS');
            Integer tcsLineNo = taxLineNos.get('TCS');
            
            System.debug('    Updating TCS Line ' + tcsLineNo + ': ' + ord.DRC_NBC_TCS_Amount__c);
            
            soapBody += 
                '<SalesOrderLineSalesForce>' +
                '<Key>' + escapeXml(tcsKey) + '</Key>' +
                '<Document_No>' + escapeXml(bcOrderNo) + '</Document_No>' +
                '<Line_No>' + tcsLineNo + '</Line_No>' +
                '<Description>TCS Amount</Description>' +
                '<Quantity>1</Quantity>' +
                '<Unit_Price>' + ord.DRC_NBC_TCS_Amount__c + '</Unit_Price>' +
                '<Line_Amount>' + ord.DRC_NBC_TCS_Amount__c + '</Line_Amount>' +
                '<Line_Discount_Percent>0</Line_Discount_Percent>' +
                '<Line_Discount_Amount>0</Line_Discount_Amount>' +
                '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                '<GST_Credit>_blank_</GST_Credit>' +
                '</SalesOrderLineSalesForce>';
        }
        
        soapBody += 
            '</SalesOrderLineSalesForce_List>' +
            '</UpdateMultiple>' +
            '</soap:Body>' +
            '</soap:Envelope>';
        
        System.debug('    *** buildUpdateMultipleSOAPRequest Completed ***');
        return soapBody;
    }
    
    // ========================================================================
    // RESPONSE PARSERS
    // ========================================================================
    
    private static String extractKeyFromReadResponse(String xmlResponse) {
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlResponse);
            Dom.XmlNode root = doc.getRootElement();
            
            for (Dom.XmlNode bodyNode : root.getChildElements()) {
                if (bodyNode.getName().contains('Body')) {
                    for (Dom.XmlNode resultNode : bodyNode.getChildElements()) {
                        if (resultNode.getName().contains('Read_Result')) {
                            for (Dom.XmlNode salesOrderNode : resultNode.getChildElements()) {
                                if (salesOrderNode.getName().contains('SalesOrderSalesForce')) {
                                    for (Dom.XmlNode fieldNode : salesOrderNode.getChildElements()) {
                                        if (fieldNode.getName() == 'Key') {
                                            return fieldNode.getText();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            return null;
        } catch (Exception ex) {
            System.debug('Exception extracting Key: ' + ex.getMessage());
            return null;
        }
    }
    
    private static Map<Integer, BCLineItem> extractLineDetailsFromReadMultiple(String xmlResponse) {
        Map<Integer, BCLineItem> lineDetailsMap = new Map<Integer, BCLineItem>();
        
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlResponse);
            Dom.XmlNode root = doc.getRootElement();
            
            for (Dom.XmlNode bodyNode : root.getChildElements()) {
                if (bodyNode.getName().contains('Body')) {
                    for (Dom.XmlNode resultNode : bodyNode.getChildElements()) {
                        if (resultNode.getName().contains('ReadMultiple_Result')) {
                            for (Dom.XmlNode innerResultNode : resultNode.getChildElements()) {
                                if (innerResultNode.getName().contains('ReadMultiple_Result')) {
                                    for (Dom.XmlNode lineNode : innerResultNode.getChildElements()) {
                                        if (lineNode.getName().contains('SalesOrderLineSalesForce')) {
                                            String key = null;
                                            Integer lineNo = null;
                                            String lineType = null;
                                            String itemNo = null;
                                            Decimal quantity = null;
                                            String description = null;
                                            
                                            for (Dom.XmlNode fieldNode : lineNode.getChildElements()) {
                                                String fieldName = fieldNode.getName();
                                                
                                                if (fieldName == 'Key') {
                                                    key = fieldNode.getText();
                                                } else if (fieldName == 'Line_No') {
                                                    lineNo = Integer.valueOf(fieldNode.getText());
                                                } else if (fieldName == 'Type') {
                                                    lineType = fieldNode.getText();
                                                } else if (fieldName == 'No') {
                                                    itemNo = fieldNode.getText();
                                                } else if (fieldName == 'Quantity') {
                                                    String qtyText = fieldNode.getText();
                                                    if (String.isNotBlank(qtyText)) {
                                                        quantity = Decimal.valueOf(qtyText);
                                                    }
                                                } else if (fieldName == 'Description') {
                                                    description = fieldNode.getText();
                                                }
                                            }
                                            
                                            if (key != null && lineNo != null) {
                                                BCLineItem bcLine = new BCLineItem(key, lineNo, lineType, itemNo, quantity, description);
                                                lineDetailsMap.put(lineNo, bcLine);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            return lineDetailsMap;
            
        } catch (Exception ex) {
            System.debug('Exception extracting line details: ' + ex.getMessage());
            return lineDetailsMap;
        }
    }
    
    private static String escapeXml(String value) {
        if (String.isBlank(value)) return '';
        return value.escapeXml();
    }
}