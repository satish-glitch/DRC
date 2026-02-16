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

public class DRC_NBC_GenerateDomOrderPIController {
    
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
    public String customerNumber { get; set; }
    public String shippingAddress { get; set; }
    public String shippingCity { get; set; }
    public String shippingPostalCode { get; set; }
    public String shippingCountry { get; set; }
    public String shippingState { get; set; }
    public String orderType { get; set; }
      public String billToCustomer { get; set; }
    Public String CustomerGSTRegNo {get; set;}
    
    
    public String billingAddress { get; set; }
    public String billingCity { get; set; }
    public String billingPostalCode { get; set; }
    public String billingCountry { get; set; }
    public String billingState { get; set; }
    
    // Tax Information
    public String gstin { get; set; }
    public String pan { get; set; }
    public Decimal cgst { get; set; }
    public Decimal sgst { get; set; }
    public Decimal igst { get; set; }
    public Decimal otherTaxes { get; set; }
    public Decimal tcs { get; set; }
    public Decimal charges { get; set; }
    
    // Totals
    public Decimal totalWithoutTax { get; set; }
    public Decimal totalWithTax { get; set; }
    
    // Terms and Logistics
    public String paymentTerms { get; set; }
    public String shipmentMethod { get; set; }
    public String prepaymentPayment { get; set; }
    public String transporter { get; set; }
    public String agent { get; set; }
    
    // Contact Information
    public String email { get; set; }
    public String phoneNumber { get; set; }
    public String website { get; set; }
    public String Bank { get; set; }
    public String AccountNo { get; set; }
    
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
    
    public DRC_NBC_GenerateDomOrderPIController() {
        Id orderId = ApexPages.currentPage().getParameters().get('id');
        if (orderId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Missing Order Id.'));
            return;
        }
        
        
        
        // Fetch order with all required fields
        Order ord = [
            SELECT Id, OrderNumber, EffectiveDate, OwnerId,  Owner.Name,DRC_NBC_Import_Starting_Sequence__c, 
            Account.Name, Account.AccountNumber, CurrencyIsoCode, DRC_NBC_Invoice_Export_Sequence_Number__c,
            ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode,ShippingCountry,
            Account.BillingStreet, Account.BillingCity, Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
            DRC_NBC_C_GST__c, DRC_NBC_I_GST__c, DRC_NBC_S_GST__c,DRC_NBC_Prepayment_Method__c, DRC_NBC_Shipment_Method__c,
            DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c,DRC_NBC_Transporter_Name__c,
            DRC_NBC_Inco_Terms__c, DRC_NBC_Terms_and_Conditions__c, DRC_NBC_Shipment_Date__c, DRC_NBC_Transport_Agent__c,
            DRC_NBC_Payment_Terms__c, DRC_NBC_Type__c, Account.DRC_NBC_Customer_Number__c, Account.DRC_NBC_GST_Number__c, Account.DRC_NBC_Consignee_Bank_Name__c,
            Account.DRC_NBC_Consignee_Bank_Account_Number__c,
            PoNumber
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        this.orderType = ord.DRC_NBC_Type__c;
        assignOrderSequenceNumber(ord); 
        // Order Information
        orderNumber = ord.OrderNumber;
        orderDate = ord.EffectiveDate;
        shipmentDate = ord.DRC_NBC_Shipment_Date__c;
        purchaseOrderNo = ord.PoNumber != null ? ord.PoNumber : ' ';
        SalesPerson = ord.Owner.Name;
        prepaymentPayment = ord.DRC_NBC_Prepayment_Method__c;
        billToCustomer = ord.Account.DRC_NBC_Customer_Number__c;
        CustomerGSTRegNo =ord.Account.DRC_NBC_GST_Number__c;
        
        // Customer Information
        customerName = ord.Account.Name;
        customerNumber = ord.Account.AccountNumber;
        
        // Shipping Address
        shippingAddress = (ord.ShippingStreet != null ? ord.ShippingStreet : '');
        shippingCity = (ord.ShippingCity != null ? ord.ShippingCity : '');
        shippingState = (ord.ShippingState != null ? ord.ShippingState : '');
        shippingPostalCode = (ord.ShippingPostalCode != null ? ord.ShippingPostalCode : '');
        shippingCountry = (ord.ShippingCountry != null ? ord.ShippingCountry : '');
        
        // Billing Address
        billingAddress = (ord.Account.BillingStreet != null ? ord.Account.BillingStreet : '');
        billingCity = (ord.Account.BillingCity != null ? ord.Account.BillingCity : '');
        billingState = (ord.Account.BillingState != null ? ord.Account.BillingState : '');
        billingPostalCode = (ord.Account.BillingPostalCode != null ? ord.Account.BillingPostalCode : '');
        billingCountry = (ord.Account.BillingCountry != null ? ord.Account.BillingCountry : '');
        
        // Tax Information
        //   gstin = ord.Account.DRC_NBC_GST_Registration_Number__c;
        //   pan = ord.Account.DRC_NBC_PAN_Number__c;
        cgst = ord.DRC_NBC_C_GST__c != null ? ord.DRC_NBC_C_GST__c : 0;
        sgst = ord.DRC_NBC_S_GST__c != null ? ord.DRC_NBC_S_GST__c : 0;
        igst = ord.DRC_NBC_I_GST__c != null ? ord.DRC_NBC_I_GST__c : 0;
        otherTaxes = ord.DRC_NBC_Other_Tax_Amount__c != null ? ord.DRC_NBC_Other_Tax_Amount__c : 0;
        tcs = ord.DRC_NBC_TCS_Amount__c != null ? ord.DRC_NBC_TCS_Amount__c : 0;
        charges = 0; // Add field if available in Order object
        
        // Terms and Logistics
        paymentTerms = ord.DRC_NBC_Payment_Terms__c;
        shipmentMethod = ord.DRC_NBC_Shipment_Method__c;
        transporter = ord.DRC_NBC_Transporter_Name__c != null ? ord.DRC_NBC_Transporter_Name__c.toUpperCase() : '';
        agent = ord.DRC_NBC_Transport_Agent__c != null ? ord.DRC_NBC_Transport_Agent__c.toUpperCase() : '';
        // Contact Information
        email = Label.DRC_NBC_Email;
        phoneNumber = Label.DRC_NBC_Phone;
        website = Label.DRC_NBC_Website;
        Bank = Label.DRC_NBC_Bank;
        AccountNo = Label.DRC_NBC_AccountNo;
        // Assign the import/export sequence display values
        if (ord.DRC_NBC_Type__c == 'Domestic' && ord.DRC_NBC_Import_Starting_Sequence__c != null) {
            importSequence = String.valueOf(ord.DRC_NBC_Import_Starting_Sequence__c.intValue());
        }
        if (ord.DRC_NBC_Type__c == 'Export' && ord.DRC_NBC_Invoice_Export_Sequence_Number__c != null) {
            exportSequence = String.valueOf(ord.DRC_NBC_Invoice_Export_Sequence_Number__c.intValue());
        }
        
        // Fetch Order Items
        List<OrderItem> orderItems = [
            SELECT Product2.Name, Product2.ProductCode, Quantity, UnitPrice, TotalPrice, Product2.QuantityUnitOfMeasure,
            DRC_NBC_Unit_Of_Measurement__c, Product2.DRC_NBC_HSN_SAC_Code__c, Product2.DRC_NBC_FG_Code__c,
            Description
            FROM OrderItem
            WHERE OrderId = :orderId
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
            wrap.unit =  oi.Product2.QuantityUnitOfMeasure; 
            wrap.unitPrice = oi.UnitPrice;
            wrap.amount = oi.TotalPrice;
            wrap.HSN_SAC = oi.Product2.DRC_NBC_HSN_SAC_Code__c;
            wrap.Description = oi.Product2.Name;
            totalWithoutTax += oi.TotalPrice;
            items.add(wrap);
        }
        
        // Calculate total with tax
        totalWithTax = totalWithoutTax + cgst + sgst + igst + otherTaxes + tcs + charges;
    }
    
    private void assignOrderSequenceNumber(Order ord) {
        // Assign sequence for Import Orders
        if (ord.DRC_NBC_Type__c != null &&
            ord.DRC_NBC_Type__c == 'Domestic' &&
            ord.DRC_NBC_Import_Starting_Sequence__c == null) {
                
                AggregateResult[] result = [
                    SELECT MAX(DRC_NBC_Import_Starting_Sequence__c) maxSeq
                    FROM Order
                    WHERE DRC_NBC_Type__c = 'Domestic'
                ];
                
                Decimal maxDecimal = (result.size() > 0 && result[0].get('maxSeq') != null)
                    ? (Decimal) result[0].get('maxSeq')
                    : Decimal.valueOf(Label.DRC_NBC_Import_Starting_Sequence);
                
                ord.DRC_NBC_Import_Starting_Sequence__c = Decimal.valueOf(maxDecimal.intValue() + 1);
            }
        
        // Assign sequence for Export Orders
        if (ord.DRC_NBC_Type__c != null &&
            ord.DRC_NBC_Type__c == 'Export' &&
            ord.DRC_NBC_Invoice_Export_Sequence_Number__c == null) {
                
                AggregateResult[] result = [
                    SELECT MAX(DRC_NBC_Invoice_Export_Sequence_Number__c) maxSeq
                    FROM Order
                    WHERE DRC_NBC_Type__c = 'Export'
                ];
                
                Decimal maxDecimal = (result.size() > 0 && result[0].get('maxSeq') != null)
                    ? (Decimal) result[0].get('maxSeq')
                    : Decimal.valueOf(Label.DRC_NBC_Export_Starting_Sequence);
                
                ord.DRC_NBC_Invoice_Export_Sequence_Number__c = Decimal.valueOf(maxDecimal.intValue() + 1);
            }
    }
}