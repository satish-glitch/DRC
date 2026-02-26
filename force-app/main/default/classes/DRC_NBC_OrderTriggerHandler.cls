public class DRC_NBC_OrderTriggerHandler {
    private static Boolean isRunning = false;
    
    public static void handleAfter(
        List<Order> newList,
        Map<Id, Order> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        if (isRunning) return;
        isRunning = true;
        
        try {
            // Existing logic: warehouse -> address update
            List<Order> toProcess = new List<Order>();
            
            // New logic: status transition tracking (OrderId -> transition type)
            // Values: 'A2R' = Accepted -> Released, 'R2A' = Released -> Accepted
            Map<Id, String> statusTransitions = new Map<Id, String>();
            
            for (Order o : newList) {
                
                // -------------------------
                // EXISTING: Warehouse logic
                // -------------------------
                if (isInsert) {
                    if (o.DRC_NBC_Warehouse__c != null) {
                        toProcess.add(o);
                    }
                }
                
                if (isUpdate) {
                    Order oldO = oldMap.get(o.Id);
                    
                    Boolean whChanged = (o.DRC_NBC_Warehouse__c != oldO.DRC_NBC_Warehouse__c);
                    if (whChanged && o.DRC_NBC_Warehouse__c != null) {
                        toProcess.add(o);
                    }
                    
                    // -------------------------
                    // NEW: Status change emails
                    // -------------------------
                    String oldStatus = oldO.Status;
                    String newStatus = o.Status;
                    
                    if (oldStatus == 'Accepted' && newStatus == 'Released') {
                        statusTransitions.put(o.Id, 'A2R');
                    } else if (oldStatus == 'Released' && newStatus == 'Accepted') {
                        statusTransitions.put(o.Id, 'R2A');
                    }
                }
            }
            
            // Run existing warehouse -> address updates
            if (!toProcess.isEmpty()) {
                updateRelatedAddresses(toProcess);
            }
            
            // Send emails for status transitions
            if (!statusTransitions.isEmpty()) {
                sendStatusChangeEmails(statusTransitions);
            }
            
        } finally {
            isRunning = false;
        }
    }
    
    private static void updateRelatedAddresses(List<Order> orders) {
        Set<Id> addressIds = new Set<Id>();
        Map<Id, Id> addressIdToOrderId = new Map<Id, Id>();
        
        for (Order o : orders) {
            if (o.DRC_NBC_Shipping_Address__c != null) {
                addressIds.add(o.DRC_NBC_Shipping_Address__c);
                addressIdToOrderId.put(o.DRC_NBC_Shipping_Address__c, o.Id);
            }
        }
        if (addressIds.isEmpty()) return;
        
        Map<Id, Order> orderMap = new Map<Id, Order>(orders);
        
        List<DRC_NBC_Addresses__c> addrToUpdate = new List<DRC_NBC_Addresses__c>();
        for (DRC_NBC_Addresses__c a : [
            SELECT Id, DRC_NBC_Warehouse__c
            FROM DRC_NBC_Addresses__c
            WHERE Id IN :addressIds
        ]) {
            Id orderId = addressIdToOrderId.get(a.Id);
            Order o = orderMap.get(orderId);
            
            a.DRC_NBC_Warehouse__c = o.DRC_NBC_Warehouse__c;
            addrToUpdate.add(a);
        }
        
        if (!addrToUpdate.isEmpty()) {
            update addrToUpdate;
        }
    }
    
    // NEW METHOD
    private static void sendStatusChangeEmails(Map<Id, String> statusTransitions) {
        // Query OrderNumber + OwnerId (OrderNumber may be null in Trigger.new depending on how update is done)
        List<Order> ords = [
            SELECT Id, OrderNumber, Status, OwnerId, DRC_NBC_Cust_Order_Number__c
            FROM Order
            WHERE Id IN :statusTransitions.keySet()
        ];
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (Order o : ords) {
            String transition = statusTransitions.get(o.Id);
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(o.OwnerId);
            mail.setSaveAsActivity(false);
            
            if (transition == 'A2R') {
                mail.setSubject('Order ' + o.DRC_NBC_Cust_Order_Number__c + ' order arrived ');
                mail.setPlainTextBody(
                    'Hello,\n\n' +
                    'The order has been moved from Accepted to Released and has arrived in BC.\n\n' +
                    'Order Number: ' + o.DRC_NBC_Cust_Order_Number__c + '\n\n' +
                    'Thanks,\n' +
                    'DRC Team'
                );
            } else if (transition == 'R2A') {
                mail.setSubject('Order ' + o.DRC_NBC_Cust_Order_Number__c + ' order Amendment ');
                mail.setPlainTextBody(
                    'Hello,\n\n' +
                    'The order status has been changed to Open for The amendment.\n\n' +
                    'Order Number: ' + o.DRC_NBC_Cust_Order_Number__c + '\n\n' +
                    'Thanks,\n' +
                    'DRC Team'
                );
            } else {
                continue;
            }
            
            emails.add(mail);
        }
        
        if (!emails.isEmpty()) {
            // One call (bulk-safe)
            Messaging.sendEmail(emails);
        }
    }
}