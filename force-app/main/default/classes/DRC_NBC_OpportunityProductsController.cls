/**
 * @File Name   : DRC_NBC_OpportunityProductsController.cls
 * @Description : Controller for LWC drc_nbc_addProductsToOpportunity
 * @Modification Log :
 *==============================================================================
 * Ver | Date       | Modification
 *==============================================================================
 * 1.0 | Initial    | Initial Version
 * 1.1 | Mar 2026   | Fixed pricebook fallback to always use DRC PriceBook
 *                  | instead of Standard Pricebook — prevents pricebook mismatch
 *                  | when Generate Quote tries to create QuoteLineItems.
 **/
/*public with sharing class DRC_NBC_OpportunityProductsController {

    // ─── Helper: fetch DRC PriceBook Id ──────────────────────────────────────
    private static Id getDRCPricebookId() {
        Pricebook2 drcPb = [
            SELECT Id FROM Pricebook2
            WHERE  Name                   = 'DRC PriceBook'
              AND  IsActive               = true
              AND  DRC_NBC_External_Id__c = 'DRC001'
            LIMIT  1
        ];
        return drcPb.Id;
    }

    // ─── Packing detail wrapper ───────────────────────────────────────────────
    public class PackingDetailWrapper {
        @AuraEnabled public String packingSize;
        @AuraEnabled public String packingQuantity;
        public PackingDetailWrapper(String size, String qty) {
            this.packingSize     = size;
            this.packingQuantity = qty;
        }
    }

    // ─── Product search result wrapper ────────────────────────────────────────
    public class ProductWrapper {
        @AuraEnabled public Id      pricebookEntryId;
        @AuraEnabled public Id      product2Id;
        @AuraEnabled public String  product2Name;
        @AuraEnabled public String  fgCode;
        @AuraEnabled public String  hsnCode;
        @AuraEnabled public String  uom;
        @AuraEnabled public String  description;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public List<PackingDetailWrapper> packingDetails;

        public ProductWrapper(Id pbeId, Id p2Id, String nm, String fg, String hsn,
                              String uomVal, String descr, Decimal price,
                              List<PackingDetailWrapper> packing) {
            this.pricebookEntryId = pbeId;
            this.product2Id       = p2Id;
            this.product2Name     = nm;
            this.fgCode           = fg;
            this.hsnCode          = hsn;
            this.uom              = uomVal;
            this.description      = descr;
            this.unitPrice        = price;
            this.packingDetails   = packing;
        }
    }

    // ─── OLI response wrapper ─────────────────────────────────────────────────
    public class OLIWrapper {
        @AuraEnabled public List<OpportunityLineItem>           olis;
        @AuraEnabled public Map<Id, List<PackingDetailWrapper>> packingDetailsMap;
    }

    // ─── Fetch existing OLIs on modal open ────────────────────────────────────
    @AuraEnabled
    public static OLIWrapper getExistingOLIs(Id opportunityId) {
        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException('Opportunity ID is required.');
        }

        Opportunity opp = [
            SELECT Id, CurrencyIsoCode, Pricebook2Id
            FROM   Opportunity
            WHERE  Id = :opportunityId
            LIMIT  1
        ];

        // Always ensure the Opp is set to DRC PriceBook.
        // If it is already set to DRC, do nothing.
        // If it is null, set it now (safe — no OLIs can exist yet).
        // Never change if OLIs already exist under a different pricebook
        // (that would throw FIELD_INTEGRITY_EXCEPTION).
        Id drcPricebookId = getDRCPricebookId();

        if (opp.Pricebook2Id == null) {
            opp.Pricebook2Id = drcPricebookId;
            update opp;
        } else if (opp.Pricebook2Id != drcPricebookId) {
            // Pricebook is set but NOT DRC — check if OLIs exist before changing
            Integer oliCount = [
                SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :opportunityId
            ];
            if (oliCount == 0) {
                // Safe to change — no OLIs yet
                opp.Pricebook2Id = drcPricebookId;
                update opp;
            }
            // If OLIs exist under a different pricebook, leave as-is.
            // searchProducts will use whatever pricebook the Opp has.
        }

        List<OpportunityLineItem> olis = [
            SELECT
                Id,
                Product2.Name,
                Product2.QuantityUnitOfMeasure,
                Product2.DRC_NBC_FG_Code__c,
                Product2.DRC_NBC_HSN_SAC_Code__c,
                PricebookEntryId,
                Description,
                Discount,
                Product2Id,
                Quantity,
                UnitPrice,
                DRC_NBC_Packing_Size__c,
                DRC_NBC_Packing_Qauntity__c
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
        ];

        Set<Id> product2Ids = new Set<Id>();
        for (OpportunityLineItem oli : olis) {
            if (oli.Product2Id != null) product2Ids.add(oli.Product2Id);
        }

        Map<Id, List<PackingDetailWrapper>> productPackingMap = new Map<Id, List<PackingDetailWrapper>>();
        if (!product2Ids.isEmpty()) {
            for (DRC_NBC_Packing_Details__c pd : [
                SELECT Id, Product__c, DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Qauntity__c
                FROM   DRC_NBC_Packing_Details__c
                WHERE  Product__c IN :product2Ids
                ORDER BY DRC_NBC_Packing_Size__c
            ]) {
                if (!productPackingMap.containsKey(pd.Product__c)) {
                    productPackingMap.put(pd.Product__c, new List<PackingDetailWrapper>());
                }
                String qtyStr = pd.DRC_NBC_Packing_Qauntity__c != null
                    ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c) : '';
                productPackingMap.get(pd.Product__c).add(
                    new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr)
                );
            }
        }

        OLIWrapper result        = new OLIWrapper();
        result.olis              = olis;
        result.packingDetailsMap = productPackingMap;
        return result;
    }

    // ─── Search products by name ──────────────────────────────────────────────
    @AuraEnabled
    public static List<ProductWrapper> searchProducts(String searchTerm, Id opportunityId) {

        System.debug('searchProducts called | searchTerm=' + searchTerm + ' | opportunityId=' + opportunityId);

        if (String.isBlank(searchTerm)) {
            return new List<ProductWrapper>();
        }
        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException('Opportunity ID is required for product search.');
        }

        Opportunity opp = [
            SELECT Id, CurrencyIsoCode, Pricebook2Id, AccountId
            FROM   Opportunity
            WHERE  Id = :opportunityId
            LIMIT  1
        ];

        // Always search within DRC PriceBook.
        // If Opp has no pricebook yet, use DRC (do NOT update here — let getExistingOLIs handle that).
        Id pricebookId = (opp.Pricebook2Id != null) ? opp.Pricebook2Id : getDRCPricebookId();

        String likePattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';

        // Restricted products for this account + current user
        Set<Id> restrictedProductIds = new Set<Id>();
        for (DRC_NBC_Restricted_Product__c rp : [
            SELECT DRC_NBC_Product__c
            FROM   DRC_NBC_Restricted_Product__c
            WHERE  DRC_NBC_Customer__c = :opp.AccountId
              AND  DRC_NBC_User__c     = :UserInfo.getUserId()
        ]) {
            restrictedProductIds.add(rp.DRC_NBC_Product__c);
        }

        List<PricebookEntry> entries;

        if (!restrictedProductIds.isEmpty()) {
            entries = [
                SELECT Id, Product2Id,
                       Product2.Name,
                       Product2.DRC_NBC_FG_Code__c,
                       Product2.DRC_NBC_HSN_SAC_Code__c,
                       Product2.QuantityUnitOfMeasure,
                       Product2.Description,
                       UnitPrice
                FROM   PricebookEntry
                WHERE  IsActive          = true
                  AND  Product2.IsActive = true
                  AND  Product2.Name LIKE :likePattern
                  AND  CurrencyIsoCode   = :opp.CurrencyIsoCode
                  AND  Pricebook2Id      = :pricebookId
                  AND  Product2Id        IN :restrictedProductIds
                ORDER BY Product2.Name
                LIMIT  100
            ];
        } else {
            entries = [
                SELECT Id, Product2Id,
                       Product2.Name,
                       Product2.DRC_NBC_FG_Code__c,
                       Product2.DRC_NBC_HSN_SAC_Code__c,
                       Product2.QuantityUnitOfMeasure,
                       Product2.Description,
                       UnitPrice
                FROM   PricebookEntry
                WHERE  IsActive          = true
                  AND  Product2.IsActive = true
                  AND  Product2.Name LIKE :likePattern
                  AND  CurrencyIsoCode   = :opp.CurrencyIsoCode
                  AND  Pricebook2Id      = :pricebookId
                ORDER BY Product2.Name
                LIMIT  100
            ];
        }

        System.debug('PricebookEntry results count: ' + entries.size());

        Set<Id> product2Ids = new Set<Id>();
        for (PricebookEntry pbe : entries) product2Ids.add(pbe.Product2Id);

        Map<Id, List<PackingDetailWrapper>> productPackingMap = new Map<Id, List<PackingDetailWrapper>>();
        if (!product2Ids.isEmpty()) {
            for (DRC_NBC_Packing_Details__c pd : [
                SELECT Id, Product__c, DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Qauntity__c
                FROM   DRC_NBC_Packing_Details__c
                WHERE  Product__c IN :product2Ids
                ORDER BY DRC_NBC_Packing_Size__c
            ]) {
                if (!productPackingMap.containsKey(pd.Product__c)) {
                    productPackingMap.put(pd.Product__c, new List<PackingDetailWrapper>());
                }
                String qtyStr = pd.DRC_NBC_Packing_Qauntity__c != null
                    ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c) : '';
                productPackingMap.get(pd.Product__c).add(
                    new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr)
                );
            }
        }

        Set<Id> seen = new Set<Id>();
        List<ProductWrapper> results = new List<ProductWrapper>();

        for (PricebookEntry pbe : entries) {
            if (!seen.contains(pbe.Product2Id)) {
                seen.add(pbe.Product2Id);
                List<PackingDetailWrapper> packing =
                    productPackingMap.containsKey(pbe.Product2Id)
                        ? productPackingMap.get(pbe.Product2Id)
                        : new List<PackingDetailWrapper>();

                results.add(new ProductWrapper(
                    pbe.Id,
                    pbe.Product2Id,
                    pbe.Product2.Name,
                    pbe.Product2.DRC_NBC_FG_Code__c,
                    pbe.Product2.DRC_NBC_HSN_SAC_Code__c,
                    pbe.Product2.QuantityUnitOfMeasure,
                    pbe.Product2.Description,
                    pbe.UnitPrice,
                    packing
                ));
            }
        }

        System.debug('Returning ' + results.size() + ' ProductWrapper results');
        return results;
    }

    // ─── Save / upsert OLIs ───────────────────────────────────────────────────
    @AuraEnabled
    public static void saveOLIData(
        List<OpportunityLineItem> oliList,
        List<String>              oliIdsToDelete,
        Id                        opportunityId
    ) {
        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException('Opportunity ID is required.');
        }

        try {
            List<OpportunityLineItem> toUpsert = new List<OpportunityLineItem>();

            for (OpportunityLineItem oli : oliList) {
                if (String.isBlank(oli.Product2Id)) {
                    throw new AuraHandledException('Missing Product2Id on a line item.');
                }
                if (oli.Quantity == null || oli.Quantity <= 0) {
                    throw new AuraHandledException('Quantity must be greater than 0.');
                }
                if (oli.UnitPrice == null) {
                    throw new AuraHandledException('Missing UnitPrice on a line item.');
                }

                // Blank Id → null so upsert inserts instead of failing update
                Id recordId = String.isBlank(oli.Id) ? null : oli.Id;

                toUpsert.add(new OpportunityLineItem(
                    Id                             = recordId,
                    Product2Id                     = oli.Product2Id,
                    Quantity                       = oli.Quantity,
                    UnitPrice                      = oli.UnitPrice,
                    Discount                       = oli.Discount,
                    OpportunityId                  = opportunityId,
                    PricebookEntryId               = oli.PricebookEntryId,
                    Description                    = oli.Description,
                    DRC_NBC_Unit_Of_Measurement__c = oli.DRC_NBC_Unit_Of_Measurement__c,
                    DRC_NBC_Packing_Size__c        = oli.DRC_NBC_Packing_Size__c,
                    DRC_NBC_Packing_Qauntity__c    = oli.DRC_NBC_Packing_Qauntity__c
                ));
            }

            if (!toUpsert.isEmpty()) upsert toUpsert;

            if (oliIdsToDelete != null && !oliIdsToDelete.isEmpty()) {
                delete [SELECT Id FROM OpportunityLineItem WHERE Id IN :oliIdsToDelete];
            }

        } catch (DmlException dmlEx) {
            throw new AuraHandledException('DML error: ' + dmlEx.getMessage());
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            throw new AuraHandledException('Unexpected error: ' + ex.getMessage());
        }
    }
}*/

public with sharing class DRC_NBC_OpportunityProductsController {

    private static Id getStandardPricebookId() {
        Pricebook2 stdPb = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];
        return stdPb.Id;
    }

    public class PackingDetailWrapper {
        @AuraEnabled public String packingSize;
        @AuraEnabled public String packingQuantity;
        public PackingDetailWrapper(String size, String qty) {
            this.packingSize = size;
            this.packingQuantity = qty;
        }
    }

    public class ProductWrapper {
        @AuraEnabled public Id      pricebookEntryId;
        @AuraEnabled public Id      product2Id;
        @AuraEnabled public String  product2Name;
        @AuraEnabled public String  fgCode;
        @AuraEnabled public String  hsnCode;
        @AuraEnabled public String  uom;
        @AuraEnabled public String  description;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public List<PackingDetailWrapper> packingDetails;

        public ProductWrapper(Id pbeId, Id p2Id, String nm, String fg, String hsn,
                              String uomVal, String descr, Decimal price,
                              List<PackingDetailWrapper> packing) {
            this.pricebookEntryId = pbeId;
            this.product2Id       = p2Id;
            this.product2Name     = nm;
            this.fgCode           = fg;
            this.hsnCode          = hsn;
            this.uom              = uomVal;
            this.description      = descr;
            this.unitPrice        = price;
            this.packingDetails   = packing;
        }
    }

    public class OLIWrapper {
        @AuraEnabled public List<OpportunityLineItem> olis;
        @AuraEnabled public Map<Id, List<PackingDetailWrapper>> packingDetailsMap;
    }

    @AuraEnabled
    public static OLIWrapper getExistingOLIs(Id opportunityId) {
        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException('Opportunity ID is required.');
        }

        Opportunity opp = [
            SELECT Id, CurrencyIsoCode, Pricebook2Id
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        Id standardPricebookId = getStandardPricebookId();

        if (opp.Pricebook2Id == null) {
            opp.Pricebook2Id = standardPricebookId;
            update opp;
        } else if (opp.Pricebook2Id != standardPricebookId) {
            Integer oliCount = [
                SELECT COUNT()
                FROM OpportunityLineItem
                WHERE OpportunityId = :opportunityId
            ];
            if (oliCount == 0) {
                opp.Pricebook2Id = standardPricebookId;
                update opp;
            }
        }

        List<OpportunityLineItem> olis = [
            SELECT Id,
                   Product2.Name,
                   Product2.QuantityUnitOfMeasure,
                   Product2.DRC_NBC_FG_Code__c,
                   Product2.DRC_NBC_HSN_SAC_Code__c,
                   PricebookEntryId,
                   Description,
                   Discount,
                   Product2Id,
                   Quantity,
                   UnitPrice,
                   DRC_NBC_Packing_Size__c,
                   DRC_NBC_Packing_Qauntity__c
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
        ];

        Set<Id> product2Ids = new Set<Id>();
        for (OpportunityLineItem oli : olis) {
            if (oli.Product2Id != null) {
                product2Ids.add(oli.Product2Id);
            }
        }

        Map<Id, List<PackingDetailWrapper>> productPackingMap = new Map<Id, List<PackingDetailWrapper>>();
        if (!product2Ids.isEmpty()) {
            for (DRC_NBC_Packing_Details__c pd : [
                SELECT Id, Product__c, DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Qauntity__c
                FROM DRC_NBC_Packing_Details__c
                WHERE Product__c IN :product2Ids
                ORDER BY DRC_NBC_Packing_Size__c
            ]) {
                if (!productPackingMap.containsKey(pd.Product__c)) {
                    productPackingMap.put(pd.Product__c, new List<PackingDetailWrapper>());
                }
                String qtyStr = pd.DRC_NBC_Packing_Qauntity__c != null
                    ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c)
                    : '';
                productPackingMap.get(pd.Product__c).add(
                    new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr)
                );
            }
        }

        OLIWrapper result = new OLIWrapper();
        result.olis = olis;
        result.packingDetailsMap = productPackingMap;
        return result;
    }

    @AuraEnabled
    public static List<ProductWrapper> searchProducts(String searchTerm, Id opportunityId) {
        if (String.isBlank(searchTerm)) {
            return new List<ProductWrapper>();
        }
        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException('Opportunity ID is required for product search.');
        }

        Opportunity opp = [
            SELECT Id, CurrencyIsoCode, Pricebook2Id, AccountId
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        Id pricebookId = (opp.Pricebook2Id != null) ? opp.Pricebook2Id : getStandardPricebookId();

        String likePattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';

        Set<Id> restrictedProductIds = new Set<Id>();
        for (DRC_NBC_Restricted_Product__c rp : [
            SELECT DRC_NBC_Product__c
            FROM DRC_NBC_Restricted_Product__c
            WHERE DRC_NBC_Customer__c = :opp.AccountId
              AND DRC_NBC_User__c = :UserInfo.getUserId()
        ]) {
            restrictedProductIds.add(rp.DRC_NBC_Product__c);
        }

        List<PricebookEntry> entries;

        if (!restrictedProductIds.isEmpty()) {
            entries = [
                SELECT Id, Product2Id,
                       Product2.Name,
                       Product2.DRC_NBC_FG_Code__c,
                       Product2.DRC_NBC_HSN_SAC_Code__c,
                       Product2.QuantityUnitOfMeasure,
                       Product2.Description,
                       UnitPrice
                FROM PricebookEntry
                WHERE IsActive = true
                  AND Product2.IsActive = true
                  AND Product2.Name LIKE :likePattern
                  AND CurrencyIsoCode = :opp.CurrencyIsoCode
                  AND Pricebook2Id = :pricebookId
                  AND Product2Id IN :restrictedProductIds
                ORDER BY Product2.Name
                LIMIT 100
            ];
        } else {
            entries = [
                SELECT Id, Product2Id,
                       Product2.Name,
                       Product2.DRC_NBC_FG_Code__c,
                       Product2.DRC_NBC_HSN_SAC_Code__c,
                       Product2.QuantityUnitOfMeasure,
                       Product2.Description,
                       UnitPrice
                FROM PricebookEntry
                WHERE IsActive = true
                  AND Product2.IsActive = true
                  AND Product2.Name LIKE :likePattern
                  AND CurrencyIsoCode = :opp.CurrencyIsoCode
                  AND Pricebook2Id = :pricebookId
                ORDER BY Product2.Name
                LIMIT 100
            ];
        }

        Set<Id> product2Ids = new Set<Id>();
        for (PricebookEntry pbe : entries) {
            product2Ids.add(pbe.Product2Id);
        }

        Map<Id, List<PackingDetailWrapper>> productPackingMap = new Map<Id, List<PackingDetailWrapper>>();
        if (!product2Ids.isEmpty()) {
            for (DRC_NBC_Packing_Details__c pd : [
                SELECT Id, Product__c, DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Qauntity__c
                FROM DRC_NBC_Packing_Details__c
                WHERE Product__c IN :product2Ids
                ORDER BY DRC_NBC_Packing_Size__c
            ]) {
                if (!productPackingMap.containsKey(pd.Product__c)) {
                    productPackingMap.put(pd.Product__c, new List<PackingDetailWrapper>());
                }
                String qtyStr = pd.DRC_NBC_Packing_Qauntity__c != null
                    ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c)
                    : '';
                productPackingMap.get(pd.Product__c).add(
                    new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr)
                );
            }
        }

        Set<Id> seen = new Set<Id>();
        List<ProductWrapper> results = new List<ProductWrapper>();

        for (PricebookEntry pbe : entries) {
            if (!seen.contains(pbe.Product2Id)) {
                seen.add(pbe.Product2Id);

                List<PackingDetailWrapper> packing = productPackingMap.containsKey(pbe.Product2Id)
                    ? productPackingMap.get(pbe.Product2Id)
                    : new List<PackingDetailWrapper>();

                results.add(new ProductWrapper(
                    pbe.Id,
                    pbe.Product2Id,
                    pbe.Product2.Name,
                    pbe.Product2.DRC_NBC_FG_Code__c,
                    pbe.Product2.DRC_NBC_HSN_SAC_Code__c,
                    pbe.Product2.QuantityUnitOfMeasure,
                    pbe.Product2.Description,
                    pbe.UnitPrice,
                    packing
                ));
            }
        }

        return results;
    }

    @AuraEnabled
    public static void saveOLIData(
        List<OpportunityLineItem> oliList,
        List<String> oliIdsToDelete,
        Id opportunityId
    ) {
        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException('Opportunity ID is required.');
        }

        try {
            List<OpportunityLineItem> toUpsert = new List<OpportunityLineItem>();

            for (OpportunityLineItem oli : oliList) {
                if (String.isBlank(oli.Product2Id)) {
                    throw new AuraHandledException('Missing Product2Id on a line item.');
                }
                if (oli.Quantity == null || oli.Quantity <= 0) {
                    throw new AuraHandledException('Quantity must be greater than 0.');
                }
                if (oli.UnitPrice == null) {
                    throw new AuraHandledException('Missing UnitPrice on a line item.');
                }

                Id recordId = String.isBlank(oli.Id) ? null : oli.Id;

                toUpsert.add(new OpportunityLineItem(
                    Id                             = recordId,
                    Product2Id                     = oli.Product2Id,
                    Quantity                       = oli.Quantity,
                    UnitPrice                      = oli.UnitPrice,
                    Discount                       = oli.Discount,
                    OpportunityId                  = opportunityId,
                    PricebookEntryId               = oli.PricebookEntryId,
                    Description                    = oli.Description,
                    DRC_NBC_Unit_Of_Measurement__c = oli.DRC_NBC_Unit_Of_Measurement__c,
                    DRC_NBC_Packing_Size__c        = oli.DRC_NBC_Packing_Size__c,
                    DRC_NBC_Packing_Qauntity__c    = oli.DRC_NBC_Packing_Qauntity__c
                ));
            }

            if (!toUpsert.isEmpty()) {
                upsert toUpsert;
            }

            if (oliIdsToDelete != null && !oliIdsToDelete.isEmpty()) {
                delete [SELECT Id FROM OpportunityLineItem WHERE Id IN :oliIdsToDelete];
            }

        } catch (DmlException dmlEx) {
            throw new AuraHandledException('DML error: ' + dmlEx.getMessage());
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            throw new AuraHandledException('Unexpected error: ' + ex.getMessage());
        }
    }
}