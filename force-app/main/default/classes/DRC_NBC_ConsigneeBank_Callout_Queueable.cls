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
            // Fetch ALL bank records for this Account
            List<DRC_NBC_Consignee_Bank_Details__c> bankDetails =
                DRC_NBC_ConsigneeBank_Callout.getBankDetails(accountId);
            
            // Skip if no bank records found
            if (bankDetails == null || bankDetails.isEmpty()) {
                System.debug('No Consignee Bank records found for Account: '
                             + accountId + '. Skipping.');
                DRC_NBC_Account_BC_Callout.updatePostedStatus(accountId);
                return;
            }
            
            // Fetch Account for Customer Number
            Account acc = DRC_NBC_ConsigneeBank_Callout.getAccountDetails(accountId);
            
            String endpoint = DRC_NBC_ConsigneeBank_Callout.getEndpoint();
            System.debug('ConsigneeBank Endpoint >>>> ' + endpoint);
            
            // ✅ Collect log data during loop — NO DML inside loop
            List<Map<String, Object>> logEntries = new List<Map<String, Object>>();
            
            // ✅ Loop through each bank record and POST separately
            for (DRC_NBC_Consignee_Bank_Details__c bankDetail : bankDetails) {
                
                DRC_NBC_Integration_Payload.ConsigneeBankPayload payload =
                    DRC_NBC_ConsigneeBank_Callout.mapToPayload(acc, bankDetail);
                
                String jsonBody = JSON.serialize(payload, true);
                System.debug('ConsigneeBank Payload >>>> ' + jsonBody);
                
                // ✅ Pure callout — no DML inside loop
                DRC_NBC_ConsigneeBank_BC_Integration integration =
                    new DRC_NBC_ConsigneeBank_BC_Integration(
                        endpoint, 'POST', jsonBody, accountId);
                
                HttpResponse response = integration.executeAndReturnResponse();
                
                // ✅ Collect log info — no DML yet
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
                    DRC_NBC_Account_BC_Callout.updatePostedStatus(accountId);
                    
                }
            }
            
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
    // DRC_NBC_Account_BC_Callout.updatePostedStatus(accountId);
    
}