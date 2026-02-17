/**
* @File Name        : Generate_Order_PI_Controller.cls
* @Description      : Controller class for Domestic PI Order visualforce page
* @Author           : Satish Yadav
* @Last Modified By : Satish Yadav
* @Last Modified On : October 22, 2025
* @Modification Log :
*==============================================================================
* Ver   | Date           | Author       | Modification
*==============================================================================
* 1.0   | October 22, 2025 | Satish Yadav | Initial Version
* 1.1   | October 22, 2025 | Satish Yadav | Added additional fields
**/

public class DRC_NBC_GenerateSamplePiController {
    
    // Order Information
    public String orderNumber { get; set; }
    public Date orderDate { get; set; }
    public Date shipmentDate { get; set; }
    public String purchaseOrderNo { get; set; }
    public String SalesPerson { get; set; }
    public String importSequence { get; set; }
    public String exportSequence { get; set; }
    // Customer Information
    public String customerName { get; set; }
    public String customerGST { get; set; }
    public String customerNumber { get; set; }
    public String shippingAddress { get; set; }
    public String shippingCity { get; set; }
    public String shippingPostalCode { get; set; }
    public String shippingCountry { get; set; }
    public String shippingState { get; set; }
    public String orderType { get; set; }
    public string billToCustomer {get; set;}
    
    
    public String billingAddress { get; set; }
    public String billingCity { get; set; }
    public String billingPostalCode { get; set; }
    public String billingCountry { get; set; }
    public String billingState { get; set; }
    
    // Tax Information
    public String gstin { get; set; }
    public String pan { get; set; }
    
    // Totals
    public Decimal totalWithoutTax { get; set; }
    public Decimal totalWithTax { get; set; }
    
    // Terms and Logistics
    public String paymentTerms { get; set; }
    public String shipmentMethod { get; set; }
    public String prepaymentPayment { get; set; }
    public String SampleName { get; set; }
    public String sampleType { get; set; }
    public String couriernumber { get; set; }
    public String deliveryStatus { get; set; }
    public Date ExpectedDeliveryDate {get; Set;}
    
    // Contact Information
    public String email { get; set; }
    public String phoneNumber { get; set; }
    public String website { get; set; }
    public String Bank { get; set; }
    public String AccountNo { get; set; }
    public Decimal sampleShipping { get; set; }
    
    // Order Items
    public List<OrderItemWrapper> items { get; set; }
    
    public class OrderItemWrapper {
        public String itemCode { get; set; }
        public String itemName { get; set; }
        public String referenceNo { get; set; }
        public Decimal quantity { get; set; }
        public String unit { get; set; }
        public String HSN_SAC { get; set; }
        public Decimal unitPrice { get; set; }
        public Decimal amount { get; set; }
        public String Description { get; set; }
        
    }
    
    public DRC_NBC_GenerateSamplePiController() {
        Id orderId = ApexPages.currentPage().getParameters().get('id');
        if (orderId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Missing Order Id.'));
            return;
        }
        
        // Fetch order with all required fields
        Order ord = [
            SELECT 
            Id, 
            OrderNumber,
            EffectiveDate,
            OwnerId,
            Owner.Name,
            Account.Name,
            Account.DRC_NBC_GST_Number__c,
            Account.DRC_NBC_Customer_Number__c,
            CurrencyIsoCode,
            DRC_NBC_Invoice_Export_Sequence_Number__c,
            DRC_NBC_Import_Starting_Sequence__c, 
            ShippingStreet,
            ShippingCity,
            ShippingState,
            ShippingPostalCode,
            ShippingCountry,
            BillingStreet,
            BillingCity,
            BillingState,
            BillingPostalCode,
            BillingCountry,
            Type, 
            DRC_NBC_Sample_Type__c,
            DRC_NBC_Sample_Amount__c,
            DRC_NBC_Sample_Shipping_Cost__c,
            DRC_NBC_Expected_Delivery_Date__c, 
            DRC_NBC_Sample_Sequence_Number__c,
            DRC_NBC_Sample_Name__c, 
            DRC_NBC_Payment_Terms__c, 
            DRC_NBC_Delivery_status__c, 
            DRC_NBC_Courier_Number__c
            FROM 
            Order
            WHERE 
            Id = :orderId
            LIMIT 1
        ];
        assignOrderSequenceNumber(ord); 
        // Order Information
        orderNumber = ord.OrderNumber;
        orderDate = ord.EffectiveDate;
        SalesPerson = ord.Owner.Name;
        customerName = ord.Account.Name;
        billToCustomer = ord.Account.DRC_NBC_Customer_Number__c;
        customerGST = ord.Account.DRC_NBC_GST_Number__c;
        ExpectedDeliveryDate = ord.DRC_NBC_Expected_Delivery_Date__c;
        couriernumber = ord.DRC_NBC_Courier_Number__c;
        deliveryStatus = ord.DRC_NBC_Delivery_status__c;
        sampleShipping = ord.DRC_NBC_Sample_Shipping_Cost__c;
        
        // Shipping Address
        shippingAddress = (ord.ShippingStreet != null ? ord.ShippingStreet : '');
        shippingCity = (ord.ShippingCity != null ? ord.ShippingCity : '');
        shippingState = (ord.ShippingState != null ? ord.ShippingState : '');
        shippingPostalCode = (ord.ShippingPostalCode != null ? ord.ShippingPostalCode : '');
        shippingCountry = (ord.ShippingCountry != null ? ord.ShippingCountry : '');
        
        // Billing Address
        billingAddress = (ord.BillingStreet != null ? ord.BillingStreet : '');
        billingCity = (ord.BillingCity != null ? ord.BillingCity : '');
        billingState = (ord.BillingState != null ? ord.BillingState : '');
        billingPostalCode = (ord.BillingPostalCode != null ? ord.BillingPostalCode : '');
        billingCountry = (ord.BillingCountry != null ? ord.BillingCountry : '');
        
        
        // Terms and Logistics
        paymentTerms = ord.DRC_NBC_Payment_Terms__c;
        shipmentMethod = String.valueOf(ord.DRC_NBC_Sample_Shipping_Cost__c);
        SampleName = ord.DRC_NBC_Sample_Name__c != null ? ord.DRC_NBC_Sample_Name__c.toUpperCase() : '';
        sampleType = ord.DRC_NBC_Sample_Type__c != null ? ord.DRC_NBC_Sample_Type__c.toUpperCase() : '';
        // Contact Information
        email = Label.DRC_NBC_Email;
        phoneNumber = Label.DRC_NBC_Phone;
        website = Label.DRC_NBC_Website;
        Bank = Label.DRC_NBC_Bank;
        AccountNo = Label.DRC_NBC_AccountNo;
        // Assign the import/export sequence display values
        if (ord.Type == 'Sample Order' && ord.DRC_NBC_Sample_Sequence_Number__c != null) {
            importSequence = String.valueOf(ord.DRC_NBC_Sample_Sequence_Number__c.intValue());
        }
        
        // Fetch Order Items
        List<OrderItem> orderItems = [
            SELECT 
            Product2.Name,
            Product2.ProductCode,
            Quantity, UnitPrice,
            TotalPrice,
            Product2.QuantityUnitOfMeasure, 
            DRC_NBC_Unit_Of_Measurement__c,
            Product2.DRC_NBC_HSN_SAC_Code__c, 
            Product2.DRC_NBC_FG_Code__c,
            Description,
            order.DRC_NBC_Sample_Shipping_Cost__c
            FROM 
            OrderItem
            WHERE 
            OrderId = :orderId
            ORDER BY CreatedDate
        ];
        
        items = new List<OrderItemWrapper>();
        totalWithoutTax = 0;
        
        for (OrderItem oi : orderItems) {
            OrderItemWrapper wrap = new OrderItemWrapper();
            wrap.itemCode = oi.Product2.ProductCode;
            wrap.itemName = oi.Product2.Name;
            wrap.referenceNo = oi.Product2.DRC_NBC_FG_Code__c;
            wrap.quantity = oi.Quantity;
            wrap.unit = oi.Product2.QuantityUnitOfMeasure; 
            wrap.unitPrice = oi.UnitPrice;
            wrap.amount = oi.TotalPrice;
            wrap.HSN_SAC = oi.Product2.DRC_NBC_HSN_SAC_Code__c;
            wrap.Description = oi.Product2.Name;
            totalWithoutTax += oi.TotalPrice;
            items.add(wrap);
        }
        
        // Calculate total with tax
        totalWithTax = totalWithoutTax + sampleShipping;
    }
    
    private void assignOrderSequenceNumber(Order ord) {
        // Assign sequence for Import Orders
        if (ord.Type != null &&
            ord.Type == 'Sample Order' &&
            ord.DRC_NBC_Sample_Sequence_Number__c == null) {
                
                AggregateResult[] result = [
                    SELECT MAX(DRC_NBC_Sample_Sequence_Number__c) maxSeq
                    FROM Order
                    WHERE Type = 'Sample Order'
                ];
                
                Decimal maxDecimal = (result.size() > 0 && result[0].get('maxSeq') != null)
                    ? (Decimal) result[0].get('maxSeq')
                    : Decimal.valueOf(Label.DRC_NBC_Sample_Sequence_Number);
                
                ord.DRC_NBC_Sample_Sequence_Number__c = Decimal.valueOf(maxDecimal.intValue() + 1);
            }
    }
}