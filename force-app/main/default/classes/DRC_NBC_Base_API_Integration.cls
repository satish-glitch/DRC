public abstract class DRC_NBC_Base_API_Integration {
    public HttpRequest request;

    public HttpRequest createHttpRequest() {
        request = new HttpRequest();
        setCommonHeaders(request);
        return request;
    }

    protected void setCommonHeaders(HttpRequest request) {
        request.setHeader('Content-Type', 'application/json');
    }

    public abstract HttpRequest prepareRequest();
    public abstract void processResponse(HttpResponse response);

    // Original void method retained
    public void execute() {
        executeAndReturnResponse();
    }

    // New method that returns the response
    public HttpResponse executeAndReturnResponse() {
        HttpRequest request = prepareRequest();
        Http http = new Http();
        HttpResponse response;

        try {
            response = http.send(request);
            processResponse(response);
            return response;
        } catch (Exception ex) {
            System.debug('Error: ' + ex.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                request.getEndpoint(),
                request.getBody(),
                response != null ? response.getBody() : null,
                request.getMethod(),
                ex.getMessage(),
                response != null ? response.getStatusCode() : 0,
                ex.getStackTraceString(),
                'Error',
                null
            );
            throw ex; // Important: propagate error
        }
    }
}