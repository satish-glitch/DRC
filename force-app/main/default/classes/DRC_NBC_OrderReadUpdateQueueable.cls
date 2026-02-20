/**
* @File Name   : DRC_NBC_OrderReadUpdateQueueable.cls
* @Description : Queueable Apex class that:
*                1. READs the Sales Order from Business Central (fetches the BC Key)
*                2. UPDATEs the Sales Order in Business Central using the fetched Key
*                Both operations use SOAP API via DRC_NBC_BC_Integration__c custom setting.
* @Author      : SATISH YADAV
* @Last Modified On : February 11, 2026
**/
public class DRC_NBC_OrderReadUpdateQueueable implements Queueable, Database.AllowsCallouts {
    
    // -------------------------------------------------------------------------
    // Custom Setting & Endpoint Config
    // (mirrors the pattern from DRC_NBC_UpdateOrderAndLineItems)
    // -------------------------------------------------------------------------
    private static DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();
    
    private static final String BC_ORDER_ENDPOINT    = bcSettings.DRC_NBC_BC_Order_Endpoint__c;
    private static final String SOAP_ORDER_NAMESPACE = bcSettings.DRC_NBC_SOAP_Order_Namespace__c;
    private static final String BC_USERNAME          = bcSettings.DRC_NBC_Username__c;
    private static final String BC_PASSWORD          = bcSettings.DRC_NBC_Password__c;
    
    // -------------------------------------------------------------------------
    // Instance variable – the Salesforce Order Id to process
    // -------------------------------------------------------------------------
    private final Id orderRecordId;
    
    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    public DRC_NBC_OrderReadUpdateQueueable(Id orderRecordId) {
        this.orderRecordId = orderRecordId;
    }
    
    // =========================================================================
    // Queueable execute – called asynchronously
    // =========================================================================
    public void execute(QueueableContext context) {
        System.debug('*** DRC_NBC_OrderReadUpdateQueueable.execute START ***');
        System.debug('Order Record ID: ' + orderRecordId);
        
        try {
            // ----------------------------------------------------------------
            // STEP 1 – Query Salesforce Order (same query pattern as existing class)
            // ----------------------------------------------------------------
            Order ord = getOrderDetails(orderRecordId);
            System.debug('SF Order Number        : ' + ord.OrderNumber);
            System.debug('BC Cust Order Number   : ' + ord.DRC_NBC_Cust_Order_Number__c);
            System.debug('Customer Number        : ' + ord.Account.DRC_NBC_Customer_Number__c);
            
            // ----------------------------------------------------------------
            // STEP 2 – READ order from BC → get the Key
            // ----------------------------------------------------------------
            System.debug('--- STEP 2: READ order from BC ---');
            String bcKey = readOrderFromBC(ord.DRC_NBC_Cust_Order_Number__c);
            
            if (String.isBlank(bcKey)) {
                System.debug('ERROR: BC Key not found for order ' + ord.DRC_NBC_Cust_Order_Number__c);
                return;
            }
            System.debug('BC Key retrieved: ' + bcKey);
            
            // ----------------------------------------------------------------
            // STEP 3 – UPDATE order in BC using the Key
            // ----------------------------------------------------------------
            System.debug('--- STEP 3: UPDATE order in BC ---');
            String updateResult = updateOrderInBC(bcKey, ord);
            System.debug('Update Result: ' + updateResult);
            
        } catch (Exception ex) {
            System.debug('*** EXCEPTION in DRC_NBC_OrderReadUpdateQueueable.execute ***');
            System.debug('Type   : ' + ex.getTypeName());
            System.debug('Message: ' + ex.getMessage());
            System.debug('Line   : ' + ex.getLineNumber());
            System.debug('Stack  : ' + ex.getStackTraceString());
        }
        
        System.debug('*** DRC_NBC_OrderReadUpdateQueueable.execute END ***');
    }
    
    // =========================================================================
    // STEP 2 – READ Order from BC → returns the <Key> string
    // =========================================================================
    private String readOrderFromBC(String bcOrderNumber) {
        System.debug('  [READ] BC Order Number: ' + bcOrderNumber);
        
        try {
            // Build SOAP request
            String requestBody = buildReadSOAPRequest(bcOrderNumber);
            
            // Build HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_ORDER_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_ORDER_NAMESPACE + ':Read');
            req.setHeader('Authorization', buildBasicAuthHeader());
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            // Send
            HttpResponse res = new Http().send(req);
            System.debug('  [READ] Response Status: ' + res.getStatusCode());
            
            if (res.getStatusCode() == 200) {
                String key = extractKeyFromReadResponse(res.getBody());
                System.debug('  [READ] Extracted Key: ' + key);
                return key;
            } else {
                System.debug('  [READ] ERROR Body: ' + res.getBody());
                return null;
            }
            
        } catch (Exception ex) {
            System.debug('  [READ] Exception: ' + ex.getMessage());
            return null;
        }
    }
    
    // =========================================================================
    // STEP 3 – UPDATE Order in BC
    // =========================================================================
    private String updateOrderInBC(String bcKey, Order ord) {
        System.debug('  [UPDATE] BC Key: ' + bcKey);
        
        try {
            // Build SOAP request (payload built inline from Order fields)
            String requestBody = buildUpdateSOAPRequest(bcKey, ord);
            
            // Build HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BC_ORDER_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', SOAP_ORDER_NAMESPACE + ':Update');
            req.setHeader('Authorization', buildBasicAuthHeader());
            req.setBody(requestBody);
            req.setTimeout(120000);
            
            // Send
            HttpResponse res = new Http().send(req);
            System.debug('  [UPDATE] Response Status: ' + res.getStatusCode());
            
            if (res.getStatusCode() == 200) {
                System.debug('  [UPDATE] Order updated successfully in BC');
                updateOrderStatusToReleased(ord.Id);
                return 'SUCCESS';
            } else {
                System.debug('  [UPDATE] ERROR Body: ' + res.getBody());
                return 'FAILURE: HTTP ' + res.getStatusCode() + ' | ' + res.getBody();
            }
            
        } catch (Exception ex) {
            System.debug('  [UPDATE] Exception: ' + ex.getMessage());
            return 'ERROR: ' + ex.getMessage();
        }
    }
    
    // =========================================================================
    // SOAP REQUEST BUILDERS
    // =========================================================================
    
    /**
* Build the READ SOAP envelope.
* <No> is populated from DRC_NBC_Cust_Order_Number__c (e.g. "SODOM/2627/00031")
*/
    private String buildReadSOAPRequest(String bcOrderNumber) {
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Read xmlns="' + SOAP_ORDER_NAMESPACE + '">' +
            '<No>' + escapeXml(bcOrderNumber) + '</No>' +
            '</Read>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    
    private String buildUpdateSOAPRequest(String bcKey, Order ord) {
        
        // Derived fields
        Boolean isSampleOrder = (ord.RecordType != null && ord.RecordType.Name == 'Sample_Order');
        String  orderDateStr  = ord.EffectiveDate != null
            ? String.valueOf(ord.EffectiveDate)   // already YYYY-MM-DD
            : '';
        
        // Billing address from Account (Account.BillingStreet), split on newline
        String billingLine1 = '';
        String billingLine2 = '';
        if (String.isNotBlank(ord.Account?.BillingStreet)) {
            List<String> parts = ord.Account.BillingStreet.split('\n', 2);
            billingLine1 = parts[0].trim();
            billingLine2 = parts.size() > 1 ? parts[1].trim() : '';
        }
        
        // Safe field accessors – all mapped to the actual query fields
        String custNo        = safeStr(ord.Account?.DRC_NBC_Customer_Number__c);
        String custName      = safeStr(ord.Account?.Name);
        String billingPost   = safeStr(ord.Account?.BillingPostalCode);
        String billingCity   = safeStr(ord.Account?.BillingCity);
        String shipToCode    = safeStr(ord.DRC_NBC_Shipping_Address__r?.DRC_NBC_Ship_To_Code__c);
        String shipToName    = safeStr(ord.Account?.Name);          
        String shipToAddr    = safeStr(ord.ShippingStreet);          
        String shipToCountry = safeStr(ord.ShippingCountryCode);    
        String shipToPost    = safeStr(ord.ShippingPostalCode);      
        String payTerms      = safeStr(ord.DRC_NBC_Payment_Terms__c);
        String incoTerms     = safeStr(ord.DRC_NBC_Inco_Terms__c);  
        String poNumber      = safeStr(ord.PoNumber);                
        
        Decimal orderAmount  = ord.DRC_NBC_Grand_Total__c != null ? ord.DRC_NBC_Grand_Total__c : 0;
        
        return
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<soap:Body>' +
            '<Update xmlns="' + SOAP_ORDER_NAMESPACE + '">' +
            '<SalesOrderSalesForce>' +
            
            // ── Identity ──────────────────────────────────────────────
            '<Key>'                          + escapeXml(bcKey)                                     + '</Key>' +
            '<No>'                           + escapeXml(safeStr(ord.DRC_NBC_Cust_Order_Number__c)) + '</No>' +
            
            // ── Sell-To (Account billing address) ─────────────────────
            '<Sell_to_Customer_No>'          + escapeXml(custNo)                                    + '</Sell_to_Customer_No>' +
            '<Sell_to_Customer_Name>'        + escapeXml(custName)                                  + '</Sell_to_Customer_Name>' +
            '<Sell_to_Address>'              + escapeXml(billingLine1)                              + '</Sell_to_Address>' +
            '<Sell_to_Address_2>'            + escapeXml(billingLine2)                              + '</Sell_to_Address_2>' +
            '<Sell_to_Post_Code>'            + escapeXml(billingPost)                               + '</Sell_to_Post_Code>' +
            '<Sell_to_City>'                 + escapeXml(billingCity)                               + '</Sell_to_City>' +
            
            // ── Order Info ────────────────────────────────────────────
            '<Order_Date>'                   + escapeXml(orderDateStr)                              + '</Order_Date>' +
            '<External_Document_No>'         + escapeXml(poNumber)                                  + '</External_Document_No>' +
            '<Salesperson_Code>'             + escapeXml(safeStr(ord.ShipToContactId))                     + '</Salesperson_Code>' +
            '<Status>Released</Status>' +
            '<Location_Code>'                + escapeXml(ord.DRC_NBC_Warehouse__c)   + '</Location_Code>' +
            '<Payment_Terms_Code>'           + escapeXml(payTerms)                                  + '</Payment_Terms_Code>' +
            '<Shipment_Method_Code>'         + escapeXml(incoTerms)                                 + '</Shipment_Method_Code>' +
            '<Sample_Sales>'                 + isSampleOrder                                        + '</Sample_Sales>' +
            '<Salesforce_So_No>'             + escapeXml(String.valueOf(ord.Id))                   + '</Salesforce_So_No>' +
            
            // ── Ship-To (Order shipping address) ──────────────────────
            '<Ship_to_Code>'                 + escapeXml(shipToCode)                                + '</Ship_to_Code>' +
            '<Ship_to_Name>'                 + escapeXml(shipToName)                                + '</Ship_to_Name>' +
            '<Ship_to_Name_2>'               + ''                                                   + '</Ship_to_Name_2>' +
            '<Ship_to_Address>'              + escapeXml(shipToAddr)                                + '</Ship_to_Address>' +
            '<Ship_to_Address_2>'            + ''                                                   + '</Ship_to_Address_2>' +
            '<Ship_to_Country_Region_Code>'  + escapeXml(shipToCountry)                             + '</Ship_to_Country_Region_Code>' +
            '<Ship_to_Post_Code>'            + escapeXml(shipToPost)                                + '</Ship_to_Post_Code>' +
            '<Ship_to_GST_Customer_Type>'    + ''                                                   + '</Ship_to_GST_Customer_Type>' +
            '<Ship_to_GST_Reg_No>'           + ''                                                   + '</Ship_to_GST_Reg_No>' +
            
            // ── Financials & Flags ────────────────────────────────────
            '<Salesforce_Order_Amount>'      + orderAmount                                          + '</Salesforce_Order_Amount>' +
            '<Salesforce_Order_Created>false</Salesforce_Order_Created>' +
            '<Currency_Code>'                + escapeXml(safeStr(ord.CurrencyIsoCode))             + '</Currency_Code>' +
            
            '</SalesOrderSalesForce>' +
            '</Update>' +
            '</soap:Body>' +
            '</soap:Envelope>';
    }
    
    // =========================================================================
    // RESPONSE PARSER – extract <Key> from Read_Result
    // =========================================================================
    private String extractKeyFromReadResponse(String xmlResponse) {
        try {
            Dom.Document doc = new Dom.Document();
            doc.load(xmlResponse);
            Dom.XmlNode root = doc.getRootElement();
            
            // Traverse: Envelope → Body → Read_Result → SalesOrderSalesForce → Key
            for (Dom.XmlNode bodyNode : root.getChildElements()) {
                if (bodyNode.getName().contains('Body')) {
                    for (Dom.XmlNode resultNode : bodyNode.getChildElements()) {
                        if (resultNode.getName().contains('Read_Result')) {
                            for (Dom.XmlNode orderNode : resultNode.getChildElements()) {
                                if (orderNode.getName().contains('SalesOrderSalesForce')) {
                                    for (Dom.XmlNode fieldNode : orderNode.getChildElements()) {
                                        if (fieldNode.getName() == 'Key') {
                                            return fieldNode.getText();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            System.debug('[PARSE] <Key> element not found in response');
            return null;
            
        } catch (Exception ex) {
            System.debug('[PARSE] Exception extracting Key: ' + ex.getMessage());
            return null;
        }
    }
    
    // =========================================================================
    // HELPER – Query Order from Salesforce
    // =========================================================================
    private Order getOrderDetails(Id orderId) {
        return [
            SELECT 
            Id, 
            Name, 
            AccountId,
            EffectiveDate,
            OrderNumber, 
            PoDate,
            PoNumber,
            DRC_NBC_Warehouse__c,
            ShipToContactId,
            DRC_NBC_Cust_Order_Number__c, 
            Status,
            DRC_NBC_Payment_Terms__c,
            RecordType.Name,
            ShippingCountryCode, 
            DRC_NBC_Inco_Terms__c,
            CreatedDate,
            Account.Name,
            ShippingCity, 
            ShippingCountry,
            DRC_NBC_Order_Sync_To_BC__c,
            ShippingPostalCode, 
            ShippingStreet, 
            DRC_NBC_Shipping_Address__c,
            Account.DRC_NBC_Posted_To_BC__c, 
            Account.DRC_NBC_Customer_Number__c,
            DRC_NBC_Grand_Total__c,
            Account.BillingStreet,
            Account.BillingPostalCode,
            Account.DRC_NBC_BC_Approval_Status__c,
            Account.BillingCity, 
            CurrencyIsoCode,
            DRC_NBC_Shipping_Address__r.DRC_NBC_Warehouse__c,
            DRC_NBC_Shipping_Address__r.DRC_NBC_Ship_To_Code__c
            FROM
            Order
            WHERE 
            Id = :orderId
            LIMIT 1
        ];
    }
    
    /** Build Basic Auth header value */
    private String buildBasicAuthHeader() {
        Blob credential = Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD);
        return 'Basic ' + EncodingUtil.base64Encode(credential);
    }
    
    /** XML-escape a string; returns empty string for null/blank */
    private String escapeXml(String value) {
        if (String.isBlank(value)) return '';
        return value.escapeXml();
    }
    
    /** Null-safe string accessor */
    private String safeStr(Object value) {
        return value != null ? String.valueOf(value) : '';
    }
    // Update Order Status To Released
    private void updateOrderStatusToReleased(Id orderId) {
        System.debug('  [DML] Updating SF Order Status to Released. OrderId: ' + orderId);
        try {
            // Re-query to get a fresh, updateable record
            Order orderToUpdate = [
                SELECT Id, Status
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];
            
            System.debug('  [DML] Current Status: ' + orderToUpdate.Status);
            orderToUpdate.Status = 'Released';
            update orderToUpdate;
            System.debug('  [DML] Order Status updated to Released successfully');
            
        } catch (Exception ex) {
            System.debug('  [DML] Exception updating Order Status: ' + ex.getMessage());
            System.debug('  [DML] Stack Trace: ' + ex.getStackTraceString());
        }
    }
}