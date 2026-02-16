/**
* @File Name : DRC_NBC_LineItemDeleter.cls
* @Description : Handles Deletion of Line Items in Business Central using SOAP Delete
* @Author : Satish Yadav
* @Last Modified On : February 05, 2026
**/
public class DRC_NBC_LineItemDeleter {
    
    // Custom Setting Instance
    private static DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();
    
    // BC Endpoints from Custom Setting
    private static final String BC_LINE_ITEM_ENDPOINT = bcSettings.DRC_NBC_BC_Line_Item_Endpoint__c;
    private static final String SOAP_LINE_NAMESPACE = bcSettings.DRC_NBC_SOAP_Line_Namespace__c;
    
    // Authentication credentials from Custom Setting
    private static final String BC_USERNAME = bcSettings.DRC_NBC_Username__c;
    private static final String BC_PASSWORD = bcSettings.DRC_NBC_Password__c;
    
    /**
     * Delete multiple line items from Business Central
     * Called only for unmatched PRODUCT lines - tax lines are never deleted
     * @param lineKeysToDelete - Map of Line_No to BC Keys (only product lines)
     * @return Result message
     */
    public static String deleteLineItems(Map<Integer, String> lineKeysToDelete) {
        System.debug('*** DELETE Line Items Started ***');
        System.debug('Number of items to delete: ' + (lineKeysToDelete != null ? lineKeysToDelete.size() : 0));
        
        if (lineKeysToDelete == null || lineKeysToDelete.isEmpty()) {
            System.debug('No items to delete');
            return 'NO_ITEMS_TO_DELETE';
        }
        
        Integer successCount = 0;
        Integer failureCount = 0;
        List<String> errorMessages = new List<String>();
        
        // Get sorted list of line numbers to delete in reverse order (highest first)
        // This prevents issues with line number shifts during deletion
        List<Integer> sortedLineNos = new List<Integer>(lineKeysToDelete.keySet());
        sortedLineNos.sort();
        
        // Delete in reverse order (from highest to lowest line number)
        for (Integer i = sortedLineNos.size() - 1; i >= 0; i--) {
            Integer lineNo = sortedLineNos[i];
            String bcKey = lineKeysToDelete.get(lineNo);
            System.debug('Deleting Line ' + lineNo + ' with Key: ' + bcKey);
            
            String result = deleteSingleLineItem(bcKey, lineNo);
            
            if (result.contains('SUCCESS')) {
                successCount++;
                System.debug('✓ Line ' + lineNo + ' deleted successfully');
            } else {
                failureCount++;
                errorMessages.add('Line ' + lineNo + ': ' + result);
                System.debug('✗ Line ' + lineNo + ' deletion failed: ' + result);
            }
        }
        
        System.debug('Delete Summary - Success: ' + successCount + ', Failures: ' + failureCount);
        
        if (failureCount == 0) {
            return 'LINE_ITEMS_DELETE_SUCCESS: All ' + successCount + ' items deleted';
        } else if (successCount == 0) {
            return 'LINE_ITEMS_DELETE_FAILED: All deletions failed. Errors: ' + String.join(errorMessages, '; ');
        } else {
            return 'LINE_ITEMS_DELETE_PARTIAL: ' + successCount + ' succeeded, ' + failureCount + ' failed. Errors: ' + String.join(errorMessages, '; ');
        }
    }
    
    /**
     * Delete a single line item using BC Delete API
     * @param bcKey - Business Central Key for the line item
     * @param lineNo - Line number (for logging purposes)
     * @return Result message
     */
    private static String deleteSingleLineItem(String bcKey, Integer lineNo) {
        System.debug('  Deleting single line item - Line No: ' + lineNo + ', Key: ' + bcKey);
        
        try {
            String requestBody = buildDeleteSOAPRequest(bcKey);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_LINE_ITEM_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_LINE_NAMESPACE + ':Delete');
            
            // Add Basic Authentication
            Blob headerValue = Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD);
            String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
            req.setHeader('Authorization', authorizationHeader);
            
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse response = http.send(req);
            
            System.debug('  Delete Response Status: ' + response.getStatusCode());
            
            if (response.getStatusCode() == 200) {
                System.debug('  Line Item Deleted Successfully');
                return 'DELETE_SUCCESS';
            } else {
                System.debug('  Delete Response Body: ' + response.getBody());
                return 'FAILURE: Status ' + response.getStatusCode();
            }
            
        } catch (Exception ex) {
            System.debug('  *** Delete Exception: ' + ex.getMessage());
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    /**
     * Build Delete SOAP Request
     */
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
    
    /**
     * Helper: Escape XML
     */
    private static String escapeXml(String value) {
        if (String.isBlank(value)) return '';
        return value.escapeXml();
    }
}