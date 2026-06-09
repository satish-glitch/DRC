public class DRC_NBC_ConsigneeBank_Callout_Queueable
implements System.Queueable, Database.AllowsCallouts {
    
    private Id orderId;
    private Id accountId;
    
    public DRC_NBC_ConsigneeBank_Callout_Queueable(Id orderId, Id accountId) {
        this.orderId   = orderId;
        this.accountId = accountId;
    }
    
    public void execute(System.QueueableContext context) {
        try {
            List<DRC_NBC_Consignee_Bank_Details__c> bankDetails =
                DRC_NBC_ConsigneeBank_Callout.getBankDetails(accountId);
            
            if (bankDetails == null || bankDetails.isEmpty()) {
                System.debug('No Consignee Bank records found for Account: '
                             + accountId + '. Skipping.');
                // ✅ No banks — go straight to next step
                System.enqueueJob(
                    new DRC_NBC_CustomerRefrenceItem_Queueable(orderId, accountId)
                );
                return;
            }
            
            Account acc = DRC_NBC_ConsigneeBank_Callout.getAccountDetails(accountId);
            String endpoint = DRC_NBC_ConsigneeBank_Callout.getEndpoint();
            System.debug('ConsigneeBank Endpoint >>>> ' + endpoint);
            
            List<Map<String, Object>> logEntries = new List<Map<String, Object>>();
            
            for (DRC_NBC_Consignee_Bank_Details__c bankDetail : bankDetails) {
                
                DRC_NBC_Integration_Payload.ConsigneeBankPayload payload =
                    DRC_NBC_ConsigneeBank_Callout.mapToPayload(acc, bankDetail);
                
                String jsonBody = JSON.serialize(payload, true);
                System.debug('ConsigneeBank Payload >>>> ' + jsonBody);
                
                DRC_NBC_ConsigneeBank_BC_Integration integration =
                    new DRC_NBC_ConsigneeBank_BC_Integration(
                        endpoint, 'POST', jsonBody, accountId);
                
                HttpResponse response = integration.executeAndReturnResponse();
                
                logEntries.add(new Map<String, Object>{
                    'requestBody'  => jsonBody,
                    'responseBody' => response != null ? response.getBody() : 'null',
                    'statusCode'   => response != null ? response.getStatusCode() : null,
                    'status'       => (response != null && response.getStatusCode() == 201)
                                      ? 'Success' : 'Error',
                    'bankName'     => bankDetail.DRC_NBC_Consignee_Bank_Name__c
                });
            }
            
            // ✅ ALL callouts done — now safe for DML logging
            for (Map<String, Object> entry : logEntries) {
                String status   = (String) entry.get('status');
                String bankName = (String) entry.get('bankName');
                
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_ConsigneeBank_BC_Integration',
                    endpoint,
                    (String) entry.get('requestBody'),
                    'POST',
                    (String) entry.get('responseBody'),
                    (Integer) entry.get('statusCode'),
                    null,
                    status,
                    accountId
                );
                
                if (status == 'Error') {
                    System.debug('ConsigneeBank Sync FAILED for Bank: ' + bankName
                                 + ' | Status: ' + entry.get('statusCode'));
                } else {
                    System.debug('ConsigneeBank Sync SUCCESS for Bank: ' + bankName);
                }
            }
            
            // ✅ All bank callouts done — enqueue CustomerReferenceItem next
            System.enqueueJob(
                new DRC_NBC_CustomerRefrenceItem_Queueable(orderId, accountId)
            );
            
        } catch (Exception e) {
            System.debug('ConsigneeBank Exception: ' + e.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_ConsigneeBank_Callout_Queueable',
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