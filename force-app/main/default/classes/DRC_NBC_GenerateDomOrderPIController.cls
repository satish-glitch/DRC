public class DRC_NBC_GenerateDomOrderPIController {
    
    public String orderNumber { get; set; }
    public String CustOrdNum { get; set; }
    public Date orderDate { get; set; }
    public Date shipmentDate { get; set; }
    public String purchaseOrderNo { get; set; }
    public String SalesPerson { get; set; }
    public String importSequence { get; set; }
    public String exportSequence { get; set; }

    public String customerName { get; set; }
    public String customerNumber { get; set; }
    public String shippingAddress { get; set; }
    public String shippingCity { get; set; }
    public String shippingPostalCode { get; set; }
    public String shippingCountry { get; set; }
    public String shippingState { get; set; }
    public String orderType { get; set; }
    public String billToCustomer { get; set; }
    public String CustomerGSTRegNo { get; set; }

    public String billingAddress { get; set; }
    public String billingCity { get; set; }
    public String billingPostalCode { get; set; }
    public String billingCountry { get; set; }
    public String billingState { get; set; }

    public Decimal cgst { get; set; }
    public Decimal sgst { get; set; }
    public Decimal igst { get; set; }
    public Decimal otherTaxes { get; set; }
    public Decimal tcs { get; set; }
    public Decimal charges { get; set; }

    public Decimal totalWithoutTax { get; set; }
    public Decimal totalWithTax { get; set; }

    public String paymentTerms { get; set; }
    public String shipmentMethod { get; set; }
    public String prepaymentPayment { get; set; }
    public String transporter { get; set; }
    public String agent { get; set; }

    public String email { get; set; }
    public String phoneNumber { get; set; }
    public String website { get; set; }
    public String Bank { get; set; }
    public String AccountNo { get; set; }

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
        public String packingDetails { get; set; }
    }

    public DRC_NBC_GenerateDomOrderPIController() {
        Id orderId = ApexPages.currentPage().getParameters().get('id');

        if (orderId == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Missing Order Id.'));
            return;
        }

        Order ord = [
            SELECT Id,
                   AccountId,
                   OrderNumber,
                   EffectiveDate,
                   OwnerId,
                   Owner.Name,
                   DRC_NBC_Import_Starting_Sequence__c,
                   Account.Name,
                   Account.AccountNumber,
                   CurrencyIsoCode,
                   DRC_NBC_Invoice_Export_Sequence_Number__c,
                   ShippingStreet,
                   ShippingCity,
                   ShippingState,
                   ShippingPostalCode,
                   ShippingCountry,
                   DRC_NBC_Cust_Order_Number__c,
                   Account.BillingStreet,
                   Account.BillingCity,
                   Account.BillingState,
                   Account.BillingPostalCode,
                   Account.BillingCountry,
                   DRC_NBC_C_GST__c,
                   DRC_NBC_I_GST__c,
                   DRC_NBC_S_GST__c,
                   DRC_NBC_Prepayment_Method__c,
                   DRC_NBC_Shipment_Method__c,
                   DRC_NBC_Other_Tax_Amount__c,
                   DRC_NBC_TCS_Amount__c,
                   DRC_NBC_Transporter_Name__c,
                   DRC_NBC_Inco_Terms__c,
                   DRC_NBC_Terms_and_Conditions__c,
                   DRC_NBC_Shipment_Date__c,
                   DRC_NBC_Transport_Agent__c,
                   DRC_NBC_Payment_Term_Description__c,
                   DRC_NBC_Type__c,
                   Account.DRC_NBC_Customer_Number__c,
                   Account.DRC_NBC_GST_Number__c,
                   Account.DRC_NBC_Consignee_Bank_Name__c,
                   Account.DRC_NBC_Consignee_Bank_Account_Number__c,
                   PoNumber
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        orderType = ord.DRC_NBC_Type__c;
        assignOrderSequenceNumber(ord);

        orderNumber = ord.OrderNumber;
        CustOrdNum = ord.DRC_NBC_Cust_Order_Number__c;
        orderDate = ord.EffectiveDate;
        shipmentDate = ord.DRC_NBC_Shipment_Date__c;
        purchaseOrderNo = ord.PoNumber != null ? ord.PoNumber : ' ';
        SalesPerson = ord.Owner.Name;
        prepaymentPayment = ord.DRC_NBC_Prepayment_Method__c;
        billToCustomer = ord.Account.DRC_NBC_Customer_Number__c;
        CustomerGSTRegNo = ord.Account.DRC_NBC_GST_Number__c;

        customerName = ord.Account.Name;
        customerNumber = ord.Account.AccountNumber;

        shippingAddress = ord.ShippingStreet != null ? ord.ShippingStreet : '';
        shippingCity = ord.ShippingCity != null ? ord.ShippingCity : '';
        shippingState = ord.ShippingState != null ? ord.ShippingState : '';
        shippingPostalCode = ord.ShippingPostalCode != null ? ord.ShippingPostalCode : '';
        shippingCountry = ord.ShippingCountry != null ? ord.ShippingCountry : '';

        billingAddress = ord.Account.BillingStreet != null ? ord.Account.BillingStreet : '';
        billingCity = ord.Account.BillingCity != null ? ord.Account.BillingCity : '';
        billingState = ord.Account.BillingState != null ? ord.Account.BillingState : '';
        billingPostalCode = ord.Account.BillingPostalCode != null ? ord.Account.BillingPostalCode : '';
        billingCountry = ord.Account.BillingCountry != null ? ord.Account.BillingCountry : '';

        cgst = ord.DRC_NBC_C_GST__c != null ? ord.DRC_NBC_C_GST__c : 0;
        sgst = ord.DRC_NBC_S_GST__c != null ? ord.DRC_NBC_S_GST__c : 0;
        igst = ord.DRC_NBC_I_GST__c != null ? ord.DRC_NBC_I_GST__c : 0;
        otherTaxes = ord.DRC_NBC_Other_Tax_Amount__c != null ? ord.DRC_NBC_Other_Tax_Amount__c : 0;
        tcs = ord.DRC_NBC_TCS_Amount__c != null ? ord.DRC_NBC_TCS_Amount__c : 0;
        charges = 0;

        paymentTerms = ord.DRC_NBC_Payment_Term_Description__c;
        shipmentMethod = ord.DRC_NBC_Inco_Terms__c;
        transporter = ord.DRC_NBC_Transporter_Name__c != null ? ord.DRC_NBC_Transporter_Name__c.toUpperCase() : '';
        agent = ord.DRC_NBC_Transport_Agent__c != null ? ord.DRC_NBC_Transport_Agent__c.toUpperCase() : '';

        email = Label.DRC_NBC_Email;
        phoneNumber = Label.DRC_NBC_Phone;
        website = Label.DRC_NBC_Website;
        Bank = Label.DRC_NBC_Bank;
        AccountNo = Label.DRC_NBC_AccountNo;

        if (ord.DRC_NBC_Type__c == 'Domestic' && ord.DRC_NBC_Import_Starting_Sequence__c != null) {
            importSequence = String.valueOf(ord.DRC_NBC_Import_Starting_Sequence__c.intValue());
        }

        if (ord.DRC_NBC_Type__c == 'Export' && ord.DRC_NBC_Invoice_Export_Sequence_Number__c != null) {
            exportSequence = String.valueOf(ord.DRC_NBC_Invoice_Export_Sequence_Number__c.intValue());
        }

        List<OrderItem> orderItems = [
            SELECT Id,
                   OrderId,
                   Product2Id,
                   Product2.Name,
                   Product2.ProductCode,
                   Product2.QuantityUnitOfMeasure,
                   Product2.DRC_NBC_HSN_SAC_Code__c,
                   Product2.DRC_NBC_FG_Code__c,
                   Quantity,
                   UnitPrice,
                   TotalPrice,
                   DRC_NBC_Unit_Of_Measurement__c,
                   DRC_NBC_Packing_Size__c,
                   Description
            FROM OrderItem
            WHERE OrderId = :orderId
            ORDER BY CreatedDate
        ];

        Set<Id> productIds = new Set<Id>();

        for (OrderItem oi : orderItems) {
            if (oi.Product2Id != null) {
                productIds.add(oi.Product2Id);
            }
        }

        Map<Id, String> productIdToCustomerProductCode = new Map<Id, String>();

        if (ord.AccountId != null && !productIds.isEmpty()) {
            for (DRC_NBC_Restricted_Product__c rp : [
                SELECT Id,
                       DRC_NBC_Customer__c,
                       DRC_NBC_Product__c,
                       DRC_NBC_Customer_s_Product_code__c
                FROM DRC_NBC_Restricted_Product__c
                WHERE DRC_NBC_Customer__c = :ord.AccountId
                AND DRC_NBC_Product__c IN :productIds
            ]) {
                productIdToCustomerProductCode.put(
                    rp.DRC_NBC_Product__c,
                    rp.DRC_NBC_Customer_s_Product_code__c
                );
            }
        }

        items = new List<OrderItemWrapper>();
        totalWithoutTax = 0;

        for (OrderItem oi : orderItems) {
            OrderItemWrapper wrap = new OrderItemWrapper();

            wrap.itemCode = oi.Product2.ProductCode;
            wrap.itemName = oi.Product2.Name;

            if (productIdToCustomerProductCode.containsKey(oi.Product2Id)
                && String.isNotBlank(productIdToCustomerProductCode.get(oi.Product2Id))) {
                wrap.referenceNo = productIdToCustomerProductCode.get(oi.Product2Id);
            } else {
                wrap.referenceNo = '';
            }

            wrap.quantity = oi.Quantity;
            wrap.unit = oi.Product2.QuantityUnitOfMeasure;
            wrap.unitPrice = oi.UnitPrice;
            wrap.amount = oi.TotalPrice;
            wrap.HSN_SAC = oi.Product2.DRC_NBC_HSN_SAC_Code__c;
            wrap.Description = oi.Product2.Name;
            wrap.packingDetails = oi.DRC_NBC_Packing_Size__c;

            totalWithoutTax += oi.TotalPrice;
            items.add(wrap);
        }

        totalWithTax = totalWithoutTax + cgst + sgst + igst + otherTaxes + tcs + charges;
    }

    private void assignOrderSequenceNumber(Order ord) {
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