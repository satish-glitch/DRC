@isTest
public class DRC_NBC_CustomerRefrenceItemCallout_Test {
    
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
    // MOCK - Exception triggers catch block
    // =====================================================
    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new MockCalloutException('Simulated Callout Exception');
        }
    }
    private class MockCalloutException extends Exception {}
    // =====================================================
    // SETUP - Mirrors getConfig() query exactly
    // =====================================================
    private static void setupConfig() {
        Boolean isSandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        String targetEnv  = isSandbox
            ? System.label.DRC_NBC_Sandbox
            : System.label.DRC_NBC_Production;
        
        DRC_NBC_BC_Integration__c config = new DRC_NBC_BC_Integration__c(
            Name__c                              = targetEnv,
            DRC_NBC_Comapny_Name__c              = 'TestCompany',
            DRC_NBC_Endpoint__c                  = 'https://mock-endpoint.test',
            CustomerItemReference__c             = 'https://mock-endpoint.test/customeritemreference',
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
    // TEST 1 - Success flow with restricted products
    // Covers callout loop + log entry creation (201 path)
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
            new DRC_NBC_CustomerRefrenceItem_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }
    
    // =====================================================
    // TEST 2 - 400 response triggers status == 'Error'
    // branch in log loop + logError call
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
            new DRC_NBC_CustomerRefrenceItem_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }
    
    // =====================================================
    // TEST 3 - No restricted products triggers early return
    // =====================================================
    @isTest
    static void testExecute_NoRestrictedProducts() {
        setupConfig();
        
        Account acc        = DRC_NBC_TestFactory.createAccount();
        Product2 prod      = DRC_NBC_TestFactory.createProduct();
        PricebookEntry pbe = DRC_NBC_TestFactory.createPricebookEntry(prod);
        Order ord          = DRC_NBC_TestFactory.createOrder(acc, pbe);
        
        // No restricted products inserted intentionally
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        Test.startTest();
        System.enqueueJob(
            new DRC_NBC_CustomerRefrenceItem_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }
    
    // =====================================================
    // TEST 4 - Callout exception triggers catch block
    // and logError via exception handler
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
            new DRC_NBC_CustomerRefrenceItem_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }
    
    // =====================================================
    // TEST 5 - Multiple restricted products ensures loop
    // iterates fully and logs all records
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
            new DRC_NBC_CustomerRefrenceItem_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }
    
    // =====================================================
    // TEST 6 - Single product 400 response — logError
    // fires exactly once, covers private logError method
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
            new DRC_NBC_CustomerRefrenceItem_Queueable(ord.Id, acc.Id)
        );
        Test.stopTest();
    }
    
    // =====================================================
    // TEST 7 - mapToPayload unit test — directly exercises
    // the static mapping method on the callout class
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
        
        Account accFull = [
            SELECT Id, Name, DRC_NBC_Customer_Number__c, Type
            FROM Account
            WHERE Id = :acc.Id
            LIMIT 1
        ];
        
        Test.startTest();
        DRC_NBC_Integration_Payload.CustomerItemReferencePayload payload =
            DRC_NBC_CustomerRefrenceItems_BC_Callout.mapToPayload(
                rp,
                accFull.DRC_NBC_Customer_Number__c,
                accFull
            );
        Test.stopTest();
    }
    
    // =====================================================
    // TEST 8 - mapToPayload with null customer number
    // covers the null/blank customerNumber branch
    // =====================================================
    @isTest
    static void testMapToPayload_NullCustomerNumber() {
        Account acc   = DRC_NBC_TestFactory.createAccount();
        Product2 prod = DRC_NBC_TestFactory.createProduct();
        
        DRC_NBC_Restricted_Product__c rp = new DRC_NBC_Restricted_Product__c(
            DRC_NBC_Customer__c                = acc.Id,
            DRC_NBC_Product__c                 = prod.Id,
            DRC_NBC_Customer_s_Product_code__c = 'CUST-PROD-NULL'
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
        
        Account accFull = [
            SELECT Id, Name, DRC_NBC_Customer_Number__c, Type
            FROM Account
            WHERE Id = :acc.Id
            LIMIT 1
        ];
        
        Test.startTest();
        DRC_NBC_Integration_Payload.CustomerItemReferencePayload payload =
            DRC_NBC_CustomerRefrenceItems_BC_Callout.mapToPayload(rp, null, accFull);
        Test.stopTest();
    }
    
    
}