@isTest
private class DRC_NBC_GeneratePdf_Controllers_Test {
    
    // ─── Test Data Setup ──────────────────────────────────────────────────────
    
    @testSetup
    static void setupTestData() {
        // Account
        Account acc = new Account(
            Name              = 'Test Account',
            BillingStreet     = '123 Test St',
            BillingCity       = 'Mumbai',
            BillingState      = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry    = 'India'
        );
        insert acc;
        
        // Opportunity (needed for Quote)
        Opportunity opp = new Opportunity(
            Name      = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        
        // Domestic Order (no sequence yet)
        Order domesticOrd = new Order(
            AccountId         = acc.Id,
            Status            = 'Draft',
            EffectiveDate     = Date.today(),
            DRC_NBC_Type__c   = 'Domestic'
        );
        insert domesticOrd;
        
        // Export Order (no sequence yet)
        Order exportOrd = new Order(
            AccountId         = acc.Id,
            Status            = 'Draft',
            EffectiveDate     = Date.today(),
            DRC_NBC_Type__c   = 'Export'
        );
        insert exportOrd;
        
        // Sample Order (no sequence yet)
        Order sampleOrd = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Type          = 'Sample order'
        );
        insert sampleOrd;
        
        // Domestic Order with existing sequence
        Order domesticWithSeq = new Order(
            AccountId                          = acc.Id,
            Status                             = 'Draft',
            EffectiveDate                      = Date.today(),
            DRC_NBC_Type__c                    = 'Domestic',
            DRC_NBC_Import_Starting_Sequence__c = 10
        );
        insert domesticWithSeq;
        
        // Export Order with existing sequence
        Order exportWithSeq = new Order(
            AccountId                                 = acc.Id,
            Status                                    = 'Draft',
            EffectiveDate                             = Date.today(),
            DRC_NBC_Type__c                           = 'Export',
            DRC_NBC_Invoice_Export_Sequence_Number__c = 20
        );
        insert exportWithSeq;
        
        // Sample Order with existing sequence
        Order sampleWithSeq = new Order(
            AccountId                      = acc.Id,
            Status                         = 'Draft',
            EffectiveDate                  = Date.today(),
            Type                           = 'Sample order',
            DRC_NBC_Sample_Sequence_Number__c = 5
        );
        insert sampleWithSeq;
        
        // Quote — Domestic (no sequence)
        Quote domesticQuote = new Quote(
            Name           = 'Test Domestic Quote',
            OpportunityId  = opp.Id,
            DRC_NBC_Type__c = 'Domestic',
            Status         = 'Draft'
        );
        insert domesticQuote;
        
        // Quote — Export (no sequence)
        Quote exportQuote = new Quote(
            Name           = 'Test Export Quote',
            OpportunityId  = opp.Id,
            DRC_NBC_Type__c = 'Export',
            Status         = 'Draft'
        );
        insert exportQuote;
        
        // Quote — Domestic with existing sequence
        Quote domesticQuoteWithSeq = new Quote(
            Name                               = 'Domestic Quote With Seq',
            OpportunityId                      = opp.Id,
            DRC_NBC_Type__c                    = 'Domestic',
            Status                             = 'Draft',
            DRC_NBC_Import_Starting_Sequence__c = 15
        );
        insert domesticQuoteWithSeq;
        
        // Quote — Export with existing sequence
        Quote exportQuoteWithSeq = new Quote(
            Name                                     = 'Export Quote With Seq',
            OpportunityId                            = opp.Id,
            DRC_NBC_Type__c                          = 'Export',
            Status                                   = 'Draft',
            DRC_NBC_Invoice_Export_Sequence_Number__c = 25
        );
        insert exportQuoteWithSeq;
        
        // Quote — no type (no sequence assigned)
        Quote noTypeQuote = new Quote(
            Name          = 'No Type Quote',
            OpportunityId = opp.Id,
            Status        = 'Draft',
            DRC_NBC_Type__c = 'Domestic'
        );
        insert noTypeQuote;
    }
    
    // ─── Helpers ──────────────────────────────────────────────────────────────
    
    private static Order getOrder(String type, Boolean withSequence) {
        if (type == 'Domestic') {
            return withSequence
                ? [SELECT Id, Name, DRC_NBC_Type__c, DRC_NBC_Import_Starting_Sequence__c,
                   DRC_NBC_Invoice_Export_Sequence_Number__c, Account.Name
                   FROM Order WHERE DRC_NBC_Type__c = 'Domestic'
                   AND DRC_NBC_Import_Starting_Sequence__c != null LIMIT 1]
                : [SELECT Id, Name, DRC_NBC_Type__c, DRC_NBC_Import_Starting_Sequence__c,
                   DRC_NBC_Invoice_Export_Sequence_Number__c, Account.Name
                   FROM Order WHERE DRC_NBC_Type__c = 'Domestic'
                   AND DRC_NBC_Import_Starting_Sequence__c = null LIMIT 1];
                       } else if (type == 'Export') {
                           return withSequence
                               ? [SELECT Id, Name, DRC_NBC_Type__c, DRC_NBC_Import_Starting_Sequence__c,
                                  DRC_NBC_Invoice_Export_Sequence_Number__c, Account.Name
                                  FROM Order WHERE DRC_NBC_Type__c = 'Export'
                                  AND DRC_NBC_Invoice_Export_Sequence_Number__c != null LIMIT 1]
                               : [SELECT Id, Name, DRC_NBC_Type__c, DRC_NBC_Import_Starting_Sequence__c,
                                  DRC_NBC_Invoice_Export_Sequence_Number__c, Account.Name
                                  FROM Order WHERE DRC_NBC_Type__c = 'Export'
                                  AND DRC_NBC_Invoice_Export_Sequence_Number__c = null LIMIT 1];
                                      } else {
                                          return withSequence
                                              ? [SELECT Id, Name, Type, DRC_NBC_Sample_Sequence_Number__c, Account.Name
                                                 FROM Order WHERE Type = 'Sample order'
                                                 AND DRC_NBC_Sample_Sequence_Number__c != null LIMIT 1]
                                              : [SELECT Id, Name, Type, DRC_NBC_Sample_Sequence_Number__c, Account.Name
                                                 FROM Order WHERE Type = 'Sample order'
                                                 AND DRC_NBC_Sample_Sequence_Number__c = null LIMIT 1];
                                                     }
    }
    
    private static Quote getQuote(String type, Boolean withSequence) {
        if (type == 'Domestic') {
            return withSequence
                ? [SELECT Id, Name, QuoteNumber, Account.Name, DRC_NBC_Type__c,
                   DRC_NBC_Import_Starting_Sequence__c, Opportunity.Account.Name,
                   DRC_NBC_Invoice_Export_Sequence_Number__c, DRC_NBC_Special_Requirements__c
                   FROM Quote WHERE DRC_NBC_Type__c = 'Domestic'
                   AND DRC_NBC_Import_Starting_Sequence__c != null LIMIT 1]
                : [SELECT Id, Name, QuoteNumber, Account.Name, DRC_NBC_Type__c,
                   DRC_NBC_Import_Starting_Sequence__c, Opportunity.Account.Name,
                   DRC_NBC_Invoice_Export_Sequence_Number__c, DRC_NBC_Special_Requirements__c
                   FROM Quote WHERE DRC_NBC_Type__c = 'Domestic'
                   AND DRC_NBC_Import_Starting_Sequence__c = null LIMIT 1];
                       } else if (type == 'Export') {
                           return withSequence
                               ? [SELECT Id, Name, QuoteNumber, Account.Name, DRC_NBC_Type__c,
                                  DRC_NBC_Import_Starting_Sequence__c, Opportunity.Account.Name,
                                  DRC_NBC_Invoice_Export_Sequence_Number__c, DRC_NBC_Special_Requirements__c
                                  FROM Quote WHERE DRC_NBC_Type__c = 'Export'
                                  AND DRC_NBC_Invoice_Export_Sequence_Number__c != null LIMIT 1]
                               : [SELECT Id, Name, QuoteNumber, Account.Name, DRC_NBC_Type__c,
                                  DRC_NBC_Import_Starting_Sequence__c, Opportunity.Account.Name,
                                  DRC_NBC_Invoice_Export_Sequence_Number__c, DRC_NBC_Special_Requirements__c
                                  FROM Quote WHERE DRC_NBC_Type__c = 'Export'
                                  AND DRC_NBC_Invoice_Export_Sequence_Number__c = null LIMIT 1];
                                      } else {
                                          return [SELECT Id, Name, QuoteNumber, Account.Name, DRC_NBC_Type__c,
                                                  DRC_NBC_Import_Starting_Sequence__c, Opportunity.Account.Name,
                                                  DRC_NBC_Invoice_Export_Sequence_Number__c, DRC_NBC_Special_Requirements__c
                                                  FROM Quote WHERE DRC_NBC_Type__c = null LIMIT 1];
                                      }
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // DRC_NBC_GeneratePdfController Tests
    // ══════════════════════════════════════════════════════════════════════════
    
    // ─── saveOrderPdfToContent ────────────────────────────────────────────────
    
    /**
* Covers: Domestic order → PDF saved to ContentVersion
*         → assignOrderSequenceNumber called → sequence assigned
*/
    @isTest
    static void test_saveOrderPdfToContent_DomesticOrder() {
        Order ord = getOrder('Domestic', false);
        
        Test.startTest();
        DRC_NBC_GeneratePdfController.saveOrderPdfToContent(ord.Id, '/apex/TestPage');
        Test.stopTest();
        
        List<ContentVersion> cvs = [SELECT Id, Title FROM ContentVersion
                                    WHERE FirstPublishLocationId = :ord.Id];
        Boolean cvCreated = cvs.size() >= 1;
        if (!cvCreated) {
            throw new IllegalArgumentException('ContentVersion should have been created for domestic order');
        }
        
        Order updated = [SELECT DRC_NBC_Import_Starting_Sequence__c FROM Order WHERE Id = :ord.Id];
        if (updated.DRC_NBC_Import_Starting_Sequence__c == null) {
            throw new IllegalArgumentException('Domestic sequence number should have been assigned');
        }
    }
    
    /**
* Covers: Export order → PDF saved → export sequence assigned
*/
    @isTest
    static void test_saveOrderPdfToContent_ExportOrder() {
        Order ord = getOrder('Export', false);
        
        Test.startTest();
        DRC_NBC_GeneratePdfController.saveOrderPdfToContent(ord.Id, '/apex/TestPage');
        Test.stopTest();
        
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion
                                    WHERE FirstPublishLocationId = :ord.Id];
        if (cvs.isEmpty()) {
            throw new IllegalArgumentException('ContentVersion should have been created for export order');
        }
        
        Order updated = [SELECT DRC_NBC_Invoice_Export_Sequence_Number__c FROM Order WHERE Id = :ord.Id];
        if (updated.DRC_NBC_Invoice_Export_Sequence_Number__c == null) {
            throw new IllegalArgumentException('Export sequence number should have been assigned');
        }
    }
    
    /**
* Covers: Domestic order with NO existing sequence → MAX query returns null
*         → falls back to Label value → assigns label + 1
*/
    @isTest
    static void test_assignOrderSequenceNumber_Domestic_NoExistingSequence() {
        // Use a fresh domestic order with no sequence
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order freshOrd = new Order(
            AccountId       = acc.Id,
            Status          = 'Draft',
            EffectiveDate   = Date.today(),
            DRC_NBC_Type__c = 'Domestic'
        );
        insert freshOrd;
        
        Order ordForMethod = [
            SELECT Id, Name, DRC_NBC_Type__c,
            DRC_NBC_Import_Starting_Sequence__c,
            DRC_NBC_Invoice_Export_Sequence_Number__c,
            Account.Name
            FROM Order WHERE Id = :freshOrd.Id
        ];
        
        Test.startTest();
        DRC_NBC_GeneratePdfController.assignOrderSequenceNumber(ordForMethod);
        Test.stopTest();
        
        Order updated = [SELECT DRC_NBC_Import_Starting_Sequence__c FROM Order WHERE Id = :freshOrd.Id];
        if (updated.DRC_NBC_Import_Starting_Sequence__c == null) {
            throw new IllegalArgumentException('Sequence number should have been assigned');
        }
    }
    
    /**
* Covers: Domestic order already has sequence → shouldUpdateOrder = false → no update
*/
    @isTest
    static void test_assignOrderSequenceNumber_Domestic_AlreadyHasSequence() {
        Order ord = getOrder('Domestic', true);
        Decimal originalSeq = ord.DRC_NBC_Import_Starting_Sequence__c;
        
        Test.startTest();
        DRC_NBC_GeneratePdfController.assignOrderSequenceNumber(ord);
        Test.stopTest();
        
        Order updated = [SELECT DRC_NBC_Import_Starting_Sequence__c FROM Order WHERE Id = :ord.Id];
        if (updated.DRC_NBC_Import_Starting_Sequence__c != originalSeq) {
            throw new IllegalArgumentException(
                'Sequence should NOT change when already set. Expected: '
                + originalSeq + ' Got: ' + updated.DRC_NBC_Import_Starting_Sequence__c
            );
        }
    }
    
    /**
* Covers: Export order with NO existing sequence → MAX returns null
*         → falls back to Label → assigns label + 1
*/
    @isTest
    static void test_assignOrderSequenceNumber_Export_NoExistingSequence() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order freshOrd = new Order(
            AccountId       = acc.Id,
            Status          = 'Draft',
            EffectiveDate   = Date.today(),
            DRC_NBC_Type__c = 'Export'
        );
        insert freshOrd;
        
        Order ordForMethod = [
            SELECT Id, Name, DRC_NBC_Type__c,
            DRC_NBC_Import_Starting_Sequence__c,
            DRC_NBC_Invoice_Export_Sequence_Number__c,
            Account.Name
            FROM Order WHERE Id = :freshOrd.Id
        ];
        
        Test.startTest();
        DRC_NBC_GeneratePdfController.assignOrderSequenceNumber(ordForMethod);
        Test.stopTest();
        
        Order updated = [SELECT DRC_NBC_Invoice_Export_Sequence_Number__c FROM Order WHERE Id = :freshOrd.Id];
        if (updated.DRC_NBC_Invoice_Export_Sequence_Number__c == null) {
            throw new IllegalArgumentException('Export sequence should have been assigned');
        }
    }
    
    /**
* Covers: Export order already has sequence → no update
*/
    @isTest
    static void test_assignOrderSequenceNumber_Export_AlreadyHasSequence() {
        Order ord = getOrder('Export', true);
        Decimal originalSeq = ord.DRC_NBC_Invoice_Export_Sequence_Number__c;
        
        Test.startTest();
        DRC_NBC_GeneratePdfController.assignOrderSequenceNumber(ord);
        Test.stopTest();
        
        Order updated = [SELECT DRC_NBC_Invoice_Export_Sequence_Number__c FROM Order WHERE Id = :ord.Id];
        if (updated.DRC_NBC_Invoice_Export_Sequence_Number__c != originalSeq) {
            throw new IllegalArgumentException(
                'Export sequence should NOT change when already set. Expected: '
                + originalSeq + ' Got: ' + updated.DRC_NBC_Invoice_Export_Sequence_Number__c
            );
        }
    }
    
    // ─── saveSampleOrderPdfToContent ──────────────────────────────────────────
    
    /**
* Covers: Sample order → PDF saved → sample sequence assigned
*/
    @isTest
    static void test_saveSampleOrderPdfToContent_SampleOrder() {
        Order ord = getOrder('Sample', false);
        
        Test.startTest();
        DRC_NBC_GeneratePdfController.saveSampleOrderPdfToContent(ord.Id, '/apex/TestSamplePage');
        Test.stopTest();
        
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion
                                    WHERE FirstPublishLocationId = :ord.Id];
        if (cvs.isEmpty()) {
            throw new IllegalArgumentException('ContentVersion should have been created for sample order');
        }
        
        Order updated = [SELECT DRC_NBC_Sample_Sequence_Number__c FROM Order WHERE Id = :ord.Id];
        if (updated.DRC_NBC_Sample_Sequence_Number__c == null) {
            throw new IllegalArgumentException('Sample sequence number should have been assigned');
        }
    }
    
    /**
* Covers: Sample order with no sequence → MAX null → falls back to label → assigns label+1
*/
    @isTest
    static void test_assignOrderSequenceNumberSample_NoExisting() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order freshOrd = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today(),
            Type          = 'Sample order'
        );
        insert freshOrd;
        
        Order ordForMethod = [
            SELECT Id, Name, Type, DRC_NBC_Sample_Sequence_Number__c, Account.Name
            FROM Order WHERE Id = :freshOrd.Id
        ];
        
        Test.startTest();
        DRC_NBC_GeneratePdfController.assignOrderSequenceNumberSample(ordForMethod);
        Test.stopTest();
        
        Order updated = [SELECT DRC_NBC_Sample_Sequence_Number__c FROM Order WHERE Id = :freshOrd.Id];
        if (updated.DRC_NBC_Sample_Sequence_Number__c == null) {
            throw new IllegalArgumentException('Sample sequence should have been assigned');
        }
    }
    
    /**
* Covers: Sample order already has sequence → no update
*/
    @isTest
    static void test_assignOrderSequenceNumberSample_AlreadyHasSequence() {
        Order ord = getOrder('Sample', true);
        Decimal originalSeq = ord.DRC_NBC_Sample_Sequence_Number__c;
        
        Test.startTest();
        DRC_NBC_GeneratePdfController.assignOrderSequenceNumberSample(ord);
        Test.stopTest();
        
        Order updated = [SELECT DRC_NBC_Sample_Sequence_Number__c FROM Order WHERE Id = :ord.Id];
        if (updated.DRC_NBC_Sample_Sequence_Number__c != originalSeq) {
            throw new IllegalArgumentException(
                'Sample sequence should NOT change when already set. Expected: '
                + originalSeq + ' Got: ' + updated.DRC_NBC_Sample_Sequence_Number__c
            );
        }
    }
    
    /**
* Covers: Non-sample order type → shouldUpdateOrder = false
*/
    @isTest
    static void test_assignOrderSequenceNumberSample_NonSampleType() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Order ord = new Order(
            AccountId     = acc.Id,
            Status        = 'Draft',
            EffectiveDate = Date.today()
            // Type intentionally null
        );
        insert ord;
        
        Order ordForMethod = [
            SELECT Id, Name, Type, DRC_NBC_Sample_Sequence_Number__c, Account.Name
            FROM Order WHERE Id = :ord.Id
        ];
        
        Test.startTest();
        DRC_NBC_GeneratePdfController.assignOrderSequenceNumberSample(ordForMethod);
        Test.stopTest();
        
        Order updated = [SELECT DRC_NBC_Sample_Sequence_Number__c FROM Order WHERE Id = :ord.Id];
        if (updated.DRC_NBC_Sample_Sequence_Number__c != null) {
            throw new IllegalArgumentException('Sequence should NOT be assigned for non-sample order type');
        }
    }
    
    // ══════════════════════════════════════════════════════════════════════════
    // DRC_NBC_GenerateQuotePdfController Tests
    // ══════════════════════════════════════════════════════════════════════════
    
    // ─── saveQuotePdfToContent ────────────────────────────────────────────────
    
    /**
* Covers: Domestic Quote → PDF saved to ContentVersion → sequence assigned
*/
    @isTest
    static void test_saveQuotePdfToContent_DomesticQuote() {
        Quote q = getQuote('Domestic', false);
        
        Test.startTest();
        DRC_NBC_GenerateQuotePdfController.saveQuotePdfToContent(q.Id, '/apex/TestQuotePage');
        Test.stopTest();
        
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion
                                    WHERE FirstPublishLocationId = :q.Id];
        if (cvs.isEmpty()) {
            throw new IllegalArgumentException('ContentVersion should be created for domestic quote');
        }
        
        Quote updated = [SELECT DRC_NBC_Import_Starting_Sequence__c FROM Quote WHERE Id = :q.Id];
        if (updated.DRC_NBC_Import_Starting_Sequence__c == null) {
            throw new IllegalArgumentException('Domestic quote sequence should have been assigned');
        }
    }
    
    /**
* Covers: Export Quote → PDF saved → export sequence assigned
*/
    @isTest
    static void test_saveQuotePdfToContent_ExportQuote() {
        Quote q = getQuote('Export', false);
        
        Test.startTest();
        DRC_NBC_GenerateQuotePdfController.saveQuotePdfToContent(q.Id, '/apex/TestQuotePage');
        Test.stopTest();
        
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion
                                    WHERE FirstPublishLocationId = :q.Id];
        if (cvs.isEmpty()) {
            throw new IllegalArgumentException('ContentVersion should be created for export quote');
        }
        
        Quote updated = [SELECT DRC_NBC_Invoice_Export_Sequence_Number__c FROM Quote WHERE Id = :q.Id];
        if (updated.DRC_NBC_Invoice_Export_Sequence_Number__c == null) {
            throw new IllegalArgumentException('Export quote sequence should have been assigned');
        }
    }
    
    /**
* Covers: Domestic quote already has sequence → no update to sequence
*/
    @isTest
    static void test_saveQuotePdfToContent_DomesticQuote_AlreadyHasSequence() {
        Quote q = getQuote('Domestic', true);
        Decimal originalSeq = q.DRC_NBC_Import_Starting_Sequence__c;
        
        Test.startTest();
        DRC_NBC_GenerateQuotePdfController.saveQuotePdfToContent(q.Id, '/apex/TestQuotePage');
        Test.stopTest();
        
        Quote updated = [SELECT DRC_NBC_Import_Starting_Sequence__c FROM Quote WHERE Id = :q.Id];
        if (updated.DRC_NBC_Import_Starting_Sequence__c != originalSeq) {
            throw new IllegalArgumentException(
                'Domestic sequence should NOT change when already set. Expected: '
                + originalSeq + ' Got: ' + updated.DRC_NBC_Import_Starting_Sequence__c
            );
        }
    }
    
    /**
* Covers: Export quote already has sequence → no update to sequence
*/
    @isTest
    static void test_saveQuotePdfToContent_ExportQuote_AlreadyHasSequence() {
        Quote q = getQuote('Export', true);
        Decimal originalSeq = q.DRC_NBC_Invoice_Export_Sequence_Number__c;
        
        Test.startTest();
        DRC_NBC_GenerateQuotePdfController.saveQuotePdfToContent(q.Id, '/apex/TestQuotePage');
        Test.stopTest();
        
        Quote updated = [SELECT DRC_NBC_Invoice_Export_Sequence_Number__c FROM Quote WHERE Id = :q.Id];
        if (updated.DRC_NBC_Invoice_Export_Sequence_Number__c != originalSeq) {
            throw new IllegalArgumentException(
                'Export sequence should NOT change when already set. Expected: '
                + originalSeq + ' Got: ' + updated.DRC_NBC_Invoice_Export_Sequence_Number__c
            );
        }
    }
    
    /**
* Covers: Export MAX aggregate returns existing value → next = max + 1
*/
    @isTest
    static void test_saveQuotePdfToContent_Export_MaxFromExisting() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // Insert a new export quote with no sequence
        Quote newExportQuote = new Quote(
            Name            = 'New Export Quote',
            OpportunityId   = opp.Id,
            DRC_NBC_Type__c = 'Export',
            Status          = 'Draft'
        );
        insert newExportQuote;
        
        Test.startTest();
        DRC_NBC_GenerateQuotePdfController.saveQuotePdfToContent(newExportQuote.Id, '/apex/TestQuotePage');
        Test.stopTest();
    }
}