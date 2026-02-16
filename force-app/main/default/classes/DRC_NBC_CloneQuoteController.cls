/**
* @File Name : DRC_NBC_CloneQuoteController.cls
* @Description : Dedicated controller for cloning quotes with automatic QLI creation
* @Author : Satish Yadav
* @Last Modified On : January 20, 2026
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | January 14, 2026 |   | Initial Version - Clone Quote functionality
* 1.1 | January 14, 2026 |   | Updated to support AccountId in clone
* 1.2 | January 16, 2026 |   | Added getAccountAddresses and searchAccounts methods
* 1.3 | January 16, 2026 |   | Integrated contact search, fixed account handling
* 1.4 | January 20, 2026 |   | Updated shipping address to exclude country code
**/

public class DRC_NBC_CloneQuoteController {

    /**
     * Wrapper class for Quote data with related information
     */
    public class QuoteCloneWrapper {
        @AuraEnabled public Quote quoteData;
        @AuraEnabled public String accountName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public List<Contact> contacts;
        @AuraEnabled public List<AddressWrapper> shippingAddresses;
        @AuraEnabled public List<AddressWrapper> billingAddresses;
        @AuraEnabled public Integer lineItemCount;
        @AuraEnabled public String accountBillingStreet;
        @AuraEnabled public String accountBillingCity;
        @AuraEnabled public String accountBillingState;
        @AuraEnabled public String accountBillingPostalCode;
        @AuraEnabled public String accountBillingCountry;
    }

    public class AddressWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public AddressWrapper(Id value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    /**
     * Wrapper class for Address information
     */
    public class AddressResultWrapper {
        @AuraEnabled public List<AddressWrapper> shippingAddresses;
        @AuraEnabled public List<AddressWrapper> billingAddresses;
        @AuraEnabled public String accountBillingStreet;
        @AuraEnabled public String accountBillingCity;
        @AuraEnabled public String accountBillingState;
        @AuraEnabled public String accountBillingPostalCode;
        @AuraEnabled public String accountBillingCountry;
    }

    /**
     * Search for accounts by name
     */
    @AuraEnabled(cacheable=true)
    public static List<Account> searchAccounts(String searchTerm) {
        if (String.isBlank(searchTerm)) {
            return new List<Account>();
        }

        String searchKey = '%' + searchTerm + '%';
        
        return [
            SELECT Id, Name
            FROM Account
            WHERE Name LIKE :searchKey
            ORDER BY Name
            LIMIT 50
        ];
    }

    /**
     * Get contacts for a specific account
     * Integrated from DRC_NBC_ProductsController
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getAccountContacts(Id accountId) {
        if (String.isBlank(accountId)) {
            return new List<Contact>();
        }

        try {
            return [
                SELECT Id, Name, Email, Phone, Fax, AccountId
                FROM Contact
                WHERE AccountId = :accountId
                ORDER BY Name
                LIMIT 100
            ];
        } catch (Exception e) {
            System.debug('Error fetching contacts: ' + e.getMessage());
            throw new AuraHandledException('Error fetching contacts: ' + e.getMessage());
        }
    }

    /**
     * Fetch all quote information for cloning
     * Does NOT return Quote Line Items to the frontend
     */
    @AuraEnabled(cacheable=true)
    public static QuoteCloneWrapper getQuoteForClone(Id quoteId) {
        if (String.isBlank(quoteId)) {
            throw new AuraHandledException('Quote ID is required.');
        }

        QuoteCloneWrapper wrapper = new QuoteCloneWrapper();

        try {
            // Fetch original quote
            Quote originalQuote = [
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
                       Opportunity.Account.Name,
                       AccountId,
                       Account.Name,
                       ContactId,
                       Contact.Name,
                       BillingStreet,
                       BillingCity,
                       BillingState,
                       BillingPostalCode,
                       BillingCountry,
                       ShippingStreet,
                       ShippingCity,
                       ShippingState,
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

            // Prepare quote data for cloning (clear ID and keep name blank)
            wrapper.quoteData = new Quote();
            wrapper.quoteData.Name = ''; // Keep blank - user must enter
            wrapper.quoteData.Status = 'Draft'; // Always set to Draft for clone
            wrapper.quoteData.ExpirationDate = originalQuote.ExpirationDate;
            wrapper.quoteData.DRC_NBC_Lead_Time__c = originalQuote.DRC_NBC_Lead_Time__c; 
            wrapper.quoteData.Description = originalQuote.Description;
            wrapper.quoteData.CurrencyIsoCode = originalQuote.CurrencyIsoCode;
            wrapper.quoteData.DRC_NBC_Type__c = originalQuote.DRC_NBC_Type__c;
            wrapper.quoteData.DRC_NBC_Payemnt_Term__c = originalQuote.DRC_NBC_Payemnt_Term__c;
            wrapper.quoteData.DRC_NBC_Inco_terms__c = originalQuote.DRC_NBC_Inco_terms__c;
            wrapper.quoteData.DRC_NBC_Special_Requirements__c = originalQuote.DRC_NBC_Special_Requirements__c;
            wrapper.quoteData.OpportunityId = originalQuote.OpportunityId;
            wrapper.quoteData.ContactId = originalQuote.ContactId;
            wrapper.quoteData.Email = originalQuote.Email;
            wrapper.quoteData.Phone = originalQuote.Phone;
            wrapper.quoteData.Fax = originalQuote.Fax;
            wrapper.quoteData.DRC_NBC_Other_Tax_Amount__c = originalQuote.DRC_NBC_Other_Tax_Amount__c;
            wrapper.quoteData.DRC_NBC_TCS_Amount__c = originalQuote.DRC_NBC_TCS_Amount__c;
            wrapper.quoteData.DRC_NBC_Shipping_Address_Id__c = originalQuote.DRC_NBC_Shipping_Address_Id__c;

            // Determine the Account ID (prioritize Opportunity's Account)
            Id accountId = originalQuote.Opportunity?.AccountId != null ? 
                          originalQuote.Opportunity.AccountId : 
                          originalQuote.AccountId;

            // Set account information
            wrapper.accountId = accountId;
            wrapper.accountName = originalQuote.Opportunity?.Account?.Name != null ? 
                                 originalQuote.Opportunity.Account.Name : 
                                 originalQuote.Account?.Name;

            // Store AccountId in quoteData for easy access
           // wrapper.quoteData.AccountId = accountId;

            // Count line items (for display purposes only)
            wrapper.lineItemCount = [
                SELECT COUNT()
                FROM QuoteLineItem
                WHERE QuoteId = :quoteId
            ];

            if (accountId != null) {
                // Fetch contacts for the account
                wrapper.contacts = getAccountContacts(accountId);

                // Fetch addresses
                wrapper.shippingAddresses = new List<AddressWrapper>();
                wrapper.billingAddresses = new List<AddressWrapper>();

                // Get shipping addresses from DRC_NBC_Addresses__c
                for (DRC_NBC_Addresses__c addr : [
                    SELECT Id,
                        DRC_NBC_Address__Street__s,
                        DRC_NBC_Address__City__s,
                        DRC_NBC_Address__StateCode__s,
                        DRC_NBC_Address__PostalCode__s,
                        DRC_NBC_Address__CountryCode__s
                    FROM DRC_NBC_Addresses__c
                    WHERE DRC_NBC_Account__c = :accountId
                    AND DRC_NBC_Type__c = 'Shipping'
                ]) {
                    List<String> addressParts = new List<String>();
                    if (String.isNotBlank(addr.DRC_NBC_Address__Street__s)) {
                        addressParts.add(addr.DRC_NBC_Address__Street__s);
                    }
                    if (String.isNotBlank(addr.DRC_NBC_Address__City__s)) {
                        addressParts.add(addr.DRC_NBC_Address__City__s);
                    }
                    if (String.isNotBlank(addr.DRC_NBC_Address__StateCode__s)) {
                        addressParts.add(addr.DRC_NBC_Address__StateCode__s);
                    }
                    if (String.isNotBlank(addr.DRC_NBC_Address__PostalCode__s)) {
                        addressParts.add(addr.DRC_NBC_Address__PostalCode__s);
                    }
                    if (String.isNotBlank(addr.DRC_NBC_Address__CountryCode__s)) {
                        addressParts.add(addr.DRC_NBC_Address__CountryCode__s);
                    }

                    String fullAddress = String.join(addressParts, ', ');
                    wrapper.shippingAddresses.add(new AddressWrapper(addr.Id, fullAddress));
                }

                // Get billing address from Account
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
                    wrapper.accountBillingStreet = acc.BillingStreet;
                    wrapper.accountBillingCity = acc.BillingCity;
                    wrapper.accountBillingState = acc.BillingState;
                    wrapper.accountBillingPostalCode = acc.BillingPostalCode;
                    wrapper.accountBillingCountry = acc.BillingCountry;

                    List<String> billingParts = new List<String>();
                    if (String.isNotBlank(acc.BillingStreet)) {
                        billingParts.add(acc.BillingStreet);
                    }
                    if (String.isNotBlank(acc.BillingCity)) {
                        billingParts.add(acc.BillingCity);
                    }
                    if (String.isNotBlank(acc.BillingState)) {
                        billingParts.add(acc.BillingState);
                    }
                    if (String.isNotBlank(acc.BillingPostalCode)) {
                        billingParts.add(acc.BillingPostalCode);
                    }
                    if (String.isNotBlank(acc.BillingCountry)) {
                        billingParts.add(acc.BillingCountry);
                    }

                    String billingAddress = String.join(billingParts, ', ');
                    wrapper.billingAddresses.add(new AddressWrapper(acc.Id, billingAddress));
                }
            }

            return wrapper;

        } catch (Exception e) {
            System.debug('Error fetching quote for clone: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching Quote for cloning: ' + e.getMessage());
        }
    }

    /**
     * Fetch addresses for a given account
     * Used when user changes the Account field
     */
    @AuraEnabled
    public static AddressResultWrapper getAccountAddresses(Id accountId) {
        if (String.isBlank(accountId)) {
            throw new AuraHandledException('Account ID is required.');
        }

        AddressResultWrapper wrapper = new AddressResultWrapper();
        wrapper.shippingAddresses = new List<AddressWrapper>();
        wrapper.billingAddresses = new List<AddressWrapper>();

        try {
            System.debug('Fetching addresses for Account ID: ' + accountId);
            
            // Get shipping addresses from DRC_NBC_Addresses__c
            List<DRC_NBC_Addresses__c> addresses = [
                SELECT Id,
                    DRC_NBC_Address__Street__s,
                    DRC_NBC_Address__City__s,
                    DRC_NBC_Address__StateCode__s,
                    DRC_NBC_Address__PostalCode__s,
                    DRC_NBC_Address__CountryCode__s
                FROM DRC_NBC_Addresses__c
                WHERE DRC_NBC_Account__c = :accountId
                AND DRC_NBC_Type__c = 'Shipping'
            ];
            
            System.debug('Found ' + addresses.size() + ' shipping addresses');
            
            for (DRC_NBC_Addresses__c addr : addresses) {
                List<String> addressParts = new List<String>();
                if (String.isNotBlank(addr.DRC_NBC_Address__Street__s)) {
                    addressParts.add(addr.DRC_NBC_Address__Street__s);
                }
                if (String.isNotBlank(addr.DRC_NBC_Address__City__s)) {
                    addressParts.add(addr.DRC_NBC_Address__City__s);
                }
                if (String.isNotBlank(addr.DRC_NBC_Address__StateCode__s)) {
                    addressParts.add(addr.DRC_NBC_Address__StateCode__s);
                }
                if (String.isNotBlank(addr.DRC_NBC_Address__PostalCode__s)) {
                    addressParts.add(addr.DRC_NBC_Address__PostalCode__s);
                }
                if (String.isNotBlank(addr.DRC_NBC_Address__CountryCode__s)) {
                    addressParts.add(addr.DRC_NBC_Address__CountryCode__s);
                }

                String fullAddress = String.join(addressParts, ', ');
                System.debug('Adding shipping address: ' + fullAddress);
                wrapper.shippingAddresses.add(new AddressWrapper(addr.Id, fullAddress));
            }

            // Get billing address from Account
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
                wrapper.accountBillingStreet = acc.BillingStreet;
                wrapper.accountBillingCity = acc.BillingCity;
                wrapper.accountBillingState = acc.BillingState;
                wrapper.accountBillingPostalCode = acc.BillingPostalCode;
                wrapper.accountBillingCountry = acc.BillingCountry;

                List<String> billingParts = new List<String>();
                if (String.isNotBlank(acc.BillingStreet)) {
                    billingParts.add(acc.BillingStreet);
                }
                if (String.isNotBlank(acc.BillingCity)) {
                    billingParts.add(acc.BillingCity);
                }
                if (String.isNotBlank(acc.BillingState)) {
                    billingParts.add(acc.BillingState);
                }
                if (String.isNotBlank(acc.BillingPostalCode)) {
                    billingParts.add(acc.BillingPostalCode);
                }
                if (String.isNotBlank(acc.BillingCountry)) {
                    billingParts.add(acc.BillingCountry);
                }

                String billingAddress = String.join(billingParts, ', ');
                System.debug('Billing address: ' + billingAddress);
                wrapper.billingAddresses.add(new AddressWrapper(acc.Id, billingAddress));
            }

            System.debug('Returning wrapper with ' + wrapper.shippingAddresses.size() + ' shipping addresses');
            return wrapper;

        } catch (Exception e) {
            System.debug('Error fetching addresses for account: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching addresses: ' + e.getMessage());
        }
    }

    /**
     * Clone the quote with all its line items
     * This method handles the complete cloning in the backend
     */
    @AuraEnabled
    public static Map<String, String> cloneQuoteWithLineItems(Id originalQuoteId, Quote quoteData) {
        Map<String, String> result = new Map<String, String>();
        Savepoint sp = Database.setSavepoint();

        try {
            // Step 1: Validate input
            if (String.isBlank(originalQuoteId)) {
                throw new AuraHandledException('Original Quote ID is required.');
            }
            if (quoteData == null) {
                throw new AuraHandledException('Quote data is required.');
            }

            System.debug('Cloning Quote ID: ' + originalQuoteId);
            System.debug('New Quote Data: ' + JSON.serializePretty(quoteData));

            // Step 2: Fetch original quote to get Pricebook2Id
            Quote originalQuote = [
                SELECT Id, Pricebook2Id, OpportunityId, Opportunity.AccountId, AccountId
                FROM Quote
                WHERE Id = :originalQuoteId
                LIMIT 1
            ];

            // Step 3: Determine the AccountId to use
            Id finalAccountId = null;
            
            // If AccountId is provided in quoteData, use it
            if (quoteData.AccountId != null) {
                finalAccountId = quoteData.AccountId;
            }
            // Otherwise, get from Opportunity or original Quote
            else if (originalQuote.Opportunity?.AccountId != null) {
                finalAccountId = originalQuote.Opportunity.AccountId;
            } else if (originalQuote.AccountId != null) {
                finalAccountId = originalQuote.AccountId;
            }

            System.debug('Final Account ID to use: ' + finalAccountId);

            // Validate that we have an AccountId
            if (finalAccountId == null) {
                throw new AuraHandledException('Account is required for cloning the quote.');
            }

            // Step 4: Create new Quote
            Quote newQuote = new Quote(
                Name = quoteData.Name,
                Status = quoteData.Status,
                ExpirationDate = quoteData.ExpirationDate,
                DRC_NBC_Lead_Time__c = quoteData.DRC_NBC_Lead_Time__c,  
                Description = quoteData.Description,
                CurrencyIsoCode = quoteData.CurrencyIsoCode,
                DRC_NBC_Type__c = quoteData.DRC_NBC_Type__c,
                DRC_NBC_Payemnt_Term__c = quoteData.DRC_NBC_Payemnt_Term__c,
                DRC_NBC_Inco_terms__c = quoteData.DRC_NBC_Inco_terms__c,
                DRC_NBC_Special_Requirements__c = quoteData.DRC_NBC_Special_Requirements__c,
                OpportunityId = quoteData.OpportunityId,
               // AccountId = finalAccountId,  // Use the determined AccountId
                ContactId = quoteData.ContactId,
                Email = quoteData.Email,
                Phone = quoteData.Phone,
                Fax = quoteData.Fax,
                DRC_NBC_Other_Tax_Amount__c = quoteData.DRC_NBC_Other_Tax_Amount__c,
                DRC_NBC_TCS_Amount__c = quoteData.DRC_NBC_TCS_Amount__c,
                DRC_NBC_Shipping_Address_Id__c = quoteData.DRC_NBC_Shipping_Address_Id__c,
                Pricebook2Id = originalQuote.Pricebook2Id,
                BillingStreet = quoteData.BillingStreet,
                BillingCity = quoteData.BillingCity,
                BillingState = quoteData.BillingState,
                BillingPostalCode = quoteData.BillingPostalCode,
                BillingCountry = quoteData.BillingCountry
            );

            // Shipping address ID is already set in DRC_NBC_Shipping_Address_Id__c
            // No need to update individual shipping address fields

            insert newQuote;
            System.debug('New Quote created with ID: ' + newQuote.Id);

            // Step 5: Fetch original Quote Line Items
            List<QuoteLineItem> originalQLIs = [
                SELECT Id,
                       Product2Id,
                       PricebookEntryId,
                       Quantity,
                       UnitPrice,
                       Discount,
                       Description,
                       ListPrice,
                       DRC_NBC_Unit_Of_Measurement__c
                FROM QuoteLineItem
                WHERE QuoteId = :originalQuoteId
            ];

            System.debug('Found ' + originalQLIs.size() + ' line items to clone');

            // Step 6: Clone Quote Line Items
            List<QuoteLineItem> newQLIs = new List<QuoteLineItem>();
            for (QuoteLineItem originalQLI : originalQLIs) {
                QuoteLineItem newQLI = new QuoteLineItem(
                    QuoteId = newQuote.Id,
                    Product2Id = originalQLI.Product2Id,
                    PricebookEntryId = originalQLI.PricebookEntryId,
                    Quantity = originalQLI.Quantity,
                    UnitPrice = originalQLI.UnitPrice,
                    Discount = originalQLI.Discount,
                    Description = originalQLI.Description,
                    DRC_NBC_Unit_Of_Measurement__c = originalQLI.DRC_NBC_Unit_Of_Measurement__c
                );
                newQLIs.add(newQLI);
            }

            // Step 7: Insert cloned Quote Line Items
            if (!newQLIs.isEmpty()) {
                insert newQLIs;
                System.debug('Successfully inserted ' + newQLIs.size() + ' line items');
            }

            // Step 8: Return success with new Quote ID
            result.put('status', 'success');
            result.put('quoteId', newQuote.Id);
            result.put('message', 'Quote cloned successfully with ' + newQLIs.size() + ' line items');

            return result;

        } catch (DmlException dmlEx) {
            Database.rollback(sp);
            System.debug('DML Error while cloning quote: ' + dmlEx.getMessage());
            System.debug('Stack trace: ' + dmlEx.getStackTraceString());
            throw new AuraHandledException('Failed to clone Quote: ' + dmlEx.getDmlMessage(0));
        } catch (Exception ex) {
            Database.rollback(sp);
            System.debug('Error while cloning quote: ' + ex.getMessage());
            System.debug('Stack trace: ' + ex.getStackTraceString());
            throw new AuraHandledException('Error cloning Quote: ' + ex.getMessage());
        }
    }
}