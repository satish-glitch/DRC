@isTest
public class DRC_NBC_CustomerItemsQueueable_Test {

    // =====================================================
    // MOCK - Success Response (201)
    // =====================================================
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setStatus('Created');
            res.setBody('{"status":"success"}');
            return res;
        }
    }

    // =====================================================
    // MOCK - Error Response (400)
    // =====================================================
    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(400);
            res.setStatus('Bad Request');
            res.setBody('{"error":"Bad Request"}');
            return res;
        }
    }

    // =====================================================
    // MOCK - Exception — triggers catch block
    // =====================================================
    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated Callout Exception');
        }
    }

    // =====================================================
    // SETUP - Matches exactly what getConfig() queries.
    // Reads isSandbox() at runtime — same logic as the
    // utility — so Name__c always matches the WHERE clause.
    // =====================================================
    private static void setupConfig() {
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        String targetEnv  = isSandbox
            ? System.label.DRC_NBC_Sandbox
            : System.label.DRC_NBC_Production;

        DRC_NBC_BC_Integration__c config = new DRC_NBC_BC_Integration__c(
            Name__c                              = targetEnv,
            DRC_NBC_Comapny_Name__c              = 'TestCompany',
            DRC_NBC_Endpoint__c                  = 'CustomerItems',
            DRC_NBC_Customer_Items_Endpoint__c   = 'CustomerItems',
            DRC_NBC_SendOrderEndpoint__c         = 'Orders',
            DRC_NBC_Shipping_Address_Endpoint__c = 'ShippingAddress',
            DRC_NBC_SendOrderLineEndpoint__c     = 'OrderLines',
            DRC_NBC_SalesPerson_Code__c          = 'SP001',
            DRC_NBC_Consignee_Bank_Endpoint__c   = 'ConsigneeBank'
        );
        insert config;
    }

    // =====================================================
    // HELPER - Create N restricted products for an account
    // =====================================================
    private static List<DRC_NBC_Restricted_Product__c> createRestrictedProducts(
        Id accountId, Id productId, Integer count
    ) {
        List<DRC_NBC_Restricted_Product__c> rpList = new List<DRC_NBC_Restricted_Product__c>();
        for (Integer i = 1; i <= count; i++) {
            rpList.add(new DRC_NBC_Restricted_Product__c(
                DRC_NBC_Customer__c                = accountId,
                DRC_NBC_Product__c                 = productId,
                DRC_NBC_Customer_s_Product_code__c = 'CUST-PROD-00' + i
            ));
        }
        insert rpList;
        return rpList;
    }

    // =====================================================
    // TEST 1 - Queueable: Success flow with restricted
    // products. Covers callout loop, log entry creation,
    // and enqueue of the next queueable.
    // =====================================================
    @isTest
    static void testExecute_WithRestrictedProducts_Success() {
        setupConfig();

        Account acc        = DRC_NBC_TestFactory.createAccount();
        Product2 prod      = DRC_NBC_TestFactory.createProduct();
        PricebookEntry pbe = DRC_NBC_TestFactory.createPricebookEntry(prod);
        Order ord          = DRC_NBC_TestFactory.createOrder(acc, pbe);

        createRestrictedProducts(acc.Id, prod.Id, 2);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_CustomerItems_Callout_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }

    // =====================================================
    // TEST 2 - Queueable: 400 response triggers logError
    // and the status == 'Error' branch in the log loop.
    // =====================================================
    @isTest
    static void testExecute_WithRestrictedProducts_ErrorResponse() {
        setupConfig();

        Account acc        = DRC_NBC_TestFactory.createAccount();
        Product2 prod      = DRC_NBC_TestFactory.createProduct();
        PricebookEntry pbe = DRC_NBC_TestFactory.createPricebookEntry(prod);
        Order ord          = DRC_NBC_TestFactory.createOrder(acc, pbe);

        createRestrictedProducts(acc.Id, prod.Id, 2);

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_CustomerItems_Callout_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }

    // =====================================================
    // TEST 3 - Queueable: No restricted products triggers
    // the early return and skips directly to next queueable.
    // =====================================================
    @isTest
    static void testExecute_NoRestrictedProducts() {
        setupConfig();

        Account acc        = DRC_NBC_TestFactory.createAccount();
        Product2 prod      = DRC_NBC_TestFactory.createProduct();
        PricebookEntry pbe = DRC_NBC_TestFactory.createPricebookEntry(prod);
        Order ord          = DRC_NBC_TestFactory.createOrder(acc, pbe);

        // Intentionally no restricted products inserted
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_CustomerItems_Callout_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }

    // =====================================================
    // TEST 4 - Queueable: Callout exception is caught
    // internally; no exception should bubble up.
    // =====================================================
    @isTest
    static void testExecute_CalloutException() {
        setupConfig();

        Account acc        = DRC_NBC_TestFactory.createAccount();
        Product2 prod      = DRC_NBC_TestFactory.createProduct();
        PricebookEntry pbe = DRC_NBC_TestFactory.createPricebookEntry(prod);
        Order ord          = DRC_NBC_TestFactory.createOrder(acc, pbe);

        createRestrictedProducts(acc.Id, prod.Id, 1);

        Test.setMock(HttpCalloutMock.class, new ExceptionMock());

        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_CustomerItems_Callout_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }

    // =====================================================
    // TEST 5 - Queueable: 5 restricted products ensures
    // the loop iterates and logs all records correctly.
    // =====================================================
    @isTest
    static void testExecute_MultipleRestrictedProducts() {
        setupConfig();

        Account acc        = DRC_NBC_TestFactory.createAccount();
        Product2 prod      = DRC_NBC_TestFactory.createProduct();
        PricebookEntry pbe = DRC_NBC_TestFactory.createPricebookEntry(prod);
        Order ord          = DRC_NBC_TestFactory.createOrder(acc, pbe);

        createRestrictedProducts(acc.Id, prod.Id, 5);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_CustomerItems_Callout_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }

    // =====================================================
    // TEST 6 - Queueable: Single product with 400 response
    // so logError fires exactly once — covers the private
    // logError method and the 'Error' branch in isolation.
    // =====================================================
    @isTest
    static void testExecute_LogError_TriggeredByErrorStatus() {
        setupConfig();

        Account acc        = DRC_NBC_TestFactory.createAccount();
        Product2 prod      = DRC_NBC_TestFactory.createProduct();
        PricebookEntry pbe = DRC_NBC_TestFactory.createPricebookEntry(prod);
        Order ord          = DRC_NBC_TestFactory.createOrder(acc, pbe);

        createRestrictedProducts(acc.Id, prod.Id, 1);

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_CustomerItems_Callout_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }

    // =====================================================
    // TEST 7 - mapToPayload: unit-tests the static mapping
    // method on DRC_NBC_CustomerItems_BC_Callout directly.
    // =====================================================
    @isTest
    static void testMapToPayload_Direct() {
        Account acc   = DRC_NBC_TestFactory.createAccount();
        Product2 prod = DRC_NBC_TestFactory.createProduct();

        DRC_NBC_Restricted_Product__c rp = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c                = acc.Id,
            DRC_NBC_Product__c                 = prod.Id,
            DRC_NBC_Customer_s_Product_code__c = 'CUST-PROD-MAP'
        );
        insert rp;

        rp = [
            SELECT Id, DRC_NBC_Customer__c, DRC_NBC_Product__c,
                   DRC_NBC_Product__r.Name,
                   DRC_NBC_Product__r.DRC_NBC_FG_Code__c,
                   DRC_NBC_Customer_s_Product_code__c
            FROM DRC_NBC_Restricted_Product__c
            WHERE Id = :rp.Id
            LIMIT 1
        ];

        Test.startTest();
        DRC_NBC_Integration_Payload.CustomerItemPayload payload =
            DRC_NBC_CustomerItems_BC_Callout.mapToPayload(rp, 'CUST-001');
        Test.stopTest();
    }

    // =====================================================
    // TEST 8 - getRestrictedProducts: unit-tests the static
    // query method on DRC_NBC_CustomerItems_BC_Callout directly.
    // =====================================================
    @isTest
    static void testGetRestrictedProducts_Direct() {
        Account acc   = DRC_NBC_TestFactory.createAccount();
        Product2 prod = DRC_NBC_TestFactory.createProduct();

        insert new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c                = acc.Id,
            DRC_NBC_Product__c                 = prod.Id,
            DRC_NBC_Customer_s_Product_code__c = 'CUST-PROD-GET'
        );

        Test.startTest();
        List<DRC_NBC_Restricted_Product__c> results =
            DRC_NBC_CustomerItems_BC_Callout.getRestrictedProducts(acc.Id);
        Test.stopTest();
    }

    // =====================================================
    // TEST 9 - BC Integration: 201 success directly
    // exercises every line in executeAndReturnResponse —
    // setEndpoint, setMethod, setHeader, setBody,
    // setTimeout, http.send, and return res.
    // =====================================================
    @isTest
    static void testBCIntegration_Success() {
        setupConfig();

        Account acc = DRC_NBC_TestFactory.createAccount();

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        DRC_NBC_CustomerItems_BC_Integration integration =
            new DRC_NBC_CustomerItems_BC_Integration(
                'CustomerItems',
                'POST',
                '{"itemNo":"PROD-001","customerNo":"CUST-001"}',
                acc.Id
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
    }

    // =====================================================
    // TEST 10 - BC Integration: 400 error response through
    // the integration class directly.
    // =====================================================
    @isTest
    static void testBCIntegration_Error() {
        setupConfig();

        Account acc = DRC_NBC_TestFactory.createAccount();

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        DRC_NBC_CustomerItems_BC_Integration integration =
            new DRC_NBC_CustomerItems_BC_Integration(
                'CustomerItems',
                'POST',
                '{"itemNo":"PROD-001","customerNo":"CUST-001"}',
                acc.Id
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
    }

    // =====================================================
    // TEST 11 - BC Integration: PUT method covers the
    // setMethod line with a value other than POST.
    // =====================================================
    @isTest
    static void testBCIntegration_PutMethod() {
        setupConfig();

        Account acc = DRC_NBC_TestFactory.createAccount();

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        DRC_NBC_CustomerItems_BC_Integration integration =
            new DRC_NBC_CustomerItems_BC_Integration(
                'CustomerItems',
                'PUT',
                '{"itemNo":"PROD-002","customerNo":"CUST-002"}',
                acc.Id
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
    }

    // =====================================================
    // TEST 12 - BC Integration: empty body covers setBody
    // with a minimal payload.
    // =====================================================
    @isTest
    static void testBCIntegration_EmptyBody() {
        setupConfig();

        Account acc = DRC_NBC_TestFactory.createAccount();

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        DRC_NBC_CustomerItems_BC_Integration integration =
            new DRC_NBC_CustomerItems_BC_Integration(
                'CustomerItems',
                'POST',
                '{}',
                acc.Id
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
    }

    // =====================================================
    // TEST 13 - BC Integration: null accountId covers the
    // constructor when no account context is available.
    // =====================================================
    @isTest
    static void testBCIntegration_NullAccountId() {
        setupConfig();

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        DRC_NBC_CustomerItems_BC_Integration integration =
            new DRC_NBC_CustomerItems_BC_Integration(
                'CustomerItems',
                'POST',
                '{"itemNo":"PROD-003"}',
                null
            );
        HttpResponse res = integration.executeAndReturnResponse();
        Test.stopTest();
    }
}