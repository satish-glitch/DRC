/**
* @File Name : DRC_NBC_GenerateQuotes_Controller.cls
* @Description : Controller for generating quotes from opportunities
* @Author :
* @Last Modified By :
* @Last Modified On : February 10, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 10, 2025 |   | Initial Version
* 1.1 | November 10, 2025 |   | Fixed PricebookEntry fallback handling
* 1.2 | November 11, 2025 |   | Changed to fetch billing address from Account
* 1.3 | February 10, 2026 |   | Added Packing Size support
**/

public with sharing class DRC_NBC_GenerateQuotes_Controller {

    @AuraEnabled(cacheable=true)
    public static QuoteWrapper getQuoteMdtDetails(Id oppId) {
        QuoteWrapper quoteWrapperObj = new QuoteWrapper();

        // Fetch Opportunity with Account information
        Opportunity opp = [SELECT CurrencyISOCode, AccountId, Account.DRC_NBC_Special_Instructions__c 
                            FROM Opportunity 
                            WHERE Id = :oppId 
                            LIMIT 1];

        quoteWrapperObj.oppCurrency = opp.CurrencyISOCode;
        quoteWrapperObj.accountId = opp.AccountId;
        quoteWrapperObj.accountSpecialInstruction = opp.Account.DRC_NBC_Special_Instructions__c;

        return quoteWrapperObj;
    }

    public class QuoteWrapper{
        @AuraEnabled public String oppCurrency;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountSpecialInstruction; 
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getOpportunityContacts(Id oppId) {
        System.debug('Opportunity ID received: ' + oppId);
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

    // NEW METHOD: Get Account Billing Address
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

    // MODIFIED: Now only returns Shipping addresses
    @AuraEnabled(cacheable=true)
    public static List<DRC_NBC_Addresses__c> getAccountAddresses(Id oppId) {
        try {
            Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1];
            return [
                SELECT Id, DRC_NBC_Type__c, DRC_NBC_Address__c
                FROM DRC_NBC_Addresses__c
                WHERE DRC_NBC_Account__c = :opp.AccountId
                AND DRC_NBC_Type__c = 'Shipping'
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching addresses: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> searchProducts(String keyword, String currencyIsoCode, Id accountId) {
        try {
            if (String.isBlank(currencyIsoCode)) {
                throw new AuraHandledException('Currency code is required to search products.');
            }

            // Step 1: Get the DRC Pricebook
            Pricebook2 drcPriceBook = [
                SELECT Id
                FROM Pricebook2
                WHERE Name = 'DRC PriceBook' 
                AND IsActive = true 
                AND DRC_NBC_External_Id__c = 'DRC001'
                LIMIT 1
            ];

            // Step 2: If accountId is provided, get restricted Product2 Ids
            Set<Id> allowedProductIds = new Set<Id>();
            if (accountId != null) {
                for (DRC_NBC_Restricted_Product__c rp : [
                    SELECT DRC_NBC_Product__c, DRC_NBC_Customer__c
                    FROM DRC_NBC_Restricted_Product__c
                    WHERE DRC_NBC_Customer__c = :accountId
                ]) {
                    allowedProductIds.add(rp.DRC_NBC_Product__c);
                }
            }

            List<PricebookEntry> entries;
            if (!allowedProductIds.isEmpty()) {
                // Restrict to allowed product IDs
                entries = [
                    SELECT Id, Product2Id, Product2.Name, Product2.DRC_NBC_FG_Code__c,
                    Product2.DRC_NBC_HSN_SAC_Code__c, Product2.QuantityUnitOfMeasure,
                    Product2.DRC_NBC_Packing_Size__c,
                    UnitPrice, CurrencyIsoCode
                    FROM PricebookEntry
                    WHERE IsActive = true
                    AND Product2.IsActive = true
                    AND Product2.Name LIKE :('%' + keyword + '%')
                    AND CurrencyIsoCode = :currencyIsoCode
                    AND Pricebook2Id = :drcPriceBook.Id
                    AND Product2Id IN :allowedProductIds
                    ORDER BY Product2.Name
                    LIMIT 100
                ];
            } else {
                // No restriction, show all matching products
                entries = [
                    SELECT Id, Product2Id, Product2.Name, Product2.DRC_NBC_FG_Code__c,
                    Product2.DRC_NBC_HSN_SAC_Code__c, Product2.QuantityUnitOfMeasure,
                    Product2.DRC_NBC_Packing_Size__c,
                    UnitPrice, CurrencyIsoCode
                    FROM PricebookEntry
                    WHERE IsActive = true
                    AND Product2.IsActive = true
                    AND Product2.Name LIKE :('%' + keyword + '%')
                    AND CurrencyIsoCode = :currencyIsoCode
                    AND Pricebook2Id = :drcPriceBook.Id
                    ORDER BY Product2.Name
                    LIMIT 100
                ];
            }

            // Step 4: De-duplicate products by Product2Id
            Set<Id> seen = new Set<Id>();
            List<ProductWrapper> results = new List<ProductWrapper>();

            for (PricebookEntry pbe : entries) {
                if (!seen.contains(pbe.Product2Id)) {
                    seen.add(pbe.Product2Id);
                    results.add(new ProductWrapper(
                        pbe.Id,
                        pbe.Product2Id,
                        pbe.Product2.Name,
                        pbe.UnitPrice,
                        pbe.Product2.DRC_NBC_FG_Code__c,
                        pbe.Product2.DRC_NBC_HSN_SAC_Code__c,
                        pbe.Product2.QuantityUnitOfMeasure,
                        pbe.Product2.DRC_NBC_Packing_Size__c
                    ));
                }
            }

            return results;

        } catch (Exception e) {
            throw new AuraHandledException('Error searching products: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String createQuoteWithLines(Id oppId, Quote quoteData, List<LineItemWrapper> lineItems) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (lineItems == null || lineItems.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error' => 'No products selected. Please select at least one product.'
                });
            }

            if (String.isNotBlank(quoteData.ContactId)) {
                Contact con = [SELECT Id, Name, Email FROM Contact WHERE Id = :quoteData.ContactId LIMIT 1];
                if (String.isBlank(con.Email)) {
                    return JSON.serialize(new Map<String, Object>{
                        'success' => false,
                        'error' => 'Please provide email for ' + con.Name + '.'
                    });
                }
            }

            Opportunity opp = [
                SELECT Id, AccountId, Pricebook2Id, CurrencyIsoCode
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];

            Pricebook2 drcPriceBook = [
                SELECT Id
                FROM Pricebook2
                WHERE Name = 'DRC PriceBook' 
                AND IsActive = true 
                AND DRC_NBC_External_Id__c = 'DRC001'
                LIMIT 1
            ];

            if (opp.Pricebook2Id == null || opp.Pricebook2Id != drcPriceBook.Id) {
                opp.Pricebook2Id = drcPriceBook.Id;
                update opp;
            }

            quoteData.OpportunityId = oppId;
            quoteData.Pricebook2Id = drcPriceBook.Id;
            quoteData.Status = String.isNotBlank(quoteData.Status) ? quoteData.Status : 'Draft';
            quoteData.CurrencyIsoCode = opp.CurrencyIsoCode;
            insert quoteData;
            System.debug('Quote created: ' + quoteData.Id + ' for Opportunity ' + oppId);
             // Populate shipping address fields from the selected custom address record
            if (quoteData.DRC_NBC_Shipping_Address_Id__c != null) {
                DRC_NBC_Addresses__c addrRecord = [
                    SELECT 
                        DRC_NBC_Address__City__s, DRC_NBC_Address__c,  DRC_NBC_Address__CountryCode__s, DRC_NBC_Address__PostalCode__s,
                        DRC_NBC_Address__StateCode__s, DRC_NBC_Address__Street__s
                    FROM 
                        DRC_NBC_Addresses__c
                    WHERE 
                        Id = :quoteData.DRC_NBC_Shipping_Address_Id__c
                    LIMIT 1
                ];

                if (addrRecord.DRC_NBC_Address__c != null) {
                    quoteData.ShippingStreet = addrRecord.DRC_NBC_Address__Street__s;
                    quoteData.ShippingCity = addrRecord.DRC_NBC_Address__City__s;
                    quoteData.ShippingPostalCode = addrRecord.DRC_NBC_Address__PostalCode__s;
                    quoteData.ShippingStateCode = addrRecord.DRC_NBC_Address__StateCode__s;
                    quoteData.ShippingCountryCode = addrRecord.DRC_NBC_Address__CountryCode__s;
                }
            }
            if (String.isBlank(quoteData.BillingStreet)) {
                Opportunity oppWithAccount = [
                    SELECT Account.BillingStreet, Account.BillingCity, Account.BillingState,
                        Account.BillingPostalCode, Account.BillingCountry, Account.BillingCountryCode
                    FROM Opportunity
                    WHERE Id = :oppId
                    LIMIT 1
                ];

                if (oppWithAccount.Account != null) {
                    quoteData.BillingStreet = oppWithAccount.Account.BillingStreet;
                    quoteData.BillingCity = oppWithAccount.Account.BillingCity;
                    quoteData.BillingState = oppWithAccount.Account.BillingState;
                    quoteData.BillingPostalCode = oppWithAccount.Account.BillingPostalCode;
                    quoteData.BillingCountry = oppWithAccount.Account.BillingCountry;
                    quoteData.BillingCountryCode = oppWithAccount.Account.BillingCountryCode;
                }
            }
            Update quoteData;

            Set<Id> product2Ids = new Set<Id>();
            for (LineItemWrapper wrapper : lineItems) {
                if (wrapper.Product2Id != null) product2Ids.add(wrapper.Product2Id);
            }
            System.debug('Collected Product2 Ids: ' + product2Ids);

            Map<Id, String> productIdToName = new Map<Id, String>();
            for (Product2 prod : [SELECT Id, Name FROM Product2 WHERE Id IN :product2Ids]) {
                productIdToName.put(prod.Id, prod.Name);
            }

            for (Id prodId : productIdToName.keySet()) {
                System.debug('Product ID: ' + prodId + ' → Name: ' + productIdToName.get(prodId));
            }

            Map<Id, Id> productIdToPriceBookEntryId = new Map<Id, Id>();
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id, CurrencyIsoCode
                FROM PricebookEntry
                WHERE Pricebook2Id = :quoteData.Pricebook2Id
                AND Product2Id IN :product2Ids
                AND IsActive = true
                AND CurrencyIsoCode = :quoteData.CurrencyIsoCode
            ]) {
                productIdToPriceBookEntryId.put(pbe.Product2Id, pbe.Id);
                System.debug('Mapped Product2Id: ' + pbe.Product2Id + ' to PBE: ' + pbe.Id);
            }

            List<QuoteLineItem> realQuoteLineItems = new List<QuoteLineItem>();
            List<String> missingPricebookProducts = new List<String>();

            for (LineItemWrapper wrapper : lineItems) {
                if (wrapper.Product2Id == null) continue;

                Id pbEntryId = productIdToPriceBookEntryId.get(wrapper.Product2Id);

                if (pbEntryId == null && wrapper.PricebookEntryId != null) {
                    pbEntryId = wrapper.PricebookEntryId;
                    System.debug('Using fallback PBE from LWC for Product: ' + wrapper.Product2Id);
                }

                if (pbEntryId == null) {
                    String productName = productIdToName.get(wrapper.Product2Id);
                    missingPricebookProducts.add(productName != null ? productName : 'Unknown Product');
                    continue;
                }

                QuoteLineItem qli = new QuoteLineItem();
                qli.QuoteId = quoteData.Id;
                qli.PricebookEntryId = pbEntryId;
                qli.Product2Id = wrapper.Product2Id;
                qli.Quantity = (wrapper.Quantity == null || wrapper.Quantity == 0) ? 1 : wrapper.Quantity;
                qli.UnitPrice = wrapper.UnitPrice != null ? wrapper.UnitPrice : 0;
                qli.Description = wrapper.Description;
                
                // Add packing information (both text fields)
                if (String.isNotBlank(wrapper.PackingSize)) {
                    qli.DRC_NBC_Packing_Size__c = wrapper.PackingSize;
                }
                if (String.isNotBlank(wrapper.PackingQuantity)) {
                    qli.DRC_NBC_Packing_Qauntity__c = wrapper.PackingQuantity;
                }
                
                realQuoteLineItems.add(qli);
            }

            if (!missingPricebookProducts.isEmpty()) {
                Database.rollback(sp);
                String missingProducts = String.join(missingPricebookProducts, ', ');
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error' => 'Missing PricebookEntries for: ' + missingProducts
                });
            }

            if (!realQuoteLineItems.isEmpty()) {
                insert realQuoteLineItems;
            } else {
                Database.rollback(sp);
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error' => 'No valid products to create quote line items.'
                });
            }

            return JSON.serialize(new Map<String, Object>{
                'success' => true,
                'quoteId' => quoteData.Id
            });

        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Error creating Quote: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => 'Error creating quote: ' + e.getMessage()
            });
        }
    }

    // Wrapper class for Account Billing Address
    public class AccountAddressWrapper {
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
        @AuraEnabled public String countryCode;

        public AccountAddressWrapper(String st, String ct, String sta, String pc, String cntry, String cc) {
            this.street = st;
            this.city = ct;
            this.state = sta;
            this.postalCode = pc;
            this.country = cntry;
            this.countryCode = cc;
        }
    }

    public class ProductWrapper {
        @AuraEnabled public Id PricebookEntryId;
        @AuraEnabled public Id Product2Id;
        @AuraEnabled public String Name;
        @AuraEnabled public Decimal UnitPrice;
        @AuraEnabled public String FGCode;
        @AuraEnabled public String HSNCode;
        @AuraEnabled public String QuantityUnitOfMeasure;
        @AuraEnabled public String PackingSizes; // Multiselect picklist values

        public ProductWrapper(Id pbeId, Id p2Id, String nm, Decimal price, String fg, String hsn, String uom, String packingSizes) {
            this.PricebookEntryId = pbeId;
            this.Product2Id = p2Id;
            this.Name = nm;
            this.UnitPrice = price;
            this.FGCode = fg;
            this.HSNCode = hsn;
            this.QuantityUnitOfMeasure = uom;
            this.PackingSizes = packingSizes;
        }
    }

    public class LineItemWrapper {
        @AuraEnabled 
        public Id Product2Id { get; set; }
        @AuraEnabled 
        public Id PricebookEntryId { get; set; }
        @AuraEnabled 
        public Integer Quantity { get; set; }
        @AuraEnabled 
        public Decimal UnitPrice { get; set; }
        @AuraEnabled 
        public String Description { get; set; }
        @AuraEnabled 
        public String CurrencyIsoCode { get; set; }
        @AuraEnabled 
        public String QuantityUnitOfMeasure { get; set; }
        @AuraEnabled
        public String PackingSize { get; set; }
        @AuraEnabled
        public String PackingQuantity { get; set; }

        public LineItemWrapper() {}
    }
}