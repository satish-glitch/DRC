public class AccountTriggerHandler {
    
    public static void preventDuplicateAccounts(List<Account> newAccounts) {
        Set<String> namePhoneSet = new Set<String>();

        for (Account acc : newAccounts) {
            if (acc.Name != null && acc.Phone != null) {
                namePhoneSet.add(acc.Name.trim().toLowerCase() + '###' + acc.Phone.trim());
            }
        }

        if (namePhoneSet.isEmpty()) return;

        // Query existing Accounts that have same Name and Phone
        Map<String, Account> existingAccountMap = new Map<String, Account>();
        for (Account existing : [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Name != null AND Phone != null
        ]) {
            String key = existing.Name.trim().toLowerCase() + '###' + existing.Phone.trim();
            if (namePhoneSet.contains(key)) {
                existingAccountMap.put(key, existing);
            }
        }

        // Add error if duplicate found
        for (Account acc : newAccounts) {
            if (acc.Name != null && acc.Phone != null) {
                String key = acc.Name.trim().toLowerCase() + '###' + acc.Phone.trim();
                if (existingAccountMap.containsKey(key)) {
                    acc.addError('Duplicate Account detected: An account with the same Name and Phone already exists.');
                }
            }
        }
    }
}