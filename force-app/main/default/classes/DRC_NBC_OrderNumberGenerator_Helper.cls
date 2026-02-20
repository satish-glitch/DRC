public class DRC_NBC_OrderNumberGenerator_Helper {
    @future
    public static void generateOrderNumbersSync(Id orderIds) {
        List<Order> orders = [
            SELECT Id, DRC_NBC_Type__c, DRC_NBC_Cust_Order_Number__c, Status
            FROM Order 
            WHERE Id =:orderIds
        ];
        List<Order> toUpdate = new List<Order>();
        for (Order ord : orders) {
            /* if (String.isBlank(ord.DRC_NBC_Type__c)) {
continue;
}  */        
            if (!String.isBlank(ord.DRC_NBC_Cust_Order_Number__c)) {
                continue;
            }          
            String rawType = ord.DRC_NBC_Type__c != null ? ord.DRC_NBC_Type__c.trim() : '';
            String type;
            if (rawType.equalsIgnoreCase('Domestic')) {
                type = 'DOM';
            } else if (rawType.equalsIgnoreCase('Export')) {
                type = 'EXP';
            } else {
                type = 'SAMPLE';
            }
            System.debug ('type before next Number>> ' + type);
            Integer nextNumber = getNextNumberFromOrders(type);
            String padded = String.valueOf(100000 + nextNumber).right(5);
            String fiscalYear = String.valueOf(Date.today().year()).right(2) +
                String.valueOf(Date.today().addYears(1).year()).right(2);
            
            ord.DRC_NBC_Cust_Order_Number__c =
                'SO' + type + '/' + fiscalYear + '/' + padded;
            toUpdate.add(ord);
        }
        
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
    
    
    public static Integer getNextNumberFromOrders(String type) {
        System.debug ('type before get prefix>> ' + type);
        
        String prefix = getPrefix(type);
        
        List<Order> matchingOrders = [
            SELECT DRC_NBC_Cust_Order_Number__c
            FROM Order
            WHERE DRC_NBC_Cust_Order_Number__c LIKE :prefix + '%'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        if (!matchingOrders.isEmpty()) {
            String lastValue = matchingOrders[0].DRC_NBC_Cust_Order_Number__c;
            String[] parts = lastValue.split('/');
            if (parts.size() == 3) {
                return Integer.valueOf(parts[2]) + 1;
            }
        }
        return 1;
    }
    
    public static String getPrefix(String type) {
        String fiscalYear = String.valueOf(Date.today().year()).right(2) +
            String.valueOf(Date.today().addYears(1).year()).right(2);
        
        return 'SO' + type + '/' + fiscalYear + '/';
    }
    
}