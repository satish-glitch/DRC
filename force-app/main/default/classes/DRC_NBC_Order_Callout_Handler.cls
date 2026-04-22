public class DRC_NBC_Order_Callout_Handler implements Queueable, Database.AllowsCallouts {
    
    private Id orderId;
    
    public DRC_NBC_Order_Callout_Handler(Id orderId) {
        this.orderId = orderId;
    }
    
    public void execute(QueueableContext context) {
        try {
            System.debug('=== Shipping Callout Handler Started ===');
            
            Order order = DRC_NBC_Order_BC_Callout.getOrderDetails(orderId);
            Id accountId = order.AccountId;
            
            // STEP 1: Shipping Callout (only if shipping address is linked)
            if (order.DRC_NBC_Shipping_Address__c != null) {
                
                Boolean canCreate = DRC_NBC_CheckShiipingDetails.checkShippingExists(orderId, accountId);
                
                if (canCreate) {
                    String shippingResult = processShippingCallout(accountId, orderId);
                    System.debug('Shipping BC Result → ' + shippingResult);
                    
                    if (!shippingResult.startsWith('SUCCESS')) {
                        System.debug('Shipping callout failed: ' + shippingResult);
                        // Intentionally continuing to order callout even on shipping failure
                    }
                } else {
                    System.debug('Ship-To already exists in BC - skipping shipping callout');
                }
                
            } else {
                System.debug('No shipping address linked to order - skipping shipping callout');
            }
            
            System.debug('=== Shipping Callout Handler Completed ===');
            
            // STEP 2: Always chain to Order Callout Handler regardless of shipping outcome
            System.debug('Chaining to Order Callout Handler...');
            System.enqueueJob(new DRC_NBC_Order_Only_Callout_Handler(orderId));
            
        } catch (Exception e) {
            System.debug('Shipping Callout Handler → FAILURE: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    // Process shipping callout (pure callout, no DML)
    public String processShippingCallout(Id accountId, Id orderId) {
        try {
            DRC_NBC_Integration_Payload.ShipToPayload payload = 
                DRC_NBC_Shipping_BC_Callout.getShippingPayload(accountId, orderId);
            
            if (payload == null) {
                return 'FAILURE: No shipping addresses found.';
            }
            
            String jsonBody = JSON.serialize(payload, true);
            String endpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_Shipping_Address_Endpoint__c;
            
            DRC_NBC_Shipping_BC_Integration integration = new DRC_NBC_Shipping_BC_Integration(
                endpoint, 'POST', jsonBody, accountId
            );
            HttpResponse response = integration.executeAndReturnResponse();
            
            if (response != null && (response.getStatusCode() == 200 || response.getStatusCode() == 201)) {
                return 'SUCCESS: HTTP ' + response.getStatusCode();
            } else {
                return 'FAILURE: HTTP ' + (response != null ? String.valueOf(response.getStatusCode()) : 'NO_RESPONSE');
            }
            
        } catch (Exception e) {
            System.debug('Shipping Error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return 'FAILURE: ' + e.getMessage();
        }
    }
}