public without sharing class DRC_NBC_Generate_Order_Controller {
    @AuraEnabled
    public static List<OptionsWrapper> getOrderRecordTypes() {
        try {
            List<OptionsWrapper> recordTypeOptions = new List<OptionsWrapper>();
            Schema.DescribeSObjectResult orderDescribe = Order.SObjectType.getDescribe();
            Map<Id, Schema.RecordTypeInfo> recordTypeInfos = orderDescribe.getRecordTypeInfosById();
            
            for (Schema.RecordTypeInfo rtInfo : recordTypeInfos.values()) {
                if (rtInfo.isAvailable() && !rtInfo.getName().equalsIgnoreCase('Master')) {
                    OptionsWrapper option = new OptionsWrapper();
                    option.label = rtInfo.getName();
                    option.value = rtInfo.getRecordTypeId();
                    recordTypeOptions.add(option);
                }
            }
            return recordTypeOptions;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static List<OptionsWrapper> getOrderTypes() {
        try {
            List<OptionsWrapper> orderTypes = new List<OptionsWrapper>();
            Schema.SObjectType orderType = Schema.getGlobalDescribe().get('Order');
            Schema.DescribeSObjectResult describeResult = orderType.getDescribe();
            Map<String, Schema.SObjectField> fieldsMap = describeResult.fields.getMap();
            
            Schema.DescribeFieldResult typeFieldResult = fieldsMap.get('DRC_NBC_Type__c').getDescribe();
            for (Schema.PicklistEntry entry : typeFieldResult.getPicklistValues()) {
                OptionsWrapper wrapper = new OptionsWrapper();
                wrapper.label = entry.getLabel();
                wrapper.value = entry.getValue();
                orderTypes.add(wrapper);
            }
            return orderTypes;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving Order Types: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static OrderDefaults getDefaultValues(String quoteID){
        try {
            System.debug(quoteID);
            Quote quoteObj = [
                SELECT
                AccountId,
                Pricebook2Id,
                OpportunityId,
                DRC_NBC_Payemnt_Term__c,
                DRC_NBC_Inco_terms__c,
                DRC_NBC_I_GST__c,
                DRC_NBC_C_GST__c,
                DRC_NBC_S_GST__c,
                DRC_NBC_TCS_Amount__c,
                DRC_NBC_Other_Tax_Amount__c,
                DRC_NBC_Delivery_Terms__c,
                DRC_NBC_Type__c,
                Account.BillingStreet,
                Account.BillingCity,
                Account.BillingState,
                Account.BillingPostalCode,
                Account.BillingCountry,
                Account.BillingCountryCode
                FROM Quote 
                WHERE ID = :quoteID
            ];
            
            // Initialize wrapper
            OrderDefaults ord = new OrderDefaults();
            ord.acc = [
                SELECT
                    ID,
                    CurrencyISOCode,
                    DRC_NBC_Consignee_Bank_Account_Number__c,
                    DRC_NBC_Consignee_Bank_IFSC_Code__c,
                    DRC_NBC_Consignee_Bank_Name__c,
                    DRC_NBC_Consignee_Bank_Address__c,
                    (
                        SELECT
                            ID,
                            DRC_NBC_Type__c,
                            DRC_NBC_Address__c
                        FROM 
                            Address__r
                        WHERE
                            DRC_NBC_Type__c = 'Shipping'
                    )
                FROM
                    Account
                WHERE
                    Id =: quoteObj.AccountId 
            ];
            
            ord.opportunityObj = [
                SELECT
                    CurrencyIsoCode
                FROM
                    Opportunity
                WHERE
                    Id =: quoteObj.OpportunityId
            ];
            
            // Assign related contacts
            List<Contact> customerContacts = [
                SELECT Id, Name
                FROM Contact
                WHERE AccountID = :ord.acc[0].Id
            ];
            ord.customerContacts = customerContacts;
            ord.paymentTerm = quoteObj.DRC_NBC_Payemnt_Term__c;
            ord.incoTerm = quoteObj.DRC_NBC_Inco_terms__c;
            ord.igst = quoteObj.DRC_NBC_I_GST__c;
            ord.types = quoteObj.DRC_NBC_Type__c;
            ord.deliveryTerm = quoteObj.DRC_NBC_Delivery_Terms__c;
            ord.cgst = quoteObj.DRC_NBC_C_GST__c;
            ord.sgst = quoteObj.DRC_NBC_S_GST__c;
            ord.tcsAmount = quoteObj.DRC_NBC_TCS_Amount__c;
            ord.otherTaxAmount = quoteObj.DRC_NBC_Other_Tax_Amount__c;
            
            // Add Account Billing Address
            ord.BillingStreet = quoteObj.Account.BillingStreet;
            ord.BillingCity = quoteObj.Account.BillingCity;
            ord.BillingState = quoteObj.Account.BillingState;
            ord.BillingPostalCode = quoteObj.Account.BillingPostalCode;
            ord.BillingCountry = quoteObj.Account.BillingCountry;
            ord.BillingCountryCode = quoteObj.Account.BillingCountryCode;
            ord.Pricebook2Id = quoteObj.Pricebook2Id;
            ord.orderItems = makeOrderWrapper(quoteID);
            return ord;	
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String createOrder(Order orderObj, List<DRC_NBC_OrderItemWrapper> orderItems, String quoteID) {
        try {
            System.debug('Received Order: ' + JSON.serialize(orderObj));
            System.debug('Order Items: ' + JSON.serialize(orderItems));
            System.debug('Quote ID: ' + quoteID);
            
            // Validate emails
            List<Contact> contacts = [SELECT Name, Email FROM Contact WHERE Id IN :new List<Id>{ orderObj.BillToContactId, orderObj.ShipToContactId }];
            for (Contact con : contacts) {
                if (String.isBlank(con.Email)) {
                    return JSON.serialize(new Map<String, Object>{
                        'success' => false,
                        'error' => 'Please provide email for ' + con.Name
                    });
                }
            }
            
            Quote quoteObj = [
                SELECT
                AccountId,
                OpportunityId,
                DRC_NBC_Inco_terms__c
                FROM 
                Quote 
                WHERE 
                ID = :quoteID
            ];
            
            orderObj.OpportunityId = quoteObj.OpportunityId;

            // Populate Location Code from Shipping Address → Warehouse
            if (orderObj.DRC_NBC_Shipping_Address__c != null) {
                DRC_NBC_Addresses__c addr = [
                    SELECT DRC_NBC_Warehouse__c
                    FROM DRC_NBC_Addresses__c
                    WHERE Id = :orderObj.DRC_NBC_Shipping_Address__c
                    LIMIT 1
                ];
                
            }

            insert orderObj;
            
            // Fetch inserted order
            Order insertedOrder = [SELECT Id, Pricebook2Id FROM Order WHERE Id = :orderObj.Id LIMIT 1];
            
            // Build PBE map
            Map<String, Id> productIdToPbeId = new Map<String, Id>();
            for (PricebookEntry pbe : [
                SELECT Id, Product2Id FROM PricebookEntry WHERE Pricebook2Id = :insertedOrder.Pricebook2Id
            ]) {
                productIdToPbeId.put(pbe.Product2Id, pbe.Id);
            }
            
            // Fetch product names for error messages
            Set<Id> productIds = new Set<Id>();
            for (DRC_NBC_OrderItemWrapper w : orderItems) {
                if (String.isNotBlank(w.Product2Id)) {
                    productIds.add(w.Product2Id);
                }
            }
            Map<Id, String> productIdToName = new Map<Id, String>();
            for (Product2 p : [SELECT Id, Name FROM Product2 WHERE Id IN :productIds]) {
                productIdToName.put(p.Id, p.Name);
            }
            
            // Build OrderItems
            List<OrderItem> finalOrderItems = new List<OrderItem>();
            List<String> missingPBEs = new List<String>();
            for (DRC_NBC_OrderItemWrapper w : orderItems) {
                if (String.isBlank(w.Product2Id)) continue;
                String pbeId = w.PriceBookEntryId;
                if (String.isBlank(pbeId)) {
                    pbeId = productIdToPbeId.get(w.Product2Id);
                }
                
                if (String.isBlank(pbeId)) {
                    missingPBEs.add(productIdToName.get(w.Product2Id) + ' (Product2Id: ' + w.Product2Id + ')');
                    continue;
                }
                System.debug('Wrapper values: Product2Id=' + w.Product2Id + ', PricebookEntryId=' + w.PriceBookEntryId + ', UnitPrice=' + w.UnitPrice + ', Quantity=' + w.Quantity);
                
                Decimal unitPrice = 0;
                try {
                    unitPrice = w.UnitPrice;
                } catch (Exception e) {
                    System.debug('Failed to parse UnitPrice for Product2Id: ' + w.Product2Id);
                }
                
                OrderItem oi = new OrderItem();
                oi.OrderId = insertedOrder.Id; 
                oi.PricebookEntryId = pbeId;
                oi.Quantity = (w.Quantity != null && w.Quantity > 0) ? w.Quantity : 1;
                oi.UnitPrice = unitPrice;
                oi.Description = w.Description;
                oi.DRC_NBC_Update_Sales_Price__c = unitPrice;
                oi.DRC_NBC_Unit_Of_Measurement__c = w.UOM;
                oi.DRC_NBC_Packing_Size__c     = w.DRC_NBC_Packing_Size;
                oi.DRC_NBC_Packing_Quantity__c = w.DRC_NBC_Packing_Quantity;
                finalOrderItems.add(oi);
            }
            
            // Update DRC_NBC_Addresses__c records with Order Id
            List<DRC_NBC_Addresses__c> addressUpdates = new List<DRC_NBC_Addresses__c>();
            if (orderObj.DRC_NBC_Shipping_Address__c != null) {
                addressUpdates.add(new DRC_NBC_Addresses__c(
                    Id = orderObj.DRC_NBC_Shipping_Address__c,
                    DRC_NBC_Order__c = insertedOrder.Id
                ));
            }

            if (!addressUpdates.isEmpty()) {
                update addressUpdates;
            }
            
            // Check for missing PBEs
            if (!missingPBEs.isEmpty()) {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error' => 'Missing PricebookEntry for: ' + String.join(missingPBEs, ', ')
                });
            }
            
            // Insert Order Items
            if (!finalOrderItems.isEmpty()) {
                insert finalOrderItems;
            } else {
                return JSON.serialize(new Map<String, Object>{
                    'success' => false,
                    'error' => 'No valid Order Items found to insert.'
                });
            }
            
            // Sync Quote to Opportunity
            Quote quote = [SELECT OpportunityId FROM Quote WHERE Id = :quoteID LIMIT 1];
            if (quote.OpportunityId != null) {
                update new Opportunity(
                    Id = quote.OpportunityId,
                    SyncedQuoteId = quoteID
                );
            }
            
            // Return success
            List<Order> createdOrders = [SELECT Id, OrderNumber FROM Order WHERE Id = :insertedOrder.Id];
            return JSON.serialize(new Map<String, Object>{
                'success' => true,
                'orders' => createdOrders
            });
        } catch (Exception e) {
            return JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => 'Error creating order: ' + e.getMessage() + ' (Line: ' + e.getLineNumber() + ')'
            });
        }
    }
    
    public class Product2Wrapper {
        @AuraEnabled 
        public String Name;
        @AuraEnabled 
        public String QuantityUnitOfMeasure;
        @AuraEnabled 
        public String DRC_NBC_FG_Code;
        @AuraEnabled 
        public String DRC_NBC_HSN_SAC_Code;
    }
    
    public class OrderDefaults{
        @AuraEnabled
        public List<Account> acc;
        @AuraEnabled
        public List<Contact> customerContacts;
        @AuraEnabled
        public String CurrencyISOCode;
        @AuraEnabled
        public String Pricebook2Id;
        @AuraEnabled
        public List<Opportunity> opportunityObj;
        @AuraEnabled
        public List<DRC_NBC_OrderItemWrapper> orderItems;
       
        @AuraEnabled 
        public String paymentTerm;
        @AuraEnabled 
        public String incoTerm;
        @AuraEnabled 
        public String wareHouse;
        @AuraEnabled 
        public String deliveryTerm;
        @AuraEnabled 
        public String types;
        @AuraEnabled 
        public Decimal igst;
        @AuraEnabled 
        public Decimal cgst;
        @AuraEnabled 
        public Decimal sgst;
        @AuraEnabled 
        public Decimal tcsAmount;
        @AuraEnabled 
        public Decimal otherTaxAmount;
        
        // Billing Address from Account
        @AuraEnabled public String BillingStreet;
        @AuraEnabled public String BillingCity;
        @AuraEnabled public String BillingState;
        @AuraEnabled public String BillingPostalCode;
        @AuraEnabled public String BillingCountry;
        @AuraEnabled public String BillingCountryCode;

        // Shipping Address
        @AuraEnabled public String ShippingStreet;
        @AuraEnabled public String ShippingCity;
        @AuraEnabled public String ShippingState;
        @AuraEnabled public String ShippingPostalCode;
        @AuraEnabled public String ShippingCountry;
        @AuraEnabled public String ShippingCountryCode;

        // Consignee Bank Address
        @AuraEnabled public String ConsigneeBankStreet;
        @AuraEnabled public String ConsigneeBankCity;
        @AuraEnabled public String ConsigneeBankStateCode;
        @AuraEnabled public String ConsigneeBankPostalCode;
        @AuraEnabled public String ConsigneeBankCountryCode;
    }
    
    public static List<DRC_NBC_OrderItemWrapper> makeOrderWrapper(String quoteID){
        try {
            List<QuoteLineItem> qlis = getRelatedQLIS(quoteID);
            if(!qlis.isEmpty()) {
                List<DRC_NBC_OrderItemWrapper> orderItems = new List<DRC_NBC_OrderItemWrapper>();
                for(QuoteLineItem qli : qlis) {
                    DRC_NBC_OrderItemWrapper oiw = new DRC_NBC_OrderItemWrapper();
                    oiw.QuoteLineItemId    = qli.Id;
                    oiw.Description        = qli.Description;
                    oiw.Quantity           = qli.Quantity;
                    oiw.UnitPrice          = qli.UnitPrice;
                    oiw.PriceBookEntryId   = qli.PriceBookEntryId;
                    oiw.Product2Id         = qli.Product2Id;
                    // Using actual field API names as they exist in Salesforce org
                    oiw.DRC_NBC_Packing_Size     = qli.DRC_NBC_Packing_Size__c;
                    oiw.DRC_NBC_Packing_Quantity = qli.DRC_NBC_Packing_Qauntity__c;
                    
                    // Create Product2 wrapper
                    Product2Wrapper p2w = new Product2Wrapper();
                    p2w.Name                  = qli.Product2.Name;
                    p2w.QuantityUnitOfMeasure = qli.Product2.QuantityUnitOfMeasure;
                    p2w.DRC_NBC_FG_Code       = qli.Product2.DRC_NBC_FG_Code__c;
                    p2w.DRC_NBC_HSN_SAC_Code  = qli.Product2.DRC_NBC_HSN_SAC_Code__c;
                    oiw.Product2 = p2w;
                    
                    orderItems.add(oiw);
                }
                return orderItems;
            }
            return new List<DRC_NBC_OrderItemWrapper>();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static List<QuoteLineItem> getRelatedQLIS(String quoteID){
        return [
            SELECT
                ID,
                Description,
                Product2.Name,
                Product2.QuantityUnitOfMeasure,
                Product2.DRC_NBC_HSN_SAC_Code__c,
                Product2.DRC_NBC_FG_Code__c,
                Product2Id,
                TotalPrice,
                UnitPrice,
                Discount,
                Quantity,
                PriceBookEntryId,
                DRC_NBC_Packing_Size__c,
                DRC_NBC_Packing_Qauntity__c
            FROM
                QuoteLineItem
            WHERE
                QuoteID =: quoteID
            AND
                Product2.IsActive = True
        ];
    }
    
    @AuraEnabled
    public static PicklistOptionsWrapper makePicklistOptions() {
        try {
            PicklistOptionsWrapper optionsData = new PicklistOptionsWrapper();
            
            try {
                optionsData.makeOptions = fieldPicklistValue('Order_Line_Item__c', 'Incoterm__c');
            } catch (Exception innerEx) {
                optionsData.makeOptions = new List<OptionsWrapper>();
            }
            
            return optionsData;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public static List<OptionsWrapper> fieldPicklistValue(String objectName, String fieldName){
        List<OptionsWrapper> optionList = new List<OptionsWrapper>();
        Schema.SObjectType s = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult r = s.getDescribe();
        Map<String, Schema.SObjectField> fields = r.fields.getMap();
        Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry pickListVal : ple) {
            OptionsWrapper option = new OptionsWrapper();
            option.label = pickListVal.getLabel();
            option.value = pickListVal.getValue();
            optionList.add(option);
        }
        return optionList;
    }
    
    public class PicklistOptionsWrapper{
        @AuraEnabled public List<OptionsWrapper> makeOptions;
    }
    
    public class OptionsWrapper{
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
}