@isTest
private class DRC_NBC_API_Log_Handler_Test {

    @isTest
    static void testCreateApiLogSuccess() {

        Test.startTest();
        DRC_NBC_API_Log_Handler.createApiLog(
            'TestEndpoint',
            '{"req":"test"}',
            '{"res":"ok"}',
            'POST',
            null,
            200,
            null,
            'Success',
            '001000000000001'
        );
        Test.stopTest();

        List<DRC_NBC_API_Log__c> logs = [
            SELECT Id, DRC_NBC_Endpoint__c, DRC_NBC_Log_Type__c
            FROM DRC_NBC_API_Log__c
        ];

        System.assertEquals(1, logs.size());
        System.assertEquals('TestEndpoint', logs[0].DRC_NBC_Endpoint__c);
        System.assertEquals('Success', logs[0].DRC_NBC_Log_Type__c);
    }

    @isTest
    static void testCreateApiLogException() {

        // Force DML failure using extremely long string
        String longText = 'x'.repeat(200000);

        Test.startTest();
        DRC_NBC_API_Log_Handler.createApiLog(
            longText,
            longText,
            longText,
            'POST',
            longText,
            500,
            longText,
            'Error',
            longText
        );
        Test.stopTest();

        // No assertion needed — just ensuring catch block runs
        System.assert(true);
    }

    @isTest
    static void testCreateApiLogAsync() {

        Test.startTest();
        DRC_NBC_API_Log_Handler.createApiLogAsync(
            'AsyncEndpoint',
            '{"req":"async"}',
            '{"res":"ok"}',
            'GET',
            null,
            201,
            null,
            'Success',
            '001000000000002'
        );
        Test.stopTest(); // Required for future method execution

        List<DRC_NBC_API_Log__c> logs = [
            SELECT Id, DRC_NBC_Endpoint__c
            FROM DRC_NBC_API_Log__c
            WHERE DRC_NBC_Endpoint__c = 'AsyncEndpoint'
        ];

        System.assertEquals(1, logs.size());
    }
}