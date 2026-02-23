@isTest
private class DRC_NBC_CustomerCreditLimit_Test {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(
            Name                         = 'Test Customer',
            DRC_NBC_Customer_Number__c   = 'CUST001',
            CurrencyIsoCode              = 'INR',
            DRC_NBC_Credit_Limit__c      = 50000,
            DRC_NBC_BC_Approval_Status__c = false,
            BillingStreet                = '123 Test Street',
            BillingCity                  = 'Mumbai',
            BillingState                 = 'Maharashtra',
            BillingPostalCode            = '400001',
            BillingCountry               = 'India'
        );
        insert acc;

        Order ord = new Order(
            AccountId                        = acc.Id,
            Status                           = 'Draft',
            EffectiveDate                    = Date.today(),
            DRC_NBC_Account_Approval_Status__c = 'Pending'
        );
        insert ord;
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    private static void setRestContext(String body) {
        RestRequest req   = new RestRequest();
        RestResponse res  = new RestResponse();
        req.requestURI    = '/services/apexrest/CustomerCreditLimitSync/';
        req.httpMethod    = 'POST';
        req.requestBody   = Blob.valueOf(body);
        RestContext.request  = req;
        RestContext.response = res;
    }

    private static String buildPayload(String customerNumber, Decimal creditLimit,
                                       String currencyCode, String status) {
        Map<String, Object> payload = new Map<String, Object>();
        if (customerNumber != null) payload.put('CustomerNumber', customerNumber);
        if (creditLimit    != null) payload.put('CreditLimit',    creditLimit);
        if (currencyCode   != null) payload.put('CurrencyCode',   currencyCode);
        if (status         != null) payload.put('Status',         status);
        return JSON.serialize(payload);
    }

    // ─── Tests ────────────────────────────────────────────────────────────────

    /**
     * Covers: Happy path — customer found, credit limit updated, orders cleared,
     *         status 200, approval status NOT changed (Status != 'Approved')
     */
    @isTest
    static void test_syncCreditLimit_Success_NoApproval() {
        String body = buildPayload('CUST001', 100000, 'INR', null);
        setRestContext(body);

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        RestResponse res = RestContext.response;
        String responseText = res.responseBody.toString();

        // Status code 200
        Boolean isSuccess = res.statusCode == 200;
        Boolean bodyContains = responseText.contains('Credit limit updated successfully.');
        Boolean condition = isSuccess && bodyContains;
        if (!condition) {
            throw new IllegalArgumentException('Expected 200 and success body but got: '
                + res.statusCode + ' - ' + responseText);
        }

        Account updated = [SELECT DRC_NBC_Credit_Limit__c, CurrencyIsoCode,
                                  DRC_NBC_BC_Approval_Status__c
                           FROM Account WHERE DRC_NBC_Customer_Number__c = 'CUST001'];

        Boolean creditUpdated   = updated.DRC_NBC_Credit_Limit__c == 100000;
        Boolean currencyUpdated = updated.CurrencyIsoCode == 'INR';
        Boolean approvalUnchanged = updated.DRC_NBC_BC_Approval_Status__c == false;

        if (!creditUpdated || !currencyUpdated || !approvalUnchanged) {
            throw new IllegalArgumentException(
                'Account fields not updated as expected. Credit: ' + updated.DRC_NBC_Credit_Limit__c
                + ', Currency: ' + updated.CurrencyIsoCode
                + ', Approval: ' + updated.DRC_NBC_BC_Approval_Status__c
            );
        }
    }

    /**
     * Covers: Status = 'Approved' → DRC_NBC_BC_Approval_Status__c set to true
     */
    @isTest
    static void test_syncCreditLimit_Success_WithApproval() {
        String body = buildPayload('CUST001', 200000, 'USD', 'Approved');
        setRestContext(body);

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        RestResponse res = RestContext.response;
        if (res.statusCode != 200) {
            throw new IllegalArgumentException('Expected 200 but got: ' + res.statusCode);
        }

        Account updated = [SELECT DRC_NBC_BC_Approval_Status__c, DRC_NBC_Credit_Limit__c,
                                  CurrencyIsoCode
                           FROM Account WHERE DRC_NBC_Customer_Number__c = 'CUST001'];

        if (updated.DRC_NBC_BC_Approval_Status__c != true) {
            throw new IllegalArgumentException(
                'Expected approval status true but got: ' + updated.DRC_NBC_BC_Approval_Status__c
            );
        }
        if (updated.DRC_NBC_Credit_Limit__c != 200000) {
            throw new IllegalArgumentException(
                'Expected credit limit 200000 but got: ' + updated.DRC_NBC_Credit_Limit__c
            );
        }
        if (updated.CurrencyIsoCode != 'USD') {
            throw new IllegalArgumentException(
                'Expected USD but got: ' + updated.CurrencyIsoCode
            );
        }
    }

    /**
     * Covers: Status = 'Pending' (not 'Approved') → approval status stays false
     */
    @isTest
    static void test_syncCreditLimit_Success_StatusNotApproved() {
        String body = buildPayload('CUST001', 75000, 'INR', 'Pending');
        setRestContext(body);

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        Account updated = [SELECT DRC_NBC_BC_Approval_Status__c
                           FROM Account WHERE DRC_NBC_Customer_Number__c = 'CUST001'];

        if (updated.DRC_NBC_BC_Approval_Status__c != false) {
            throw new IllegalArgumentException(
                'Approval status should remain false for non-Approved status, got: '
                + updated.DRC_NBC_BC_Approval_Status__c
            );
        }
    }

    /**
     * Covers: Customer not found → 404 response, API log created
     */
    @isTest
    static void test_syncCreditLimit_CustomerNotFound() {
        String body = buildPayload('CUST_DOES_NOT_EXIST', 50000, 'INR', null);
        setRestContext(body);

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        RestResponse res = RestContext.response;

        if (res.statusCode != 404) {
            throw new IllegalArgumentException('Expected 404 but got: ' + res.statusCode);
        }

        Boolean bodyHasNotFound = res.responseBody.toString().contains('Customer not found');
        if (!bodyHasNotFound) {
            throw new IllegalArgumentException(
                'Expected "Customer not found" in body but got: ' + res.responseBody.toString()
            );
        }
    }

    /**
     * Covers: Blank CustomerNumber → CalloutException thrown → 500 response
     */
    @isTest
    static void test_syncCreditLimit_BlankCustomerNumber() {
        String body = buildPayload('', 50000, 'INR', null);
        setRestContext(body);

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        RestResponse res = RestContext.response;

        if (res.statusCode != 500) {
            throw new IllegalArgumentException('Expected 500 but got: ' + res.statusCode);
        }

        Boolean bodyHasError = res.responseBody.toString().contains('CustomerNumber is required');
        if (!bodyHasError) {
            throw new IllegalArgumentException(
                'Expected CustomerNumber error but got: ' + res.responseBody.toString()
            );
        }
    }

    /**
     * Covers: Null CustomerNumber in payload → CalloutException → 500
     */
    @isTest
    static void test_syncCreditLimit_NullCustomerNumber() {
        String body = buildPayload(null, 50000, 'INR', null);
        setRestContext(body);

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        RestResponse res = RestContext.response;

        if (res.statusCode != 500) {
            throw new IllegalArgumentException('Expected 500 but got: ' + res.statusCode);
        }
    }

    /**
     * Covers: Malformed JSON body → JSON deserialization exception → 500
     */
    @isTest
    static void test_syncCreditLimit_MalformedJson() {
        setRestContext('{ invalid json %%%');

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        RestResponse res = RestContext.response;

        if (res.statusCode != 500) {
            throw new IllegalArgumentException(
                'Expected 500 for malformed JSON but got: ' + res.statusCode
            );
        }

        Boolean hasError = res.responseBody.toString().startsWith('Error:');
        if (!hasError) {
            throw new IllegalArgumentException(
                'Expected "Error:" prefix in body but got: ' + res.responseBody.toString()
            );
        }
    }

    /**
     * Covers: Empty JSON body → deserialization exception → 500
     */
    @isTest
    static void test_syncCreditLimit_EmptyBody() {
        setRestContext('');

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        RestResponse res = RestContext.response;

        if (res.statusCode != 500) {
            throw new IllegalArgumentException(
                'Expected 500 for empty body but got: ' + res.statusCode
            );
        }
    }

    /**
     * Covers: Account with no related orders → relatedOrders.isEmpty() = true
     *         → update block skipped, still returns 200
     */
    @isTest
    static void test_syncCreditLimit_NoRelatedOrders() {
        // Create a fresh account with no orders
        Account freshAcc = new Account(
            Name                       = 'No Orders Customer',
            DRC_NBC_Customer_Number__c = 'CUST_NOORDERS',
            CurrencyIsoCode            = 'INR',
            BillingStreet              = '1 Test Road',
            BillingCity                = 'Delhi',
            BillingState               = 'Delhi',
            BillingPostalCode          = '110001',
            BillingCountry             = 'India'
        );
        insert freshAcc;

        String body = buildPayload('CUST_NOORDERS', 30000, 'INR', null);
        setRestContext(body);

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        RestResponse res = RestContext.response;

        if (res.statusCode != 200) {
            throw new IllegalArgumentException(
                'Expected 200 for account with no orders but got: ' + res.statusCode
            );
        }
    }

    /**
     * Covers: Multiple related orders → all cleared in bulk update
     */
    @isTest
    static void test_syncCreditLimit_MultipleRelatedOrders() {
        Account acc = [SELECT Id FROM Account WHERE DRC_NBC_Customer_Number__c = 'CUST001' LIMIT 1];

        // Insert additional orders
        List<Order> extraOrders = new List<Order>();
        for (Integer i = 0; i < 3; i++) {
            extraOrders.add(new Order(
                AccountId                        = acc.Id,
                Status                           = 'Draft',
                EffectiveDate                    = Date.today(),
                DRC_NBC_Account_Approval_Status__c = 'Pending'
            ));
        }
        insert extraOrders;

        String body = buildPayload('CUST001', 150000, 'INR', 'Approved');
        setRestContext(body);

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        RestResponse res = RestContext.response;

        if (res.statusCode != 200) {
            throw new IllegalArgumentException(
                'Expected 200 for multiple orders but got: ' + res.statusCode
            );
        }
    }

    /**
     * Covers: Valid payload with null CreditLimit and null CurrencyCode
     *         → account fields set to null, no exception
     */
    @isTest
    static void test_syncCreditLimit_NullCreditLimitAndCurrency() {
        String body = buildPayload('CUST001', null, null, null);
        setRestContext(body);

        Test.startTest();
        DRC_NBC_CustomerCreditLimitSyncService.syncCreditLimit();
        Test.stopTest();

        RestResponse res = RestContext.response;

        if (res.statusCode != 200) {
            throw new IllegalArgumentException(
                'Expected 200 even with null credit limit/currency but got: ' + res.statusCode
            );
        }
    }
}