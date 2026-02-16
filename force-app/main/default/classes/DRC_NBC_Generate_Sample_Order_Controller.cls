/**
* @File Name : DRC_NBC_Generate_Sample_Order_Controller.cls
* @Description : Controller for generating sample orders from opportunities
* @Author :
* @Last Modified By :
* @Last Modified On : February 12, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 13, 2025 |   | Initial Version
* 1.1 | October 14, 2025 |   | Fixed Unit Price handling
* 1.2 | November 11, 2025 |   | Changed to fetch billing address from Account
* 1.3 | February 12, 2026 |   | Added Packing Size support
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

    @AuraEnabled(cacheable=true)
    public static String getAccountPaymentTerms(Id oppId) {
        Opportunity opp = [
            SELECT Account.DRC_NBC_Payment_Term_Code__c 
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        return opp.Account.DRC_NBC_Payment_Term_Code__c;
    }

    @AuraEnabled(cacheable=true)
    public static String getOpportunityCurrency(Id oppId) {
        return [SELECT CurrencyIsoCode FROM Opportunity WHERE Id = :oppId LIMIT 1].CurrencyIsoCode;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> getAllProducts(Id oppId) {
        Opportunity opp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id = :oppId LIMIT 1];
        List<PricebookEntry> entries = [
            SELECT Id, Product2Id, Product2.Name, Product2.DRC_NBC_FG_Code__c, Product2.QuantityUnitOfMeasure,
                Product2.DRC_NBC_HSN_SAC_Code__c, Product2.DRC_NBC_Packing_Size__c, UnitPrice
            FROM PricebookEntry
            WHERE IsActive = true
            AND Product2.IsActive = true
            AND Pricebook2Id = :opp.Pricebook2Id
            LIMIT 100
        ];
        List<ProductWrapper> wrappedProducts = new List<ProductWrapper>();
        for (PricebookEntry pbe : entries) {
            wrappedProducts.add(new ProductWrapper(
                pbe.Id,
                pbe.Product2Id,
                pbe.Product2.Name,
                pbe.Product2.DRC_NBC_FG_Code__c,
                pbe.Product2.DRC_NBC_HSN_SAC_Code__c,
                pbe.UnitPrice,
                pbe.Product2.QuantityUnitOfMeasure,
                pbe.Product2.DRC_NBC_Packing_Size__c
            ));
        }
        return wrappedProducts;
    }

    public class ProductWrapper {
        @AuraEnabled public Id PricebookEntryId;
        @AuraEnabled public Id Product2Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String FGCode;
        @AuraEnabled public String HSNCode;
        @AuraEnabled public Decimal UnitPrice;
        @AuraEnabled public String UOM;
        @AuraEnabled public String PackingSize;

        public ProductWrapper(Id pbeId, Id prodId, String name, String fg, String hsn, Decimal price, String UOM, String packingSize) {
            this.PricebookEntryId = pbeId;
            this.Product2Id = prodId;
            this.Name = name;
            this.FGCode = fg;
            this.HSNCode = hsn;
            this.UnitPrice = price;
            this.UOM = UOM;
            this.PackingSize = packingSize;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductWrapper> searchProducts(String keyword, String currencyIsoCode, Id oppId) {
        if (String.isBlank(currencyIsoCode)) {
            throw new AuraHandledException('Currency code is required to search products.');
        }

        // Step 1: Fetch Opportunity and related AccountId
        Opportunity opp = [
            SELECT AccountId
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        Id accountId = opp.AccountId;

        // Step 2: Fetch allowed products for this Account (from custom restriction object)
        Set<Id> allowedProductIds = new Set<Id>();
        if (accountId != null) {
            for (DRC_NBC_Restricted_Product__c restriction : [
                SELECT DRC_NBC_Product__c, DRC_NBC_Customer__c
                FROM DRC_NBC_Restricted_Product__c
                WHERE DRC_NBC_Customer__c = :accountId
            ]) {
                allowedProductIds.add(restriction.DRC_NBC_Product__c);
            }
        }
        // Step 3: Get DRC Pricebook
        Pricebook2 drcPriceBook = [
            SELECT Id
            FROM Pricebook2
            WHERE Name = 'DRC PriceBook'
            AND IsActive = true
            AND DRC_NBC_External_Id__c = 'DRC001'
            LIMIT 1
        ];
        
        List<PricebookEntry> entries;
        
        if (!allowedProductIds.isEmpty()) {
            // Restrict to allowed product IDs
            entries = [
                SELECT Id, Product2Id, Product2.Name, Product2.DRC_NBC_FG_Code__c,
                Product2.DRC_NBC_HSN_SAC_Code__c, Product2.QuantityUnitOfMeasure,
                Product2.DRC_NBC_Packing_Size__c, UnitPrice, CurrencyIsoCode
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
                Product2.DRC_NBC_Packing_Size__c, UnitPrice, CurrencyIsoCode
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
        // Step 5: Wrap results and avoid duplicates
        Set<Id> seenProductIds = new Set<Id>();
        List<ProductWrapper> wrapped = new List<ProductWrapper>();

        for (PricebookEntry pbe : entries) {
            if (!seenProductIds.contains(pbe.Product2Id)) {
                seenProductIds.add(pbe.Product2Id);
                wrapped.add(new ProductWrapper(
                    pbe.Id,
                    pbe.Product2Id,
                    pbe.Product2.Name,
                    pbe.Product2.DRC_NBC_FG_Code__c,
                    pbe.Product2.DRC_NBC_HSN_SAC_Code__c,
                    pbe.UnitPrice,
                    pbe.Product2.QuantityUnitOfMeasure,
                    pbe.Product2.DRC_NBC_Packing_Size__c
                ));
            }
        }

        return wrapped;
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

    // Keep shipping address method for custom addresses
    @AuraEnabled(cacheable=true)
    public static List<DRC_NBC_Addresses__c> getAccountAddresses(Id oppId) {
        Opportunity opp = [SELECT AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1];
        return [
            SELECT Id, DRC_NBC_Type__c, DRC_NBC_Address__c
            FROM DRC_NBC_Addresses__c
            WHERE DRC_NBC_Account__c = :opp.AccountId
            AND DRC_NBC_Type__c = 'Shipping'
        ];
    }

    @AuraEnabled
    public static String createSampleOrder(Order orderObj, List<OrderItemWrapper> orderItems, Id opportunityId) {
        Savepoint sp = Database.setSavepoint();
        try {
            if (orderItems == null || orderItems.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error' => 'No products selected. Please select at least one product.'
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
                        'error' => 'Please provide email for ' + con.Name + '.'
                    });
                }
            }
            
            Opportunity opp = [
                SELECT Id, AccountId, Pricebook2Id, CurrencyIsoCode
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            
            Pricebook2 drcPriceBook = [
                SELECT Id
                FROM Pricebook2
                WHERE Name = 'DRC PriceBook' AND IsActive = true AND DRC_NBC_External_Id__c = 'DRC001'
                LIMIT 1
            ];    
            
            if (opp.Pricebook2Id == null || opp.Pricebook2Id != drcPriceBook.Id) {
                opp.Pricebook2Id = drcPriceBook.Id;
                update opp;
            }
            
            orderObj.OpportunityId = opportunityId;
            orderObj.AccountId = opp.AccountId;
            orderObj.Pricebook2Id = drcPriceBook.Id;
            orderObj.EffectiveDate = orderObj.EffectiveDate != null ? orderObj.EffectiveDate : Date.today();
            orderObj.Status = orderObj.Status != null ? orderObj.Status : 'Requested';
            orderObj.CurrencyIsoCode = orderObj.CurrencyIsoCode != null ? orderObj.CurrencyIsoCode : opp.CurrencyIsoCode;
            insert orderObj;

            Order insertedOrder = [
                SELECT Id, Pricebook2Id
                FROM Order
                WHERE Id = :orderObj.Id
                LIMIT 1
            ];
            
            Set<Id> product2Ids = new Set<Id>();
            for (OrderItemWrapper wrapper : orderItems) {
                if (wrapper.Product2Id != null) {
                    product2Ids.add(wrapper.Product2Id);
                }
            }
            
            Map<Id, String> productIdToName = new Map<Id, String>();
            for (Product2 prod : [
                SELECT Id, Name
                FROM Product2
                WHERE Id IN :product2Ids
            ]) {
                productIdToName.put(prod.Id, prod.Name);
            }
            
            Map<Id, Id> productIdToPriceBookEntryId = new Map<Id, Id>();
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id, CurrencyIsoCode
                FROM PricebookEntry
                WHERE Pricebook2Id = :insertedOrder.Pricebook2Id
                AND Product2Id IN :product2Ids
                AND IsActive = true
                AND CurrencyIsoCode = :orderObj.CurrencyIsoCode
            ]) {
                productIdToPriceBookEntryId.put(pbe.Product2Id, pbe.Id);
            }
            
            List<OrderItem> realOrderItems = new List<OrderItem>();
            List<String> missingPricebookProducts = new List<String>();

            for (OrderItemWrapper wrapper : orderItems) {
                if (wrapper.Product2Id == null) {
                    continue;
                }
                
                Id pbEntryId = productIdToPriceBookEntryId.get(wrapper.Product2Id);
                if (pbEntryId == null) {
                    String productName = productIdToName.get(wrapper.Product2Id);
                    missingPricebookProducts.add(productName != null ? productName : 'Unknown Product');
                    continue;
                }
                OrderItem oi = new OrderItem();
                oi.OrderId = orderObj.Id;
                oi.PricebookEntryId = pbEntryId;
                oi.Product2Id = wrapper.Product2Id;
                oi.Quantity = (wrapper.Quantity == null || wrapper.Quantity == 0) ? 1 : wrapper.Quantity;
                oi.UnitPrice = wrapper.UnitPrice != null ? wrapper.UnitPrice : 0;
                oi.Description = wrapper.Description;
                oi.DRC_NBC_Unit_Of_Measurement__c = wrapper.QuantityUnitOfMeasure;
                oi.DRC_NBC_Packing_Size__c = wrapper.PackingSize;
               oi.DRC_NBC_Packing_Quantity__c = String.valueOf(wrapper.PackingQuantity);
                realOrderItems.add(oi);
            }
            
            if (!missingPricebookProducts.isEmpty()) {
                Database.rollback(sp);
                String missingProducts = String.join(missingPricebookProducts, ', ');
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error' => 'Missing PricebookEntries for: ' + missingProducts
                });
            }
            
            if (!realOrderItems.isEmpty()) {
                insert realOrderItems;
            } else {
                Database.rollback(sp);
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error' => 'No valid products to create order items.'
                });
            }
            
            // Update shipping address reference only (billing comes from Account)
            if (orderObj.DRC_NBC_Shipping_Address__c != null) {
                DRC_NBC_Addresses__c shippingAddr = new DRC_NBC_Addresses__c(
                    Id = orderObj.DRC_NBC_Shipping_Address__c,
                    DRC_NBC_Order__c = insertedOrder.Id
                );
                update shippingAddr;
            }
            
            Order createdOrder = [
                SELECT Id, OrderNumber
                FROM Order
                WHERE Id = :orderObj.Id
                LIMIT 1
            ];
            return JSON.serialize(new Map<String, Object>{
                'success' => true,
                'orderId' => createdOrder.Id,
                'orders' => new List<Order>{ createdOrder }
            });
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Exception: ' + e.getMessage() + ' | Stack Trace: ' + e.getStackTraceString());
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => 'Error creating order: ' + e.getMessage()
            });
        }
    }

    public class OrderItemWrapper {
        @AuraEnabled 
        public Id Product2Id { get; set; }
        @AuraEnabled 
        public Id PriceBookEntryId { get; set; }
        @AuraEnabled 
        public Decimal Quantity { get; set; }
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
        public Decimal PackingQuantity { get; set; }
        
        public OrderItemWrapper() {
        }
    }

    // Add this new method to DRC_NBC_Generate_Sample_Order_Controller.cls
    @AuraEnabled(cacheable=true)
    public static AccountBankDetailsWrapper getAccountBankDetails(Id oppId) {
        try {
            Opportunity opp = [
                SELECT Account.DRC_NBC_Consignee_Bank_Name__c,
                    Account.DRC_NBC_Consignee_Bank_Account_Number__c,
                    Account.DRC_NBC_Consignee_Bank_IFSC_Code__c,
                    Account.DRC_NBC_Consignee_Bank_Address__c
                FROM Opportunity 
                WHERE Id = :oppId 
                LIMIT 1
            ];
            
            return new AccountBankDetailsWrapper(
                opp.Account.DRC_NBC_Consignee_Bank_Name__c,
                opp.Account.DRC_NBC_Consignee_Bank_Account_Number__c,
                opp.Account.DRC_NBC_Consignee_Bank_IFSC_Code__c,
                opp.Account.DRC_NBC_Consignee_Bank_Address__c
            );
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching bank details: ' + e.getMessage());
        }
    }

    // Add this wrapper class after AccountAddressWrapper
    public class AccountBankDetailsWrapper {
        @AuraEnabled public String bankName;
        @AuraEnabled public String accountNumber;
        @AuraEnabled public String ifscCode;
        @AuraEnabled public String bankAddress;

        public AccountBankDetailsWrapper(String bn, String an, String ifc, String ba) {
            this.bankName = bn;
            this.accountNumber = an;
            this.ifscCode = ifc;
            this.bankAddress = ba;
        }
    }
}