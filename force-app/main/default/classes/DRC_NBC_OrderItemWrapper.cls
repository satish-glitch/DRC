/**
* @File Name : DRC_NBC_OrderItemWrapper .cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : October 14, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 14, 2025 |   | Initial Version
**/


public class DRC_NBC_OrderItemWrapper {
    @AuraEnabled 
    public String QuoteLineItemId { get; set; }
    
    @AuraEnabled 
    public String Product2Id { get; set; }
    
    @AuraEnabled 
    public String PriceBookEntryId { get; set; }
    
    @AuraEnabled 
    public String Description { get; set; }
    
    @AuraEnabled 
    public Decimal Quantity { get; set; }
    
    @AuraEnabled 
    public Decimal UnitPrice { get; set; }
    
    @AuraEnabled 
    public String DRC_NBC_FG_Code  { get; set; }
    
    @AuraEnabled 
    public String DRC_NBC_HSN_Code { get; set; }

    @AuraEnabled 
    public String UOM { get; set; }

    @AuraEnabled
    public String DRC_NBC_Packing_Size { get; set; }

    @AuraEnabled 
    public String DRC_NBC_Packing_Quantity { get; set; }

     @AuraEnabled 
     public DRC_NBC_Generate_Order_Controller.Product2Wrapper Product2 { get; set; }
    
    // Default constructor (important for deserialization)
    public DRC_NBC_OrderItemWrapper() {
    }
}