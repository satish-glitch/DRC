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
}