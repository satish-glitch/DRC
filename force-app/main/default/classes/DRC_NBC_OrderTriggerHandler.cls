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
            List<Order> toProcess = new List<Order>();

            for (Order o : newList) {
                // On INSERT: fire if Warehouse is not null
                if (isInsert) {
                    if (o.DRC_NBC_Warehouse__c != null) {
                        toProcess.add(o);
                    }
                }

                // On UPDATE: fire if Warehouse changed AND new value not null
                if (isUpdate) {
                    Order oldO = oldMap.get(o.Id);
                    Boolean changed =
                        o.DRC_NBC_Warehouse__c != oldO.DRC_NBC_Warehouse__c;

                    if (changed && o.DRC_NBC_Warehouse__c != null) {
                        toProcess.add(o);
                    }
                }
            }

            if (toProcess.isEmpty()) return;
            updateRelatedAddresses(toProcess);

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
            // Update Address field with Order warehouse value
            a.DRC_NBC_Warehouse__c = o.DRC_NBC_Warehouse__c;

            addrToUpdate.add(a);
        }

        if (!addrToUpdate.isEmpty()) {
            update addrToUpdate;
        }
    }
}