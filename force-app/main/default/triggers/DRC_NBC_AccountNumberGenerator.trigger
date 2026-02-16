trigger DRC_NBC_AccountNumberGenerator on Account (after insert) {
    List<Id> accountIds = new List<Id>();

    for (Account acc : Trigger.new) {
        if (!String.isBlank(acc.BillingCountry) && String.isBlank(acc.DRC_NBC_Customer_Number__c)) {
            accountIds.add(acc.Id);
        }
    }

    if (!accountIds.isEmpty()) {
       // DRC_NBC_AccountNumberGenerator_Helper.generateAccountNumbersAsync(accountIds);
    }
}