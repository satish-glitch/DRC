public class DRC_NBC_Shipping_BC_Integration_SOAP {
    
    private static final String ENDPOINT = 'https://salesforceuat.drcresins.com:2023/DR_LiveSSL/WS/D.R.%20Coats%20live/Page/CustomerShiptoAddressSalesForce';
    private static final String NS_ENVELOPE = 'http://schemas.xmlsoap.org/soap/envelope/';
    private static final String NS_PAGE     = 'urn:microsoft-dynamics-schemas/page/customershiptoaddresssalesforce';

    private static final String BC_USERNAME = 'Salesforce';
    private static final String BC_PASSWORD = 'Admin@2026';

    private static String lastCalloutExceptionMessage;
    private static String lastCalloutExceptionStack;

    private class PendingApiLog {
        String className;
        String requestBody;
        String responseBody;
        String methodName;
        String message;
        Integer statusCode;
        String stackTrace;
        String logType;
        Id relatedRecordId;

        PendingApiLog(
            String className,
            String requestBody,
            String responseBody,
            String methodName,
            String message,
            Integer statusCode,
            String stackTrace,
            String logType,
            Id relatedRecordId
        ) {
            this.className = className;
            this.requestBody = requestBody;
            this.responseBody = responseBody;
            this.methodName = methodName;
            this.message = message;
            this.statusCode = statusCode;
            this.stackTrace = stackTrace;
            this.logType = logType;
            this.relatedRecordId = relatedRecordId;
        }
    }

    private static List<PendingApiLog> pendingLogs = new List<PendingApiLog>();
    
    @AuraEnabled
    public static String syncByAddressId(Id addressId) {
        pendingLogs.clear();

        try {
            DRC_NBC_Integration_Payload.ShipToPayload payload = buildPayloadFromAddress(addressId);

            if (payload == null) {
                return 'FAILURE: No shipping address found for the given Address Id.';
            }

            String result = upsertShipToInternal(payload);
            flushApiLogs();
            return result;

        } catch (Exception e) {
            queueApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',
                null,
                null,
                'syncByAddressId',
                e.getMessage(),
                null,
                e.getStackTraceString(),
                'Error',
                addressId
            );

            flushApiLogs();
            return 'FAILURE: ' + e.getMessage();
        }
    }
    
    public static DRC_NBC_Integration_Payload.ShipToPayload buildPayloadFromAddress(Id addressId) {
        List<DRC_NBC_Addresses__c> addrList = [
            SELECT Id,
                   DRC_NBC_Address__Street__s,
                   DRC_NBC_Address__City__s,
                   DRC_NBC_Address__CountryCode__s,
                   DRC_NBC_Address__PostalCode__s,
                   DRC_NBC_Address__StateCode__s,
                   DRC_NBC_GST_Number__c,
                   DRC_Inco_Term__c,
                   DRC_NBC_Warehouse__c,
                   DRC_NBC_Type__c,
                   DRC_NBC_Ship_To_Code__c,
                   DRC_Shipping_Gst_Customer_Type__c,
                   DRC_NBC_Account__c,
                   DRC_NBC_Account__r.Name,
                   DRC_NBC_Account__r.Phone,
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
        
        DRC_NBC_Integration_Payload.ShipToPayload payload =
            new DRC_NBC_Integration_Payload.ShipToPayload();

        payload.CustomerNo = addr.DRC_NBC_Account__r.DRC_NBC_Customer_Number__c;
        payload.ShiptoCode = addr.DRC_NBC_Ship_To_Code__c;
        payload.Name       = addr.DRC_NBC_Account__r.Name;
        
        String street = addr.DRC_NBC_Address__Street__s;

        if (!String.isBlank(street)) {
            if (street.length() > 100) {
                payload.ShippingAddress = street.substring(0, 99);
                payload.ShippingAddress2 = street.length() > 149
                    ? street.substring(99, 149)
                    : street.substring(99);
            } else {
                payload.ShippingAddress = street;
                payload.ShippingAddress2 = '';
            }
        } else {
            payload.ShippingAddress = '';
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
        
        List<Warehouse_Location_Code__mdt> wMeta = [
            SELECT DRC_NBC_Code__c
            FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel = :addr.DRC_NBC_Warehouse__c
            AND DRC_NBC_Type__c = 'Warehouse Location'
            LIMIT 1
        ];

        payload.Location_Code = !wMeta.isEmpty() ? wMeta[0].DRC_NBC_Code__c : null;
        
        List<Warehouse_Location_Code__mdt> iTerm = [
            SELECT DRC_NBC_Code__c
            FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel = :addr.DRC_Inco_Term__c
            AND DRC_NBC_Type__c = 'Inco Terms'
            LIMIT 1
        ];

        payload.Shipment_Method_Code = !iTerm.isEmpty() ? iTerm[0].DRC_NBC_Code__c : null;
        
        return payload;
    }
    
    public static String upsertShipTo(DRC_NBC_Integration_Payload.ShipToPayload payload) {
        pendingLogs.clear();

        try {
            String result = upsertShipToInternal(payload);
            flushApiLogs();
            return result;

        } catch (Exception e) {
            queueApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',
                null,
                null,
                'upsertShipTo',
                e.getMessage(),
                null,
                e.getStackTraceString(),
                'Error',
                null
            );

            flushApiLogs();
            return 'FAILURE: ' + e.getMessage();
        }
    }

    private static String upsertShipToInternal(DRC_NBC_Integration_Payload.ShipToPayload payload) {
        System.debug('upsertShipToInternal: Before Read');

        String bcKey = readShipToKeyInternal(payload.CustomerNo, payload.ShiptoCode);

        System.debug('upsertShipToInternal: After Read. bcKey = ' + bcKey);
        System.debug('upsertShipToInternal: Before Update');

        return updateShipToInternal(payload, bcKey);
    }
    
    public static String readShipToKey(String customerNo, String shipToCode) {
        pendingLogs.clear();

        try {
            String key = readShipToKeyInternal(customerNo, shipToCode);
            flushApiLogs();
            return key;

        } catch (Exception e) {
            queueApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',null,null,'readShipToKey',e.getMessage(),null,e.getStackTraceString(),'Error',null
            );

            flushApiLogs();
            return null;
        }
    }

    private static String readShipToKeyInternal(String customerNo, String shipToCode) {
        String reqBody = buildReadEnvelope(customerNo, shipToCode);
        HttpResponse res = sendSoap(reqBody, 'Read');
        
        if (res == null) {
            queueApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',reqBody,null,'Read',String.isBlank(lastCalloutExceptionMessage)? 'No response received from BC.': lastCalloutExceptionMessage,null,lastCalloutExceptionStack,'Error',null
            );

            return null;
        }

        Integer statusCode = res.getStatusCode();

        queueApiLog(
            'DRC_NBC_Shipping_BC_Integration_SOAP',
            reqBody,
            res.getBody(),
            'Read',
            null,
            statusCode,
            null,
            statusCode == 200 || statusCode == 201 ? 'Success' : 'Error',
            null
        );

        if (statusCode != 200) {
            System.debug('Read returned non-200: ' + statusCode);
            return null;
        }

        try {
            Dom.Document doc = res.getBodyDocument();
            Dom.XmlNode root = doc.getRootElement();

            Dom.XmlNode body = getChildElementSafe(root, 'Body', NS_ENVELOPE);
            if (body == null) {
                System.debug('Read response: Body node not found.');
                return null;
            }
            
            Dom.XmlNode readRes = getChildElementSafe(body, 'Read_Result', NS_PAGE);
            if (readRes == null) {
                System.debug('Read response: Read_Result node not found.');
                return null;
            }
            
            Dom.XmlNode record = getChildElementSafe(
                readRes,
                'CustomerShiptoAddressSalesForce',
                NS_PAGE
            );

            if (record == null) {
                System.debug('Read response: CustomerShiptoAddressSalesForce node not found.');
                return null;
            }
            
            Dom.XmlNode keyNode = getChildElementSafe(record, 'Key', NS_PAGE);

            return keyNode != null ? keyNode.getText() : null;

        } catch (Exception e) {
            System.debug('Read XML parse failed: ' + e.getMessage());

            queueApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',
                reqBody,
                res.getBody(),
                'Read Parse',
                e.getMessage(),
                statusCode,
                e.getStackTraceString(),
                'Error',
                null
            );

            return null;
        }
    }
    
    public static String updateShipTo(DRC_NBC_Integration_Payload.ShipToPayload payload, String bcKey) {
        pendingLogs.clear();

        try {
            String result = updateShipToInternal(payload, bcKey);
            flushApiLogs();
            return result;

        } catch (Exception e) {
            queueApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',
                null,
                null,
                'updateShipTo',
                e.getMessage(),
                null,
                e.getStackTraceString(),
                'Error',
                null
            );

            flushApiLogs();
            return 'FAILURE: ' + e.getMessage();
        }
    }

    private static String updateShipToInternal(DRC_NBC_Integration_Payload.ShipToPayload payload, String bcKey) {
        String reqBody = buildUpdateEnvelope(payload, bcKey);
        HttpResponse res = sendSoap(reqBody, 'Update');
        
        if (res == null) {
            queueApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',
                reqBody,
                null,
                'Update',
                String.isBlank(lastCalloutExceptionMessage)
                    ? 'No response received from BC.'
                    : lastCalloutExceptionMessage,
                null,
                lastCalloutExceptionStack,
                'Error',
                null
            );

            return 'FAILURE: No response received from BC.';
        }
        
        Integer statusCode = res.getStatusCode();

        if (statusCode == 200 || statusCode == 201) {
            queueApiLog(
                'DRC_NBC_Shipping_BC_Integration_SOAP',
                reqBody,
                res.getBody(),
                'Update',
                null,
                statusCode,
                null,
                'Success',
                null
            );

            return 'SUCCESS: Shipping address synced to BC for Customer '
                + payload.CustomerNo
                + ', ShipToCode '
                + payload.ShiptoCode
                + '.';
        }
        
        String faultMsg = parseSoapFault(res.getBody());

        queueApiLog(
            'DRC_NBC_Shipping_BC_Integration_SOAP',
            reqBody,
            res.getBody(),
            'Update',
            faultMsg,
            statusCode,
            null,
            'Error',
            null
        );

        return 'FAILURE: ' + faultMsg;
    }
    
    private static String buildReadEnvelope(String customerNo, String shipToCode) {
        return '<?xml version="1.0" encoding="utf-8"?>'
            + '<s:Envelope xmlns:s="' + NS_ENVELOPE + '">'
            +   '<s:Header>'
            +     '<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">'
            +       '<wsse:UsernameToken>'
            +         '<wsse:Username>' + escapeXml(BC_USERNAME) + '</wsse:Username>'
            +         '<wsse:Password>' + escapeXml(BC_PASSWORD) + '</wsse:Password>'
            +       '</wsse:UsernameToken>'
            +     '</wsse:Security>'
            +   '</s:Header>'
            +   '<s:Body>'
            +     '<Read xmlns="' + NS_PAGE + '">'
            +       '<CustomerNo>' + escapeXml(customerNo) + '</CustomerNo>'
            +       '<ShiptoCode>' + escapeXml(shipToCode) + '</ShiptoCode>'
            +     '</Read>'
            +   '</s:Body>'
            + '</s:Envelope>';
    }
    
    private static String buildUpdateEnvelope(DRC_NBC_Integration_Payload.ShipToPayload p, String bcKey) {
        return '<?xml version="1.0" encoding="utf-8"?>'
            + '<s:Envelope xmlns:s="' + NS_ENVELOPE + '">'
            +   '<s:Header>'
            +     '<wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">'
            +       '<wsse:UsernameToken>'
            +         '<wsse:Username>' + escapeXml(BC_USERNAME) + '</wsse:Username>'
            +         '<wsse:Password>' + escapeXml(BC_PASSWORD) + '</wsse:Password>'
            +       '</wsse:UsernameToken>'
            +     '</wsse:Security>'
            +   '</s:Header>'
            +   '<s:Body>'
            +     '<Update xmlns="' + NS_PAGE + '">'
            +       '<CustomerShiptoAddressSalesForce>'
            +         xmlTag('Key', bcKey)
            +         xmlTag('CustomerNo', p.CustomerNo)
            +         xmlTag('ShiptoCode', p.ShiptoCode)
            +         xmlTag('Name', p.Name)
            +         xmlTag('ShippingAddress', p.ShippingAddress)
            +         xmlTag('ShippingAddress2', p.ShippingAddress2)
            +         xmlTag('ShippingCity', p.ShippingCity)
            +         xmlTag('ShippingPostCode', p.ShippingPostCode)
            +         xmlTag('ShippingCountry', p.ShippingCountry)
            +         xmlTag('ShippingPhoneNo', p.ShippingPhoneNo)
            +         xmlTag('ShippingEmail', p.ShippingEmail)
            +         xmlTag('State', p.State)
            +         xmlTag('Ship_to_GST_Customer_Type', p.Ship_to_GST_Customer_Type)
            +         xmlTag('ShippingGSTRegistrationNo', p.ShippingGSTRegistrationNo)
            +         xmlTag('Shipment_Method_Code', p.Shipment_Method_Code)
            +         xmlTag('Location_Code', p.Location_Code)
            +       '</CustomerShiptoAddressSalesForce>'
            +     '</Update>'
            +   '</s:Body>'
            + '</s:Envelope>';
    }
    
    private static HttpResponse sendSoap(String body, String action) {
        lastCalloutExceptionMessage = null;
        lastCalloutExceptionStack = null;

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', action);
            
            String encodedCredentials = EncodingUtil.base64Encode(
                Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD)
            );

            req.setHeader('Authorization', 'Basic ' + encodedCredentials);
            req.setBody(body);
            req.setTimeout(120000);
            
            Http http = new Http();
            return http.send(req);
            
        } catch (Exception e) {
            System.debug('sendSoap callout exception [' + action + ']: ' + e.getMessage());

            lastCalloutExceptionMessage = e.getMessage();
            lastCalloutExceptionStack = e.getStackTraceString();

            return null;
        }
    }
    
    private static String xmlTag(String tag, String value) {
        if (String.isBlank(value)) {
            return '<' + tag + '/>';
        }

        return '<' + tag + '>' + escapeXml(value) + '</' + tag + '>';
    }
    
    private static String escapeXml(String s) {
        if (s == null) {
            return '';
        }

        return s.replace('&', '&amp;')
                .replace('<', '&lt;')
                .replace('>', '&gt;')
                .replace('"', '&quot;')
                .replace('\'', '&apos;');
    }
    
    private static String parseSoapFault(String responseBody) {
        if (String.isBlank(responseBody)) {
            return 'Unknown error: Empty response body.';
        }

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(responseBody);

            Dom.XmlNode root = doc.getRootElement();

            Dom.XmlNode body = getChildElementSafe(root, 'Body', NS_ENVELOPE);
            if (body == null) {
                return 'Unknown error (no Body).';
            }

            Dom.XmlNode fault = getChildElementSafe(body, 'Fault', NS_ENVELOPE);
            if (fault == null) {
                return 'HTTP error — ' + responseBody.left(200);
            }

            Dom.XmlNode faultString = getChildElementSafe(fault, 'faultstring', null);

            if (faultString != null) {
                return faultString.getText();
            }

            Dom.XmlNode reason = getChildElementSafe(fault, 'Reason', NS_ENVELOPE);
            if (reason != null) {
                Dom.XmlNode textNode = getChildElementSafe(reason, 'Text', NS_ENVELOPE);
                if (textNode != null) {
                    return textNode.getText();
                }

                String reasonText = reason.getText();
                if (!String.isBlank(reasonText)) {
                    return reasonText;
                }
            }

            return responseBody.left(200);

        } catch (Exception e) {
            return responseBody.left(200);
        }
    }

    private static Dom.XmlNode getChildElementSafe(
        Dom.XmlNode parent,
        String childName,
        String namespaceValue
    ) {
        if (parent == null) {
            return null;
        }

        Dom.XmlNode child;

        if (namespaceValue != null) {
            child = parent.getChildElement(childName, namespaceValue);
            if (child != null) {
                return child;
            }
        }

        child = parent.getChildElement(childName, null);
        if (child != null) {
            return child;
        }

        child = parent.getChildElement(childName, NS_ENVELOPE);
        if (child != null) {
            return child;
        }

        child = parent.getChildElement(childName, NS_PAGE);
        if (child != null) {
            return child;
        }

        return null;
    }

    private static void queueApiLog(
        String className,
        String requestBody,
        String responseBody,
        String methodName,
        String message,
        Integer statusCode,
        String stackTrace,
        String logType,
        Id relatedRecordId
    ) {
        pendingLogs.add(new PendingApiLog(
            className,
            requestBody,
            responseBody,
            methodName,
            message,
            statusCode,
            stackTrace,
            logType,
            relatedRecordId
        ));
    }

    private static void flushApiLogs() {
        if (pendingLogs.isEmpty()) {
            return;
        }

        List<PendingApiLog> logsToInsert = new List<PendingApiLog>();
        logsToInsert.addAll(pendingLogs);
        pendingLogs.clear();

        for (PendingApiLog logItem : logsToInsert) {
            try {
                DRC_NBC_API_Log_Handler.createApiLog(
                    logItem.className,
                    logItem.requestBody,
                    logItem.responseBody,
                    logItem.methodName,
                    logItem.message,
                    logItem.statusCode,
                    logItem.stackTrace,
                    logItem.logType,
                    logItem.relatedRecordId
                );
            } catch (Exception logEx) {
                System.debug(
                    'API log creation failed for '
                    + logItem.methodName
                    + ': '
                    + logEx.getMessage()
                );
            }
        }
    }
}