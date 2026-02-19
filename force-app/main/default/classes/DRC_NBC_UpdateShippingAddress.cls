/**
* @File Name : DRC_NBC_UpdateShippingAddress.cls
* @Description : Reads and Updates Customer Ship-To Address in Business Central via SOAP
*                Called BEFORE updating Order Status in DRC_NBC_UpdateOrderAndLineItems.
*                - Reads existing Ship-To Address from BC using CustomerNo + ShipToCode
*                - Compares Location_Code
*                - Updates if Location_Code is different (or any field needs refresh)
* @Author : Satish YADAV
* @Last Modified On : February 19, 2026
**/
public class DRC_NBC_UpdateShippingAddress {

    // Custom Setting
    private static DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();

    // Endpoints and credentials
    private static final String BC_SHIP_TO_ENDPOINT  = bcSettings.DRC_NBC_BC_ShipTo_Endpoint__c;  // Add this field to Custom Setting
    private static final String SOAP_SHIP_TO_NS      = bcSettings.DRC_NBC_SOAP_Order_Namespace__c;
    private static final String BC_USERNAME           = bcSettings.DRC_NBC_Username__c;
    private static final String BC_PASSWORD           = bcSettings.DRC_NBC_Password__c;

    /**
    * Main entry point.
    * Call this from DRC_NBC_UpdateOrderAndLineItems.updateOrderInBC()
    * BEFORE the Status field is sent in the Update payload.
    *
    * @param orderId  Salesforce Order record Id
    * @return         Result string: 'SUCCESS', 'SKIPPED: ...', or 'ERROR: ...'
    */
    public static String syncShippingAddress(Id orderId) {
        System.debug('*** START: DRC_NBC_UpdateShippingAddress.syncShippingAddress ***');
        System.debug('Order Id: ' + orderId);

        try {
            // ----------------------------------------------------------------
            // Step 1: Query Order to get Shipping Address lookup Id
            // ----------------------------------------------------------------
            Order ord = [
                SELECT Id,
                       DRC_NBC_Shipping_Address__c,
                       Account.DRC_NBC_Customer_Number__c,
                       DRC_NBC_Warehouse__c
                FROM   Order
                WHERE  Id = :orderId
                LIMIT  1
            ];

            if (ord.DRC_NBC_Shipping_Address__c == null) {
                String msg = 'SKIPPED: No Shipping Address linked to Order.';
                System.debug(msg);
                return msg;
            }

            String customerNo  = ord.Account.DRC_NBC_Customer_Number__c;
            String warehouseLabel = ord.DRC_NBC_Warehouse__c;

            if (String.isBlank(customerNo)) {
                String msg = 'SKIPPED: Customer Number is blank on Account.';
                System.debug(msg);
                return msg;
            }

            // ----------------------------------------------------------------
            // Step 2: Query DRC_NBC_Addresses__c for shipping details
            // ----------------------------------------------------------------
            DRC_NBC_Addresses__c shipAddr = [
                SELECT Id,
                       Name,
                       DRC_NBC_Ship_To_Code__c,
                       DRC_NBC_Address__Street__s,
                       DRC_NBC_Address__City__s,
                       DRC_NBC_Address__PostalCode__s,
                       DRC_NBC_Address__CountryCode__s,
                       DRC_NBC_Address__StateCode__s,
                       DRC_NBC_GST_Number__c,
                       DRC_NBC_Warehouse__c
                FROM   DRC_NBC_Addresses__c
                WHERE  Id = :ord.DRC_NBC_Shipping_Address__c
                LIMIT  1
            ];

            String shipToCode = shipAddr.DRC_NBC_Ship_To_Code__c;
            if (String.isBlank(shipToCode)) {
                String msg = 'SKIPPED: Ship-To Code is blank on Shipping Address record.';
                System.debug(msg);
                return msg;
            }

            System.debug('CustomerNo: ' + customerNo + ' | ShipToCode: ' + shipToCode);

            // ----------------------------------------------------------------
            // Step 3: Resolve Location_Code from Warehouse metadata
            // ----------------------------------------------------------------
            String sfLocationCode = '';
            String resolvedWarehouse = String.isNotBlank(warehouseLabel)
                                        ? warehouseLabel
                                        : shipAddr.DRC_NBC_Warehouse__c;

            if (String.isNotBlank(resolvedWarehouse)) {
                List<Warehouse_Location_Code__mdt> metaList = [
                    SELECT DRC_NBC_Code__c
                    FROM   Warehouse_Location_Code__mdt
                    WHERE  MasterLabel     = :resolvedWarehouse
                    AND    DRC_NBC_Type__c = 'Warehouse Location'
                    LIMIT  1
                ];
                if (!metaList.isEmpty()) {
                    sfLocationCode = metaList[0].DRC_NBC_Code__c;
                }
            }

            System.debug('Resolved SF Location_Code: ' + sfLocationCode);

            // ----------------------------------------------------------------
            // Step 4: READ from BC to get Key + existing Location_Code
            // ----------------------------------------------------------------
            Map<String, String> bcReadResult = readShipToFromBC(customerNo, shipToCode);

            if (bcReadResult == null || !bcReadResult.containsKey('key')) {
                String msg = 'ERROR: Could not read Ship-To Address from BC.';
                System.debug(msg);
                return msg;
            }

            String bcKey              = bcReadResult.get('key');
            String bcLocationCode     = bcReadResult.get('locationCode');

            System.debug('BC Key: ' + bcKey);
            System.debug('BC Location_Code: ' + bcLocationCode);
            System.debug('SF Location_Code: ' + sfLocationCode);

            // ----------------------------------------------------------------
            // Step 5: Compare Location_Code - Update if different
            // ----------------------------------------------------------------
            if (bcLocationCode == sfLocationCode) {
                String msg = 'SKIPPED: Location_Code unchanged (' + bcLocationCode + '). No update needed.';
                System.debug(msg);
                return msg;
            }

            System.debug('Location_Code changed from [' + bcLocationCode + '] to [' + sfLocationCode + ']. Updating BC...');

            // ----------------------------------------------------------------
            // Step 6: Build payload and UPDATE in BC
            // ----------------------------------------------------------------
            String updateResult = updateShipToInBC(
                bcKey,
                customerNo,
                shipToCode,
                shipAddr,
                sfLocationCode
            );

            System.debug('BC Ship-To Update Result: ' + updateResult);
            return updateResult;

        } catch (Exception ex) {
            System.debug('*** EXCEPTION in syncShippingAddress: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            return 'ERROR: ' + ex.getMessage();
        }
    }

    // ========================================================================
    // READ Ship-To Address from BC
    // Returns Map with 'key', 'locationCode' (and other fields if needed)
    // ========================================================================
    private static Map<String, String> readShipToFromBC(String customerNo, String shipToCode) {
        System.debug('  *** READ Ship-To from BC ***');

        try {
            String requestBody = buildReadSOAPRequest(customerNo, shipToCode);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_SHIP_TO_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_SHIP_TO_NS + ':Read');

            String authHeader = 'Basic ' + EncodingUtil.base64Encode(
                                    Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD));
            req.setHeader('Authorization', authHeader);
            req.setBody(requestBody);
            req.setTimeout(120000);

            Http http = new Http();
            HttpResponse response = http.send(req);

            System.debug('  Read Response Status: ' + response.getStatusCode());

            if (response.getStatusCode() == 200) {
                return extractReadResponse(response.getBody());
            } else {
                System.debug('  Read Error Body: ' + response.getBody());
                return null;
            }

        } catch (Exception ex) {
            System.debug('  *** READ Exception: ' + ex.getMessage());
            return null;
        }
    }

    // ========================================================================
    // UPDATE Ship-To Address in BC
    // ========================================================================
    private static String updateShipToInBC(String bcKey,
                                           String customerNo,
                                           String shipToCode,
                                           DRC_NBC_Addresses__c shipAddr,
                                           String locationCode) {
        System.debug('  *** UPDATE Ship-To in BC ***');

        try {
            String requestBody = buildUpdateSOAPRequest(bcKey, customerNo, shipToCode, shipAddr, locationCode);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_SHIP_TO_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_SHIP_TO_NS + ':Update');

            String authHeader = 'Basic ' + EncodingUtil.base64Encode(
                                    Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD));
            req.setHeader('Authorization', authHeader);
            req.setBody(requestBody);
            req.setTimeout(120000);

            Http http = new Http();
            HttpResponse response = http.send(req);

            System.debug('  Update Response Status: ' + response.getStatusCode());

            if (response.getStatusCode() == 200) {
                System.debug('  Ship-To Address Updated Successfully in BC');
                return 'SUCCESS';
            } else {
                System.debug('  Update Error Body: ' + response.getBody());
                return 'FAILURE: HTTP ' + response.getStatusCode() + ' - ' + response.getBody();
            }

        } catch (Exception ex) {
            System.debug('  *** UPDATE Exception: ' + ex.getMessage());
            return 'ERROR: ' + ex.getMessage();
        }
    }

    // ========================================================================
    // SOAP REQUEST BUILDERS
    // ========================================================================

    private static String buildReadSOAPRequest(String customerNo, String shipToCode) {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read xmlns="' + SOAP_SHIP_TO_NS + '">' +
            '<CustomerNo>' + escapeXml(customerNo) + '</CustomerNo>' +
            '<ShiptoCode>' + escapeXml(shipToCode) + '</ShiptoCode>' +
            '</Read>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    private static String buildUpdateSOAPRequest(String bcKey,
                                                  String customerNo,
                                                  String shipToCode,
                                                  DRC_NBC_Addresses__c shipAddr,
                                                  String locationCode) {

        // Derive phone/email if available — extend field list on DRC_NBC_Addresses__c as needed
        String phone     = '';   // Add DRC_NBC_Phone__c to object if required
        String email     = '';   // Add DRC_NBC_Email__c to object if required
        String shipmentMethodCode = ''; // Add DRC_NBC_Shipment_Method_Code__c if required

        String street   = escapeXml(shipAddr.DRC_NBC_Address__Street__s);
        String city     = escapeXml(shipAddr.DRC_NBC_Address__City__s);
        String postCode = escapeXml(shipAddr.DRC_NBC_Address__PostalCode__s);
        String country  = escapeXml(shipAddr.DRC_NBC_Address__CountryCode__s);
        String state    = escapeXml(shipAddr.DRC_NBC_Address__StateCode__s);
        String gstNo    = escapeXml(shipAddr.DRC_NBC_GST_Number__c);
        String name     = escapeXml(shipAddr.Name);

        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Update xmlns="' + SOAP_SHIP_TO_NS + '">' +
            '<CustomerShiptoAddressSalesForce>' +
            '<Key>'                           + escapeXml(bcKey)      + '</Key>' +
            '<CustomerNo>'                    + escapeXml(customerNo) + '</CustomerNo>' +
            '<ShiptoCode>'                    + escapeXml(shipToCode) + '</ShiptoCode>' +
            '<Name>'                          + name                  + '</Name>' +
            '<ShippingAddress>'               + street                + '</ShippingAddress>' +
            '<ShippingAddress2></ShippingAddress2>' +
            '<ShippingCity>'                  + city                  + '</ShippingCity>' +
            '<ShippingPostCode>'              + postCode              + '</ShippingPostCode>' +
            '<ShippingCountry>'               + country               + '</ShippingCountry>' +
            '<ShippingPhoneNo>'               + phone                 + '</ShippingPhoneNo>' +
            '<ShippingEmail>'                 + email                 + '</ShippingEmail>' +
            '<State>'                         + state                 + '</State>' +
            '<ShippingGSTRegistrationNo>'     + gstNo                 + '</ShippingGSTRegistrationNo>' +
            '<Shipment_Method_Code>'          + shipmentMethodCode    + '</Shipment_Method_Code>' +
            '<Location_Code>'                 + escapeXml(locationCode) + '</Location_Code>' +
            '</CustomerShiptoAddressSalesForce>' +
            '</Update>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }

    // ========================================================================
    // RESPONSE PARSER - extracts Key and Location_Code from BC Read response
    // ========================================================================
    private static Map<String, String> extractReadResponse(String xmlResponse) {
        Map<String, String> result = new Map<String, String>();

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlResponse);
            Dom.XmlNode root = doc.getRootElement();

            for (Dom.XmlNode bodyNode : root.getChildElements()) {
                if (bodyNode.getName().contains('Body')) {
                    for (Dom.XmlNode resultNode : bodyNode.getChildElements()) {
                        if (resultNode.getName().contains('Read_Result')) {
                            for (Dom.XmlNode shipNode : resultNode.getChildElements()) {
                                if (shipNode.getName().contains('CustomerShiptoAddressSalesForce')) {
                                    for (Dom.XmlNode fieldNode : shipNode.getChildElements()) {
                                        String fieldName = fieldNode.getName();
                                        if (fieldName == 'Key') {
                                            result.put('key', fieldNode.getText());
                                        } else if (fieldName == 'Location_Code') {
                                            result.put('locationCode', fieldNode.getText());
                                        } else if (fieldName == 'CustomerNo') {
                                            result.put('customerNo', fieldNode.getText());
                                        } else if (fieldName == 'ShiptoCode') {
                                            result.put('shipToCode', fieldNode.getText());
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

        } catch (Exception ex) {
            System.debug('Exception parsing Read response: ' + ex.getMessage());
        }

        return result;
    }

    private static String escapeXml(String value) {
        if (String.isBlank(value)) return '';
        return value.escapeXml();
    }
}