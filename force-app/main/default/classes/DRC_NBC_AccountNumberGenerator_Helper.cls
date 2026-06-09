public without sharing class DRC_NBC_AccountNumberGenerator_Helper {
    
    @future
    public static void generateAccountNumbersAsync(Id accountIds) {
        generateAccountNumbersSync(accountIds);
    }
    
    public static void generateAccountNumbersSync(Id accountIds) {
        List<Account> accounts = [
            SELECT Id, BillingCountry, DRC_NBC_Customer_Number__c
            FROM Account
            WHERE Id = :accountIds
        ];
        
        List<Account> toUpdate = new List<Account>();
        
        for (Account acc : accounts) {
            if (String.isNotBlank(acc.DRC_NBC_Customer_Number__c)) {
                continue;
            }
            
            String country = acc.BillingCountry != null ? acc.BillingCountry.trim().toLowerCase() : '';
            String type = country == 'india' ? Label.DRC_NBC_Domestic_Customer : Label.DRC_NBC_Export_Customer;
            
            Integer nextNumber = getNextNumber(type);
            String padded = String.valueOf(100000 + nextNumber).right(5);
            
            acc.DRC_NBC_Customer_Number__c = type + padded;
            toUpdate.add(acc);
        }
        
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
    
    public static Integer getNextNumber(String type) {
        // 'type' here is the Custom Label value e.g. 'DomCust' or 'ExpCust'
        String prefix = type; // use the label value directly as prefix
        String queryPattern = prefix + '%';
        
        System.debug('Prefix used for query: ' + prefix);
        
        // Fetch all accounts whose customer number starts with this label prefix
        List<Account> existing = [
            SELECT DRC_NBC_Customer_Number__c
            FROM Account
            WHERE DRC_NBC_Customer_Number__c LIKE :queryPattern
        ];
        
        System.debug('Existing Numbers: ' + existing);
        
        Integer maxNum = 0;
        Integer prefixLength = prefix.length(); // e.g. 'DomCust'.length() = 7
        
        for (Account acc : existing) {
            if (String.isBlank(acc.DRC_NBC_Customer_Number__c)) {
                continue;
            }
            
            String customerNum = acc.DRC_NBC_Customer_Number__c;
            
            // Extract only the numeric portion after the prefix
            // e.g. 'DomCust00001' → '00001'
            if (customerNum.length() > prefixLength) {
                String numericPart = customerNum.substring(prefixLength);
                try {
                    Integer num = Integer.valueOf(numericPart);
                    if (num > maxNum) {
                        maxNum = num;
                    }
                } catch (Exception e) {
                    System.debug('Skipping invalid format: ' + customerNum);
                }
            }
        }
        
        System.debug('Max Number Found: ' + maxNum);
        
        return maxNum + 1;
    }
    
    public static String getPrefix(String type) {
        // Returns the Custom Label value directly as the prefix
        return type;
    }
}