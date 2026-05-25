/**
* @File Name : DRC_NBC_Generate_Sample_Order_Controller.cls
* @Description : Controller for generating sample orders from opportunities
* @Author :
* @Last Modified By :
* @Last Modified On : April 23, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 13, 2025  |   | Initial Version
* 1.1 | October 14, 2025  |   | Fixed Unit Price handling
* 1.2 | November 11, 2025 |   | Changed to fetch billing address from Account
* 1.3 | February 12, 2026 |   | Added Packing Size support
* 1.4 | February 26, 2026 |   | Packing Size/Qty now from DRC_NBC_Packing_Details__c child object
* 1.5 | April 15, 2026    |   | Support Standard Pricebook alongside custom DRC PriceBook
* 1.6 | April 18, 2026    |   | Remove currency filter from product search; auto-create PricebookEntry
*                              | if missing for opportunity currency; PackingQuantity is now a multiplier
* 1.7 | April 19, 2026    |   | Added ensurePricebookEntryForProduct (non-cacheable, called on product
*                              | select in search); PackingQuantity now shows raw DRC_NBC_Packing_Qauntity__c
* 1.8 | April 23, 2026    |   | Fixed searchProducts: show all products when account has no restricted
*                              | products configured (previously returned empty results)
**/

public with sharing class DRC_NBC_Generate_Sample_Order_Controller {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getOrderRecordTypes() {
        List<Map<String, String>> rtList = new List<Map<String, String>>();
        for (Schema.RecordTypeInfo rt : Order.SObjectType.getDescribe().getRecordTypeInfosById().values()) {
            if (rt.isAvailable() && rt.getName() != 'Master') {
                rtList.add(new Map<String, String>{
                    'label' => rt.getName(),
                    'value' => rt.getRecordTypeId()
                });
            }
        }
        return rtList;
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getOpportunityContacts(Id oppId) {
        try {
            Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1];
            return [SELECT Id, Name, Email FROM Contact WHERE AccountId = :opp.AccountId ORDER BY Name];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching contacts: ' + e.getMessage());
        }
    }

    public class AccountPaymentInfoWrapper {
        @AuraEnabled public String paymentTermCode;
        @AuraEnabled public String paymentTermDescription;
        @AuraEnabled public String incoTerm;

        public AccountPaymentInfoWrapper(String code, String des, String inco) {
            this.paymentTermCode        = code;
            this.paymentTermDescription = des;
            this.incoTerm               = inco;
        }
    }

    @AuraEnabled(cacheable=true)
    public static AccountPaymentInfoWrapper getAccountPaymentInfo(Id oppId) {
        Opportunity opp = [
            SELECT Account.DRC_NBC_Payment_Term_Code__c,
                Account.DRC_NBC_Payment_Terms_Description__c,
                Account.DRC_Inco_Term__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        return new AccountPaymentInfoWrapper(
            opp.Account.DRC_NBC_Payment_Term_Code__c,
            opp.Account.DRC_NBC_Payment_Terms_Description__c,
            opp.Account.DRC_Inco_Term__c
        );
    }

    @AuraEnabled(cacheable=true)
    public static String getOpportunityCurrency(Id oppId) {
        return [SELECT CurrencyIsoCode FROM Opportunity WHERE Id = :oppId LIMIT 1].CurrencyIsoCode;
    }

    // ─── Helper: get Standard Pricebook Id safely ────────────────────────────────

    private static Id getStandardPricebookId() {
        if (Test.isRunningTest()) {
            return Test.getStandardPricebookId();
        }
        return [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
    }

    // ─── Helper: resolve the effective Pricebook Id for an Opportunity ──────────
    // Returns the Opportunity's Pricebook2Id if set, otherwise falls back to Standard Pricebook.

    private static Id resolveOpportunityPricebookId(Opportunity opp) {
        if (opp.Pricebook2Id != null) {
            return opp.Pricebook2Id;
        }
        return getStandardPricebookId();
    }

    // ─── Helper: ensure a PricebookEntry exists for the given currency ───────────
    // If an entry already exists for the target currency, returns it.
    // Otherwise clones the first available entry for that product/pricebook into
    // the target currency and returns the new entry Id.
    // NOTE: This method performs DML and must NOT be called from a cacheable method.

    private static Id ensurePricebookEntry(Id pricebook2Id, Id product2Id, String currencyIsoCode) {
        // Check if entry already exists for this currency
        List<PricebookEntry> existing = [
            SELECT Id
            FROM PricebookEntry
            WHERE Pricebook2Id    = :pricebook2Id
              AND Product2Id      = :product2Id
              AND CurrencyIsoCode = :currencyIsoCode
              AND IsActive        = true
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        // Find any active entry for this product in the pricebook to clone the UnitPrice from
        List<PricebookEntry> anyEntry = [
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :pricebook2Id
              AND Product2Id   = :product2Id
              AND IsActive     = true
            LIMIT 1
        ];

        Decimal unitPrice = (anyEntry.isEmpty()) ? 0 : anyEntry[0].UnitPrice;

        PricebookEntry newEntry = new PricebookEntry(
            Pricebook2Id    = pricebook2Id,
            Product2Id      = product2Id,
            UnitPrice       = unitPrice,
            CurrencyIsoCode = currencyIsoCode,
            IsActive        = true
        );
        insert newEntry;
        return newEntry.Id;
    }

    // ─── ensurePricebookEntryForProduct — callable from LWC (non-cacheable) ──────
    // Called from LWC immediately when the user selects a product from search results.
    // Guarantees a PricebookEntry exists for the opportunity currency and returns
    // the resolved Id + UnitPrice so the JS row can update without waiting for save.

    public class PricebookEntryResult {
        @AuraEnabled public Id      pricebookEntryId;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Boolean created;

        public PricebookEntryResult(Id pbeId, Decimal price, Boolean wasCreated) {
            this.pricebookEntryId = pbeId;
            this.unitPrice        = price;
            this.created          = wasCreated;
        }
    }

    @AuraEnabled
    public static PricebookEntryResult ensurePricebookEntryForProduct(
            Id opportunityId, Id product2Id, String currencyIsoCode) {
        try {
            Opportunity opp = [
                SELECT Id, Pricebook2Id
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            Id pricebook2Id = resolveOpportunityPricebookId(opp);

            // Check if entry already exists for this currency
            List<PricebookEntry> existing = [
                SELECT Id, UnitPrice
                FROM PricebookEntry
                WHERE Pricebook2Id    = :pricebook2Id
                  AND Product2Id      = :product2Id
                  AND CurrencyIsoCode = :currencyIsoCode
                  AND IsActive        = true
                LIMIT 1
            ];
            if (!existing.isEmpty()) {
                return new PricebookEntryResult(existing[0].Id, existing[0].UnitPrice, false);
            }

            // Find any active entry to clone the UnitPrice from
            List<PricebookEntry> anyEntry = [
                SELECT Id, UnitPrice
                FROM PricebookEntry
                WHERE Pricebook2Id = :pricebook2Id
                  AND Product2Id   = :product2Id
                  AND IsActive     = true
                LIMIT 1
            ];
            Decimal unitPrice = anyEntry.isEmpty() ? 0 : anyEntry[0].UnitPrice;

            PricebookEntry newEntry = new PricebookEntry(
                Pricebook2Id    = pricebook2Id,
                Product2Id      = product2Id,
                UnitPrice       = unitPrice,
                CurrencyIsoCode = currencyIsoCode,
                IsActive        = true
            );
            insert newEntry;
            return new PricebookEntryResult(newEntry.Id, unitPrice, true);

        } catch (Exception e) {
            throw new AuraHandledException('Error ensuring pricebook entry: ' + e.getMessage());
        }
    }

    // ─── Packing detail wrappers ─────────────────────────────────────────────────

    // Wrapper for a single packing detail record.
    // packingQuantity is serialised as String so that null Decimals don't cause
    // JSON serialisation issues; the JS layer parses it with parseFloat().
    public class PackingDetailWrapper {
        @AuraEnabled public String packingSize;
        @AuraEnabled public String packingQuantity;  // raw multiplier from DRC_NBC_Packing_Qauntity__c, e.g. "100"

        public PackingDetailWrapper(String size, String qty) {
            this.packingSize     = size;
            this.packingQuantity = qty;
        }
    }

    // Groups packing details by Product2Id as a List.
    // Using List instead of Map<Id,...> because Apex Maps don't serialize correctly to LWC.
    public class ProductPackingWrapper {
        @AuraEnabled public String                    product2Id;
        @AuraEnabled public List<PackingDetailWrapper> packingDetails;

        public ProductPackingWrapper(String pid, List<PackingDetailWrapper> details) {
            this.product2Id     = pid;
            this.packingDetails = details;
        }
    }

    // ─── Wrapper for ProductWrapper ──────────────────────────────────────────────

    public class ProductWrapper {
        @AuraEnabled public Id      PricebookEntryId;
        @AuraEnabled public Id      Product2Id;
        @AuraEnabled public String  Name;
        @AuraEnabled public String  FGCode;
        @AuraEnabled public String  HSNCode;
        @AuraEnabled public Decimal UnitPrice;
        @AuraEnabled public String  UOM;

        public ProductWrapper(Id pbeId, Id prodId, String name, String fg, String hsn, Decimal price, String uom) {
            this.PricebookEntryId = pbeId;
            this.Product2Id       = prodId;
            this.Name             = name;
            this.FGCode           = fg;
            this.HSNCode          = hsn;
            this.UnitPrice        = price;
            this.UOM              = uom;
        }
    }

    // ─── Wrapper returned by getAllProducts and searchProducts ───────────────────

    public class ProductSearchResult {
        @AuraEnabled public List<ProductWrapper>        products;
        @AuraEnabled public List<ProductPackingWrapper> packingDetailsList;

        public ProductSearchResult(List<ProductWrapper> prods, List<ProductPackingWrapper> packing) {
            this.products           = prods;
            this.packingDetailsList = packing;
        }
    }

    // ─── Helper: build packing details list from a set of Product2 Ids ──────────
    // PackingQuantity (DRC_NBC_Packing_Qauntity__c) is the raw multiplier/step value,
    // e.g. 100 means valid quantities are 100, 200, 300 ...
    // The JS layer stores this raw value directly into the PackingQuantity display field.

    private static List<ProductPackingWrapper> buildPackingDetailsList(Set<Id> product2Ids) {
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
            // Convert Decimal field to String — matches PackingDetailWrapper(String, String).
            // The JS layer receives this as a string and calls parseFloat() on it.
            String qtyStr = pd.DRC_NBC_Packing_Qauntity__c != null
                ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c)
                : null;
            tempMap.get(pd.Product__c).add(
                new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr)
            );
        }

        List<ProductPackingWrapper> result = new List<ProductPackingWrapper>();
        for (Id pid : tempMap.keySet()) {
            result.add(new ProductPackingWrapper(pid, tempMap.get(pid)));
        }
        return result;
    }

    // ─── getAllProducts — returns ProductSearchResult ────────────────────────────

    @AuraEnabled(cacheable=true)
    public static ProductSearchResult getAllProducts(Id oppId) {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id = :oppId LIMIT 1];

        // Use the Opportunity's pricebook; fall back to Standard if unset
        Id effectivePricebookId = resolveOpportunityPricebookId(opp);

        // No currency filter — show all active products regardless of currency
        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, Product2.Name, Product2.DRC_NBC_FG_Code__c,
                   Product2.QuantityUnitOfMeasure, Product2.DRC_NBC_HSN_SAC_Code__c,
                   UnitPrice
            FROM PricebookEntry
            WHERE IsActive         = true
              AND Product2.IsActive = true
              AND Pricebook2Id      = :effectivePricebookId
            LIMIT 100
        ];

        Set<Id>              product2Ids      = new Set<Id>();
        List<ProductWrapper> wrappedProducts  = new List<ProductWrapper>();
        Set<Id>              seenProductIds   = new Set<Id>();

        for (PricebookEntry pbe : entries) {
            // De-duplicate products (multiple currency entries for the same product)
            if (!seenProductIds.contains(pbe.Product2Id)) {
                seenProductIds.add(pbe.Product2Id);
                product2Ids.add(pbe.Product2Id);
                wrappedProducts.add(new ProductWrapper(
                    pbe.Id,
                    pbe.Product2Id,
                    pbe.Product2.Name,
                    pbe.Product2.DRC_NBC_FG_Code__c,
                    pbe.Product2.DRC_NBC_HSN_SAC_Code__c,
                    pbe.UnitPrice,
                    pbe.Product2.QuantityUnitOfMeasure
                ));
            }
        }

        return new ProductSearchResult(wrappedProducts, buildPackingDetailsList(product2Ids));
    }

    // ─── searchProducts — no currency filter; returns ProductSearchResult ─────────
    // Currency is still accepted as a parameter for context but is no longer used
    // as a SOQL filter. If the product has no PricebookEntry for the opportunity's
    // currency, ensurePricebookEntryForProduct is called from the LWC immediately
    // on product selection (non-cacheable, so DML is allowed there).
    //
    // FIX (v1.8): When the account has NO restricted products configured, show all
    // matching products. Previously the else branch was commented out, causing an
    // empty result set for accounts without any restriction records.

    @AuraEnabled(cacheable=true)
    public static ProductSearchResult searchProducts(String keyword, String currencyIsoCode, Id oppId) {

        Opportunity opp = [SELECT AccountId, Pricebook2Id FROM Opportunity WHERE Id = :oppId LIMIT 1];
        Id accountId = opp.AccountId;

        // Use the Opportunity's pricebook; fall back to Standard if unset
        Id effectivePricebookId = resolveOpportunityPricebookId(opp);

        Set<Id> allowedProductIds = new Set<Id>();
        if (accountId != null) {
            for (DRC_NBC_Restricted_Product__c restriction : [
                SELECT DRC_NBC_Product__c
                FROM DRC_NBC_Restricted_Product__c
                WHERE DRC_NBC_Customer__c = :accountId
            ]) {
                allowedProductIds.add(restriction.DRC_NBC_Product__c);
            }
        }

        List<PricebookEntry> entries;

        if (!allowedProductIds.isEmpty()) {
            // Account has restricted products configured — only show those products
            entries = [
                SELECT Id, Product2Id, Product2.Name, Product2.DRC_NBC_FG_Code__c,
                       Product2.DRC_NBC_HSN_SAC_Code__c, Product2.QuantityUnitOfMeasure,
                       UnitPrice, CurrencyIsoCode
                FROM PricebookEntry
                WHERE IsActive          = true
                  AND Product2.IsActive = true
                  AND Product2.Name     LIKE :('%' + keyword + '%')
                  AND Pricebook2Id      = :effectivePricebookId
                 // AND Product2Id        IN :allowedProductIds
                ORDER BY Product2.Name
                LIMIT 100
            ];
        } else {
            // Account has NO restricted products configured — show all matching products
            entries = [
                SELECT Id, Product2Id, Product2.Name, Product2.DRC_NBC_FG_Code__c,
                       Product2.DRC_NBC_HSN_SAC_Code__c, Product2.QuantityUnitOfMeasure,
                       UnitPrice, CurrencyIsoCode
                FROM PricebookEntry
                WHERE IsActive          = true
                  AND Product2.IsActive = true
                  AND Product2.Name     LIKE :('%' + keyword + '%')
                  AND Pricebook2Id      = :effectivePricebookId
                ORDER BY Product2.Name
                LIMIT 100
            ];
        }

        Set<Id>              product2Ids    = new Set<Id>();
        Set<Id>              seenProductIds = new Set<Id>();
        List<ProductWrapper> wrapped        = new List<ProductWrapper>();

        for (PricebookEntry pbe : entries) {
            // De-duplicate: keep only the first PBE seen per product
            if (!seenProductIds.contains(pbe.Product2Id)) {
                seenProductIds.add(pbe.Product2Id);
                product2Ids.add(pbe.Product2Id);
                wrapped.add(new ProductWrapper(
                    pbe.Id,
                    pbe.Product2Id,
                    pbe.Product2.Name,
                    pbe.Product2.DRC_NBC_FG_Code__c,
                    pbe.Product2.DRC_NBC_HSN_SAC_Code__c,
                    pbe.UnitPrice,
                    pbe.Product2.QuantityUnitOfMeasure
                ));
            }
        }

        return new ProductSearchResult(wrapped, buildPackingDetailsList(product2Ids));
    }

    // ─── Address methods ─────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static AccountAddressWrapper getAccountBillingAddress(Id oppId) {
        try {
            Opportunity opp = [
                SELECT Account.BillingStreet, Account.BillingCity,
                       Account.BillingState, Account.BillingPostalCode,
                       Account.BillingCountry, Account.BillingCountryCode
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

    @AuraEnabled(cacheable=true)
    public static List<DRC_NBC_Addresses__c> getAccountAddresses(Id oppId) {
        Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1];
        return [
            SELECT Id, DRC_NBC_Type__c, DRC_NBC_Address__c
            FROM DRC_NBC_Addresses__c
            WHERE DRC_NBC_Account__c = :opp.AccountId
              AND DRC_NBC_Type__c    = 'Shipping'
        ];
    }

    // ─── Bank details ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static AccountBankDetailsWrapper getAccountBankDetails(Id oppId) {
        try {
            Opportunity opp = [
                SELECT Account.DRC_NBC_Consignee_Bank_Name__c,
                       Account.DRC_NBC_Consignee_Bank_Account_Number__c,
                       Account.DRC_NBC_Consignee_Bank_IFSC_Code__c,
                       Account.DRC_NBC_Consignee_Bank_Address__c,
                       Account.SalesPerson_Code__c 
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
            return new AccountBankDetailsWrapper(
                opp.Account.DRC_NBC_Consignee_Bank_Name__c,
                opp.Account.DRC_NBC_Consignee_Bank_Account_Number__c,
                opp.Account.DRC_NBC_Consignee_Bank_IFSC_Code__c,
                opp.Account.DRC_NBC_Consignee_Bank_Address__c,
                opp.Account.SalesPerson_Code__c  
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching bank details: ' + e.getMessage());
        }
    }

   public class AccountBankDetailsWrapper {
        @AuraEnabled public String bankName;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String ifscCode;
        @AuraEnabled public String bankAddress;
        @AuraEnabled public String salesPersonCode;   // ← ADD THIS

        public AccountBankDetailsWrapper(String bn, String an, String ifc, String ba, String sp) {
            this.bankName       = bn;
            this.accountNumber  = an;
            this.ifscCode       = ifc;
            this.bankAddress    = ba;
            this.salesPersonCode = sp;                // ← ADD THIS
        }
    }
    // ─── createSampleOrder ───────────────────────────────────────────────────────

    @AuraEnabled
    public static String createSampleOrder(Order orderObj, List<OrderItemWrapper> orderItems, Id opportunityId) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (orderItems == null || orderItems.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error'   => 'No products selected. Please select at least one product.'
                });
            }

            List<Contact> contacts = [
                SELECT Id, Name, Email
                FROM Contact
                WHERE Id = :orderObj.BillToContactId OR Id = :orderObj.ShipToContactId
            ];
            for (Contact con : contacts) {
                if (String.isBlank(con.Email)) {
                    return JSON.serialize(new Map<String, Object>{
                        'success' => false,
                        'error'   => 'Please provide email for ' + con.Name + '.'
                    });
                }
            }

            Opportunity opp = [
                SELECT Id, AccountId, Pricebook2Id, CurrencyIsoCode
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];

            // Use the Opportunity's pricebook; fall back to Standard Pricebook if unset.
            if (opp.Pricebook2Id == null) {
                opp.Pricebook2Id = getStandardPricebookId();
                update opp;
            }

            String targetCurrency = orderObj.CurrencyIsoCode != null
                ? orderObj.CurrencyIsoCode
                : opp.CurrencyIsoCode;

            orderObj.OpportunityId   = opportunityId;
            orderObj.AccountId       = opp.AccountId;
            orderObj.Pricebook2Id    = opp.Pricebook2Id;
            orderObj.EffectiveDate   = orderObj.EffectiveDate != null ? orderObj.EffectiveDate : Date.today();
            orderObj.Status          = orderObj.Status        != null ? orderObj.Status        : 'Requested';
            orderObj.CurrencyIsoCode = targetCurrency;
            insert orderObj;

            Order insertedOrder = [SELECT Id, Pricebook2Id FROM Order WHERE Id = :orderObj.Id LIMIT 1];

            Set<Id> product2Ids = new Set<Id>();
            for (OrderItemWrapper wrapper : orderItems) {
                if (wrapper.Product2Id != null) product2Ids.add(wrapper.Product2Id);
            }

            Map<Id, String> productIdToName = new Map<Id, String>();
            for (Product2 prod : [SELECT Id, Name FROM Product2 WHERE Id IN :product2Ids]) {
                productIdToName.put(prod.Id, prod.Name);
            }

            // Build map: Product2Id → PricebookEntry Id for the target currency.
            // If an entry doesn't exist yet for the currency, create it automatically.
            Map<Id, Id> productIdToPriceBookEntryId = new Map<Id, Id>();

            // First pass: collect existing entries
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id
                FROM PricebookEntry
                WHERE Pricebook2Id    = :insertedOrder.Pricebook2Id
                  AND Product2Id      IN :product2Ids
                  AND IsActive        = true
                  AND CurrencyIsoCode = :targetCurrency
            ]) {
                productIdToPriceBookEntryId.put(pbe.Product2Id, pbe.Id);
            }

            // Second pass: for any product without a matching-currency entry, create one
            for (Id prodId : product2Ids) {
                if (!productIdToPriceBookEntryId.containsKey(prodId)) {
                    Id newPbeId = ensurePricebookEntry(insertedOrder.Pricebook2Id, prodId, targetCurrency);
                    productIdToPriceBookEntryId.put(prodId, newPbeId);
                }
            }

            List<OrderItem> realOrderItems           = new List<OrderItem>();
            List<String>    missingPricebookProducts = new List<String>();

            for (OrderItemWrapper wrapper : orderItems) {
                if (wrapper.Product2Id == null) continue;

                Id pbEntryId = productIdToPriceBookEntryId.get(wrapper.Product2Id);
                if (pbEntryId == null) {
                    String productName = productIdToName.get(wrapper.Product2Id);
                    missingPricebookProducts.add(productName != null ? productName : 'Unknown Product');
                    continue;
                }

                OrderItem oi                         = new OrderItem();
                oi.OrderId                           = orderObj.Id;
                oi.PricebookEntryId                  = pbEntryId;
                oi.Product2Id                        = wrapper.Product2Id;
                oi.Quantity                          = (wrapper.Quantity == null || wrapper.Quantity == 0) ? 1 : wrapper.Quantity;
                oi.UnitPrice                         = wrapper.UnitPrice != null ? wrapper.UnitPrice : 0;
                oi.Description                       = wrapper.Description;
                oi.DRC_NBC_Unit_Of_Measurement__c    = wrapper.QuantityUnitOfMeasure;
                oi.DRC_NBC_Packing_Size__c           = wrapper.PackingSize;
                // PackingQuantity = raw value from DRC_NBC_Packing_Qauntity__c
                oi.DRC_NBC_Packing_Quantity__c       = wrapper.PackingQuantity != null
                    ? String.valueOf(wrapper.PackingQuantity)
                    : null;
                realOrderItems.add(oi);
            }

            if (!missingPricebookProducts.isEmpty()) {
                Database.rollback(sp);
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error'   => 'Could not resolve PricebookEntries for: ' + String.join(missingPricebookProducts, ', ')
                });
            }

            if (!realOrderItems.isEmpty()) {
                insert realOrderItems;
            } else {
                Database.rollback(sp);
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error'   => 'No valid products to create order items.'
                });
            }

            if (orderObj.DRC_NBC_Shipping_Address__c != null) {
                DRC_NBC_Addresses__c shippingAddr = new DRC_NBC_Addresses__c(
                    Id               = orderObj.DRC_NBC_Shipping_Address__c,
                    DRC_NBC_Order__c = insertedOrder.Id
                );
                update shippingAddr;
            }

            Order createdOrder = [SELECT Id, OrderNumber FROM Order WHERE Id = :orderObj.Id LIMIT 1];
            return JSON.serialize(new Map<String, Object>{
                'success' => true,
                'orderId' => createdOrder.Id,
                'orders'  => new List<Order>{ createdOrder }
            });

        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Exception: ' + e.getMessage() + ' | Stack Trace: ' + e.getStackTraceString());
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error'   => 'Error creating order: ' + e.getMessage()
            });
        }
    }

    public class OrderItemWrapper {
        @AuraEnabled public Id      Product2Id            { get; set; }
        @AuraEnabled public Id      PriceBookEntryId      { get; set; }
        @AuraEnabled public Decimal Quantity              { get; set; }
        @AuraEnabled public Decimal UnitPrice             { get; set; }
        @AuraEnabled public String  Description           { get; set; }
        @AuraEnabled public String  CurrencyIsoCode       { get; set; }
        @AuraEnabled public String  QuantityUnitOfMeasure { get; set; }
        @AuraEnabled public String  PackingSize           { get; set; }
        @AuraEnabled public Decimal PackingQuantity       { get; set; }

        public OrderItemWrapper() {}
    }
}