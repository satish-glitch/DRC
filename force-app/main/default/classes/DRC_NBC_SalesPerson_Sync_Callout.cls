/**
 * @File Name          : DRC_NBC_SalesPerson_Sync_Callout.cls
 * @Description        : Synchronous Salesperson/Contact creation callout to BC.
 *                       Called directly from DRC_NBC_Order_BC_Callout.
 *                       contactId & accountId passed directly — no re-query on Order.
 *                       API Log created ONLY on Failure/Exception — NOT on Success.
 * @Author             : Satish
 * @Last Modified On   : December 11, 2025
**/
public class DRC_NBC_SalesPerson_Sync_Callout implements Database.AllowsCallouts {

    // ── Main Synchronous Static Method ─────────────────────────────────────────
    // Called from DRC_NBC_Order_BC_Callout with already-fetched Order values
    // ✅ contactId & accountId passed directly — zero extra SOQL on Order
    public static String executeCallout(Id contactId, Id accountId) {
        HttpResponse response;
        String requestPayload = '';
        String responseBody   = '';
        Integer statusCode    = null;

        try {
            // Step 1: Validate inputs
            if (contactId == null) {
                String errMsg = 'contactId cannot be null.';
                System.debug(errMsg);
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_SalesPerson_Sync_Callout',
                    null, null, 'POST',
                    errMsg,
                    null, null,
                    'Error', null
                );
                return 'FAILURE: ' + errMsg;
            }

            if (accountId == null) {
                String errMsg = 'accountId cannot be null.';
                System.debug(errMsg);
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_SalesPerson_Sync_Callout',
                    null, null, 'POST',
                    errMsg,
                    null, null,
                    'Error', null
                );
                return 'FAILURE: ' + errMsg;
            }

            // Step 2: Fetch Contact using passed contactId & accountId
            List<Contact> contacts = [
                SELECT Id, Name, Email, Phone, AccountId
                FROM Contact
                WHERE Id        = :contactId
                AND AccountId   = :accountId
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];

            if (contacts.isEmpty()) {
                // ❌ No Contact found → Log & return failure
                String errMsg = 'No Contact found for ContactId: ' + contactId
                              + ' | AccountId: '                   + accountId;
                System.debug(errMsg);
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_SalesPerson_Sync_Callout',
                    null, null, 'POST',
                    errMsg,
                    null, null,
                    'Error', null
                );
                return 'FAILURE: ' + errMsg;
            }

            Contact con = contacts[0];
            System.debug('Contact fetched → Name: ' + con.Name 
                       + ' | Email: '               + con.Email 
                       + ' | Phone: '               + con.Phone);

            // Step 3: Get API path from config
            String apiPath = DRC_NBC_BC_Callout_Utility.getConfig().DRC_NBC_SalesPerson_Code__c;
            System.debug('Salesperson API Path: ' + apiPath);

            if (String.isBlank(apiPath)) {
                String errMsg = 'API Path is blank in config for DRC_NBC_SalesPerson_Code__c.';
                System.debug(errMsg);
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_SalesPerson_Sync_Callout',
                    null, null, 'POST',
                    errMsg,
                    null, null,
                    'Error', null
                );
                return 'FAILURE: ' + errMsg;
            }

            // Step 4: Build payload
            Map<String, Object> payloadMap = new Map<String, Object>{
                'Name'     => con.Name,
                'Phone_No' => con.Phone,
                'E_Mail'   => con.Email,
                'Code'     => String.valueOf(con.Id)
            };
            requestPayload = JSON.serialize(payloadMap);
            System.debug('Request Payload: ' + requestPayload);

            // Step 5: Execute callout
            DRC_NBC_SalesPerson_BC_Integration integration = new DRC_NBC_SalesPerson_BC_Integration(
                apiPath,
                'POST',
                requestPayload,
                con.AccountId
            );
            response     = integration.executeAndReturnResponse();
            statusCode   = integration.httpStatusCode;
            responseBody = integration.responseSummary;

            System.debug('POST Status Code → ' + statusCode);
            System.debug('POST Response    → ' + responseBody);

            // Step 6: Handle Response
            if (statusCode != null && statusCode >= 200 && statusCode < 300) {
                // ✅ SUCCESS — No API Log on success
                System.debug('Salesperson created in BC successfully.');
                return 'SUCCESS';

            } else {
                // ❌ FAILURE — Log the error
                String errMsg = 'POST failed. Status: ' + statusCode
                              + ' | Response: '         + responseBody;
                System.debug(errMsg);
             /*   DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_SalesPerson_Sync_Callout',
                    null,
                    String.valueOf(accountId),
                    'POST',
                    errMsg,
                    requestPayload,
                    null,
                    'Error',
                    null
                );*/
                return 'FAILURE: ' + errMsg;
            }

        } catch (Exception ex) {
            // ❌ EXCEPTION — Log with full stack trace
            String errMsg = 'Exception: ' + ex.getMessage();
            System.debug(errMsg);
            System.debug('Stack Trace: ' + ex.getStackTraceString());
           /* DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_SalesPerson_Sync_Callout',
                null,
                String.valueOf(accountId),
                'POST',
                errMsg,
                requestPayload,
                ex.getStackTraceString(),
                'Exception',
                null
            );*/
            return 'FAILURE: ' + ex.getMessage();
        }
    }
}