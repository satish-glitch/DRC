/**
* @File Name : DRC_NBC_BC_Generate_Token.cls
* @Description : Triggers token generation via Named Credential (if needed by BC)
* @Author : Satish
* @Last Modified On : November 12, 2025
**/

public class DRC_NBC_BC_Generate_Token extends DRC_NBC_Base_API_Integration {
    
    private String apiPath;
    private String httpMethod;
    
    public DRC_NBC_BC_Generate_Token(String apiPath, String httpMethod) {
        this.apiPath = apiPath;
        this.httpMethod = httpMethod;
    }
    
    public override HttpRequest prepareRequest() {
        HttpRequest request = new HttpRequest();
        String fullEndpoint = DRC_NBC_BC_Callout_Utility.getFullEndpoint(apiPath);
        
        request.setEndpoint(fullEndpoint);
        request.setMethod(this.httpMethod);
        DRC_NBC_BC_Callout_Utility.prepareRequest(request);
        return request;
    }
    
    public override void processResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        String responseBody = response.getBody();
        
        if (statusCode == 200 || statusCode == 201) {
            System.debug('Named Credential token generation successful. Response: ' + responseBody);
            
            DRC_NBC_API_Log_Handler.createApiLog(
                this.apiPath,
                null,
                responseBody,
                this.httpMethod,
                null,
                statusCode,
                null,
                'Success',
                null
            );
        } else {
            System.debug('Named Credential token generation failed. Status: ' + statusCode);
            DRC_NBC_API_Log_Handler.createApiLog(
                this.apiPath,
                null,
                responseBody,
                this.httpMethod,
                'Token request failed.',
                statusCode,
                null,
                'Error',
                null
            );
        }
    }
}