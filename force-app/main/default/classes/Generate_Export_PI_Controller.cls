public class Generate_Export_PI_Controller {
    
    public String companyName { get; set; }
    public String companyFooterAddress { get; set; }
    public String companyPhone { get; set; }
    public String companyFax { get; set; }
    public String companyWebsite { get; set; }
    
    public Order orderRecord { get; set; }
    
    // Shipper Information
    public String shipperName { get; set; }
    public String shipperAddress { get; set; }
    public String shipperCity { get; set; }
    public String shipperState { get; set; }
    public String shipperPostalCode { get; set; }
    public String shipperCountry { get; set; }
    public String orderType {get; set;}
    public String exportSequence {get; set;}
    
    // Consignee Information
    public String consigneeName { get; set; }
    public String consigneeAddress { get; set; }
    public String consigneeCity { get; set; }
    public String consigneeState { get; set; }
    public String consigneePostalCode { get; set; }
    public String consigneeCountry { get; set; }
    public String consigneePhone { get; set; }
    public String consigneeEmail { get; set; }
    
    // Bank Details (Dynamic)
    public String beneficiaryName { get; set; }
    public String bankName { get; set; }
    public String bankAddress { get; set; }
    public String accountNumber { get; set; }
    public String swiftCode { get; set; }
    public String ifscCode { get; set; }
    
    // Items & Totals
    public List<ExportLineItem> items { get; set; }
    public Decimal totalAmount { get; set; }
    public String amountInWords { get; set; }
    
    // Required Documents
    public List<String> requiredDocuments { get; set; }
    
    private Id recordId;
    
    public Generate_Export_PI_Controller() {
        recordId = ApexPages.currentPage().getParameters().get('id');
        items = new List<ExportLineItem>();
        requiredDocuments = new List<String>();
        
        if (recordId != null) {
            loadData();
        }
    }
    
    // ========================
    // LOAD ORDER + BANK + ITEMS
    // ========================
    private void loadData() {
        try {
            orderRecord = [
                SELECT Id, OrderNumber, EffectiveDate, PoNumber,
                Account.Name, Account.Phone, Account.Website,
                Account.BillingStreet, Account.BillingCity, Account.BillingState,
                Account.BillingPostalCode, Account.BillingCountry,
                BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry,
                ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                CurrencyIsoCode,
                DRC_NBC_Payment_Terms__c,
                DRC_NBC_Special_Instructions__c,
                DRC_NBC_Port_Of_Loading__c,
                DRC_NBC_Port_Of_Discharge__c,
                DRC_NBC_Final_Destination__c,
                DRC_NBC_Vessel_no_Flight_no__c,
                DRC_NBC_Country_Of_Origin__c,
                DRC_NBC_Trans_Shipment__c,
                DRC_NBC_Part_Shipment__c,
                DRC_NBC_Shipment_Method__c,
                DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c,
                DRC_NBC_Notify_Party__c,
                DRC_NBC_Country_of_Final_Destination__c,
                DRC_NBC_Inco_Terms__c,
                Quote.DRC_NBC_Delivery_Terms__c,
                DRC_NBC_Type__c,
                DRC_NBC_Invoice_Export_Sequence_Number__c,
                DRC_NBC_Select_Bank__c
                FROM Order
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            // Assign Export/Import sequence
            orderType = orderRecord.DRC_NBC_Type__c;
            assignOrderSequenceNumber(orderRecord);
            
            if (orderRecord.DRC_NBC_Type__c == 'Export' &&
                orderRecord.DRC_NBC_Invoice_Export_Sequence_Number__c != null) {
                    
                    exportSequence = 
                        String.valueOf(orderRecord.DRC_NBC_Invoice_Export_Sequence_Number__c.intValue());
                }
            
            // Company Info
            companyName = 'D.R. COATS INK & RESINS PVT. LTD.';
            companyFooterAddress = 
                '230, NEW SONAL LINK IND ESTATE, BLDG NO 2, LINK ROAD, MALAD W MUMBAI INDIA 400064';
            companyPhone = '91 022 6866 0700';
            companyFax = '91-22-28888189';
            companyWebsite = 'www.drcoats.com';
            
            // Consignee
            consigneeName = orderRecord.Account.Name;
            consigneeAddress = orderRecord.BillingStreet;
            consigneeCity = orderRecord.BillingCity;
            consigneeState = orderRecord.BillingState;
            consigneePostalCode = orderRecord.BillingPostalCode;
            consigneeCountry = orderRecord.BillingCountry;
            consigneePhone = orderRecord.Account.Phone;
            
            //  Load BANK DETAILS dynamically
            loadBankDetails();           
            // Load items
            loadLineItems();
            // Required documents
            setRequiredDocuments();
            
        } catch (Exception e) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR, 'Error: ' + e.getMessage())
            );
        }
    }
    
    // =====================
    // DYNAMIC BANK DETAILS
    // =====================
    private void loadBankDetails() {
        try {
            if (orderRecord.DRC_NBC_Select_Bank__c == null) {
                beneficiaryName = 'D.R. Coats Ink & Resins Pvt. Ltd.';
                bankName = '';
                bankAddress = '';
                accountNumber = '';
                swiftCode = '';
                ifscCode = '';
                return;
            }
            
            DRC_NBC_Bank_Master__mdt bank = [
                SELECT DRC_Name_Bank_Name__c, DRC_NBC_Bank_Address__c, DRC_NBC_Account_Number__c,
                DRC_NBC_Swift_Code__c, DRC_NBC_IFSC_Code__c
                FROM DRC_NBC_Bank_Master__mdt
                WHERE MasterLabel = :orderRecord.DRC_NBC_Select_Bank__c
                LIMIT 1
            ];
            
            beneficiaryName = 'D.R. Coats Ink & Resins Pvt. Ltd.';
            bankName = bank.DRC_Name_Bank_Name__c;
            bankAddress = bank.DRC_NBC_Bank_Address__c;
            accountNumber = bank.DRC_NBC_Account_Number__c;
            swiftCode = bank.DRC_NBC_Swift_Code__c;
            ifscCode = bank.DRC_NBC_IFSC_Code__c;
            
        } catch (Exception e) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR,
                                      'Bank details not found: ' + e.getMessage())
            );
        }
    }
    
    // =====================
    // LOAD LINE ITEMS
    // =====================
    private void loadLineItems() {
        try {
            List<OrderItem> orderItems = [
                SELECT Id, Quantity, UnitPrice, TotalPrice, Description,
                Product2.Name, Product2.ProductCode,
                Product2.DRC_NBC_HSN_SAC_Code__c,
                Product2.DRC_NBC_Hazardous__c,
                Product2.DRC_NBC_MARKS_NOS__c,
                Product2.DRC_NBC_KIND_OF_PKG__c
                FROM OrderItem
                WHERE OrderId = :recordId
            ];
            
            totalAmount = 0;
            
            for (OrderItem oi : orderItems) {
                ExportLineItem lineItem = new ExportLineItem();
                
                lineItem.marksAndNos = 
                    oi.Product2.DRC_NBC_MARKS_NOS__c != null ? 
                    oi.Product2.DRC_NBC_MARKS_NOS__c : oi.Product2.Name;
                
                lineItem.description = 
                    oi.Description != null ? oi.Description : oi.Product2.Name;
                
                String hazardousValue = String.valueOf(oi.Product2.DRC_NBC_Hazardous__c);
                lineItem.hazardous = 
                    (hazardousValue == 'true' || hazardousValue == 'Yes') ? 'Yes' : 'No';
                
                lineItem.hscCode = oi.Product2.DRC_NBC_HSN_SAC_Code__c;
                lineItem.kindOfPackage = oi.Product2.DRC_NBC_KIND_OF_PKG__c;
                
                lineItem.quantityKgs = oi.Quantity.setScale(2).toPlainString();
                lineItem.rate = oi.UnitPrice.setScale(2);
                lineItem.amount = oi.TotalPrice.setScale(2);
                
                items.add(lineItem);
                totalAmount += oi.TotalPrice;
            }
            
            amountInWords = 
                convertAmountToWords(totalAmount, orderRecord.CurrencyIsoCode);
            
        } catch (Exception e) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.ERROR,
                                      'Error loading items: ' + e.getMessage())
            );
        }
    }
    
    // ======================
    // REQUIRED DOCUMENTS
    // ======================
    private void setRequiredDocuments() {
        try {
            String docs = [
                SELECT DRC_NBC_Required_Documents__c 
                FROM Order 
                WHERE Id = :recordId 
                LIMIT 1
            ].DRC_NBC_Required_Documents__c;
            
            if (String.isNotBlank(docs)) {
                for (String doc : docs.split('[;\\n]+')) {
                    if (String.isNotBlank(doc)) {
                        requiredDocuments.add(doc.trim());
                    }
                }
            }
            
        } catch (Exception e) {
            ApexPages.addMessage(
                new ApexPages.Message(ApexPages.Severity.WARNING,
                                      'Docs not loaded: ' + e.getMessage())
            );
        }
    }
    
    // ======================
    // AMOUNT → WORDS
    // ======================
    private String convertAmountToWords(Decimal amount, String currencies) {
        if (amount == null) return '';
        
        Long wholePart = amount.longValue();
        Integer decimalPart = ((amount - wholePart) * 100).intValue();
        
        String result = convertNumberToWords(wholePart, currencies);
        
        if (decimalPart > 0) {
            result += ' AND ' + convertNumberToWords(decimalPart, currencies);
            result += (currencies == 'USD' || currencies == 'EUR' || currencies == 'GBP') 
                ? ' CENTS' : ' PAISE';
        } else {
            result += ' AND ZERO ' + 
                ((currencies == 'USD' || currencies == 'EUR' || currencies == 'GBP')
                 ? 'CENTS' : 'PAISE');
        }
        
        return result + ' ONLY';
    }
    
    private String convertNumberToWords(Long num, String currencies) {
        if (num == 0) return 'ZERO';
        
        String[] ones = 
            new String[]{'', 'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE', 'SIX', 'SEVEN', 'EIGHT', 'NINE'};
                String[] teens = 
                new String[]{'TEN', 'ELEVEN', 'TWELVE', 'THIRTEEN', 'FOURTEEN',
                    'FIFTEEN','SIXTEEN','SEVENTEEN','EIGHTEEN','NINETEEN'};
                        String[] tens = 
                        new String[]{'', '', 'TWENTY','THIRTY','FORTY','FIFTY','SIXTY','SEVENTY','EIGHTY','NINETY'};
                            
                            String result = '';
        Boolean isINR = currencies == 'INR';
        
        if (!isINR) {
            // International system: Billion, Million, Thousand
            if (num >= 1000000000) {
                result += convertNumberToWords(num / 1000000000, currencies) + ' BILLION ';
                num = Math.mod(num, 1000000000);
            }
            if (num >= 1000000) {
                result += convertNumberToWords(num / 1000000, currencies) + ' MILLION ';
                num = Math.mod(num, 1000000);
            }
            if (num >= 1000) {
                result += convertNumberToWords(num / 1000, currencies) + ' THOUSAND ';
                num = Math.mod(num, 1000);
            }
        } else {
            // Indian system: Crore, Lakh, Thousand
            if (num >= 10000000) {
                result += convertNumberToWords(num / 10000000, currencies) + ' CRORE ';
                num = Math.mod(num, 10000000);
            }
            if (num >= 100000) {
                result += convertNumberToWords(num / 100000, currencies) + ' LAKH ';
                num = Math.mod(num, 100000);
            }
            if (num >= 1000) {
                result += convertNumberToWords(num / 1000, currencies) + ' THOUSAND ';
                num = Math.mod(num, 1000);
            }
        }
        
        if (num >= 100) {
            result += ones[(Integer)(num / 100)] + ' HUNDRED ';
            num = Math.mod(num, 100);
        }
        if (num >= 20) {
            result += tens[(Integer)(num / 10)] + ' ';
            num = Math.mod(num, 10);
        } else if (num >= 10) {
            result += teens[(Integer)(num - 10)] + ' ';
            num = 0;
        }
        if (num > 0) {
            result += ones[num.intValue()] + ' ';
        }
        
        return result.trim();
    }
    
    // ======================
    // SEQUENCE NUMBERS
    // ======================
    private void assignOrderSequenceNumber(Order ord) {
        
        // DOMESTIC
        if (ord.DRC_NBC_Type__c == 'Domestic' &&
            ord.DRC_NBC_Import_Starting_Sequence__c == null) {
                
                AggregateResult[] result = [
                    SELECT MAX(DRC_NBC_Import_Starting_Sequence__c) maxSeq
                    FROM Order
                    WHERE DRC_NBC_Type__c = 'Domestic'
                ];
                
                Decimal maxDecimal = (result != null && result.size() > 0 
                                      && result[0].get('maxSeq') != null)
                    ? (Decimal) result[0].get('maxSeq')
                    : Decimal.valueOf(Label.DRC_NBC_Import_Starting_Sequence);
                
                ord.DRC_NBC_Import_Starting_Sequence__c = 
                    Decimal.valueOf(maxDecimal.intValue() + 1);
            }
        
        // EXPORT
        if (ord.DRC_NBC_Type__c == 'Export' &&
            ord.DRC_NBC_Invoice_Export_Sequence_Number__c == null) {
                
                AggregateResult[] result = [
                    SELECT MAX(DRC_NBC_Invoice_Export_Sequence_Number__c) maxSeq
                    FROM Order
                    WHERE DRC_NBC_Type__c = 'Export'
                ];
                
                Decimal maxDecimal = (result != null && result.size() > 0 
                                      && result[0].get('maxSeq') != null)
                    ? (Decimal) result[0].get('maxSeq')
                    : Decimal.valueOf(Label.DRC_NBC_Export_Starting_Sequence);
                
                ord.DRC_NBC_Invoice_Export_Sequence_Number__c = 
                    Decimal.valueOf(maxDecimal.intValue() + 1);
            }
    }
    public String getFormattedEffectiveDate() {
        if (orderRecord != null && orderRecord.EffectiveDate != null) {
            DateTime dt = DateTime.newInstance(orderRecord.EffectiveDate, Time.newInstance(0, 0, 0, 0));
            return dt.format('dd-MMM-yyyy'); // Example: 05-Feb-2026
        }
        return '';
    }


    
    // ======================
    // LINE ITEM CLASS
    // ======================
    public class ExportLineItem {
        public String marksAndNos { get; set; }
        public String description { get; set; }
        public String hazardous { get; set; }
        public String hscCode { get; set; }
        public String kindOfPackage { get; set; }
        public String quantityKgs { get; set; }
        public Decimal rate { get; set; }
        public Decimal amount { get; set; }
    }
}