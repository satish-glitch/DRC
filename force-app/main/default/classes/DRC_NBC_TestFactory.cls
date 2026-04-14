@isTest
public class DRC_NBC_TestFactory {
    public static Account createAccount() {
        Account acc = new Account(
            Name = 'Test Customer',
            AccountNumber = 'CUST001',
            NBC_DRC_Account_DRC_Code__c = 'DRC-CODE-001',
            CurrencyIsoCode = 'INR',
            Phone = '1234567890',
            DRC_NBC_PAN_No__c = 'AWVPY9594J',
            DRC_NBC_GST_Number__c = '27AWVPY9594J1ZY',
            DRC_NBC_Payment_Term_Code__c = 'PDC90',
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
            Type = 'Analyst'
        );
        insert acc;
        return acc;
    }
    
    public static Product2 createProduct() {
        Product2 prod = new Product2(
            Name = 'Test Product',
            ProductCode = 'TP001',
            isActive = true,
            QuantityUnitOfMeasure = 'PCS',
            DRC_NBC_HSN_SAC_Code__c = 'HSN1234',
            DRC_NBC_FG_Code__c = 'FG001'
        );
        insert prod;
        return prod;
    }
    
    public static PricebookEntry createPricebookEntry(Product2 product) {
        // Step 1: Insert standard PricebookEntry
        Id standardPBId = Test.getStandardPricebookId();
        
        PricebookEntry standardPBE = new PricebookEntry(
            Pricebook2Id = standardPBId,
            Product2Id = product.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert standardPBE;
        
        // Step 2: Create custom pricebook
        Pricebook2 customPB = new Pricebook2(
            Name = 'Custom Pricebook',
            IsActive = true
        );
        insert customPB;
        
        // Step 3: Insert custom PricebookEntry
        PricebookEntry customPBE = new PricebookEntry(
            Pricebook2Id = customPB.Id,
            Product2Id = product.Id,
            UnitPrice = 100.00,
            IsActive = true
        );
        insert customPBE;
        
        return customPBE;
    }
    
    
    public static Order createOrder(Account acc, PricebookEntry pbe) {
        Order ord = new Order(
            AccountId = acc.Id,
            Status = 'Draft',
            EffectiveDate = Date.today(),
            Pricebook2Id = pbe.Pricebook2Id,
            DRC_NBC_Type__c = 'Domestic',
            DRC_NBC_Other_Tax_Amount__c = 2,
            DRC_NBC_TCS_Amount__c = 1,
            DRC_NBC_Shipment_Date__c = Date.today().addDays(10),
            DRC_NBC_Prepayment_Method__c = '100 % Advance',
            DRC_NBC_Payment_Terms__c = 'PDC90',
            DRC_NBC_Shipment_Method__c = 'By Air',
            DRC_NBC_Transporter_Name__c = 'TransCo',
            DRC_NBC_Transport_Agent__c = 'AgentX',
            ShippingStreet = '123 Test Street',
            ShippingCity = 'Mumbai',
            ShippingStateCode = 'MH',
            ShippingPostalCode = '400001',
            ShippingCountryCode = 'IN',
            BillingStreet = '456 Billing Street',
            BillingCity = 'Delhi',
            BillingStateCode = 'KA',
            BillingPostalCode = '110001',
            BillingCountryCode = 'IN',
            PoNumber = 'PO12345'
        );	
        insert ord; 
        return ord;
    }
    
    public static OrderItem createOrderItem(Order ord, PricebookEntry pbe) {
        OrderItem oi = new OrderItem(
            OrderId = ord.Id,
            Quantity = 10,
            UnitPrice = 100,
            PricebookEntryId = pbe.Id,
            Description = 'Test Order Item'
        );
        insert oi;
        return oi;
    }
    
}