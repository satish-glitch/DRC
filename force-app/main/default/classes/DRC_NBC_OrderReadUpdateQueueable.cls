public class DRC_NBC_OrderReadUpdateQueueable {

    // Custom setting (assumes Hierarchy/Custom Setting with getInstance())
    private static final DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();
    private static final String BC_ORDER_ENDPOINT    = bcSettings.DRC_NBC_BC_Order_Endpoint__c;
    private static final String SOAP_ORDER_NAMESPACE = bcSettings.DRC_NBC_SOAP_Order_Namespace__c;
    private static final String BC_USERNAME          = bcSettings.DRC_NBC_Username__c;
    private static final String BC_PASSWORD          = bcSettings.DRC_NBC_Password__c;

    public static void execute(Id orderRecordId) {

        if (orderRecordId == null) {
            System.debug(LoggingLevel.ERROR, 'Order Id is null.');
            return;
        }

        // --- STEP 1: Query Order safely (avoid "List has no rows...")
        List<Order> ordList = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, EffectiveDate, PoNumber,
                   ShipToContactId, DRC_NBC_Warehouse__c, DRC_NBC_Inco_Terms__c,
                   DRC_NBC_Grand_Total__c, RecordType.Name, CurrencyIsoCode,
                   Account.Name, Account.DRC_NBC_Customer_Number__c, Status,
                   Account.BillingStreet, Account.BillingPostalCode, Account.BillingCity
            FROM Order
            WHERE Id = :orderRecordId
            LIMIT 1
        ];
        if (ordList.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'No Order found for Id: ' + orderRecordId);
            return;
        }
        Order ord = ordList[0];

        if (String.isBlank(ord.DRC_NBC_Cust_Order_Number__c)) {
            System.debug(LoggingLevel.ERROR, 'Order has blank DRC_NBC_Cust_Order_Number__c. Order Id: ' + ord.Id);
            return;
        }

        // Auth header
        String authHeader = 'Basic ' + EncodingUtil.base64Encode(
            Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD)
        );

        // --- STEP 2: Metadata lookups BEFORE callout
        String locationCode = resolveMdtCode(ord.DRC_NBC_Warehouse__c, 'Warehouse Location');
        String incoTerms    = resolveMdtCode(ord.DRC_NBC_Inco_Terms__c, 'Inco Terms');

        String  orderDateStr = (ord.EffectiveDate != null) ? String.valueOf(ord.EffectiveDate) : ''; // yyyy-MM-dd
        Decimal orderAmount  = (ord.DRC_NBC_Grand_Total__c != null) ? ord.DRC_NBC_Grand_Total__c : 0;
        Boolean isSample     = (ord.RecordType != null && ord.RecordType.Name == 'Sample_Order');

        System.debug('BC Order No  : ' + ord.DRC_NBC_Cust_Order_Number__c);
        System.debug('locationCode : ' + locationCode);
        System.debug('incoTerms    : ' + incoTerms);
        System.debug('orderAmount  : ' + orderAmount);

        // --- STEP 3: READ
        String readBody =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
              '<soap:Body>' +
                '<Read xmlns="' + x(SOAP_ORDER_NAMESPACE) + '">' +
                  '<Document_Type>Order</Document_Type>' +
                  '<No>' + x(ord.DRC_NBC_Cust_Order_Number__c) + '</No>' +
                '</Read>' +
              '</soap:Body>' +
            '</soap:Envelope>';

        HttpResponse readRes = sendSoap('Read', readBody, authHeader);
        System.debug('READ HTTP: ' + readRes.getStatusCode());
        System.debug('READ BODY: ' + readRes.getBody());

        if (readRes.getStatusCode() != 200 || hasSoapFault(readRes.getBody())) {
            System.debug(LoggingLevel.ERROR, 'BC READ failed (or SOAP Fault). Not proceeding.');
            return;
        }

        // --- STEP 4: Parse READ response
        Map<String, String> bc = parseSalesOrderFields(readRes.getBody());
        System.debug('BC Status (READ): ' + bc.get('Status'));
        System.debug('BC Key           : ' + bc.get('Key'));

        if (String.isBlank(bc.get('Key')) || String.isBlank(bc.get('No'))) {
            System.debug(LoggingLevel.ERROR, 'READ did not return required fields (Key/No). Not proceeding.');
            return;
        }

        // Fill blanks from BC if Salesforce values missing
        if (String.isBlank(locationCode)) locationCode = (bc.get('Location_Code') != null) ? bc.get('Location_Code') : '';
        if (String.isBlank(incoTerms))    incoTerms    = (bc.get('Shipment_Method_Code') != null) ? bc.get('Shipment_Method_Code') : '';
        if (String.isBlank(orderDateStr)) orderDateStr = (bc.get('Order_Date') != null) ? bc.get('Order_Date') : '';

        // IMPORTANT:
        // Do NOT send Salesforce ContactId into BC Salesperson_Code (often Code[10] in BC).
        // Preserve BC value unless you have a proper mapping.
        String salespersonCode = (bc.get('Salesperson_Code') != null) ? bc.get('Salesperson_Code') : '';

        // --- STEP 5: UPDATE
        String updateBody =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
              '<soap:Body>' +
                '<Update xmlns="' + x(SOAP_ORDER_NAMESPACE) + '">' +
                  '<SalesOrderSalesForce>' +

                    // Required keys
                    '<Key>'           + x(bc.get('Key'))           + '</Key>' +
                    '<Document_Type>' + x(bc.get('Document_Type')) + '</Document_Type>' +
                    '<No>'            + x(bc.get('No'))            + '</No>' +

                    // Sell-to
                    '<Sell_to_Customer_No>'   + x(bc.get('Sell_to_Customer_No'))   + '</Sell_to_Customer_No>' +
                    '<Sell_to_Customer_Name>' + x(bc.get('Sell_to_Customer_Name')) + '</Sell_to_Customer_Name>' +
                    '<Sell_to_Address>'       + x(bc.get('Sell_to_Address'))       + '</Sell_to_Address>' +
                    '<Sell_to_Address_2>'     + x(bc.get('Sell_to_Address_2'))     + '</Sell_to_Address_2>' +
                    '<Sell_to_Post_Code>'     + x(bc.get('Sell_to_Post_Code'))     + '</Sell_to_Post_Code>' +
                    '<Sell_to_City>'          + x(bc.get('Sell_to_City'))          + '</Sell_to_City>' +

                    // Order
                    '<Order_Date>'            + x(orderDateStr) + '</Order_Date>' +
                    '<External_Document_No>'  + x(ord.PoNumber) + '</External_Document_No>' +
                    '<Salesperson_Code>'      + x(salespersonCode) + '</Salesperson_Code>' +

                    // Status (BC may ignore if not editable; at least you’ll see it in response/readback)
                    '<Status>Released</Status>' +

                    // Codes
                    '<Location_Code>'         + x(locationCode) + '</Location_Code>' +
                    '<Payment_Terms_Code>'    + x(bc.get('Payment_Terms_Code')) + '</Payment_Terms_Code>' +
                    '<Shipment_Method_Code>'  + x(incoTerms) + '</Shipment_Method_Code>' +

                    // Custom flags
                    '<Sample_Sales>'          + String.valueOf(isSample) + '</Sample_Sales>' +
                    '<Salesforce_So_No>'      + x(String.valueOf(ord.Id)) + '</Salesforce_So_No>' +

                    // Ship-to
                    '<Ship_to_Code>'                + x(bc.get('Ship_to_Code'))                + '</Ship_to_Code>' +
                    '<Ship_to_Name>'                + x(bc.get('Ship_to_Name'))                + '</Ship_to_Name>' +
                    '<Ship_to_Name_2>'              + x(bc.get('Ship_to_Name_2'))              + '</Ship_to_Name_2>' +
                    '<Ship_to_Address>'             + x(bc.get('Ship_to_Address'))             + '</Ship_to_Address>' +
                    '<Ship_to_Address_2>'           + x(bc.get('Ship_to_Address_2'))           + '</Ship_to_Address_2>' +
                    '<Ship_to_Country_Region_Code>' + x(bc.get('Ship_to_Country_Region_Code')) + '</Ship_to_Country_Region_Code>' +
                    '<Ship_to_Post_Code>'           + x(bc.get('Ship_to_Post_Code'))           + '</Ship_to_Post_Code>' +
                    '<Ship_to_GST_Customer_Type>'   + x(bc.get('Ship_to_GST_Customer_Type'))   + '</Ship_to_GST_Customer_Type>' +
                    '<Ship_to_GST_Reg_No>'          + x(bc.get('Ship_to_GST_Reg_No'))          + '</Ship_to_GST_Reg_No>' +

                    // Amount/Currency
                    '<Salesforce_Order_Amount>'     + String.valueOf(orderAmount) + '</Salesforce_Order_Amount>' +
                    '<Salesforce_Order_Created>false</Salesforce_Order_Created>' +
                    '<Currency_Code>'               + x(bc.get('Currency_Code')) + '</Currency_Code>' +

                  '</SalesOrderSalesForce>' +
                '</Update>' +
              '</soap:Body>' +
            '</soap:Envelope>';

        HttpResponse updateRes = sendSoap('Update', updateBody, authHeader);
        System.debug('UPDATE HTTP: ' + updateRes.getStatusCode());
        System.debug('UPDATE BODY: ' + updateRes.getBody());

        Boolean bcUpdateOk = (updateRes.getStatusCode() == 200 && !hasSoapFault(updateRes.getBody()));
        if (!bcUpdateOk) {
            System.debug(LoggingLevel.ERROR, 'BC UPDATE failed (or SOAP Fault). Not updating Salesforce Order status.');
            return;
        }

        // Optional: parse UPDATE response to see what BC returned as Status
        Map<String, String> bcAfter = parseSalesOrderFields(updateRes.getBody());
        if (!bcAfter.isEmpty()) {
            System.debug('BC Status (UPDATE response): ' + bcAfter.get('Status'));
        }

        // --- STEP 6: Update Salesforce Order status ONLY after BC success
        try {
            update new Order(
                Id = ord.Id,
                Status = 'Released'
            );
            System.debug('Salesforce Order updated to Status=Released. Order Id: ' + ord.Id);
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'Salesforce status update failed: ' + e.getDmlMessage(0));
        }
    }

    // ========== Helpers ==========

    private static HttpResponse sendSoap(String action, String body, String authHeader) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(BC_ORDER_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');

        // Many SOAP tools send SOAPAction in quotes; BC endpoints often like that too.
        req.setHeader('SOAPAction', '"' + SOAP_ORDER_NAMESPACE + ':' + action + '"');

        req.setHeader('Authorization', authHeader);
        req.setTimeout(120000);
        req.setBody(body);
        return new Http().send(req);
    }

    private static Boolean hasSoapFault(String body) {
        if (String.isBlank(body)) return false;
        return body.contains('<soap:Fault') || body.contains(':Fault') || body.contains('<Fault');
    }

    // Escapes XML special characters to prevent broken XML when values contain &, <, >, etc.
    private static String x(String v) {
        if (v == null) return '';
        return v.replace('&','&amp;')
                .replace('<','&lt;')
                .replace('>','&gt;')
                .replace('"','&quot;')
                .replace('\'','&apos;');
    }

    private static String resolveMdtCode(String label, String type) {
        if (String.isBlank(label)) return '';
        List<Warehouse_Location_Code__mdt> rows = [
            SELECT DRC_NBC_Code__c
            FROM Warehouse_Location_Code__mdt
            WHERE MasterLabel = :label
              AND DRC_NBC_Type__c = :type
            LIMIT 1
        ];
        return rows.isEmpty() ? '' : rows[0].DRC_NBC_Code__c;
    }

    // Finds the first node whose name contains a token (case-insensitive)
    private static Dom.XmlNode findNodeContains(Dom.XmlNode node, String tokenLower) {
        if (node == null) return null;
        String n = node.getName();
        if (n != null && n.toLowerCase().contains(tokenLower)) return node;

        for (Dom.XmlNode c : node.getChildElements()) {
            Dom.XmlNode found = findNodeContains(c, tokenLower);
            if (found != null) return found;
        }
        return null;
    }

    // Parses any SOAP response body that contains a SalesOrderSalesForce node
    private static Map<String, String> parseSalesOrderFields(String soapBody) {
        Map<String, String> out = new Map<String, String>();
        if (String.isBlank(soapBody)) return out;

        try {
            Dom.Document doc = new Dom.Document();
            doc.load(soapBody);

            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode soNode = findNodeContains(root, 'salesordersalesforce');
            if (soNode == null) return out;

            for (Dom.XmlNode f : soNode.getChildElements()) {
                out.put(f.getName(), f.getText());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'XML parse failed: ' + e.getMessage());
        }
        return out;
    }
}