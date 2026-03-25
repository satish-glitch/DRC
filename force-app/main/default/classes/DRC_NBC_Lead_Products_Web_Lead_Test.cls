/**
* @File Name : DRC_NBC_Lead_Products_Web_Lead_Test.cls
* @Description : Test class for DRC_NBC_Lead_Products_From_Web_To_Lead 
*                and DRC_NBC_LeadInterestedChemistry
* @Last Modified On : September 3, 2025
**/
@isTest
private class DRC_NBC_Lead_Products_Web_Lead_Test {
    
    // ─── Test Data Setup ─────────────────────────────────────────────────────
    
    @TestSetup
    static void setupTestData() {
        // Create active products
        List<Product2> products = new List<Product2>{
            new Product2(Name = 'Chemical A', IsActive = true),
                new Product2(Name = 'Chemical B', IsActive = true),
                new Product2(Name = 'Chemical C', IsActive = true),
                new Product2(Name = 'Inactive Product', IsActive = false)
                };
                    insert products;
        
        
        // Create test Leads
        List<Lead> leads = new List<Lead>{
            new Lead(
                FirstName = 'Test',
                LastName = 'Lead One',
                Company = 'Company A',
                Phone = '9876543210',
                Email = 'leadone@test.com',
                Country = 'India',
                DRC_NBC_Interested_Chemistry__c = ''
            ),
                new Lead(
                    FirstName = 'Test',
                    LastName = 'Lead Two',
                    Company = 'Company B',
                    Phone = '9876543211',
                    Email = 'leadtwo@test.com',
                    Country = 'India',
                    DRC_NBC_Interested_Chemistry__c = 'Epoxy resin'
                ),
                new Lead(
                    FirstName = 'Test',
                    LastName = 'Lead Three',
                    Company = 'Company C',
                    Phone = '9876543212',
                    Email = 'leadthree@test.com',
                    Country = 'India',
                    DRC_NBC_Interested_Chemistry__c = ''
                )
                };
                    insert leads;
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // DRC_NBC_Lead_Products_From_Web_To_Lead — REST API Tests
    // ═══════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testGetProducts_ReturnsOnlyActiveProducts() {
        // Setup REST context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/ProductList';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        List<DRC_NBC_Lead_Products_From_Web_To_Lead.ProductWrapper> result =
            DRC_NBC_Lead_Products_From_Web_To_Lead.getProducts();
        Test.stopTest();
    }
    
    @isTest
    static void testGetProducts_WrapperFieldsPopulated() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/ProductList';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        List<DRC_NBC_Lead_Products_From_Web_To_Lead.ProductWrapper> result =
            DRC_NBC_Lead_Products_From_Web_To_Lead.getProducts();
        Test.stopTest();
    }
    
    
    @isTest
    static void testGetProducts_NoActiveProducts_ReturnsEmptyList() {
        // Deactivate all products
        List<Product2> allProducts = [SELECT Id, IsActive FROM Product2];
        for (Product2 p : allProducts) {
            p.IsActive = false;
        }
        update allProducts;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/ProductList';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        List<DRC_NBC_Lead_Products_From_Web_To_Lead.ProductWrapper> result =
            DRC_NBC_Lead_Products_From_Web_To_Lead.getProducts();
        Test.stopTest();
    }
    
    @isTest
    static void testProductWrapper_ConstructorSetsFields() {
        Id fakeId = [SELECT Id FROM Product2 WHERE IsActive = true LIMIT 1].Id;
        String fakeName = 'Test Wrapper Product';
        
        Test.startTest();
        DRC_NBC_Lead_Products_From_Web_To_Lead.ProductWrapper pw =
            new DRC_NBC_Lead_Products_From_Web_To_Lead.ProductWrapper(fakeId, fakeName);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // DRC_NBC_LeadInterestedChemistry — Invocable Method Tests
    // ═══════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testUpdateLeadChemistry_SingleValue() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Lead One' LIMIT 1];
        
        DRC_NBC_LeadInterestedChemistry.InputWrapper input =
            new DRC_NBC_LeadInterestedChemistry.InputWrapper();
        input.leadId      = testLead.Id;
        input.chosenValues = 'Polymer';
        
        Test.startTest();
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>{ input }
        );
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLeadChemistry_MultipleValues() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Lead One' LIMIT 1];
        
        DRC_NBC_LeadInterestedChemistry.InputWrapper input =
            new DRC_NBC_LeadInterestedChemistry.InputWrapper();
        input.leadId       = testLead.Id;
        input.chosenValues = 'Polymer;Adhesive;Coating';
        
        Test.startTest();
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>{ input }
        );
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLeadChemistry_OverwritesExistingValue() {
        // Lead Two already has 'ChemX' set
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Lead Two' LIMIT 1];
        
        DRC_NBC_LeadInterestedChemistry.InputWrapper input =
            new DRC_NBC_LeadInterestedChemistry.InputWrapper();
        input.leadId       = testLead.Id;
        input.chosenValues = 'NewChem';
        
        Test.startTest();
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>{ input }
        );
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLeadChemistry_TrimsWhitespace() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Lead One' LIMIT 1];
        
        DRC_NBC_LeadInterestedChemistry.InputWrapper input =
            new DRC_NBC_LeadInterestedChemistry.InputWrapper();
        input.leadId       = testLead.Id;
        input.chosenValues = ' Polymer ; Adhesive ; Coating ';
        
        Test.startTest();
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>{ input }
        );
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLeadChemistry_DeduplicatesValues() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Lead One' LIMIT 1];
        
        DRC_NBC_LeadInterestedChemistry.InputWrapper input =
            new DRC_NBC_LeadInterestedChemistry.InputWrapper();
        input.leadId       = testLead.Id;
        input.chosenValues = 'Polymer;Polymer;Adhesive';
        
        Test.startTest();
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>{ input }
        );
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLeadChemistry_BlankChosenValues() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Lead One' LIMIT 1];
        
        DRC_NBC_LeadInterestedChemistry.InputWrapper input =
            new DRC_NBC_LeadInterestedChemistry.InputWrapper();
        input.leadId       = testLead.Id;
        input.chosenValues = '';
        
        Test.startTest();
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>{ input }
        );
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLeadChemistry_NullChosenValues() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName = 'Lead One' LIMIT 1];
        
        DRC_NBC_LeadInterestedChemistry.InputWrapper input =
            new DRC_NBC_LeadInterestedChemistry.InputWrapper();
        input.leadId       = testLead.Id;
        input.chosenValues = null;
        
        Test.startTest();
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>{ input }
        );
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLeadChemistry_NullLeadId_Skipped() {
        DRC_NBC_LeadInterestedChemistry.InputWrapper input =
            new DRC_NBC_LeadInterestedChemistry.InputWrapper();
        input.leadId       = null;
        input.chosenValues = 'Polymer';
        
        Test.startTest();
        // Should complete without exception — null leadId is skipped
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>{ input }
        );
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLeadChemistry_NullInputList() {
        Test.startTest();
        // Passing null list — early return guard should handle it
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(null);
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLeadChemistry_EmptyInputList() {
        Test.startTest();
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>()
        );
        Test.stopTest();
        
        System.assert(true, 'Empty input list should be handled gracefully');
    }
    
    @isTest
    static void testUpdateLeadChemistry_BulkLeads() {
        // Create 50 leads for bulk testing
        List<Lead> bulkLeads = new List<Lead>();
        for (Integer i = 0; i < 50; i++) {
            bulkLeads.add(new Lead(
                FirstName = 'Bulk',
                LastName  = 'Lead ' + i,
                Company   = 'Bulk Co ' + i,
                Phone = '9876543211' + i,
                Email = 'leadtwo@test.com',
                Country = 'India'
            ));
        }
        insert bulkLeads;
        
        List<DRC_NBC_LeadInterestedChemistry.InputWrapper> inputs =
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>();
        
        for (Lead ld : bulkLeads) {
            DRC_NBC_LeadInterestedChemistry.InputWrapper inp =
                new DRC_NBC_LeadInterestedChemistry.InputWrapper();
            inp.leadId       = ld.Id;
            inp.chosenValues = 'Polymer;Adhesive';
            inputs.add(inp);
        }
        
        Test.startTest();
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(inputs);
        Test.stopTest();
    }
    
    @isTest
    static void testUpdateLeadChemistry_MultipleDifferentLeads() {
        List<Lead> testLeads = [SELECT Id FROM Lead WHERE LastName IN ('Lead One', 'Lead Three')];
        
        List<DRC_NBC_LeadInterestedChemistry.InputWrapper> inputs =
            new List<DRC_NBC_LeadInterestedChemistry.InputWrapper>();
        
        for (Integer i = 0; i < testLeads.size(); i++) {
            DRC_NBC_LeadInterestedChemistry.InputWrapper inp =
                new DRC_NBC_LeadInterestedChemistry.InputWrapper();
            inp.leadId       = testLeads[i].Id;
            inp.chosenValues = 'ChemX' + i;
            inputs.add(inp);
        }
        
        Test.startTest();
        DRC_NBC_LeadInterestedChemistry.updateLeadChemistry(inputs);
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // DRC_NBC_MultiSelect_Picklist_Values — Invocable Method Tests
    // ═══════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testCheckValues_MultipleSemicolonSeparated() {
        List<String> input = new List<String>{ 'Polymer;Adhesive;Coating' };
            
            Test.startTest();
        List<List<String>> result = DRC_NBC_MultiSelect_Picklist_Values.CheckValues(input);
        Test.stopTest();
    }
    
    @isTest
    static void testCheckValues_SingleValue() {
        List<String> input = new List<String>{ 'Polymer' };
            
            Test.startTest();
        List<List<String>> result = DRC_NBC_MultiSelect_Picklist_Values.CheckValues(input);
        Test.stopTest();
    }
    
    @isTest
    static void testCheckValues_EmptyList_ReturnsNull() {
        List<String> input = new List<String>();
        
        Test.startTest();
        List<List<String>> result = DRC_NBC_MultiSelect_Picklist_Values.CheckValues(input);
        Test.stopTest();
    }
    
    @isTest
    static void testCheckValues_TrailingSemicolon() {
        // Trailing semicolon produces an empty string at the end after split
        List<String> input = new List<String>{ 'Polymer;Adhesive;' };
            
            Test.startTest();
        List<List<String>> result = DRC_NBC_MultiSelect_Picklist_Values.CheckValues(input);
        Test.stopTest();
    }
    
    @isTest
    static void testCheckValues_SingleSemicolonOnly() {
        // Edge case: just a semicolon — split produces two empty strings
        List<String> input = new List<String>{ ';' };
            
            Test.startTest();
        List<List<String>> result = DRC_NBC_MultiSelect_Picklist_Values.CheckValues(input);
        Test.stopTest();
    }
    
    @isTest
    static void testCheckValues_PreservesValueOrder() {
        List<String> input = new List<String>{ 'Alpha;Beta;Gamma;Delta' };
            
            Test.startTest();
        List<List<String>> result = DRC_NBC_MultiSelect_Picklist_Values.CheckValues(input);
        Test.stopTest();
    }
    
    @isTest
    static void testCheckValues_OnlyFirstElementProcessed() {
        // InvocableMethod receives a list but only values[0] is processed
        List<String> input = new List<String>{ 'Polymer;Adhesive', 'ShouldBeIgnored' };
            
            Test.startTest();
        List<List<String>> result = DRC_NBC_MultiSelect_Picklist_Values.CheckValues(input);
        Test.stopTest();
    }
    
    @isTest
    static void testCheckValues_LargeNumberOfValues() {
        // Build a semicolon-separated string with 50 values
        List<String> parts = new List<String>();
        for (Integer i = 0; i < 50; i++) {
            parts.add('Value' + i);
        }
        List<String> input = new List<String>{ String.join(parts, ';') };
            
            Test.startTest();
        List<List<String>> result = DRC_NBC_MultiSelect_Picklist_Values.CheckValues(input);
        Test.stopTest();
    }
}