/**
* @File Name : DRC_NBC_LineItemDeleter.cls
* @Description : Handles Deletion of Line Items in Business Central using SOAP Delete
* @Author : Satish Yadav
* @Last Modified On : April 22, 2026
**/
public class DRC_NBC_LineItemDeleter {

    private static DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();
    private static final String BC_LINE_ITEM_ENDPOINT   = bcSettings.DRC_NBC_BC_Line_Item_Endpoint__c;
    private static final String SOAP_LINE_NAMESPACE     = bcSettings.DRC_NBC_SOAP_Line_Namespace__c;
    private static final String BC_USERNAME             = bcSettings.DRC_NBC_Username__c;
    private static final String BC_PASSWORD             = bcSettings.DRC_NBC_Password__c;

    public static String deleteLineItems(Map<Integer, String> lineKeysToDelete) {
        System.debug('*** DELETE Line Items Started ***');

        if (lineKeysToDelete == null || lineKeysToDelete.isEmpty()) {
            System.debug('No items to delete');
            return 'NO_ITEMS_TO_DELETE';
        }

        Integer successCount       = 0;
        Integer failureCount       = 0;
        List<String> errorMessages = new List<String>();

        // Delete highest line number first to avoid line number shift issues
        List<Integer> sortedLineNos = new List<Integer>(lineKeysToDelete.keySet());
        sortedLineNos.sort();

        for (Integer i = sortedLineNos.size() - 1; i >= 0; i--) {
            Integer lineNo  = sortedLineNos[i];
            String bcKey    = lineKeysToDelete.get(lineNo);
            System.debug('Deleting Line ' + lineNo + ' with Key: ' + bcKey);

            String result = deleteSingleLineItem(bcKey, lineNo);

            if (result.contains('SUCCESS')) {
                successCount++;
                System.debug('Line ' + lineNo + ' deleted successfully');
            } else {
                failureCount++;
                errorMessages.add('Line ' + lineNo + ': ' + result);
                System.debug('Line ' + lineNo + ' deletion failed: ' + result);
            }
        }

        System.debug('Delete Summary - Success: ' + successCount + ', Failures: ' + failureCount);

        if (failureCount == 0) {
            // ✅ No log here — in the middle of process
            // Final SUCCESS log written by intelligentLineItemSync after all steps pass
            return 'LINE_ITEMS_DELETE_SUCCESS: All ' + successCount + ' items deleted';
        } else if (successCount == 0) {
            return 'LINE_ITEMS_DELETE_FAILED: All deletions failed. Errors: ' + String.join(errorMessages, '; ');
        } else {
            return 'LINE_ITEMS_DELETE_PARTIAL: ' + successCount + ' succeeded, ' + failureCount + ' failed. Errors: ' + String.join(errorMessages, '; ');
        }
    }

    private static String deleteSingleLineItem(String bcKey, Integer lineNo) {
        System.debug('  Deleting single line item - Line No: ' + lineNo + ', Key: ' + bcKey);

        try {
            String requestBody = buildDeleteSOAPRequest(bcKey);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_LINE_ITEM_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_LINE_NAMESPACE + ':Delete');
            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(
                Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD)
            ));
            req.setBody(requestBody);
            req.setTimeout(120000);

            HttpResponse response = new Http().send(req); // ← CALLOUT

            System.debug('  Delete Response Status: ' + response.getStatusCode());

            if (response.getStatusCode() == 200) {
                // ✅ No log here — in the middle of process
                // Final SUCCESS log written by intelligentLineItemSync after all steps pass
                System.debug('  Line Item Deleted Successfully');
                return 'DELETE_SUCCESS';

            } else {
                // ✅ ERROR log — safe because deleteLineItems checks the result
                // and intelligentLineItemSync stops after seeing FAILED, no more callouts follow
                System.debug('  Delete failed: ' + response.getStatusCode());
                System.debug('  Delete Response Body: ' + response.getBody());
                DRC_NBC_API_Log_Handler.createApiLog(
                    BC_LINE_ITEM_ENDPOINT,
                    requestBody,
                    response.getBody(),
                    'deleteSingleLineItem_Line' + lineNo,
                    'Delete failed: ' + response.getStatusCode(),
                    response.getStatusCode(),
                    null,
                    'ERROR',
                    bcKey
                );
                return 'FAILURE: Status ' + response.getStatusCode();
            }

        } catch (Exception ex) {
            System.debug('  *** Delete Exception: ' + ex.getMessage());
            // ✅ ERROR log — exception means no more callouts, safe to DML
            DRC_NBC_API_Log_Handler.createApiLog(
                BC_LINE_ITEM_ENDPOINT,
                null,
                null,
                'deleteSingleLineItem_Line' + lineNo,
                ex.getMessage(),
                null,
                ex.getStackTraceString(),
                'ERROR',
                bcKey
            );
            return 'ERROR: ' + ex.getMessage();
        }
    }

    private static String buildDeleteSOAPRequest(String bcKey) {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Delete xmlns="' + SOAP_LINE_NAMESPACE + '">' +
            '<Key>' + escapeXml(bcKey) + '</Key>' +
            '</Delete>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    private static String escapeXml(String value) {
        if (String.isBlank(value)) return '';
        return value.escapeXml();
    }
}