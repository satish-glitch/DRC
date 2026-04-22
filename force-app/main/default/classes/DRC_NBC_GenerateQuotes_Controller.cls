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
*                  | Opportunity pricebook when OLIs exist.
* 1.7 | Apr 2026   | Changed to use Standard Price Book instead of custom price book
* 1.8 | Apr 2026   | Product search by name pattern only (not currency-filtered);
*                  | currency auto-set from Opportunity; packing qty always returned
**/
public with sharing class DRC_NBC_GenerateQuotes_Controller {

    // ─── Helper: fetch Standard Price Book Id ────────────────────────────────
    private static Id getStandardPricebookId() {
        if (Test.isRunningTest()) {
            return Test.getStandardPricebookId();
        }
        return [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ].Id;
    }

    // ─── Wrappers ─────────────────────────────────────────────────────────────
    public class QuoteWrapper {
        @AuraEnabled public String oppCurrency;
        @AuraEnabled public Id     accountId;
        @AuraEnabled public String accountSpecialInstruction;
        @AuraEnabled public String paymentTerm;
        @AuraEnabled public String paymentTermDescription;
         @AuraEnabled public String incoterms;
    }
    

    public class AccountAddressWrapper {
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
        @AuraEnabled public String countryCode;

        public AccountAddressWrapper(String st, String ct, String sta, String pc, String cntry, String cc) {
            this.street      = st;
            this.city        = ct;
            this.state       = sta;
            this.postalCode  = pc;
            this.country     = cntry;
            this.countryCode = cc;
        }
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
        @AuraEnabled public Id      PricebookEntryId;
        @AuraEnabled public Id      Product2Id;
        @AuraEnabled public String  Name;
        @AuraEnabled public Decimal UnitPrice;
        @AuraEnabled public String  FGCode;
        @AuraEnabled public String  HSNCode;
        @AuraEnabled public String  QuantityUnitOfMeasure;
        @AuraEnabled public List<PackingDetailWrapper> PackingDetails;

        public ProductWrapper(
            Id pbeId, Id p2Id, String nm, Decimal price,
            String fg, String hsn, String uom,
            List<PackingDetailWrapper> packing
        ) {
            this.PricebookEntryId      = pbeId;
            this.Product2Id            = p2Id;
            this.Name                  = nm;
            this.UnitPrice             = price;
            this.FGCode                = fg;
            this.HSNCode               = hsn;
            this.QuantityUnitOfMeasure = uom;
            this.PackingDetails        = packing;
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
        @AuraEnabled public List<OpportunityLineItem>            olis;
        @AuraEnabled public Map<Id, List<PackingDetailWrapper>>  packingDetailsMap;
    }

    // ─── getQuoteMdtDetails ───────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static QuoteWrapper getQuoteMdtDetails(Id oppId) {
        QuoteWrapper w = new QuoteWrapper();
        Opportunity opp = [
            SELECT CurrencyISOCode, AccountId, Account.DRC_NBC_Special_Instructions__c,
            Account.DRC_NBC_Payment_Terms__c,
            Account.DRC_NBC_Payment_Terms_Description__c, Account.DRC_Inco_Term__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        w.oppCurrency              = opp.CurrencyISOCode;
        w.accountId                = opp.AccountId;
        w.accountSpecialInstruction = opp.Account.DRC_NBC_Special_Instructions__c;
        w.paymentTerm = opp.Account != null ? opp.Account.DRC_NBC_Payment_Terms__c : null;
        w.paymentTermDescription = opp.Account != null ? opp.Account.DRC_NBC_Payment_Terms_Description__c : null;
        w.incoterms              = opp.Account != null ? opp.Account.DRC_Inco_Term__c : null;
        return w;
    }

    // ─── getOpportunityContacts ───────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Contact> getOpportunityContacts(Id oppId) {
        try {
            Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1];
            return [
                SELECT Id, Name, Email, Phone, Fax
                FROM Contact
                WHERE AccountId = :opp.AccountId
                ORDER BY Name
            ];
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
                        
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            return new AccountAddressWrapper(
                opp.Account.BillingStreet,
                opp.Account.BillingCity,
                opp.Account.BillingState,
                opp.Account.BillingPostalCode,
                opp.Account.BillingCountry,
                opp.Account.BillingCountryCode
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
                FROM DRC_NBC_Addresses__c
                WHERE DRC_NBC_Account__c = :opp.AccountId
                AND   DRC_NBC_Type__c    = 'Shipping'
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching addresses: ' + e.getMessage());
        }
    }

    // ─── searchProducts ───────────────────────────────────────────────────────
    // v1.8: Searches by product name pattern ONLY — no currency filter.
    //       Returns the best available PricebookEntry (matching opp currency first,
    //       then INR, then any active entry) so the modal works regardless of currency.
    @AuraEnabled
    public static List<ProductWrapper> searchProducts(String keyword, String currencyIsoCode, Id accountId) {
        try {
            if (String.isBlank(keyword)) {
                return new List<ProductWrapper>();
            }

            Id standardPricebookId = getStandardPricebookId();
            String likePattern     = '%' + keyword.trim() + '%';

            // ── 1. Build allowed-product filter (account restrictions) ─────────
            Set<Id> allowedProductIds = new Set<Id>();
            if (accountId != null) {
                for (DRC_NBC_Restricted_Product__c rp : [
                    SELECT DRC_NBC_Product__c
                    FROM   DRC_NBC_Restricted_Product__c
                    WHERE  DRC_NBC_Customer__c = :accountId
                ]) {
                    allowedProductIds.add(rp.DRC_NBC_Product__c);
                }
            }

            // ── 2. Fetch matching products ────────────────────────────────────
            List<Product2> products;
            if (!allowedProductIds.isEmpty()) {
                products = [
                    SELECT Id, Name, DRC_NBC_FG_Code__c, DRC_NBC_HSN_SAC_Code__c, QuantityUnitOfMeasure
                    FROM   Product2
                    WHERE  IsActive = true
                    AND    Name     LIKE :likePattern
                    AND    Id       IN  :allowedProductIds
                    ORDER BY Name
                    LIMIT 100
                ];
            } /*else {
                products = [
                    SELECT Id, Name, DRC_NBC_FG_Code__c, DRC_NBC_HSN_SAC_Code__c, QuantityUnitOfMeasure
                    FROM   Product2
                    WHERE  IsActive = true
                    AND    Name     LIKE :likePattern
                    ORDER BY Name
                    LIMIT 100
                ];
            }*/

            if (products.isEmpty()) return new List<ProductWrapper>();

            Set<Id> product2Ids = new Set<Id>();
            Map<Id, Product2> productById = new Map<Id, Product2>();
            for (Product2 p : products) {
                product2Ids.add(p.Id);
                productById.put(p.Id, p);
            }

            // ── 3. Ensure PricebookEntries exist for the target currency ──────
            // (creates them if missing, based on INR price)
            if (String.isNotBlank(currencyIsoCode) && currencyIsoCode != 'INR') {
                ensurePricebookEntriesForCurrency(product2Ids, currencyIsoCode, standardPricebookId);
            }

            // ── 4. Fetch ALL active PBEs for these products (any currency) ────
            //       We'll pick the best one per product in priority order:
            //       (a) target currency  (b) INR  (c) first available
            List<PricebookEntry> allEntries = [
                SELECT Id, Product2Id, UnitPrice, CurrencyIsoCode
                FROM   PricebookEntry
                WHERE  IsActive      = true
                AND    Pricebook2Id  = :standardPricebookId
                AND    Product2Id    IN :product2Ids
                ORDER BY Product2Id, CurrencyIsoCode
            ];

            // Build a map: productId → best PBE
            Map<Id, PricebookEntry> bestPbeByProduct = new Map<Id, PricebookEntry>();
            String targetCcy = String.isNotBlank(currencyIsoCode) ? currencyIsoCode : 'INR';

            for (PricebookEntry pbe : allEntries) {
                PricebookEntry existing = bestPbeByProduct.get(pbe.Product2Id);
                if (existing == null) {
                    // first entry seen — use it
                    bestPbeByProduct.put(pbe.Product2Id, pbe);
                } else if (pbe.CurrencyIsoCode == targetCcy) {
                    // target currency wins over anything else
                    bestPbeByProduct.put(pbe.Product2Id, pbe);
                } else if (pbe.CurrencyIsoCode == 'INR' && existing.CurrencyIsoCode != targetCcy) {
                    // INR wins over "any other" fallback
                    bestPbeByProduct.put(pbe.Product2Id, pbe);
                }
            }

            // ── 5. Fetch packing details ──────────────────────────────────────
            Map<Id, List<PackingDetailWrapper>> productPackingMap = new Map<Id, List<PackingDetailWrapper>>();
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

            // ── 6. Build result list ──────────────────────────────────────────
            List<ProductWrapper> results = new List<ProductWrapper>();
            for (Product2 prod : products) {
                PricebookEntry pbe = bestPbeByProduct.get(prod.Id);
                if (pbe == null) continue;   // no active PBE at all — skip

                List<PackingDetailWrapper> packing = productPackingMap.containsKey(prod.Id)
                    ? productPackingMap.get(prod.Id)
                    : new List<PackingDetailWrapper>();

                results.add(new ProductWrapper(
                    pbe.Id, prod.Id, prod.Name, pbe.UnitPrice,
                    prod.DRC_NBC_FG_Code__c, prod.DRC_NBC_HSN_SAC_Code__c,
                    prod.QuantityUnitOfMeasure, packing
                ));
            }

            return results;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error searching products: ' + e.getMessage());
        }
    }

    // ─── getExistingOLIs ─────────────────────────────────────────────────────
    @AuraEnabled
    public static OLIWrapper getExistingOLIs(Id oppId) {
        if (String.isBlank(oppId)) {
            throw new AuraHandledException('Opportunity ID is required.');
        }

        List<OpportunityLineItem> olis = [
            SELECT Id,
                   Product2.Name, Product2.QuantityUnitOfMeasure,
                   Product2.DRC_NBC_FG_Code__c, Product2.DRC_NBC_HSN_SAC_Code__c,
                   PricebookEntryId, Description, Discount,
                   Product2Id, Quantity, UnitPrice,
                   DRC_NBC_Packing_Size__c, DRC_NBC_Packing_Qauntity__c
            FROM  OpportunityLineItem
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
                if (!packingMap.containsKey(pd.Product__c)) {
                    packingMap.put(pd.Product__c, new List<PackingDetailWrapper>());
                }
                String qtyStr = pd.DRC_NBC_Packing_Qauntity__c != null
                    ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c) : '';
                packingMap.get(pd.Product__c).add(
                    new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr)
                );
            }
        }

        OLIWrapper result  = new OLIWrapper();
        result.olis            = olis;
        result.packingDetailsMap = packingMap;
        return result;
    }

    // ─── createQuoteWithLines ─────────────────────────────────────────────────
    @AuraEnabled
    public static String createQuoteWithLines(Id oppId, Quote quoteData, List<LineItemWrapper> lineItems) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (lineItems == null || lineItems.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false, 'error' => 'No products selected.'
                });
            }

            if (String.isNotBlank(quoteData.ContactId)) {
                Contact con = [SELECT Id, Name, Email FROM Contact WHERE Id = :quoteData.ContactId LIMIT 1];
                if (String.isBlank(con.Email)) {
                    return JSON.serialize(new Map<String, Object>{
                        'success' => false,
                        'error'   => 'Please provide email for ' + con.Name + '.'
                    });
                }
            }

            Opportunity opp = [
                SELECT Id, AccountId, Pricebook2Id, CurrencyIsoCode
                FROM  Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];

            Id standardPricebookId = getStandardPricebookId();
            if (opp.Pricebook2Id == null || opp.Pricebook2Id != standardPricebookId) {
                opp.Pricebook2Id = standardPricebookId;
                update opp;
            }

            quoteData.OpportunityId = oppId;
            quoteData.Pricebook2Id  = standardPricebookId;
            quoteData.Status        = String.isNotBlank(quoteData.Status) ? quoteData.Status : 'Draft';

            // Currency always comes from Opportunity
            String effectiveCurrency = opp.CurrencyIsoCode;
            quoteData.CurrencyIsoCode = effectiveCurrency;

            insert quoteData;

            // ── Shipping address ──────────────────────────────────────────────
            if (quoteData.DRC_NBC_Shipping_Address_Id__c != null) {
                DRC_NBC_Addresses__c addr = [
                    SELECT DRC_NBC_Address__City__s, DRC_NBC_Address__c,
                           DRC_NBC_Address__CountryCode__s, DRC_NBC_Address__PostalCode__s,
                           DRC_NBC_Address__StateCode__s,  DRC_NBC_Address__Street__s
                    FROM   DRC_NBC_Addresses__c
                    WHERE  Id = :quoteData.DRC_NBC_Shipping_Address_Id__c
                    LIMIT 1
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
                    SELECT Account.BillingStreet, Account.BillingCity, Account.BillingState,
                           Account.BillingPostalCode, Account.BillingCountry, Account.BillingCountryCode
                    FROM  Opportunity
                    WHERE Id = :oppId
                    LIMIT 1
                ];
                if (oppA.Account != null) {
                    quoteData.BillingStreet     = oppA.Account.BillingStreet;
                    quoteData.BillingCity       = oppA.Account.BillingCity;
                    quoteData.BillingState      = oppA.Account.BillingState;
                    quoteData.BillingPostalCode = oppA.Account.BillingPostalCode;
                    quoteData.BillingCountry    = oppA.Account.BillingCountry;
                    quoteData.BillingCountryCode= oppA.Account.BillingCountryCode;
                }
            }
            update quoteData;

            // ── Build QLIs ────────────────────────────────────────────────────
            Set<Id> product2Ids = new Set<Id>();
            for (LineItemWrapper w : lineItems) {
                if (w.Product2Id != null) product2Ids.add(w.Product2Id);
            }

            Map<Id, String> productIdToName = new Map<Id, String>();
            for (Product2 p : [SELECT Id, Name FROM Product2 WHERE Id IN :product2Ids]) {
                productIdToName.put(p.Id, p.Name);
            }

            ensurePricebookEntriesForCurrency(product2Ids, effectiveCurrency, standardPricebookId);

            Map<Id, Id> productIdToPBE = new Map<Id, Id>();
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id
                FROM   PricebookEntry
                WHERE  Pricebook2Id = :standardPricebookId
                AND    Product2Id   IN :product2Ids
                AND    IsActive     = true
                AND    CurrencyIsoCode = :effectiveCurrency
            ]) {
                productIdToPBE.put(pbe.Product2Id, pbe.Id);
            }

            List<QuoteLineItem> qlis        = new List<QuoteLineItem>();
            List<String>        missingProds = new List<String>();

            for (LineItemWrapper w : lineItems) {
                if (w.Product2Id == null) continue;

                Id pbEntryId = productIdToPBE.get(w.Product2Id);
                if (pbEntryId == null && w.PricebookEntryId != null) pbEntryId = w.PricebookEntryId;

                if (pbEntryId == null) {
                    missingProds.add(
                        productIdToName.containsKey(w.Product2Id)
                            ? productIdToName.get(w.Product2Id) : 'Unknown Product'
                    );
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

                if (String.isNotBlank(w.PackingSize))     qli.DRC_NBC_Packing_Size__c      = w.PackingSize;
                if (String.isNotBlank(w.PackingQuantity)) qli.DRC_NBC_Packing_Qauntity__c  = w.PackingQuantity;

                qlis.add(qli);
            }

            if (!missingProds.isEmpty()) {
                Database.rollback(sp);
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error'   => 'Missing PricebookEntries for: ' + String.join(missingProds, ', ')
                });
            }

            if (qlis.isEmpty()) {
                Database.rollback(sp);
                return JSON.serialize(new Map<String, Object>{ 'success' => false, 'error' => 'No valid products.' });
            }

            insert qlis;

            return JSON.serialize(new Map<String, Object>{
                'success' => true, 'quoteId' => quoteData.Id
            });

        } catch (Exception e) {
            Database.rollback(sp);
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error'   => 'Error creating quote: ' + e.getMessage()
            });
        }
    }

    // ─── ensurePricebookEntriesForCurrency ───────────────────────────────────
    private static void ensurePricebookEntriesForCurrency(
        Set<Id> productIds,
        String  targetCurrency,
        Id      pricebook2Id
    ) {
        if (productIds == null || productIds.isEmpty()
                || String.isBlank(targetCurrency) || pricebook2Id == null) return;

        Map<Id, PricebookEntry> targetPbeByProductId = new Map<Id, PricebookEntry>();
        List<PricebookEntry>    toActivate            = new List<PricebookEntry>();

        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, UnitPrice, CurrencyIsoCode, IsActive
            FROM   PricebookEntry
            WHERE  Pricebook2Id    = :pricebook2Id
            AND    Product2Id      IN :productIds
            AND    CurrencyIsoCode = :targetCurrency
        ]) {
            targetPbeByProductId.put(pbe.Product2Id, pbe);
            if (!pbe.IsActive) { pbe.IsActive = true; toActivate.add(pbe); }
        }

        if (!toActivate.isEmpty()) update toActivate;

        Set<Id> missingProductIds = new Set<Id>(productIds);
        missingProductIds.removeAll(targetPbeByProductId.keySet());
        if (missingProductIds.isEmpty()) return;

        Map<Id, PricebookEntry> inrPbeByProductId = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, UnitPrice
            FROM   PricebookEntry
            WHERE  Pricebook2Id    = :pricebook2Id
            AND    Product2Id      IN :missingProductIds
            AND    CurrencyIsoCode = 'INR'
        ]) {
            inrPbeByProductId.put(pbe.Product2Id, pbe);
        }

        List<PricebookEntry> toInsert = new List<PricebookEntry>();
        for (Id productId : missingProductIds) {
            PricebookEntry inrPbe = inrPbeByProductId.get(productId);
            if (inrPbe == null) continue;
            toInsert.add(new PricebookEntry(
                Pricebook2Id    = pricebook2Id,
                Product2Id      = productId,
                CurrencyIsoCode = targetCurrency,
                UnitPrice       = inrPbe.UnitPrice,
                IsActive        = true
            ));
        }

        if (!toInsert.isEmpty()) insert toInsert;
    }
}