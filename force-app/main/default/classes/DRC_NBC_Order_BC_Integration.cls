/**
* @File Name : DRC_NBC_Order_BC_Integration.cls
* @Description : Handles actual BC Order callout logic (called by the queueable class)
* @Author : Satish
* @Last Modified On : November 12, 2025
**/

public class DRC_NBC_Order_BC_Integration extends DRC_NBC_Base_API_Integration {
    
    private String apiPath;
    private String httpMethod;
    private String payload;
    private Id orderId;
    public String responseSummary;
    public Integer httpStatusCode;
    
    public DRC_NBC_Order_BC_Integration(String apiPath, String httpMethod, String payload, Id orderId) {
        this.apiPath = apiPath;
        this.httpMethod = httpMethod;
        this.payload = payload;
        this.orderId = orderId;
    }
    
    public override HttpRequest prepareRequest() {
        HttpRequest request = new HttpRequest();
        String fullEndpoint = DRC_NBC_BC_Callout_Utility.getFullEndpoint(apiPath);
        request.setEndpoint(fullEndpoint);
        request.setTimeout(120000);
        request.setMethod(this.httpMethod);
        DRC_NBC_BC_Callout_Utility.prepareRequest(request);
        request.setBody(payload);
        
        System.debug('BC Order Payload >>> ' + DRC_NBC_BC_Callout_Utility.trimPayload(payload));
        return request;
    }
    
    public override void processResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        String responseBody = response.getBody();
        this.httpStatusCode = response.getStatusCode();
        this.responseSummary = response.getBody();
        System.debug('BC Order Callout Response >>> ' + responseBody);
        System.debug('Status Code >>> ' + statusCode);
        
        if (statusCode >= 200 && statusCode < 300) {
            
            sendBlobFields(orderId);
            
            // Success logging
            DRC_NBC_API_Log_Handler.createApiLog(
                this.apiPath,
                DRC_NBC_BC_Callout_Utility.trimPayload(payload),
                DRC_NBC_BC_Callout_Utility.trimPayload(responseBody),
                this.httpMethod,
                null,
                statusCode,
                null,
                'Success',
                orderId
            );
        } else {
            // Error logging
            DRC_NBC_API_Log_Handler.createApiLog(
                this.apiPath,
                DRC_NBC_BC_Callout_Utility.trimPayload(payload),
                DRC_NBC_BC_Callout_Utility.trimPayload(responseBody),
                this.httpMethod,
                'Non-success status code received.',
                statusCode,
                null,
                'Error',
                orderId
            ); 
            System.debug('BC Order POST failed with status: ' + statusCode);
        }
    }
    
    // ── Blob field sender ─────────────────────────────────────────────────────
    
    public void sendBlobFields(Id orderId ) {
        try {
            // Query order directly here — no dependency on constructor parameter
            Order ord = [
                SELECT DRC_NBC_Cust_Order_Number__c,
                DRC_NBC_Special_request__c,
                DRC_NBC_Remarks__c
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
            
            if (String.isBlank(ord.DRC_NBC_Cust_Order_Number__c)) {
                System.debug('sendBlobFields: skipped — DRC_NBC_Cust_Order_Number__c is blank.');
                return;
            }
            
            String baseMediaUrl = DRC_NBC_BC_Callout_Utility.getFullEndpoint(
                DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_SendOrderEndpoint__c
            )
                + '(Document_Type=\'Order\',No=\''
                + ord.DRC_NBC_Cust_Order_Number__c
                + '\')';
            
            if (String.isNotBlank(ord.DRC_NBC_Special_request__c)) {
                sendSingleBlobField(
                    baseMediaUrl + '/Work_Description',
                    ord.DRC_NBC_Special_request__c,
                    'Work_Description'
                );
            }
            System.debug('baseMediaUrl>>>>>' +  baseMediaUrl);
            if (String.isNotBlank(ord.DRC_NBC_Remarks__c)) {
                sendSingleBlobField(
                    baseMediaUrl + '/Remarks',
                    ord.DRC_NBC_Remarks__c,
                    'Remarks'
                );
            }
            
        } catch (Exception e) {
            System.debug('sendBlobFields query error: ' + e.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Order_BC_Integration',
                null, null, 'PATCH',
                'sendBlobFields query exception: ' + e.getMessage(),
                null, null, 'Error', orderId
            );
        }
    }
    
    public void sendSingleBlobField(String mediaUrl, String value, String fieldName) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(mediaUrl);
            req.setMethod('PATCH');
            req.setTimeout(120000);
            DRC_NBC_BC_Callout_Utility.prepareRequest(req);
            
            String username = 'CRM.1';
            String password = 'Admin@2025';
            String encoded  = EncodingUtil.base64Encode(
                Blob.valueOf(username + ':' + password)
            );
            req.setHeader('Authorization', 'Basic ' + encoded);  // ← was missing
            req.setHeader('Content-Type', 'text/plain');
            req.setHeader('If-Match', '*');
            req.setBody(value);
            
            HttpResponse res = new Http().send(req);
            System.debug(fieldName + ' blob PATCH → ' + res.getStatusCode()
                         + ' | ' + res.getBody());
            
        /*    DRC_NBC_API_Log_Handler.createApiLog(
                mediaUrl,
                value.length() > 255 ? value.substring(0, 255) : value,
                res.getBody(),
                'PATCH',
                res.getStatusCode() == 204 ? null : fieldName + ' blob PATCH failed: ' + res.getBody(),
                res.getStatusCode(),
                null,
                res.getStatusCode() == 204 ? 'Success' : 'Error',
                orderId
            );*/
            
        } catch (Exception e) {
            System.debug('Exception in sendSingleBlobField [' + fieldName + ']: ' + e.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                mediaUrl, null, null, 'PATCH',
                'Exception: ' + e.getMessage(),
                null, null, 'Error', orderId
            );
        }
    }
    
}