public class DRC_NBC_Shipping_BC_Integration extends DRC_NBC_Base_API_Integration {

    private String apiPath;
    private String httpMethod;
    private String payload;
    private Id accountId;

    public DRC_NBC_Shipping_BC_Integration(String apiPath, String httpMethod, String payload, Id accountId) {
        this.apiPath = apiPath;
        this.httpMethod = httpMethod;
        this.payload = payload;
        this.accountId = accountId;
    }

    public override HttpRequest prepareRequest() {
        HttpRequest req = new HttpRequest();
        String fullEndpoint = DRC_NBC_BC_Callout_Utility.getFullEndpoint(apiPath);
        System.debug('Shipping Endpoint URL → ' + fullEndpoint);

        req.setEndpoint(fullEndpoint);
        req.setMethod(this.httpMethod);
        DRC_NBC_BC_Callout_Utility.prepareRequest(req);
        req.setBody(payload);

        System.debug('Shipping Payload >>> ' + DRC_NBC_BC_Callout_Utility.trimPayload(payload));
        return req;
    }

    public override void processResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        String responseBody = response.getBody();

        System.debug('📨 Shipping Response: ' + responseBody);
        System.debug('Status Code: ' + statusCode);

        if (statusCode >= 200 && statusCode < 300) {
           DRC_NBC_API_Log_Handler.createApiLogAsync(
                this.apiPath,
                DRC_NBC_BC_Callout_Utility.trimPayload(payload),
                DRC_NBC_BC_Callout_Utility.trimPayload(responseBody),
                this.httpMethod,
                null,
                statusCode,
                null,
                'Success',
                accountId
            );
        } else {
            DRC_NBC_API_Log_Handler.createApiLogAsync(
                this.apiPath,
                DRC_NBC_BC_Callout_Utility.trimPayload(payload),
                DRC_NBC_BC_Callout_Utility.trimPayload(responseBody),
                this.httpMethod,
                'Non-success response',
                statusCode,
                null,
                'Error',
                accountId
            );
        }
    }
}