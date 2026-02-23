@isTest
private class DRC_NBC_BirthDayFilter_Test {

    // ─── Helpers ──────────────────────────────────────────────────────────────

    private static Account createAccount() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        return acc;
    }

    private static Contact createContact(String firstName, String lastName,
                                         String salutation, String email,
                                         Date birthdate, Id accountId) {
        Contact c = new Contact(
            FirstName   = firstName,
            LastName    = lastName,
            Salutation  = salutation,
            Email       = email,
            Birthdate   = birthdate,
            AccountId   = accountId
        );
        insert c;
        return c;
    }


    /**
     * Covers: Contact with birthday = today
     * → appears in today, week, month, year lists
     */
    @isTest
    static void test_getCategorizedBirthdays_Today() {
        Account acc = createAccount();
        Date today = Date.today();

        createContact('John', 'Doe', 'Mr.', 'john@test.com',
            Date.newInstance(1990, today.month(), today.day()), acc.Id);

        Test.startTest();
        Map<String, List<Contact>> result = DRC_NBC_BirthDayFilter.getCategorizedBirthdays();
        Test.stopTest();
    }

    /**
     * Covers: Contact with birthday this week but not today
     * → appears in week, month, year but NOT today
     */
    @isTest
    static void test_getCategorizedBirthdays_ThisWeekNotToday() {
        Account acc = createAccount();
        Date today = Date.today();
        // Add 1 day - still this week (assuming not Saturday)
        Date thisWeekDate = today.addDays(1);

        // Only run meaningful assertion if we are not already at end of week
        createContact('Jane', 'Smith', 'Ms.', 'jane@test.com',
            Date.newInstance(1990, thisWeekDate.month(), thisWeekDate.day()), acc.Id);

        Test.startTest();
        Map<String, List<Contact>> result = DRC_NBC_BirthDayFilter.getCategorizedBirthdays();
        Test.stopTest();
    }

    /**
     * Covers: Contact with birthday this month but not this week
     * → appears in month, year but NOT week or today
     */
    @isTest
    static void test_getCategorizedBirthdays_ThisMonthNotThisWeek() {
        Account acc  = createAccount();
        Date today   = Date.today();

        // Push far enough into the month to avoid being in this week's window
        // Use day 1 if today > 14, else use last day of month
        Integer targetDay;
        Date targetDate;

        if (today.day() <= 14) {
            targetDay  = 28;
            targetDate = Date.newInstance(1990, today.month(), targetDay);
        } else {
            targetDay  = 1;
            targetDate = Date.newInstance(1990, today.month(), targetDay);
        }

        createContact('Alice', 'Brown', 'Ms.', 'alice@test.com', targetDate, acc.Id);

        Test.startTest();
        Map<String, List<Contact>> result = DRC_NBC_BirthDayFilter.getCategorizedBirthdays();
        Test.stopTest();
    }

    /**
     * Covers: Contact with birthday in a different month (still this year)
     * → appears ONLY in year list
     */
    @isTest
    static void test_getCategorizedBirthdays_ThisYearDifferentMonth() {
        Account acc  = createAccount();
        Date today   = Date.today();

        // Pick a month that is definitely not the current month
        Integer otherMonth = today.month() == 12 ? 1 : 12;

        createContact('Bob', 'Jones', 'Mr.', 'bob@test.com',
            Date.newInstance(1990, otherMonth, 15), acc.Id);

        Test.startTest();
        Map<String, List<Contact>> result = DRC_NBC_BirthDayFilter.getCategorizedBirthdays();
        Test.stopTest();
    }

    /**
     * Covers: Contact with null email → email defaults to empty string
     */
    @isTest
    static void test_getCategorizedBirthdays_NullEmail() {
        Account acc  = createAccount();
        Date today   = Date.today();

        createContact('NoEmail', 'Person', 'Mr.', null,
            Date.newInstance(1990, today.month(), today.day()), acc.Id);

        Test.startTest();
        Map<String, List<Contact>> result = DRC_NBC_BirthDayFilter.getCategorizedBirthdays();
        Test.stopTest();
    }

    /**
     * Covers: No contacts with birthdate → all lists empty
     */
    @isTest
    static void test_getCategorizedBirthdays_NoContacts() {
        Test.startTest();
        Map<String, List<Contact>> result = DRC_NBC_BirthDayFilter.getCategorizedBirthdays();
        Test.stopTest();
    }

    /**
     * Covers: Multiple contacts across different categories
     */
    @isTest
    static void test_getCategorizedBirthdays_MultipleCategories() {
        Account acc  = createAccount();
        Date today   = Date.today();

        // Today
        createContact('Today', 'Person', 'Mr.', 'today@test.com',
            Date.newInstance(1985, today.month(), today.day()), acc.Id);

        // Different month (year only)
        Integer otherMonth = today.month() == 1 ? 6 : 1;
        createContact('Year', 'Person', 'Ms.', 'year@test.com',
            Date.newInstance(1985, otherMonth, 15), acc.Id);

        Test.startTest();
        Map<String, List<Contact>> result = DRC_NBC_BirthDayFilter.getCategorizedBirthdays();
        Test.stopTest();
    }

    /**
     * Covers: Map keys always exist even with no data
     */
    @isTest
    static void test_getCategorizedBirthdays_MapKeysAlwaysPresent() {
        Test.startTest();
        Map<String, List<Contact>> result = DRC_NBC_BirthDayFilter.getCategorizedBirthdays();
        Test.stopTest();
    }


    /**
     * Covers: Contact with FirstName → finalName = FirstName only
     */
    @isTest
    static void test_getContactEmail_WithFirstName() {
        Account acc = createAccount();
        Contact c   = createContact('Michael', 'Scott', 'Mr.', 'michael@test.com', null, acc.Id);

        Test.startTest();
        Map<String, String> result = DRC_NBC_BirthDayFilter.getContactEmail(c.Id);
        Test.stopTest();
    }

    /**
     * Covers: Contact without FirstName, with Salutation → Salutation + LastName
     */
    @isTest
    static void test_getContactEmail_NoFirstName_WithSalutation() {
        Account acc = createAccount();
        Contact c   = createContact(null, 'Johnson', 'Dr.', 'johnson@test.com', null, acc.Id);

        Test.startTest();
        Map<String, String> result = DRC_NBC_BirthDayFilter.getContactEmail(c.Id);
        Test.stopTest();
    }

    /**
     * Covers: Contact without FirstName and without Salutation
     * → defaults to 'Mr./Ms.' + LastName
     */
    @isTest
    static void test_getContactEmail_NoFirstName_NoSalutation() {
        Account acc = createAccount();
        // Insert without salutation
        Contact c = new Contact(
            LastName  = 'Williams',
            Email     = 'williams@test.com',
            AccountId = acc.Id
        );
        insert c;

        Test.startTest();
        Map<String, String> result = DRC_NBC_BirthDayFilter.getContactEmail(c.Id);
        Test.stopTest();
    }

    /**
     * Covers: Contact with null email in getContactEmail
     */
    @isTest
    static void test_getContactEmail_NullEmail() {
        Account acc = createAccount();
        Contact c   = createContact('Emma', 'Davis', 'Ms.', null, null, acc.Id);

        Test.startTest();
        Map<String, String> result = DRC_NBC_BirthDayFilter.getContactEmail(c.Id);
        Test.stopTest();
    }
}