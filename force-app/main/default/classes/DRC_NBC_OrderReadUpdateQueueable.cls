public class DRC_NBC_OrderReadUpdateQueueable {
    
    private static DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();
    private static final String BC_ORDER_ENDPOINT    = bcSettings.DRC_NBC_BC_Order_Endpoint__c;
    private static final String SOAP_ORDER_NAMESPACE = bcSettings.DRC_NBC_SOAP_Order_Namespace__c;
    private static final String BC_USERNAME          = bcSettings.DRC_NBC_Username__c;
    private static final String BC_PASSWORD          = bcSettings.DRC_NBC_Password__c;
        
   
    public static void execute(Id orderRecordId) {
        
        DRC_NBC_BC_Integration__c s = DRC_NBC_BC_Integration__c.getInstance();
        String endpoint   = s.DRC_NBC_BC_Order_Endpoint__c;
        String namespace  = s.DRC_NBC_SOAP_Order_Namespace__c;
        String authHeader = 'Basic ' + EncodingUtil.base64Encode(
            Blob.valueOf(s.DRC_NBC_Username__c + ':' + s.DRC_NBC_Password__c)
        );
        
        // STEP 1 - Query order
        Order ord = [
            SELECT Id, DRC_NBC_Cust_Order_Number__c, EffectiveDate, PoNumber,
            ShipToContactId, DRC_NBC_Warehouse__c, DRC_NBC_Inco_Terms__c,
            DRC_NBC_Grand_Total__c, RecordType.Name, CurrencyIsoCode,
            Account.Name, Account.DRC_NBC_Customer_Number__c,Status, 
            Account.BillingStreet, Account.BillingPostalCode, Account.BillingCity
            FROM Order WHERE Id = :orderRecordId
        ];
        System.debug('BC Order No: ' + ord.DRC_NBC_Cust_Order_Number__c);
        
        // STEP 2 - Metadata lookups BEFORE callout
        String locationCode = '';
        if (String.isNotBlank(ord.DRC_NBC_Warehouse__c)) {
            List<Warehouse_Location_Code__mdt> rows = [
                SELECT DRC_NBC_Code__c FROM Warehouse_Location_Code__mdt
                WHERE MasterLabel = :ord.DRC_NBC_Warehouse__c
                AND DRC_NBC_Type__c = 'Warehouse Location' LIMIT 1
            ];
            if (!rows.isEmpty()) locationCode = rows[0].DRC_NBC_Code__c;
        }
        
        String incoTerms = '';
        if (String.isNotBlank(ord.DRC_NBC_Inco_Terms__c)) {
            List<Warehouse_Location_Code__mdt> rows = [
                SELECT DRC_NBC_Code__c FROM Warehouse_Location_Code__mdt
                WHERE MasterLabel = :ord.DRC_NBC_Inco_Terms__c
                AND DRC_NBC_Type__c = 'Inco Terms' LIMIT 1
            ];
            if (!rows.isEmpty()) incoTerms = rows[0].DRC_NBC_Code__c;
        }
        
        String orderDateStr  = ord.EffectiveDate != null ? String.valueOf(ord.EffectiveDate) : '';
        Decimal orderAmount  = ord.DRC_NBC_Grand_Total__c != null ? ord.DRC_NBC_Grand_Total__c : 0;
        Boolean isSample     = (ord.RecordType != null && ord.RecordType.Name == 'Sample_Order');
        
        System.debug('locationCode: ' + locationCode);
        System.debug('incoTerms   : ' + incoTerms);
        System.debug('orderAmount : ' + orderAmount);
        
        // STEP 3 - READ (callout starts here)
        HttpRequest readReq = new HttpRequest();
        readReq.setEndpoint(endpoint);
        readReq.setMethod('POST');
        readReq.setHeader('Content-Type', 'text/xml; charset=utf-8');
        readReq.setHeader('SOAPAction', namespace + ':Read');
        readReq.setHeader('Authorization', authHeader);
        readReq.setBody(
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><Read xmlns="' + namespace + '">' +
            '<Document_Type>Order</Document_Type>' +
            '<No>' + ord.DRC_NBC_Cust_Order_Number__c + '</No>' +
            '</Read></soap:Body></soap:Envelope>'
        );
        readReq.setTimeout(120000);
        
        HttpResponse readRes = new Http().send(readReq);
        System.debug('READ HTTP: ' + readRes.getStatusCode());
        
        // STEP 4 - Parse
        Map<String, String> bc = new Map<String, String>();
        Dom.Document doc = new Dom.Document();
        doc.load(readRes.getBody());
        Dom.XmlNode root = doc.getRootElement();
        for (Dom.XmlNode l1 : root.getChildElements()) {
            if (!l1.getName().containsIgnoreCase('Body')) continue;
            for (Dom.XmlNode l2 : l1.getChildElements()) {
                for (Dom.XmlNode l3 : l2.getChildElements()) {
                    if (!l3.getName().containsIgnoreCase('SalesOrderSalesForce')) continue;
                    for (Dom.XmlNode f : l3.getChildElements()) {
                        bc.put(f.getName(), f.getText());
                    }
                }
            }
        }
        System.debug('BC Status: ' + bc.get('Status'));
        System.debug('BC Key   : ' + bc.get('Key'));
        
        if (String.isBlank(locationCode)) locationCode = bc.get('Location_Code') != null ? bc.get('Location_Code') : '';
        if (String.isBlank(incoTerms))    incoTerms    = bc.get('Shipment_Method_Code') != null ? bc.get('Shipment_Method_Code') : '';
        if (String.isBlank(orderDateStr)) orderDateStr = bc.get('Order_Date') != null ? bc.get('Order_Date') : '';
        
        // STEP 5 - UPDATE immediately
        String updateBody =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body><Update xmlns="' + namespace + '">' +
            '<SalesOrderSalesForce>' +
            '<Key>'                         + bc.get('Key')                         + '</Key>' +
            '<Document_Type>'               + bc.get('Document_Type')               + '</Document_Type>' +
            '<No>'                          + bc.get('No')                          + '</No>' +
            '<Sell_to_Customer_No>'         + bc.get('Sell_to_Customer_No')         + '</Sell_to_Customer_No>' +
            '<Sell_to_Customer_Name>'       + bc.get('Sell_to_Customer_Name')       + '</Sell_to_Customer_Name>' +
            '<Sell_to_Address>'             + bc.get('Sell_to_Address')             + '</Sell_to_Address>' +
            '<Sell_to_Post_Code>'           + bc.get('Sell_to_Post_Code')           + '</Sell_to_Post_Code>' +
            '<Sell_to_City>'                + bc.get('Sell_to_City')                + '</Sell_to_City>' +
            '<Order_Date>'                  + orderDateStr                          + '</Order_Date>' +
            '<External_Document_No>'        + (ord.PoNumber != null ? ord.PoNumber : '') + '</External_Document_No>' +
            '<Salesperson_Code>'            + (ord.ShipToContactId != null ? String.valueOf(ord.ShipToContactId) : '') + '</Salesperson_Code>' +
            '<Status>Released</Status>' +
            '<Location_Code>'               + locationCode                          + '</Location_Code>' +
            '<Payment_Terms_Code>'          + bc.get('Payment_Terms_Code')          + '</Payment_Terms_Code>' +
            '<Shipment_Method_Code>'        + incoTerms                             + '</Shipment_Method_Code>' +
            '<Sample_Sales>'                + String.valueOf(isSample)              + '</Sample_Sales>' +
            '<Salesforce_So_No>'            + String.valueOf(ord.Id)                + '</Salesforce_So_No>' +
            '<Ship_to_Code>'                + bc.get('Ship_to_Code')                + '</Ship_to_Code>' +
            '<Ship_to_Name>'                + bc.get('Ship_to_Name')                + '</Ship_to_Name>' +
            '<Ship_to_Address>'             + bc.get('Ship_to_Address')             + '</Ship_to_Address>' +
            '<Ship_to_Country_Region_Code>' + bc.get('Ship_to_Country_Region_Code') + '</Ship_to_Country_Region_Code>' +
            '<Ship_to_Post_Code>'           + bc.get('Ship_to_Post_Code')           + '</Ship_to_Post_Code>' +
            '<Ship_to_GST_Customer_Type>'   + bc.get('Ship_to_GST_Customer_Type')   + '</Ship_to_GST_Customer_Type>' +
            '<Ship_to_GST_Reg_No>'          + bc.get('Ship_to_GST_Reg_No')          + '</Ship_to_GST_Reg_No>' +
            '<Salesforce_Order_Amount>'     + orderAmount                           + '</Salesforce_Order_Amount>' +
            '<Salesforce_Order_Created>false</Salesforce_Order_Created>' +
            '<Currency_Code>'               + bc.get('Currency_Code')               + '</Currency_Code>' +
            '</SalesOrderSalesForce>' +
            '</Update></soap:Body></soap:Envelope>';
        
        HttpRequest updateReq = new HttpRequest();
        updateReq.setEndpoint(endpoint);
        updateReq.setMethod('POST');
        updateReq.setHeader('Content-Type', 'text/xml; charset=utf-8');
        updateReq.setHeader('SOAPAction', namespace + ':Update');
        updateReq.setHeader('Authorization', authHeader);
        updateReq.setBody(updateBody);
        updateReq.setTimeout(120000);
        HttpResponse updateRes = new Http().send(updateReq);
        System.debug('UPDATE HTTP: ' + updateRes.getStatusCode());
        System.debug('UPDATE BODY: ' + updateRes.getBody());
        if(updateRes.getStatusCode() == 200) {
            ord.Status = 'Released';
        }
        
        Update ord;
 
    } 
}