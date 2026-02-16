/**
* @File Name : DRC_NBC_ProductsController.cls
* @Description : Updated to support Packing Size and Packing Quantity
* @Author : Satish yadav
* @Last Modified By : Satish Yadav
* @Last Modified On : February 12, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | October 6, 2025 |   | Initial Version
* 1.1 | October 13, 2025 |   | Added DRC_NBC_update_Sales_price__c support
* 1.2 | November 11, 2025 |   | Updated to fetch billing from Account
* 1.3 | February 12, 2026 |   | Added Packing Size and Packing Quantity support
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

    public class AddressWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public AddressWrapper(Id value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    public class AddressListWrapper {
        @AuraEnabled public List<AddressWrapper> billingAddresses;
        @AuraEnabled public List<AddressWrapper> shippingAddresses;

        public AddressListWrapper() {
            billingAddresses = new List<AddressWrapper>();
            shippingAddresses = new List<AddressWrapper>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static AddressListWrapper getAccountAddresses(Id accountId) {
        AddressListWrapper result = new AddressListWrapper();

        // Query addresses from DRC_NBC_Addresses__c for Shipping addresses
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

        // Query Account for Billing Address
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

            // Use Account Id as the value for billing address
            result.billingAddresses.add(new AddressWrapper(acc.Id, billingAddress));
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

                if (fieldName == 'Name') qToUpdate.Name = (String)fieldValue;
                else if (fieldName == 'ExpirationDate') qToUpdate.ExpirationDate = (Date)fieldValue;
                else if (fieldName == 'DRC_NBC_Lead_Time__c') {
                    if (fieldValue != null) {
                        qToUpdate.DRC_NBC_Lead_Time__c = Date.valueOf((String)fieldValue);
                    }
                }
                else if (fieldName == 'Description') qToUpdate.Description = (String)fieldValue;
                else if (fieldName == 'Status') qToUpdate.Status = (String)fieldValue;
                else if (fieldName == 'CurrencyIsoCode') qToUpdate.CurrencyIsoCode = (String)fieldValue;
                else if (fieldName == 'DRC_NBC_Type__c') qToUpdate.DRC_NBC_Type__c = (String)fieldValue;
                else if (fieldName == 'DRC_NBC_Payemnt_Term__c') qToUpdate.DRC_NBC_Payemnt_Term__c = (String)fieldValue;
                else if (fieldName == 'DRC_NBC_Inco_terms__c') qToUpdate.DRC_NBC_Inco_terms__c = (String)fieldValue;
                else if (fieldName == 'DRC_NBC_Special_Requirements__c') qToUpdate.DRC_NBC_Special_Requirements__c = (String)fieldValue;
                else if (fieldName == 'ContactId') qToUpdate.ContactId = (Id)fieldValue;
                else if (fieldName == 'BillingStreet') qToUpdate.BillingStreet = (String)fieldValue;
                else if (fieldName == 'BillingCity') qToUpdate.BillingCity = (String)fieldValue;
                else if (fieldName == 'BillingPostalCode') qToUpdate.BillingPostalCode = (String)fieldValue;
                else if (fieldName == 'BillingCountry') qToUpdate.BillingCountry = (String)fieldValue;
                else if (fieldName == 'ShippingStreet') qToUpdate.ShippingStreet = (String)fieldValue;
                else if (fieldName == 'ShippingCity') qToUpdate.ShippingCity = (String)fieldValue;
                else if (fieldName == 'ShippingPostalCode') qToUpdate.ShippingPostalCode = (String)fieldValue;
                else if (fieldName == 'ShippingCountry') qToUpdate.ShippingCountry = (String)fieldValue;
                else if (fieldName == 'Email') qToUpdate.Email = (String)fieldValue;
                else if (fieldName == 'Phone') qToUpdate.Phone = (String)fieldValue;
                else if (fieldName == 'Fax') qToUpdate.Fax = (String)fieldValue;
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
            Pricebook2 defaultPricebook = [
                SELECT Id 
                FROM Pricebook2 
                WHERE IsActive = true 
                ORDER BY IsStandard DESC, CreatedDate ASC 
                LIMIT 1
            ];
            quoteRecord.Pricebook2Id = defaultPricebook.Id;
            update quoteRecord;
        }
        
        // NEW: Query QLIs with packing information
        List<QuoteLineItem> qlis = [
            SELECT
                Id,
                Product2.Name,
                Product2.Family,
                Product2.QuantityUnitOfMeasure,
                Product2.DRC_NBC_FG_Code__c,
                Product2.DRC_NBC_HSN_SAC_Code__c,
                Product2.DRC_NBC_Packing_Size__c,
                Quote.CurrencyIsoCode,
                PricebookEntryId,
                Description, 
                Discount,
                ListPrice,
                Product2Id,
                Quantity,
                UnitPrice,
                DRC_NBC_Packing_Size__c,
                DRC_NBC_Packing_Qauntity__c
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
        ];

        qliWrapper qliRecs = new qliWrapper();
        qliRecs.qlis = qlis;
        qliRecs.productsList = new List<PricebookEntry>();
        
        // NEW: Query products with packing size information
        qliRecs.productsList = [
            SELECT
                Id,
                Product2Id,
                Product2.Name,
                Product2.Family,
                Product2.DRC_NBC_FG_Code__c,
                Product2.DRC_NBC_HSN_SAC_Code__c,
                Product2.QuantityUnitOfMeasure,
                Product2.DRC_NBC_Packing_Size__c,
                CurrencyIsoCode,
                Pricebook2Id,
                Product2.Description,
                Product2.IsActive,
                UnitPrice
            FROM PricebookEntry
            WHERE
                IsActive = true
                AND CurrencyISOCode = :quoteRecord.CurrencyIsoCode
                AND Product2.IsActive = true
                AND Pricebook2Id = :quoteRecord.Pricebook2Id
            ORDER BY Product2.Name
        ];
        
        if (!productAccessibilitiesList.isEmpty()) {
            for (DRC_NBC_Restricted_Product__c access : productAccessibilitiesList) {
                if (access.DRC_NBC_Customer__c == quoteRecord?.Opportunity?.AccountId) {
                    accessibleRestrictedProductIds.add(access.DRC_NBC_Product__c);
                }
            }

            if (!accessibleRestrictedProductIds.isEmpty()) {
                qliRecs.productsList.addAll([
                    SELECT
                        Id,
                        Product2Id,
                        Product2.Name,
                        Product2.Family,
                        Product2.DRC_NBC_FG_Code__c,
                        Product2.DRC_NBC_HSN_SAC_Code__c,
                        Product2.QuantityUnitOfMeasure,
                        Product2.DRC_NBC_Packing_Size__c,
                        CurrencyIsoCode,
                        Pricebook2Id,
                        Product2.Description,
                        Product2.IsActive,
                        UnitPrice
                    FROM PricebookEntry
                    WHERE
                        IsActive = true
                        AND CurrencyISOCode = :quoteRecord.CurrencyIsoCode
                        AND Product2.IsActive = true
                        AND Pricebook2Id = :quoteRecord.Pricebook2Id
                    ORDER BY Name
                ]);
            }
        }
        
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
        Id currentUserId = UserInfo.getUserId();

        return [
            SELECT
                DRC_NBC_Product__c,
                DRC_NBC_Customer__c
            FROM DRC_NBC_Restricted_Product__c
            WHERE
                DRC_NBC_Customer__c = :accountId
                AND DRC_NBC_User__c = :currentUserId
        ];
    }

    @AuraEnabled
    public static void saveQLIData(List<QuoteLineItem> qliList, List<String> qliIdsToDelete, Quote quoteData) {
        try {
            if (quoteData != null && quoteData.Id != null) {
                Quote qToUpdate = new Quote(
                    Id = quoteData.Id,
                    Name = quoteData.Name,
                    ExpirationDate = quoteData.ExpirationDate,
                    DRC_NBC_Lead_Time__c = quoteData.DRC_NBC_Lead_Time__c,
                    Description = quoteData.Description,
                    CurrencyIsoCode = quoteData.CurrencyIsoCode,
                    Status = quoteData.Status,
                    DRC_NBC_Type__c = quoteData.DRC_NBC_Type__c,
                    DRC_NBC_Payemnt_Term__c = quoteData.DRC_NBC_Payemnt_Term__c,
                    DRC_NBC_Inco_terms__c = quoteData.DRC_NBC_Inco_terms__c,
                    DRC_NBC_Special_Requirements__c = quoteData.DRC_NBC_Special_Requirements__c,
                    DRC_NBC_Other_Tax_Amount__c = quoteData.DRC_NBC_Other_Tax_Amount__c,
                    DRC_NBC_TCS_Amount__c = quoteData.DRC_NBC_TCS_Amount__c,
                    ContactId = quoteData.ContactId,
                    Email = quoteData.Email,
                    Phone = quoteData.Phone,
                    Fax = quoteData.Fax,
                    BillingStreet = quoteData.BillingStreet,
                    BillingCity = quoteData.BillingCity,
                    BillingStateCode = quoteData.BillingStateCode,
                    BillingPostalCode = quoteData.BillingPostalCode,
                    BillingCountryCode = quoteData.BillingCountryCode,
                    DRC_NBC_Shipping_Address_Id__c = quoteData.DRC_NBC_Shipping_Address_Id__c
                );
                // Fetch and assign shipping address values from selected DRC_NBC_Addresses__c
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

                    qToUpdate.ShippingStreet     = addr.DRC_NBC_Address__Street__s;
                    qToUpdate.ShippingCity       = addr.DRC_NBC_Address__City__s;
                    qToUpdate.ShippingStateCode      = addr.DRC_NBC_Address__StateCode__s;
                    qToUpdate.ShippingPostalCode = addr.DRC_NBC_Address__PostalCode__s;
                    qToUpdate.ShippingCountryCode    = addr.DRC_NBC_Address__CountryCode__s;
                }

                update qToUpdate;
            }

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
                
                // NEW: Ensure packing fields are populated correctly
                QuoteLineItem qliToSave = new QuoteLineItem(
                    Id = qli.Id,
                    Product2Id = qli.Product2Id,
                    Quantity = qli.Quantity,
                    UnitPrice = qli.UnitPrice,
                    Discount = qli.Discount,
                    QuoteId = qli.QuoteId,
                    PricebookEntryId = qli.PricebookEntryId,
                    Description = qli.Description,
                    DRC_NBC_Unit_Of_Measurement__c = qli.DRC_NBC_Unit_Of_Measurement__c,
                    DRC_NBC_Packing_Size__c = qli.DRC_NBC_Packing_Size__c,
                    DRC_NBC_Packing_Qauntity__c = qli.DRC_NBC_Packing_Qauntity__c
                );
                
                qlisToUpsert.add(qliToSave);
            }

            if (!qlisToUpsert.isEmpty()) {
                upsert qlisToUpsert;
            }

            if (!qliIdsToDelete.isEmpty()) {
                delete [SELECT Id FROM QuoteLineItem WHERE Id IN :qliIdsToDelete];
            }

        } catch (Exception ex) {
            throw new AuraHandledException('Error saving Quote and Line Items: ' + ex.getMessage());
        }
    }

    public class qliWrapper {
        @AuraEnabled public List<QuoteLineItem> qlis;
        @AuraEnabled public List<PricebookEntry> productsList;
    }
}