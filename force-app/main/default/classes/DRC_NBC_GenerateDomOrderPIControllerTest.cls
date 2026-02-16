@isTest
public class DRC_NBC_GenerateDomOrderPIControllerTest {
    
    @isTest
    static void testControllerInitialization() {
        // Setup data
        Account acc = DRC_NBC_TestFactory.createAccount();
        Product2 prod = DRC_NBC_TestFactory.createProduct();
        PricebookEntry pbe = DRC_NBC_TestFactory.createPricebookEntry(prod);
        Order ord = DRC_NBC_TestFactory.createOrder(acc, pbe);
        OrderItem oi = DRC_NBC_TestFactory.createOrderItem(ord, pbe);
        Test.startTest();
        ApexPages.currentPage().getParameters().put('id', ord.Id);
        DRC_NBC_GenerateDomOrderPIController ctrl = new DRC_NBC_GenerateDomOrderPIController();
        Test.stopTest();
    }
}