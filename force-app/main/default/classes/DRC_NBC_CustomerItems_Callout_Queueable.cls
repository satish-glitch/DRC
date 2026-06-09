public class DRC_NBC_CustomerItems_Callout_Queueable
implements System.Queueable, Database.AllowsCallouts {
    
    Public Id orderId;
    Public Id accountId;
    
    public DRC_NBC_CustomerItems_Callout_Queueable(Id orderId, Id accountId) {
        this.orderId   = orderId;
        this.accountId = accountId;
    }
    
    public void execute(System.QueueableContext context) {
        try {
            Account acc = [
                SELECT Id, DRC_NBC_Customer_Number__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            
            String customerNumber = acc.DRC_NBC_Customer_Number__c;
            
            List<DRC_NBC_Restricted_Product__c> products =
                DRC_NBC_CustomerItems_BC_Callout.getRestrictedProducts(accountId);
            
            if (products == null || products.isEmpty()) {
                System.enqueueJob(new DRC_NBC_ConsigneeBank_Callout_Queueable(orderId, accountId));
                return;
            }
            
            String endpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_Customer_Items_Endpoint__c;
            System.debug('CustomerItem Endpoint >>>> ' + endpoint);
            
            // ✅ Collect log data during callout loop — NO DML inside loop
            List<Map<String, Object>> logEntries = new List<Map<String, Object>>();
            
            for (DRC_NBC_Restricted_Product__c rp : products) {
                DRC_NBC_Integration_Payload.CustomerItemPayload payload =
                    DRC_NBC_CustomerItems_BC_Callout.mapToPayload(rp, customerNumber);
                
                String jsonBody = JSON.serialize(payload, true);
                
                DRC_NBC_CustomerItems_BC_Integration integration =
                    new DRC_NBC_CustomerItems_BC_Integration(
                        endpoint, 'POST', jsonBody, accountId);
                
                // ✅ Pure callout — no DML inside
                HttpResponse response = integration.executeAndReturnResponse();
                
                // ✅ Collect log info — no DML yet
                Map<String, Object> logEntry = new Map<String, Object>{
                    'requestBody'  => jsonBody,
                        'responseBody' => response != null ? response.getBody() : 'null',
                            'statusCode'   => response != null ? String.valueOf(response.getStatusCode()) : 'null',
                                'status'       => (response != null && response.getStatusCode() == 201) ? 'Success' : 'Error',
                                    'itemNo'       => rp.DRC_NBC_Product__r.DRC_NBC_FG_Code__c
                                    };
                                        logEntries.add(logEntry);
            }
            
            for (Map<String, Object> entry : logEntries) {
                String status = (String) entry.get('status');
                String itemNo = (String) entry.get('itemNo');
                
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_CustomerItems_BC_Integration',
                    endpoint,
                    (String) entry.get('requestBody'),
                    'POST',
                    (String) entry.get('responseBody'),
                    entry.get('statusCode') != null 
                    ? Integer.valueOf(String.valueOf(entry.get('statusCode'))) 
                    : null,                 
                    null,
                    status,
                    accountId
                );
                
                if (status == 'Error') {
                    logError(
                        'CustomerItem POST failed. Status: ' + entry.get('statusCode') +
                        ' | Item: ' + (String) entry.get('itemNo'),
                        accountId
                    );
                }
            }
            
          System.enqueueJob(new DRC_NBC_ConsigneeBank_Callout_Queueable(orderId, accountId));
            
        } catch (Exception e) {
            // logError(e.getMessage(), accountId);
            if (!Test.isRunningTest())  {
                System.enqueueJob(new DRC_NBC_ConsigneeBank_Callout_Queueable(orderId, accountId));
            }
            
        }
    }
    
    private void logError(String errorMsg, Id accountId) {
        DRC_NBC_API_Log_Handler.createApiLog(
            'DRC_NBC_CustomerItems_BC_Callout_Queueable',
            null,
            null,
            'QueueableJob',
            errorMsg,
            null,
            null,
            'Error',
            accountId
        );
    }
}