@RestResource(urlMapping = '/ProductSync/*')
global without sharing class DRC_NBC_ProductSync_WebService {
    
    @HttpPost
    global static void syncProducts() {
        Savepoint sp;
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        try {
            sp = Database.setSavePoint();
            String body = req.requestBody.toString();
            
            // Deserialize and validate payload
            DRC_NBC_Integration_Payload.productWithPriceBookPayloadLst dataLst =
                DRC_NBC_Integration_Utility.validateProductSyncPayload(body);
            
            // Declare working collections
            List<Product2> productToUpsert = new List<Product2>();
            Map<String, String> productCodeToProductId = new Map<String, String>();
            Set<String> uniqueStdPriceBookEntryKey = new Set<String>();
            List<PriceBookEntry> priceBookEntriesToUpsert = new List<PriceBookEntry>();
            Map<String, PriceBookEntry> priceBookExternalIdToPriceBook = new Map<String, PriceBookEntry>();
            Map<String, PriceBook2> pricebooksToUpsertMap = new Map<String, PriceBook2>();
            Map<String, PriceBookEntry> priceBookEntriesToUpsertMap = new Map<String, PriceBookEntry>();
            Set<String> productCodes = new Set<String>();
            Set<String> priceBookCurrency = new Set<String>();
            
            // Retrieve standard price book
            String standardPricebookId;
            if (Test.isRunningTest()) {
                standardPricebookId = Test.getStandardPricebookId();
            } else {
                standardPricebookId = [
                    SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1
                ].Id;
            }
            
            // -----------------------------------
            // STEP 1: Upsert Products
            // -----------------------------------
            for (DRC_NBC_Integration_Payload.productWithPriceBookPayload data : dataLst.products) {
                Product2 productObj = new Product2(
                    Name                          = data.product.productName,
                    ProductCode                   = data.product.FGCode,
                    QuantityUnitOfMeasure         = data.product.uom,
                    IsActive                      = data.product.isActive,
                    DRC_NBC_FG_Code__c            = data.product.FGCode,
                    DRC_NBC_GST_Group_Code__c     = data.product.GST_Group_Code,
                    Family                        = data.product.productFamily,
                    DRC_NBC_Category_Level_1__c   = data.product.ProductCategoryL1,
                    DRC_NBC_Category_Level_2__c   = data.product.ProductCategoryL2,
                    DRC_NBC_Category_Level_3__c   = data.product.ProductCategoryL3,
                    DRC_NBC_HSN_SAC_Code__c       = data.product.HSNCode
                    // ✅ Removed DRC_NBC_Packing_Size__c — now handled via child object
                );
                productToUpsert.add(productObj);
                productCodes.add(productObj.ProductCode);
            }
            
            upsert productToUpsert DRC_NBC_FG_Code__c;
            
            // Map product code to Id after upsert
            for (Product2 p : productToUpsert) {
                productCodeToProductId.put(p.DRC_NBC_FG_Code__c, p.Id);
            }
            
            // -----------------------------------
            // STEP 2: Upsert Packing Details
            // -----------------------------------
            // Delete existing packing detail records for these products
            // so we do a clean replace on each sync
            List<DRC_NBC_Packing_Details__c> existingPackingDetails = [
                SELECT Id 
                FROM DRC_NBC_Packing_Details__c 
                WHERE Product__c IN :productCodeToProductId.values()
            ];
            if (!existingPackingDetails.isEmpty()) {
                delete existingPackingDetails;
            }
            
            // Build new packing detail records
            List<DRC_NBC_Packing_Details__c> packingDetailsToInsert = new List<DRC_NBC_Packing_Details__c>();
            
            for (DRC_NBC_Integration_Payload.productWithPriceBookPayload data : dataLst.products) {
                String productId = productCodeToProductId.get(data.product.FGCode);
                
                if (data.product.packingDetails != null && !data.product.packingDetails.isEmpty()) {
                    for (DRC_NBC_Integration_Payload.PackingDetail pd : data.product.packingDetails) {
                        DRC_NBC_Packing_Details__c packingRecord = new DRC_NBC_Packing_Details__c(
                            Product__c                    = productId,           // ✅ Lookup to Product2
                            DRC_NBC_Packing_Size__c       = pd.packingSize,      // ✅ Size field
                            DRC_NBC_Packing_Qauntity__c   = pd.PackingQty,       // ✅ Quantity field
                            DRC_NBC_Packing_Description__c = pd.PackingDescription // ✅ Description field
                        );
                        packingDetailsToInsert.add(packingRecord);
                    }
                }
            }
            
            if (!packingDetailsToInsert.isEmpty()) {
                insert packingDetailsToInsert;
            }
            
            // -----------------------------------
            // STEP 3: Query existing PriceBookEntries
            // -----------------------------------
            for (PriceBookEntry priceBookEntry : [
                SELECT Id, DRC_NBC_External_Id__c
                FROM PriceBookEntry
                WHERE Product2.DRC_NBC_FG_Code__c IN :productCodes
            ]) {
                priceBookExternalIdToPriceBook.put(
                    priceBookEntry.DRC_NBC_External_Id__c,
                    priceBookEntry
                );
            }
            
            // -----------------------------------
            // STEP 4: Collect Currencies
            // -----------------------------------
            for (DRC_NBC_Integration_Payload.productWithPriceBookPayload data : dataLst.products) {
                for (DRC_NBC_Integration_Payload.priceBook pb : data.priceBook) {
                    priceBookCurrency.add(pb.bookEntryCurrency);
                }
            }
            
            for (PricebookEntry currentRecord : [
                SELECT Id, CurrencyIsoCode, Product2.DRC_NBC_FG_Code__c
                FROM PricebookEntry 
                WHERE Pricebook2Id = :standardPricebookId
                AND CurrencyIsoCode IN :priceBookCurrency
                AND Product2.DRC_NBC_FG_Code__c IN :productCodes
            ]) {
                uniqueStdPriceBookEntryKey.add(
                    currentRecord.Product2.DRC_NBC_FG_Code__c + '-' + standardPricebookId + '-' + currentRecord.CurrencyIsoCode
                );
            }
            
            // First pass: collect all pricebooks
            for (DRC_NBC_Integration_Payload.productWithPriceBookPayload data : dataLst.products) {
                for (DRC_NBC_Integration_Payload.priceBook priceBook : data.priceBook) {
                    PriceBook2 pricebookNew = new PriceBook2(
                        Name                   = priceBook.priceBookName,
                        DRC_NBC_External_Id__c = priceBook.priceBookExternalId,
                        IsActive               = true,
                        CurrencyIsoCode        = priceBook.bookEntryCurrency
                    );
                    pricebooksToUpsertMap.put(pricebookNew.DRC_NBC_External_Id__c, pricebookNew);
                }
            }
            
            // Upsert PriceBooks
            List<Pricebook2> pricebookLst = new List<Pricebook2>(pricebooksToUpsertMap.values());
            upsert pricebookLst DRC_NBC_External_Id__c;
            
            // -----------------------------------
            // STEP 5: Build PriceBook Entries
            // -----------------------------------
            for (DRC_NBC_Integration_Payload.productWithPriceBookPayload data : dataLst.products) {
                for (DRC_NBC_Integration_Payload.priceBook priceBook : data.priceBook) {
                    String pricebookPayloadCurrencyFinal = priceBook.bookEntryCurrency;
                    String priceBookExternalIdForStandard =
                        data.product.FGCode + '-' + priceBook.priceBookExternalId + '-' + pricebookPayloadCurrencyFinal;
                    
                    // Standard PriceBook Entry
                    String keyForStdPriceBook = data.product.FGCode + '-' + standardPricebookId + '-' + pricebookPayloadCurrencyFinal;
                    if (!uniqueStdPriceBookEntryKey.contains(keyForStdPriceBook)) {
                        PriceBookEntry priceBookEntryStandard = new PriceBookEntry(
                            Pricebook2Id           = standardPricebookId,
                            Product2Id             = productCodeToProductId.get(data.product.FGCode),
                            UnitPrice              = priceBook.bookEntryAmount,
                            DRC_NBC_External_Id__c = priceBookExternalIdForStandard,
                            IsActive               = true
                        );
                        if (!priceBookExternalIdToPriceBook.containsKey(priceBookExternalIdForStandard)) {
                            priceBookEntryStandard.CurrencyIsoCode = pricebookPayloadCurrencyFinal;
                        }
                        priceBookEntriesToUpsertMap.put(priceBookExternalIdForStandard, priceBookEntryStandard);
                        uniqueStdPriceBookEntryKey.add(keyForStdPriceBook);
                    }
                    
                    // Custom PriceBook Entry
                    PriceBookEntry priceBookEntryCustom = new PriceBookEntry(
                        Pricebook2             = new PriceBook2(DRC_NBC_External_Id__c = priceBook.priceBookExternalId),
                        Product2Id             = productCodeToProductId.get(data.product.FGCode),
                        UnitPrice              = priceBook.bookEntryAmount,
                        IsActive               = true,
                        DRC_NBC_External_Id__c = priceBook.bookEntryExternalId
                    );
                    if (!priceBookExternalIdToPriceBook.containsKey(priceBook.bookEntryExternalId)) {
                        priceBookEntryCustom.CurrencyIsoCode = pricebookPayloadCurrencyFinal;
                    }
                    priceBookEntriesToUpsertMap.put(priceBook.bookEntryExternalId, priceBookEntryCustom);
                }
            }
            
            // Upsert PriceBook Entries
            priceBookEntriesToUpsert = new List<PriceBookEntry>(priceBookEntriesToUpsertMap.values());
            upsert priceBookEntriesToUpsert DRC_NBC_External_Id__c;
            
            // -----------------------------------
            // SUCCESS RESPONSE
            // -----------------------------------
            res.statusCode = 200;
            res.responseBody = Blob.valueOf('Record Upserted Successfully');
            DRC_NBC_API_Log_Handler.createApiLog(
                '/ProductSync', body, res.responseBody?.toString(), 'POST', null, res.statusCode, null, 'Success', null
            );
            
        } catch (Exception e) {
            Database.rollback(sp);
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error: ' + e.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                '/ProductSync', req.requestBody.toString(), null, 'POST',
                e.getMessage(), 500, e.getStackTraceString(), 'Error', null
            );
        }
    }
}