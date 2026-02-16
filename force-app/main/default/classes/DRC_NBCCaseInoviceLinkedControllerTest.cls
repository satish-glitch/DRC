@IsTest
private class DRC_NBCCaseInoviceLinkedControllerTest {
    
    @TestSetup
    static void setupData() {
        
        // Account
        Account acc = new Account(
            Name = 'Test Account'
        );
        insert acc;
        
        // Contact
        Contact con = new Contact(
            LastName = 'Test Contact',
            Email = 'test@test.com',
            Phone = '9999999999',
            AccountId = acc.Id
        );
        insert con;
        
        // Invoice
        DRC_NBC_Invoice__c inv = new DRC_NBC_Invoice__c(
            // Name = 'INV-001',
            DRC_NBC_Invoice_Number__c = 'INV-001',
            DRC_NBC_Account__c = acc.Id
        );
        insert inv;
        
        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'FG001',
            IsActive = true
        );
        insert prod;
        
        // Invoice Line Item
        DRC_NBC_Invoice_Line_Item__c ili = new DRC_NBC_Invoice_Line_Item__c(
            DRC_NBC_Invoice_Number__c = inv.Id,
            DRC_NBC_Product__c = prod.Id,
            DRC_NBC_Product_Code__c = 'FG001',
            DRC_NBC_Amount__c = 1000
        );
        insert ili;
        
        // Invoice Lot
        DRC_NBC_Invoice_Lot__c lot = new DRC_NBC_Invoice_Lot__c(
            DRC_NBC_Invoice_Line_Item__c = ili.Id,
            DRC_NBC_Lot_Number__c = 'LOT-001',
            DRC_NBC_Lot_Quantity__c = '100',
            DRC_NBC_Invoice__c = inv.Id
        );
        insert lot;
    }
    
    @IsTest
    static void testGetAvailableInvoices() {
        Test.startTest();
        List<DRC_NBC_Invoice__c> invoices =
            DRC_NBCCaseInoviceLinkedController.getAvailableInvoices();
        Test.stopTest();
        
        System.assert(!invoices.isEmpty());
    }
    
    @IsTest
    static void testSearchMethods() {
        Test.startTest();
        List<Account> accs =
            DRC_NBCCaseInoviceLinkedController.searchAccounts('Test');
        List<Contact> cons =
            DRC_NBCCaseInoviceLinkedController.searchContacts('Test', accs[0].Id);
        Test.stopTest();
        
        System.assert(!accs.isEmpty());
        System.assert(!cons.isEmpty());
    }
    
    @IsTest
    static void testGetCaseDetails_NewAndExisting() {
        // Create required Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Case c = new Case(
            Subject = 'Test Case',
            Status = 'New',
            Description = 'Description',
            DRC_NBC_Issue_type__c = 'Late Delivery',
            AccountId = acc.Id 
        );
        insert c;
        
        Test.startTest();
        Case newCase = DRC_NBCCaseInoviceLinkedController.getCaseDetails(null);
        Case existingCase = DRC_NBCCaseInoviceLinkedController.getCaseDetails(c.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, existingCase.Id);
    }
    
    
    @IsTest
    static void testSaveCase_CreateAndUpdate() {
        // Account
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        // Contact (optional if validation requires)
        Contact con = new Contact(LastName = 'Test', Email = 'test@example.com', AccountId = acc.Id);
        insert con;
        
        // Product
        Product2 prod = new Product2(Name = 'Test Product', ProductCode = 'FG001', IsActive = true);
        insert prod;
        
        // Invoice
        DRC_NBC_Invoice__c inv = new DRC_NBC_Invoice__c(
            //   Name = 'INV-TEST',
            DRC_NBC_Invoice_Number__c = 'INV-TEST',
            DRC_NBC_Account__c = acc.Id
        );
        insert inv;
        
        // Line Item
        DRC_NBC_Invoice_Line_Item__c ili = new DRC_NBC_Invoice_Line_Item__c(
            DRC_NBC_Invoice_Number__c = inv.Id,
            DRC_NBC_Product__c = prod.Id,
            DRC_NBC_Product_Code__c = 'FG001',
            DRC_NBC_Amount__c = 100
        );
        insert ili;
        
        // Lot
        DRC_NBC_Invoice_Lot__c lot = new DRC_NBC_Invoice_Lot__c(
            DRC_NBC_Invoice_Line_Item__c = ili.Id,
            DRC_NBC_Lot_Number__c = 'LOT-001',
            DRC_NBC_Lot_Quantity__c = '100',
            DRC_NBC_Invoice__c = inv.Id
        );
        insert lot;
        
        // Case JSON
        Map<String, Object> caseData = new Map<String, Object>{
            'Subject' => 'Test',
                'Status' => 'New',
                'IsEscalated' => false,
                'Origin' => 'Phone',
                'Priority' => 'Medium',
                'Description' => 'Testing',
                'DRC_NBC_Issue_type__c' => 'Quality',
                'DRC_NBC_Action_Inititated_By_DRC__c' => 'No',
                'DRC_NBCPreferred_Resolution_to_Customers__c' => 'Replacement',
                'AccountId' => acc.Id,
                'ContactId' => con.Id
                };
                    
                    List<Object> selectedLots = new List<Object>{
                        new Map<String, Object>{
                            'lotId' => lot.Id,
                                'lotNumber' => 'LOT-001',
                                'productName' => 'Test Product',
                                'productCode' => 'FG001',
                                'quantity' => 100,
                                'complaintQuantity' => 5
                                }
                    };
                        
                        String caseJson = JSON.serialize(caseData);
        String lotJson = JSON.serialize(selectedLots);
        
        // Create Case
        Test.startTest();
        Map<String, Object> resultCreate = DRC_NBCCaseInoviceLinkedController.saveCase(null, caseJson, inv.Id, lotJson);
        Test.stopTest();
        
        System.assertEquals(true, resultCreate.get('success'));
        
        Id caseId = (Id) resultCreate.get('caseId');
        System.debug('Created Case ID: ' + caseId);
        
        // Update Case
        Test.startTest();
        Map<String, Object> resultUpdate = DRC_NBCCaseInoviceLinkedController.saveCase(caseId, caseJson, inv.Id, lotJson);
        Test.stopTest();
        
        System.assertEquals(true, resultUpdate.get('success'));
    }
    
    
    @IsTest
    static void testPicklistMethods() {
        
        Test.startTest();
        List<String> issueTypes =
            DRC_NBCCaseInoviceLinkedController.getIssueTypePicklistValues();
        List<String> origins =
            DRC_NBCCaseInoviceLinkedController.getOriginPicklistValues();
        List<String> priorities =
            DRC_NBCCaseInoviceLinkedController.getPriorityPicklistValues();
        List<String> statuses =
            DRC_NBCCaseInoviceLinkedController.getStatusPicklistValues();
        Test.stopTest();
    }
    
    @IsTest
    static void testConvertToDecimalHelper() {
        // Decimal input
        Decimal d = DRC_NBCCaseInoviceLinkedController.convertToDecimal(Decimal.valueOf('123.45'));
        System.assertEquals(123.45, d);
        
        // Integer input
        Decimal i = DRC_NBCCaseInoviceLinkedController.convertToDecimal(10);
        System.assertEquals(10, i);
        
        // Valid string input
        Decimal s = DRC_NBCCaseInoviceLinkedController.convertToDecimal('55.5');
        System.assertEquals(55.5, s);
        
        // Empty string input
        Decimal emptyStr = DRC_NBCCaseInoviceLinkedController.convertToDecimal('');
        System.assertEquals(0, emptyStr);
        
        // Null input
        Decimal nullVal = DRC_NBCCaseInoviceLinkedController.convertToDecimal(null);
        System.assertEquals(0, nullVal);
        
        // Invalid string input (should not crash)
        Decimal invalidStr = DRC_NBCCaseInoviceLinkedController.convertToDecimal('abc123');
        System.assertEquals(0, invalidStr);
    }
    
}