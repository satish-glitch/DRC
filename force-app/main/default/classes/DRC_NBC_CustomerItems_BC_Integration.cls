public class DRC_NBC_CustomerItems_BC_Integration {
    private String endpoint;
    private String method;
    private String body;
    private Id accountId;

    public DRC_NBC_CustomerItems_BC_Integration(
            String endpoint,
            String method,
            String body,
            Id accountId) {
        this.endpoint  = endpoint;
        this.method    = method;
        this.body      = body;
        this.accountId = accountId;
    }

    public HttpResponse executeAndReturnResponse() {
        HttpRequest req = new HttpRequest();
        String fullEndpoint = DRC_NBC_BC_Callout_Utility.getFullEndpoint(endpoint);
        req.setEndpoint(fullEndpoint);
        req.setMethod(method);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        req.setTimeout(120000);

        Http http = new Http();
        HttpResponse res = http.send(req);

        return res;
    }
}