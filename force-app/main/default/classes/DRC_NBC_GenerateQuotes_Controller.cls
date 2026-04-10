/**
* @File Name   : DRC_NBC_GenerateQuotes_Controller.cls
* @Description : Controller for generating quotes from opportunities
* @Modification Log :
*==============================================================================
* Ver | Date       | Modification
*==============================================================================
* 1.0 | Nov 2025   | Initial Version
* 1.1 | Nov 2025   | Fixed PricebookEntry fallback handling
* 1.2 | Nov 2025   | Changed to fetch billing address from Account
* 1.3 | Feb 2026   | Added Packing Size support
* 1.4 | Feb 2026   | Packing Size/Qty from DRC_NBC_Packing_Details__c child object
* 1.5 | Mar 2026   | Added getExistingOLIs so Generate Quote modal pre-loads OLIs
* 1.6 | Mar 2026   | Fixed FIELD_INTEGRITY_EXCEPTION — no longer force-changes
*                  | Opportunity pricebook when OLIs exist. Resolves pricebook
*                  | from Opportunity instead of hardcoding DRC PriceBook.
**/
public with sharing class DRC_NBC_GenerateQuotes_Controller {
    
    // ─── Helper: fetch DRC PriceBook Id ──────────────────────────────────────
    private static Id getDRCPricebookId() {
        String externalId = Label.DRC_Price_Books_External_Id;
        Pricebook2 drcPb = [
            SELECT Id FROM Pricebook2
            WHERE  Name                   = 'DRC PriceBook'
            AND  IsActive               = true
            AND DRC_NBC_External_Id__c = :externalId
            LIMIT  1
        ];
        return drcPb.Id;
    }
    
    // ─── Wrappers ─────────────────────────────────────────────────────────────
    public class QuoteWrapper {
        @AuraEnabled public String oppCurrency;
        @AuraEnabled public Id     accountId;
        @AuraEnabled public String accountSpecialInstruction;
    }
    
    public class AccountAddressWrapper {
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
        @AuraEnabled public String countryCode;
        public AccountAddressWrapper(String st, String ct, String sta, String pc, String cntry, String cc) {
            this.street = st; this.city = ct; this.state = sta;
            this.postalCode = pc; this.country = cntry; this.countryCode = cc;
        }
    }
    
    public class PackingDetailWrapper {
        @AuraEnabled public String packingSize;
        @AuraEnabled public String packingQuantity;
        public PackingDetailWrapper(String size, String qty) {
            this.packingSize = size; this.packingQuantity = qty;
        }
    }
    
    public class ProductWrapper {
        @AuraEnabled public Id      PricebookEntryId;
        @AuraEnabled public Id      Product2Id;
        @AuraEnabled public String  Name;
        @AuraEnabled public Decimal UnitPrice;
        @AuraEnabled public String  FGCode;
        @AuraEnabled public String  HSNCode;
        @AuraEnabled public String  QuantityUnitOfMeasure;
        @AuraEnabled public List<PackingDetailWrapper> PackingDetails;
        public ProductWrapper(Id pbeId, Id p2Id, String nm, Decimal price,
                              String fg, String hsn, String uom,
                              List<PackingDetailWrapper> packing) {
                                  this.PricebookEntryId   = pbeId; this.Product2Id = p2Id;
                                  this.Name = nm; this.UnitPrice = price;
                                  this.FGCode = fg; this.HSNCode = hsn;
                                  this.QuantityUnitOfMeasure = uom; this.PackingDetails = packing;
                              }
    }
    
    public class LineItemWrapper {
        @AuraEnabled public Id      Product2Id            { get; set; }
        @AuraEnabled public Id      PricebookEntryId      { get; set; }
        @AuraEnabled public Integer Quantity              { get; set; }
        @AuraEnabled public Decimal UnitPrice             { get; set; }
        @AuraEnabled public String  Description           { get; set; }
        @AuraEnabled public String  CurrencyIsoCode       { get; set; }
        @AuraEnabled public String  QuantityUnitOfMeasure { get; set; }
        @AuraEnabled public String  PackingSize           { get; set; }
        @AuraEnabled public String  PackingQuantity       { get; set; }
        public LineItemWrapper() {}
    }
    
    public class OLIWrapper {
        @AuraEnabled public List<OpportunityLineItem>           olis;
        @AuraEnabled public Map<Id, List<PackingDetailWrapper>> packingDetailsMap;
    }
    
    // ─── getQuoteMdtDetails ───────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static QuoteWrapper getQuoteMdtDetails(Id oppId) {
        QuoteWrapper w = new QuoteWrapper();
        Opportunity opp = [
            SELECT CurrencyISOCode, AccountId, Account.DRC_NBC_Special_Instructions__c
            FROM   Opportunity WHERE Id = :oppId LIMIT 1
        ];
        w.oppCurrency               = opp.CurrencyISOCode;
        w.accountId                 = opp.AccountId;
        w.accountSpecialInstruction = opp.Account.DRC_NBC_Special_Instructions__c;
        return w;
    }
    
    // ─── getOpportunityContacts ───────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Contact> getOpportunityContacts(Id oppId) {
        try {
            Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1];
            return [SELECT Id, Name, Email, Phone, Fax FROM Contact
                    WHERE AccountId = :opp.AccountId ORDER BY Name];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching contacts: ' + e.getMessage());
        }
    }
    
    // ─── getAccountBillingAddress ─────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static AccountAddressWrapper getAccountBillingAddress(Id oppId) {
        try {
            Opportunity opp = [
                SELECT Account.BillingStreet, Account.BillingCity, Account.BillingState,
                Account.BillingPostalCode, Account.BillingCountry, Account.BillingCountryCode
                FROM   Opportunity WHERE Id = :oppId LIMIT 1
            ];
            return new AccountAddressWrapper(
                opp.Account.BillingStreet, opp.Account.BillingCity,
                opp.Account.BillingState,  opp.Account.BillingPostalCode,
                opp.Account.BillingCountry, opp.Account.BillingCountryCode
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching billing address: ' + e.getMessage());
        }
    }
    
    // ─── getAccountAddresses ──────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<DRC_NBC_Addresses__c> getAccountAddresses(Id oppId) {
        try {
            Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1];
            return [
                SELECT Id, DRC_NBC_Type__c, DRC_NBC_Address__c
                FROM   DRC_NBC_Addresses__c
                WHERE  DRC_NBC_Account__c = :opp.AccountId
                AND  DRC_NBC_Type__c    = 'Shipping'
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching addresses: ' + e.getMessage());
        }
    }
    
    // ─── searchProducts ───────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> searchProducts(String keyword, String currencyIsoCode, Id accountId) {
        try {
            if (String.isBlank(currencyIsoCode))
                throw new AuraHandledException('Currency code is required.');
            
            Id drcPricebookId = getDRCPricebookId();
            
            Set<Id> allowedProductIds = new Set<Id>();
            if (accountId != null) {
                for (DRC_NBC_Restricted_Product__c rp : [
                    SELECT DRC_NBC_Product__c FROM DRC_NBC_Restricted_Product__c
                    WHERE  DRC_NBC_Customer__c = :accountId
                ]) { allowedProductIds.add(rp.DRC_NBC_Product__c); }
            }
            
            List<PricebookEntry> entries;
            String likePattern = '%' + keyword + '%';
            
            if (!allowedProductIds.isEmpty()) {
                entries = [
                    SELECT Id, Product2Id, Product2.Name, Product2.DRC_NBC_FG_Code__c,
                    Product2.DRC_NBC_HSN_SAC_Code__c, Product2.QuantityUnitOfMeasure,
                    UnitPrice, CurrencyIsoCode
                    FROM   PricebookEntry
                    WHERE  IsActive = true AND Product2.IsActive = true
                    AND  Product2.Name LIKE :likePattern
                    AND  CurrencyIsoCode = :currencyIsoCode
                    AND  Pricebook2Id = :drcPricebookId
                    AND  Product2Id IN :allowedProductIds
                    ORDER BY Product2.Name LIMIT 100
                ];
            } else {
                entries = [
                    SELECT Id, Product2Id, Product2.Name, Product2.DRC_NBC_FG_Code__c,
                    Product2.DRC_NBC_HSN_SAC_Code__c, Product2.QuantityUnitOfMeasure,
                    UnitPrice, CurrencyIsoCode
                    FROM   PricebookEntry
                    WHERE  IsActive = true AND Product2.IsActive = true
                    AND  Product2.Name LIKE :likePattern
                    AND  CurrencyIsoCode = :currencyIsoCode
                    AND  Pricebook2Id = :drcPricebookId
                    ORDER BY Product2.Name LIMIT 100
                ];
            }
            
            Set<Id> product2Ids = new Set<Id>();
            for (PricebookEntry pbe : entries) product2Ids.add(pbe.Product2Id);
            
            Map<Id, List<PackingDetailWrapper>> productPackingMap = new Map<Id, List<PackingDetailWrapper>>();
            for (DRC_NBC_Packing_Details__c pd : [
                SELECT Id, Product__c, DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Qauntity__c
                FROM   DRC_NBC_Packing_Details__c
                WHERE  Product__c IN :product2Ids ORDER BY DRC_NBC_Packing_Size__c
            ]) {
                if (!productPackingMap.containsKey(pd.Product__c))
                    productPackingMap.put(pd.Product__c, new List<PackingDetailWrapper>());
                String qtyStr = pd.DRC_NBC_Packing_Qauntity__c != null
                    ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c) : '';
                productPackingMap.get(pd.Product__c).add(
                    new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr));
            }
            
            Set<Id> seen = new Set<Id>();
            List<ProductWrapper> results = new List<ProductWrapper>();
            for (PricebookEntry pbe : entries) {
                if (!seen.contains(pbe.Product2Id)) {
                    seen.add(pbe.Product2Id);
                    List<PackingDetailWrapper> packing = productPackingMap.containsKey(pbe.Product2Id)
                        ? productPackingMap.get(pbe.Product2Id) : new List<PackingDetailWrapper>();
                    results.add(new ProductWrapper(
                        pbe.Id, pbe.Product2Id, pbe.Product2.Name, pbe.UnitPrice,
                        pbe.Product2.DRC_NBC_FG_Code__c, pbe.Product2.DRC_NBC_HSN_SAC_Code__c,
                        pbe.Product2.QuantityUnitOfMeasure, packing));
                }
            }
            return results;
        } catch (Exception e) {
            throw new AuraHandledException('Error searching products: ' + e.getMessage());
        }
    }
    
    // ─── getExistingOLIs ──────────────────────────────────────────────────────
    @AuraEnabled
    public static OLIWrapper getExistingOLIs(Id oppId) {
        if (String.isBlank(oppId)) {
            throw new AuraHandledException('Opportunity ID is required.');
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
            WHERE OpportunityId = :oppId
        ];
        
        Set<Id> product2Ids = new Set<Id>();
        for (OpportunityLineItem oli : olis) {
            if (oli.Product2Id != null) product2Ids.add(oli.Product2Id);
        }
        
        Map<Id, List<PackingDetailWrapper>> packingMap = new Map<Id, List<PackingDetailWrapper>>();
        if (!product2Ids.isEmpty()) {
            for (DRC_NBC_Packing_Details__c pd : [
                SELECT Id, Product__c, DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Qauntity__c
                FROM   DRC_NBC_Packing_Details__c
                WHERE  Product__c IN :product2Ids
                ORDER BY DRC_NBC_Packing_Size__c
            ]) {
                if (!packingMap.containsKey(pd.Product__c))
                    packingMap.put(pd.Product__c, new List<PackingDetailWrapper>());
                String qtyStr = pd.DRC_NBC_Packing_Qauntity__c != null
                    ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c) : '';
                packingMap.get(pd.Product__c).add(
                    new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr));
            }
        }
        
        OLIWrapper result        = new OLIWrapper();
        result.olis              = olis;
        result.packingDetailsMap = packingMap;
        return result;
    }
    
    // ─── createQuoteWithLines ─────────────────────────────────────────────────
    @AuraEnabled
    public static String createQuoteWithLines(Id oppId, Quote quoteData, List<LineItemWrapper> lineItems) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (lineItems == null || lineItems.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{'success'=>false,'error'=>'No products selected.'});
            }
            
            // Validate contact email
            if (String.isNotBlank(quoteData.ContactId)) {
                Contact con = [SELECT Id, Name, Email FROM Contact WHERE Id = :quoteData.ContactId LIMIT 1];
                if (String.isBlank(con.Email)) {
                    return JSON.serialize(new Map<String, Object>{
                        'success'=>false,'error'=>'Please provide email for ' + con.Name + '.'});
                }
            }
            
            Opportunity opp = [
                SELECT Id, AccountId, Pricebook2Id, CurrencyIsoCode
                FROM   Opportunity WHERE Id = :oppId LIMIT 1
            ];
            
            Id drcPricebookId = getDRCPricebookId();
            
            // ── Resolve pricebook ─────────────────────────────────────────────
            // Rule: always use the Opp's existing pricebook if it is already set
            // (OLIs were added via DRC PriceBook so it will already be DRC).
            // Only set it when null — safe because no OLIs can exist yet then.
            // NEVER force-change when OLIs exist → avoids FIELD_INTEGRITY_EXCEPTION.
            Id resolvedPricebookId;
            if (opp.Pricebook2Id != null) {
                resolvedPricebookId = opp.Pricebook2Id;
            } else {
                // No pricebook yet → no OLIs yet → safe to set
                opp.Pricebook2Id    = drcPricebookId;
                update opp;
                resolvedPricebookId = drcPricebookId;
            }
            
            // ── Create the Quote ──────────────────────────────────────────────
            quoteData.OpportunityId   = oppId;
            quoteData.Pricebook2Id    = resolvedPricebookId;
            quoteData.Status          = String.isNotBlank(quoteData.Status) ? quoteData.Status : 'Draft';
            quoteData.CurrencyIsoCode = opp.CurrencyIsoCode;
            insert quoteData;
            
            // ── Shipping address ──────────────────────────────────────────────
            if (quoteData.DRC_NBC_Shipping_Address_Id__c != null) {
                DRC_NBC_Addresses__c addr = [
                    SELECT DRC_NBC_Address__City__s, DRC_NBC_Address__c,
                    DRC_NBC_Address__CountryCode__s, DRC_NBC_Address__PostalCode__s,
                    DRC_NBC_Address__StateCode__s, DRC_NBC_Address__Street__s
                    FROM   DRC_NBC_Addresses__c
                    WHERE  Id = :quoteData.DRC_NBC_Shipping_Address_Id__c LIMIT 1
                ];
                if (addr.DRC_NBC_Address__c != null) {
                    quoteData.ShippingStreet      = addr.DRC_NBC_Address__Street__s;
                    quoteData.ShippingCity        = addr.DRC_NBC_Address__City__s;
                    quoteData.ShippingPostalCode  = addr.DRC_NBC_Address__PostalCode__s;
                    quoteData.ShippingStateCode   = addr.DRC_NBC_Address__StateCode__s;
                    quoteData.ShippingCountryCode = addr.DRC_NBC_Address__CountryCode__s;
                }
            }
            
            // ── Billing address fallback ──────────────────────────────────────
            if (String.isBlank(quoteData.BillingStreet)) {
                Opportunity oppA = [
                    SELECT Account.BillingStreet, Account.BillingCity,
                    Account.BillingState,  Account.BillingPostalCode,
                    Account.BillingCountry, Account.BillingCountryCode
                    FROM   Opportunity WHERE Id = :oppId LIMIT 1
                ];
                if (oppA.Account != null) {
                    quoteData.BillingStreet      = oppA.Account.BillingStreet;
                    quoteData.BillingCity        = oppA.Account.BillingCity;
                    quoteData.BillingState       = oppA.Account.BillingState;
                    quoteData.BillingPostalCode  = oppA.Account.BillingPostalCode;
                    quoteData.BillingCountry     = oppA.Account.BillingCountry;
                    quoteData.BillingCountryCode = oppA.Account.BillingCountryCode;
                }
            }
            update quoteData;
            
            // ── Build QuoteLineItems ──────────────────────────────────────────
            Set<Id> product2Ids = new Set<Id>();
            for (LineItemWrapper w : lineItems) if (w.Product2Id != null) product2Ids.add(w.Product2Id);
            
            Map<Id, String> productIdToName = new Map<Id, String>();
            for (Product2 p : [SELECT Id, Name FROM Product2 WHERE Id IN :product2Ids])
                productIdToName.put(p.Id, p.Name);
            
            // Look up PBEs using the RESOLVED pricebook (same one the Opp has)
            Map<Id, Id> productIdToPBE = new Map<Id, Id>();
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id FROM PricebookEntry
                WHERE  Pricebook2Id    = :resolvedPricebookId
                AND  Product2Id      IN :product2Ids
                AND  IsActive        = true
                AND  CurrencyIsoCode = :quoteData.CurrencyIsoCode
            ]) {
                productIdToPBE.put(pbe.Product2Id, pbe.Id);
            }
            
            List<QuoteLineItem> qlis         = new List<QuoteLineItem>();
            List<String>        missingProds = new List<String>();
            
            for (LineItemWrapper w : lineItems) {
                if (w.Product2Id == null) continue;
                
                Id pbEntryId = productIdToPBE.get(w.Product2Id);
                // Fallback: use PricebookEntryId passed from the LWC
                if (pbEntryId == null && w.PricebookEntryId != null) pbEntryId = w.PricebookEntryId;
                
                if (pbEntryId == null) {
                    missingProds.add(productIdToName.containsKey(w.Product2Id)
                                     ? productIdToName.get(w.Product2Id) : 'Unknown Product');
                    continue;
                }
                
                QuoteLineItem qli = new QuoteLineItem(
                    QuoteId          = quoteData.Id,
                    PricebookEntryId = pbEntryId,
                    Product2Id       = w.Product2Id,
                    Quantity         = (w.Quantity == null || w.Quantity == 0) ? 1 : w.Quantity,
                    UnitPrice        = w.UnitPrice != null ? w.UnitPrice : 0,
                    Description      = w.Description
                );
                if (String.isNotBlank(w.PackingSize))     qli.DRC_NBC_Packing_Size__c     = w.PackingSize;
                if (String.isNotBlank(w.PackingQuantity)) qli.DRC_NBC_Packing_Qauntity__c = w.PackingQuantity;
                qlis.add(qli);
            }
            
            if (!missingProds.isEmpty()) {
                Database.rollback(sp);
                return JSON.serialize(new Map<String, Object>{
                    'success'=>false,
                        'error'=>'Missing PricebookEntries for: ' + String.join(missingProds, ', ')});
            }
            if (qlis.isEmpty()) {
                Database.rollback(sp);
                return JSON.serialize(new Map<String, Object>{'success'=>false,'error'=>'No valid products.'});
            }
            
            insert qlis;
            return JSON.serialize(new Map<String, Object>{'success'=>true,'quoteId'=>quoteData.Id});
            
        } catch (Exception e) {
            Database.rollback(sp);
            return JSON.serialize(new Map<String, Object>{
                'success'=>false,'error'=>'Error creating quote: ' + e.getMessage()});
        }
    }
}