public class QuoteLineItemTableController {
    public Id quoteRecordId { get; set; }

    public List<QuoteLineItem> getQuoteLineItems() {
        return [
            SELECT Id,
                   Description,
                   Product2.Name,
                   Product2.DRC_NBC_HSN_SAC_Code__c,
                   Product2.DRC_NBC_KIND_OF_PKG__c,
                   UnitPrice,
                   Quantity,
                   TotalPrice
            FROM QuoteLineItem
            WHERE QuoteId = :quoteRecordId
        ];
    }
}