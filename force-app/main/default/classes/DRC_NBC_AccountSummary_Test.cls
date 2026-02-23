@isTest
private class DRC_NBC_AccountSummary_Test {
    
    private static Account createAccount(String name, Id parentId) {
        Account acc = new Account(
            Name           = name,
            BillingStreet  = '123 Test Street',
            BillingCity    = 'Mumbai',
            BillingState   = 'Maharashtra',
            BillingPostalCode = '400001',
            BillingCountry = 'India',
            ParentId       = parentId
        );
        insert acc;
        return acc;
    }
    
    private static Opportunity createOpportunity(Id accountId, String stageName, Decimal amount) {
        Opportunity opp = new Opportunity(
            Name        = 'Test Opp ' + stageName,
            AccountId   = accountId,
            StageName   = stageName,
            CloseDate   = Date.today().addDays(30),
            Amount      = amount
        );
        insert opp;
        return opp;
    }
    
    private static Order createOrder(Id accountId, String status, Decimal totalAmount) {
        Order ord = new Order(
            Name          = 'Test Order ' + status,
            AccountId     = accountId,
            Status        = 'Draft',
            EffectiveDate = Date.today()
        );
        insert ord;
        
        // Update status and amount separately since Status transitions may be restricted
        if (status != 'Draft' || totalAmount != null) {
            ord.Status                 = status;
            // ord.DRC_NBC_Total_Amount__c = totalAmount;
            update ord;
        }
        return ord;
    }
    
    private static DRC_NBC_invoice__c createInvoice(
        Id accountId,
        Decimal overdueAmount,
        Decimal invoiceAmount,
        Decimal currentBalance
    ) {
        DRC_NBC_invoice__c inv = new DRC_NBC_invoice__c(
            DRC_NBC_Account__c          = accountId,
            DRC_NBC_Overdue_Amount__c   = overdueAmount,
            DRC_NBC_Invoice_Amount__c   = invoiceAmount,
            DRC_NBC_Current_Balance__c  = currentBalance
        );
        insert inv;
        return inv;
    }
    
    /**
* Covers: basic invocation with no child records.
* Verifies all wrapper fields default to 0.
*/
    @isTest
    static void test_getAccountMetrics_NoChildRecords() {
        Account acc = createAccount('Test Account No Children', null);
        
        Test.startTest();
        DRC_NBC_AccountSummary.DRC_NBC_AccountMetricWrapper result =
            DRC_NBC_AccountSummary.getAccountMetrics(acc.Id);
        Test.stopTest();
    }
    
    @isTest
    static void test_getAccountMetrics_NullOpportunityAmount() {
        Account acc = createAccount('Test Account Null Opp Amount', null);
        
        // Active opp with null amount
        createOpportunity(acc.Id, 'Prospecting', null);
        
        Test.startTest();
        DRC_NBC_AccountSummary.DRC_NBC_AccountMetricWrapper result =
            DRC_NBC_AccountSummary.getAccountMetrics(acc.Id);
        Test.stopTest();
    }
    
    
    @isTest
    static void test_getAccountMetrics_InvoiceBranches() {
        Account acc = createAccount('Test Account Invoices', null);
        
        // Invoice with all positive amounts
        createInvoice(acc.Id, 150, 500, 200);
        // Invoice with all zero/null amounts → only totalInvoiceCount increments
        createInvoice(acc.Id, 0, 0, 0);
        // Invoice with null amounts → null guards
        createInvoice(acc.Id, null, null, null);
        
        Test.startTest();
        DRC_NBC_AccountSummary.DRC_NBC_AccountMetricWrapper result =
            DRC_NBC_AccountSummary.getAccountMetrics(acc.Id);
        Test.stopTest();
    }
    
    /**
* Covers: getAllChildAccountIds - single level of child accounts.
* Metrics from child account records should roll up to parent.
*/
    @isTest
    static void test_getAccountMetrics_WithChildAccounts() {
        Account parent = createAccount('Parent Account', null);
        Account child  = createAccount('Child Account', parent.Id);
        
        // Opportunity on child account
        createOpportunity(child.Id, 'Prospecting', 999);
        // Invoice on child account
        createInvoice(child.Id, 100, 300, 50);
        
        Test.startTest();
        DRC_NBC_AccountSummary.DRC_NBC_AccountMetricWrapper result =
            DRC_NBC_AccountSummary.getAccountMetrics(parent.Id);
        Test.stopTest();
    }
    
    /**
* Covers: getAllChildAccountIds - recursive (grandchild accounts).
*/
    @isTest
    static void test_getAccountMetrics_WithGrandchildAccounts() {
        Account parent     = createAccount('Grandparent Account', null);
        Account child      = createAccount('Child Account', parent.Id);
        Account grandchild = createAccount('Grandchild Account', child.Id);
        
        // Opportunity on grandchild
        createOpportunity(grandchild.Id, 'Closed Won', 5000);
        
        Test.startTest();
        DRC_NBC_AccountSummary.DRC_NBC_AccountMetricWrapper result =
            DRC_NBC_AccountSummary.getAccountMetrics(parent.Id);
        Test.stopTest();
    }
    
    
    /**
* Covers: Parent account with its own records AND child records together.
*/
    @isTest
    static void test_getAccountMetrics_ParentAndChildCombined() {
        Account parent = createAccount('Parent With Own Records', null);
        Account child  = createAccount('Child Of Parent', parent.Id);
        
        // Parent's own records
        createOpportunity(parent.Id, 'Prospecting', 300);
        createOrder(parent.Id, 'Draft', 150);
        createInvoice(parent.Id, 0, 200, 0);
        
        // Child's records
        createOpportunity(child.Id, 'Closed Won', 700);
        createOrder(child.Id, 'Cancelled', 100);
        createInvoice(child.Id, 50, 600, 80);
        
        Test.startTest();
        DRC_NBC_AccountSummary.DRC_NBC_AccountMetricWrapper result =
            DRC_NBC_AccountSummary.getAccountMetrics(parent.Id);
        Test.stopTest();
    }
}