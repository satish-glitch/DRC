public class DRC_NBC_ConsigneeBank_BC_Queueable implements Queueable, Database.AllowsCallouts {

    private Id accountId;

    public DRC_NBC_ConsigneeBank_BC_Queueable(Id accountId) {
        this.accountId = accountId;
    }

    public void execute(QueueableContext context) {
        try {
            Account acc     = DRC_NBC_ConsigneeBank_Callout.getAccountDetails(accountId);
            String endpoint = DRC_NBC_ConsigneeBank_Callout.getEndpoint();

            List<DRC_NBC_Consignee_Bank_Details__c> banks =
                DRC_NBC_ConsigneeBank_Callout.getBankDetails(accountId);

            if (banks == null || banks.isEmpty()) {
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_ConsigneeBank_BC_Queueable',
                    endpoint, null, 'POST',
                    'No primary bank records found for Account: ' + accountId,
                    null, null, 'Warning', accountId
                );
                return;
            }

            Integer successCount = 0;
            Integer errorCount   = 0;

            List<Map<String, Object>> logEntries = new List<Map<String, Object>>();

            // ── All callouts first — no DML inside this loop ──────────────────
            for (DRC_NBC_Consignee_Bank_Details__c bankDetail : banks) {

                DRC_NBC_Integration_Payload.ConsigneeBankPayload payload =
                    DRC_NBC_ConsigneeBank_Callout.mapToPayload(acc, bankDetail);

                String jsonBody = JSON.serialize(payload, true);

                DRC_NBC_ConsigneeBank_BC_Integration integration =
                    new DRC_NBC_ConsigneeBank_BC_Integration(
                        endpoint, 'POST', jsonBody, accountId);

                HttpResponse response = integration.executeAndReturnResponse();

                Boolean isSuccess = response != null && response.getStatusCode() == 201;

                logEntries.add(new Map<String, Object>{
                    'requestBody'  => jsonBody,
                    'responseBody' => response != null ? response.getBody() : 'null',
                    'statusCode'   => response != null ? response.getStatusCode() : null,
                    'status'       => isSuccess ? 'Success' : 'Error'
                });

                if (isSuccess) {
                    successCount++;
                } else {
                    errorCount++;
                }
            }

            // ── All callouts done — now safe for DML (logging) ────────────────
            for (Map<String, Object> entry : logEntries) {
                Integer code = (Integer) entry.get('statusCode');
                String  status = (String) entry.get('status');

                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_ConsigneeBank_BC_Queueable',
                    endpoint,
                    (String) entry.get('requestBody'),
                    'POST',
                    (String) entry.get('responseBody'),
                    code,
                    null,
                    status,
                    accountId
                );
            }



        } catch (Exception e) {
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_ConsigneeBank_BC_Queueable',
                null, null, 'POST',
                e.getMessage(), null,
                e.getStackTraceString(),
                'Error',
                accountId
            );
        }
    }
}