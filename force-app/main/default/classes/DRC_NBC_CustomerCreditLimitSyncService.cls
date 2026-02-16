@RestResource(urlMapping = '/CustomerCreditLimitSync/*')
global with sharing class DRC_NBC_CustomerCreditLimitSyncService {
    
    @HttpPost
    global static void syncCreditLimit() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        Savepoint sp;
        String requestBody = '';
        
        try {
            sp = Database.setSavepoint();
            requestBody = req.requestBody.toString();
            // Step 1: Parse and validate payload
            DRC_NBC_Integration_Payload.CustomerCreditLimitPayload payload =
                (DRC_NBC_Integration_Payload.CustomerCreditLimitPayload)
                JSON.deserialize(requestBody, DRC_NBC_Integration_Payload.CustomerCreditLimitPayload.class);
            
            if (String.isBlank(payload.CustomerNumber)) {
                throw new CalloutException('CustomerNumber is required.');
            }
            List<Account> customerList = [
                SELECT 
                Id, Name, DRC_NBC_Customer_Number__c,
                CurrencyIsoCode, DRC_NBC_Credit_Limit__c, 
                DRC_NBC_BC_Approval_Status__c
                FROM 
                Account
                WHERE 
                DRC_NBC_Customer_Number__c = :payload.CustomerNumber
                LIMIT 1
            ];
            
            if (customerList.isEmpty()) {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf('Customer not found in Salesforce for CustomerNumber: ' + payload.CustomerNumber);
                
                DRC_NBC_API_Log_Handler.createApiLog(
                    '/CustomerCreditLimitSync',
                    requestBody,
                    null,
                    'POST',
                    'Customer not found in Salesforce',
                    404,
                    null,
                    'Error',
                    null
                );
                return;
            }
            
            Account customerAcc = customerList[0];          
            customerAcc.DRC_NBC_Credit_Limit__c = payload.CreditLimit;
            customerAcc.CurrencyIsoCode = payload.CurrencyCode;
            if(payload.Status != null && payload.Status == 'Approved'){
                customerAcc.DRC_NBC_BC_Approval_Status__c = true;               
            }
            update customerAcc;
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Credit limit updated successfully.');
            List<Order> relatedOrders = [
                SELECT Id, DRC_NBC_Account_Approval_Status__c
                FROM Order
                WHERE AccountId = :customerAcc.Id
            ];
            
            for (Order ord : relatedOrders) {
                ord.DRC_NBC_Account_Approval_Status__c = '';
            }
            
            if (!relatedOrders.isEmpty()) {
                update relatedOrders;
            }
            
            DRC_NBC_API_Log_Handler.createApiLog(
                '/CustomerCreditLimitSync',
                requestBody,
                'Credit limit updated successfully.',
                'POST',
                null,
                200,
                null,
                'Success',
                customerAcc.Id
            );
            
        } catch (Exception ex) {
            Database.rollback(sp);
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + ex.getMessage());
            
            DRC_NBC_API_Log_Handler.createApiLog(
                '/CustomerCreditLimitSync',
                requestBody,
                null,
                'POST',
                ex.getMessage(),
                500,
                ex.getStackTraceString(),
                'Error',
                null
            );
        }
    }
}