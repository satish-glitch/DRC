/**
* @File Name : DRC_NBC_UpdateOrderAndLineItems.cls
* @Description : Handles Order and Line Items sync with Business Central using SOAP
* @Author : Satish YADAV
* @Last Modified On : April 17, 2026
* * 1. Generate Ship-To Code (if missing)
* 2. Read Order from BC - check status, if Released → reopen to Open, re-read for fresh Key
* 3. Update Order in BC
* 4. UPDATE existing line items (matched products + existing taxes)
* 5. CREATE new line items (new products only - tax lines never created here)
* 6. DELETE unmatched PRODUCT line items ONLY
* 7. DELETE tax lines ONLY if amounts changed from non-zero to zero
*
* LOGGING STRATEGY:
* - Each callout logs API log ONLY on failure (non-200 or exception), with request + response body
* - On failure, process halts immediately - no further steps are executed
* - On full success, ONE final success log is written at end of processOrderSync
**/
public class DRC_NBC_UpdateOrderAndLineItems {
    
    // Custom Setting Instance
    public static DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();
    
    // BC Endpoints from Custom Setting
    public static final String BC_ORDER_ENDPOINT     = bcSettings.DRC_NBC_BC_Order_Endpoint__c;
    public static final String BC_LINE_ITEM_ENDPOINT = bcSettings.DRC_NBC_BC_Line_Item_Endpoint__c;
    public static final String SOAP_ORDER_NAMESPACE  = bcSettings.DRC_NBC_SOAP_Order_Namespace__c;
    public static final String SOAP_LINE_NAMESPACE   = bcSettings.DRC_NBC_SOAP_Line_Namespace__c;
    public static final String GST_CREDIT_VALUE      = bcSettings.DRC_NBC_GST_Credit_Value__c;
    
    // Authentication credentials from Custom Setting
    public static final String BC_USERNAME = bcSettings.DRC_NBC_Username__c;
    public static final String BC_PASSWORD = bcSettings.DRC_NBC_Password__c;
    
    // Log Type constants
    private static final String LOG_TYPE_ERROR   = 'Error';
    private static final String LOG_TYPE_SUCCESS = 'Success';
    
    // ========================================================================
    // INNER CLASSES
    // ========================================================================
    
    /** Holds BC Order Read result (Key + Status) */
    public class BCOrderReadResult {
        public String key;
        public String status;
        public BCOrderReadResult(String key, String status) {
            this.key    = key;
            this.status = status;
        }
    }
    
    /** Holds BC Line Item details for intelligent matching */
    public class BCLineItem {
        public String  key;
        public Integer lineNo;
        public String  lineType;
        public String  itemNo;
        public Decimal quantity;
        public String  description;
        public BCLineItem(String k, Integer ln, String lt, String item, Decimal qty, String des) {
            this.key         = k;
            this.lineNo      = ln;
            this.lineType    = lt;
            this.itemNo      = item;
            this.quantity    = qty;
            this.description = des;
        }
    }
    
    // ========================================================================
    // ENTRY POINT
    // ========================================================================
    
    /**
* Main entry point - called from DRC_NBC_Order_BC_Callout
* Handles Ship-To Code generation if needed, then processes order sync
*/
    public static String orderId(Id orderRecordId) {
        System.debug('*** START: DRC_NBC_UpdateOrderAndLineItems.orderId ***');
        System.debug('Order Record ID: ' + orderRecordId);
        
        if (bcSettings == null || String.isBlank(BC_ORDER_ENDPOINT) || String.isBlank(BC_USERNAME)) {
            String errorMsg = 'ERROR: Business Central settings not configured. Please setup DRC_NBC_BC_Integration__c Custom Setting.';
            System.debug(errorMsg);
            return errorMsg;
        }
        
        String resultMessage = '';
        
        try {
            System.debug('Step 1: Querying Order details...');
            Order ord       = DRC_NBC_Order_BC_Callout.getOrderDetails(orderRecordId);
            Id    accountId = ord.AccountId;
            
            System.debug('Order Number: '             + ord.OrderNumber);
            System.debug('BC Customer Order Number: ' + ord.DRC_NBC_Cust_Order_Number__c);
            System.debug('Customer Number: '          + ord.Account.DRC_NBC_Customer_Number__c);
            System.debug('Ship To Code: '             + ord.DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c);
            
            if (ord.DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c != null) {
                Boolean callShipping = DRC_NBC_CheckShiipingDetails.checkShippingExists(orderRecordId, accountId);
                if (callShipping) {
                    System.enqueueJob(new ShippingCalloutQueueable(orderRecordId, accountId));
                } else {
                    System.enqueueJob(new OrderSyncQueueable(orderRecordId, accountId));
                }
                resultMessage = 'QUEUED: Ship-To Code generation started. Shipping and Order sync will follow.';
                System.debug(resultMessage);
                return resultMessage;
            } else {
                System.debug('Ship-To Code already present. Proceeding with Order sync.');
                resultMessage = processOrderSync(ord, accountId);
            }
            
        } catch (Exception ex) {
            System.debug('*** EXCEPTION in orderId: ' + ex.getMessage());
            resultMessage = 'ERROR: ' + ex.getMessage();
        }
        
        System.debug('*** END: DRC_NBC_UpdateOrderAndLineItems.orderId ***');
        return resultMessage;
    }
    
    // ========================================================================
    // QUEUEABLE CHAIN
    // ========================================================================
    
    public class ShippingCalloutQueueable implements Queueable, Database.AllowsCallouts {
        private Id orderRecordId;
        private Id accountId;
        
        public ShippingCalloutQueueable(Id orderRecordId, Id accountId) {
            this.orderRecordId = orderRecordId;
            this.accountId     = accountId;
        }
        
        public void execute(QueueableContext context) {
            System.debug('*** ShippingCalloutQueueable Started ***');
            try {
                String shippingResult = DRC_NBC_Shipping_BC_Callout.processShipping(accountId, orderRecordId);
                System.debug('Shipping Callout Result: ' + shippingResult);
                System.enqueueJob(new OrderSyncQueueable(orderRecordId, accountId));
            } catch (Exception ex) {
                System.debug('*** EXCEPTION in ShippingCalloutQueueable: ' + ex.getMessage());
            }
        }
    }
    
    public class OrderSyncQueueable implements Queueable, Database.AllowsCallouts {
        private Id orderRecordId;
        private Id accountId;
        
        public OrderSyncQueueable(Id orderRecordId, Id accountId) {
            this.orderRecordId = orderRecordId;
            this.accountId     = accountId;
        }
        
        public void execute(QueueableContext context) {
            System.debug('*** OrderSyncQueueable Started ***');
            try {
                Order  ord             = DRC_NBC_Order_BC_Callout.getOrderDetails(orderRecordId);
                String orderSyncResult = processOrderSync(ord, accountId);
                System.debug('Order Sync Result: ' + orderSyncResult);
            } catch (Exception ex) {
                System.debug('*** EXCEPTION in OrderSyncQueueable: ' + ex.getMessage());
            }
        }
    }
    
    // ========================================================================
    // MAIN ORCHESTRATION
    // ========================================================================
    
    /**
* Orchestrates the full order sync flow.
*
* Failure behaviour:
*   - Each callout method logs its OWN API error log (with request + response body)
*     the moment it fails, then returns null / ERROR / FAILURE string.
*   - The caller checks the return value and returns immediately without proceeding.
*   - The final SUCCESS log is only written when ALL steps complete successfully.
*/
    public static String processOrderSync(Order ord, Id accountId) {
        String resultMessage = '';
        String sfOrderId     = String.valueOf(ord.Id);
        
        try {
            
            // -----------------------------------------------------------------
            // STEP 1: READ ORDER FROM BC
            // Failure → readOrderFromBC already logged → return immediately
            // -----------------------------------------------------------------
            System.debug('Step 1: Reading Order from BC...');
            BCOrderReadResult readResult = readOrderFromBC(ord);
            
            if (readResult == null || String.isBlank(readResult.key)) {
                return 'ERROR: Read Order from BC failed. Process halted.';
            }
            
            System.debug('BC Key: ' + readResult.key + ' | Status: ' + readResult.status);
            String bcKey = readResult.key;
            
            // -----------------------------------------------------------------
            // STEP 2: REOPEN IF RELEASED
            // Failure → reopenOrderInBC already logged → return immediately
            // -----------------------------------------------------------------
            if (readResult.status == 'Released') {
                System.debug('Step 2: Order is Released. Reopening...');
                String reopenResult = reopenOrderInBC(bcKey, ord);
                
                if (reopenResult.startsWith('ERROR') || reopenResult.startsWith('FAILURE')) {
                    return 'ERROR: Reopen Released Order failed. Process halted. Detail: ' + reopenResult;
                }
                
                // Re-read for fresh Key after reopen
                // Failure → readOrderFromBC already logged → return immediately
                System.debug('Step 2b: Re-reading Order for fresh Key after reopen...');
                BCOrderReadResult freshRead = readOrderFromBC(ord);
                
                if (freshRead == null || String.isBlank(freshRead.key)) {
                    return 'ERROR: Re-read after Reopen failed. Process halted.';
                }
                
                bcKey = freshRead.key;
                System.debug('Fresh Key: ' + bcKey + ' | Status: ' + freshRead.status);
                
            } else {
                System.debug('Step 2: Order is Open. No reopen needed.');
            }
            
            // -----------------------------------------------------------------
            // STEP 3: UPDATE ORDER IN BC
            // Failure → updateOrderInBC already logged → return immediately
            // -----------------------------------------------------------------
            System.debug('Step 3: Updating Order in BC...');
            String orderUpdateResult = updateOrderInBC(bcKey, ord, false);
            
            if (orderUpdateResult.startsWith('ERROR') || orderUpdateResult.startsWith('FAILURE')) {
                return 'ERROR: Update Order in BC failed. Process halted. Detail: ' + orderUpdateResult;
            }
            
            System.debug('Order Update Result: ' + orderUpdateResult);
            
            // -----------------------------------------------------------------
            // STEP 4: INTELLIGENT LINE ITEM SYNC
            // Failure → inner callout already logged → return immediately
            // -----------------------------------------------------------------
            System.debug('Step 4: Syncing Line Items...');
            String lineItemResult = intelligentLineItemSync(ord.DRC_NBC_Cust_Order_Number__c, ord.Id);
            
            if (lineItemResult.startsWith('ERROR')) {
                return 'ERROR: Line Item Sync failed. Process halted. Detail: ' + lineItemResult;
            }
            
            System.debug('Line Items Sync Result: ' + lineItemResult);
            
            // All steps passed
            resultMessage = 'ORDER_UPDATE_SUCCESS | ' + lineItemResult;
            
        } catch (Exception ex) {
            System.debug('*** EXCEPTION in processOrderSync: ' + ex.getMessage());
            resultMessage = 'ERROR: ' + ex.getMessage() + ' | Stack: ' + ex.getStackTraceString();
        }
        
        // -----------------------------------------------------------------
        // SINGLE FINAL LOG — written only when we reach this line.
        // If an error caused an early return above, that callout already
        // logged its own specific error log and we never reach here.
        // This log captures the full SUCCESS (or any unexpected error bubble).
        // -----------------------------------------------------------------
        Boolean isError = resultMessage.startsWith('ERROR') || resultMessage.contains('FAILURE');
        DRC_NBC_API_Log_Handler.createApiLog(
            BC_ORDER_ENDPOINT,
            null,
            resultMessage,
            'processOrderSync - FinalResult',
            isError ? resultMessage : null,
            null, null,
            isError ? LOG_TYPE_ERROR : LOG_TYPE_SUCCESS,
            sfOrderId
        );
        
        return resultMessage;
    }
    
    // ========================================================================
    // INTELLIGENT LINE ITEM SYNC
    // ========================================================================
    
    /**
* Workflow:
*   1. UPDATE matched lines (products + non-zero tax lines)
*   2. CREATE new product items
*   3. DELETE unmatched product items / zeroed tax lines
*
* Each inner callout logs its own API error on failure and returns
* an ERROR/FAILURE string so this method can halt and bubble up.
*/
    private static String intelligentLineItemSync(String bcOrderNo, Id orderId) {
        System.debug('  *** Intelligent Line Item Sync Started ***');
        
        try {
            // --- Read BC line items ---
            // Failure → readMultipleLineItemsWithDetails already logged → halt
            Map<Integer, BCLineItem> bcLineDetails = readMultipleLineItemsWithDetails(bcOrderNo, orderId);
            
            if (bcLineDetails == null) {
                return 'ERROR: ReadMultiple Line Items failed. Line Item Sync halted.';
            }
            
            // --- Salesforce OrderItems ---
            List<OrderItem> orderItems = [
                SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice,
                DRC_NBC_Discount__c,
                Order.DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                Order.DRC_NBC_TCS_Amount__c, Order.DRC_NBC_Other_Tax_Amount__c,
                DRC_NBC_Total_Price__c, Order.DRC_NBC_Cust_Order_Number__c,
                Order.Account.DRC_NBC_Customer_Number__c, Order.RecordType.Name,
                Product2.DRC_NBC_FG_Code__c, Product2.DRC_NBC_GST_Group_Code__c,
                Product2.DRC_NBC_HSN_SAC_Code__c, DRC_NBC_Unit_Of_Measurement__c,
                Order.DRC_NBC_Warehouse__c, DRC_NBC_Packing_Quantity__c,
                DRC_NBC_Packing_Size__c
                FROM OrderItem
                WHERE OrderId = :orderId
                ORDER BY CreatedDate ASC
            ];
            
            // --- Order for Tax amounts ---
            Order ord = [
                SELECT DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,
                DRC_NBC_Cust_Order_Number__c, RecordType.Name,
                DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c, DRC_NBC_Warehouse__c
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
            
            System.debug('  SF Product Items: ' + orderItems.size());
            System.debug('  BC Line Items: '    + bcLineDetails.size());
            
            // --- Separate BC product lines vs tax lines ---
            List<BCLineItem>        bcProductLines = new List<BCLineItem>();
            Map<String, BCLineItem> bcTaxLines     = new Map<String, BCLineItem>();
            
            for (BCLineItem bcLine : bcLineDetails.values()) {
                if (bcLine.lineType == 'Item') {
                    bcProductLines.add(bcLine);
                } else {
                    if (bcLine.description != null && bcLine.description.contains('TCS')) {
                        bcTaxLines.put('TCS', bcLine);
                    } else if (bcLine.description != null && bcLine.description.contains('Other Tax')) {
                        bcTaxLines.put('OTHER_TAX', bcLine);
                    }
                }
            }
            
            // --- Match SF items to BC lines by FG Code ---
            Map<Integer, String>    linesToUpdate    = new Map<Integer, String>();
            Set<Integer>            matchedBCLineNos = new Set<Integer>();
            List<OrderItem>         itemsToCreate    = new List<OrderItem>();
            
            Map<String, BCLineItem> bcLinesByFGCode  = new Map<String, BCLineItem>();
            for (BCLineItem bcLine : bcProductLines) {
                if (String.isNotBlank(bcLine.itemNo)) {
                    bcLinesByFGCode.put(bcLine.itemNo, bcLine);
                }
            }
            
            for (OrderItem sfItem : orderItems) {
                String sfFGCode = sfItem.Product2.DRC_NBC_FG_Code__c;
                if (bcLinesByFGCode.containsKey(sfFGCode)) {
                    BCLineItem bcLine = bcLinesByFGCode.get(sfFGCode);
                    if (!matchedBCLineNos.contains(bcLine.lineNo)) {
                        linesToUpdate.put(bcLine.lineNo, bcLine.key);
                        matchedBCLineNos.add(bcLine.lineNo);
                        System.debug('  MATCHED for UPDATE: Line ' + bcLine.lineNo + ' FG: ' + sfFGCode);
                    }
                } else {
                    itemsToCreate.add(sfItem);
                    System.debug('  NEW ITEM to CREATE: ' + sfFGCode);
                }
            }
            
            // --- Tax lines: add to update if non-zero ---
            if (bcTaxLines.containsKey('OTHER_TAX') &&
                ord.DRC_NBC_Other_Tax_Amount__c != null && ord.DRC_NBC_Other_Tax_Amount__c != 0) {
                    BCLineItem taxLine = bcTaxLines.get('OTHER_TAX');
                    linesToUpdate.put(taxLine.lineNo, taxLine.key);
                    System.debug('  OTHER TAX added to UPDATE (amt: ' + ord.DRC_NBC_Other_Tax_Amount__c + ')');
                }
            if (bcTaxLines.containsKey('TCS') &&
                ord.DRC_NBC_TCS_Amount__c != null && ord.DRC_NBC_TCS_Amount__c != 0) {
                    BCLineItem taxLine = bcTaxLines.get('TCS');
                    linesToUpdate.put(taxLine.lineNo, taxLine.key);
                    System.debug('  TCS added to UPDATE (amt: ' + ord.DRC_NBC_TCS_Amount__c + ')');
                }
            
            // --- Unmatched BC product lines → delete ---
            Map<Integer, String> linesToDelete = new Map<Integer, String>();
            for (BCLineItem bcLine : bcProductLines) {
                if (!matchedBCLineNos.contains(bcLine.lineNo)) {
                    linesToDelete.put(bcLine.lineNo, bcLine.key);
                    System.debug('  UNMATCHED PRODUCT for DELETE: Line ' + bcLine.lineNo);
                }
            }
            
            // --- Tax lines → delete if amount became zero ---
            if (bcTaxLines.containsKey('OTHER_TAX')) {
                if (ord.DRC_NBC_Other_Tax_Amount__c == null || ord.DRC_NBC_Other_Tax_Amount__c == 0) {
                    BCLineItem taxLine = bcTaxLines.get('OTHER_TAX');
                    linesToDelete.put(taxLine.lineNo, taxLine.key);
                    linesToUpdate.remove(taxLine.lineNo);
                    System.debug('  OTHER TAX marked for DELETE (amount → zero)');
                } else {
                    System.debug('  OTHER TAX PRESERVED (amt: ' + ord.DRC_NBC_Other_Tax_Amount__c + ')');
                }
            }
            if (bcTaxLines.containsKey('TCS')) {
                if (ord.DRC_NBC_TCS_Amount__c == null || ord.DRC_NBC_TCS_Amount__c == 0) {
                    BCLineItem taxLine = bcTaxLines.get('TCS');
                    linesToDelete.put(taxLine.lineNo, taxLine.key);
                    linesToUpdate.remove(taxLine.lineNo);
                    System.debug('  TCS marked for DELETE (amount → zero)');
                } else {
                    System.debug('  TCS PRESERVED (amt: ' + ord.DRC_NBC_TCS_Amount__c + ')');
                }
            }
            
            String updateResult = 'NO_UPDATE';
            String createResult = 'NO_CREATE';
            String deleteResult = 'NO_DELETE';
            
            // --- STEP 1: UPDATE matched lines ---
            // Failure → updateMultipleLineItems already logged → halt
            if (!linesToUpdate.isEmpty()) {
                System.debug('  STEP 1: Updating ' + linesToUpdate.size() + ' lines...');
                updateResult = updateMultipleLineItems(
                    bcOrderNo, linesToUpdate, orderItems, ord, orderId, bcLineDetails
                );
                System.debug('  Update Result: ' + updateResult);
                
                if (updateResult.startsWith('ERROR') || updateResult.startsWith('FAILURE')) {
                    return 'ERROR: UpdateMultiple Line Items failed. Detail: ' + updateResult;
                }
            }
            
            // --- STEP 2: CREATE new items ---
            // Failure → createLineItemsAtLineNumber already logged → halt
            if (!itemsToCreate.isEmpty()) {
                Integer maxLineNo = 0;
                for (Integer lineNo : bcLineDetails.keySet()) {
                    if (lineNo > maxLineNo) { maxLineNo = lineNo; }
                }
                Integer nextLineNo = maxLineNo + 10000;
                System.debug('  STEP 2: Creating ' + itemsToCreate.size() + ' items at line ' + nextLineNo);
                createResult = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
                    bcOrderNo, itemsToCreate, ord, nextLineNo
                );
                System.debug('  Create Result: ' + createResult);
                
                if (createResult.startsWith('ERROR') || createResult.startsWith('FAILURE')) {
                    return 'ERROR: Create Line Items failed. Detail: ' + createResult;
                }
            }
            
            // --- STEP 3: DELETE unmatched / zeroed lines ---
            // Failure → deleteLineItems already logged → halt
            if (!linesToDelete.isEmpty()) {
                System.debug('  STEP 3: Deleting ' + linesToDelete.size() + ' lines...');
                deleteResult = DRC_NBC_LineItemDeleter.deleteLineItems(linesToDelete);
                System.debug('  Delete Result: ' + deleteResult);
                
                if (deleteResult.startsWith('ERROR') || deleteResult.startsWith('FAILURE')) {
                    return 'ERROR: Delete Line Items failed. Detail: ' + deleteResult;
                }
            }
            
            // --- STEP 4: DML after all callouts ---
            if (!linesToUpdate.isEmpty()) {
                System.debug('  STEP 4: Updating SF Order status after callouts...');
                DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
            }
            
            return 'UPDATE: ' + updateResult + ' | CREATE: ' + createResult + ' | DELETE: ' + deleteResult;
            
        } catch (Exception ex) {
            System.debug('  *** Intelligent Sync Exception: ' + ex.getMessage());
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    // ========================================================================
    // CALLOUT: READ ORDER
    //
    // Logs API error (with full request + response body) on:
    //   - Non-200 HTTP response
    //   - 200 but Key/Status missing in response body
    //   - Callout exception
    // Returns null on any failure → caller returns immediately.
    // ========================================================================
    
    private static BCOrderReadResult readOrderFromBC(Order ord) {
        System.debug('  *** READ Order Operation Started ***');
        
        String requestBody = buildReadSOAPRequest(ord.DRC_NBC_Cust_Order_Number__c);
        String sfOrderId   = String.valueOf(ord.Id);
        
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_ORDER_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_ORDER_NAMESPACE + ':Read');
            req.setHeader('Authorization',
                          'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD)));
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            HttpResponse response = new Http().send(req);
            System.debug('  Read Response Status: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                BCOrderReadResult result = extractKeyAndStatusFromReadResponse(response.getBody());
                
                if (result == null || String.isBlank(result.key)) {
                    // 200 returned but Key/Status absent — treat as failure
                    DRC_NBC_API_Log_Handler.createApiLog(
                        BC_ORDER_ENDPOINT, requestBody, response.getBody(),
                        'readOrderFromBC',
                        'Key or Status not found in Read response body.',
                        response.getStatusCode(), null,
                        LOG_TYPE_ERROR, sfOrderId
                    );
                    return null;
                }
                
                System.debug('  Key: ' + result.key + ' | Status: ' + result.status);
                return result;
                
            } else {
                // Non-200 → log failure and halt
                DRC_NBC_API_Log_Handler.createApiLog(
                    BC_ORDER_ENDPOINT, requestBody, response.getBody(),
                    'readOrderFromBC',
                    'Non-200 response. HTTP ' + response.getStatusCode() + ': ' + response.getStatus(),
                    response.getStatusCode(), null,
                    LOG_TYPE_ERROR, sfOrderId
                );
                return null;
            }
            
        } catch (Exception ex) {
            System.debug('  *** READ Exception: ' + ex.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                BC_ORDER_ENDPOINT, requestBody, null,
                'readOrderFromBC',
                ex.getMessage(), null, ex.getStackTraceString(),
                LOG_TYPE_ERROR, sfOrderId
            );
            return null;
        }
    }
    
    // ========================================================================
    // CALLOUT: REOPEN ORDER (Released → Open)
    //
    // Logs API error (with full request + response body) on:
    //   - Non-200 HTTP response
    //   - Callout exception
    // Returns 'REOPEN_SUCCESS' on 200.
    // Returns 'FAILURE:...' / 'ERROR:...' on failure → caller returns immediately.
    // ========================================================================
    
    @TestVisible
    private static String reopenOrderInBC(String bcKey, Order ord) {
        System.debug('  *** REOPEN Order Operation Started ***');
        
        String requestBody = buildReopenOrderSOAPRequest(bcKey, ord.DRC_NBC_Cust_Order_Number__c);
        String sfOrderId   = String.valueOf(ord.Id);
        
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_ORDER_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_ORDER_NAMESPACE + ':Update');
            req.setHeader('Authorization',
                          'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD)));
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            HttpResponse response = new Http().send(req);
            System.debug('  Reopen Response: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                System.debug('  Order Reopened Successfully (Released → Open)');
                return 'REOPEN_SUCCESS';
            } else {
                DRC_NBC_API_Log_Handler.createApiLog(
                    BC_ORDER_ENDPOINT, requestBody, response.getBody(),
                    'reopenOrderInBC',
                    'Non-200 response. HTTP ' + response.getStatusCode() + ': ' + response.getStatus(),
                    response.getStatusCode(), null,
                    LOG_TYPE_ERROR, sfOrderId
                );
                return 'FAILURE: ' + response.getStatusCode() + ' | ' + response.getBody();
            }
            
        } catch (Exception ex) {
            System.debug('  *** REOPEN Exception: ' + ex.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                BC_ORDER_ENDPOINT, requestBody, null,
                'reopenOrderInBC',
                ex.getMessage(), null, ex.getStackTraceString(),
                LOG_TYPE_ERROR, sfOrderId
            );
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    // ========================================================================
    // CALLOUT: UPDATE ORDER
    //
    // Logs API error (with full request + response body) on:
    //   - Non-200 HTTP response
    //   - Callout exception
    // Returns 'ORDER_UPDATE_SUCCESS' on 200.
    // Returns 'FAILURE:...' / 'ERROR:...' on failure → caller returns immediately.
    // ========================================================================
    
    private static String updateOrderInBC(String bcKey, Order ord, Boolean updateSF) {
        System.debug('  *** UPDATE Order Operation Started ***');
        
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        
        String requestBody = buildUpdateOrderSOAPRequest(bcKey, payload, ord);
        String sfOrderId   = String.valueOf(ord.Id);
        
        System.debug('  Syncing Shipping Address before Order update...');
        String shipSyncResult = DRC_NBC_UpdateShippingAddress.syncShippingAddress(ord.Id);
        System.debug('  Shipping Sync Result: ' + shipSyncResult);
        
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_ORDER_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_ORDER_NAMESPACE + ':Update');
            req.setHeader('Authorization',
                          'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD)));
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            HttpResponse response = new Http().send(req);
            System.debug('  Update Response: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                System.debug('  Order Updated Successfully in BC');
                return 'ORDER_UPDATE_SUCCESS';
            } else {
                DRC_NBC_API_Log_Handler.createApiLog(
                    BC_ORDER_ENDPOINT, requestBody, response.getBody(),
                    'updateOrderInBC',
                    'Non-200 response. HTTP ' + response.getStatusCode() + ': ' + response.getStatus(),
                    response.getStatusCode(), null,
                    LOG_TYPE_ERROR, sfOrderId
                );
                return 'FAILURE: ' + response.getStatusCode();
            }
            
        } catch (Exception ex) {
            System.debug('  *** UPDATE Exception: ' + ex.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                BC_ORDER_ENDPOINT, requestBody, null,
                'updateOrderInBC',
                ex.getMessage(), null, ex.getStackTraceString(),
                LOG_TYPE_ERROR, sfOrderId
            );
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    // ========================================================================
    // CALLOUT: READ MULTIPLE LINE ITEMS
    //
    // Logs API error (with full request + response body) on:
    //   - Non-200 HTTP response
    //   - Callout exception
    // Returns parsed map on 200, null on failure → caller returns immediately.
    // ========================================================================
    
    private static Map<Integer, BCLineItem> readMultipleLineItemsWithDetails(
        String bcOrderNo, Id orderId) {
            
            System.debug('    *** ReadMultiple Line Items Started ***');
            
            String requestBody = buildReadMultipleSOAPRequest(bcOrderNo);
            String sfOrderId   = String.valueOf(orderId);
            
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(BC_LINE_ITEM_ENDPOINT);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'text/xml; charset=utf-8');
                req.setHeader('SOAPAction', SOAP_LINE_NAMESPACE + ':ReadMultiple');
                req.setHeader('Authorization',
                              'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD)));
                req.setBody(requestBody);
                req.setTimeout(120000);
                
                HttpResponse response = new Http().send(req);
                System.debug('    ReadMultiple Response: ' + response.getStatusCode());
                
                if (response.getStatusCode() == 200) {
                    Map<Integer, BCLineItem> result = extractLineDetailsFromReadMultiple(response.getBody());
                    System.debug('    Extracted ' + result.size() + ' line items');
                    return result;
                } else {
                    DRC_NBC_API_Log_Handler.createApiLog(
                        BC_LINE_ITEM_ENDPOINT, requestBody, response.getBody(),
                        'readMultipleLineItemsWithDetails',
                        'Non-200 response. HTTP ' + response.getStatusCode() + ': ' + response.getStatus(),
                        response.getStatusCode(), null,
                        LOG_TYPE_ERROR, sfOrderId
                    );
                    return null;
                }
                
            } catch (Exception ex) {
                System.debug('    *** ReadMultiple Exception: ' + ex.getMessage());
                DRC_NBC_API_Log_Handler.createApiLog(
                    BC_LINE_ITEM_ENDPOINT, requestBody, null,
                    'readMultipleLineItemsWithDetails',
                    ex.getMessage(), null, ex.getStackTraceString(),
                    LOG_TYPE_ERROR, sfOrderId
                );
                return null;
            }
        }
    
    // ========================================================================
    // CALLOUT: UPDATE MULTIPLE LINE ITEMS
    //
    // Logs API error (with full request + response body) on:
    //   - Non-200 HTTP response
    //   - Callout exception
    // Returns 'SUCCESS' on 200.
    // Returns 'FAILURE:...' / 'ERROR:...' on failure → caller returns immediately.
    // ========================================================================
    
    @TestVisible
    private static String updateMultipleLineItems(
        String bcOrderNo,
        Map<Integer, String> bcLineKeys,
        List<OrderItem> orderItems,
        Order ord,
        Id orderId,
        Map<Integer, BCLineItem> bcLineDetails) {
            
            System.debug('    *** UpdateMultiple Started ***');
            
            // ✅ FIX: Re-fetch order to get the latest Warehouse__c before building payload
            // The passed-in `ord` may be stale — updateOrderInBC runs before this and
            // can result in a different location code being needed.
            Order freshOrd = [
                SELECT DRC_NBC_Warehouse__c, DRC_NBC_Other_Tax_Amount__c,
                DRC_NBC_TCS_Amount__c, DRC_NBC_Cust_Order_Number__c,
                RecordType.Name, DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
            
            String requestBody = buildUpdateMultipleSOAPRequest(
                bcOrderNo, bcLineKeys, orderItems, freshOrd, bcLineDetails);  // pass freshOrd
            String sfOrderId = String.valueOf(orderId);
                        
            try {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(BC_LINE_ITEM_ENDPOINT);
                req.setMethod('POST');
                req.setHeader('Content-Type', 'text/xml; charset=utf-8');
                req.setHeader('SOAPAction', SOAP_LINE_NAMESPACE + ':UpdateMultiple');
                req.setHeader('Authorization',
                              'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD)));
                req.setBody(requestBody);
                req.setTimeout(120000);
                
                HttpResponse response = new Http().send(req);
                System.debug('    UpdateMultiple Response: ' + response.getStatusCode());
                
                if (response.getStatusCode() == 200) {
                    return 'SUCCESS';
                } else {
                    DRC_NBC_API_Log_Handler.createApiLog(
                        BC_LINE_ITEM_ENDPOINT, requestBody, response.getBody(),
                        'updateMultipleLineItems',
                        'Non-200 response. HTTP ' + response.getStatusCode() + ': ' + response.getStatus(),
                        response.getStatusCode(), null,
                        LOG_TYPE_ERROR, sfOrderId
                    );
                    return 'FAILURE: ' + response.getStatusCode();
                }
                
            } catch (Exception ex) {
                System.debug('    *** UpdateMultiple Exception: ' + ex.getMessage());
                DRC_NBC_API_Log_Handler.createApiLog(
                    BC_LINE_ITEM_ENDPOINT, requestBody, null,
                    'updateMultipleLineItems',
                    ex.getMessage(), null, ex.getStackTraceString(),
                    LOG_TYPE_ERROR, sfOrderId
                );
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
            '<Document_Type>Order</Document_Type>' +
            '<No>' + escapeXml(bcOrderNumber) + '</No>' +
            '</Read>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    @TestVisible
    private static String buildReopenOrderSOAPRequest(String bcKey, String bcOrderNo) {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Update xmlns="' + SOAP_ORDER_NAMESPACE + '">' +
            '<SalesOrderSalesForce>' +
            '<Key>'           + escapeXml(bcKey)     + '</Key>' +
            '<Document_Type>Order</Document_Type>' +
            '<No>'            + escapeXml(bcOrderNo) + '</No>' +
            '<Status>Open</Status>' +
            '</SalesOrderSalesForce>' +
            '</Update>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    private static String buildUpdateOrderSOAPRequest(
        String bcKey,
        DRC_NBC_Integration_Payload.OrderPayload payload,
        Order ord) {
            
            if (String.isNotBlank(ord.DRC_NBC_Warehouse__c)) {
                List<Warehouse_Location_Code__mdt> metaList = [
                    SELECT DRC_NBC_Code__c FROM Warehouse_Location_Code__mdt
                    WHERE MasterLabel = :ord.DRC_NBC_Warehouse__c
                    AND DRC_NBC_Type__c = 'Warehouse Location'
                    LIMIT 1
                ];
                if (!metaList.isEmpty()) {
                    payload.Location_Code = metaList[0].DRC_NBC_Code__c;
                }
            }
            
            System.debug('Order Payload => ' + JSON.serialize(payload));
            System.debug('bcKey => ' + bcKey);
            System.debug('Order Id => ' + ord.Id);
            
            return
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<Update xmlns="' + SOAP_ORDER_NAMESPACE + '">' +
                '<SalesOrderSalesForce>' +
                '<Key>'                         + escapeXml(bcKey)                               + '</Key>' +
                '<No>'                          + escapeXml(payload.No)                          + '</No>' +
                '<Document_Type>Order</Document_Type>' +
                '<Sell_to_Customer_No>'         + escapeXml(payload.Sell_to_Customer_No)         + '</Sell_to_Customer_No>' +
                '<Sell_to_Customer_Name>'       + escapeXml(payload.Sell_to_Customer_Name)       + '</Sell_to_Customer_Name>' +
                '<Sell_to_Address>'             + escapeXml(payload.Sell_to_Address)             + '</Sell_to_Address>' +
                '<Sell_to_Address_2>'           + escapeXml(payload.Sell_to_Address_2)           + '</Sell_to_Address_2>' +
                '<Sell_to_City>'                + escapeXml(payload.Sell_to_City)                + '</Sell_to_City>' +
                '<Sell_to_Post_Code>'           + escapeXml(payload.Sell_to_Post_Code)           + '</Sell_to_Post_Code>' +
                '<Order_Date>'                  + escapeXml(payload.Order_Date)                  + '</Order_Date>' +
                '<External_Document_No>'        + escapeXml(payload.External_Document_No)        + '</External_Document_No>' +
                '<Salesperson_Code>'            + escapeXml(payload.Salesperson_Code)            + '</Salesperson_Code>' +
                '<Status>Open</Status>' +
                '<Location_Code>' + escapeXml(payload.Location_Code) +  '</Location_Code>' +
                '<Payment_Terms_Code>'          + escapeXml(payload.Payment_Terms_Code)          + '</Payment_Terms_Code>' +
                '<Shipment_Method_Code>'        + escapeXml(payload.Shipment_Method_Code)        + '</Shipment_Method_Code>' +
                '<Sample_Sales>'                + payload.Sample_Sales                           + '</Sample_Sales>' +
                '<Salesforce_So_No>'            + escapeXml(payload.Salesforce_So_No)            + '</Salesforce_So_No>' +
                '<Ship_to_Code>'                + escapeXml(payload.Ship_to_Code)                + '</Ship_to_Code>' +
                '<Ship_to_Name>'                + escapeXml(payload.Ship_to_Name)                + '</Ship_to_Name>' +
                '<Ship_to_Name_2>'              + escapeXml(payload.Ship_to_Name_2)              + '</Ship_to_Name_2>' +
                '<Ship_to_Address>'             + escapeXml(payload.Ship_to_Address)             + '</Ship_to_Address>' +
                '<Ship_to_Address_2>'           + escapeXml(payload.Ship_to_Address_2)           + '</Ship_to_Address_2>' +
                '<Ship_to_Post_Code>'           + escapeXml(payload.Ship_to_Post_Code)           + '</Ship_to_Post_Code>' +
                '<Ship_to_Country_Region_Code>' + escapeXml(payload.Ship_to_Country_Region_Code) + '</Ship_to_Country_Region_Code>' +
                '<Salesforce_Order_Amount>'     + payload.Salesforce_Order_Amount                + '</Salesforce_Order_Amount>' +
                '<Salesforce_Order_Created>'    + payload.Salesforce_Order_Created               + '</Salesforce_Order_Created>' +
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
    
    @TestVisible
    private static String buildUpdateMultipleSOAPRequest(
        String bcOrderNo,
        Map<Integer, String> bcLineKeys,
        List<OrderItem> orderItems,
        Order ord,
        Map<Integer, BCLineItem> bcLineDetails) {
            
            System.debug('    *** buildUpdateMultipleSOAPRequest Started ***');
            String orderLocationCode = getLocationCodeFromWarehouse(ord.DRC_NBC_Warehouse__c);
            System.debug('orderLocationCode for Line item and other taxes ' + orderLocationCode);
            
            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<UpdateMultiple xmlns="' + SOAP_LINE_NAMESPACE + '">' +
                '<SalesOrderLineSalesForce_List>';
            
            Map<Integer, String> productKeys = new Map<Integer, String>();
            Map<String, String>  taxKeys     = new Map<String, String>();
            Map<String, Integer> taxLineNos  = new Map<String, Integer>();
            
            for (Integer lineNo : bcLineKeys.keySet()) {
                String     bcKey  = bcLineKeys.get(lineNo);
                BCLineItem bcLine = bcLineDetails.get(lineNo);
                if (bcLine != null) {
                    if (bcLine.lineType == 'Item') {
                        productKeys.put(lineNo, bcKey);
                    } else {
                        if (bcLine.description != null && bcLine.description.contains('TCS')) {
                            taxKeys.put('TCS', bcKey);
                            taxLineNos.put('TCS', lineNo);
                        } else if (bcLine.description != null && bcLine.description.contains('Other Tax')) {
                            taxKeys.put('OTHER_TAX', bcKey);
                            taxLineNos.put('OTHER_TAX', lineNo);
                        }
                    }
                }
            }
            
            List<Integer> sortedProductLineNos = new List<Integer>(productKeys.keySet());
            sortedProductLineNos.sort();
            
            Map<String, OrderItem> sfItemsByFGCode = new Map<String, OrderItem>();
            for (OrderItem item : orderItems) {
                sfItemsByFGCode.put(item.Product2.DRC_NBC_FG_Code__c, item);
            }
            
            for (Integer lineNo : sortedProductLineNos) {
                String     bcKey  = productKeys.get(lineNo);
                BCLineItem bcLine = bcLineDetails.get(lineNo);
                if (bcLine == null) continue;
                
                OrderItem matchedItem = sfItemsByFGCode.get(bcLine.itemNo);
                if (matchedItem == null) continue;
                
                Boolean isSampleOrder      = matchedItem.Order.RecordType.Name == 'Sample_Order';
                Decimal discountPercent    = matchedItem.DRC_NBC_Discount__c    != null ? matchedItem.DRC_NBC_Discount__c    : 0;
                Decimal totalPrice         = matchedItem.DRC_NBC_Total_Price__c  != null ? matchedItem.DRC_NBC_Total_Price__c  : 0;
                Decimal lineDiscountAmount = (totalPrice * discountPercent) / 100;
                
                if (isSampleOrder) {
                    totalPrice         = 0;
                    lineDiscountAmount = 0;
                }
                
                soapBody +=
                    '<SalesOrderLineSalesForce>' +
                    '<Key>'                   + escapeXml(bcKey)                                                           + '</Key>' +
                    '<Document_Type>Order</Document_Type>' +
                    '<Document_No>'           + escapeXml(bcOrderNo)                                                       + '</Document_No>' +
                    '<Line_No>'               + lineNo                                                                     + '</Line_No>' +
                    '<Type>Item</Type>' +
                    '<No>'                    + escapeXml(matchedItem.Product2.DRC_NBC_FG_Code__c)                         + '</No>' +
                    '<Customer_item_no>'      + escapeXml(matchedItem.Product2.DRC_NBC_FG_Code__c)                         + '</Customer_item_no>' +
                    '<Description>'           + escapeXml(matchedItem.Description != null ? matchedItem.Description : '') + '</Description>' +
                    '<Quantity>'              + (matchedItem.Quantity  != null ? matchedItem.Quantity  : 0)                + '</Quantity>' +
                    '<Unit_of_Measure_Code>KGS</Unit_of_Measure_Code>' +
                    '<Unit_Price>'            + (isSampleOrder ? 0 : (matchedItem.UnitPrice != null ? matchedItem.UnitPrice : 0)) + '</Unit_Price>' +
                    '<Line_Amount>'           + totalPrice                                                                 + '</Line_Amount>' +
                    '<Line_Discount_Percent>' + discountPercent                                                            + '</Line_Discount_Percent>' +
                    '<Line_Discount_Amount>'  + lineDiscountAmount                                                         + '</Line_Discount_Amount>' +
                    '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                    '<GST_Credit>'            + GST_CREDIT_VALUE                                                           + '</GST_Credit>' +
                    '<Location_Code>'        + escapeXml(orderLocationCode)                  + '</Location_Code>' +
                    '<GST_Group_Code>'        + escapeXml(matchedItem.Product2.DRC_NBC_GST_Group_Code__c)                  + '</GST_Group_Code>' +
                    '<HSN_SAC_Code>'          + escapeXml(matchedItem.Product2.DRC_NBC_HSN_SAC_Code__c)                    + '</HSN_SAC_Code>' +
                    '<Packing_Details>'       + escapeXml(matchedItem.DRC_NBC_Packing_Size__c)                             + '</Packing_Details>' +
                    '<No_of_Pkg_for_Qty>'     + (matchedItem.Quantity  != null ? matchedItem.Quantity  : 0)                + '</No_of_Pkg_for_Qty>' +
                    '</SalesOrderLineSalesForce>';
            }
            
            // Other Tax Line
            if (taxKeys.containsKey('OTHER_TAX') &&
                ord.DRC_NBC_Other_Tax_Amount__c != null && ord.DRC_NBC_Other_Tax_Amount__c != 0) {
                    
                    String  otherTaxKey    = taxKeys.get('OTHER_TAX');
                    Integer otherTaxLineNo = taxLineNos.get('OTHER_TAX');
                    
                    soapBody +=
                        '<SalesOrderLineSalesForce>' +
                        '<Key>'                   + escapeXml(otherTaxKey)          + '</Key>' +
                        '<Document_Type>Order</Document_Type>' +
                        '<Document_No>'           + escapeXml(bcOrderNo)            + '</Document_No>' +
                        '<Line_No>'               + otherTaxLineNo                  + '</Line_No>' +
                        '<Type>G/L Account</Type>' +
                        '<No>70563200</No>' +
                        '<Customer_item_no></Customer_item_no>' +
                        '<Description>Other Tax Amount</Description>' +
                        '<Quantity>1</Quantity>' +
                        '<HSN_SAC_Code></HSN_SAC_Code>' +
                        '<Unit_of_Measure_Code>KGS</Unit_of_Measure_Code>' +
                        '<Location_Code>'        + escapeXml(orderLocationCode)                  + '</Location_Code>' +
                        '<Unit_Price>'            + ord.DRC_NBC_Other_Tax_Amount__c + '</Unit_Price>' +
                        '<Line_Amount>'           + ord.DRC_NBC_Other_Tax_Amount__c + '</Line_Amount>' +
                        '<Line_Discount_Percent>0</Line_Discount_Percent>' +
                        '<Line_Discount_Amount>0</Line_Discount_Amount>' +
                        '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                        '<GST_Credit>_blank_</GST_Credit>' +
                        '<Packing_Details></Packing_Details>' +
                        '<No_of_Pkg_for_Qty>1</No_of_Pkg_for_Qty>' +
                        '</SalesOrderLineSalesForce>';
                }
            
            // TCS Line
            if (taxKeys.containsKey('TCS') &&
                ord.DRC_NBC_TCS_Amount__c != null && ord.DRC_NBC_TCS_Amount__c != 0) {
                    
                    String  tcsKey    = taxKeys.get('TCS');
                    Integer tcsLineNo = taxLineNos.get('TCS');
                    
                    soapBody +=
                        '<SalesOrderLineSalesForce>' +
                        '<Key>'                   + escapeXml(tcsKey)             + '</Key>' +
                        '<Document_Type>Order</Document_Type>' +
                        '<Document_No>'           + escapeXml(bcOrderNo)          + '</Document_No>' +
                        '<Line_No>'               + tcsLineNo                     + '</Line_No>' +
                        '<Type>G/L Account</Type>' +
                        '<No>70563200</No>' +
                        '<Customer_item_no></Customer_item_no>' +
                        '<Description>TCS Amount</Description>' +
                        '<Quantity>1</Quantity>' +
                        '<HSN_SAC_Code></HSN_SAC_Code>' +
                        '<Unit_of_Measure_Code>KGS</Unit_of_Measure_Code>' +
                        '<Location_Code>'        + escapeXml(orderLocationCode)                  + '</Location_Code>' +
                        '<Unit_Price>'            + ord.DRC_NBC_TCS_Amount__c     + '</Unit_Price>' +
                        '<Line_Amount>'           + ord.DRC_NBC_TCS_Amount__c     + '</Line_Amount>' +
                        '<Line_Discount_Percent>0</Line_Discount_Percent>' +
                        '<Line_Discount_Amount>0</Line_Discount_Amount>' +
                        '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                        '<GST_Credit>_blank_</GST_Credit>' +
                        '<Packing_Details></Packing_Details>' +
                        '<No_of_Pkg_for_Qty>1</No_of_Pkg_for_Qty>' +
                        '</SalesOrderLineSalesForce>';
                }
            
            soapBody +=
                '</SalesOrderLineSalesForce_List>' +
                '</UpdateMultiple>' +
                '</soap:Body>' +
                '</soap:Envelope>';
            
            return soapBody;
        }
    
    // ========================================================================
    // RESPONSE PARSERS
    // ========================================================================
    
    private static BCOrderReadResult extractKeyAndStatusFromReadResponse(String xmlResponse) {
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlResponse);
            Dom.XmlNode root = doc.getRootElement();
            
            String key    = null;
            String status = null;
            
            for (Dom.XmlNode bodyNode : root.getChildElements()) {
                if (bodyNode.getName().contains('Body')) {
                    for (Dom.XmlNode resultNode : bodyNode.getChildElements()) {
                        if (resultNode.getName().contains('Read_Result')) {
                            for (Dom.XmlNode salesOrderNode : resultNode.getChildElements()) {
                                if (salesOrderNode.getName().contains('SalesOrderSalesForce')) {
                                    for (Dom.XmlNode fieldNode : salesOrderNode.getChildElements()) {
                                        if (fieldNode.getName() == 'Key')    { key    = fieldNode.getText(); }
                                        if (fieldNode.getName() == 'Status') { status = fieldNode.getText(); }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            System.debug('  Parsed Key: ' + key + ' | Status: ' + status);
            return (key != null) ? new BCOrderReadResult(key, status) : null;
            
        } catch (Exception ex) {
            System.debug('Exception extracting Key/Status: ' + ex.getMessage());
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
                            for (Dom.XmlNode innerNode : resultNode.getChildElements()) {
                                if (innerNode.getName().contains('ReadMultiple_Result')) {
                                    for (Dom.XmlNode lineNode : innerNode.getChildElements()) {
                                        if (lineNode.getName().contains('SalesOrderLineSalesForce')) {
                                            String  key         = null;
                                            Integer lineNo      = null;
                                            String  lineType    = null;
                                            String  itemNo      = null;
                                            Decimal quantity    = null;
                                            String  description = null;
                                            
                                            for (Dom.XmlNode f : lineNode.getChildElements()) {
                                                String fn = f.getName();
                                                if      (fn == 'Key')         { key         = f.getText(); }
                                                else if (fn == 'Line_No')     { lineNo      = Integer.valueOf(f.getText()); }
                                                else if (fn == 'Type')        { lineType    = f.getText(); }
                                                else if (fn == 'No')          { itemNo      = f.getText(); }
                                                else if (fn == 'Quantity')    {
                                                    if (String.isNotBlank(f.getText())) {
                                                        quantity = Decimal.valueOf(f.getText());
                                                    }
                                                }
                                                else if (fn == 'Description') { description = f.getText(); }
                                            }
                                            
                                            if (key != null && lineNo != null) {
                                                lineDetailsMap.put(lineNo,
                                                                   new BCLineItem(key, lineNo, lineType, itemNo, quantity, description));
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug('Exception extracting line details: ' + ex.getMessage());
        }
        
        return lineDetailsMap;
    }
    
    // ========================================================================
    // HELPERS
    // ========================================================================
    
    private static String escapeXml(String value) {
        if (String.isBlank(value)) return '';
        return value.escapeXml();
    }
    
    @TestVisible
    private static String getLocationCodeFromWarehouse(String warehouseLabel) {
        if (String.isBlank(warehouseLabel)) return '';
        
        List<Warehouse_Location_Code__mdt> metaList = [
            SELECT DRC_NBC_Code__c FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel = :warehouseLabel
            AND DRC_NBC_Type__c = 'Warehouse Location'
            LIMIT 1
        ];
        
        return metaList.isEmpty() ? '' : metaList[0].DRC_NBC_Code__c;
    }
}