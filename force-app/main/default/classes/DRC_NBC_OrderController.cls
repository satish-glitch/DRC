/**
* @File Name : DRC_NBC_OrderController.cls
* @Description : Controller for Order Edit functionality with Packing Size and Packing Quantity support
* @Author : Satish Yadav
* @Test_Class : DRC_NBC_OrderControllerTest
* @Last Modified By : Satish Yadav
* @Last Modified On : February 26, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 11, 2025 | Satish Yadav | Initial Version
* 1.1 | February 12, 2026 |              | Added Packing Size & Quantity fields
* 1.2 | February 26, 2026 |              | Packing Size/Qty now fetched from DRC_NBC_Packing_Details__c child object
**/

public class DRC_NBC_OrderController {

    @AuraEnabled(cacheable=true)
    public static Order getOrderRecord(Id orderId) {
        if (String.isBlank(orderId)) {
            throw new AuraHandledException('Order ID is required.');
        }

        try {
            Order ord = [
                SELECT Id,
                       OrderNumber,
                       Status,
                       Name,
                       EffectiveDate,
                       EndDate,
                       DRC_NBC_Type__c,
                       DRC_NBC_Payment_Terms__c,
                       DRC_NBC_Select_Bank__c,
                       DRC_NBC_Inco_Terms__c,
                       DRC_NBC_Warehouse__c,
                       Description,
                       DRC_NBC_Other_Rejection_Reason__c,
                       DRC_NBC_Reject_Reason_Text__c,
                       DRC_NBC_Terms_and_Conditions__c,
                       DRC_NBC_Special_Instructions__c,
                       PONumber,
                       PoDate,
                       Type,
                       OpportunityId,
                       QuoteId,
                       BillToContactId,
                       BillToContact.Name,
                       BillToContact.AccountId,
                       BillToContact.Account.Name,
                       ShipToContactId,
                       ShipToContact.Name,
                       ShipToContact.AccountId,
                       ShipToContact.Account.Name,
                       CurrencyIsoCode,
                       BillingCity,
                       BillingCountry,
                       BillingCountryCode,
                       BillingPostalCode,
                       BillingState,
                       BillingStateCode,
                       BillingStreet,
                       DRC_NBC_Shipping_Address__c,
                       ShippingCity,
                       ShippingCountry,
                       ShippingCountryCode,
                       ShippingPostalCode,
                       ShippingState,
                       ShippingStateCode,
                       ShippingStreet,
                       DRC_NBC_Transporter_Name__c,
                       DRC_NBC_Transport_Agent__c,
                       DRC_NBC_Shipment_Date__c,
                       DRC_NBC_Country_of_Origin__c,
                       DRC_NBC_Country_of_Final_Destination__c,
                       DRC_NBC_Shipment_Method__c,
                       DRC_NBC_Port_Of_Discharge__c,
                       DRC_NBC_Port_of_Loading__c,
                       DRC_NBC_Notify_Party__c,
                       DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c,
                       DRC_NBC_Prepayment_Method__c,
                       DRC_NBC_Vessel_no_Flight_no__c,
                       DRC_NBC_Part_Shipment__c,
                       DRC_NBC_Trans_Shipment__c,
                       DRC_NBC_Final_Destination__c,
                       DRC_NBC_Required_Documents__c,
                       DRC_NBC_Sample_Name__c,
                       DRC_NBC_Sample_Type__c,
                       DRC_NBC_Courier_service__c,
                       DRC_NBC_Delivery_status__c,
                       DRC_NBC_Courier_Number__c,
                       DRC_NBC_Expected_Delivery_Date__c,
                       DRC_NBC_Courier_date__c,
                       DRC_NBC_Sample_Shipping_Cost__c,
                       DRC_NBC_Special_request__c,
                       DRC_NBC_Sample_Amount__c,
                       DRC_NBC_Remarks__c,
                       DRC_NBC_TCS_Amount__c,
                       DRC_NBC_Other_Tax_Amount__c,
                       DRC_NBC_Consignee_Bank_Address__c,
                       DRC_NBC_Consignee_Bank_IFSC_Code__c,
                       DRC_NBC_Consignee_Bank_Account_Number__c,
                       DRC_NBC_Consignee_Bank_Name__c,
                       Opportunity.Name,
                       Quote.Name
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];

            return ord;
        } catch (Exception e) {
            System.debug('Error fetching order: ' + e.getMessage());
            throw new AuraHandledException('Error fetching Order record: ' + e.getMessage());
        }
    }

    public class AddressWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public AddressWrapper(Id value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<AddressWrapper> getAccountAddresses(Id accountId) {
        List<AddressWrapper> result = new List<AddressWrapper>();

        for (DRC_NBC_Addresses__c addr : [
            SELECT Id,
                   DRC_NBC_Address__Street__s,
                   DRC_NBC_Address__City__s,
                   DRC_NBC_Address__StateCode__s,
                   DRC_NBC_Address__PostalCode__s,
                   DRC_NBC_Address__CountryCode__s,
                   DRC_NBC_Type__c
            FROM DRC_NBC_Addresses__c
            WHERE DRC_NBC_Account__c = :accountId
            AND DRC_NBC_Type__c = 'Shipping'
        ]) {
            String fullAddress = String.join(new List<String>{
                addr.DRC_NBC_Address__Street__s,
                addr.DRC_NBC_Address__City__s,
                addr.DRC_NBC_Address__StateCode__s,
                addr.DRC_NBC_Address__PostalCode__s,
                addr.DRC_NBC_Address__CountryCode__s
            }, ', ');

            result.add(new AddressWrapper(addr.Id, fullAddress));
        }

        return result;
    }

    // Wrapper for a single packing detail record (mirrors DRC_NBC_GenerateQuotes_Controller)
    public class PackingDetailWrapper {
        @AuraEnabled public String packingSize;
        @AuraEnabled public String packingQuantity;

        public PackingDetailWrapper(String size, String qty) {
            this.packingSize     = size;
            this.packingQuantity = qty;
        }
    }

    // Wrapper that groups packing details by Product2Id
    // Using a List instead of Map so LWC can deserialize it correctly
    public class ProductPackingWrapper {
        @AuraEnabled public String product2Id;
        @AuraEnabled public List<PackingDetailWrapper> packingDetails;

        public ProductPackingWrapper(String pid, List<PackingDetailWrapper> details) {
            this.product2Id     = pid;
            this.packingDetails = details;
        }
    }

    @AuraEnabled
    public static oliWrapper getExistingOrderLineItems(String orderId) {
        List<DRC_NBC_Restricted_Product__c> productAccessibilitiesList = getRestrictedProductsAccessList(orderId);
        Set<Id> accessibleRestrictedProductIds = new Set<Id>();

        Order orderRecord = [
            SELECT Id, AccountId, CurrencyIsoCode, Pricebook2Id
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        if (orderRecord.Pricebook2Id == null) {
            Pricebook2 defaultPricebook = [
                SELECT Id
                FROM Pricebook2
                WHERE IsActive = true
                ORDER BY IsStandard DESC, CreatedDate ASC
                LIMIT 1
            ];
            orderRecord.Pricebook2Id = defaultPricebook.Id;
            update orderRecord;
        }

        // Query OrderItems — no longer need Product2.DRC_NBC_Packing_Size__c
        List<OrderItem> olis = [
            SELECT Id,
                   Product2.Name,
                   Product2.Family,
                   Product2.QuantityUnitOfMeasure,
                   Product2.DRC_NBC_FG_Code__c,
                   Product2.DRC_NBC_HSN_SAC_Code__c,
                   PricebookEntryId,
                   Description,
                   Product2Id,
                   Quantity,
                   UnitPrice,
                   DRC_NBC_Packing_Size__c,
                   DRC_NBC_Packing_Quantity__c
            FROM OrderItem
            WHERE OrderId = :orderId
        ];

        oliWrapper oliRecs = new oliWrapper();
        oliRecs.olis = olis;
        oliRecs.productsList = new List<PricebookEntry>();

        // Query products — no longer need Product2.DRC_NBC_Packing_Size__c
        List<PricebookEntry> allEntries = [
            SELECT Id,
                   Product2Id,
                   Product2.Name,
                   Product2.Family,
                   Product2.DRC_NBC_FG_Code__c,
                   Product2.DRC_NBC_HSN_SAC_Code__c,
                   Product2.QuantityUnitOfMeasure,
                   CurrencyIsoCode,
                   Pricebook2Id,
                   Product2.Description,
                   Product2.IsActive,
                   UnitPrice
            FROM PricebookEntry
            WHERE IsActive = true
              AND CurrencyISOCode = :orderRecord.CurrencyIsoCode
              AND Product2.IsActive = true
              AND Pricebook2Id = :orderRecord.Pricebook2Id
            ORDER BY Product2.Name
        ];
        oliRecs.productsList = allEntries;

        if (!productAccessibilitiesList.isEmpty()) {
            for (DRC_NBC_Restricted_Product__c access : productAccessibilitiesList) {
                if (access.DRC_NBC_Customer__c == orderRecord.AccountId) {
                    accessibleRestrictedProductIds.add(access.DRC_NBC_Product__c);
                }
            }

            if (!accessibleRestrictedProductIds.isEmpty()) {
                oliRecs.productsList.addAll([
                    SELECT Id,
                           Product2Id,
                           Product2.Name,
                           Product2.Family,
                           Product2.DRC_NBC_FG_Code__c,
                           Product2.DRC_NBC_HSN_SAC_Code__c,
                           Product2.QuantityUnitOfMeasure,
                           CurrencyIsoCode,
                           Pricebook2Id,
                           Product2.Description,
                           Product2.IsActive,
                           UnitPrice
                    FROM PricebookEntry
                    WHERE IsActive = true
                      AND CurrencyISOCode = :orderRecord.CurrencyIsoCode
                      AND Product2.IsActive = true
                      AND Pricebook2Id = :orderRecord.Pricebook2Id
                      AND Product2Id IN :accessibleRestrictedProductIds
                    ORDER BY Name
                ]);
            }
        }

        // Collect all Product2 Ids from OLIs and products list
        Set<Id> product2Ids = new Set<Id>();
        for (OrderItem oli : olis) {
            if (oli.Product2Id != null) product2Ids.add(oli.Product2Id);
        }
        for (PricebookEntry pbe : oliRecs.productsList) {
            if (pbe.Product2Id != null) product2Ids.add(pbe.Product2Id);
        }

        // Fetch packing details from child object for all relevant products
        // Build intermediate map first, then convert to List<ProductPackingWrapper>
        // so that LWC can deserialize it correctly (Apex Map<Id,...> doesn't serialize to LWC)
        Map<Id, List<PackingDetailWrapper>> tempMap = new Map<Id, List<PackingDetailWrapper>>();
        for (DRC_NBC_Packing_Details__c pd : [
            SELECT Id, Product__c, DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Qauntity__c
            FROM DRC_NBC_Packing_Details__c
            WHERE Product__c IN :product2Ids
            ORDER BY DRC_NBC_Packing_Size__c
        ]) {
            if (!tempMap.containsKey(pd.Product__c)) {
                tempMap.put(pd.Product__c, new List<PackingDetailWrapper>());
            }
            String qtyStr = pd.DRC_NBC_Packing_Qauntity__c != null
                ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c)
                : '';
            tempMap.get(pd.Product__c).add(
                new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr)
            );
        }

        List<ProductPackingWrapper> packingList = new List<ProductPackingWrapper>();
        for (Id pid : tempMap.keySet()) {
            packingList.add(new ProductPackingWrapper(pid, tempMap.get(pid)));
        }
        oliRecs.packingDetailsList = packingList;

        return oliRecs;
    }

    @AuraEnabled
    public static List<DRC_NBC_Restricted_Product__c> getRestrictedProductsAccessList(String orderId) {
        Order orderRecord = [
            SELECT AccountId
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];

        Id accountId = orderRecord.AccountId;
        return [
            SELECT DRC_NBC_Product__c,
                   DRC_NBC_Customer__c
            FROM DRC_NBC_Restricted_Product__c
            WHERE DRC_NBC_Customer__c = :accountId
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getContactsByAccount(Id accountId) {
        return [
            SELECT Id, Name
            FROM Contact
            WHERE AccountId = :accountId
            ORDER BY Name
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Opportunity> getOpportunitiesByAccount(Id accountId) {
        return [
            SELECT Id, Name
            FROM Opportunity
            WHERE AccountId = :accountId
            ORDER BY CloseDate DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Quote> getQuotesByOpportunity(Id opportunityId) {
        return [
            SELECT Id, Name
            FROM Quote
            WHERE OpportunityId = :opportunityId
            ORDER BY CreatedDate DESC
        ];
    }

    @AuraEnabled
    public static void saveOrderLineItems(List<OrderItem> oliList, List<String> oliIdsToDelete, Order orderData) {
        try {
            // Update Order record
            if (orderData != null && orderData.Id != null) {
                Order ordToUpdate = new Order(
                    Id = orderData.Id,
                    Name = orderData.Name,
                    EffectiveDate = orderData.EffectiveDate,
                    EndDate = orderData.EndDate,
                    Description = orderData.Description,
                    CurrencyIsoCode = orderData.CurrencyIsoCode,
                    Status = orderData.Status,
                    Type = orderData.Type,
                    DRC_NBC_Type__c = orderData.DRC_NBC_Type__c,
                    DRC_NBC_Payment_Terms__c = orderData.DRC_NBC_Payment_Terms__c,
                    DRC_NBC_Select_Bank__c = orderData.DRC_NBC_Select_Bank__c,
                    DRC_NBC_Inco_Terms__c = orderData.DRC_NBC_Inco_Terms__c,
                    DRC_NBC_Warehouse__c = orderData.DRC_NBC_Warehouse__c,
                    DRC_NBC_Other_Rejection_Reason__c = orderData.DRC_NBC_Other_Rejection_Reason__c,
                    DRC_NBC_Reject_Reason_Text__c = orderData.DRC_NBC_Reject_Reason_Text__c,
                    DRC_NBC_Special_Instructions__c = orderData.DRC_NBC_Special_Instructions__c,
                    DRC_NBC_Terms_and_Conditions__c = orderData.DRC_NBC_Terms_and_Conditions__c,
                    PONumber = orderData.PONumber,
                    PoDate = orderData.PoDate,
                    DRC_NBC_TCS_Amount__c = orderData.DRC_NBC_TCS_Amount__c,
                    DRC_NBC_Other_Tax_Amount__c = orderData.DRC_NBC_Other_Tax_Amount__c,
                    DRC_NBC_Consignee_Bank_Name__c = orderData.DRC_NBC_Consignee_Bank_Name__c,
                    DRC_NBC_Consignee_Bank_Account_Number__c = orderData.DRC_NBC_Consignee_Bank_Account_Number__c,
                    DRC_NBC_Consignee_Bank_IFSC_Code__c = orderData.DRC_NBC_Consignee_Bank_IFSC_Code__c,
                    DRC_NBC_Consignee_Bank_Address__c = orderData.DRC_NBC_Consignee_Bank_Address__c,
                    OpportunityId = orderData.OpportunityId,
                    QuoteId = orderData.QuoteId,
                    BillToContactId = orderData.BillToContactId,
                    ShipToContactId = orderData.ShipToContactId,
                    DRC_NBC_Shipping_Address__c = orderData.DRC_NBC_Shipping_Address__c
                );

                // Fetch and populate Shipping address
                if (orderData.DRC_NBC_Shipping_Address__c != null) {
                    DRC_NBC_Addresses__c shipToAddr = [
                        SELECT DRC_NBC_Address__Street__s,
                               DRC_NBC_Address__City__s,
                               DRC_NBC_Address__StateCode__s,
                               DRC_NBC_Address__PostalCode__s,
                               DRC_NBC_Address__CountryCode__s,
                               DRC_NBC_Warehouse__c
                        FROM DRC_NBC_Addresses__c
                        WHERE Id = :orderData.DRC_NBC_Shipping_Address__c
                        LIMIT 1
                    ];

                    ordToUpdate.ShippingStreet      = shipToAddr.DRC_NBC_Address__Street__s;
                    ordToUpdate.ShippingCity        = shipToAddr.DRC_NBC_Address__City__s;
                    ordToUpdate.ShippingStateCode   = shipToAddr.DRC_NBC_Address__StateCode__s;
                    ordToUpdate.ShippingPostalCode  = shipToAddr.DRC_NBC_Address__PostalCode__s;
                    ordToUpdate.ShippingCountryCode = shipToAddr.DRC_NBC_Address__CountryCode__s;
                }

                // Set the back-reference from the address to the order
                if (orderData.DRC_NBC_Shipping_Address__c != null) {
                    DRC_NBC_Addresses__c addressToUpdate = new DRC_NBC_Addresses__c(
                        Id = orderData.DRC_NBC_Shipping_Address__c,
                        DRC_NBC_Order__c = orderData.Id
                    );
                    update addressToUpdate;
                }

                // Add type-specific fields
                if (orderData.DRC_NBC_Type__c == 'Domestic') {
                    ordToUpdate.DRC_NBC_Transporter_Name__c  = orderData.DRC_NBC_Transporter_Name__c;
                    ordToUpdate.DRC_NBC_Transport_Agent__c   = orderData.DRC_NBC_Transport_Agent__c;
                    ordToUpdate.DRC_NBC_Prepayment_Method__c = orderData.DRC_NBC_Prepayment_Method__c;
                    ordToUpdate.DRC_NBC_Shipment_Method__c   = orderData.DRC_NBC_Shipment_Method__c;
                    ordToUpdate.DRC_NBC_Shipment_Date__c     = orderData.DRC_NBC_Shipment_Date__c;
                } else if (orderData.DRC_NBC_Type__c == 'Export') {
                    ordToUpdate.DRC_NBC_Country_of_Origin__c              = orderData.DRC_NBC_Country_of_Origin__c;
                    ordToUpdate.DRC_NBC_Country_of_Final_Destination__c   = orderData.DRC_NBC_Country_of_Final_Destination__c;
                    ordToUpdate.DRC_NBC_Shipment_Method__c                = orderData.DRC_NBC_Shipment_Method__c;
                    ordToUpdate.DRC_NBC_Port_Of_Discharge__c              = orderData.DRC_NBC_Port_Of_Discharge__c;
                    ordToUpdate.DRC_NBC_Port_of_Loading__c                = orderData.DRC_NBC_Port_of_Loading__c;
                    ordToUpdate.DRC_NBC_Notify_Party__c                   = orderData.DRC_NBC_Notify_Party__c;
                    ordToUpdate.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c    = orderData.DRC_NBC_PLACE_OF_RECEIPT_BY_CARRIAG__c;
                    ordToUpdate.DRC_NBC_Prepayment_Method__c              = orderData.DRC_NBC_Prepayment_Method__c;
                    ordToUpdate.DRC_NBC_Vessel_no_Flight_no__c            = orderData.DRC_NBC_Vessel_no_Flight_no__c;
                    ordToUpdate.DRC_NBC_Part_Shipment__c                  = orderData.DRC_NBC_Part_Shipment__c;
                    ordToUpdate.DRC_NBC_Trans_Shipment__c                 = orderData.DRC_NBC_Trans_Shipment__c;
                    ordToUpdate.DRC_NBC_Final_Destination__c              = orderData.DRC_NBC_Final_Destination__c;
                    ordToUpdate.DRC_NBC_Required_Documents__c             = orderData.DRC_NBC_Required_Documents__c;
                } else if (orderData.Type == 'Sample Order') {
                    ordToUpdate.DRC_NBC_Sample_Name__c            = orderData.DRC_NBC_Sample_Name__c;
                    ordToUpdate.DRC_NBC_Sample_Type__c            = orderData.DRC_NBC_Sample_Type__c;
                    ordToUpdate.DRC_NBC_Courier_service__c        = orderData.DRC_NBC_Courier_service__c;
                    ordToUpdate.DRC_NBC_Delivery_status__c        = orderData.DRC_NBC_Delivery_status__c;
                    ordToUpdate.DRC_NBC_Courier_Number__c         = orderData.DRC_NBC_Courier_Number__c;
                    ordToUpdate.DRC_NBC_Expected_Delivery_Date__c = orderData.DRC_NBC_Expected_Delivery_Date__c;
                    ordToUpdate.DRC_NBC_Courier_date__c           = orderData.DRC_NBC_Courier_date__c;
                    ordToUpdate.DRC_NBC_Sample_Shipping_Cost__c   = orderData.DRC_NBC_Sample_Shipping_Cost__c;
                    ordToUpdate.DRC_NBC_Special_request__c        = orderData.DRC_NBC_Special_request__c;
                    ordToUpdate.DRC_NBC_Sample_Amount__c          = orderData.DRC_NBC_Sample_Amount__c;
                    ordToUpdate.DRC_NBC_Reject_Reason_Text__c     = orderData.DRC_NBC_Reject_Reason_Text__c;
                    ordToUpdate.DRC_NBC_Remarks__c                = orderData.DRC_NBC_Remarks__c;
                }

                update ordToUpdate;
            }

            // Upsert Order Line Items
            List<OrderItem> olisToUpsert = new List<OrderItem>();
            for (OrderItem oli : oliList) {
                if (String.isBlank(oli.Product2Id)) {
                    throw new AuraHandledException('Missing Product2Id.');
                }
                if (oli.Quantity == null) {
                    throw new AuraHandledException('Missing Quantity.');
                }
                if (oli.UnitPrice == null) {
                    throw new AuraHandledException('Missing UnitPrice.');
                }
                // Packing fields (DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Quantity__c)
                // are already set on the oli object from JavaScript
                olisToUpsert.add(oli);
            }

            if (!olisToUpsert.isEmpty()) {
                upsert olisToUpsert;
            }

            if (!oliIdsToDelete.isEmpty()) {
                delete [SELECT Id FROM OrderItem WHERE Id IN :oliIdsToDelete];
            }

        } catch (Exception ex) {
            System.debug('Error saving Order: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());

            Order existing = [
                SELECT Id,
                       DRC_NBC_Warehouse__c,
                       DRC_NBC_Order_PartiallyShipped__c,
                       DRC_NBC_Shipping_Address__c
                FROM Order
                WHERE Id = :orderData.Id
                LIMIT 1
            ];

            Boolean partiallyShipped = existing.DRC_NBC_Order_PartiallyShipped__c;

            if (partiallyShipped) {
                if (orderData.DRC_NBC_Warehouse__c != null &&
                    orderData.DRC_NBC_Warehouse__c != existing.DRC_NBC_Warehouse__c) {
                    throw new AuraHandledException(
                        'Warehouse cannot be modified because the order is partially shipped.'
                    );
                }
            }
            throw new AuraHandledException('Error saving Order and Line Items: ' + ex.getMessage());
        }
    }

    public class oliWrapper {
        @AuraEnabled public List<OrderItem> olis;
        @AuraEnabled public List<PricebookEntry> productsList;
        // Packing details as List (Map<Id,...> doesn't serialize correctly to LWC)
        @AuraEnabled public List<ProductPackingWrapper> packingDetailsList;
    }
}