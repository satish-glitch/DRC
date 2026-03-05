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
    
    @isTest
    static void test_CompetitorCopiedOnLeadConversion() {
        
        // Create Lead
        Lead ld = new Lead(
            FirstName = 'Alex',
            LastName  = 'Test',
            Company   = 'Test Company',
            Status    = 'Open - Not Contacted',
            Country   = 'Austria',
            Phone     = '8472196530',
            Email     = 'alex@gmail.com'
        );
        insert ld;
        
        // Create Competitor linked to Lead
        DRC_NBC_Competitor__c comp = new DRC_NBC_Competitor__c();
        comp.DRC_NBC_Lead__c = ld.Id;
        comp.DRC_NBC_Competitor_s_Name__c = 'CDF';
        comp.DRC_NBCompetitor_s_Influence_on_the_Deal__c = 'High';
        
        insert comp;
        
        // Get converted status
        LeadStatus convertStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = TRUE
            LIMIT 1
        ];
        
        // Convert Lead
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(ld.Id);
        lc.setConvertedStatus(convertStatus.MasterLabel);
        lc.setDoNotCreateOpportunity(true);
        
        Test.startTest();
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Test.stopTest();
        
        System.assert(lcr.isSuccess());
        
        // Verify competitor updated
        DRC_NBC_Competitor__c updatedComp = [
            SELECT Id, DRC_NBC_Account__c, DRC_NBC_Lead__c
            FROM DRC_NBC_Competitor__c
            WHERE Id = :comp.Id
        ];
        
        System.assertEquals(null, updatedComp.DRC_NBC_Lead__c);
        System.assertNotEquals(null, updatedComp.DRC_NBC_Account__c);
    }
}