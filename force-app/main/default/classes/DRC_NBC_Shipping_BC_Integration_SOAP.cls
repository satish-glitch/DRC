public class DRC_NBC_Shipping_BC_Integration_SOAP {
    
    private static final String ENDPOINT = 
        'https://salesforceuat.drcresins.com:2023/DR_LiveSSL/WS/D.R.%20Coats%20live/Page/CustomerShiptoAddressSalesForce';
    private static final String NS_ENVELOPE = 'http://schemas.xmlsoap.org/soap/envelope/';
    private static final String NS_PAGE     = 'urn:microsoft-dynamics-schemas/page/customershiptoaddresssalesforce';
    private static final String BC_USERNAME = 'Salesforce';
    private static final String BC_PASSWORD = 'Admin@2026';
    
    // ─────────────────────────────────────────────────────────────────────────
    // ENTRY POINT FROM BUTTON — accepts only Address Id
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static String syncByAddressId(Id addressId) {
        try {
            DRC_NBC_Integration_Payload.ShipToPayload payload = buildPayloadFromAddress(addressId);
            if (payload == null) {
                return 'FAILURE: No shipping address found for the given Address Id.';
            }
            return upsertShipTo(payload);
        } catch (Exception e) {
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',
                null, null, 'syncByAddressId',
                e.getMessage(), null, e.getStackTraceString(),
                'Error', addressId
            );
            return 'FAILURE: ' + e.getMessage();
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // BUILD PAYLOAD FROM ADDRESS ID
    // ─────────────────────────────────────────────────────────────────────────
    public static DRC_NBC_Integration_Payload.ShipToPayload buildPayloadFromAddress(Id addressId) {
        List<DRC_NBC_Addresses__c> addrList = [
            SELECT Id,
                   DRC_NBC_Address__Street__s, DRC_NBC_Address__City__s,
                   DRC_NBC_Address__CountryCode__s, DRC_NBC_Address__PostalCode__s,
                   DRC_NBC_Address__StateCode__s, DRC_NBC_GST_Number__c,
                   DRC_Inco_Term__c, DRC_NBC_Warehouse__c, DRC_NBC_Type__c,
                   DRC_NBC_Ship_To_Code__c, DRC_Shipping_Gst_Customer_Type__c,
                   DRC_NBC_Account__c,
                   DRC_NBC_Account__r.Name, DRC_NBC_Account__r.Phone,
                   DRC_NBC_Account__r.DRC_NBC_Customer_Number__c
            FROM DRC_NBC_Addresses__c
            WHERE Id = :addressId
            AND DRC_NBC_Type__c = 'Shipping'
            LIMIT 1
        ];
        
        if (addrList.isEmpty()) {
            System.debug('buildPayloadFromAddress: No Shipping address found for Id ' + addressId);
            return null;
        }
        
        DRC_NBC_Addresses__c addr = addrList[0];
        
        DRC_NBC_Integration_Payload.ShipToPayload payload = new DRC_NBC_Integration_Payload.ShipToPayload();
        payload.CustomerNo  = addr.DRC_NBC_Account__r.DRC_NBC_Customer_Number__c;
        payload.ShiptoCode  = addr.DRC_NBC_Ship_To_Code__c;
        payload.Name        = addr.DRC_NBC_Account__r.Name;
        
        // Address split (100 char limit per field)
        String street = addr.DRC_NBC_Address__Street__s;
        if (!String.isBlank(street)) {
            if (street.length() > 100) {
                payload.ShippingAddress  = street.substring(0, 99);
                payload.ShippingAddress2 = street.length() > 149
                    ? street.substring(99, 149)
                    : street.substring(99);
            } else {
                payload.ShippingAddress  = street;
                payload.ShippingAddress2 = '';
            }
        } else {
            payload.ShippingAddress  = '';
            payload.ShippingAddress2 = '';
        }
        
        payload.ShippingCity              = addr.DRC_NBC_Address__City__s;
        payload.State                     = addr.DRC_NBC_Address__StateCode__s;
        payload.ShippingPostCode          = addr.DRC_NBC_Address__PostalCode__s;
        payload.ShippingCountry           = addr.DRC_NBC_Address__CountryCode__s == 'IN'
                                                ? 'IND'
                                                : addr.DRC_NBC_Address__CountryCode__s;
        payload.ShippingPhoneNo           = addr.DRC_NBC_Account__r.Phone;
        payload.ShippingGSTRegistrationNo = addr.DRC_NBC_GST_Number__c;
        payload.Ship_to_GST_Customer_Type = addr.DRC_Shipping_Gst_Customer_Type__c;
        
        // Warehouse → Location_Code
        List<Warehouse_Location_Code__mdt> wMeta = [
            SELECT DRC_NBC_Code__c
            FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel   = :addr.DRC_NBC_Warehouse__c
            AND DRC_NBC_Type__c = 'Warehouse Location'
            LIMIT 1
        ];
        payload.Location_Code = !wMeta.isEmpty() ? wMeta[0].DRC_NBC_Code__c : null;
        
        // Inco Terms → Shipment_Method_Code
        List<Warehouse_Location_Code__mdt> iTerm = [
            SELECT DRC_NBC_Code__c
            FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel   = :addr.DRC_Inco_Term__c
            AND DRC_NBC_Type__c = 'Inco Terms'
            LIMIT 1
        ];
        payload.Shipment_Method_Code = !iTerm.isEmpty() ? iTerm[0].DRC_NBC_Code__c : null;
        
        return payload;
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // ENTRY POINT FROM DRC_NBC_Shipping_BC_Callout.processShipping
    // ─────────────────────────────────────────────────────────────────────────
    public static String upsertShipTo(DRC_NBC_Integration_Payload.ShipToPayload payload) {
        try {
            String bcKey = readShipToKey(payload.CustomerNo, payload.ShiptoCode);
            return updateShipTo(payload, bcKey);
        } catch (Exception e) {
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',
                null, null, 'upsertShipTo',
                e.getMessage(), null, e.getStackTraceString(),
                'Error', null
            );
            return 'FAILURE: ' + e.getMessage();
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // READ — returns BC Key string, or null if not found
    // ─────────────────────────────────────────────────────────────────────────
    public static String readShipToKey(String customerNo, String shipToCode) {
        String reqBody = buildReadEnvelope(customerNo, shipToCode);
        HttpResponse res = sendSoap(reqBody, 'Read');
        
        if (res == null || res.getStatusCode() != 200) {
            System.debug('Read returned non-200: ' + (res != null ? String.valueOf(res.getStatusCode()) : 'NULL'));
            return null;
        }
        
        Dom.Document doc = res.getBodyDocument();
        Dom.XmlNode root = doc.getRootElement();
        Dom.XmlNode body = root.getChildElement('Body', NS_ENVELOPE);
        if (body == null) return null;
        
        Dom.XmlNode readRes = body.getChildElement('Read_Result', NS_PAGE);
        if (readRes == null) return null;
        
        Dom.XmlNode record = readRes.getChildElement('CustomerShiptoAddressSalesForce', NS_PAGE);
        if (record == null) return null;
        
        Dom.XmlNode keyNode = record.getChildElement('Key', NS_PAGE);
        return keyNode != null ? keyNode.getText() : null;
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // UPDATE — returns user-facing result message
    // ─────────────────────────────────────────────────────────────────────────
    public static String updateShipTo(DRC_NBC_Integration_Payload.ShipToPayload payload, String bcKey) {
        String reqBody = buildUpdateEnvelope(payload, bcKey);
        HttpResponse res = sendSoap(reqBody, 'Update');
        
        if (res == null) {
            return 'FAILURE: No response received from BC.';
        }
        
        Integer statusCode = res.getStatusCode();
        if (statusCode == 200 || statusCode == 201) {
            return 'SUCCESS: Shipping address synced to BC for Customer '
                + payload.CustomerNo + ', ShipToCode ' + payload.ShiptoCode + '.';
        }
        
        DRC_NBC_API_Log_Handler.createApiLog(
            'DRC_NBC_Shipping_BC_Integration_SOAP',
            reqBody, res.getBody(), 'Update',
            null, statusCode, null,
            'Error', null
        );
        return 'FAILURE: ';
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // ENVELOPE BUILDERS
    // ─────────────────────────────────────────────────────────────────────────
    private static String buildReadEnvelope(String customerNo, String shipToCode) {
        return '<?xml version="1.0" encoding="utf-8"?>'
            + '<Envelope xmlns="' + NS_ENVELOPE + '">'
            +   '<Header>'
            +     '<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">'
            +       '<wsse:UsernameToken>'
            +         '<wsse:Username>' + BC_USERNAME + '</wsse:Username>'
            +         '<wsse:Password>' + BC_PASSWORD + '</wsse:Password>'
            +       '</wsse:UsernameToken>'
            +     '</wsse:Security>'
            +   '</Header>'
            +   '<Body>'
            +     '<Read xmlns="' + NS_PAGE + '">'
            +       '<CustomerNo>' + escapeXml(customerNo) + '</CustomerNo>'
            +       '<ShiptoCode>' + escapeXml(shipToCode) + '</ShiptoCode>'
            +     '</Read>'
            +   '</Body>'
            + '</Envelope>';
    }
    
    private static String buildUpdateEnvelope(DRC_NBC_Integration_Payload.ShipToPayload p, String bcKey) {
        return '<?xml version="1.0" encoding="utf-8"?>'
            + '<Envelope xmlns="' + NS_ENVELOPE + '">'
            +   '<Header>'
            +     '<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">'
            +       '<wsse:UsernameToken>'
            +         '<wsse:Username>' + BC_USERNAME + '</wsse:Username>'
            +         '<wsse:Password>' + BC_PASSWORD + '</wsse:Password>'
            +       '</wsse:UsernameToken>'
            +     '</wsse:Security>'
            +   '</Header>'
            +   '<Body>'
            +     '<Update xmlns="' + NS_PAGE + '">'
            +       '<CustomerShiptoAddressSalesForce>'
            +         xmlTag('Key',                       bcKey)
            +         xmlTag('CustomerNo',                p.CustomerNo)
            +         xmlTag('ShiptoCode',                p.ShiptoCode)
            +         xmlTag('Name',                      p.Name)
            +         xmlTag('ShippingAddress',           p.ShippingAddress)
            +         xmlTag('ShippingAddress2',          p.ShippingAddress2)
            +         xmlTag('ShippingCity',              p.ShippingCity)
            +         xmlTag('ShippingPostCode',          p.ShippingPostCode)
            +         xmlTag('ShippingCountry',           p.ShippingCountry)
            +         xmlTag('ShippingPhoneNo',           p.ShippingPhoneNo)
            +         xmlTag('ShippingEmail',             p.ShippingEmail)
            +         xmlTag('State',                     p.State)
            +         xmlTag('Ship_to_GST_Customer_Type', p.Ship_to_GST_Customer_Type)
            +         xmlTag('ShippingGSTRegistrationNo', p.ShippingGSTRegistrationNo)
            +         xmlTag('Shipment_Method_Code',      p.Shipment_Method_Code)
            +         xmlTag('Location_Code',             p.Location_Code)
            +       '</CustomerShiptoAddressSalesForce>'
            +     '</Update>'
            +   '</Body>'
            + '</Envelope>';
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // HTTP HELPER
    // ─────────────────────────────────────────────────────────────────────────
    private static HttpResponse sendSoap(String body, String action) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', action);

            // Basic Auth header as additional fallback
            String credentials = BC_USERNAME + ':' + BC_PASSWORD;
            String encodedCredentials = EncodingUtil.base64Encode(Blob.valueOf(credentials));
            req.setHeader('Authorization', 'Basic ' + encodedCredentials);

            req.setBody(body);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',
                body, res.getBody(), action,
                null, res.getStatusCode(), null,
                'Success', null
            );
            
            return res;
            
        } catch (Exception e) {
            System.debug('sendSoap exception [' + action + ']: ' + e.getMessage());
            return null;
        }
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // XML UTILITIES
    // ─────────────────────────────────────────────────────────────────────────
    private static String xmlTag(String tag, String value) {
        if (String.isBlank(value)) {
            return '<' + tag + '/>';
        }
        return '<' + tag + '>' + escapeXml(value) + '</' + tag + '>';
    }
    
    private static String escapeXml(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;')
                .replace('<', '&lt;')
                .replace('>', '&gt;')
                .replace('"', '&quot;')
                .replace('\'', '&apos;');
    }
    
   
}