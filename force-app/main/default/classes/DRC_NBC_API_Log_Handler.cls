public with sharing class DRC_NBC_API_Log_Handler {
    public static void createApiLog(
        String endpoint,
        String requestBody,
        String responseBody,
        String method,
        String errorMessage,
        Integer statusCode,
        String stackTrace,
        String logType,
        String sfId
    ) {
        try {
            DRC_NBC_API_Log__c apiLog = new DRC_NBC_API_Log__c();
            apiLog.DRC_NBC_Endpoint__c = endpoint;
            apiLog.DRC_NBC_Payload__c = requestBody;
            apiLog.DRC_NBC_Response_Body__c = responseBody;
            apiLog.DRC_NBC_Method_Name__c = method;
            apiLog.DRC_NBC_Error_Message__c = errorMessage;
            apiLog.DRC_NBC_Status_Code__c = statusCode;
            apiLog.DRC_NBC_Stack_Trace__c = stackTrace;
            apiLog.DRC_NBC_Timestamp__c = System.now();
            apiLog.DRC_NBC_Log_Type__c = logType;
            apiLog.DRC_NBC_Created_Updated_SF_Id__c = sfId;
            insert apiLog;
        } catch (Exception e) {
            System.debug('Failed to log API call: ' + e.getMessage());
        }
    }
    
    @future
    public static void createApiLogAsync(
        String endpoint,
        String requestBody,
        String responseBody,
        String method,
        String errorMessage,
        Integer statusCode,
        String stackTrace,
        String logType,
        String sfId
    ) {
        try {
            DRC_NBC_API_Log__c apiLog = new DRC_NBC_API_Log__c();
            apiLog.DRC_NBC_Endpoint__c = endpoint;
            apiLog.DRC_NBC_Payload__c = requestBody;
            apiLog.DRC_NBC_Response_Body__c = responseBody;
            apiLog.DRC_NBC_Method_Name__c = method;
            apiLog.DRC_NBC_Error_Message__c = errorMessage;
            apiLog.DRC_NBC_Status_Code__c = statusCode;
            apiLog.DRC_NBC_Stack_Trace__c = stackTrace;
            apiLog.DRC_NBC_Timestamp__c = System.now();
            apiLog.DRC_NBC_Log_Type__c = logType;
            apiLog.DRC_NBC_Created_Updated_SF_Id__c = sfId;
            insert apiLog;
        } catch (Exception e) {
            System.debug('Failed to log API call: ' + e.getMessage());
        }
    }
}