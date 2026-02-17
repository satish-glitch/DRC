@isTest
private class DRC_NBC_OrderTriggerHandlerTest {

    // ── Helper: create Account ─────────────────────────────────────────────
    private static Account createAccount() {
        Account acc = new Account(Name = 'Test Account');
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
}