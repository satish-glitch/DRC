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
                
                // After DML, chain to second queue for the callout
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
            
            DRC_NBC_Integration_Payload.CustomerPayload payload = 
                DRC_NBC_Account_BC_Callout.mapAccountToPayload(acc);
            String jsonBody = JSON.serialize(payload, true);
            String endpoint = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_Endpoint__c;
            
            DRC_NBC_Account_BC_Integration integration = 
                new DRC_NBC_Account_BC_Integration(endpoint, 'POST', jsonBody, accountId);
            HttpResponse response = integration.executeAndReturnResponse();
            
            if (response != null && response.getStatusCode() == 201) {
                
                // ✅ Null-safe downstream checks
                List<DRC_NBC_Restricted_Product__c> restrictedProducts = 
                    DRC_NBC_CustomerItems_BC_Callout.getRestrictedProducts(accountId);
                
                List<DRC_NBC_Consignee_Bank_Details__c> bankDetails = 
                    DRC_NBC_ConsigneeBank_Callout.getBankDetails(accountId);
                
                Boolean hasRestrictedProducts = (restrictedProducts != null && !restrictedProducts.isEmpty());
                Boolean hasBankDetails        = (bankDetails != null && !bankDetails.isEmpty());
                
                if (!hasRestrictedProducts && !hasBankDetails) {
                    // CASE 1: Nothing downstream → mark posted and stop
                    DRC_NBC_Account_BC_Callout.updatePostedStatus(accountId);
                    
                } else if (hasRestrictedProducts) {
                    // CASE 2: Has products (with or without banks)
                    // CustomerItems will automatically chain to ConsigneeBank
                    // ConsigneeBank will call updatePostedStatus at the end
                    System.enqueueJob(new DRC_NBC_CustomerItems_Callout_Queueable(orderId, accountId));
                    
                } else {
                    // CASE 3: No products but has banks → go directly to ConsigneeBank
                    // ConsigneeBank will call updatePostedStatus at the end
                    System.enqueueJob(new DRC_NBC_ConsigneeBank_Callout_Queueable(orderId, accountId));
                }
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