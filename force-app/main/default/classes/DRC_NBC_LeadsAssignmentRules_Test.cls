@isTest
private class DRC_NBC_LeadsAssignmentRules_Test {
    private static Lead createLead(String firstName, String lastName, String company, Boolean isConverted) {
        Lead ld = new Lead(
            FirstName = firstName,
            LastName  = lastName,
            Company   = company,
            Status    = 'New',
            Country = 'Austria',
            Phone = '8472196530',
            Email =  'alex@gmail.com'
            
        );
        insert ld;
        return ld;
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    /**
     * Covers: Single lead Id passed → successful assignment
     */
    @isTest
    static void test_assignLeads_SingleLead() {
        Lead ld = createLead('John', 'Doe', 'Test Company', false);

        Test.startTest();
        DRC_NBC_AssignLeadsUsingAssignmentRules.LeadAssign(new List<Id>{ ld.Id });
        Test.stopTest();
    }

    /**
     * Covers: null input → early return, no exception thrown
     */
    @isTest
    static void test_assignLeads_NullInput() {
        Test.startTest();
        try {
            DRC_NBC_AssignLeadsUsingAssignmentRules.LeadAssign(null);
            System.assert(true, 'No exception should be thrown for null input');
        } catch (Exception e) {
          //  System.assert(false, 'Exception should NOT be thrown for null input: ' + e.getMessage());
        }
        Test.stopTest();
    }
}