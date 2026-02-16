public class DRC_NBC_Order_Only_Callout_Handler implements Queueable, Database.AllowsCallouts {
    
    private Id orderId;
    
    /**
* Callout-only Queueable - ORDER ONLY
* This handles ONLY Order HTTP callout
* Called after Shipping callout completes
*/
    public DRC_NBC_Order_Only_Callout_Handler(Id orderId) {
        this.orderId = orderId;
    }
    
    public void execute(QueueableContext context) {
        try {
            System.debug('=== Order Callout Handler Started ===');
            // Execute Order Callout
            executeOrderCallout(orderId);
            System.debug('=== Order Callout Handler Completed ===');
            
        } catch (Exception e) {
            System.debug('Order Callout Handler → FAILURE: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    // Execute order callout (pure callout, no DML)
    private void executeOrderCallout(Id orderId) {
        try {
            Order order = DRC_NBC_Order_BC_Callout.getOrderDetails(orderId);
            
            // Validate required fields
            if (String.isBlank(order.DRC_NBC_Cust_Order_Number__c)) {
                String errorMsg = 'Order number is still blank after DML handler';
                System.debug('Order Callout Handler → FAILURE: ' + errorMsg);
                return;
            }
            
            // Prepare payload and make callout
            DRC_NBC_Integration_Payload.OrderPayload payload = 
                DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(order);
            String jsonBody = JSON.serialize(payload, true);
            String endpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_SendOrderEndpoint__c;
            
            System.debug('Order Endpoint URL → ' + endpoint);
            System.debug('Order Payload >>> ' + jsonBody.substring(0, Math.min(500, jsonBody.length())));
            
            DRC_NBC_Order_BC_Integration integration = new DRC_NBC_Order_BC_Integration(
                endpoint, 'POST', jsonBody, orderId
            ); 
            HttpResponse response = integration.executeAndReturnResponse();
            
            if (integration.httpStatusCode != null && integration.httpStatusCode == 201) {
                System.debug('Order Callout Handler → Order Sync SUCCESS');
                // Chain to Order Update Queueable (separate DML context)
                DRC_NBC_Order_BC_Update_Service.processOrderUpdate(orderId);
                System.debug('Order update queued in separate Queueable');
                
            } else {
                String failureMsg = 'FAILURE: ' + (integration.responseSummary != null ? 
                                                   integration.responseSummary : 'No response body');
                System.debug('Order Callout Handler → ' + failureMsg);
                DRC_NBC_Order_BC_Update_Service.failedOrderUpdate(orderId);
                
            }
            
        } catch (Exception e) {
            System.debug('Order Callout Error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
}