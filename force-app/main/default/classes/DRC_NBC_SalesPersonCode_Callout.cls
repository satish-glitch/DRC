public class DRC_NBC_SalesPersonCode_Callout implements Queueable, Database.AllowsCallouts {

    private Id orderId;

    public DRC_NBC_SalesPersonCode_Callout(Id orderId) {
        this.orderId = orderId;
    }

    public void execute(QueueableContext context) {
        try {
            // Step 1: Fetch Order and AccountId
            Order ord = [
                SELECT Id, AccountId
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];

            if (ord.AccountId == null) {
                System.debug('No Account on Order. Skipping SalesPersonCode.');
                // Chain to Account sync only in production
                if (!Test.isRunningTest()) {
                    System.enqueueJob(new DRC_NBC_Account_BC_Callout_Queueable(orderId));
                }
                return;
            }

            // Step 2: Fetch SalesPerson_Code__c from Account
            Account acc = [
                SELECT Id, SalesPerson_Code__c
                FROM Account
                WHERE Id = :ord.AccountId
                LIMIT 1
            ];

            if (String.isBlank(acc.SalesPerson_Code__c)) {
                System.debug('No SalesPerson Code on Account. Skipping callout.');
                // Chain to Account sync only in production
                if (!Test.isRunningTest()) {
                    System.enqueueJob(new DRC_NBC_Account_BC_Callout_Queueable(orderId));
                }
                return;
            }

            // Step 3: Fetch metadata matching SalesPerson_Code__c
            List<SalesPerson_Code__mdt> mdtRecords = [
                SELECT MasterLabel, Name__c, Phone__c, Email__c
                FROM SalesPerson_Code__mdt
                WHERE Name__c = :acc.SalesPerson_Code__c
                LIMIT 1
            ];

            if (mdtRecords.isEmpty()) {
                System.debug('No metadata found for SalesPerson: ' + acc.SalesPerson_Code__c);
                // Chain to Account sync only in production
                if (!Test.isRunningTest()) {
                    System.enqueueJob(new DRC_NBC_Account_BC_Callout_Queueable(orderId));
                }
                return;
            }

            SalesPerson_Code__mdt spMdt = mdtRecords[0];

            // Step 4: Build payload
            String apiPath = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_SalesPerson_Code__c;

            Map<String, Object> payloadMap = new Map<String, Object>{
                'Code'     => spMdt.MasterLabel,
                'Name'     => spMdt.Name__c,
                'Phone_No' => spMdt.Phone__c,
                'E_Mail'   => spMdt.Email__c
            };
            String payload = JSON.serialize(payloadMap);
            System.debug('SalesPersonCode Payload: ' + payload);

            // Step 5: Pure callout — no DML before this
            DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
                apiPath,
                'POST',
                payload,
                ord.AccountId
            );
            HttpResponse response = integration.executeAndReturnResponse();

            // Step 6: Log after callout — DML safe now
            if (integration.httpStatusCode != null
                    && integration.httpStatusCode >= 200
                    && integration.httpStatusCode < 300) {
                System.debug('SalesPersonCode → SUCCESS');
            } else {
                System.debug('SalesPersonCode → FAILED. Status: ' +
                    String.valueOf(integration.httpStatusCode));
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_SalesPersonCode_Callout',
                    apiPath,
                    payload,
                    'POST',
                    response != null ? response.getBody() : 'null',
                    integration.httpStatusCode,
                    null,
                    'Error',
                    ord.AccountId
                );
            }

        } catch (Exception e) {
            System.debug('SalesPersonCode Exception: ' + e.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_SalesPersonCode_Callout',
                null,
                null,
                'POST',
                e.getMessage(),
                null,
                e.getStackTraceString(),
                'Error',
                null
            );
        }

        // Always chain to Account sync in production — pass or fail
        if (!Test.isRunningTest()) {
            System.enqueueJob(new DRC_NBC_Account_BC_Callout_Queueable(orderId));
        }
    }
}