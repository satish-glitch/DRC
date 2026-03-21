/**
 * @File Name   : DRC_NBC_OpportunityProductsController.cls
 * @Description : Controller for LWC drc_nbc_addProductsToOpportunity
 *                Handles fetching and saving OpportunityLineItems (products).
 * @Author      : Generated based on DRC_NBC_ProductsController pattern
 **/
public with sharing class DRC_NBC_OpportunityProductsController {

    // ─── Wrapper: single packing detail ──────────────────────────────────────
    public class PackingDetailWrapper {
        @AuraEnabled public String packingSize;
        @AuraEnabled public String packingQuantity;

        public PackingDetailWrapper(String size, String qty) {
            this.packingSize     = size;
            this.packingQuantity = qty;
        }
    }

    // ─── Response wrapper ─────────────────────────────────────────────────────
    public class OLIWrapper {
        @AuraEnabled public List<OpportunityLineItem>           olis;
        @AuraEnabled public List<PricebookEntry>                productsList;
        @AuraEnabled public Map<Id, List<PackingDetailWrapper>> packingDetailsMap;
    }

    // ─── Fetch existing OLIs + product catalogue ──────────────────────────────
    @AuraEnabled
    public static OLIWrapper getExistingOLIs(Id opportunityId) {
        if (String.isBlank(opportunityId)) {
            throw new AuraHandledException('Opportunity ID is required.');
        }

        // Load opportunity to get currency & pricebook
        Opportunity opp = [
            SELECT Id, CurrencyIsoCode, Pricebook2Id
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        // Ensure a pricebook is set
        if (opp.Pricebook2Id == null) {
            Pricebook2 defaultPb = [
                SELECT Id
                FROM Pricebook2
                WHERE IsActive = true
                ORDER BY IsStandard DESC, CreatedDate ASC
                LIMIT 1
            ];
            opp.Pricebook2Id = defaultPb.Id;
            update opp;
        }

        // Existing Opportunity Products
        List<OpportunityLineItem> olis = [
            SELECT
                Id,
                Product2.Name,
                Product2.Family,
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

        // Active products in the opportunity's pricebook & currency
        List<PricebookEntry> productsList = [
            SELECT
                Id,
                Product2Id,
                Product2.Name,
                Product2.Family,
                Product2.DRC_NBC_FG_Code__c,
                Product2.DRC_NBC_HSN_SAC_Code__c,
                Product2.QuantityUnitOfMeasure,
                Product2.Description,
                Product2.IsActive,
                CurrencyIsoCode,
                Pricebook2Id,
                UnitPrice
            FROM PricebookEntry
            WHERE IsActive          = true
              AND CurrencyISOCode   = :opp.CurrencyIsoCode
              AND Product2.IsActive = true
              AND Pricebook2Id      = :opp.Pricebook2Id
            ORDER BY Product2.Name
        ];

        // Collect all Product2 Ids
        Set<Id> product2Ids = new Set<Id>();
        for (OpportunityLineItem oli : olis) {
            if (oli.Product2Id != null) product2Ids.add(oli.Product2Id);
        }
        for (PricebookEntry pbe : productsList) {
            if (pbe.Product2Id != null) product2Ids.add(pbe.Product2Id);
        }

        // Fetch packing details from child object
        Map<Id, List<PackingDetailWrapper>> productPackingMap = new Map<Id, List<PackingDetailWrapper>>();
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
                ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c) : '';
            productPackingMap.get(pd.Product__c).add(
                new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr)
            );
        }

        OLIWrapper result          = new OLIWrapper();
        result.olis                = olis;
        result.productsList        = productsList;
        result.packingDetailsMap   = productPackingMap;
        return result;
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

                toUpsert.add(new OpportunityLineItem(
                    Id                             = oli.Id,
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
            throw new AuraHandledException('DML error saving Opportunity Products: ' + dmlEx.getMessage());
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            throw new AuraHandledException('Unexpected error: ' + ex.getMessage());
        }
    }
}