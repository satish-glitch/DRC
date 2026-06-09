public class DRC_NBC_Order_Only_Callout_Handler implements Queueable, Database.AllowsCallouts {
    
    private Id orderId;
    
    public DRC_NBC_Order_Only_Callout_Handler(Id orderId) {
        this.orderId = orderId;
    }
    
    public void execute(QueueableContext context) {
        try {
            System.debug('=== Order Callout Handler Started ===');
            executeOrderCallout(orderId);
            System.debug('=== Order Callout Handler Completed ===');
            
        } catch (Exception e) {
            System.debug('Order Callout Handler → FAILURE: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    private void executeOrderCallout(Id orderId) {
        try {
            Order order = DRC_NBC_Order_BC_Callout.getOrderDetails(orderId);
            
            // Validate required fields
            if (String.isBlank(order.DRC_NBC_Cust_Order_Number__c)) {
                String errorMsg = 'Order number is still blank after DML handler';
                System.debug('Order Callout Handler → FAILURE: ' + errorMsg);
                return;
            }
            
            String custOrderNumber = order.DRC_NBC_Cust_Order_Number__c;
            String baseEndpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_SendOrderEndpoint__c;
            
            // ─── STEP 1: GET — Check if order already exists in BC ───────────────
            Boolean orderExistsInBC = checkOrderExistsInBC(baseEndpoint, custOrderNumber);
            
            if (orderExistsInBC) {
                // Order already present in BC → skip POST, treat as success
                System.debug('Order already exists in BC for No: ' + custOrderNumber + ' → Skipping POST.');
                DRC_NBC_Order_BC_Update_Service.processOrderUpdate(orderId);
                System.debug('Order update queued (already existed in BC).');
                return;
            }
            
            // ─── STEP 2: POST — Order not found in BC, create it ─────────────────
            System.debug('Order not found in BC → Proceeding with POST.');
            
            DRC_NBC_Integration_Payload.OrderPayload payload = 
                DRC_NBC_Order_BC_Callout.mapOrderToBCPayload(order);
            String jsonBody = JSON.serialize(payload, true);
            
            System.debug('Order Endpoint URL → ' + baseEndpoint);
            System.debug('Order Payload >>> ' + jsonBody.substring(0, Math.min(500, jsonBody.length())));
            
            DRC_NBC_Order_BC_Integration integration = new DRC_NBC_Order_BC_Integration(
                baseEndpoint, 'POST', jsonBody, orderId
            );
            HttpResponse response = integration.executeAndReturnResponse();
            
            if (integration.httpStatusCode != null && integration.httpStatusCode == 201) {
                System.debug('Order Callout Handler → Order Sync SUCCESS');
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
    
    /**
* GET request to BC OData endpoint to check if an order with the given
* customer order number already exists.
*
* URL pattern:  <baseEndpoint>?$filter=No eq '<custOrderNumber>'
*
* Returns true  → value array is non-empty  (order exists)
* Returns false → value array is empty OR any error occurred
*/
    private Boolean checkOrderExistsInBC(String baseEndpoint, String custOrderNumber) {
        try {
            // Encode the customer order number for safe URL embedding
            String encodedOrderNo = EncodingUtil.urlEncode(custOrderNumber, 'UTF-8');
            String fullEndpoint = DRC_NBC_BC_Callout_Utility.getFullEndpoint(baseEndpoint);
            String getEndpoint   = fullEndpoint + '?$filter=No eq \'' + encodedOrderNo + '\'';
            
            System.debug('BC GET Check URL → ' + getEndpoint);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(getEndpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setTimeout(120000);
            
            // Reuse whatever auth the utility provides (Named Credential / Basic Auth)
            // If your integration class sets auth via a Named Credential on the endpoint,
            // this plain HttpRequest will also honour it automatically.
            // If you need explicit Basic Auth, uncomment and adapt the lines below:
            //
            // String creds = EncodingUtil.base64Encode(
            //     Blob.valueOf('Salesforce:Admin@2026')
            // );
            // req.setHeader('Authorization', 'Basic ' + creds);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('BC GET Status  → ' + res.getStatusCode());
            System.debug('BC GET Body    → ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = 
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                List<Object> valueList = (List<Object>) responseMap.get('value');
                
                if (valueList != null && !valueList.isEmpty()) {
                    System.debug('BC GET → Order EXISTS in BC. Count: ' + valueList.size());
                    return true;
                } else {
                    System.debug('BC GET → Order NOT found in BC (empty value array).');
                    return false;
                }
            } else {
                System.debug('BC GET → Non-200 response (' + res.getStatusCode() + '). Treating as not found.');
                return false;
            }
            
        } catch (Exception e) {
            System.debug('BC GET Check Error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // On error, default to false so POST is attempted
            return false;
        }
    }
}