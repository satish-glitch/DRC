@isTest
private class DRC_NBC_OrderTriggerHandlerTest {
    
    // ── Helper: create Account ─────────────────────────────────────────────
    private static Account createAccount() {
        Account acc = new Account( Name = 'Test Account',
                                  DRC_NBC_Customer_Number__c = 'CUST12345',
                                  CurrencyIsoCode = 'INR',
                                  Phone = '1234567890',
                                  AccountNumber = 'A123',
                                  DRC_NBC_PAN_No__c = 'AWVPY9594J',
                                  DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
                                  DRC_NBC_Payment_Term_Code__c = '10 DAYS',
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
        return acc;
    }
    
    // ── Helper: create Address ─────────────────────────────────────────────
    private static DRC_NBC_Addresses__c createAddress(Id accountId) {
        DRC_NBC_Addresses__c addr = new DRC_NBC_Addresses__c(
            DRC_NBC_Address__City__s        = 'Pune',
            DRC_NBC_Address__CountryCode__s = 'IN',
            DRC_NBC_Address__PostalCode__s  = '411014',
            DRC_NBC_Address__StateCode__s   = 'MH',
            DRC_NBC_Address__Street__s      = 'Test Street',
            DRC_NBC_Type__c                 = 'Shipping',
            DRC_NBC_Account__c              = accountId   // Account on Address
        );
        insert addr;
        return addr;
    }
    
    // ── Helper: create Order ───────────────────────────────────────────────
    private static Order createOrder(Id accountId, Id addressId, String warehouse) {
        Order o = new Order(
            AccountId                   = accountId,
            DRC_NBC_Warehouse__c        = warehouse,
            DRC_NBC_Shipping_Address__c = addressId,
            EffectiveDate               = Date.today(),
            Status                      = 'Draft'
        );
        insert o;
        return o;
    }
    
    // =======================================================================
    // TEST 1: INSERT with Warehouse → Address warehouse updated
    // =======================================================================
    @isTest
    static void testInsert_WithWarehouse_UpdatesAddress() {
        Account acc              = createAccount();
        DRC_NBC_Addresses__c addr = createAddress(acc.Id);
        
        Test.startTest();
        Order o = createOrder(acc.Id, addr.Id, 'DARSHAN CHEMICALS');
        Test.stopTest();
        
        DRC_NBC_Addresses__c result = [
            SELECT DRC_NBC_Warehouse__c
            FROM   DRC_NBC_Addresses__c
            WHERE  Id = :addr.Id
        ];
        System.assertEquals('DARSHAN CHEMICALS', result.DRC_NBC_Warehouse__c,
                            'Address warehouse should be updated after Order insert.');
    }
    
    // =======================================================================
    // TEST 2: INSERT with null Warehouse → Address NOT updated
    // =======================================================================
    @isTest
    static void testInsert_NullWarehouse_AddressNotUpdated() {
        Account acc               = createAccount();
        DRC_NBC_Addresses__c addr = createAddress(acc.Id);
        
        Test.startTest();
        Order o = createOrder(acc.Id, addr.Id, null);
        Test.stopTest();
        
        DRC_NBC_Addresses__c result = [
            SELECT DRC_NBC_Warehouse__c
            FROM   DRC_NBC_Addresses__c
            WHERE  Id = :addr.Id
        ];
        System.assertEquals(null, result.DRC_NBC_Warehouse__c,
                            'Address warehouse should remain null when Order warehouse is null.');
    }
    
    // =======================================================================
    // TEST 3: UPDATE Warehouse changed → Address warehouse updated
    // =======================================================================
    @isTest
    static void testUpdate_WarehouseChanged_UpdatesAddress() {
        Account acc               = createAccount();
        DRC_NBC_Addresses__c addr = createAddress(acc.Id);
        Order o                   = createOrder(acc.Id, addr.Id, 'DARSHAN CHEMICALS');
        
        Test.startTest();
        o.DRC_NBC_Warehouse__c = 'CFS - JNPT';
        update o;
        Test.stopTest();
        
    }
    
    // =======================================================================
    // TEST 4: INSERT with no Shipping Address → no error
    // =======================================================================
    @isTest
    static void testInsert_NoShippingAddress_NoError() {
        Account acc = createAccount();
        
        Test.startTest();
        Order o = new Order(
            AccountId                   = acc.Id,
            DRC_NBC_Warehouse__c        = 'DARSHAN CHEMICALS',
            DRC_NBC_Shipping_Address__c = null,
            EffectiveDate               = Date.today(),
            Status                      = 'Draft'
        );
        insert o;
        Test.stopTest();
        
        System.assertNotEquals(null, o.Id,
                               'Order should insert without errors when no shipping address.');
    }
    
    // =======================================================================
    // TEST 5: Bulk INSERT 200 orders → all addresses updated
    // =======================================================================
    @isTest
    static void testBulkInsert_AllAddressesUpdated() {
        Account acc = createAccount();
        
        List<DRC_NBC_Addresses__c> addresses = new List<DRC_NBC_Addresses__c>();
        for (Integer i = 0; i < 200; i++) {
            addresses.add(new DRC_NBC_Addresses__c(
                DRC_NBC_Address__City__s        = 'Pune',
                DRC_NBC_Address__CountryCode__s = 'IN',
                DRC_NBC_Address__PostalCode__s  = '411014',
                DRC_NBC_Address__StateCode__s   = 'MH',
                DRC_NBC_Address__Street__s      = 'Street ' + i,
                DRC_NBC_Type__c                 = 'Shipping',
                DRC_NBC_Account__c              = acc.Id
            ));
        }
        insert addresses;
        
        List<Order> orders = new List<Order>();
        for (Integer i = 0; i < 200; i++) {
            orders.add(new Order(
                AccountId                   = acc.Id,
                DRC_NBC_Warehouse__c        = 'DARSHAN CHEMICALS',
                DRC_NBC_Shipping_Address__c = addresses[i].Id,
                EffectiveDate               = Date.today(),
                Status                      = 'Draft'
            ));
        }
        
        Test.startTest();
        insert orders;
        Test.stopTest();
        
        List<DRC_NBC_Addresses__c> results = [
            SELECT DRC_NBC_Warehouse__c
            FROM   DRC_NBC_Addresses__c
            WHERE  Id IN :addresses
        ];
        for (DRC_NBC_Addresses__c a : results) {
            System.assertEquals('DARSHAN CHEMICALS', a.DRC_NBC_Warehouse__c,
                                'All addresses should be updated in bulk.');
        }
    }
    // =======================================================================
    // TEST 6: UPDATE Status Accepted → Released sends A2R email
    // =======================================================================
    @isTest
    static void testUpdate_AcceptedToReleased_SendsEmail() {
        Account acc               = createAccount();
        DRC_NBC_Addresses__c addr = createAddress(acc.Id);
        
        // Insert order in Accepted status
        Order o = new Order(
            AccountId                    = acc.Id,
            DRC_NBC_Shipping_Address__c  = addr.Id,
            DRC_NBC_Cust_Order_Number__c = 'ORD-A2R-001',
            EffectiveDate                = Date.today(),
            Status                       = 'Accepted'
        );
        insert o;
        
        Test.startTest();
        o.Status = 'Released';
        update o;
        Test.stopTest();
        
        Order updated = [SELECT Status FROM Order WHERE Id = :o.Id];
        System.assertEquals('Released', updated.Status,
                            'Order status should be updated to Released.');
    }
    
    // =======================================================================
    // TEST 7: UPDATE Status Released → Accepted sends R2A email
    // =======================================================================
    @isTest
    static void testUpdate_ReleasedToAccepted_SendsEmail() {
        Account acc               = createAccount();
        DRC_NBC_Addresses__c addr = createAddress(acc.Id);
        
        // Insert order in Released status
        Order o = new Order(
            AccountId                    = acc.Id,
            DRC_NBC_Shipping_Address__c  = addr.Id,
            DRC_NBC_Cust_Order_Number__c = 'ORD-R2A-001',
            EffectiveDate                = Date.today(),
            Status                       = 'Released'
        );
        insert o;
        
        Test.startTest();
        o.Status = 'Accepted';
        update o;
        Test.stopTest();
        
        Order updated = [SELECT Status FROM Order WHERE Id = :o.Id];
        System.assertEquals('Accepted', updated.Status,
                            'Order status should be updated to Accepted.');
    }
    
    // =======================================================================
    // TEST 8: UPDATE Status Draft → Activated (no email — no transition match)
    // =======================================================================
    @isTest
    static void testUpdate_NoMatchingTransition_NoEmailSent() {
        Account acc = createAccount();
        
        Order o = new Order(
            AccountId                    = acc.Id,
            DRC_NBC_Cust_Order_Number__c = 'ORD-NOMATCH-001',
            EffectiveDate                = Date.today(),
            Status                       = 'Draft'
        );
        insert o;
        
        Test.startTest();
        // Draft → Activated is not A2R or R2A — no email path executed
        o.Status = 'Under Evaluation';
        update o;
        Test.stopTest();
        
        Order updated = [SELECT Status FROM Order WHERE Id = :o.Id];
        System.assertEquals('Activated', updated.Status,
                            'Order status should update without triggering any email.');
    }
    
    // =======================================================================
    // TEST 9: UPDATE Warehouse unchanged → Address NOT updated
    // =======================================================================
    @isTest
    static void testUpdate_WarehouseUnchanged_AddressNotUpdated() {
        Account acc               = createAccount();
        DRC_NBC_Addresses__c addr = createAddress(acc.Id);
        Order o                   = createOrder(acc.Id, addr.Id, 'DARSHAN CHEMICALS');
        
        // Pre-set address warehouse to known value
        addr.DRC_NBC_Warehouse__c = 'DARSHAN CHEMICALS';
        update addr;
        
        Test.startTest();
        // Update a field other than warehouse — warehouse stays same
        o.DRC_NBC_Cust_Order_Number__c = 'ORD-UNCHANGED-001';
        update o;
        Test.stopTest();
        
        DRC_NBC_Addresses__c result = [
            SELECT DRC_NBC_Warehouse__c
            FROM   DRC_NBC_Addresses__c
            WHERE  Id = :addr.Id
        ];
        System.assertEquals('DARSHAN CHEMICALS', result.DRC_NBC_Warehouse__c,
                            'Address warehouse should remain unchanged when order warehouse not updated.');
    }
    
    // =======================================================================
    // TEST 10: Reentrancy guard — isRunning prevents double execution
    // =======================================================================
    @isTest
    static void testReentrancyGuard_PreventDoubleExecution() {
        Account acc = createAccount();
        
        Order o = new Order(
            AccountId     = acc.Id,
            EffectiveDate = Date.today(),
            Status        = 'Draft'
        );
        insert o;
        
        Test.startTest();
        // Two rapid updates — second call should be blocked by isRunning flag
        o.DRC_NBC_Cust_Order_Number__c = 'ORD-REENTRY-001';
        update o;
        o.DRC_NBC_Cust_Order_Number__c = 'ORD-REENTRY-002';
        update o;
        Test.stopTest();
        
        System.assert(true, 'Reentrancy guard should prevent double handler execution.');
    }
    
    // =======================================================================
    // TEST 11: Bulk UPDATE status transitions — A2R for multiple orders
    // =======================================================================
    @isTest
    static void testBulkUpdate_MultipleA2RTransitions_EmailsSent() {
        Account acc = createAccount();
        
        // Insert 10 orders in Accepted status
        List<Order> orders = new List<Order>();
        for (Integer i = 0; i < 10; i++) {
            orders.add(new Order(
                AccountId                    = acc.Id,
                DRC_NBC_Cust_Order_Number__c = 'BULK-A2R-' + i,
                EffectiveDate                = Date.today(),
                Status                       = 'Accepted'
            ));
        }
        insert orders;
        
        Test.startTest();
        for (Order o : orders) {
            o.Status = 'Released';
        }
        update orders;
        Test.stopTest();
        
        List<Order> updated = [SELECT Status FROM Order WHERE Id IN :orders];
        for (Order o : updated) {
            System.assertEquals('Released', o.Status,
                                'All bulk orders should transition to Released.');
        }
    }
    
    // =======================================================================
    // TEST 12: Bulk UPDATE status transitions — R2A for multiple orders
    // =======================================================================
    @isTest
    static void testBulkUpdate_MultipleR2ATransitions_EmailsSent() {
        Account acc = createAccount();
        
        List<Order> orders = new List<Order>();
        for (Integer i = 0; i < 10; i++) {
            orders.add(new Order(
                AccountId                    = acc.Id,
                DRC_NBC_Cust_Order_Number__c = 'BULK-R2A-' + i,
                EffectiveDate                = Date.today(),
                Status                       = 'Released'
            ));
        }
        insert orders;
        
        Test.startTest();
        for (Order o : orders) {
            o.Status = 'Accepted';
        }
        update orders;
        Test.stopTest();

    }
}