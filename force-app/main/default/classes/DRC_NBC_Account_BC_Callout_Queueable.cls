public class DRC_NBC_Account_BC_Callout_Queueable implements System.Queueable, Database.AllowsCallouts {
    
    private Id orderId;
    
    public DRC_NBC_Account_BC_Callout_Queueable(Id orderId) {
        this.orderId = orderId;
    }
    
    public void execute(System.QueueableContext context) {
        Id accountId;
        
        try {
            Order orderRecord = [
                SELECT Id, AccountId
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
            accountId = orderRecord.AccountId;
            
            if (accountId == null) {
                logError('Order does not have an associated Account', accountId);
                return;
            }
            
            // Check if account number needs to be generated
            Account checkAcc = [
                SELECT Id, DRC_NBC_Customer_Number__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            
            // Generate account number if blank
            if (String.isBlank(checkAcc.DRC_NBC_Customer_Number__c)) {
                DRC_NBC_AccountNumberGenerator_Helper.generateAccountNumbersSync(accountId);
                
                // After DML, we need to chain to another queueable for the callout
                System.enqueueJob(new DRC_NBC_Account_BC_Callout_Second_Queue(orderId, accountId));
                return;
            }
            
            // If account number exists, proceed with callout directly
            executeCallout(orderId, accountId);
            
        } catch (Exception e) {
            logError(e.getMessage(), accountId);
        }
    }
    
    private void executeCallout(Id orderId, Id accountId) {
        try {
            Account acc = DRC_NBC_Account_BC_Callout.getAccountDetails(accountId);
            
          /*  if (acc.DRC_NBC_BC_Approval_Status__c) {
                System.enqueueJob(new DRC_NBC_Order_BC_Callout(orderId));
                return;
            }*/
            
         /*   Boolean hasShippingAddressInIndia = false;
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
            logError(e.getMessage(), accountId);
        }
    }
    
    private void logError(String errorMsg, Id accountId) {
        DRC_NBC_API_Log_Handler.createApiLog(
            'DRC_NBC_Account_BC_Callout_Queueable',
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