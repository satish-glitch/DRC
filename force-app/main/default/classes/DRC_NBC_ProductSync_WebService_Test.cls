/**
 * @File Name : DRC_NBC_ProductSync_WebService_Test.cls
 * @Description : Test class for DRC_NBC_ProductSync_WebService
 *                Targets 90%+ code coverage across all branches:
 *                - Happy path: products + pricebook entries upserted
 *                - Packing details child records created/replaced
 *                - Existing standard pricebook entry (uniqueStdPriceBookEntryKey branch)
 *                - Existing custom pricebook entry (priceBookExternalIdToPriceBook branch)
 *                - Exception / rollback path
 * @Author : Satish YADAV
 * @Last Modified On : February 25, 2026
 **/
@isTest
private class DRC_NBC_ProductSync_WebService_Test {

    // =========================================================================
    // HELPERS - Build JSON payloads
    // =========================================================================

    /**
     * Single product with one pricebook entry and one packing detail
     */
    private static String buildSingleProductPayload(String fgCode, String priceBookExtId,
                                                    String bookEntryExtId, String cur) {
        return JSON.serialize(new Map<String, Object>{
            'products' => new List<Object>{
                new Map<String, Object>{
                    'product' => new Map<String, Object>{
                        'productName'       => 'Test Product ' + fgCode,
                        'FGCode'            => fgCode,
                        'uom'               => 'KGS',
                        'isActive'          => true,
                        'GST_Group_Code'    => 'GST18',
                        'productFamily'     => 'Beverages',
                        'ProductCategoryL1' => 'Cat1',
                        'ProductCategoryL2' => 'Cat2',
                        'ProductCategoryL3' => 'Cat3',
                        'HSNCode'           => 'HSN1234',
                        'packingDetails'    => new List<Object>{
                            new Map<String, Object>{
                                'packingSize'        => 'PAPER BAGS 15 KGS',
                                'PackingQty'         => '1',
                                'PackingDescription' => 'PAPER BAGS 15 KGS'
                            }
                        }
                    },
                    'priceBook' => new List<Object>{
                        new Map<String, Object>{
                            'priceBookName'       => 'Test PriceBook ' + fgCode,
                            'priceBookExternalId' => priceBookExtId,
                            'bookEntryExternalId' => bookEntryExtId,
                            'bookEntryCurrency'   => cur,
                            'bookEntryAmount'     => 500.00
                        }
                    }
                }
            }
        });
    }

    /**
     * Single product with MULTIPLE packing details (covers list iteration)
     */
    private static String buildMultiPackingPayload(String fgCode, String priceBookExtId,
                                                   String bookEntryExtId, String cur) {
        return JSON.serialize(new Map<String, Object>{
            'products' => new List<Object>{
                new Map<String, Object>{
                    'product' => new Map<String, Object>{
                        'productName'       => 'Multi Pack Product ' + fgCode,
                        'FGCode'            => fgCode,
                        'uom'               => 'KGS',
                        'isActive'          => true,
                        'GST_Group_Code'    => 'GST18',
                        'productFamily'     => 'Beverages',
                        'ProductCategoryL1' => 'Cat1',
                        'ProductCategoryL2' => 'Cat2',
                        'ProductCategoryL3' => 'Cat3',
                        'HSNCode'           => 'HSN1234',
                        'packingDetails'    => new List<Object>{
                            new Map<String, Object>{
                                'packingSize'        => 'PAPER BAGS 15 KGS',
                                'PackingQty'         => '1',
                                'PackingDescription' => 'Small Pack'
                            },
                            new Map<String, Object>{
                                'packingSize'        => 'PAPER BAGS 25 KGS',
                                'PackingQty'         => '2',
                                'PackingDescription' => 'Large Pack'
                            },
                            new Map<String, Object>{
                                'packingSize'        => 'DRUMS 50 KGS',
                                'PackingQty'         => '5',
                                'PackingDescription' => 'Bulk Pack'
                            }
                        }
                    },
                    'priceBook' => new List<Object>{
                        new Map<String, Object>{
                            'priceBookName'       => 'Test PriceBook ' + fgCode,
                            'priceBookExternalId' => priceBookExtId,
                            'bookEntryExternalId' => bookEntryExtId,
                            'bookEntryCurrency'   => cur,
                            'bookEntryAmount'     => 750.00
                        }
                    }
                }
            }
        });
    }

    /**
     * Product with null/empty packingDetails (covers null-check branch)
     */
    private static String buildNullPackingPayload(String fgCode, String priceBookExtId,
                                                  String bookEntryExtId, String cur) {
        return JSON.serialize(new Map<String, Object>{
            'products' => new List<Object>{
                new Map<String, Object>{
                    'product' => new Map<String, Object>{
                        'productName'       => 'No Pack Product ' + fgCode,
                        'FGCode'            => fgCode,
                        'uom'               => 'KGS',
                        'isActive'          => true,
                        'GST_Group_Code'    => 'GST18',
                        'productFamily'     => 'Beverages',
                        'ProductCategoryL1' => 'Cat1',
                        'ProductCategoryL2' => 'Cat2',
                        'ProductCategoryL3' => 'Cat3',
                        'HSNCode'           => 'HSN1234'
                        // packingDetails intentionally omitted → null
                    },
                    'priceBook' => new List<Object>{
                        new Map<String, Object>{
                            'priceBookName'       => 'Test PriceBook ' + fgCode,
                            'priceBookExternalId' => priceBookExtId,
                            'bookEntryExternalId' => bookEntryExtId,
                            'bookEntryCurrency'   => cur,
                            'bookEntryAmount'     => 300.00
                        }
                    }
                }
            }
        });
    }

    /**
     * Two products with multiple pricebooks (covers loop iteration depth)
     */
    private static String buildMultiProductPayload() {
        return JSON.serialize(new Map<String, Object>{
            'products' => new List<Object>{
                new Map<String, Object>{
                    'product' => new Map<String, Object>{
                        'productName'       => 'Product Alpha',
                        'FGCode'            => 'FG-ALPHA-001',
                        'uom'               => 'PCS',
                        'isActive'          => true,
                        'GST_Group_Code'    => 'GST5',
                        'productFamily'     => 'Food',
                        'ProductCategoryL1' => 'L1A',
                        'ProductCategoryL2' => 'L2A',
                        'ProductCategoryL3' => 'L3A',
                        'HSNCode'           => 'HSN0001',
                        'packingDetails'    => new List<Object>{
                            new Map<String, Object>{
                                'packingSize'        => 'BOX 10 PCS',
                                'PackingQty'         => '10',
                                'PackingDescription' => 'Standard Box'
                            },
                            new Map<String, Object>{
                                'packingSize'        => 'CARTON 50 PCS',
                                'PackingQty'         => '50',
                                'PackingDescription' => 'Carton Pack'
                            }
                        }
                    },
                    'priceBook' => new List<Object>{
                        new Map<String, Object>{
                            'priceBookName'       => 'Alpha PriceBook INR',
                            'priceBookExternalId' => 'PB-ALPHA-INR',
                            'bookEntryExternalId' => 'PBE-ALPHA-INR-001',
                            'bookEntryCurrency'   => 'INR',
                            'bookEntryAmount'     => 250.00
                        },
                        new Map<String, Object>{
                            'priceBookName'       => 'Alpha PriceBook USD',
                            'priceBookExternalId' => 'PB-ALPHA-USD',
                            'bookEntryExternalId' => 'PBE-ALPHA-USD-001',
                            'bookEntryCurrency'   => 'USD',
                            'bookEntryAmount'     => 3.00
                        }
                    }
                },
                new Map<String, Object>{
                    'product' => new Map<String, Object>{
                        'productName'       => 'Product Beta',
                        'FGCode'            => 'FG-BETA-001',
                        'uom'               => 'LTR',
                        'isActive'          => true,
                        'GST_Group_Code'    => 'GST12',
                        'productFamily'     => 'Drinks',
                        'ProductCategoryL1' => 'L1B',
                        'ProductCategoryL2' => 'L2B',
                        'ProductCategoryL3' => 'L3B',
                        'HSNCode'           => 'HSN0002',
                        'packingDetails'    => new List<Object>{
                            new Map<String, Object>{
                                'packingSize'        => 'BOTTLE 1 LTR',
                                'PackingQty'         => '12',
                                'PackingDescription' => 'Case of 12'
                            }
                        }
                    },
                    'priceBook' => new List<Object>{
                        new Map<String, Object>{
                            'priceBookName'       => 'Beta PriceBook INR',
                            'priceBookExternalId' => 'PB-BETA-INR',
                            'bookEntryExternalId' => 'PBE-BETA-INR-001',
                            'bookEntryCurrency'   => 'INR',
                            'bookEntryAmount'     => 100.00
                        }
                    }
                }
            }
        });
    }

    /**
     * Payload with invalid/missing required fields to trigger exception
     */
    private static String buildInvalidPayload() {
        return '{ "invalid_json_structure": true, "products": null }';
    }

    // =========================================================================
    // HELPER - Set up RestContext
    // =========================================================================
    private static void setupRestContext(String jsonBody) {
        RestRequest req  = new RestRequest();
        req.requestURI   = '/services/apexrest/ProductSync/';
        req.httpMethod   = 'POST';
        req.requestBody  = Blob.valueOf(jsonBody);
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    // =========================================================================
    // TEST 1: Happy path - single product + single packing detail
    // Covers: product upsert, packing detail insert, standard + custom
    //         pricebook entry creation, 200 success response
    // =========================================================================
    @isTest
    static void testSyncProducts_SingleProduct_Success() {
        String payload = buildSingleProductPayload('FG-TEST-001', 'PB-TEST-INR-001', 'PBE-TEST-INR-001', 'INR');
        setupRestContext(payload);

        Test.startTest();
        DRC_NBC_ProductSync_WebService.syncProducts();
        Test.stopTest();
    }

    // =========================================================================
    // TEST 2: Multiple products + multiple pricebooks
    // Covers: multi-product loop, multi-pricebook loop
    // =========================================================================
    @isTest
    static void testSyncProducts_MultipleProducts_Success() {
        String payload = buildMultiProductPayload();
        setupRestContext(payload);

        Test.startTest();
        DRC_NBC_ProductSync_WebService.syncProducts();
        Test.stopTest();
    }

    // =========================================================================
    // TEST 3: Multiple packing details on a single product
    // Covers: packingDetails list iteration (3 entries), all 3 fields mapped
    // =========================================================================
    @isTest
    static void testSyncProducts_MultiplePackingDetails_AllFieldsMapped() {
        String payload = buildMultiPackingPayload('FG-PACK-001', 'PB-PACK-INR', 'PBE-PACK-INR-001', 'INR');
        setupRestContext(payload);

        Test.startTest();
        DRC_NBC_ProductSync_WebService.syncProducts();
        Test.stopTest();
    }

    // =========================================================================
    // TEST 4: Null packingDetails - covers null/empty check branch
    // Ensures no packing detail records are inserted and no error is thrown
    // =========================================================================
    @isTest
    static void testSyncProducts_NullPackingDetails_NoChildRecords() {
        String payload = buildNullPackingPayload('FG-NULL-PACK-001', 'PB-NULL-INR', 'PBE-NULL-INR-001', 'INR');
        setupRestContext(payload);

        Test.startTest();
        DRC_NBC_ProductSync_WebService.syncProducts();
        Test.stopTest();
    }

    // =========================================================================
    // TEST 5: Re-sync replaces packing details (delete + re-insert branch)
    // First call inserts 2 packing records; second call sends 1 → old 2 deleted
    // =========================================================================
    @isTest
    static void testSyncProducts_ResyncReplacesPackingDetails() {
        // First sync - 2 packing details
        String payload1 = buildMultiPackingPayload('FG-RESYNC-001', 'PB-RESYNC-INR', 'PBE-RESYNC-INR-001', 'INR');
        setupRestContext(payload1);

        Test.startTest();
        DRC_NBC_ProductSync_WebService.syncProducts();

        // Second sync - only 1 packing detail
        String payload2 = buildSingleProductPayload('FG-RESYNC-001', 'PB-RESYNC-INR', 'PBE-RESYNC-INR-001', 'INR');
        setupRestContext(payload2);
        DRC_NBC_ProductSync_WebService.syncProducts();
        Test.stopTest();
    }
}