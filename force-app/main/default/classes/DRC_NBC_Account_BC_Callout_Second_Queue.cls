public class DRC_NBC_Account_BC_Callout_Second_Queue implements System.Queueable, Database.AllowsCallouts {
    
    private Id orderId;
    private Id accountId;
    
    public DRC_NBC_Account_BC_Callout_Second_Queue(Id orderId, Id accountId) {
        this.orderId = orderId;
        this.accountId = accountId;
    }
    
    public void execute(System.QueueableContext context) {
        try {
            Account acc = DRC_NBC_Account_BC_Callout.getAccountDetails(accountId);
            
           /* if (acc.DRC_NBC_BC_Approval_Status__c) {
                System.enqueueJob(new DRC_NBC_Order_BC_Callout(orderId));
                return;
            }*/
            
          /*  Boolean hasShippingAddressInIndia = false;
            for (DRC_NBC_Addresses__c addr : acc.Address__r) {
                if (addr.DRC_NBC_Type__c == 'Shipping' &&
                    addr.DRC_NBC_Address__CountryCode__s == 'IND') {
                    hasShippingAddressInIndia = true;
                    break;
                }
            }*/
            
            DRC_NBC_Integration_Payload.CustomerPayload payload = DRC_NBC_Account_BC_Callout.mapAccountToPayload(acc);
            String jsonBody = JSON.serialize(payload, true);
            String endpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_Endpoint__c;
            
            DRC_NBC_Account_BC_Integration integration = new DRC_NBC_Account_BC_Integration(endpoint, 'POST', jsonBody, accountId);
            HttpResponse response = integration.executeAndReturnResponse();
            
            if (response != null && response.getStatusCode() == 201) {
                System.enqueueJob(new DRC_NBC_SalesPersonCode_Callout(orderId));
              /*  if (hasShippingAddressInIndia) {
                    System.enqueueJob(new DRC_NBC_Shipping_BC_Callout(accountId, orderId));
                }*/
                DRC_NBC_Account_BC_Callout.updatePostedStatus(accountId);
            }
            
        } catch (Exception e) {
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Account_BC_Callout_Second_Queue',
                null,
                null,
                'QueueableJob',
                e.getMessage(),
                null,
                e.getStackTraceString(),
                'Error',
                accountId
            );
        }
    }
}