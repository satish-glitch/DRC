public class DRC_NBC_Order_BC_Update_Service {
    
    public static void processOrderUpdate(Id orderId) {
        try {
            markOrderSynced(orderId);
            System.debug('Total OrderItems for Order ' + orderId );
            // Start the first batch with index 0
            Database.executeBatch(new DRC_NBC_OrderProduct_BC_Batch(orderId));
            System.debug('Order marked as synced. OrderProduct batch initiated.');
            
        } catch (Exception e) {
            System.debug('Error in Order BC Update: ' + e.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Order_BC_Update_Service',
                null,
                null,
                'DirectCall',
                e.getMessage(),
                null,
                e.getStackTraceString(),
                'Error',
                orderId
            );
        }
    }
    @future
    Public static void markOrderSynced(Id orderId) {
        List<Order> ordersToUpdate = [
            SELECT Id, DRC_NBC_Order_Sync_To_BC__c,DRC_NBC_Integration_Status__c
            FROM Order 
            WHERE Id = :orderId
        ];
        
        for (Order ord : ordersToUpdate) {
            ord.DRC_NBC_Order_Sync_To_BC__c = true;
            ord.DRC_NBC_Integration_Status__c = 'ORDER_SUCCESS';
        }
        
        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }
    }
    
    @future
    public static void failedOrderUpdate(Id orderId) {
        List<Order> ordersToUpdate = [
            SELECT Id, DRC_NBC_Integration_Status__c
            FROM Order 
            WHERE Id = :orderId
        ];
        
        for (Order ord : ordersToUpdate) {
            ord.DRC_NBC_Integration_Status__c = 'ORDER_FAILED';
        }
        
        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }
    }
    
}