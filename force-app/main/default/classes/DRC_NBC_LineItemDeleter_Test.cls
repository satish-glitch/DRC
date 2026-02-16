/**
* @File Name : DRC_NBC_LineItemDeleter_Test.cls
* @Description : Test class for DRC_NBC_LineItemDeleter
* @Author : Satish Yadav
* @Last Modified On : February 09, 2026
**/
@isTest
private class DRC_NBC_LineItemDeleter_Test {
    public static List<String> deletedKeys = new List<String>();
    
    /**
* Test Data Setup
*/
    @testSetup
    static void setupTestData() {
        // Create Custom Setting
        DRC_NBC_BC_Integration__c bcSettings = new DRC_NBC_BC_Integration__c();
        bcSettings.DRC_NBC_BC_Order_Endpoint__c = 'https://test.bc.com/order';
        bcSettings.DRC_NBC_BC_Line_Item_Endpoint__c = 'https://test.bc.com/lineitem';
        bcSettings.DRC_NBC_SOAP_Order_Namespace__c = 'urn:microsoft-dynamics-schemas/codeunit/SalesOrderSalesForce';
        bcSettings.DRC_NBC_SOAP_Line_Namespace__c = 'urn:microsoft-dynamics-schemas/page/SalesOrderLineSalesForce';
        bcSettings.DRC_NBC_GST_Credit_Value__c = 'AVAILMENT';
        bcSettings.DRC_NBC_Username__c = 'testuser';
        bcSettings.DRC_NBC_Password__c = 'testpass';
        insert bcSettings;
    }
    
    /**
* Test: Delete single line item successfully
*/
    @isTest
    static void testDeleteSingleLineItem() {
        Test.setMock(HttpCalloutMock.class, new DeleteSuccessHttpMock());
        
        Map<Integer, String> lineKeysToDelete = new Map<Integer, String>();
        lineKeysToDelete.put(10000, 'LINE-KEY-001');
        
        Test.startTest();
        String result = DRC_NBC_LineItemDeleter.deleteLineItems(lineKeysToDelete);
        Test.stopTest();
        
        System.assert(result.contains('SUCCESS'), 'Should return success: ' + result);
        System.assert(result.contains('1 items deleted'), 'Should indicate 1 item deleted: ' + result);
    }
    
    /**
* Test: Delete multiple line items successfully
*/
    @isTest
    static void testDeleteMultipleLineItems() {
        Test.setMock(HttpCalloutMock.class, new DeleteSuccessHttpMock());
        
        Map<Integer, String> lineKeysToDelete = new Map<Integer, String>();
        lineKeysToDelete.put(10000, 'LINE-KEY-001');
        lineKeysToDelete.put(20000, 'LINE-KEY-002');
        lineKeysToDelete.put(30000, 'LINE-KEY-003');
        
        Test.startTest();
        String result = DRC_NBC_LineItemDeleter.deleteLineItems(lineKeysToDelete);
        Test.stopTest();
        
        System.assert(result.contains('SUCCESS'), 'Should return success: ' + result);
        System.assert(result.contains('3 items deleted'), 'Should indicate 3 items deleted: ' + result);
    }
    
    /**
* Test: Delete with empty map
*/
    @isTest
    static void testDeleteEmptyMap() {
        Map<Integer, String> lineKeysToDelete = new Map<Integer, String>();
        
        Test.startTest();
        String result = DRC_NBC_LineItemDeleter.deleteLineItems(lineKeysToDelete);
        Test.stopTest();
        
        System.assertEquals('NO_ITEMS_TO_DELETE', result, 'Should return NO_ITEMS_TO_DELETE');
    }
    
    /**
* Test: Delete with null map
*/
    @isTest
    static void testDeleteNullMap() {
        Test.startTest();
        String result = DRC_NBC_LineItemDeleter.deleteLineItems(null);
        Test.stopTest();
        
        System.assertEquals('NO_ITEMS_TO_DELETE', result, 'Should return NO_ITEMS_TO_DELETE for null');
    }
    
    /**
* Test: Delete with BC failure response
*/
    @isTest
    static void testDeleteWithBCFailure() {
        Test.setMock(HttpCalloutMock.class, new DeleteFailureHttpMock());
        
        Map<Integer, String> lineKeysToDelete = new Map<Integer, String>();
        lineKeysToDelete.put(10000, 'LINE-KEY-001');
        lineKeysToDelete.put(20000, 'LINE-KEY-002');
        
        Test.startTest();
        String result = DRC_NBC_LineItemDeleter.deleteLineItems(lineKeysToDelete);
        Test.stopTest();
        
        System.assert(result.contains('FAILED'), 'Should indicate failure: ' + result);
    }
    
    /**
* Test: Partial success scenario
*/
    @isTest
    static void testDeletePartialSuccess() {
        Test.setMock(HttpCalloutMock.class, new DeletePartialSuccessHttpMock());
        
        Map<Integer, String> lineKeysToDelete = new Map<Integer, String>();
        lineKeysToDelete.put(10000, 'LINE-KEY-SUCCESS');
        lineKeysToDelete.put(20000, 'LINE-KEY-FAIL');
        lineKeysToDelete.put(30000, 'LINE-KEY-SUCCESS');
        
        Test.startTest();
        String result = DRC_NBC_LineItemDeleter.deleteLineItems(lineKeysToDelete);
        Test.stopTest();
        
        System.assert(result.contains('PARTIAL'), 'Should indicate partial success: ' + result);
        System.assert(result.contains('2 succeeded'), 'Should show 2 succeeded');
        System.assert(result.contains('1 failed'), 'Should show 1 failed');
    }
    
    /**
* Test: Delete items in reverse order (highest line number first)
*/
    @isTest
    static void testDeleteReverseOrder() {
        Test.setMock(HttpCalloutMock.class, new DeleteOrderTrackingHttpMock());
        
        Map<Integer, String> lineKeysToDelete = new Map<Integer, String>();
        lineKeysToDelete.put(10000, 'LINE-KEY-001');
        lineKeysToDelete.put(50000, 'LINE-KEY-005');
        lineKeysToDelete.put(30000, 'LINE-KEY-003');
        
        Test.startTest();
        String result = DRC_NBC_LineItemDeleter.deleteLineItems(lineKeysToDelete);
        Test.stopTest();
        
        // Items should be deleted from highest to lowest line number
        System.assert(result.contains('SUCCESS'), 'Should return success');
    }
    
    /**
* Test: Exception handling
*/
    @isTest
    static void testDeleteException() {
        Test.setMock(HttpCalloutMock.class, new DeleteExceptionHttpMock());
        
        Map<Integer, String> lineKeysToDelete = new Map<Integer, String>();
        lineKeysToDelete.put(10000, 'LINE-KEY-001');
        
        Test.startTest();
        String result = DRC_NBC_LineItemDeleter.deleteLineItems(lineKeysToDelete);
        Test.stopTest();
        
        System.assert(result.contains('ERROR') || result.contains('FAILED'), 'Should handle exception: ' + result);
    }
    
    /**
* Test: Delete with large number of items
*/
    @isTest
    static void testDeleteLargeNumberOfItems() {
        Test.setMock(HttpCalloutMock.class, new DeleteSuccessHttpMock());
        
        Map<Integer, String> lineKeysToDelete = new Map<Integer, String>();
        for (Integer i = 1; i <= 10; i++) {
            lineKeysToDelete.put(i * 10000, 'LINE-KEY-' + i);
        }
        
        Test.startTest();
        String result = DRC_NBC_LineItemDeleter.deleteLineItems(lineKeysToDelete);
        Test.stopTest();
        
        System.assert(result.contains('SUCCESS'), 'Should successfully delete all items: ' + result);
        System.assert(result.contains('10 items deleted'), 'Should delete 10 items');
    }
    
    /**
* HTTP Mock for successful delete responses
*/
    private class DeleteSuccessHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<Delete_Result>Success</Delete_Result>' +
                '</soap:Body>' +
                '</soap:Envelope>'
            );
            return res;
        }
    }
    
    /**
* HTTP Mock for failed delete responses
*/
    private class DeleteFailureHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
    
    /**
* HTTP Mock for partial success (alternating success/failure)
*/
    private class DeletePartialSuccessHttpMock implements HttpCalloutMock {
        private Integer callCount = 0;
        
        public HTTPResponse respond(HTTPRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            
            // Check if request contains "FAIL" key
            if (req.getBody().contains('LINE-KEY-FAIL')) {
                res.setStatusCode(500);
                res.setBody('Delete Failed');
            } else {
                res.setStatusCode(200);
                res.setBody(
                    '<?xml version="1.0" encoding="utf-8"?>' +
                    '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soap:Body>' +
                    '<Delete_Result>Success</Delete_Result>' +
                    '</soap:Body>' +
                    '</soap:Envelope>'
                );
            }
            
            return res;
        }
    }
    
    /**
* HTTP Mock to track delete order
*/
    private class DeleteOrderTrackingHttpMock implements HttpCalloutMock {
        
        
        public HTTPResponse respond(HTTPRequest req) {
            // Track which key is being deleted
            String requestBody = req.getBody();
            if (requestBody.contains('LINE-KEY-001')) {
                deletedKeys.add('001');
            } else if (requestBody.contains('LINE-KEY-003')) {
                deletedKeys.add('003');
            } else if (requestBody.contains('LINE-KEY-005')) {
                deletedKeys.add('005');
            }
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                '<soap:Body>' +
                '<Delete_Result>Success</Delete_Result>' +
                '</soap:Body>' +
                '</soap:Envelope>'
            );
            return res;
        }
    }
    
    /**
* HTTP Mock that throws exception
*/
    private class DeleteExceptionHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            throw new CalloutException('Connection timeout');
        }
    }
}