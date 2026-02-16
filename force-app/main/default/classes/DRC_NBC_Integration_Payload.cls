/**
* @File Name : DRC_NBC_Integration_Payload.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : September 3, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 3, 2025 |   | Initial Version
**/

global with sharing class DRC_NBC_Integration_Payload {
    public class WebToLeadPayLoad{
        public String company;
        public String firstName;
        public String lastName;
        public String email;
        public String message;
        public String country;
        public String phone;
        public Set<String> applicationArea; 
        public Set<String> interestedChemistry;
        public String otherProduct;
    }
    global class productWithPriceBookPayload {
        global product product;
        global List<priceBook> priceBook;
    }
    
    global class productWithPriceBookPayloadLst {
        global List<productWithPriceBookPayload> products;
    }
    
    global class product {
        global String productName;
        global String FGCode;
        global String GST_Group_Code;
        global String HSNCode;
        global String packingSize;
       // global List<String> packingSize; 
        global String productFamily;
        global String uom;
        global Boolean isActive;
        global String ProductCategoryL1;
        global String ProductCategoryL2;
        global String ProductCategoryL3;
    }
    
    global class priceBook {
        global String priceBookExternalId;
        global String priceBookName;
        global Decimal bookEntryAmount;
        global String bookEntryExternalId;
        global String bookEntryCurrency;
    }
    // Payload for BC Account Integration
    global class CustomerPayload {
        public String No;
        public String Name;
        public String Currency_Code;
        public String Address;
        public String Address_2;
        public String Country_Region_Code;
        public String State_Code;
        public String City;
        public String Post_Code;
        public String P_A_N_No;
        public String GST_Registration_No;
        public String Phone_No;
        public String Mobile_Phone_No;
        public String E_Mail;
        public String Payment_Terms_Code;
        public String Shipment_Method_Code;
        public String Approval_Status;
    }
    
    
    // Payload for BC Account  Shipping Integration
    public class ShipToPayload {
        public String CustomerNo;
        public String ShiptoCode;
        public String Name;
        public String ShippingAddress;
        public String ShippingAddress2;
        public String ShippingCity;
        public String State;
        public String ShippingPostCode;
        public String ShippingCountry;
        public String ShippingPhoneNo;
        public String ShippingEmail;
        public String ShippingGSTRegistrationNo;
        public String Shipment_Method_Code;
        public String Location_Code;
    }
    
    public class OrderPayload {
        public String Document_Type;
        public String No;
        public String Sell_to_Customer_No;
        public String Sell_to_Customer_Name;
        public String Sell_to_Address;
        public String Sell_to_Address_2;
        public String Sell_to_Post_Code;
        public String Sell_to_City;
        public String Order_Date;
        public String Salesperson_Code;
        public String Status;
        public String Location_Code;
        public String Payment_Terms_Code;
        public String Shipment_Method_Code;
        public Boolean Sample_Sales;
        public String Salesforce_So_No;
        public String External_Document_No;
      /*  public String Ship_to_GST_Customer_Type;
        public String Ship_to_GST_Reg_No;*/
        public String Ship_to_Code;
        public String Ship_to_Country_Region_Code;
        public String Ship_to_Name;
        public String Ship_to_Name_2;
        public String Ship_to_Address;
        public String Ship_to_Address_2;
        public String Ship_to_Post_Code;
        public String Ship_to_City;
        Public Decimal Salesforce_Order_Amount;
        Public Boolean Salesforce_Order_Created;
        Public String Currency_Code;
        
        
    }
    
    public class OrderLinePayload {
        public String Document_Type;
        public String Document_No;
        public Integer Line_No;
        public String Type;
        public String No;
        public String Description;
        public String Location_Code;
        public Decimal Quantity;
        public String Unit_of_Measure_Code;
        public Decimal Unit_Price;
        public Decimal Line_Amount;
        public Decimal Line_Discount_Percent;
        public Decimal Line_Discount_Amount;
        public Decimal Inv_Discount_Amount;
        public String GST_Credit;
        public String HSN_SAC_Code;
        public String GST_Group_Code;
        public String Packing_Details;
        public Decimal No_of_Pkg_for_Qty;
    }
    
    public class BCResponse {
        public Boolean status { get; set; }
        public String message { get; set; }
        public Map<String, String> data { get; set; }
    }
    
    public class OrderStatusPayload {
        public String orderId;
        public String status;
        public String expectedDeliveryDate;
        public String trackingId;
        public String paymentTerms;
        public String incoTerms;
    }
    
    public class CustomerCreditLimitPayload {
        public String CustomerNumber;
        public Decimal CreditLimit;
        public String CurrencyCode;
        public String Status;
    }
    
    public class Response {
        public Boolean success;
        public String message;
    } 
    
    public class invoiceSyncPayload {
        public String InvoiceNumber;
        public Date InvoiceDate;
        Public String OrderNumber;
        public String ExternalDocumentNumber;
        public String IRNNumber;
        public String AcknowledgementNumber;
        Public String AcknowledgementDate;
        public String EWayBillNumber;
        Public String VehicleNumber;
        Public String PaymentTerms;
        Public String DeliveryLocation;   
        //  Public String CustomerDRCCode;
        Public String ShippingDRCCode;
        Public String ShippingCustomerName;
        Public String ShippingAddress;
        Public String ShippingGSTNumber;
        Public String ShippingState;
        Public String ShippingStateCode;
        public List<invoiceLineItem> lineItems;
    }
    
    public class invoiceLineItem {
        public String ProductCode;
        public Decimal Amount;
        public List<lotDetail> lotDetails;
    }
    
    public class lotDetail {
        public String lot;
        public Integer quantity;
    }
    
    
    public class SalesPersonResponseWrapper {
        public List<SalesPersonInfo> value;
    }
    
    public class SalesPersonInfo {
        public String Code;
        public String Name;
        public String E_Mail;
    } 
    
    
}