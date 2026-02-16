public class DRC_NBC_OrderProduct_BC_Integration extends DRC_NBC_Base_API_Integration {

    private String apiPath;
    private String httpMethod;
    private String payload;
    private Id orderId;

    public DRC_NBC_OrderProduct_BC_Integration(String apiPath, String httpMethod, String payload, Id orderId) {
        this.apiPath = apiPath;
        this.httpMethod = httpMethod;
        this.payload = payload;
        this.orderId = orderId;
    }

    public override HttpRequest prepareRequest() {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(apiPath);
        request.setMethod(this.httpMethod);
        DRC_NBC_BC_Callout_Utility.prepareRequest(request);
        request.setBody(payload);
        System.debug('BC Order Product Payload >>> ' + DRC_NBC_BC_Callout_Utility.trimPayload(payload));
        return request;
    }

    public override void processResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        String responseBody = response.getBody();
        System.debug('BC Order Product Response >>> ' + responseBody);
        System.debug('Status Code >>> ' + statusCode);

        if (statusCode >= 200 && statusCode < 300) {
         /* DRC_NBC_API_Log_Handler.createApiLogAsync(
                this.apiPath,
                DRC_NBC_BC_Callout_Utility.trimPayload(payload),
                DRC_NBC_BC_Callout_Utility.trimPayload(responseBody),
                this.httpMethod,
                null,
                statusCode,
                null,
                'Success',
                orderId
            );*/
        } else {
           /* DRC_NBC_API_Log_Handler.createApiLogAsync(
                this.apiPath,
                DRC_NBC_BC_Callout_Utility.trimPayload(payload),
                DRC_NBC_BC_Callout_Utility.trimPayload(responseBody),
                this.httpMethod,
                'Non-success status code received.',
                statusCode,
                null,
                'Error',
                orderId
            );*/
        }
    }
}