@RestResource(urlMapping = '/OrderDispatchStatusSync/*')
global without sharing class DRC_NBC_OrderDispatchStatusSync {
    
    @HttpPost
    global static void syncOrderStatus() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        Savepoint sp;
        String requestBody = '';
        try {
            sp = Database.setSavepoint();
            requestBody = req.requestBody.toString();
            DRC_NBC_Integration_Payload.OrderStatusPayload payload =
                DRC_NBC_Integration_Utility.validateOrderStatusPayload(requestBody);
            
            // STEP 2: Validate required fields
            if (String.isBlank(payload.orderId)) {
                throw new CalloutException('Order ID is required.');
            }
            System.debug('payload.orderId>>>>>>> '+ payload.orderId);
            Order orderRec = [
                SELECT Id, Status, DRC_NBC_Cust_Order_Number__c, DRC_NBC_Expected_Delivery_Date__c,DRC_NBC_Tracking_Id__c,
                DRC_NBC_Payment_Terms__c, DRC_NBC_Inco_Terms__c, DRC_NBC_Order_PartiallyShipped__c
                FROM Order
                WHERE DRC_NBC_Cust_Order_Number__c = :payload.orderId
                LIMIT 1
            ];
            
            // STEP 4: Apply updates from payload
            if (payload.status != null) orderRec.Status = payload.status;
            if (payload.PartiallyShipped != null) orderRec.DRC_NBC_Order_PartiallyShipped__c = payload.PartiallyShipped;
            if (payload.trackingId != null) orderRec.DRC_NBC_Tracking_Id__c = payload.trackingId;
            Date expDt = parseExpectedDeliveryDate(payload.expectedDeliveryDate);
            if (expDt != null) {
                orderRec.DRC_NBC_Expected_Delivery_Date__c = expDt;
            }
            if (payload.paymentTerms != null) orderRec.DRC_NBC_Payment_Terms__c = payload.paymentTerms;
            // if (payload.incoTerms != null) orderRec.DRC_NBC_Inco_Terms__c = payload.incoTerms;
            if (!String.isBlank(payload.incoTerms)) {
                Warehouse_Location_Code__mdt incoTermsMeta = [
                    SELECT MasterLabel
                    FROM Warehouse_Location_Code__mdt
                    WHERE DRC_NBC_Code__c = :payload.incoTerms
                    AND DRC_NBC_Type__c = 'Inco Terms'
                    LIMIT 1
                ];
                
                if (incoTermsMeta != null) {
                    orderRec.DRC_NBC_Inco_Terms__c = incoTermsMeta.MasterLabel;
                } else {
                    throw new CalloutException('Invalid IncoTerms code: ' + payload.incoTerms);
                }
            }
            
            update orderRec;
            // STEP 5: Success Response
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Order updated successfully.');
            DRC_NBC_API_Log_Handler.createApiLog(
                '/OrderDispatchStatusSync',
                requestBody,
                'Order updated successfully.',
                'POST',
                null,
                200,
                null,
                'Success',
                orderRec.Id
            );
        } catch (Exception ex) {
            Database.rollback(sp);
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + ex.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                '/OrderDispatchStatusSync',
                requestBody,
                null,
                'POST',
                ex.getMessage(),
                500,
                ex.getStackTraceString(),
                'Error',
                null
            );
        }
    }
    
    private static Date parseExpectedDeliveryDate(String s) {
        if (String.isBlank(s)) return null;
        
        s = s.trim();
        
        // Treat default "empty" dates from external systems as null (do not update)
        if (s == '0001-01-01' || s == '01/01/0001' || s == '01-01-0001') return null;
        
        // DD/MM/YYYY
        if (s.contains('/')) {
            List<String> p = s.split('/');
            if (p.size() == 3) {
                Integer dd = Integer.valueOf(p[0]);
                Integer mm = Integer.valueOf(p[1]);
                Integer yy = Integer.valueOf(p[2]);
                return Date.newInstance(yy, mm, dd);
            }
        }
        
        // DD-MM-YYYY
        if (s.contains('-') && s.indexOf('-') == 2) {
            List<String> p = s.split('-');
            if (p.size() == 3) {
                Integer dd = Integer.valueOf(p[0]);
                Integer mm = Integer.valueOf(p[1]);
                Integer yy = Integer.valueOf(p[2]);
                return Date.newInstance(yy, mm, dd);
            }
        }
        
        // Fallback: YYYY-MM-DD (Salesforce default)
        return Date.valueOf(s);
    }
}