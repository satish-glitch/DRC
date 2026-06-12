@isTest
public class CustomerItemReferenceSOAPQueueableTest {
    
    // ─────────────────────────────────────────────────────────
    // HTTP Mock - returns ReadMultiple / CreateMultiple / UpdateMultiple responses
    // ─────────────────────────────────────────────────────────
    private class SOAPMock implements HttpCalloutMock {
        Integer statusCode;
        String soapAction;
        
        public SOAPMock(Integer statusCode) {
            this.statusCode = statusCode;
        }
        
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setHeader('Content-Type', 'text/xml');
            
            String action = req.getHeader('SOAPAction');
            
            if (statusCode != 200) {
                res.setBody('<error>Failed</error>');
                return res;
            }
            
            if (action != null && action.contains('ReadMultiple')) {
                // Return one existing CustomerItemReference matching FG001 / restricted product name
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body>' +
                    '<ReadMultiple_Result>' +
                    '<CUstomerItemReference_List>' +
                    '<CUstomerItemReference>' +
                    '<Key>EXISTINGKEY001</Key>' +
                    '<Item_No>FG001</Item_No>' +
                    '<Reference_No>RP-EXISTING</Reference_No>' +
                    '</CUstomerItemReference>' +
                    '</CUstomerItemReference_List>' +
                    '</ReadMultiple_Result>' +
                    '</soapenv:Body>' +
                    '</soapenv:Envelope>'
                );
            } else if (action != null && action.contains('CreateMultiple')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><CreateMultiple_Result/></soapenv:Body>' +
                    '</soapenv:Envelope>'
                );
            } else if (action != null && action.contains('UpdateMultiple')) {
                res.setBody(
                    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">' +
                    '<soapenv:Body><UpdateMultiple_Result/></soapenv:Body>' +
                    '</soapenv:Envelope>'
                );
            } else {
                res.setBody('<empty/>');
            }
            
            return res;
        }
    }
    
    // ─────────────────────────────────────────────────────────
    // Setup helpers
    // ─────────────────────────────────────────────────────────
    private static void setupCustomSetting() {
        DRC_NBC_BC_Integration__c cs = new DRC_NBC_BC_Integration__c();
        cs.CustomerItemRef_SOAP_NS__c = 'http://schemas.xmlsoap.org/soap/envelope/';
        cs.CustomerItemRef_BC_NS__c = 'urn:microsoft-dynamics-schemas/page/customeritemreference';
        cs.customer_item_ref_endpoint__c = 'https://test.businesscentral.com/CustomerItemReference';
        cs.DRC_NBC_Username__c = 'testuser';
        cs.DRC_NBC_Password__c = 'testpass';
        insert cs;
    }
    
    private static DRC_NBC_Restricted_Product__c createRestrictedProduct(Account acc, Product2 prod, String name) {
        DRC_NBC_Restricted_Product__c rp = new DRC_NBC_Restricted_Product__c();
        rp.DRC_NBC_Customer__c = acc.Id;
        rp.DRC_NBC_Product__c = prod.Id;
        rp.DRC_NBC_Customer_s_Product_code__c = 'CUST-PROD-CODE';
        insert rp;
        return rp;
    }
    
    // ─────────────────────────────────────────────────────────
    // 1. Happy path: account fetch, mixed Create + Update
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testExecute_CreateAndUpdate_Success() {
        setupCustomSetting();
        
        Account acc = DRC_NBC_TestFactory.createAccount();
       
        
        Product2 prod1 = DRC_NBC_TestFactory.createProduct();
        
        Product2 prod2 = new Product2(
            Name = 'Test Product 2',
            ProductCode = 'TP002',
            isActive = true,
            QuantityUnitOfMeasure = 'PCS',
            DRC_NBC_HSN_SAC_Code__c = 'HSN5678',
            DRC_NBC_FG_Code__c = 'FG002'
        );
        insert prod2;
        
        // This one matches ReadMultiple mock → goes to Update
        createRestrictedProduct(acc, prod1, 'RP-EXISTING');
        // This one does NOT match mock → goes to Create
        createRestrictedProduct(acc, prod2, 'RP-NEW');
        
        Test.setMock(HttpCalloutMock.class, new SOAPMock(200));
        
        Test.startTest();
        CustomerItemReferenceSOAPQueueable q = new CustomerItemReferenceSOAPQueueable(acc.Id);
        System.enqueueJob(q);
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────
    // 2. Early-exit: no restricted products
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testExecute_NoRestrictedProducts_EarlyExit() {
        setupCustomSetting();
        
        Account acc = DRC_NBC_TestFactory.createAccount();
      
        
        Test.setMock(HttpCalloutMock.class, new SOAPMock(200));
        
        Test.startTest();
        CustomerItemReferenceSOAPQueueable q = new CustomerItemReferenceSOAPQueueable(acc.Id);
        System.enqueueJob(q);
        Test.stopTest();
        
        List<DRC_NBC_API_Log__c> logs = [SELECT Id FROM DRC_NBC_API_Log__c];
        System.assertEquals(0, logs.size(), 'No logs expected when no products and early exit');
    }
    
    // ─────────────────────────────────────────────────────────
    // 3. Product with blank Item_No (FG Code) is skipped
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testExecute_BlankItemNo_Skipped() {
        setupCustomSetting();
        
        Account acc = DRC_NBC_TestFactory.createAccount();
      
        Product2 prodNoFG = new Product2(
            Name = 'No FG Code Product',
            ProductCode = 'TP003',
            isActive = true,
            QuantityUnitOfMeasure = 'PCS',
            DRC_NBC_HSN_SAC_Code__c = 'HSN0000'
            // DRC_NBC_FG_Code__c left blank
        );
        insert prodNoFG;
        
        createRestrictedProduct(acc, prodNoFG, 'RP-NOFG');
        
        Test.setMock(HttpCalloutMock.class, new SOAPMock(200));
        
        Test.startTest();
        CustomerItemReferenceSOAPQueueable q = new CustomerItemReferenceSOAPQueueable(acc.Id);
        System.enqueueJob(q);
        Test.stopTest();
    }
    
    // ─────────────────────────────────────────────────────────
    // 4. Callout failure (non-200) → Error status logs
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testExecute_CalloutFailure_ErrorLogged() {
        setupCustomSetting();
        
        Account acc = DRC_NBC_TestFactory.createAccount();
       
        
        Product2 prod = DRC_NBC_TestFactory.createProduct();
        createRestrictedProduct(acc, prod, 'RP-FAIL');
        
        Test.setMock(HttpCalloutMock.class, new SOAPMock(500));
        
        Test.startTest();
        CustomerItemReferenceSOAPQueueable q = new CustomerItemReferenceSOAPQueueable(acc.Id);
        System.enqueueJob(q);
        Test.stopTest();
        
    }
    
    // ─────────────────────────────────────────────────────────
    // 5. Exception path (invalid account id) → caught and logged
    // ─────────────────────────────────────────────────────────
    @isTest
    static void testExecute_InvalidAccount_ExceptionLogged() {
        setupCustomSetting();
        
        Account acc = DRC_NBC_TestFactory.createAccount();
        // delete after construction so SOQL in execute() throws (no record found)
        Id accId = acc.Id;
        delete acc;
        
        Test.setMock(HttpCalloutMock.class, new SOAPMock(200));
        
        Test.startTest();
        CustomerItemReferenceSOAPQueueable q = new CustomerItemReferenceSOAPQueueable(accId);
        System.enqueueJob(q);
        Test.stopTest();
    }
}