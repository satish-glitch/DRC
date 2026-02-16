@IsTest
private class DRC_NBC_Invoice_Sync_WebService_Test {
    
    @TestSetup
    static void setupData() {
        // Account
        Account acc = new Account(
            Name = 'Test Customer',
            DRC_NBC_Customer_Number__c = 'CustDOM/2526-00014'
        );
        insert acc;
        
        // Order
        Order ord = new Order(
            Name = 'Test Order',
            Status = 'Draft',
            EffectiveDate = Date.today(),
            AccountId = acc.Id,
            DRC_NBC_Cust_Order_Number__c = 'SODOM/2526/00134'
        );
        insert ord;
        
        // Product
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'FG00004',
            IsActive = true
        );
        insert prod;
    }
    
    @IsTest
    static void testInvoiceSync_InsertAndUpdate() {
        // Prepare REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/InvoiceSync';
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'InvoiceNumber' => 'SIDOM/23/00109',
                'InvoiceDate' => '2025-12-26',
                'OrderNumber' => 'SODOM/2526/00134',
                'ExternalDocumentNumber' => 'SAN154',
                'IRNNumber' => '',
                'AcknowledgementNumber' => '',
                'AcknowledgementDate' => '',
                'EWayBillNumber' => '',
                'VehicleNumber' => '',
                'PaymentTerms' => '30D INV',
                'DeliveryLocation' => 'E-123',
                'ShippingDRCCode' => 'CustDOM/2526-00014',
                'ShippingCustomerName' => 'SAMRAT CHEMICAL INDUSTRIES',
                'ShippingAddress' => 'UDAIPUR ADDRESS',
                'ShippingGSTNumber' => '08ABGFS2082K1ZV',
                'ShippingState' => 'RJ',
                'ShippingStateCode' => '08',
                'lineItems' => new List<Object>{
                    new Map<String, Object>{
                        'ProductCode' => 'FG00004',
                            'Amount' => 116520.0,
                            'lotDetails' => new List<Object>{
                                new Map<String, Object>{
                                    'lot' => 'LOC-001-A',
                                        'quantity' => 200
                                        },
                                            new Map<String, Object>{
                                                'lot' => 'LOC-001-B',
                                                    'quantity' => 200
                                                    }
                            }
                    }
                }
        });
        
        req.requestBody = Blob.valueOf(requestBody);
        RestContext.request = req;
        RestContext.response = res;
        
        DRC_NBC_Invoice_Sync_WebService.syncInvoices();
        
        // Assertions – Invoice
        DRC_NBC_Invoice__c inv = [
            SELECT Id, DRC_NBC_Invoice_Number__c
            FROM DRC_NBC_Invoice__c
            WHERE DRC_NBC_Invoice_Number__c = 'SIDOM/23/00109'
            LIMIT 1
        ];
        System.assertNotEquals(null, inv.Id);
        
        // Assertions – Line Item
        List<DRC_NBC_Invoice_Line_Item__c> ilis = [
            SELECT Id
            FROM DRC_NBC_Invoice_Line_Item__c
            WHERE DRC_NBC_Invoice_Number__c = :inv.Id
        ];
        System.assertEquals(1, ilis.size());
        
        // Assertions – Lot records
        List<DRC_NBC_Invoice_Lot__c> lots = [
            SELECT Id, DRC_NBC_Lot_Number__c, DRC_NBC_Lot_Quantity__c
            FROM DRC_NBC_Invoice_Lot__c
            WHERE DRC_NBC_Invoice__c = :inv.Id
        ];
        System.assertEquals(2, lots.size());
        
        // Call again to cover UPDATE path
        RestContext.request = req;
        RestContext.response = new RestResponse();
        
        Test.startTest();
        DRC_NBC_Invoice_Sync_WebService.syncInvoices();
        Test.stopTest();
        
    }
    
    @IsTest
    static void testErrorHandling() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/InvoiceSync';
        req.requestBody = Blob.valueOf('INVALID_JSON');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        DRC_NBC_Invoice_Sync_WebService.syncInvoices();
        Test.stopTest();
        
    }
    
    @IsTest
    static void testFormatLotHelpers() {
        String input = 'LOT123 - Qty : 50, LOT124 - Qty : 75';
        
        String lotNoOutput = DRC_NBC_Invoice_Sync_WebService.formatLotNo(input);
        System.assertEquals('1. LOT123\n2. LOT124', lotNoOutput);
        
        String lotQtyOutput = DRC_NBC_Invoice_Sync_WebService.formatLotQuantity(input);
    }
    
}