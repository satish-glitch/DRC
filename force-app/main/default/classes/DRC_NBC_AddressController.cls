/**
* @File Name : DRC_NBC_AddressController.cls
* @Description : Controller for fetching Account Addresses from Quote
* @Author :
* @Last Modified On : November 21, 2025
**/

public with sharing class DRC_NBC_AddressController {
    
    @AuraEnabled
    public static void updateQuoteAddress(Id quoteId, Id shippingAddressId) {
        if (quoteId == null) return;

        Quote q = [
            SELECT Id, AccountId
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];
        
        // Billing address is now fetched from Account and set automatically
        Account acc = [
            SELECT BillingStreet, BillingCity, BillingPostalCode,
                   BillingCountryCode, BillingStateCode, BillingCountry, BillingState
            FROM Account
            WHERE Id = :q.AccountId
            LIMIT 1
        ];
        
        // Set billing address from Account (not editable by user)
        q.BillingStreet = acc.BillingStreet;
        q.BillingCity = acc.BillingCity;
        q.BillingPostalCode = acc.BillingPostalCode;
        q.BillingCountryCode = acc.BillingCountryCode;
        q.BillingStateCode = acc.BillingStateCode;
        q.BillingCountry = acc.BillingCountry;
        q.BillingState = acc.BillingState;
        q.DRC_NBC_Billing_Address_Id__c = null; // Clear custom billing address ID
        
        // Update shipping address if provided
        if (shippingAddressId != null) {
            DRC_NBC_Addresses__c shipping = [
                SELECT DRC_NBC_Address__Street__s,
                       DRC_NBC_Address__City__s,
                       DRC_NBC_Address__PostalCode__s,
                       DRC_NBC_Address__CountryCode__s,
                       DRC_NBC_Address__StateCode__s
                FROM DRC_NBC_Addresses__c
                WHERE Id = :shippingAddressId
                LIMIT 1
            ];

            q.ShippingStreet = shipping.DRC_NBC_Address__Street__s;
            q.ShippingCity = shipping.DRC_NBC_Address__City__s;
            q.ShippingPostalCode = shipping.DRC_NBC_Address__PostalCode__s;
            q.ShippingCountryCode = shipping.DRC_NBC_Address__CountryCode__s;
            q.ShippingStateCode = shipping.DRC_NBC_Address__StateCode__s;
            q.DRC_NBC_Shipping_Address_Id__c = shippingAddressId;
        }
        
        update q;
    }

    // Wrapper to pass addresses + selected values + account billing address back to LWC
    public class QuoteAddressWrapper {
        @AuraEnabled public List<DRC_NBC_Addresses__c> addresses;
        @AuraEnabled public Id selectedShippingId;
        @AuraEnabled public Account accountBillingAddress;
    }

    @AuraEnabled(cacheable=true)
    public static QuoteAddressWrapper getAccountAddressesFromQuote(Id quoteId) {
        Quote quote = [
            SELECT Id, AccountId,
                   DRC_NBC_Shipping_Address_Id__c
            FROM Quote
            WHERE Id = :quoteId
            LIMIT 1
        ];

        // Fetch Account billing address
        Account acc = [
            SELECT BillingStreet, BillingCity, BillingPostalCode,
                   BillingCountryCode, BillingStateCode, BillingCountry, BillingState
            FROM Account
            WHERE Id = :quote.AccountId
            LIMIT 1
        ];

        // Fetch only shipping addresses from custom object
        List<DRC_NBC_Addresses__c> addresses = [
            SELECT Id,
                   DRC_NBC_Type__c,
                   DRC_NBC_Address__Street__s,
                   DRC_NBC_Address__City__s,
                   DRC_NBC_Address__PostalCode__s,
                   DRC_NBC_Address__CountryCode__s,
                   DRC_NBC_Address__StateCode__s
            FROM DRC_NBC_Addresses__c
            WHERE DRC_NBC_Account__c = :quote.AccountId
            AND DRC_NBC_Type__c = 'Shipping'
        ];

        QuoteAddressWrapper wrapper = new QuoteAddressWrapper();
        wrapper.addresses = addresses;
        wrapper.selectedShippingId = quote.DRC_NBC_Shipping_Address_Id__c;
        wrapper.accountBillingAddress = acc;

        return wrapper;
    }
}