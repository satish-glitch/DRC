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
            this.packingSize     = size;
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
        @AuraEnabled public List<OpportunityLineItem>           olis;
        @AuraEnabled public Map<Id, List<PackingDetailWrapper>> packingDetailsMap;
    }

    // ─── Shared: fetch packing details for a set of product IDs ─────────────
    private static Map<Id, List<PackingDetailWrapper>> getPackingDetailsMap(Set<Id> product2Ids) {
        Map<Id, List<PackingDetailWrapper>> productPackingMap = new Map<Id, List<PackingDetailWrapper>>();
        if (product2Ids.isEmpty()) return productPackingMap;

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
        return productPackingMap;
    }

    // ─── NEW HELPER: Ensure PricebookEntries exist for the Opportunity currency ─
    // For any product that has entries in OTHER currencies but NOT in oppCurrency,
    // this method creates a new PricebookEntry with the same UnitPrice from the
    // existing entry (source currency). Returns a map of Product2Id → new/existing PBE.
    private static Map<Id, PricebookEntry> ensurePricebookEntriesForCurrency(
        Set<Id>  product2Ids,
        String   oppCurrency,
        Id       pricebookId
    ) {
        Map<Id, PricebookEntry> result = new Map<Id, PricebookEntry>();
        if (product2Ids.isEmpty()) return result;

        // 1. Find which products already have an entry in the opp currency
        Set<Id> alreadyHasCurrency = new Set<Id>();
        for (PricebookEntry existing : [
            SELECT Id, Product2Id, UnitPrice
            FROM   PricebookEntry
            WHERE  Product2Id     IN :product2Ids
              AND  Pricebook2Id   = :pricebookId
              AND  CurrencyIsoCode = :oppCurrency
              AND  IsActive       = true
        ]) {
            alreadyHasCurrency.add(existing.Product2Id);
            result.put(existing.Product2Id, existing);
        }

        // 2. Find the products that are MISSING the opp currency
        Set<Id> missingCurrency = new Set<Id>();
        for (Id pid : product2Ids) {
            if (!alreadyHasCurrency.contains(pid)) {
                missingCurrency.add(pid);
            }
        }

        if (missingCurrency.isEmpty()) return result;

        // 3. Fetch any existing PricebookEntry for missing products (any currency)
        //    to copy the UnitPrice from
        Map<Id, PricebookEntry> sourcePbeMap = new Map<Id, PricebookEntry>();
        for (PricebookEntry sourcePbe : [
            SELECT Id, Product2Id, UnitPrice, CurrencyIsoCode
            FROM   PricebookEntry
            WHERE  Product2Id   IN :missingCurrency
              AND  Pricebook2Id = :pricebookId
              AND  IsActive     = true
            ORDER BY CurrencyIsoCode   // deterministic: pick first alphabetically
            LIMIT  200
        ]) {
            // Keep only the first entry found per product (one source to copy from)
            if (!sourcePbeMap.containsKey(sourcePbe.Product2Id)) {
                sourcePbeMap.put(sourcePbe.Product2Id, sourcePbe);
            }
        }

        if (sourcePbeMap.isEmpty()) return result;

        // 4. Build new PricebookEntries in the opp currency using the source price
        List<PricebookEntry> toInsert = new List<PricebookEntry>();
        for (Id pid : sourcePbeMap.keySet()) {
            PricebookEntry src = sourcePbeMap.get(pid);
            toInsert.add(new PricebookEntry(
                Product2Id      = pid,
                Pricebook2Id    = pricebookId,
                CurrencyIsoCode = oppCurrency,
                UnitPrice       = src.UnitPrice,   // list price copied from source currency
                IsActive        = true
            ));
        }

        // 5. Insert and add to result map
        if (!toInsert.isEmpty()) {
            insert toInsert;
            for (PricebookEntry newPbe : toInsert) {
                result.put(newPbe.Product2Id, newPbe);
            }
        }

        return result;
    }

    // ─── Shared: query PricebookEntries with auto-create for opp currency ────
    private static List<PricebookEntry> queryPricebookEntries(
        String      likePattern,
        String      currencyCode,
        Id          pricebookId,
        Set<Id>     restrictedProductIds,
        Boolean     useRestricted
    ) {
        // ── Step 1: Find matching products (any currency) ─────────────────────
        List<PricebookEntry> allEntries = new List<PricebookEntry>();

        if (useRestricted) {
            allEntries = [
                SELECT Id, Product2Id,
                       Product2.Name,
                       Product2.DRC_NBC_FG_Code__c,
                       Product2.DRC_NBC_HSN_SAC_Code__c,
                       Product2.QuantityUnitOfMeasure,
                       Product2.Description,
                       UnitPrice,
                       CurrencyIsoCode
                FROM   PricebookEntry
                WHERE  IsActive          = true
                  AND  Product2.IsActive = true
                  AND  Product2.Name     LIKE :likePattern
                  AND  Pricebook2Id      = :pricebookId
                  AND  Product2Id        IN :restrictedProductIds
                ORDER BY Product2.Name
                LIMIT  100
            ];
        } else {
            allEntries = [
                SELECT Id, Product2Id,
                       Product2.Name,
                       Product2.DRC_NBC_FG_Code__c,
                       Product2.DRC_NBC_HSN_SAC_Code__c,
                       Product2.QuantityUnitOfMeasure,
                       Product2.Description,
                       UnitPrice,
                       CurrencyIsoCode
                FROM   PricebookEntry
                WHERE  IsActive          = true
                  AND  Product2.IsActive = true
                  AND  Product2.Name     LIKE :likePattern
                  AND  Pricebook2Id      = :pricebookId
                ORDER BY Product2.Name
                LIMIT  100
            ];
        }

        if (allEntries.isEmpty()) return allEntries;

        // ── Step 2: Collect all matching Product2Ids ──────────────────────────
        Set<Id> allProduct2Ids = new Set<Id>();
        for (PricebookEntry pbe : allEntries) {
            allProduct2Ids.add(pbe.Product2Id);
        }

        // ── Step 3: Ensure every product has a PBE in the opp currency ────────
        // This creates missing entries automatically, copying price from existing currency
        Map<Id, PricebookEntry> currencyPbeMap = ensurePricebookEntriesForCurrency(
            allProduct2Ids,
            currencyCode,
            pricebookId
        );

        // ── Step 4: Build final deduplicated list using opp-currency PBEs ─────
        // For each product, prefer the opp-currency entry (existing or newly created)
        Set<Id> seen = new Set<Id>();
        List<PricebookEntry> finalEntries = new List<PricebookEntry>();

        // First pass: use opp-currency PBEs where available
        for (PricebookEntry pbe : allEntries) {
            if (!seen.contains(pbe.Product2Id) && currencyPbeMap.containsKey(pbe.Product2Id)) {
                seen.add(pbe.Product2Id);
                PricebookEntry oppCurrencyPbe = currencyPbeMap.get(pbe.Product2Id);

                // Stamp the opp-currency PBE's Id + price onto the record
                // but carry over product details from the allEntries query
                pbe.Id        = oppCurrencyPbe.Id;
                pbe.UnitPrice = oppCurrencyPbe.UnitPrice;
                finalEntries.add(pbe);
            }
        }

        // Second pass: any product not in currencyPbeMap (edge case — no source PBE found)
        for (PricebookEntry pbe : allEntries) {
            if (!seen.contains(pbe.Product2Id)) {
                seen.add(pbe.Product2Id);
                finalEntries.add(pbe);
            }
        }

        return finalEntries;
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

        Id standardPricebookId = getStandardPricebookId();

        if (opp.Pricebook2Id == null) {
            opp.Pricebook2Id = standardPricebookId;
            update opp;
        } else if (opp.Pricebook2Id != standardPricebookId) {
            Integer oliCount = [
                SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :opportunityId
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
            FROM   OpportunityLineItem
            WHERE  OpportunityId = :opportunityId
        ];

        Set<Id> product2Ids = new Set<Id>();
        for (OpportunityLineItem oli : olis) {
            if (oli.Product2Id != null) product2Ids.add(oli.Product2Id);
        }

        OLIWrapper result        = new OLIWrapper();
        result.olis              = olis;
        result.packingDetailsMap = getPackingDetailsMap(product2Ids);
        return result;
    }

    // ─── Search products by name ───────────────────────────────────────────────
    @AuraEnabled
    public static List<ProductWrapper> searchProducts(String searchTerm, Id opportunityId) {
        if (String.isBlank(searchTerm)) return new List<ProductWrapper>();
        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException('Opportunity ID is required for product search.');
        }

        Opportunity opp = [
            SELECT Id, CurrencyIsoCode, Pricebook2Id, AccountId
            FROM   Opportunity
            WHERE  Id = :opportunityId
            LIMIT  1
        ];

        Id pricebookId = (opp.Pricebook2Id != null) ? opp.Pricebook2Id : getStandardPricebookId();
        String likePattern = '%' + String.escapeSingleQuotes(searchTerm) + '%';

        // ── Account-level restriction ─────────────────────────────────────────
        Set<Id> restrictedProductIds = new Set<Id>();
        for (DRC_NBC_Restricted_Product__c rp : [
            SELECT DRC_NBC_Product__c
            FROM   DRC_NBC_Restricted_Product__c
            WHERE  DRC_NBC_Customer__c = :opp.AccountId
        ]) {
            restrictedProductIds.add(rp.DRC_NBC_Product__c);
        }

        Boolean useRestricted = !restrictedProductIds.isEmpty();

        // ── Query (auto-creates missing currency PBEs inside) ─────────────────
        List<PricebookEntry> entries = queryPricebookEntries(
            likePattern,
            opp.CurrencyIsoCode,
            pricebookId,
            restrictedProductIds,
            useRestricted
        );

        Set<Id> product2Ids = new Set<Id>();
        for (PricebookEntry pbe : entries) product2Ids.add(pbe.Product2Id);

        Map<Id, List<PackingDetailWrapper>> productPackingMap = getPackingDetailsMap(product2Ids);

        List<ProductWrapper> results = new List<ProductWrapper>();
        for (PricebookEntry pbe : entries) {
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
}