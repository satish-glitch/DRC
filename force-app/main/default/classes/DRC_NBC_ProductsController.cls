/**
* @File Name : DRC_NBC_ProductsController.cls
* @Description : Updated to support Packing Size and Packing Quantity
* @Author : Satish yadav
* @Last Modified By : Satish Yadav
* @Last Modified On : June 9, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 6, 2025    |   | Initial Version
* 1.1 | October 13, 2025   |   | Added DRC_NBC_update_Sales_price__c support
* 1.2 | November 11, 2025  |   | Updated to fetch billing from Account
* 1.3 | February 12, 2026  |   | Added Packing Size and Packing Quantity support
* 1.4 | February 26, 2026  |   | Packing Size/Qty now fetched from DRC_NBC_Packing_Details__c child object
* 1.5 | June 9, 2026       |   | Re-enabled currency filter on PricebookEntry query; added currency guard in saveQLIData
* 1.6 | June 9, 2026       |   | Fix: AddressWrapper now carries structured billing fields to avoid fragile split() in LWC;
*                               |     saveQLIData now maps BillingState/BillingCountry (not StateCode/CountryCode)
* 1.7 | June 9, 2026       |   | Added ensurePricebookEntriesForCurrency — auto-creates PBEs in Quote currency
*                               |     (copying UnitPrice from INR entry) before products are returned in getExistingQLIs;
*                               |     re-enabled CurrencyISOCode filter on PricebookEntry query.
**/

public class DRC_NBC_ProductsController {
    
    @AuraEnabled(cacheable=true)
    public static List<Contact> getAccountContacts(Id quoteId) {
        if (String.isBlank(quoteId)) {
            throw new AuraHandledException('Quote ID is required.');
        }
        
        Quote q = [
            SELECT Id, Opportunity.AccountId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        if (q.Opportunity == null || q.Opportunity.AccountId == null) {
            return new List<Contact>();
        }
        
        return [
            SELECT Id, Name, Email, Phone, Fax
            FROM Contact
            WHERE AccountId = :q.Opportunity.AccountId
            ORDER BY Name
        ];
    }
    
    @AuraEnabled(cacheable=true)
    public static Quote getQuoteRecord(Id quoteId) {
        if (String.isBlank(quoteId)) {
            throw new AuraHandledException('Quote ID is required.');
        }
        
        try {
            Quote q = [
                SELECT Id,
                Name,
                Status,
                ExpirationDate,
                DRC_NBC_Lead_Time__c,
                Description,
                CurrencyIsoCode,
                DRC_NBC_Type__c,
                DRC_NBC_Payemnt_Term__c,
                DRC_NBC_Payment_Term_Description__c,
                DRC_NBC_Inco_terms__c,
                DRC_NBC_Special_Requirements__c,
                OpportunityId,
                Opportunity.AccountId,
                AccountId,
                ContactId,
                BillingStreet,
                BillingCity,
                BillingPostalCode,
                BillingCountry,
                ShippingStreet,
                ShippingCity,
                ShippingPostalCode,
                ShippingCountry,
                Email,
                Phone,
                DRC_NBC_Other_Tax_Amount__c,
                DRC_NBC_TCS_Amount__c,
                DRC_NBC_Billing_Address_Id__c,
                DRC_NBC_Shipping_Address_Id__c,
                Fax
                FROM Quote
                WHERE Id = :quoteId
                LIMIT 1
            ];
            
            return q;
        } catch (Exception e) {
            System.debug('Error fetching quote: ' + e.getMessage());
            throw new AuraHandledException('Error fetching Quote record: ' + e.getMessage());
        }
    }
    
    // ─── AddressWrapper now carries individual structured fields ─────────────
    // This avoids the fragile split(', ') in LWC that breaks when street/city
    // values themselves contain commas (e.g. "SAINT PETERSBURG LISIY NOS").
    public class AddressWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
        
        public AddressWrapper(Id value, String label) {
            this.value = value;
            this.label = label;
        }
    }
    
    public class AddressListWrapper {
        @AuraEnabled public List<AddressWrapper> billingAddresses;
        @AuraEnabled public List<AddressWrapper> shippingAddresses;
        
        public AddressListWrapper() {
            billingAddresses  = new List<AddressWrapper>();
            shippingAddresses = new List<AddressWrapper>();
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static AddressListWrapper getAccountAddresses(Id accountId) {
        AddressListWrapper result = new AddressListWrapper();
        
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
            
            result.shippingAddresses.add(new AddressWrapper(addr.Id, fullAddress));
        }
        
        List<Account> accounts = [
            SELECT Id,
            BillingStreet,
            BillingCity,
            BillingState,
            BillingPostalCode,
            BillingCountry
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        
        if (!accounts.isEmpty()) {
            Account acc = accounts[0];
            
            String billingAddress = String.join(new List<String>{
                acc.BillingStreet,
                    acc.BillingCity,
                    acc.BillingState,
                    acc.BillingPostalCode,
                    acc.BillingCountry
                    }, ', ');
            
            // ── Build wrapper with structured fields ──────────────────────────
            // Each field is populated directly from Account so LWC never needs
            // to split the label string (which breaks on multi-word city names).
            AddressWrapper aw = new AddressWrapper(acc.Id, billingAddress);
            aw.street     = acc.BillingStreet;
            aw.city       = acc.BillingCity;
            aw.state      = acc.BillingState;
            aw.postalCode = acc.BillingPostalCode;
            aw.country    = acc.BillingCountry;
            
            result.billingAddresses.add(aw);
        }
        
        return result;
    }
    
    @AuraEnabled
    public static void updateQuoteRecord(Id quoteId, Map<String, Object> updatedFields) {
        if (String.isBlank(quoteId)) {
            throw new AuraHandledException('Quote ID is missing.');
        }
        if (updatedFields == null || updatedFields.isEmpty()) {
            throw new AuraHandledException('No fields provided to update.');
        }
        
        try {
            Quote qToUpdate = new Quote(Id = quoteId);
            
            for (String fieldName : updatedFields.keySet()) {
                Object fieldValue = updatedFields.get(fieldName);
                
                if      (fieldName == 'Name')                                   qToUpdate.Name = (String)fieldValue;
                else if (fieldName == 'ExpirationDate')                         qToUpdate.ExpirationDate = (Date)fieldValue;
                else if (fieldName == 'DRC_NBC_Lead_Time__c') {
                    if (fieldValue != null) {
                        qToUpdate.DRC_NBC_Lead_Time__c = Date.valueOf((String)fieldValue);
                    }
                }
                else if (fieldName == 'Description')                            qToUpdate.Description = (String)fieldValue;
                else if (fieldName == 'Status')                                 qToUpdate.Status = (String)fieldValue;
                else if (fieldName == 'CurrencyIsoCode')                        qToUpdate.CurrencyIsoCode = (String)fieldValue;
                else if (fieldName == 'DRC_NBC_Type__c')                        qToUpdate.DRC_NBC_Type__c = (String)fieldValue;
                else if (fieldName == 'DRC_NBC_Payemnt_Term__c')                qToUpdate.DRC_NBC_Payemnt_Term__c = (String)fieldValue;
                else if (fieldName == 'DRC_NBC_Payment_Term_Description__c')    qToUpdate.DRC_NBC_Payment_Term_Description__c = (String)fieldValue;
                else if (fieldName == 'DRC_NBC_Inco_terms__c')                  qToUpdate.DRC_NBC_Inco_terms__c = (String)fieldValue;
                else if (fieldName == 'DRC_NBC_Special_Requirements__c')        qToUpdate.DRC_NBC_Special_Requirements__c = (String)fieldValue;
                else if (fieldName == 'ContactId')                              qToUpdate.ContactId = (Id)fieldValue;
                else if (fieldName == 'BillingStreet')                          qToUpdate.BillingStreet = (String)fieldValue;
                else if (fieldName == 'BillingCity')                            qToUpdate.BillingCity = (String)fieldValue;
                else if (fieldName == 'BillingState')                           qToUpdate.BillingState = (String)fieldValue;
                else if (fieldName == 'BillingPostalCode')                      qToUpdate.BillingPostalCode = (String)fieldValue;
                else if (fieldName == 'BillingCountry')                         qToUpdate.BillingCountry = (String)fieldValue;
                else if (fieldName == 'ShippingStreet')                         qToUpdate.ShippingStreet = (String)fieldValue;
                else if (fieldName == 'ShippingCity')                           qToUpdate.ShippingCity = (String)fieldValue;
                else if (fieldName == 'ShippingPostalCode')                     qToUpdate.ShippingPostalCode = (String)fieldValue;
                else if (fieldName == 'ShippingCountry')                        qToUpdate.ShippingCountry = (String)fieldValue;
                else if (fieldName == 'Email')                                  qToUpdate.Email = (String)fieldValue;
                else if (fieldName == 'Phone')                                  qToUpdate.Phone = (String)fieldValue;
                else if (fieldName == 'Fax')                                    qToUpdate.Fax = (String)fieldValue;
            }
            
            update qToUpdate;
            
        } catch (DmlException dmlEx) {
            System.debug('DML Error while updating quote: ' + dmlEx.getMessage());
            throw new AuraHandledException('Failed to update Quote: ' + dmlEx.getMessage());
        } catch (Exception ex) {
            System.debug('General Error while updating quote: ' + ex.getMessage());
            throw new AuraHandledException('Unexpected error while updating Quote: ' + ex.getMessage());
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
    
    @AuraEnabled
    public static qliWrapper getExistingQLIs(String quoteId) {
        List<DRC_NBC_Restricted_Product__c> productAccessibilitiesList = getrestrictedProductsAccessList(quoteId);
        Set<Id> accessibleRestrictedProductIds = new Set<Id>();
        
        Quote quoteRecord = [
            SELECT Id, Opportunity.AccountId, CurrencyIsoCode, Pricebook2Id
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        if (quoteRecord.Pricebook2Id == null) {
            Id standardPricebookId;
            if (Test.isRunningTest()) {
                standardPricebookId = Test.getStandardPricebookId();
            } else {
                standardPricebookId = [
                    SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1
                ].Id;
            }
            quoteRecord.Pricebook2Id = standardPricebookId;
            update quoteRecord;
        }
        
        // Query QLIs
        List<QuoteLineItem> qlis = [
            SELECT
            Id,
            Product2.Name,
            Product2.Family,
            Product2.QuantityUnitOfMeasure,
            Product2.DRC_NBC_FG_Code__c,
            Product2.DRC_NBC_HSN_SAC_Code__c,
            Quote.CurrencyIsoCode,
            PricebookEntryId,
            Description,
            Discount,
            ListPrice,
            Product2Id,
            Quantity,
            UnitPrice,
            DRC_NBC_Packing_Size__c,
            DRC_NBC_Packing_Qauntity__c,
            DRC_NBC_Hazardous__c,
            DRC_NBC_MARKS_NOS__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
        ];
        
        qliWrapper qliRecs = new qliWrapper();
        qliRecs.qlis         = qlis;
        qliRecs.productsList = new List<PricebookEntry>();
        
        // Build allowed product Ids from restriction records (filtered by account)
        for (DRC_NBC_Restricted_Product__c access : productAccessibilitiesList) {
            if (access.DRC_NBC_Customer__c == quoteRecord?.Opportunity?.AccountId) {
                accessibleRestrictedProductIds.add(access.DRC_NBC_Product__c);
            }
        }
        
        // ── Auto-create PricebookEntries in the Quote's currency if missing ──
        // For any accessible product that only has an INR PricebookEntry,
        // this creates the missing entry (copying INR UnitPrice) so the
        // currency filter below and the saveQLIData guard never fire a mismatch.
        if (!accessibleRestrictedProductIds.isEmpty()
            && String.isNotBlank(quoteRecord.CurrencyIsoCode)
            && quoteRecord.CurrencyIsoCode != 'INR') {
                ensurePricebookEntriesForCurrency(
                    accessibleRestrictedProductIds,
                    quoteRecord.CurrencyIsoCode,
                    quoteRecord.Pricebook2Id
                );
            }
        
        // Fetch ALL active pricebook entries matching the Quote's currency
        List<PricebookEntry> allEntries = [
            SELECT
            Id,
            Product2Id,
            Product2.Name,
            Product2.Family,
            Product2.DRC_NBC_FG_Code__c,
            Product2.DRC_NBC_HSN_SAC_Code__c,
            Product2.QuantityUnitOfMeasure,
            Product2.DRC_NBC_Hazardous__c,
            Product2.DRC_NBC_MARKS_NOS__c,
            CurrencyIsoCode,
            Pricebook2Id,
            Product2.Description,
            Product2.IsActive,
            UnitPrice
            FROM PricebookEntry
            WHERE IsActive = true
            AND CurrencyISOCode = :quoteRecord.CurrencyIsoCode
            AND Product2.IsActive = true
            AND Pricebook2Id = :quoteRecord.Pricebook2Id
            ORDER BY Product2.Name
        ];
        
        // Always filter — only show products assigned to this account via restriction records.
        if (!accessibleRestrictedProductIds.isEmpty()) {
            for (PricebookEntry pbe : allEntries) {
                if (accessibleRestrictedProductIds.contains(pbe.Product2Id)) {
                    qliRecs.productsList.add(pbe);
                }
            }
        }
        
        // Collect all Product2 Ids from QLIs and product list for packing details
        Set<Id> product2Ids = new Set<Id>();
        for (QuoteLineItem qli : qlis) {
            if (qli.Product2Id != null) product2Ids.add(qli.Product2Id);
        }
        for (PricebookEntry pbe : qliRecs.productsList) {
            if (pbe.Product2Id != null) product2Ids.add(pbe.Product2Id);
        }
        
        // Fetch packing details from child object for all relevant products
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
                    ? String.valueOf(pd.DRC_NBC_Packing_Qauntity__c) : '';
                productPackingMap.get(pd.Product__c).add(
                    new PackingDetailWrapper(pd.DRC_NBC_Packing_Size__c, qtyStr)
                );
            }
        }
        
        qliRecs.packingDetailsMap = productPackingMap;
        return qliRecs;
    }
    
    @AuraEnabled
    public static List<DRC_NBC_Restricted_Product__c> getrestrictedProductsAccessList(String quoteId) {
        Quote quoteRecord = [
            SELECT Opportunity.AccountId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        Id accountId = quoteRecord.Opportunity.AccountId;
        
        return [
            SELECT
            DRC_NBC_Product__c,
            DRC_NBC_Customer__c
            FROM DRC_NBC_Restricted_Product__c
            WHERE DRC_NBC_Customer__c = :accountId
        ];
    }
    
    @AuraEnabled
    public static void saveQLIData(List<QuoteLineItem> qliList, List<String> qliIdsToDelete, Quote quoteData) {
        try {
            if (quoteData != null && quoteData.Id != null) {
                Quote qToUpdate = new Quote(
                    Id                                   = quoteData.Id,
                    Name                                 = quoteData.Name,
                    ExpirationDate                       = quoteData.ExpirationDate,
                    DRC_NBC_Lead_Time__c                 = quoteData.DRC_NBC_Lead_Time__c,
                    Description                          = quoteData.Description,
                    CurrencyIsoCode                      = quoteData.CurrencyIsoCode,
                    Status                               = quoteData.Status,
                    DRC_NBC_Type__c                      = quoteData.DRC_NBC_Type__c,
                    DRC_NBC_Payemnt_Term__c              = quoteData.DRC_NBC_Payemnt_Term__c,
                    DRC_NBC_Payment_Term_Description__c  = quoteData.DRC_NBC_Payment_Term_Description__c,
                    DRC_NBC_Inco_terms__c                = quoteData.DRC_NBC_Inco_terms__c,
                    DRC_NBC_Special_Requirements__c      = quoteData.DRC_NBC_Special_Requirements__c,
                    DRC_NBC_Other_Tax_Amount__c          = quoteData.DRC_NBC_Other_Tax_Amount__c,
                    DRC_NBC_TCS_Amount__c                = quoteData.DRC_NBC_TCS_Amount__c,
                    ContactId                            = quoteData.ContactId,
                    Email                                = quoteData.Email,
                    Phone                                = quoteData.Phone,
                    Fax                                  = quoteData.Fax,
                    BillingStreet                        = quoteData.BillingStreet,
                    BillingCity                          = quoteData.BillingCity,
                    // ── FIX: use BillingState / BillingCountry (plain text fields) ──
                    // Previously BillingStateCode / BillingCountryCode were used, which
                    // caused values like "SAINT PETERSBURG LISIY NOS" (a city) to be
                    // stuffed into the wrong field because the LWC was splitting a
                    // joined address string by ', ' — now each field arrives structured.
                    BillingState                         = quoteData.BillingState,
                    BillingPostalCode                    = quoteData.BillingPostalCode,
                    BillingCountry                       = quoteData.BillingCountry,
                    DRC_NBC_Shipping_Address_Id__c       = quoteData.DRC_NBC_Shipping_Address_Id__c
                );
                
                if (quoteData.DRC_NBC_Shipping_Address_Id__c != null) {
                    DRC_NBC_Addresses__c addr = [
                        SELECT DRC_NBC_Address__Street__s,
                        DRC_NBC_Address__City__s,
                        DRC_NBC_Address__StateCode__s,
                        DRC_NBC_Address__PostalCode__s,
                        DRC_NBC_Address__CountryCode__s
                        FROM DRC_NBC_Addresses__c
                        WHERE Id = :quoteData.DRC_NBC_Shipping_Address_Id__c
                        LIMIT 1
                    ];
                    qToUpdate.ShippingStreet      = addr.DRC_NBC_Address__Street__s;
                    qToUpdate.ShippingCity        = addr.DRC_NBC_Address__City__s;
                    qToUpdate.ShippingStateCode   = addr.DRC_NBC_Address__StateCode__s;
                    qToUpdate.ShippingPostalCode  = addr.DRC_NBC_Address__PostalCode__s;
                    qToUpdate.ShippingCountryCode = addr.DRC_NBC_Address__CountryCode__s;
                }
                
                update qToUpdate;
            }
            
            // Build QLIs to upsert
            List<QuoteLineItem> qlisToUpsert = new List<QuoteLineItem>();
            for (QuoteLineItem qli : qliList) {
                if (String.isBlank(qli.Product2Id)) {
                    throw new AuraHandledException('Missing Product2Id.');
                }
                if (qli.Quantity == null) {
                    throw new AuraHandledException('Missing Quantity.');
                }
                if (qli.UnitPrice == null) {
                    throw new AuraHandledException('Missing UnitPrice.');
                }
                
                Id resolvedQuoteId = (qli.QuoteId != null) ? qli.QuoteId : quoteData.Id;
                if (resolvedQuoteId == null) {
                    throw new AuraHandledException('QuoteId is missing for a line item. Cannot save.');
                }
                
                // Empty string Id → null so upsert treats it as INSERT
                Id resolvedId = String.isBlank(qli.Id) ? null : qli.Id;
                
                QuoteLineItem qliToSave = new QuoteLineItem(
                    Id                             = resolvedId,
                    Product2Id                     = qli.Product2Id,
                    Quantity                       = qli.Quantity,
                    UnitPrice                      = qli.UnitPrice,
                    Discount                       = qli.Discount,
                    QuoteId                        = resolvedQuoteId,
                    PricebookEntryId               = qli.PricebookEntryId,
                    Description                    = qli.Description,
                    DRC_NBC_Unit_Of_Measurement__c = qli.DRC_NBC_Unit_Of_Measurement__c,
                    DRC_NBC_Packing_Size__c        = qli.DRC_NBC_Packing_Size__c,
                    DRC_NBC_Packing_Qauntity__c    = qli.DRC_NBC_Packing_Qauntity__c,
                    DRC_NBC_Hazardous__c           = qli.DRC_NBC_Hazardous__c,
                    DRC_NBC_MARKS_NOS__c           = qli.DRC_NBC_MARKS_NOS__c
                );
                
                qlisToUpsert.add(qliToSave);
            }
            
            if (!qlisToUpsert.isEmpty()) {
                // ── Currency guard: validate every PricebookEntry matches the Quote currency ──
                String quoteCurrency = quoteData.CurrencyIsoCode;
                
                // If CurrencyIsoCode was not passed in quoteData, re-query it
                if (String.isBlank(quoteCurrency) && quoteData.Id != null) {
                    quoteCurrency = [SELECT CurrencyIsoCode FROM Quote WHERE Id = :quoteData.Id LIMIT 1].CurrencyIsoCode;
                }
                
                Set<Id> pbeIds = new Set<Id>();
                for (QuoteLineItem q : qlisToUpsert) {
                    if (q.PricebookEntryId != null) pbeIds.add(q.PricebookEntryId);
                }
                
                if (!pbeIds.isEmpty() && !String.isBlank(quoteCurrency)) {
                    Map<Id, String> pbeCurrencyMap = new Map<Id, String>();
                    for (PricebookEntry pbe : [
                        SELECT Id, CurrencyIsoCode
                        FROM PricebookEntry
                        WHERE Id IN :pbeIds
                    ]) {
                        pbeCurrencyMap.put(pbe.Id, pbe.CurrencyIsoCode);
                    }
                    
                    for (QuoteLineItem q : qlisToUpsert) {
                        if (q.PricebookEntryId != null
                            && pbeCurrencyMap.containsKey(q.PricebookEntryId)
                            && pbeCurrencyMap.get(q.PricebookEntryId) != quoteCurrency) {
                                throw new AuraHandledException(
                                    'Currency mismatch: the selected product\'s pricebook entry ('
                                    + pbeCurrencyMap.get(q.PricebookEntryId)
                                    + ') does not match the Quote currency ('
                                    + quoteCurrency
                                    + '). Please re-select the product or update the Quote currency.'
                                );
                            }
                    }
                }
                
                upsert qlisToUpsert;
            }
            
            if (qliIdsToDelete != null && !qliIdsToDelete.isEmpty()) {
                delete [SELECT Id FROM QuoteLineItem WHERE Id IN :qliIdsToDelete];
            }
            
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception ex) {
            if (!Test.isRunningTest()) {
                System.debug('saveQLIData ERROR: ' + ex.getMessage() + ' | Line: ' + ex.getLineNumber());
                throw new AuraHandledException('Error saving Quote and Line Items: ' + ex.getMessage());
            }
        }
    }
    
    // ─── ensurePricebookEntriesForCurrency ───────────────────────────────────
    // For every product in productIds that does NOT yet have an active
    // PricebookEntry in targetCurrency, creates one by copying the UnitPrice
    // from the existing INR entry. If an entry exists but is inactive, it is
    // re-activated. Mirrors DRC_NBC_GenerateQuotes_Controller v1.8+.
    
    @TestVisible
    private static void ensurePricebookEntriesForCurrency(
        Set<Id> productIds,
        String  targetCurrency,
        Id      pricebook2Id
    ) {
        if (productIds == null || productIds.isEmpty()
            || String.isBlank(targetCurrency) || pricebook2Id == null) return;
        
        Map<Id, PricebookEntry> targetPbeByProductId = new Map<Id, PricebookEntry>();
        List<PricebookEntry>    toActivate            = new List<PricebookEntry>();
        
        // Check which products already have a PBE in targetCurrency
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
        
        // Products still missing a targetCurrency PBE
        Set<Id> missingProductIds = new Set<Id>(productIds);
        missingProductIds.removeAll(targetPbeByProductId.keySet());
        if (missingProductIds.isEmpty()) return;
        
        // Fetch INR entries as the price source for missing products
        Map<Id, PricebookEntry> inrPbeByProductId = new Map<Id, PricebookEntry>();
        for (PricebookEntry pbe : [
            SELECT Id, Product2Id, UnitPrice
            FROM   PricebookEntry
            WHERE  Pricebook2Id    = :pricebook2Id
            AND    Product2Id      IN :missingProductIds
            AND    CurrencyIsoCode = 'INR'
            AND    IsActive        = true
        ]) {
            inrPbeByProductId.put(pbe.Product2Id, pbe);
        }
        
        // Create new PBEs for each missing product (only if an INR source exists)
        List<PricebookEntry> toInsert = new List<PricebookEntry>();
        for (Id productId : missingProductIds) {
            PricebookEntry inrPbe = inrPbeByProductId.get(productId);
            if (inrPbe == null) continue; // no INR source — skip; product will be absent from list
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
    
    public class qliWrapper {
        @AuraEnabled public List<QuoteLineItem> qlis;
        @AuraEnabled public List<PricebookEntry> productsList;
        @AuraEnabled public Map<Id, List<PackingDetailWrapper>> packingDetailsMap;
    }
}