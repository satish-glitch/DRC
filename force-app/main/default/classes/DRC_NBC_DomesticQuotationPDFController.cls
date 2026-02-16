public class DRC_NBC_DomesticQuotationPDFController {
    
    public Quote quoteRecord { get; set; }
    public List<QuoteLineItem> quoteLineItems { get; set; }
    public Decimal subtotal { get; set; }
    public Decimal cgstAmount { get; set; }
    public Decimal sgstAmount { get; set; }
    public Decimal igstAmount { get; set; }
    public Decimal otherTaxAmount { get; set; }
    public Decimal tcsAmount { get; set; }
    public Decimal totalAmount { get; set; }

    // ★ NEW: Full text for special instructions
    public String specialInstructions { get; set; }

    // Existing bullets list
    public List<String> specialRequirementList { get; set; }
    
    public DRC_NBC_DomesticQuotationPDFController(ApexPages.StandardController stdController) {
        Id quoteId = stdController.getId();
        
        // Fetch Quote details
        quoteRecord = [SELECT Id, Name, QuoteNumber, CreatedDate, ExpirationDate,
                       Account.Name, BillingStreet, BillingCity,BillingStateCode,Contact.Account.BillingStateCode,
                       BillingState, BillingPostalCode, BillingCountry, CurrencyISOCode,
                       ShippingStreet, ShippingCity, ShippingState, 
                       ShippingPostalCode, ShippingCountry,
                       Account.DRC_NBC_GST_Number__c, ShippingStateCode,
                       ShippingHandling, Tax, GrandTotal, Subtotal,
                       DRC_NBC_Payemnt_Term__c, DRC_NBC_Inco_terms__c, 
                       DRC_NBC_C_GST__c, DRC_NBC_S_GST__c, DRC_NBC_I_GST__c,
                       DRC_NBC_Type__c,
                       DRC_NBC_Import_Starting_Sequence__c, 
                       DRC_NBC_Grand_Total__c,
                       DRC_NBC_Invoice_Export_Sequence_Number__c,
                       DRC_NBC_Special_Requirements__c,
                       DRC_NBC_Other_Tax_Amount__c, DRC_NBC_TCS_Amount__c
                       FROM Quote 
                       WHERE Id = :quoteId];
        
        Integer generatedSequence = assignQuoteSequenceNumber(quoteRecord);
        
        if (generatedSequence != null) {
            if (quoteRecord.DRC_NBC_Type__c == 'Domestic') {
                quoteRecord.DRC_NBC_Import_Starting_Sequence__c = generatedSequence;
            } else if (quoteRecord.DRC_NBC_Type__c == 'Export') {
                quoteRecord.DRC_NBC_Invoice_Export_Sequence_Number__c = generatedSequence;
            }
        }

        // Fetch Quote Line Items
        quoteLineItems = [SELECT Id, Product2.Name, Quantity, UnitPrice, TotalPrice,
                          DRC_NBC_Unit_Of_Measurement__c,
                          Product2.QuantityUnitOfMeasure, Product2.DRC_NBC_HSN_SAC_Code__c, 
                          Product2.DRC_NBC_KIND_OF_PKG__c, Product2.CurrencyIsoCode,
                          Product2.Description
                          FROM QuoteLineItem 
                          WHERE QuoteId = :quoteId 
                          ORDER BY LineNumber];
        
        // Calculate amounts
        calculateAmounts();

        // ★ NEW — Full Special Instructions text with proper null/blank handling
        specialInstructions = quoteRecord.DRC_NBC_Special_Requirements__c;

         if (specialInstructions == null) {
             specialInstructions = '';
            } else {
            specialInstructions = specialInstructions.trim();
        }


        // Existing — Break into bullet points
        specialRequirementList = new List<String>();
        String specialReqRaw = quoteRecord.DRC_NBC_Special_Requirements__c;
          
        if (!String.isBlank(specialReqRaw)) {
            specialReqRaw = specialReqRaw.replace('\n', ' ').replace('\r', ' ');
            for (String part : specialReqRaw.split('\\.')) {
                if (!String.isBlank(part.trim())) {
                    specialRequirementList.add(part.trim());
                }
            }
        }
    }
    
    private void calculateAmounts() {
        subtotal = 0;
        
        for (QuoteLineItem qli : quoteLineItems) {
            subtotal += qli.TotalPrice != null ? qli.TotalPrice : 0;
        }
        
        cgstAmount = quoteRecord.DRC_NBC_C_GST__c != null ? quoteRecord.DRC_NBC_C_GST__c : 0;
        sgstAmount = quoteRecord.DRC_NBC_S_GST__c != null ? quoteRecord.DRC_NBC_S_GST__c : 0;
        igstAmount = quoteRecord.DRC_NBC_I_GST__c != null ? quoteRecord.DRC_NBC_I_GST__c : 0;
        otherTaxAmount = quoteRecord.DRC_NBC_Other_Tax_Amount__c != null ? quoteRecord.DRC_NBC_Other_Tax_Amount__c : 0;
        tcsAmount = quoteRecord.DRC_NBC_TCS_Amount__c != null ? quoteRecord.DRC_NBC_TCS_Amount__c : 0;
        
        totalAmount = quoteRecord.DRC_NBC_Grand_Total__c;
    }
    
    public String getFormattedDate(Date dt) {
        if (dt != null) {
            return dt.format();
        }
        return '';
    }
    
    
    private static Integer assignQuoteSequenceNumber(Quote quoteRec) {
        Integer newSequenceNumber;
        
        // Domestic logic
        if (quoteRec.DRC_NBC_Type__c == 'Domestic' &&
            quoteRec.DRC_NBC_Import_Starting_Sequence__c == null) {
                
            AggregateResult[] result = [
                SELECT MAX(DRC_NBC_Import_Starting_Sequence__c) maxSeq
                FROM Quote
                WHERE DRC_NBC_Type__c = 'Domestic'
            ];
                
            Decimal maxDecimal = (result.size() > 0 && result[0].get('maxSeq') != null)
                ? (Decimal) result[0].get('maxSeq')
                : Decimal.valueOf(Label.DRC_NBC_Import_Starting_Sequence);
                
            newSequenceNumber = maxDecimal.intValue() + 1;
            return newSequenceNumber;
        }
        
        // Export logic
        if (quoteRec.DRC_NBC_Type__c == 'Export' &&
            quoteRec.DRC_NBC_Invoice_Export_Sequence_Number__c == null) {
                
            AggregateResult[] result = [
                SELECT MAX(DRC_NBC_Invoice_Export_Sequence_Number__c) maxSeq
                FROM Quote
                WHERE DRC_NBC_Type__c = 'Export'
            ];
                
            Decimal maxDecimal = (result.size() > 0 && result[0].get('maxSeq') != null)
                ? (Decimal) result[0].get('maxSeq')
                : Decimal.valueOf(Label.DRC_NBC_Export_Starting_Sequence);
                
            newSequenceNumber = maxDecimal.intValue() + 1;
            return newSequenceNumber;
        }
        
        return null;
    }
}