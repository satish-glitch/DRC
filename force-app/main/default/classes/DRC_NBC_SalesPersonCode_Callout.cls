/**
 * @File Name : DRC_NBC_SalesPersonCode_Callout.cls
 * @Description : Queueable class that makes a POST callout to BC for Salesperson Code using reusable integration logic
 * @Author : Satish
 * @Last Modified On : December 11, 2025
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
                SELECT Id, AccountId, ShipToContactId
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];

            if (ord.AccountId == null) {
                throw new AuraHandledException('Order does not have an associated Account.');
            }

            // Step 2: Fetch first Contact related to Account
            List<Contact> contacts = [
                SELECT Id, Name, Email, Phone
                FROM Contact
                WHERE AccountId = :ord.AccountId
                AND Id = :ord.ShipToContactId
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];

            if (contacts.isEmpty()) {
                throw new AuraHandledException('No Contact found for the Account related to this Order.');
            }

            Contact con = contacts[0];

            // Step 3: Get API path from config
            String apiPath = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_SalesPerson_Code__c;
            System.debug('Salesperson API Path: ' + apiPath);

            // Step 4: Build payload
            Map<String, Object> payloadMap = new Map<String, Object>{
                'Name' => con.Name,
                'Phone_No' => con.Phone,
                'E_Mail' => con.Email,
                'Code' => con.Id // Or use external code if needed
            };

            String payload = JSON.serialize(payloadMap);

            // Step 5: Execute the callout
            DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
                apiPath,
                'POST',
                payload,
                con.Id
            );

            response = integration.executeAndReturnResponse();

            if (integration.httpStatusCode != null && integration.httpStatusCode >= 200 && integration.httpStatusCode < 300) {
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