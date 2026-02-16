trigger DRC_NBC_OrderNumberGenerator on Order (after insert) {
   /* List<Id> validOrderIds = new List<Id>();
    
    for (Order ord : Trigger.new) {
        if (String.isBlank(ord.DRC_NBC_Cust_Order_Number__c)) {
            validOrderIds.add(ord.Id);
        }
        System.debug('Order Id: ' + ord.Id);
        System.debug('DRC_NBC_Type__c: ' + ord.DRC_NBC_Type__c);
        System.debug('DRC_NBC_Cust_Order_Number__c: ' + ord.DRC_NBC_Cust_Order_Number__c);
        
    }
    
    if (!validOrderIds.isEmpty()) {
      //  DRC_NBC_OrderNumberGenerator_Helper.generateOrderNumbersAsync(validOrderIds);
    }*/
}