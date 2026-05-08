/**
 * @File Name : DRC_NBC_SalesPersonCode_Callout.cls
 * @Description : Queueable class that makes a POST callout to BC for Salesperson Code using reusable integration logic
 * @Author : Satish
 * @Last Modified On : May 08, 2026
**/
public class DRC_NBC_SalesPersonCode_Callout implements Queueable, Database.AllowsCallouts {
    private Id orderId;

    // Constructor to accept Order Id
    public DRC_NBC_SalesPersonCode_Callout(Id orderId) {
        this.orderId = orderId;
    }

    public void execute(QueueableContext context) {
        String result = executeCallout(orderId);
        System.debug('Salesperson POST Result → ' + result);
    }

    public static String executeCallout(Id orderId) {
        HttpResponse response;
        try {
            // Step 1: Fetch Order and AccountId
            Order ord = [
                SELECT Id, AccountId
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
            if (ord.AccountId == null) {
                throw new AuraHandledException('Order does not have an associated Account.');
            }

            // Step 2: Fetch SalesPerson_Code__c from Account
            Account acc = [
                SELECT Id, SalesPerson_Code__c
                FROM Account
                WHERE Id = :ord.AccountId
                LIMIT 1
            ];
            if (String.isBlank(acc.SalesPerson_Code__c)) {
                throw new AuraHandledException('Account does not have a Salesperson Code assigned.');
            }

            // Step 3: Query Custom Metadata where MasterLabel matches Account's SalesPerson_Code__c
            List<SalesPerson_Code__mdt> mdtRecords = [
                SELECT MasterLabel, Name__c, Phone__c, Email__c
                FROM SalesPerson_Code__mdt
                WHERE MasterLabel = :acc.SalesPerson_Code__c
                LIMIT 1
            ];
            if (mdtRecords.isEmpty()) {
                throw new AuraHandledException(
                    'No Salesperson Code metadata record found matching: ' + acc.SalesPerson_Code__c
                );
            }
            SalesPerson_Code__mdt spMdt = mdtRecords[0];

            // Step 4: Get API path from config
            String apiPath = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_SalesPerson_Code__c;
            System.debug('Salesperson API Path: ' + apiPath);

            // Step 5: Build payload using Custom Metadata fields
            Map<String, Object> payloadMap = new Map<String, Object>{
                'Name'     => spMdt.Name__c,
                'Phone_No' => spMdt.Phone__c,
                'E_Mail'   => spMdt.Email__c,
                'Code'     => spMdt.MasterLabel   // Salesperson Code value
            };
            String payload = JSON.serialize(payloadMap);
            System.debug('Salesperson Payload: ' + payload);

            // Step 6: Execute the callout
            DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
                apiPath,
                'POST',
                payload,
                ord.AccountId
            );
            response = integration.executeAndReturnResponse();

            if (integration.httpStatusCode != null
                && integration.httpStatusCode >= 200
                && integration.httpStatusCode < 300) {
                System.debug('Salesperson POST Success → ' + integration.responseSummary);
                return 'SUCCESS';
            } else {
                System.debug('Salesperson POST Failed → ' + integration.responseSummary);
                return 'FAILURE: ' + integration.responseSummary;
            }

        } catch (Exception ex) {
            System.debug('Exception during Salesperson POST callout: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_SalesPersonCode_Callout',
                orderId,
                null,
                'POST',
                ex.getMessage(),
                null,
                ex.getStackTraceString(),
                'Exception',
                null
            );
            return 'FAILURE: ' + ex.getMessage();
        }
    }
}