public with sharing class DRC_NBC_BirthDayFilter {
    @AuraEnabled
    public static Map<String, List<Contact>> getCategorizedBirthdays(){
        try {
            List<Contact> allContacts = [SELECT Id, Name, Birthdate, Email, Account.Name FROM Contact WHERE Birthdate != null];
            System.debug('allContact' + allContacts);

            Date today = Date.Today();
            Integer currentYear = today.year();
            Date startOfWeek = today.toStartOfWeek();
            Date endOfWeek = today.addDays(6);

            Map<String, List<Contact>> categorized = new Map<String, List<Contact>>();

            categorized.put('today', new List<Contact>());
            categorized.put('week', new List<Contact>());
            categorized.put('month', new List<Contact>());
            categorized.put('year', new List<Contact>());

            for (Contact c : allContacts) {
                if (c.Email == null) {
                    c.Email = ''; 
                }

                Date birthdate = c.Birthdate;
                if (birthdate == null) continue;
        
                
                Date thisYearBd = Date.newInstance(currentYear, birthdate.month(), birthdate.day());

                Boolean isToday = thisYearBd == today;
                Boolean isThisWeek = thisYearBd >= startOfWeek && thisYearBd <= endOfWeek;
                Boolean isThisMonth = thisYearBd.month() == today.month();
                Boolean isThisYear = thisYearBd.year() == currentYear;
        
                
                if (isThisYear) {
                    categorized.get('year').add(c);
                    if (isThisMonth) {
                        categorized.get('month').add(c);
                        if (isThisWeek) {
                            categorized.get('week').add(c);
                            if (isToday) {
                                categorized.get('today').add(c);
                            }
                        }
                    }
                }
            }
            System.debug('categorized' + categorized);
            return categorized;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, String> getContactEmail(Id contactId) {
        try {
            Map<String, String> result = new Map<String, String>();

            Contact contactRecord = [
                SELECT Salutation, FirstName, LastName, Email
                FROM Contact 
                WHERE Id = :contactId 
                LIMIT 1
            ];

            result.put('Email', contactRecord.Email);

            // Build Name based on the rules
            String finalName;

            if (String.isNotBlank(contactRecord.FirstName)) {
                // Case 1: First name exists → only First Name
                finalName = contactRecord.FirstName;
            } else if (String.isNotBlank(contactRecord.LastName)) {
                // Case 2: First name missing → Salutation + Last Name
                String sal = String.isNotBlank(contactRecord.Salutation) 
                    ? contactRecord.Salutation 
                    : 'Mr./Ms.';  // default salutation
                finalName = sal + ' ' + contactRecord.LastName;
            } 

            result.put('Name', finalName);

            return result;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}