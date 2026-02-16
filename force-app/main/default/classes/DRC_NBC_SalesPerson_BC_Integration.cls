/**
* @File Name : DRC_NBC_SalesPerson_BC_Integration.cls
* @Description : Handles actual BC Salesperson Code callout logic (called by the queueable class)
* @Author : Satish
* @Last Modified On : December 10, 2025
**/

public class DRC_NBC_SalesPerson_BC_Integration extends DRC_NBC_Base_API_Integration {

    private String apiPath;
    private String httpMethod;
    private String payload;
    private Id recordId; // Optional: can be used for associating the callout log with a record
    public String responseSummary;
    public Integer httpStatusCode;

    public DRC_NBC_SalesPerson_BC_Integration(String apiPath, String httpMethod, String payload, Id recordId) {
        this.apiPath = apiPath;
        this.httpMethod = httpMethod;
        this.payload = payload;
        this.recordId = recordId;
    }

    public override HttpRequest prepareRequest() {
        HttpRequest request = new HttpRequest();
        String fullEndpoint = DRC_NBC_BC_Callout_Utility.getFullEndpoint(apiPath);
        request.setEndpoint(fullEndpoint);
        request.setMethod(this.httpMethod);
        request.setHeader('Content-Type', 'application/json');
        request.setBody(this.payload);

        DRC_NBC_BC_Callout_Utility.prepareRequest(request);

        System.debug('BC Salesperson Payload >>> ' + DRC_NBC_BC_Callout_Utility.trimPayload(payload));
        return request;
    }

    public override void processResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        String responseBody = response.getBody();
        this.httpStatusCode = statusCode;
        this.responseSummary = responseBody;

        System.debug('BC Salesperson Callout Response >>> ' + responseBody);
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
                this.recordId
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
                this.recordId
            );

            System.debug('BC Salesperson POST failed with status: ' + statusCode);
        }
    }
}