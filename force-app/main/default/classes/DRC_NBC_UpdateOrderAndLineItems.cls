/**
* @File Name :         DRC_NBC_UpdateOrderAndLineItems.cls
* @Description : Handles Order and Line Items sync with Business Central using SOAP
* @Author : Satish YADAV
* @Last Modified On : June 12, 2026
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
* - DEBUG STRATEGY (added): every payload (SF data, SOAP request body, SOAP response body,
*   parsed maps, decisions) is printed via System.debug at each step for traceability.
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
        System.debug('=================================================================');
        System.debug('*** START: DRC_NBC_UpdateOrderAndLineItems.orderId ***');
        System.debug('=================================================================');
        System.debug('DEBUG PAYLOAD >>> Input orderRecordId: ' + orderRecordId);
        
        System.debug('DEBUG PAYLOAD >>> bcSettings: ' + (bcSettings != null ? JSON.serializePretty(bcSettings) : 'NULL'));
        System.debug('DEBUG PAYLOAD >>> BC_ORDER_ENDPOINT: '     + BC_ORDER_ENDPOINT);
        System.debug('DEBUG PAYLOAD >>> BC_LINE_ITEM_ENDPOINT: ' + BC_LINE_ITEM_ENDPOINT);
        System.debug('DEBUG PAYLOAD >>> SOAP_ORDER_NAMESPACE: '  + SOAP_ORDER_NAMESPACE);
        System.debug('DEBUG PAYLOAD >>> SOAP_LINE_NAMESPACE: '   + SOAP_LINE_NAMESPACE);
        System.debug('DEBUG PAYLOAD >>> GST_CREDIT_VALUE: '      + GST_CREDIT_VALUE);
        System.debug('DEBUG PAYLOAD >>> BC_USERNAME: '           + BC_USERNAME);
        
        if (bcSettings == null || String.isBlank(BC_ORDER_ENDPOINT) || String.isBlank(BC_USERNAME)) {
            String errorMsg = 'ERROR: Business Central settings not configured. Please setup DRC_NBC_BC_Integration__c Custom Setting.';
            System.debug('DEBUG PAYLOAD >>> ' + errorMsg);
            return errorMsg;
        }
        
        String resultMessage = '';
        
        try {
            System.debug('Step 1: Querying Order details...');
            Order ord       = DRC_NBC_Order_BC_Callout.getOrderDetails(orderRecordId);
            Id    accountId = ord.AccountId;
            
            System.debug('DEBUG PAYLOAD >>> Order queried (full): ' + JSON.serializePretty(ord));
            System.debug('DEBUG PAYLOAD >>> Order Id: '             + ord.Id);
            System.debug('DEBUG PAYLOAD >>> Order Number: '         + ord.OrderNumber);
            System.debug('DEBUG PAYLOAD >>> Account Id: '           + accountId);
            System.debug('DEBUG PAYLOAD >>> BC Customer Order Number: ' + ord.DRC_NBC_Cust_Order_Number__c);
            System.debug('DEBUG PAYLOAD >>> Customer Number: '      + ord.Account.DRC_NBC_Customer_Number__c);
            System.debug('DEBUG PAYLOAD >>> Ship To Code: '         + ord.DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c);
            System.debug('DEBUG PAYLOAD >>> Is_Domestic_Merchnat__c: ' + ord.Is_Domestic_Merchnat__c);
            
            if (ord.DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c != null) {
                System.debug('DEBUG PAYLOAD >>> Ship-To Code present. Checking shipping details existence...');
                Boolean callShipping = DRC_NBC_CheckShiipingDetails.checkShippingExists(orderRecordId, accountId);
                System.debug('DEBUG PAYLOAD >>> callShipping flag: ' + callShipping);
                
                if (callShipping) {
                    System.debug('DEBUG PAYLOAD >>> Enqueuing ShippingCalloutQueueable with orderRecordId=' + orderRecordId + ', accountId=' + accountId);
                    System.enqueueJob(new ShippingCalloutQueueable(orderRecordId, accountId));
                } else {
                    System.debug('DEBUG PAYLOAD >>> Enqueuing OrderSyncQueueable directly with orderRecordId=' + orderRecordId + ', accountId=' + accountId);
                    System.enqueueJob(new OrderSyncQueueable(orderRecordId, accountId));
                }
                resultMessage = 'QUEUED: Ship-To Code generation started. Shipping and Order sync will follow.';
                System.debug('DEBUG PAYLOAD >>> resultMessage: ' + resultMessage);
                return resultMessage;
            } else {
                System.debug('DEBUG PAYLOAD >>> Ship-To Code already present. Proceeding with Order sync (synchronous).');
                resultMessage = processOrderSync(ord, accountId);
            }
            
        } catch (Exception ex) {
            System.debug('*** EXCEPTION in orderId: ' + ex.getMessage());
            System.debug('DEBUG PAYLOAD >>> Stack Trace: ' + ex.getStackTraceString());
            resultMessage = 'ERROR: ' + ex.getMessage();
        }
        
        System.debug('DEBUG PAYLOAD >>> Final resultMessage from orderId: ' + resultMessage);
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
            System.debug('=================================================================');
            System.debug('*** ShippingCalloutQueueable Started ***');
            System.debug('=================================================================');
            System.debug('DEBUG PAYLOAD >>> orderRecordId: ' + orderRecordId + ' | accountId: ' + accountId);
            try {
                String shippingResult = DRC_NBC_Shipping_BC_Callout.processShipping(accountId, orderRecordId);
                System.debug('DEBUG PAYLOAD >>> Shipping Callout Result: ' + shippingResult);
                System.debug('DEBUG PAYLOAD >>> Enqueuing OrderSyncQueueable after shipping callout');
                System.enqueueJob(new OrderSyncQueueable(orderRecordId, accountId));
            } catch (Exception ex) {
                System.debug('*** EXCEPTION in ShippingCalloutQueueable: ' + ex.getMessage());
                System.debug('DEBUG PAYLOAD >>> Stack Trace: ' + ex.getStackTraceString());
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
            System.debug('=================================================================');
            System.debug('*** OrderSyncQueueable Started ***');
            System.debug('=================================================================');
            System.debug('DEBUG PAYLOAD >>> orderRecordId: ' + orderRecordId + ' | accountId: ' + accountId);
            try {
                Order  ord = DRC_NBC_Order_BC_Callout.getOrderDetails(orderRecordId);
                System.debug('DEBUG PAYLOAD >>> Order fetched in OrderSyncQueueable: ' + JSON.serializePretty(ord));
                String orderSyncResult = processOrderSync(ord, accountId);
                System.debug('DEBUG PAYLOAD >>> Order Sync Result: ' + orderSyncResult);
            } catch (Exception ex) {
                System.debug('*** EXCEPTION in OrderSyncQueueable: ' + ex.getMessage());
                System.debug('DEBUG PAYLOAD >>> Stack Trace: ' + ex.getStackTraceString());
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
        System.debug('=================================================================');
        System.debug('*** processOrderSync STARTED ***');
        System.debug('=================================================================');
        System.debug('DEBUG PAYLOAD >>> Order Id: ' + ord.Id + ' | accountId: ' + accountId);
        System.debug('DEBUG PAYLOAD >>> Order (full): ' + JSON.serializePretty(ord));
        
        String resultMessage = '';
        String sfOrderId     = String.valueOf(ord.Id);
        
        try {
            
            // -----------------------------------------------------------------
            // STEP 1: READ ORDER FROM BC
            // -----------------------------------------------------------------
            System.debug('--- Step 1: Reading Order from BC ---');
            BCOrderReadResult readResult = readOrderFromBC(ord);
            
            System.debug('DEBUG PAYLOAD >>> readResult: ' + (readResult != null
                ? ('Key=' + readResult.key + ' | Status=' + readResult.status)
                : 'NULL'));
            
            if (readResult == null || String.isBlank(readResult.key)) {
                System.debug('DEBUG PAYLOAD >>> Read Order from BC failed. Halting process.');
                return 'ERROR: Read Order from BC failed. Process halted.';
            }
            
            System.debug('DEBUG PAYLOAD >>> BC Key: ' + readResult.key + ' | Status: ' + readResult.status);
            String bcKey = readResult.key;
            
            // -----------------------------------------------------------------
            // STEP 2: REOPEN IF RELEASED
            // -----------------------------------------------------------------
            if (readResult.status == 'Released') {
                System.debug('--- Step 2: Order is Released. Reopening... ---');
                String reopenResult = reopenOrderInBC(bcKey, ord);
                System.debug('DEBUG PAYLOAD >>> reopenResult: ' + reopenResult);
                
                if (reopenResult.startsWith('ERROR') || reopenResult.startsWith('FAILURE')) {
                    System.debug('DEBUG PAYLOAD >>> Reopen failed. Halting process.');
                    return 'ERROR: Reopen Released Order failed. Process halted. Detail: ' + reopenResult;
                }
                
                System.debug('--- Step 2b: Re-reading Order for fresh Key after reopen ---');
                BCOrderReadResult freshRead = readOrderFromBC(ord);
                System.debug('DEBUG PAYLOAD >>> freshRead: ' + (freshRead != null
                    ? ('Key=' + freshRead.key + ' | Status=' + freshRead.status)
                    : 'NULL'));
                
                if (freshRead == null || String.isBlank(freshRead.key)) {
                    System.debug('DEBUG PAYLOAD >>> Re-read after Reopen failed. Halting process.');
                    return 'ERROR: Re-read after Reopen failed. Process halted.';
                }
                
                bcKey = freshRead.key;
                System.debug('DEBUG PAYLOAD >>> Fresh Key: ' + bcKey + ' | Status: ' + freshRead.status);
                
            } else {
                System.debug('--- Step 2: Order is Open. No reopen needed. ---');
            }
            
            // -----------------------------------------------------------------
            // STEP 3: UPDATE ORDER IN BC
            // -----------------------------------------------------------------
            System.debug('--- Step 3: Updating Order in BC ---');
            System.debug('DEBUG PAYLOAD >>> bcKey used for Order Update: ' + bcKey);
            String orderUpdateResult = updateOrderInBC(bcKey, ord, false);
            System.debug('DEBUG PAYLOAD >>> orderUpdateResult: ' + orderUpdateResult);
            
            if (orderUpdateResult.startsWith('ERROR') || orderUpdateResult.startsWith('FAILURE')) {
                System.debug('DEBUG PAYLOAD >>> Order update failed. Halting process.');
                return 'ERROR: Update Order in BC failed. Process halted. Detail: ' + orderUpdateResult;
            }
            
            System.debug('DEBUG PAYLOAD >>> Order Update Result: ' + orderUpdateResult);
            
            // -----------------------------------------------------------------
            // STEP 4: INTELLIGENT LINE ITEM SYNC
            // -----------------------------------------------------------------
            System.debug('--- Step 4: Syncing Line Items ---');
            System.debug('DEBUG PAYLOAD >>> bcOrderNo for line sync: ' + ord.DRC_NBC_Cust_Order_Number__c);
            String lineItemResult = intelligentLineItemSync(ord.DRC_NBC_Cust_Order_Number__c, ord.Id, accountId);
            System.debug('DEBUG PAYLOAD >>> lineItemResult: ' + lineItemResult);
            
            if (lineItemResult.startsWith('ERROR')) {
                System.debug('DEBUG PAYLOAD >>> Line item sync failed. Halting process.');
                return 'ERROR: Line Item Sync failed. Process halted. Detail: ' + lineItemResult;
            }
            
            System.debug('DEBUG PAYLOAD >>> Line Items Sync Result: ' + lineItemResult);
            
            resultMessage = 'ORDER_UPDATE_SUCCESS | ' + lineItemResult;
            
        } catch (Exception ex) {
            System.debug('*** EXCEPTION in processOrderSync: ' + ex.getMessage());
            System.debug('DEBUG PAYLOAD >>> Stack Trace: ' + ex.getStackTraceString());
            resultMessage = 'ERROR: ' + ex.getMessage() + ' | Stack: ' + ex.getStackTraceString();
        }
        
        Boolean isError = resultMessage.startsWith('ERROR') || resultMessage.contains('FAILURE');
        System.debug('DEBUG PAYLOAD >>> Final resultMessage: ' + resultMessage + ' | isError: ' + isError);
        
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
        
        System.debug('*** processOrderSync ENDED *** resultMessage=' + resultMessage);
        return resultMessage;
    }
    
    // ========================================================================
    // INTELLIGENT LINE ITEM SYNC
    // ========================================================================
    
    private static String intelligentLineItemSync(String bcOrderNo, Id orderId, Id accountId) {
        System.debug('=================================================================');
        System.debug('  *** Intelligent Line Item Sync Started ***');
        System.debug('=================================================================');
        System.debug('DEBUG PAYLOAD >>> bcOrderNo: ' + bcOrderNo + ' | orderId: ' + orderId + ' | accountId: ' + accountId);
        
        try {
            // --- Read BC line items ---
            Map<Integer, BCLineItem> bcLineDetails = readMultipleLineItemsWithDetails(bcOrderNo, orderId);
            
            System.debug('DEBUG PAYLOAD >>> bcLineDetails: ' + (bcLineDetails != null ? JSON.serializePretty(bcLineDetails) : 'NULL'));
            
            if (bcLineDetails == null) {
                System.debug('DEBUG PAYLOAD >>> ReadMultiple Line Items returned NULL. Halting sync.');
                return 'ERROR: ReadMultiple Line Items failed. Line Item Sync halted.';
            }
            
            // --- Salesforce OrderItems ---
            List<OrderItem> orderItems = [
                SELECT Id, OrderId, Description, Product2Id, Quantity, UnitPrice,
                DRC_NBC_Discount__c,
                Order.DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                Order.DRC_NBC_TCS_Amount__c, Order.DRC_NBC_Other_Tax_Amount__c,
                Order.DRC_NBC_Fright_Charges__c,
                Order.DRC_NBC_Insurance__c,
                DRC_NBC_Total_Price__c, Order.DRC_NBC_Cust_Order_Number__c,
                Order.Account.DRC_NBC_Customer_Number__c, Order.Account.Type,
                Order.RecordType.Name, Order.Is_Domestic_Merchnat__c,
                Product2.DRC_NBC_FG_Code__c, Product2.DRC_NBC_GST_Group_Code__c,
                Product2.DRC_NBC_HSN_SAC_Code__c, DRC_NBC_Unit_Of_Measurement__c,
                Order.DRC_NBC_Warehouse__c, DRC_NBC_Packing_Quantity__c,
                DRC_NBC_Packing_Size__c, DRC_NBC_Hazardous__c, DRC_NBC_MARKS_NOS__c
                FROM OrderItem
                WHERE OrderId = :orderId
                ORDER BY CreatedDate ASC
            ];
            
            System.debug('DEBUG PAYLOAD >>> orderItems queried (count=' + orderItems.size() + '): ' + JSON.serializePretty(orderItems));
            
            // --- Order for Tax amounts ---
            Order ord = [
                SELECT DRC_NBC_Other_Tax_Amount__c,AccountId, DRC_NBC_TCS_Amount__c,
                DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
                DRC_NBC_Cust_Order_Number__c, RecordType.Name,
                DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c, DRC_NBC_Warehouse__c,
                Is_Domestic_Merchnat__c
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
            
            System.debug('DEBUG PAYLOAD >>> ord (tax amounts query): ' + JSON.serializePretty(ord));
            
            // ── Build Restricted Product Map (Product2Id → Restricted Product Name) ──
            Map<Id, String> restrictedProductMap = new Map<Id, String>();
            if (accountId != null) {
                try {
                    for (DRC_NBC_Restricted_Product__c rp : [
                        SELECT Name, DRC_NBC_Product__c
                        FROM DRC_NBC_Restricted_Product__c
                        WHERE DRC_NBC_Customer__c = :accountId
                    ]) {
                        restrictedProductMap.put(rp.DRC_NBC_Product__c, rp.Name);
                    }
                    System.debug('  Restricted Product Map built. Size: ' + restrictedProductMap.size());
                    System.debug('DEBUG PAYLOAD >>> Restricted Product Map: ' + JSON.serializePretty(restrictedProductMap));
                } catch (Exception ex) {
                    System.debug('  !!! ERROR building Restricted Product Map: ' + ex.getMessage());
                    System.debug('  Stack Trace: ' + ex.getStackTraceString());
                }
            } else {
                System.debug('DEBUG PAYLOAD >>> Skipping Restricted Product Map — accountId is null');
            }
            
            System.debug('  SF Product Items: ' + orderItems.size());
            System.debug('  BC Line Items: '    + bcLineDetails.size());
            
            System.debug('========== ORDER ITEMS & TAX AMOUNTS ==========');
            System.debug('Other Tax Amount  : ' + ord.DRC_NBC_Other_Tax_Amount__c);
            System.debug('TCS Amount        : ' + ord.DRC_NBC_TCS_Amount__c);
            System.debug('Freight Charges   : ' + ord.DRC_NBC_Fright_Charges__c);
            System.debug('Insurance         : ' + ord.DRC_NBC_Insurance__c);
            System.debug('Is_Domestic_Merchnat__c : ' + ord.Is_Domestic_Merchnat__c);
            System.debug('--- Order Line Items ---');
            for (OrderItem oi : orderItems) {
                System.debug(
                    'Product: '       + oi.Product2.DRC_NBC_FG_Code__c +
                    ' | Qty: '        + oi.Quantity                    +
                    ' | UnitPrice: '  + oi.UnitPrice                   +
                    ' | TotalPrice: ' + oi.DRC_NBC_Total_Price__c      +
                    ' | Discount%: '  + oi.DRC_NBC_Discount__c         +
                    ' | UOM: '        + oi.DRC_NBC_Unit_Of_Measurement__c +
                    ' | PackSize: '   + oi.DRC_NBC_Packing_Size__c     +
                    ' | PackQty: '    + oi.DRC_NBC_Packing_Quantity__c +
                    ' | Hazardous: '  + oi.DRC_NBC_Hazardous__c        +
                    ' | MarksNos: '   + oi.DRC_NBC_MARKS_NOS__c        +
                    ' | Desc: '       + oi.Description
                );
            }
            System.debug('================================================');
            
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
                    } else if (bcLine.description != null && bcLine.description.contains('Freight')) {
                        bcTaxLines.put('FREIGHT', bcLine);
                    } else if (bcLine.description != null && bcLine.description.contains('Insurance')) {
                        bcTaxLines.put('INSURANCE', bcLine);
                    }
                }
            }
            
            System.debug('DEBUG PAYLOAD >>> bcProductLines (count=' + bcProductLines.size() + '): ' + JSON.serializePretty(bcProductLines));
            System.debug('DEBUG PAYLOAD >>> bcTaxLines: ' + JSON.serializePretty(bcTaxLines));
            
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
            
            System.debug('DEBUG PAYLOAD >>> bcLinesByFGCode: ' + JSON.serializePretty(bcLinesByFGCode));
            
            for (OrderItem sfItem : orderItems) {
                String sfFGCode = sfItem.Product2.DRC_NBC_FG_Code__c;
                if (bcLinesByFGCode.containsKey(sfFGCode)) {
                    BCLineItem bcLine = bcLinesByFGCode.get(sfFGCode);
                    if (!matchedBCLineNos.contains(bcLine.lineNo)) {
                        linesToUpdate.put(bcLine.lineNo, bcLine.key);
                        matchedBCLineNos.add(bcLine.lineNo);
                        System.debug('  MATCHED for UPDATE: Line ' + bcLine.lineNo + ' FG: ' + sfFGCode + ' | Key: ' + bcLine.key);
                    }
                } else {
                    itemsToCreate.add(sfItem);
                    System.debug('  NEW ITEM to CREATE: ' + sfFGCode + ' | OrderItemId: ' + sfItem.Id);
                }
            }
            
            System.debug('DEBUG PAYLOAD >>> linesToUpdate (after product match): ' + JSON.serializePretty(linesToUpdate));
            System.debug('DEBUG PAYLOAD >>> itemsToCreate (count=' + itemsToCreate.size() + '): ' + JSON.serializePretty(itemsToCreate));
            
            // --- Tax lines: add to update if non-zero ---
            if (bcTaxLines.containsKey('OTHER_TAX') &&
                ord.DRC_NBC_Other_Tax_Amount__c != null && ord.DRC_NBC_Other_Tax_Amount__c != 0) {
                    BCLineItem taxLine = bcTaxLines.get('OTHER_TAX');
                    linesToUpdate.put(taxLine.lineNo, taxLine.key);
                    System.debug('  OTHER TAX added to UPDATE (amt: ' + ord.DRC_NBC_Other_Tax_Amount__c + ') | Line: ' + taxLine.lineNo + ' | Key: ' + taxLine.key);
                }
            if (bcTaxLines.containsKey('TCS') &&
                ord.DRC_NBC_TCS_Amount__c != null && ord.DRC_NBC_TCS_Amount__c != 0) {
                    BCLineItem taxLine = bcTaxLines.get('TCS');
                    linesToUpdate.put(taxLine.lineNo, taxLine.key);
                    System.debug('  TCS added to UPDATE (amt: ' + ord.DRC_NBC_TCS_Amount__c + ') | Line: ' + taxLine.lineNo + ' | Key: ' + taxLine.key);
                }
            if (bcTaxLines.containsKey('FREIGHT') &&
                ord.DRC_NBC_Fright_Charges__c != null && ord.DRC_NBC_Fright_Charges__c != 0) {
                    BCLineItem taxLine = bcTaxLines.get('FREIGHT');
                    linesToUpdate.put(taxLine.lineNo, taxLine.key);
                    System.debug('  FREIGHT added to UPDATE (amt: ' + ord.DRC_NBC_Fright_Charges__c + ') | Line: ' + taxLine.lineNo + ' | Key: ' + taxLine.key);
                }
            if (bcTaxLines.containsKey('INSURANCE') &&
                ord.DRC_NBC_Insurance__c != null && ord.DRC_NBC_Insurance__c != 0) {
                    BCLineItem taxLine = bcTaxLines.get('INSURANCE');
                    linesToUpdate.put(taxLine.lineNo, taxLine.key);
                    System.debug('  INSURANCE added to UPDATE (amt: ' + ord.DRC_NBC_Insurance__c + ') | Line: ' + taxLine.lineNo + ' | Key: ' + taxLine.key);
                }
            
            System.debug('DEBUG PAYLOAD >>> linesToUpdate (after tax additions): ' + JSON.serializePretty(linesToUpdate));
            
            // --- Unmatched BC product lines → delete ---
            Map<Integer, String> linesToDelete = new Map<Integer, String>();
            for (BCLineItem bcLine : bcProductLines) {
                if (!matchedBCLineNos.contains(bcLine.lineNo)) {
                    linesToDelete.put(bcLine.lineNo, bcLine.key);
                    System.debug('  UNMATCHED PRODUCT for DELETE: Line ' + bcLine.lineNo + ' | Key: ' + bcLine.key + ' | ItemNo: ' + bcLine.itemNo);
                }
            }
            
            // --- Tax lines → delete if amount became zero ---
            if (bcTaxLines.containsKey('OTHER_TAX')) {
                if (ord.DRC_NBC_Other_Tax_Amount__c == null || ord.DRC_NBC_Other_Tax_Amount__c == 0) {
                    BCLineItem taxLine = bcTaxLines.get('OTHER_TAX');
                    linesToDelete.put(taxLine.lineNo, taxLine.key);
                    linesToUpdate.remove(taxLine.lineNo);
                    System.debug('  OTHER TAX marked for DELETE (amount → zero) | Line: ' + taxLine.lineNo + ' | Key: ' + taxLine.key);
                } else {
                    System.debug('  OTHER TAX PRESERVED (amt: ' + ord.DRC_NBC_Other_Tax_Amount__c + ')');
                }
            }
            if (bcTaxLines.containsKey('TCS')) {
                if (ord.DRC_NBC_TCS_Amount__c == null || ord.DRC_NBC_TCS_Amount__c == 0) {
                    BCLineItem taxLine = bcTaxLines.get('TCS');
                    linesToDelete.put(taxLine.lineNo, taxLine.key);
                    linesToUpdate.remove(taxLine.lineNo);
                    System.debug('  TCS marked for DELETE (amount → zero) | Line: ' + taxLine.lineNo + ' | Key: ' + taxLine.key);
                } else {
                    System.debug('  TCS PRESERVED (amt: ' + ord.DRC_NBC_TCS_Amount__c + ')');
                }
            }
            if (bcTaxLines.containsKey('FREIGHT')) {
                if (ord.DRC_NBC_Fright_Charges__c == null || ord.DRC_NBC_Fright_Charges__c == 0) {
                    BCLineItem taxLine = bcTaxLines.get('FREIGHT');
                    linesToDelete.put(taxLine.lineNo, taxLine.key);
                    linesToUpdate.remove(taxLine.lineNo);
                    System.debug('  FREIGHT marked for DELETE (amount → zero) | Line: ' + taxLine.lineNo + ' | Key: ' + taxLine.key);
                } else {
                    System.debug('  FREIGHT PRESERVED (amt: ' + ord.DRC_NBC_Fright_Charges__c + ')');
                }
            }
            if (bcTaxLines.containsKey('INSURANCE')) {
                if (ord.DRC_NBC_Insurance__c == null || ord.DRC_NBC_Insurance__c == 0) {
                    BCLineItem taxLine = bcTaxLines.get('INSURANCE');
                    linesToDelete.put(taxLine.lineNo, taxLine.key);
                    linesToUpdate.remove(taxLine.lineNo);
                    System.debug('  INSURANCE marked for DELETE (amount → zero) | Line: ' + taxLine.lineNo + ' | Key: ' + taxLine.key);
                } else {
                    System.debug('  INSURANCE PRESERVED (amt: ' + ord.DRC_NBC_Insurance__c + ')');
                }
            }
            
            System.debug('DEBUG PAYLOAD >>> linesToUpdate (FINAL): ' + JSON.serializePretty(linesToUpdate));
            System.debug('DEBUG PAYLOAD >>> linesToDelete (FINAL): ' + JSON.serializePretty(linesToDelete));
            System.debug('DEBUG PAYLOAD >>> itemsToCreate (FINAL count=' + itemsToCreate.size() + ')');
            
            String updateResult = 'NO_UPDATE';
            String createResult = 'NO_CREATE';
            String deleteResult = 'NO_DELETE';
            
            // --- STEP 1: UPDATE matched lines ---
            if (!linesToUpdate.isEmpty()) {
                System.debug('  STEP 1: Updating ' + linesToUpdate.size() + ' lines...');
                updateResult = updateMultipleLineItems(
                    bcOrderNo, linesToUpdate, orderItems, ord, orderId, bcLineDetails, restrictedProductMap
                );
                System.debug('DEBUG PAYLOAD >>> Update Result: ' + updateResult);
                
                if (updateResult.startsWith('ERROR') || updateResult.startsWith('FAILURE')) {
                    System.debug('DEBUG PAYLOAD >>> UpdateMultiple failed. Halting line item sync.');
                    return 'ERROR: UpdateMultiple Line Items failed. Detail: ' + updateResult;
                }
            } else {
                System.debug('DEBUG PAYLOAD >>> No lines to update. Skipping STEP 1.');
            }
            
            // --- STEP 2: CREATE new items ---
            if (!itemsToCreate.isEmpty()) {
                Integer maxLineNo = 0;
                for (Integer lineNo : bcLineDetails.keySet()) {
                    if (lineNo > maxLineNo) { maxLineNo = lineNo; }
                }
                Integer nextLineNo = maxLineNo + 10000;
                System.debug('  STEP 2: Creating ' + itemsToCreate.size() + ' items at line ' + nextLineNo);
                System.debug('DEBUG PAYLOAD >>> maxLineNo: ' + maxLineNo + ' | nextLineNo: ' + nextLineNo);
                createResult = DRC_NBC_LineItemCreator.createLineItemsAtLineNumber(
                    bcOrderNo, itemsToCreate, ord, nextLineNo
                );
                System.debug('DEBUG PAYLOAD >>> Create Result: ' + createResult);
                
                if (createResult.startsWith('ERROR') || createResult.startsWith('FAILURE')) {
                    System.debug('DEBUG PAYLOAD >>> CreateMultiple failed. Halting line item sync.');
                    return 'ERROR: Create Line Items failed. Detail: ' + createResult;
                }
            } else {
                System.debug('DEBUG PAYLOAD >>> No items to create. Skipping STEP 2.');
            }
            
            // --- STEP 3: DELETE unmatched / zeroed lines ---
            if (!linesToDelete.isEmpty()) {
                System.debug('  STEP 3: Deleting ' + linesToDelete.size() + ' lines...');
                deleteResult = DRC_NBC_LineItemDeleter.deleteLineItems(linesToDelete);
                System.debug('DEBUG PAYLOAD >>> Delete Result: ' + deleteResult);
                
                if (deleteResult.startsWith('ERROR') || deleteResult.startsWith('FAILURE')) {
                    System.debug('DEBUG PAYLOAD >>> DeleteMultiple failed. Halting line item sync.');
                    return 'ERROR: Delete Line Items failed. Detail: ' + deleteResult;
                }
            } else {
                System.debug('DEBUG PAYLOAD >>> No lines to delete. Skipping STEP 3.');
            }
            
            // --- STEP 4: DML after all callouts ---
            if (!linesToUpdate.isEmpty()) {
                System.debug('  STEP 4: Updating SF Order status after callouts...');
                System.debug('DEBUG PAYLOAD >>> Calling DRC_NBC_OrderReadUpdateQueueable.execute for orderId: ' + orderId);
                DRC_NBC_OrderReadUpdateQueueable.execute(orderId);
            } else {
                System.debug('DEBUG PAYLOAD >>> Skipping STEP 4 (no lines updated).');
            }
            
            String finalResult = 'UPDATE: ' + updateResult + ' | CREATE: ' + createResult + ' | DELETE: ' + deleteResult;
            System.debug('DEBUG PAYLOAD >>> intelligentLineItemSync FINAL RESULT: ' + finalResult);
            return finalResult;
            
        } catch (Exception ex) {
            System.debug('  *** Intelligent Sync Exception: ' + ex.getMessage());
            System.debug('DEBUG PAYLOAD >>> Stack Trace: ' + ex.getStackTraceString());
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    // ========================================================================
    // CALLOUT: READ ORDER
    // ========================================================================
    
    private static BCOrderReadResult readOrderFromBC(Order ord) {
        System.debug('=================================================================');
        System.debug('  *** READ Order Operation Started ***');
        System.debug('=================================================================');
        
        String requestBody = buildReadSOAPRequest(ord.DRC_NBC_Cust_Order_Number__c);
        String sfOrderId   = String.valueOf(ord.Id);
        
        System.debug('DEBUG PAYLOAD >>> readOrderFromBC | Endpoint: ' + BC_ORDER_ENDPOINT);
        System.debug('DEBUG PAYLOAD >>> readOrderFromBC | SOAPAction: ' + SOAP_ORDER_NAMESPACE + ':Read');
        System.debug('DEBUG PAYLOAD >>> readOrderFromBC | Request Body: ' + requestBody);
        
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
            System.debug('DEBUG PAYLOAD >>> readOrderFromBC | Response Status Code: ' + response.getStatusCode());
            System.debug('DEBUG PAYLOAD >>> readOrderFromBC | Response Status: '      + response.getStatus());
            System.debug('DEBUG PAYLOAD >>> readOrderFromBC | Response Body: '        + response.getBody());
            
            if (response.getStatusCode() == 200) {
                BCOrderReadResult result = extractKeyAndStatusFromReadResponse(response.getBody());
                System.debug('DEBUG PAYLOAD >>> readOrderFromBC | Extracted Result: ' + (result != null
                    ? ('Key=' + result.key + ' | Status=' + result.status)
                    : 'NULL'));
                
                if (result == null || String.isBlank(result.key)) {
                    System.debug('DEBUG PAYLOAD >>> readOrderFromBC | Key or Status missing. Logging error.');
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
                System.debug('DEBUG PAYLOAD >>> readOrderFromBC | Non-200 response. Logging error.');
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
            System.debug('DEBUG PAYLOAD >>> readOrderFromBC | Exception Stack: ' + ex.getStackTraceString());
            DRC_NBC_API_Log_Handler.createApiLog(
                BC_ORDER_ENDPOINT, requestBody, null,'readOrderFromBC',ex.getMessage(), null, ex.getStackTraceString(),LOG_TYPE_ERROR, sfOrderId
            );
            return null;
        }
    }
    
    // ========================================================================
    // CALLOUT: REOPEN ORDER (Released → Open)
    // ========================================================================
    
    @TestVisible
    private static String reopenOrderInBC(String bcKey, Order ord) {
        System.debug('=================================================================');
        System.debug('  *** REOPEN Order Operation Started ***');
        System.debug('=================================================================');
        
        String requestBody = buildReopenOrderSOAPRequest(bcKey, ord.DRC_NBC_Cust_Order_Number__c);
        String sfOrderId   = String.valueOf(ord.Id);
        
        System.debug('DEBUG PAYLOAD >>> reopenOrderInBC | bcKey: ' + bcKey + ' | bcOrderNo: ' + ord.DRC_NBC_Cust_Order_Number__c);
        System.debug('DEBUG PAYLOAD >>> reopenOrderInBC | Endpoint: ' + BC_ORDER_ENDPOINT);
        System.debug('DEBUG PAYLOAD >>> reopenOrderInBC | SOAPAction: ' + SOAP_ORDER_NAMESPACE + ':Update');
        System.debug('DEBUG PAYLOAD >>> reopenOrderInBC | Request Body: ' + requestBody);
        
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
            System.debug('DEBUG PAYLOAD >>> reopenOrderInBC | Response Status Code: ' + response.getStatusCode());
            System.debug('DEBUG PAYLOAD >>> reopenOrderInBC | Response Status: '      + response.getStatus());
            System.debug('DEBUG PAYLOAD >>> reopenOrderInBC | Response Body: '        + response.getBody());
            
            if (response.getStatusCode() == 200) {
                System.debug('  Order Reopened Successfully (Released → Open)');
                return 'REOPEN_SUCCESS';
            } else {
                System.debug('DEBUG PAYLOAD >>> reopenOrderInBC | Non-200 response. Logging error.');
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
            System.debug('DEBUG PAYLOAD >>> reopenOrderInBC | Exception Stack: ' + ex.getStackTraceString());
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
    // ========================================================================
    
    private static String updateOrderInBC(String bcKey, Order ord, Boolean updateSF) {
        System.debug('=================================================================');
        System.debug('  *** UPDATE Order Operation Started ***');
        System.debug('=================================================================');
        
        DRC_NBC_Integration_Payload.OrderPayload payload =
            DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(ord);
        
        System.debug('DEBUG PAYLOAD >>> updateOrderInBC | Mapped OrderPayload (BEFORE Location_Code lookup): ' + JSON.serializePretty(payload));
        
        String requestBody = buildUpdateOrderSOAPRequest(bcKey, payload, ord);
        String sfOrderId   = String.valueOf(ord.Id);
        
        System.debug('========== ORDER UPDATE PAYLOAD ==========');
        System.debug('Order Id            : ' + ord.Id);
        System.debug('BC Customer Order No: ' + ord.DRC_NBC_Cust_Order_Number__c);
        System.debug('BC Key              : ' + bcKey);
        System.debug('Full Payload (JSON) : ' + JSON.serializePretty(payload));
        System.debug('SOAP Request Body   : ' + requestBody);
        System.debug('==========================================');
        
        System.debug('DEBUG PAYLOAD >>> updateOrderInBC | Endpoint: ' + BC_ORDER_ENDPOINT);
        System.debug('DEBUG PAYLOAD >>> updateOrderInBC | SOAPAction: ' + SOAP_ORDER_NAMESPACE + ':Update');
        
        System.debug('  Syncing Shipping Address before Order update...');
        String shipSyncResult = DRC_NBC_UpdateShippingAddress.syncShippingAddress(ord.Id);
        System.debug('DEBUG PAYLOAD >>> updateOrderInBC | Shipping Sync Result: ' + shipSyncResult);
        
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
            System.debug('DEBUG PAYLOAD >>> updateOrderInBC | Response Status Code: ' + response.getStatusCode());
            System.debug('DEBUG PAYLOAD >>> updateOrderInBC | Response Status: '      + response.getStatus());
            System.debug('DEBUG PAYLOAD >>> updateOrderInBC | Response Body: '        + response.getBody());
            
            if (response.getStatusCode() == 200) {
                System.debug('  Order Updated Successfully in BC');
                return 'ORDER_UPDATE_SUCCESS';
            } else {
                System.debug('DEBUG PAYLOAD >>> updateOrderInBC | Non-200 response. Logging error.');
                DRC_NBC_API_Log_Handler.createApiLog(
                    BC_ORDER_ENDPOINT, requestBody, response.getBody(), 'updateOrderInBC','Non-200 response. HTTP ' + response.getStatusCode() + ': ' + response.getStatus(),response.getStatusCode(), null,LOG_TYPE_ERROR, sfOrderId
                );
                return 'FAILURE: ' + response.getStatusCode();
            }
            
        } catch (Exception ex) {
            System.debug('  *** UPDATE Exception: ' + ex.getMessage());
            System.debug('DEBUG PAYLOAD >>> updateOrderInBC | Exception Stack: ' + ex.getStackTraceString());
            DRC_NBC_API_Log_Handler.createApiLog(
                BC_ORDER_ENDPOINT, requestBody, null,'updateOrderInBC',ex.getMessage(), null, ex.getStackTraceString(),LOG_TYPE_ERROR, sfOrderId
            );
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    // ========================================================================
    // CALLOUT: READ MULTIPLE LINE ITEMS
    // ========================================================================
    
    private static Map<Integer, BCLineItem> readMultipleLineItemsWithDetails(
        String bcOrderNo, Id orderId) {
            
            System.debug('=================================================================');
            System.debug('    *** ReadMultiple Line Items Started ***');
            System.debug('=================================================================');
            
            String requestBody = buildReadMultipleSOAPRequest(bcOrderNo);
            String sfOrderId   = String.valueOf(orderId);
            
            System.debug('DEBUG PAYLOAD >>> readMultipleLineItemsWithDetails | bcOrderNo: ' + bcOrderNo + ' | orderId: ' + orderId);
            System.debug('DEBUG PAYLOAD >>> readMultipleLineItemsWithDetails | Endpoint: ' + BC_LINE_ITEM_ENDPOINT);
            System.debug('DEBUG PAYLOAD >>> readMultipleLineItemsWithDetails | SOAPAction: ' + SOAP_LINE_NAMESPACE + ':ReadMultiple');
            System.debug('DEBUG PAYLOAD >>> readMultipleLineItemsWithDetails | Request Body: ' + requestBody);
            
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
                System.debug('DEBUG PAYLOAD >>> readMultipleLineItemsWithDetails | Response Status Code: ' + response.getStatusCode());
                System.debug('DEBUG PAYLOAD >>> readMultipleLineItemsWithDetails | Response Status: '      + response.getStatus());
                System.debug('DEBUG PAYLOAD >>> readMultipleLineItemsWithDetails | Response Body: '        + response.getBody());
                
                if (response.getStatusCode() == 200) {
                    Map<Integer, BCLineItem> result = extractLineDetailsFromReadMultiple(response.getBody());
                    System.debug('DEBUG PAYLOAD >>> readMultipleLineItemsWithDetails | Extracted Result: ' + JSON.serializePretty(result));
                    System.debug('    Extracted ' + result.size() + ' line items');
                    return result;
                } else {
                    System.debug('DEBUG PAYLOAD >>> readMultipleLineItemsWithDetails | Non-200 response. Logging error.');
                    DRC_NBC_API_Log_Handler.createApiLog(
                        BC_LINE_ITEM_ENDPOINT, requestBody, response.getBody(),'readMultipleLineItemsWithDetails','Non-200 response. HTTP ' + response.getStatusCode() + ': ' + response.getStatus(),response.getStatusCode(), null,LOG_TYPE_ERROR, sfOrderId
                    );
                    return null;
                }
                
            } catch (Exception ex) {
                System.debug('    *** ReadMultiple Exception: ' + ex.getMessage());
                System.debug('DEBUG PAYLOAD >>> readMultipleLineItemsWithDetails | Exception Stack: ' + ex.getStackTraceString());
                DRC_NBC_API_Log_Handler.createApiLog(
                    BC_LINE_ITEM_ENDPOINT, requestBody, null,'readMultipleLineItemsWithDetails',ex.getMessage(), null, ex.getStackTraceString(),LOG_TYPE_ERROR, sfOrderId
                );
                return null;
            }
        }
    
    // ========================================================================
    // CALLOUT: UPDATE MULTIPLE LINE ITEMS
    // ========================================================================
    
    @TestVisible
    private static String updateMultipleLineItems(
        String bcOrderNo,
        Map<Integer, String> bcLineKeys,
        List<OrderItem> orderItems,
        Order ord,
        Id orderId,
        Map<Integer, BCLineItem> bcLineDetails,
        Map<Id, String> restrictedProductMap) {
            
            System.debug('=================================================================');
            System.debug('    *** UpdateMultiple Started ***');
            System.debug('=================================================================');
            System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | bcOrderNo: ' + bcOrderNo + ' | orderId: ' + orderId);
            System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | bcLineKeys (input): ' + JSON.serializePretty(bcLineKeys));
            System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | restrictedProductMap (input): ' + JSON.serializePretty(restrictedProductMap));
            
            String sfOrderId   = String.valueOf(orderId);
            String requestBody = '';
            
            try {
                // Inside updateMultipleLineItems:
                Order freshOrd = [
                    SELECT DRC_NBC_Warehouse__c, DRC_NBC_Other_Tax_Amount__c,
                    DRC_NBC_TCS_Amount__c, DRC_NBC_Fright_Charges__c, DRC_NBC_Insurance__c,
                    DRC_NBC_Cust_Order_Number__c, RecordType.Name,
                    DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
                    Is_Domestic_Merchnat__c
                    FROM Order
                    WHERE Id = :orderId
                    LIMIT 1
                ];
                
                System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | freshOrd: ' + JSON.serializePretty(freshOrd));
                
                requestBody = buildUpdateMultipleSOAPRequest(
                    bcOrderNo, bcLineKeys, orderItems, freshOrd, bcLineDetails, restrictedProductMap);
                
                System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | Endpoint: ' + BC_LINE_ITEM_ENDPOINT);
                System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | SOAPAction: ' + SOAP_LINE_NAMESPACE + ':UpdateMultiple');
                System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | Request Body: ' + requestBody);
                
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
                System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | Response Status Code: ' + response.getStatusCode());
                System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | Response Status: '      + response.getStatus());
                System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | Response Body: '        + response.getBody());
                
                if (response.getStatusCode() == 200) {
                    return 'SUCCESS';
                } else {
                    System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | Non-200 response. Logging error.');
                    DRC_NBC_API_Log_Handler.createApiLog(
                        BC_LINE_ITEM_ENDPOINT, requestBody, response.getBody(),'updateMultipleLineItems', 'Non-200 response. HTTP ' + response.getStatusCode() + ': ' + response.getStatus(),  response.getStatusCode(), null,LOG_TYPE_ERROR, sfOrderId
                    );
                    return 'FAILURE: ' + response.getStatusCode();
                }
                
            } catch (Exception ex) {
                System.debug('    *** UpdateMultiple Exception: ' + ex.getMessage());
                System.debug('DEBUG PAYLOAD >>> updateMultipleLineItems | Exception Stack: ' + ex.getStackTraceString());
                DRC_NBC_API_Log_Handler.createApiLog(
                    BC_LINE_ITEM_ENDPOINT, requestBody, null, 'updateMultipleLineItems',ex.getMessage(), null, ex.getStackTraceString(),LOG_TYPE_ERROR, sfOrderId
                );
                return 'ERROR: ' + ex.getMessage();
            }
        }
    // ========================================================================
    // SOAP REQUEST BUILDERS
    // ========================================================================
    
    Public static String buildReadSOAPRequest(String bcOrderNumber) {
        String body =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read xmlns="' + SOAP_ORDER_NAMESPACE + '">' +
            '<Document_Type>Order</Document_Type>' +
            '<No>' + escapeXml(bcOrderNumber) + '</No>' +
            '</Read>' +
            '</soap:Body>' +
            '</soap:Envelope>';
        System.debug('DEBUG PAYLOAD >>> buildReadSOAPRequest | bcOrderNumber: ' + bcOrderNumber);
        System.debug('DEBUG PAYLOAD >>> buildReadSOAPRequest | Built Body: ' + body);
        return body;
    }
    
    @TestVisible
    private static String buildReopenOrderSOAPRequest(String bcKey, String bcOrderNo) {
        String body =
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
        System.debug('DEBUG PAYLOAD >>> buildReopenOrderSOAPRequest | bcKey: ' + bcKey + ' | bcOrderNo: ' + bcOrderNo);
        System.debug('DEBUG PAYLOAD >>> buildReopenOrderSOAPRequest | Built Body: ' + body);
        return body;
    }
    
    private static String buildUpdateOrderSOAPRequest(
        String bcKey,
        DRC_NBC_Integration_Payload.OrderPayload payload,
        Order ord) {
            
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | bcKey: ' + bcKey);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | Incoming payload: ' + JSON.serializePretty(payload));
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | Order.DRC_NBC_Warehouse__c: ' + ord.DRC_NBC_Warehouse__c);
            
            if (String.isNotBlank(ord.DRC_NBC_Warehouse__c)) {
                List<Warehouse_Location_Code__mdt> metaList = [
                    SELECT DRC_NBC_Code__c FROM Warehouse_Location_Code__mdt
                    WHERE MasterLabel = :ord.DRC_NBC_Warehouse__c
                    AND DRC_NBC_Type__c = 'Warehouse Location'
                    LIMIT 1
                ];
                System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | Warehouse_Location_Code__mdt query result: ' + JSON.serializePretty(metaList));
                if (!metaList.isEmpty()) {
                    payload.Location_Code = metaList[0].DRC_NBC_Code__c;
                    System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | Resolved Location_Code: ' + payload.Location_Code);
                } else {
                    System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | No Location_Code metadata found for warehouse: ' + ord.DRC_NBC_Warehouse__c);
                }
            }
            
            System.debug('Order Payload => ' + JSON.serialize(payload));
            System.debug('bcKey => '         + bcKey);
            System.debug('Order Id => '      + ord.Id);
            System.debug('Order Type => '    + ord.DRC_NBC_Type__c);
            
            String dispatchDateVal            = String.isNotBlank(payload.DispatchDate)
                ? payload.DispatchDate : '';
            String poDateVal                  = String.isNotBlank(payload.PO_Date)
                ? payload.PO_Date : '';
            String requestedDeliveryDateVal   = String.isNotBlank(payload.Requested_Delivery_Date)
                ? payload.Requested_Delivery_Date : '';
            String courierDateVal             = String.isNotBlank(payload.Courier_Date)
                ? payload.Courier_Date : '';
            String modeOfTransportVal         = String.isNotBlank(payload.Mode_of_Transport)
                ? payload.Mode_of_Transport : '';
            String companyBankCodeVal         = String.isNotBlank(payload.Company_Bank_Account_Code_New)
                ? payload.Company_Bank_Account_Code_New : '';
            String partShipmentVal            = String.isNotBlank(payload.Part_Shipment)
                ? payload.Part_Shipment : '';
            String transShipmentVal           = String.isNotBlank(payload.Trans_Shipment)
                ? payload.Trans_Shipment : '';
            String deliveryTermsVal           = String.isNotBlank(payload.Delivery_Terms)
                ? payload.Delivery_Terms : '';
            String transporterCodeVal         = String.isNotBlank(payload.Transporter_Code)
                ? payload.Transporter_Code : '';
            String courierNumberVal           = String.isNotBlank(payload.Courier_Number)
                ? payload.Courier_Number : '';
            String countryOfOriginVal         = String.isNotBlank(payload.Country_Of_Origin_Of_Goods)
                ? payload.Country_Of_Origin_Of_Goods : '';
            String countryOfFinalDestVal      = String.isNotBlank(payload.Country_Of_Final_Destination)
                ? payload.Country_Of_Final_Destination : '';
            String notifyNameVal              = String.isNotBlank(payload.Notify_Name)
                ? payload.Notify_Name : '';
            String vesselFlightNoVal          = String.isNotBlank(payload.Vessel_Flight_No)
                ? payload.Vessel_Flight_No : '';
            String portOfDischargeVal         = String.isNotBlank(payload.Port_Of_Discharge)
                ? payload.Port_Of_Discharge : '';
            String portOfLoadingVal           = String.isNotBlank(payload.Port_of_Loading)
                ? payload.Port_of_Loading : '';
            String finalDestinationVal        = String.isNotBlank(payload.Final_Destination)
                ? payload.Final_Destination : '';
            String placeOfReceiptVal          = String.isNotBlank(payload.Place_of_receipt_pre_carrier)
                ? payload.Place_of_receipt_pre_carrier : '';
            String currencyCodeVal            = String.isNotBlank(payload.Currency_Code)
                ? payload.Currency_Code : '';
            
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | dispatchDateVal: '          + dispatchDateVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | poDateVal: '                 + poDateVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | requestedDeliveryDateVal: '  + requestedDeliveryDateVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | courierDateVal: '            + courierDateVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | modeOfTransportVal: '        + modeOfTransportVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | companyBankCodeVal: '        + companyBankCodeVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | partShipmentVal: '           + partShipmentVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | transShipmentVal: '          + transShipmentVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | deliveryTermsVal: '          + deliveryTermsVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | transporterCodeVal: '        + transporterCodeVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | courierNumberVal: '          + courierNumberVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | countryOfOriginVal: '        + countryOfOriginVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | countryOfFinalDestVal: '     + countryOfFinalDestVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | notifyNameVal: '             + notifyNameVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | vesselFlightNoVal: '         + vesselFlightNoVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | portOfDischargeVal: '        + portOfDischargeVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | portOfLoadingVal: '          + portOfLoadingVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | finalDestinationVal: '       + finalDestinationVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | placeOfReceiptVal: '         + placeOfReceiptVal);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | currencyCodeVal: '           + currencyCodeVal);
            
            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<Update xmlns="' + SOAP_ORDER_NAMESPACE + '">' +
                '<SalesOrderSalesForce>' +
                '<Key>'                             + escapeXml(bcKey)                               + '</Key>' +
                '<No>'                              + escapeXml(payload.No)                          + '</No>' +
                '<Document_Type>Order</Document_Type>' +
                '<Sell_to_Customer_No>'             + escapeXml(payload.Sell_to_Customer_No)         + '</Sell_to_Customer_No>' +
                '<Sell_to_Customer_Name>'           + escapeXml(payload.Sell_to_Customer_Name)       + '</Sell_to_Customer_Name>' +
                '<Sell_to_Address>'                 + escapeXml(payload.Sell_to_Address)             + '</Sell_to_Address>' +
                '<Sell_to_Address_2>'               + escapeXml(payload.Sell_to_Address_2)           + '</Sell_to_Address_2>' +
                '<Sell_to_City>'                    + escapeXml(payload.Sell_to_City)                + '</Sell_to_City>' +
                '<Sell_to_Post_Code>'               + escapeXml(payload.Sell_to_Post_Code)           + '</Sell_to_Post_Code>' +
                '<Order_Date>'                      + escapeXml(payload.Order_Date)                  + '</Order_Date>' +
                '<External_Document_No>'            + escapeXml(payload.External_Document_No)        + '</External_Document_No>' +
                '<Salesperson_Code>'                + escapeXml(payload.Salesperson_Code)            + '</Salesperson_Code>' +
                '<Status>Open</Status>' +
                '<Location_Code>'                   + escapeXml(payload.Location_Code)               + '</Location_Code>' +
                '<Payment_Terms_Code>'              + escapeXml(payload.Payment_Terms_Code)          + '</Payment_Terms_Code>' +
                '<Shipment_Method_Code>'            + escapeXml(payload.Shipment_Method_Code)        + '</Shipment_Method_Code>' +
                '<Sample_Sales>'                    + payload.Sample_Sales                           + '</Sample_Sales>' +
                '<Salesforce_So_No>'                + escapeXml(payload.Salesforce_So_No)            + '</Salesforce_So_No>' +
                '<Ship_to_Code>'                    + escapeXml(payload.Ship_to_Code)                + '</Ship_to_Code>' +
                '<Ship_to_Name>'                    + escapeXml(payload.Ship_to_Name)                + '</Ship_to_Name>' +
                '<Ship_to_Name_2>'                  + escapeXml(payload.Ship_to_Name_2)              + '</Ship_to_Name_2>' +
                '<Ship_to_Address>'                 + escapeXml(payload.Ship_to_Address)             + '</Ship_to_Address>' +
                '<Ship_to_Address_2>'               + escapeXml(payload.Ship_to_Address_2)           + '</Ship_to_Address_2>' +
                '<Ship_to_Post_Code>'               + escapeXml(payload.Ship_to_Post_Code)           + '</Ship_to_Post_Code>' +
                '<Ship_to_Country_Region_Code>'     + escapeXml(payload.Ship_to_Country_Region_Code) + '</Ship_to_Country_Region_Code>' +
                '<Salesforce_Order_Amount>'         + payload.Salesforce_Order_Amount                + '</Salesforce_Order_Amount>' +
                '<Salesforce_Order_Created>'        + payload.Salesforce_Order_Created               + '</Salesforce_Order_Created>' +
                '<Export_Document>'                 + payload.Export_Document                        + '</Export_Document>' +
                '<Company_Bank_Account_Code_New>'   + escapeXml(companyBankCodeVal)                  + '</Company_Bank_Account_Code_New>' +
                '<PO_Date>'                         + escapeXml(poDateVal)                           + '</PO_Date>' +
                '<Requested_Delivery_Date>'         + escapeXml(requestedDeliveryDateVal)            + '</Requested_Delivery_Date>' +
                '<Courier_Date>'                    + escapeXml(courierDateVal)                      + '</Courier_Date>' +
                '<DispatchDate>'                    + escapeXml(dispatchDateVal)                     + '</DispatchDate>' +
                '<Mode_of_Transport>'               + escapeXml(modeOfTransportVal)                  + '</Mode_of_Transport>' +
                '<Part_Shipment>'                   + escapeXml(partShipmentVal)                     + '</Part_Shipment>' +
                '<Trans_Shipment>'                  + escapeXml(transShipmentVal)                    + '</Trans_Shipment>' +
                '<Delivery_Terms>'                  + escapeXml(deliveryTermsVal)                    + '</Delivery_Terms>' +
                '<Transporter_Code>'                + escapeXml(transporterCodeVal)                  + '</Transporter_Code>' +
                '<Courier_Number>'                  + escapeXml(courierNumberVal)                    + '</Courier_Number>' +
                '<Currency_Code>'                   + escapeXml(currencyCodeVal)                     + '</Currency_Code>' +
                '<Country_Of_Origin_Of_Goods>'      + escapeXml(countryOfOriginVal)                  + '</Country_Of_Origin_Of_Goods>' +
                '<Country_Of_Final_Destination>'    + escapeXml(countryOfFinalDestVal)               + '</Country_Of_Final_Destination>' +
                '<Notify_Name>'                     + escapeXml(notifyNameVal)                       + '</Notify_Name>' +
                '<Place_of_receipt_pre_carrier>'    + escapeXml(placeOfReceiptVal)                   + '</Place_of_receipt_pre_carrier>' +
                '<Vessel_Flight_No>'                + escapeXml(vesselFlightNoVal)                   + '</Vessel_Flight_No>' +
                '<Port_Of_Discharge>'               + escapeXml(portOfDischargeVal)                  + '</Port_Of_Discharge>' +
                '<Port_of_Loading>'                 + escapeXml(portOfLoadingVal)                    + '</Port_of_Loading>' +
                '<Final_Destination>'               + escapeXml(finalDestinationVal)                 + '</Final_Destination>' +
                '</SalesOrderSalesForce>' +
                '</Update>' +
                '</soap:Body>' +
                '</soap:Envelope>';
            
            System.debug('SOAP Request Body: ' + soapBody);
            System.debug('DEBUG PAYLOAD >>> buildUpdateOrderSOAPRequest | Final Built SOAP Body: ' + soapBody);
            return soapBody;
        }
    
    private static String buildReadMultipleSOAPRequest(String bcOrderNo) {
        String body =
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
        System.debug('DEBUG PAYLOAD >>> buildReadMultipleSOAPRequest | bcOrderNo: ' + bcOrderNo);
        System.debug('DEBUG PAYLOAD >>> buildReadMultipleSOAPRequest | Built Body: ' + body);
        return body;
    }
    
    @TestVisible
    private static String buildUpdateMultipleSOAPRequest(
        String bcOrderNo,
        Map<Integer, String> bcLineKeys,
        List<OrderItem> orderItems,
        Order ord,
        Map<Integer, BCLineItem> bcLineDetails,
        Map<Id, String> restrictedProductMap) {
            
            System.debug('=================================================================');
            System.debug('    *** buildUpdateMultipleSOAPRequest Started ***');
            System.debug('=================================================================');
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | bcOrderNo: ' + bcOrderNo);
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | bcLineKeys: ' + JSON.serializePretty(bcLineKeys));
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | ord: ' + JSON.serializePretty(ord));
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | bcLineDetails: ' + JSON.serializePretty(bcLineDetails));
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | restrictedProductMap: ' + JSON.serializePretty(restrictedProductMap));
            
            String orderLocationCode = getLocationCodeFromWarehouse(ord.DRC_NBC_Warehouse__c);
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | orderLocationCode: ' + orderLocationCode);
            System.debug('orderLocationCode: ' + orderLocationCode);
            
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
                        } else if (bcLine.description != null && bcLine.description.contains('Freight')) {
                            taxKeys.put('FREIGHT', bcKey);
                            taxLineNos.put('FREIGHT', lineNo);
                        } else if (bcLine.description != null && bcLine.description.contains('Insurance')) {
                            taxKeys.put('INSURANCE', bcKey);
                            taxLineNos.put('INSURANCE', lineNo);
                        }
                    }
                }
            }
            
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | productKeys: ' + JSON.serializePretty(productKeys));
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | taxKeys: '     + JSON.serializePretty(taxKeys));
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | taxLineNos: '  + JSON.serializePretty(taxLineNos));
            
            List<Integer> sortedProductLineNos = new List<Integer>(productKeys.keySet());
            sortedProductLineNos.sort();
            
            Map<String, OrderItem> sfItemsByFGCode = new Map<String, OrderItem>();
            for (OrderItem item : orderItems) {
                sfItemsByFGCode.put(item.Product2.DRC_NBC_FG_Code__c, item);
            }
            
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | sfItemsByFGCode keys: ' + sfItemsByFGCode.keySet());
            
            // ── Product lines ────────────────────────────────────────────────────────
            for (Integer lineNo : sortedProductLineNos) {
                String     bcKey  = productKeys.get(lineNo);
                BCLineItem bcLine = bcLineDetails.get(lineNo);
                if (bcLine == null) {
                    System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | bcLine NULL for lineNo: ' + lineNo + '. Skipping.');
                    continue;
                }
                
                OrderItem matchedItem = sfItemsByFGCode.get(bcLine.itemNo);
                if (matchedItem == null) {
                    System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | No matched SF item for BC itemNo: ' + bcLine.itemNo + ' (lineNo: ' + lineNo + '). Skipping.');
                    continue;
                }
                
                Boolean isSampleOrder      = matchedItem.Order.RecordType.Name == 'Sample_Order';
                Decimal discountPercent    = matchedItem.DRC_NBC_Discount__c    != null ? matchedItem.DRC_NBC_Discount__c    : 0;
                Decimal totalPrice         = matchedItem.DRC_NBC_Total_Price__c  != null ? matchedItem.DRC_NBC_Total_Price__c  : 0;
                Decimal lineDiscountAmount = (totalPrice * discountPercent) / 100;
                
                if (isSampleOrder) {
                    totalPrice         = 0;
                    lineDiscountAmount = 0;
                }
                
                System.debug('DEBUG PAYLOAD >>> Product Line | lineNo: ' + lineNo
                    + ' | bcKey: ' + bcKey
                    + ' | itemNo: ' + bcLine.itemNo
                    + ' | isSampleOrder: ' + isSampleOrder
                    + ' | discountPercent: ' + discountPercent
                    + ' | totalPrice: ' + totalPrice
                    + ' | lineDiscountAmount: ' + lineDiscountAmount
                    + ' | UnitPrice(raw): ' + matchedItem.UnitPrice
                    + ' | Quantity: ' + matchedItem.Quantity);
                
                // ✅ GST fields respect Is_Domestic_Merchnat__c
                String gstGroupCode = '';
                String hsnSacCode   = '';
                if (matchedItem.Order.Is_Domestic_Merchnat__c == true) {
                    gstGroupCode = Label.Merchnat_GST_Group_Code;
                    //   hsnSacCode   = Label.Merchnat_HSN_SAC_Code;
                } else {
                    gstGroupCode = String.isNotBlank(matchedItem.Product2.DRC_NBC_GST_Group_Code__c)
                        ? matchedItem.Product2.DRC_NBC_GST_Group_Code__c : '';
                    hsnSacCode   = String.isNotBlank(matchedItem.Product2.DRC_NBC_HSN_SAC_Code__c)
                        ? matchedItem.Product2.DRC_NBC_HSN_SAC_Code__c : '';
                }
                
                System.debug('DEBUG PAYLOAD >>> Product Line | lineNo: ' + lineNo
                    + ' | Is_Domestic_Merchnat__c: ' + matchedItem.Order.Is_Domestic_Merchnat__c
                    + ' | gstGroupCode: ' + gstGroupCode
                    + ' | hsnSacCode: ' + hsnSacCode);
                
                // ✅ Item_Reference_No from Restricted Product map — same logic as batch
                String itemReferenceNo = restrictedProductMap.containsKey(matchedItem.Product2Id)
                    ? restrictedProductMap.get(matchedItem.Product2Id)
                    : '';
                System.debug('  Item Reference No (Restricted Product Name): ' + itemReferenceNo + ' for FG: ' + bcLine.itemNo);
                System.debug('DEBUG PAYLOAD >>> Product Line | lineNo: ' + lineNo
                    + ' | Product2Id: ' + matchedItem.Product2Id
                    + ' | itemReferenceNo: ' + itemReferenceNo
                    + ' | Item_Reference_Type_No (CustomerNumber): ' + matchedItem.Order.Account.DRC_NBC_Customer_Number__c
                    + ' | Item_Reference_Type (AccountType): ' + matchedItem.Order.Account.Type);
                
                soapBody +=
                    '<SalesOrderLineSalesForce>' +
                    '<Key>'                            + escapeXml(bcKey)                                                                                     + '</Key>' +
                    '<Document_Type>Order</Document_Type>' +
                    '<Document_No>'                    + escapeXml(bcOrderNo)                                                                                 + '</Document_No>' +
                    '<Line_No>'                        + lineNo                                                                                               + '</Line_No>' +
                    '<Type>Item</Type>' +
                    '<No>'                             + escapeXml(matchedItem.Product2.DRC_NBC_FG_Code__c)                                                   + '</No>' +
                    '<Customer_item_no>'               + escapeXml(matchedItem.Product2.DRC_NBC_FG_Code__c)                                                   + '</Customer_item_no>' +
                    '<Description>'                    + escapeXml(matchedItem.Description != null ? matchedItem.Description : '')                            + '</Description>' +
                    '<Quantity>'                       + (matchedItem.Quantity  != null ? matchedItem.Quantity  : 0)                                          + '</Quantity>' +
                    '<Unit_of_Measure_Code>KGS</Unit_of_Measure_Code>' +
                    '<Unit_Price>'                     + (isSampleOrder ? 0 : (matchedItem.UnitPrice != null ? matchedItem.UnitPrice : 0))                   + '</Unit_Price>' +
                    '<Line_Amount>'                    + totalPrice                                                                                           + '</Line_Amount>' +
                    '<Line_Discount_Percent>'          + discountPercent                                                                                      + '</Line_Discount_Percent>' +
                    '<Line_Discount_Amount>'           + lineDiscountAmount                                                                                   + '</Line_Discount_Amount>' +
                    '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                    '<GST_Credit>'                     + GST_CREDIT_VALUE                                                                                     + '</GST_Credit>' +
                    '<Location_Code>'                  + escapeXml(orderLocationCode)                                                                         + '</Location_Code>' +
                    '<GST_Group_Code>'                 + escapeXml(gstGroupCode)                                                                              + '</GST_Group_Code>' +
                    '<HSN_SAC_Code>'                   + escapeXml(hsnSacCode)                                                                                + '</HSN_SAC_Code>' +
                    '<Packing_Details>'                + escapeXml(matchedItem.DRC_NBC_Packing_Size__c)                                                       + '</Packing_Details>' +
                    '<No_of_Pkg_for_Qty>'              + (matchedItem.Quantity != null ? matchedItem.Quantity : 0)                                            + '</No_of_Pkg_for_Qty>' +
                    '<Hazardous>'                      + (matchedItem.DRC_NBC_Hazardous__c == true)                                                           + '</Hazardous>' +
                    '<MarkNosContainerNos>'            + escapeXml(String.isBlank(matchedItem.DRC_NBC_MARKS_NOS__c) ? '' : matchedItem.DRC_NBC_MARKS_NOS__c.trim()) + '</MarkNosContainerNos>' +
                    // ✅ UPDATED: Item_Reference_No now from Restricted Product map
                    '<Item_Reference_No>'              + escapeXml(itemReferenceNo)                                                                           + '</Item_Reference_No>' +
                    '<Item_Reference_Type_No>'        + escapeXml(matchedItem.Order.Account.DRC_NBC_Customer_Number__c != null ? matchedItem.Order.Account.DRC_NBC_Customer_Number__c : '') + '</Item_Reference_Type_No>' +
                    '<Item_Reference_Type>'         + escapeXml(matchedItem.Order.Account.Type != null ? matchedItem.Order.Account.Type : '')              + '</Item_Reference_Type>' +

                    '<Item_Reference_Unit_of_Measure>KGS</Item_Reference_Unit_of_Measure>' +
                    '</SalesOrderLineSalesForce>';
            }
            
            // ── Other Tax Line ───────────────────────────────────────────────────────
            if (taxKeys.containsKey('OTHER_TAX') &&
                ord.DRC_NBC_Other_Tax_Amount__c != null && ord.DRC_NBC_Other_Tax_Amount__c != 0) {
                    
                    String  otherTaxKey    = taxKeys.get('OTHER_TAX');
                    Integer otherTaxLineNo = taxLineNos.get('OTHER_TAX');
                    String glGstGroup = ord.Is_Domestic_Merchnat__c == true ? Label.Merchnat_GST_Group_Code : '';
                    String glHsnSac   = ord.Is_Domestic_Merchnat__c == true ? Label.Merchnat_HSN_SAC_Code   : '';
                    
                    System.debug('DEBUG PAYLOAD >>> Other Tax Line | lineNo: ' + otherTaxLineNo
                        + ' | key: ' + otherTaxKey
                        + ' | amount: ' + ord.DRC_NBC_Other_Tax_Amount__c
                        + ' | glGstGroup: ' + glGstGroup
                        + ' | glHsnSac: ' + glHsnSac);
                    
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
                        '<Unit_of_Measure_Code>KGS</Unit_of_Measure_Code>' +
                        '<Location_Code>'         + escapeXml(orderLocationCode)    + '</Location_Code>' +
                        '<Unit_Price>'            + ord.DRC_NBC_Other_Tax_Amount__c + '</Unit_Price>' +
                        '<Line_Amount>'           + ord.DRC_NBC_Other_Tax_Amount__c + '</Line_Amount>' +
                        '<Line_Discount_Percent>0</Line_Discount_Percent>' +
                        '<Line_Discount_Amount>0</Line_Discount_Amount>' +
                        '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                        '<GST_Credit>_blank_</GST_Credit>' +
                        '<GST_Group_Code>'        + escapeXml(glGstGroup)           + '</GST_Group_Code>' +
                        // '<HSN_SAC_Code>'          + escapeXml(glHsnSac)             + '</HSN_SAC_Code>' +
                        '<HSN_SAC_Code></HSN_SAC_Code>' +
                        '<Packing_Details></Packing_Details>' +
                        '<No_of_Pkg_for_Qty>1</No_of_Pkg_for_Qty>' +
                        '<Hazardous>false</Hazardous>' +
                        '<MarkNosContainerNos></MarkNosContainerNos>' +
                        '<Item_Reference_No></Item_Reference_No>' +
                        '<Item_Reference_Type></Item_Reference_Type>' +
                        '<Item_Reference_Type_No></Item_Reference_Type_No>' +
                        '<Item_Reference_Unit_of_Measure>KGS</Item_Reference_Unit_of_Measure>' +
                        '</SalesOrderLineSalesForce>';
                }
            
            // ── TCS Line ─────────────────────────────────────────────────────────────
            if (taxKeys.containsKey('TCS') &&
                ord.DRC_NBC_TCS_Amount__c != null && ord.DRC_NBC_TCS_Amount__c != 0) {
                    
                    String  tcsKey    = taxKeys.get('TCS');
                    Integer tcsLineNo = taxLineNos.get('TCS');
                    String glGstGroup = ord.Is_Domestic_Merchnat__c == true ? Label.Merchnat_GST_Group_Code : '';
                    String glHsnSac   = ord.Is_Domestic_Merchnat__c == true ? Label.Merchnat_HSN_SAC_Code   : '';
                    
                    System.debug('DEBUG PAYLOAD >>> TCS Line | lineNo: ' + tcsLineNo
                        + ' | key: ' + tcsKey
                        + ' | amount: ' + ord.DRC_NBC_TCS_Amount__c
                        + ' | glGstGroup: ' + glGstGroup
                        + ' | glHsnSac: ' + glHsnSac);
                    
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
                        '<Unit_of_Measure_Code>KGS</Unit_of_Measure_Code>' +
                        '<Location_Code>'         + escapeXml(orderLocationCode)  + '</Location_Code>' +
                        '<Unit_Price>'            + ord.DRC_NBC_TCS_Amount__c     + '</Unit_Price>' +
                        '<Line_Amount>'           + ord.DRC_NBC_TCS_Amount__c     + '</Line_Amount>' +
                        '<Line_Discount_Percent>0</Line_Discount_Percent>' +
                        '<Line_Discount_Amount>0</Line_Discount_Amount>' +
                        '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                        '<GST_Credit>_blank_</GST_Credit>' +
                        '<GST_Group_Code>'        + escapeXml(glGstGroup)         + '</GST_Group_Code>' +
                        // '<HSN_SAC_Code>'          + escapeXml(glHsnSac)           + '</HSN_SAC_Code>' +
                        '<HSN_SAC_Code></HSN_SAC_Code>' +
                        '<Packing_Details></Packing_Details>' +
                        '<No_of_Pkg_for_Qty>1</No_of_Pkg_for_Qty>' +
                        '<Hazardous>false</Hazardous>' +
                        '<MarkNosContainerNos></MarkNosContainerNos>' +
                        '<Item_Reference_No></Item_Reference_No>' +
                        '<Item_Reference_Type></Item_Reference_Type>' +
                        '<Item_Reference_Type_No></Item_Reference_Type_No>' +
                        '<Item_Reference_Unit_of_Measure>KGS</Item_Reference_Unit_of_Measure>' +
                        '</SalesOrderLineSalesForce>';
                }
            
            // ── Freight Charges Line ─────────────────────────────────────────────────
            if (taxKeys.containsKey('FREIGHT') &&
                ord.DRC_NBC_Fright_Charges__c != null && ord.DRC_NBC_Fright_Charges__c != 0) {
                    
                    String  freightKey    = taxKeys.get('FREIGHT');
                    Integer freightLineNo = taxLineNos.get('FREIGHT');
                    String glGstGroup = ord.Is_Domestic_Merchnat__c == true ? Label.Merchnat_GST_Group_Code : '';
                    String glHsnSac   = ord.Is_Domestic_Merchnat__c == true ? Label.Merchnat_HSN_SAC_Code   : '';
                    
                    System.debug('DEBUG PAYLOAD >>> Freight Line | lineNo: ' + freightLineNo
                        + ' | key: ' + freightKey
                        + ' | amount: ' + ord.DRC_NBC_Fright_Charges__c
                        + ' | glGstGroup: ' + glGstGroup
                        + ' | glHsnSac: ' + glHsnSac
                        + ' | GLAccountNo (Label.DRC_TCS_Tax_Number): ' + Label.DRC_TCS_Tax_Number);
                    
                    soapBody +=
                        '<SalesOrderLineSalesForce>' +
                        '<Key>'                   + escapeXml(freightKey)             + '</Key>' +
                        '<Document_Type>Order</Document_Type>' +
                        '<Document_No>'           + escapeXml(bcOrderNo)              + '</Document_No>' +
                        '<Line_No>'               + freightLineNo                     + '</Line_No>' +
                        '<Type>G/L Account</Type>' +
                        '<No>'                    + Label.DRC_TCS_Tax_Number          + '</No>' +
                        '<Customer_item_no></Customer_item_no>' +
                        '<Description>Freight Charges</Description>' +
                        '<Quantity>1</Quantity>' +
                        '<Unit_of_Measure_Code>KGS</Unit_of_Measure_Code>' +
                        '<Location_Code>'         + escapeXml(orderLocationCode)      + '</Location_Code>' +
                        '<Unit_Price>'            + ord.DRC_NBC_Fright_Charges__c     + '</Unit_Price>' +
                        '<Line_Amount>'           + ord.DRC_NBC_Fright_Charges__c     + '</Line_Amount>' +
                        '<Line_Discount_Percent>0</Line_Discount_Percent>' +
                        '<Line_Discount_Amount>0</Line_Discount_Amount>' +
                        '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                        '<GST_Credit>_blank_</GST_Credit>' +
                        '<GST_Group_Code>'        + escapeXml(glGstGroup)             + '</GST_Group_Code>' +
                        // '<HSN_SAC_Code>'          + escapeXml(glHsnSac)               + '</HSN_SAC_Code>' +
                        '<HSN_SAC_Code></HSN_SAC_Code>' +
                        '<Packing_Details></Packing_Details>' +
                        '<No_of_Pkg_for_Qty>1</No_of_Pkg_for_Qty>' +
                        '<Hazardous>false</Hazardous>' +
                        '<MarkNosContainerNos></MarkNosContainerNos>' +
                        '<Item_Reference_No></Item_Reference_No>' +
                        '<Item_Reference_Type></Item_Reference_Type>' +
                        '<Item_Reference_Type_No></Item_Reference_Type_No>' +
                        '<Item_Reference_Unit_of_Measure>KGS</Item_Reference_Unit_of_Measure>' +
                        '</SalesOrderLineSalesForce>';
                }
            
            // ── Insurance Line ────────────────────────────────────────────────────────
            if (taxKeys.containsKey('INSURANCE') &&
                ord.DRC_NBC_Insurance__c != null && ord.DRC_NBC_Insurance__c != 0) {
                    
                    String  insuranceKey    = taxKeys.get('INSURANCE');
                    Integer insuranceLineNo = taxLineNos.get('INSURANCE');
                    String glGstGroup = ord.Is_Domestic_Merchnat__c == true ? Label.Merchnat_GST_Group_Code : '';
                    String glHsnSac   = ord.Is_Domestic_Merchnat__c == true ? Label.Merchnat_HSN_SAC_Code   : '';
                    
                    System.debug('DEBUG PAYLOAD >>> Insurance Line | lineNo: ' + insuranceLineNo
                        + ' | key: ' + insuranceKey
                        + ' | amount: ' + ord.DRC_NBC_Insurance__c
                        + ' | glGstGroup: ' + glGstGroup
                        + ' | glHsnSac: ' + glHsnSac
                        + ' | GLAccountNo (Label.DRC_TCS_Tax_Number): ' + Label.DRC_TCS_Tax_Number);
                    
                    soapBody +=
                        '<SalesOrderLineSalesForce>' +
                        '<Key>'                   + escapeXml(insuranceKey)          + '</Key>' +
                        '<Document_Type>Order</Document_Type>' +
                        '<Document_No>'           + escapeXml(bcOrderNo)             + '</Document_No>' +
                        '<Line_No>'               + insuranceLineNo                  + '</Line_No>' +
                        '<Type>G/L Account</Type>' +
                        '<No>'                    + Label.DRC_TCS_Tax_Number         + '</No>' +
                        '<Customer_item_no></Customer_item_no>' +
                        '<Description>Insurance</Description>' +
                        '<Quantity>1</Quantity>' +
                        '<Unit_of_Measure_Code>KGS</Unit_of_Measure_Code>' +
                        '<Location_Code>'         + escapeXml(orderLocationCode)     + '</Location_Code>' +
                        '<Unit_Price>'            + ord.DRC_NBC_Insurance__c         + '</Unit_Price>' +
                        '<Line_Amount>'           + ord.DRC_NBC_Insurance__c         + '</Line_Amount>' +
                        '<Line_Discount_Percent>0</Line_Discount_Percent>' +
                        '<Line_Discount_Amount>0</Line_Discount_Amount>' +
                        '<Inv_Discount_Amount>0</Inv_Discount_Amount>' +
                        '<GST_Credit>_blank_</GST_Credit>' +
                        '<GST_Group_Code>'        + escapeXml(glGstGroup)            + '</GST_Group_Code>' +
                        // '<HSN_SAC_Code>'          + escapeXml(glHsnSac)              + '</HSN_SAC_Code>' +
                        '<HSN_SAC_Code></HSN_SAC_Code>' +
                        '<Packing_Details></Packing_Details>' +
                        '<No_of_Pkg_for_Qty>1</No_of_Pkg_for_Qty>' +
                        '<Hazardous>false</Hazardous>' +
                        '<MarkNosContainerNos></MarkNosContainerNos>' +
                        '<Item_Reference_No></Item_Reference_No>' +
                        '<Item_Reference_Type></Item_Reference_Type>' +
                        '<Item_Reference_Type_No></Item_Reference_Type_No>' +
                        '<Item_Reference_Unit_of_Measure>KGS</Item_Reference_Unit_of_Measure>' +
                        '</SalesOrderLineSalesForce>';
                }
            
            soapBody +=
                '</SalesOrderLineSalesForce_List>' +
                '</UpdateMultiple>' +
                '</soap:Body>' +
                '</soap:Envelope>';
            
            System.debug('DEBUG PAYLOAD >>> buildUpdateMultipleSOAPRequest | Final Built SOAP Body: ' + soapBody);
            return soapBody;
        }
    
    // ========================================================================
    // RESPONSE PARSERS
    // ========================================================================
    
    private static BCOrderReadResult extractKeyAndStatusFromReadResponse(String xmlResponse) {
        System.debug('DEBUG PAYLOAD >>> extractKeyAndStatusFromReadResponse | Input XML: ' + xmlResponse);
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
            System.debug('DEBUG PAYLOAD >>> extractKeyAndStatusFromReadResponse | Parsed Key: ' + key + ' | Parsed Status: ' + status);
            return (key != null) ? new BCOrderReadResult(key, status) : null;
            
        } catch (Exception ex) {
            System.debug('Exception extracting Key/Status: ' + ex.getMessage());
            System.debug('DEBUG PAYLOAD >>> extractKeyAndStatusFromReadResponse | Exception Stack: ' + ex.getStackTraceString());
            return null;
        }
    }
    
    private static Map<Integer, BCLineItem> extractLineDetailsFromReadMultiple(String xmlResponse) {
        System.debug('DEBUG PAYLOAD >>> extractLineDetailsFromReadMultiple | Input XML: ' + xmlResponse);
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
                                                System.debug('DEBUG PAYLOAD >>> extractLineDetailsFromReadMultiple | Parsed Line: '
                                                    + 'lineNo=' + lineNo
                                                    + ' | key=' + key
                                                    + ' | type=' + lineType
                                                    + ' | itemNo=' + itemNo
                                                    + ' | qty=' + quantity
                                                    + ' | desc=' + description);
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
            System.debug('DEBUG PAYLOAD >>> extractLineDetailsFromReadMultiple | Exception Stack: ' + ex.getStackTraceString());
        }
        
        System.debug('DEBUG PAYLOAD >>> extractLineDetailsFromReadMultiple | Final Map: ' + JSON.serializePretty(lineDetailsMap));
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
        System.debug('DEBUG PAYLOAD >>> getLocationCodeFromWarehouse | Input warehouseLabel: ' + warehouseLabel);
        if (String.isBlank(warehouseLabel)) return '';
        
        List<Warehouse_Location_Code__mdt> metaList = [
            SELECT DRC_NBC_Code__c FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel = :warehouseLabel
            AND DRC_NBC_Type__c = 'Warehouse Location'
            LIMIT 1
        ];
        
        System.debug('DEBUG PAYLOAD >>> getLocationCodeFromWarehouse | metaList result: ' + JSON.serializePretty(metaList));
        
        String result = metaList.isEmpty() ? '' : metaList[0].DRC_NBC_Code__c;
        System.debug('DEBUG PAYLOAD >>> getLocationCodeFromWarehouse | Resolved Code: ' + result);
        return result;
    }
}