public class DRC_NBC_Shipping_Then_Order_Future {
    
    /**
* This future method handles the sequence:
* 1. Shipping Callout (after Ship-To Code has been generated)
* 2. Order Callout
* 
* Called when Ship-To Code needs to be generated first
*/
    @future(callout=true)
    public static void processShippingThenOrder(Id accountId, Id orderId) {
        try {
            System.debug('=== Starting Shipping Then Order Sequence ===');
            
            // STEP 1: Process Shipping Callout
            String shippingResult = processShipping(accountId, orderId);
            System.debug('Shipping Result → ' + shippingResult);
            
            // STEP 2: Process Order Callout
            String orderResult = processOrder(orderId);
            System.debug('Order Result → ' + orderResult);
            
            System.debug('=== Completed Shipping Then Order Sequence ===');
            
        } catch (Exception e) {
            System.debug('Shipping Then Order Future → FAILURE: ' + e.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Shipping_Then_Order_Future',
                null,
                null,
                'FutureMethod',
                e.getMessage(),
                null,
                e.getStackTraceString(),
                'Error',
                orderId
            );
        }
    }
    
    private static String processShipping(Id accountId, Id orderId) {
        try {
            DRC_NBC_Integration_Payload.ShipToPayload payloads = 
                DRC_NBC_Shipping_BC_Callout.getShippingPayload(accountId, orderId);
            
            if (payloads == null) {
                return 'FAILURE: No shipping addresses found.';
            }
            
            String jsonBody = JSON.serialize(payloads, true);
            String endpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_Shipping_Address_Endpoint__c;
            DRC_NBC_Shipping_BC_Integration integration = new DRC_NBC_Shipping_BC_Integration(
                endpoint, 'POST', jsonBody, accountId
            );
            HttpResponse response = integration.executeAndReturnResponse();
            
            if (response == null || (response.getStatusCode() != 200 && response.getStatusCode() != 201)) {
                return 'FAILURE: HTTP ' + (response != null ? String.valueOf(response.getStatusCode()) : 'NO_RESPONSE');
            }
            
            return 'SUCCESS';
            
        } catch (Exception e) {
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Shipping_Then_Order_Future',
                null, null, 'FutureMethod',
                'Shipping Error: ' + e.getMessage(), null, e.getStackTraceString(),
                'Error', accountId
            );
            return 'FAILURE: ' + e.getMessage();
        }
    }
    
    private static String processOrder(Id orderId) {
        try {
            Order order = DRC_NBC_Order_BC_Callout.getOrderDetails(orderId);
            
            // Check if order number needs generation
            if (String.isBlank(order.DRC_NBC_Cust_Order_Number__c)) {
                // Can't do DML in @future(callout=true)
                // Log error and skip
                String errorMsg = 'Order number is blank and cannot be generated in callout future method';
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_Shipping_Then_Order_Future',
                    null, null, 'FutureMethod',
                    errorMsg, null, null,
                    'Error', orderId
                );
                return 'FAILURE: ' + errorMsg;
            }
            
            // Prepare payload and make callout
            DRC_NBC_Integration_Payload.OrderPayload payload = DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(order);
            String jsonBody = JSON.serialize(payload, true);
            String endpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_SendOrderEndpoint__c;
            
            DRC_NBC_Order_BC_Integration integration = new DRC_NBC_Order_BC_Integration(endpoint, 'POST', jsonBody, orderId); 
            HttpResponse response = integration.executeAndReturnResponse();
            
            if (integration.httpStatusCode != null && integration.httpStatusCode == 201) {
                // Success - trigger order update
                DRC_NBC_Order_BC_Update_Service.processOrderUpdate(orderId);
                return 'SUCCESS';
            } else {
                String failureMsg = 'FAILURE: ' + (integration.responseSummary != null ? integration.responseSummary : 'No response body');
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_Shipping_Then_Order_Future',
                    null, null, 'FutureMethod',
                    'Order Error: ' + failureMsg, null, null,
                    'Error', orderId
                );
                return failureMsg;
            }
            
        } catch (Exception e) {
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Shipping_Then_Order_Future',
                null, null, 'FutureMethod',
                'Order Error: ' + e.getMessage(), null, e.getStackTraceString(),
                'Error', orderId
            );
            return 'FAILURE: ' + e.getMessage();
        }
    }
}