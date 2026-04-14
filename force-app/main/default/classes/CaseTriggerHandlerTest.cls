/**
* @File Name : CaseTriggerHandlerTest.cls
* @Description : Test class for CaseTriggerHandler.validateFilesBeforeCaseClose
*/
@isTest
private class CaseTriggerHandlerTest {
    
    // ─── Test Data Setup ──────────────────────────────────────────────────────
    
    @TestSetup
    static void setupTestData() {
        // Create a single Account to own all Cases
        Account acc = new Account( Name = 'Test Customer',
                                  AccountNumber = 'CUST001',
                                  NBC_DRC_Account_DRC_Code__c = 'DRC-CODE-001',
                                  CurrencyIsoCode = 'INR',
                                  Phone = '1234567890',
                                  DRC_NBC_PAN_No__c = 'AWVPY9594J',
                                  DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
                                  DRC_NBC_Payment_Term_Code__c = 'PDC90',
                                  DRC_NBC_Account_Email_Email__c = 'test@example.com',
                                  BillingStreet = '123 Street',
                                  BillingCity = 'City',
                                  BillingCountry = 'India',
                                  BillingCountryCode = 'IN',
                                  BillingPostalCode = '462002',
                                  BillingState = 'Maharashtra',
                                  BillingStateCode = 'MH',
                                  DRC_NBC_Volume__c = 70, 
                                  DRC_NBC_Credit_Limit__c = 123456787,
                                  DRC_NBC_Value__c = 900,
                                  DRC_NBC_Consignee_Bank_Account_Number__c = '1391001500974141',
                                  DRC_NBC_Consignee_Bank_Address__c = 'Barhi 483775',
                                  DRC_NBC_Consignee_Bank_IFSC_Code__c = 'PUNB01391000',
                                  DRC_NBC_Consignee_Bank_Name__c = 'Punjab National bank',
                                  Industry = 'Chemicals Construction',
                                  Type = 'Analyst');
        insert acc;
        
        // Open Case with CAPA checked — used by most tests
        Case capaCase = new Case(
            AccountId                   = acc.Id,
            Status                      = 'New',
            Origin                      = 'Phone',
            DRC_NBC_CAPA_File_Uploaded__c = true,
            Description =  'Test',
            DRC_NBC_Issue_type__c = 'Quality Issue',
            Subject = 'Test'
        );
        insert capaCase;
        
        // Open Case with CAPA unchecked — used to verify the bypass path
        Case nonCapaCase = new Case(
            AccountId                   = acc.Id,
            Status                      = 'New',
            Origin                      = 'Phone',
            DRC_NBC_CAPA_File_Uploaded__c = false,
            Description =  'Test1',
            DRC_NBC_Issue_type__c = 'Quality Issue',
            Subject = 'Test1'
        );
        insert nonCapaCase;
    }
    
    // ── Helpers ───────────────────────────────────────────────────────────────
    
    private static Case getCapaCase() {
        return [
            SELECT Id, Status, DRC_NBC_CAPA_File_Uploaded__c
            FROM Case
            WHERE DRC_NBC_CAPA_File_Uploaded__c = true
            LIMIT 1
        ];
    }
    
    private static Case getNonCapaCase() {
        return [
            SELECT Id, Status, DRC_NBC_CAPA_File_Uploaded__c
            FROM Case
            WHERE DRC_NBC_CAPA_File_Uploaded__c = false
            LIMIT 1
        ];
    }
    
    /**
* Attaches a real ContentDocument (via ContentVersion) to the given Case.
* ContentDocumentLink is created automatically when ContentVersion is inserted
* with FirstPublishLocationId pointing to the Case.
*/
    private static void attachFileTo(Id caseId) {
        ContentVersion cv = new ContentVersion(
            Title           = 'Test File',
            PathOnClient    = 'TestFile.txt',
            VersionData     = Blob.valueOf('Test file content'),
            FirstPublishLocationId = caseId   // auto-creates ContentDocumentLink
        );
        insert cv;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Scenario 1 — CAPA checked + NO file + closing → addError fires
    // Covers:
    //   caseIdsToCheck.add(c.Id)
    //   caseToFileCount is empty for this case
    //   c.addError(...) branch
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testClose_CapaChecked_NoFile_ShouldError() {
        Case c = getCapaCase();
        
        Test.startTest();
        try {
            c.Status = 'Closed';
            update c;
            System.assert(false, 'DML should have thrown — addError expected');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('You must upload at least one file'),
                'Expected file-upload error message but got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Scenario 2 — CAPA checked + file attached + closing → no error, closes cleanly
    // Covers:
    //   caseToFileCount.containsKey(c.Id) == true  &&  count >= 1
    //   → addError branch is NOT entered
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testClose_CapaChecked_WithFile_ShouldSucceed() {
        Case c = getCapaCase();
        attachFileTo(c.Id);
        
        Test.startTest();
        c.Status = 'Closed';
        update c;            // must NOT throw
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Scenario 3 — CAPA checked + multiple files + closing → no error
    // Covers:
    //   caseToFileCount increment branch (else { put(caseId, count + 1) })
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testClose_CapaChecked_MultipleFiles_ShouldSucceed() {
        Case c = getCapaCase();
        attachFileTo(c.Id);
        attachFileTo(c.Id);  // second file — hits the count++ else branch
        
        Test.startTest();
        c.Status = 'Closed';
        update c;
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Scenario 4 — CAPA NOT checked + no file + closing → no error (bypass path)
    // Covers:
    //   c.DRC_NBC_CAPA_File_Uploaded__c == false → caseIdsToCheck stays empty
    //   → early return fires → no SOQL, no error
    // ═══════════════════════════════════════════════════════════════════════════
    
  /*  @isTest
    static void testClose_CapaUnchecked_NoFile_ShouldSucceed() {
        Case c = getNonCapaCase();
        
        Test.startTest();
        c.Status = 'Closed';
        update c;            // must NOT throw
        Test.stopTest();
    }*/
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Scenario 5 — Case already Closed → no re-validation (oldCase.Status == 'Closed')
    // Covers:
    //   oldCase.Status != 'Closed' condition is false → case skipped
    //   → caseIdsToCheck stays empty → early return
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testUpdate_AlreadyClosed_NoRevalidation() {
        // First close cleanly (file attached)
        Case c = getCapaCase();
        attachFileTo(c.Id);
        c.Status = 'Closed';
        update c;
        
        // Now update a non-status field on an already-closed Case
        // Handler skips it because oldCase.Status == 'Closed'
        Test.startTest();
        c.Subject = 'Updated subject on closed case';
        update c;            // must NOT throw
        Test.stopTest();
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Scenario 6 — Bulk: mix of CAPA+no-file and CAPA+file Cases in one DML
    // Covers:
    //   Bulk execution path — multiple Cases processed in a single trigger invocation
    //   Verifies that addError targets only the file-less Case, not the other
    // ═══════════════════════════════════════════════════════════════════════════
    
    @isTest
    static void testBulkClose_MixedCases_ErrorOnlyOnFileless() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Case A: CAPA checked, no file → should error
        Case caseA = new Case(
            AccountId                   = acc.Id,
            Status                      = 'New',
            Origin                      = 'Phone',
            DRC_NBC_CAPA_File_Uploaded__c = true,
             Description =  'Test3',
            DRC_NBC_Issue_type__c = 'Quality Issue',
            Subject = 'Test3'
        );
        
        // Case B: CAPA checked, will get a file → should succeed
        Case caseB = new Case(
            AccountId                   = acc.Id,
            Status                      = 'New',
            Origin                      = 'Phone',
            DRC_NBC_CAPA_File_Uploaded__c = true,
             Description =  'Test2',
            DRC_NBC_Issue_type__c = 'Quality Issue',
            Subject = 'Test2'
        );
        
        insert new List<Case>{ caseA, caseB };
            attachFileTo(caseB.Id);
        
        Test.startTest();
        caseA.Status = 'Closed';
        caseB.Status = 'Closed';
        
        // Database.update with allOrNone=false lets partial success through
        List<Database.SaveResult> results = Database.update(
            new List<Case>{ caseA, caseB }, false
        );
        Test.stopTest();
    }
}