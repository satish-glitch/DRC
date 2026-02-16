public class DRC_NBC_AccountNumberGenerator_Helper {
    
    @future
    public static void generateAccountNumbersAsync(Id accountIds) {
        generateAccountNumbersSync(accountIds);
    }
    
    public static void generateAccountNumbersSync(Id accountIds) {
        List<Account> accounts = [
            SELECT Id, BillingCountry, DRC_NBC_Customer_Number__c
            FROM Account
            WHERE Id  =:accountIds
        ];
        
        List<Account> toUpdate = new List<Account>();
        
        for (Account acc : accounts) {
            if (String.isNotBlank(acc.DRC_NBC_Customer_Number__c)) {
                continue;
            }
            
            String country = acc.BillingCountry != null ? acc.BillingCountry.trim().toLowerCase() : '';
            String type = country == 'india' ? 'CustDOM' : 'CustEXP';
            
            Integer nextNumber = getNextNumber(type);
            String padded = String.valueOf(100000 + nextNumber).right(5);
            String year = String.valueOf(Date.today().year()).right(2) +
                String.valueOf(Date.today().addYears(1).year()).right(2);
            
            acc.DRC_NBC_Customer_Number__c = type + '/' + year + '-' + padded;
            
            toUpdate.add(acc);
        }
        
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
    
    public static Integer getNextNumber(String type) {
        String prefix = getPrefix(type);
        System.debug('prefix ' + prefix);
        String pattern = prefix + '%';  
        // Get all customer numbers that match the prefix
        List<Account> existing = [
            SELECT DRC_NBC_Customer_Number__c
            FROM Account
            WHERE DRC_NBC_Customer_Number__c LIKE :pattern
        ];
        
        Integer maxNum = 0;
        System.debug('Existing Numbers: ' + existing);
        for (Account acc : existing) {
            if (String.isBlank(acc.DRC_NBC_Customer_Number__c)) {
                continue;
            }
            List<String> parts = acc.DRC_NBC_Customer_Number__c.split('-');        
            if (parts.size() == 2) {
                try {
                    Integer num = Integer.valueOf(parts[1]);
                    if (num > maxNum) {
                        maxNum = num;         
                    }
                } catch (Exception e) {
                    // Skip invalid formats
                }
            }
        }
        
        System.debug('Max Number Found: ' + maxNum);
        
        return maxNum + 1;
    }
    
    
    public static String getPrefix(String type) {
        String year = String.valueOf(Date.today().year()).right(2) +
            String.valueOf(Date.today().addYears(1).year()).right(2);
        
        return type + '/' + year + '-';
    }
}