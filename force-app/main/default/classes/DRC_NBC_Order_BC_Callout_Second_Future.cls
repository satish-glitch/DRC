public class DRC_NBC_Order_BC_Callout_Second_Future {

    @future(callout=true)
    public static void processOrderBC(Id orderId) {
        try {
            Order order = DRC_NBC_Order_BC_Callout.getOrderDetails(orderId);
            // Prepare payload and make callout
            DRC_NBC_Integration_Payload.OrderPayload payload = DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(order);
            String jsonBody = JSON.serialize(payload, true);
            String endpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_SendOrderEndpoint__c;
            
            DRC_NBC_Order_BC_Integration integration = new DRC_NBC_Order_BC_Integration(endpoint, 'POST', jsonBody, orderId); 
            HttpResponse response = integration.executeAndReturnResponse();
            
            if (integration.httpStatusCode != null && integration.httpStatusCode == 201) {
                // Callout succeeded - update order
                DRC_NBC_Order_BC_Update_Service.processOrderUpdate(orderId);
                System.debug('Order BC Future → Order Sync SUCCESS. Order updated.');
            } else {
                String failureMsg = 'FAILURE: ' + (integration.responseSummary != null ? integration.responseSummary : 'No response body');
                System.debug('Order BC Future → ' + failureMsg);
                logError(orderId, failureMsg);
            }
            
        } catch (Exception e) {
            System.debug('Order BC Future → FAILURE: ' + e.getMessage());
            logError(orderId, e.getMessage());
        }
    }
    
    private static void logError(Id orderId, String errorMsg) {
        DRC_NBC_API_Log_Handler.createApiLog(
            'DRC_NBC_Order_BC_Callout_Second_Future',
            null,
            null,
            'FutureMethod',
            errorMsg,
            null,
            null,
            'Error',
            orderId
        );
    }
}