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
            System.debug('1');
            
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
                //For Adding Multiple Packaging Size
           /*     String packingSizeValue = (data.product.packingSize != null && !data.product.packingSize.isEmpty())
                    ? String.join(data.product.packingSize, '; ')
                    : null;*/
                Product2 productObj = new Product2(
                    Name = data.product.productName,
                    ProductCode = data.product.FGCode,
                    QuantityUnitOfMeasure = data.product.uom,
                    IsActive = data.product.isActive,
                    DRC_NBC_FG_Code__c = data.product.FGCode,
                    DRC_NBC_GST_Group_Code__c = data.product.GST_Group_Code,
                    Family = data.product.productFamily,
                    DRC_NBC_Category_Level_1__c = data.product.ProductCategoryL1,
                    DRC_NBC_Category_Level_2__c = data.product.ProductCategoryL2,
                    DRC_NBC_Category_Level_3__c = data.product.ProductCategoryL3,
                    DRC_NBC_HSN_SAC_Code__c = data.product.HSNCode,
                    //  DRC_NBC_KIND_OF_PKG__c = data.product.packingSize
                    DRC_NBC_Packing_Size__c      = data.product.packingSize
                );
                productToUpsert.add(productObj);
                productCodes.add(productObj.ProductCode);
            }
            
            upsert productToUpsert DRC_NBC_FG_Code__c;
            
            // Map product code to Id
            for (Product2 p : productToUpsert) {
                productCodeToProductId.put(p.DRC_NBC_FG_Code__c, p.Id);
            }
            
            Map<String, Id> priceBookExtIdToId = new Map<String, Id>();
            for (PriceBookEntry priceBookEntry : [
                Select
                Id,
                DRC_NBC_External_Id__c
                FROM
                PriceBookEntry
                WHERE
                Product2.DRC_NBC_FG_Code__c IN : productCodes]) {
                    // priceBookExtIdToId.put(pb2.DRC_NBC_External_Id__c, pb2.Id);
                    priceBookExternalIdToPriceBook.put(
                        priceBookEntry.DRC_NBC_External_Id__c,
                        priceBookEntry
                    );
                }
            
            // -----------------------------------
            // STEP 2: Collect Currencies & Build PriceBooks
            // -----------------------------------
            for (DRC_NBC_Integration_Payload.productWithPriceBookPayload data : dataLst.products) {
                for (DRC_NBC_Integration_Payload.priceBook pb : data.priceBook) {
                    priceBookCurrency.add(pb.bookEntryCurrency);
                }
            }
            
            for(PricebookEntry currentRecord : [
                SELECT
                Id, CurrencyIsoCode,Product2.DRC_NBC_FG_Code__c
                FROM
                PricebookEntry 
                WHERE
                Pricebook2Id =:standardPricebookId  AND
                CurrencyIsoCode In :priceBookCurrency AND
                Product2.DRC_NBC_FG_Code__c IN :productCodes
            ]) {
                String currencyCode = currentRecord.CurrencyIsoCode;
                uniqueStdPriceBookEntryKey.add(
                    currentRecord.Product2.DRC_NBC_FG_Code__c + '-' + standardPricebookId + '-' + currencyCode
                );
            }
            
            // Upsert PriceBooks
            upsert new List<PriceBook2>(pricebooksToUpsertMap.values()) DRC_NBC_External_Id__c;
            System.debug('1');
            
            // Refresh PriceBook2 Ids after upsert
            
            
            for (DRC_NBC_Integration_Payload.productWithPriceBookPayload data : dataLst.products) {                
                for (DRC_NBC_Integration_Payload.priceBook priceBook : data.priceBook) {
                    String pricebookPayloadCurrencyFinal = pricebook.bookEntryCurrency;
                    // Step 2>  upsert PriceBook
                    PriceBook2 pricebookNew = new PriceBook2(
                        Name = priceBook.priceBookName,
                        DRC_NBC_External_Id__c = priceBook.priceBookExternalId,
                        IsActive = true,
                        CurrencyIsoCode = pricebookPayloadCurrencyFinal
                    );
                    //--------------------------------------
                    
                    pricebooksToUpsertMap.put(pricebookNew.DRC_NBC_External_Id__c, pricebookNew);
                    String priceBookExternalIdForStandard =
                        data.product.FGCode + '-' + priceBook.priceBookExternalId + '-' + pricebookPayloadCurrencyFinal;                    
                    
                    // Only add std pricebookentry if its not alread there for that currency under the product
                    String keyForStdPriceBook = data.product.FGCode + '-' + standardPricebookId + '-' + pricebookPayloadCurrencyFinal;
                    if(!uniqueStdPriceBookEntryKey.contains(keyForStdPriceBook)) {
                        PriceBookEntry priceBookEntryStandard = new PriceBookEntry(
                            Pricebook2Id = standardPricebookId,
                            Product2Id = productCodeToProductId.get(data.product.FGCode),
                            UnitPrice = priceBook.bookEntryAmount,
                            DRC_NBC_External_Id__c = priceBookExternalIdForStandard,
                            isActive = true
                        );                    
                        if(!priceBookExternalIdToPriceBook.containsKey(priceBookExternalIdForStandard)) {
                            priceBookEntryStandard.CurrencyIsoCode = pricebookPayloadCurrencyFinal;
                        }
                        priceBookEntriesToUpsertMap.put(
                            priceBookExternalIdForStandard,
                            priceBookEntryStandard
                        );
                        uniqueStdPriceBookEntryKey.add(keyForStdPriceBook);
                    }
                    PriceBookEntry priceBookEntryCustom = new PriceBookEntry(
                        Pricebook2 = new PriceBook2(DRC_NBC_External_Id__c = priceBook.priceBookExternalId),
                        Product2Id = productCodeToProductId.get(data.product.FGCode),
                        UnitPrice = priceBook.bookEntryAmount,
                        isActive = true,
                        DRC_NBC_External_Id__c = priceBook.bookEntryExternalId
                    );
                    if(!priceBookExternalIdToPriceBook.containsKey(priceBook.bookEntryExternalId)) {
                        priceBookEntryCustom.CurrencyIsoCode = pricebookPayloadCurrencyFinal;
                    }
                    priceBookEntriesToUpsertMap.put(
                        priceBook.bookEntryExternalId,
                        priceBookEntryCustom
                    );
                }
            }
            
            {
                // -----------------------------------
                // STEP 3: Handle PricebookEntries (avoid duplicates)
                // -----------------------------------
                
                // Query existing PricebookEntries to avoid duplicate Product + Pricebook combinations
                // List<PricebookEntry> existingPBEs = [
                //     SELECT Id, Product2Id, Pricebook2Id
                //     FROM    
                //     WHERE Product2Id IN :productCodeToProductId.values()
                // ];
                
                // Set<String> existingProductPricebookKeys = new Set<String>();
                // for (PricebookEntry pbe : existingPBEs) {
                //     existingProductPricebookKeys.add(pbe.Product2Id + '-' + pbe.Pricebook2Id);
                // }
                
                // // Build new entries safely
                // for (DRC_NBC_Integration_Payload.productWithPriceBookPayload data : dataLst.products) {
                //     String productId = productCodeToProductId.get(data.product.FGCode);
                
                //     for (DRC_NBC_Integration_Payload.priceBook pb : data.priceBook) {
                //         Id pricebookId = priceBookExtIdToId.get(pb.priceBookExternalId);
                //         if (pricebookId == null) continue;
                
                //         // --- Standard Pricebook Entry ---
                //         String stdKey = productId + '-' + standardPricebookId;
                //         if (!existingProductPricebookKeys.contains(stdKey)) {
                //             PriceBookEntry stdEntry = new PriceBookEntry(
                //                 Pricebook2Id = standardPricebookId,
                //                 Product2Id = productId,
                //                 UnitPrice = pb.bookEntryAmount,
                //                 DRC_NBC_External_Id__c = data.product.FGCode + '-' + pb.priceBookExternalId,
                //                 IsActive = true,
                //                 CurrencyIsoCode = pb.bookEntryCurrency
                
                //             );
                //             priceBookEntriesToUpsertMap.put(stdEntry.DRC_NBC_External_Id__c, stdEntry);
                //             existingProductPricebookKeys.add(stdKey);
                //         }
                
                //         // --- Custom Pricebook Entry ---
                //         String customKey = productId + '-' + pricebookId;
                //         if (!existingProductPricebookKeys.contains(customKey)) {
                //             PriceBookEntry customEntry = new PriceBookEntry(
                //                 Pricebook2Id = pricebookId,
                //                 Product2Id = productId,
                //                 UnitPrice = pb.bookEntryAmount,
                //                 IsActive = true,
                //                 DRC_NBC_External_Id__c = pb.bookEntryExternalId
                //             );
                //             priceBookEntriesToUpsertMap.put(customEntry.DRC_NBC_External_Id__c, customEntry);
                //             existingProductPricebookKeys.add(customKey);
                //         }
                //     }
                // }
            }
            
            
            // Upsert Pricebook Entries
            // if (!priceBookEntriesToUpsertMap.isEmpty()) {
            //     upsert new List<PriceBookEntry>(priceBookEntriesToUpsertMap.values()) DRC_NBC_External_Id__c;
            // }
            
            List<Pricebook2> pricebookLst = new List<Pricebook2>(pricebooksToUpsertMap.values());
            upsert pricebookLst DRC_NBC_External_Id__c;
            
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
            System.debug('1');
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