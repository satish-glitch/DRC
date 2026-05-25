/**
* DRC_NBC_Account_SOAP_Queueable
* ─────────────────────────────────────────────────────────────────────────────
* Self-contained Queueable for BC CustomerSalesForce SOAP sync.
*
* Custom Setting  : DRC_NBC_BC_Integration__c
* Fields used     :
*   Account_SOAP_Endpoint__c     → full SOAP endpoint URL
*   Account_SOAP_NS__c           → SOAP envelope namespace
*   Account_BC_NS__c             → BC page namespace
*
* Flow inside execute()
* ──────────────────────
*  1. Load namespaces + endpoint from custom setting (one getInstance() call)
*  2. Query Account with all required fields + SalesPerson_Code__mdt
*  3. SOAP Read  → get existing Key from BC (by Customer No)
*  4. Build Update payload — ONLY Salesperson_Code is synced per requirement
*  5. SOAP Update → send payload with Key
*  6. Log result  (DML only AFTER all callouts)
*
* Rules respected
* ────────────────
*  • Zero DML inside callout block
*  • All callouts finish before any DML (logging)
*/
public class DRC_NBC_Account_SOAP_Queueable
implements System.Queueable, Database.AllowsCallouts {
    
    // ─────────────────────────────────────────────────────────────────────────
    // Fields
    // ─────────────────────────────────────────────────────────────────────────
    //   public Id orderId;
    public Id accountId;
    
    public DRC_NBC_Account_SOAP_Queueable( Id accountId) {
        //   this.orderId   = orderId;
        this.accountId = accountId;
    }
    
    // =========================================================================
    // EXECUTE
    // =========================================================================
    public void execute(System.QueueableContext context) {
        
        // ── Load all config in one custom setting call ─────────────────────
        DRC_NBC_BC_Integration__c config = DRC_NBC_BC_Integration__c.getInstance();
        
        String endpoint = config.Account_SOAP_Endpoint__c;   // full URL
        String soapNS   = config.Account_SOAP_NS__c;         // http://schemas.xmlsoap.org/soap/envelope/
        String bcNS     = config.Account_BC_NS__c;           // urn:microsoft-dynamics-schemas/page/customersalesforce
        
        System.debug('Account SOAP Endpoint >>>> ' + endpoint);
        System.debug('Account SOAP_NS        >>>> ' + soapNS);
        System.debug('Account BC_NS          >>>> ' + bcNS);
        
        // Log collector — flushed after all callouts
        List<Map<String, Object>> logEntries = new List<Map<String, Object>>();
        
        try {
            
            // ── 1. Query Account ───────────────────────────────────────────
            Account acc = [
                SELECT Id,
                Name,
                DRC_NBC_Customer_Number__c,
                DRC_NBC_PAN_No__c,
                DRC_NBC_GST_Number__c,
                DRC_Gst_Customer_Type__c,
                Phone,
                DRC_NBC_Account_Email_Email__c,
                DRC_NBC_Payment_Terms__c,
                DRC_NBC_Credit_Limit__c,
                CurrencyIsoCode,
                Website,
                Other_Email__c,
                BillingStreet,
                BillingCity,
                BillingStateCode,
                BillingPostalCode,
                BillingCountryCode,
                DRC_Inco_Term__c,
                SalesPerson_Code__c
                FROM   Account
                WHERE  Id = :accountId
                LIMIT  1
            ];
            
            
            
            String custNo = acc.DRC_NBC_Customer_Number__c;
            
            if (String.isBlank(custNo)) {
                throw new AuraHandledException(
                    'Account has no BC Customer Number — cannot sync.');
            }
            
            // ── 2. Resolve Salesperson Code from metadata ──────────────────
            List<SalesPerson_Code__mdt> spList = [
                SELECT MasterLabel, Name__c, Phone__c, Email__c
                FROM   SalesPerson_Code__mdt
                WHERE  Name__c = :acc.SalesPerson_Code__c
                LIMIT  1
            ];
            
            if (spList.isEmpty()) {
                throw new AuraHandledException(
                    'No Salesperson Code metadata found for: ' + acc.SalesPerson_Code__c);
            }
            String salespersonCode = spList[0].MasterLabel;
            
            // ── After resolving salespersonCode (Step 2) ──
            callSalesPerson(accountId, spList[0]);            
            // ── 3. SOAP Read → get Key ─────────────────────────────────────
            String readEnvelope = buildReadEnvelope(soapNS, bcNS, custNo);
            HttpResponse readRes = doCallout(endpoint, bcNS, 'Read', readEnvelope);
            
            logEntries.add(new Map<String, Object>{
                'operation'    => 'Read',
                    'requestBody'  => readEnvelope,
                    'responseBody' => readRes != null ? readRes.getBody() : 'null',
                        'statusCode'   => readRes != null ? String.valueOf(readRes.getStatusCode()) : 'null',
                            'status'       => (readRes != null && readRes.getStatusCode() == 200) ? 'Success' : 'Error'
                                });
            
            String bcKey = parseKey(readRes);
            
            if (String.isBlank(bcKey)) {
                throw new AuraHandledException(
                    'SOAP Read returned no Key for Customer No: ' + custNo +
                    '. Cannot perform Update.');
            }
            
            // ── 4. Build Update envelope (Salesperson_Code only) ───────────
            String updateEnvelope = buildUpdateEnvelope(soapNS, bcNS, acc, bcKey, salespersonCode);
            
            // ── 5. SOAP Update ─────────────────────────────────────────────
            HttpResponse updateRes = doCallout(endpoint, bcNS, 'Update', updateEnvelope);
            
            logEntries.add(new Map<String, Object>{
                'operation'    => 'Update',
                    'requestBody'  => updateEnvelope,
                    'responseBody' => updateRes != null ? updateRes.getBody() : 'null',
                        'statusCode'   => updateRes != null ? String.valueOf(updateRes.getStatusCode()) : 'null',
                            'status'       => (updateRes != null && updateRes.getStatusCode() == 200) ? 'Success' : 'Error'
                                });
            
        } catch (Exception e) {
            System.debug('Account SOAP Queueable exception: ' + e.getMessage());
            logEntries.add(new Map<String, Object>{
                'operation'    => 'QueueableJob',
                    'requestBody'  => null,
                    'responseBody' => e.getMessage(),
                    'statusCode'   => 'null',
                    'status'       => 'Error'
                    });
        } finally {
            // ── 6. Flush logs (DML after ALL callouts) ─────────────────────
            flushLogs(logEntries, endpoint);
        }
    }
    
    // =========================================================================
    // SOAP ENVELOPE BUILDERS
    // =========================================================================
    
    /**
* Read envelope — fetches existing BC record Key by Customer No.
*/
    public String buildReadEnvelope(String soapNS, String bcNS, String custNo) {
        return '<soapenv:Envelope' +
            ' xmlns:soapenv="' + soapNS + '"' +
            ' xmlns:bc="'      + bcNS   + '">' +
            '<soapenv:Body>' +
            '<bc:Read>' +
            '<bc:No>' + escapeXml(custNo) + '</bc:No>' +
            '</bc:Read>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }
    
    /**
* Update envelope — sends ONLY Salesperson_Code per business requirement.
* Key (from Read response) is mandatory for BC to locate the record.
* All other fields included as empty/blank — BC ignores blank optional fields.
*/
    public String buildUpdateEnvelope(
        String  soapNS,
        String  bcNS,
        Account acc,
        String  bcKey,
        String  salespersonCode) {
            
            // Currency — INR maps to blank per existing REST logic
            String currencyCode = (acc.CurrencyIsoCode == 'INR') ? '' : acc.CurrencyIsoCode;
            
            // Address split — max 100 chars per line per existing REST logic
            String address  = '';
            String address2 = '';
            if (String.isNotBlank(acc.BillingStreet)) {
                if (acc.BillingStreet.length() > 100) {
                    address  = acc.BillingStreet.substring(0, 100);
                    String rem = acc.BillingStreet.substring(100);
                    address2 = rem.length() > 100 ? rem.substring(0, 100) : rem;
                } else {
                    address = acc.BillingStreet;
                }
            }
            
            // Country — IN maps to IND per existing REST logic
            String countryCode = (acc.BillingCountryCode == 'IN') ? 'IND' : acc.BillingCountryCode;
            
            return '<soapenv:Envelope' +
                ' xmlns:soapenv="' + soapNS + '"' +
                ' xmlns:bc="'      + bcNS   + '">' +
                '<soapenv:Body>' +
                '<bc:Update>' +
                '<bc:CustomerSalesForce>' +
                '<bc:Key>'                + escapeXml(bcKey)                                          + '</bc:Key>' +
                '<bc:No>'                 + escapeXml(nullSafe(acc.DRC_NBC_Customer_Number__c))       + '</bc:No>' +
                '<bc:Salesperson_Code>'   + escapeXml(nullSafe(salespersonCode))                      + '</bc:Salesperson_Code>' +
                /*   '<bc:Name>'               + escapeXml(nullSafe(acc.Name))                             + '</bc:Name>' +
'<bc:Currency_Code>'      + escapeXml(nullSafe(currencyCode))                         + '</bc:Currency_Code>' +
'<bc:Address>'            + escapeXml(nullSafe(address))                              + '</bc:Address>' +
'<bc:Address_2>'          + escapeXml(nullSafe(address2))                             + '</bc:Address_2>' +
'<bc:Country_Region_Code>'+ escapeXml(nullSafe(countryCode))                          + '</bc:Country_Region_Code>' +
'<bc:State_Code>'         + escapeXml(nullSafe(acc.BillingStateCode))                 + '</bc:State_Code>' +
'<bc:City>'               + escapeXml(nullSafe(acc.BillingCity))                      + '</bc:City>' +
'<bc:Post_Code>'          + escapeXml(nullSafe(acc.BillingPostalCode))                + '</bc:Post_Code>' +
'<bc:P_A_N_No>'           + escapeXml(nullSafe(acc.DRC_NBC_PAN_No__c))               + '</bc:P_A_N_No>' +
'<bc:GST_Registration_No>'+ escapeXml(nullSafe(acc.DRC_NBC_GST_Number__c))           + '</bc:GST_Registration_No>' +
'<bc:GST_Customer_Type>'  + escapeXml(nullSafe(acc.DRC_Gst_Customer_Type__c))        + '</bc:GST_Customer_Type>' +
'<bc:Phone_No>'           + escapeXml(nullSafe(acc.Phone))                            + '</bc:Phone_No>' +
'<bc:Mobile_Phone_No>'    + ''                                                        + '</bc:Mobile_Phone_No>' +
'<bc:E_Mail>'             + escapeXml(nullSafe(acc.DRC_NBC_Account_Email_Email__c))   + '</bc:E_Mail>' +
'<bc:Payment_Terms_Code>' + escapeXml(nullSafe(acc.DRC_NBC_Payment_Terms__c))         + '</bc:Payment_Terms_Code>' +
'<bc:Shipment_Method_Code>'+ ''                                                       + '</bc:Shipment_Method_Code>' +
'<bc:Approval_Status>'    + 'Open'                                                    + '</bc:Approval_Status>' +
'<bc:Credit_Limit_LCY>'   + (acc.DRC_NBC_Credit_Limit__c != null
? String.valueOf(Integer.valueOf(acc.DRC_NBC_Credit_Limit__c))
: '0')                                                + '</bc:Credit_Limit_LCY>' +
// ✅ Only this field is the purpose of this sync
'<bc:Home_Page>'          + escapeXml(nullSafe(acc.Website))                          + '</bc:Home_Page>' +
'<bc:Business_type>'      + ''                                                        + '</bc:Business_type>' +
'<bc:Other_E_Mail>'       + escapeXml(nullSafe(acc.Other_Email__c))                   + '</bc:Other_E_Mail>' +*/
                '</bc:CustomerSalesForce>' +
                '</bc:Update>' +
                '</soapenv:Body>' +
                '</soapenv:Envelope>';
        }
    
    // =========================================================================
    // HTTP CALLOUT
    // =========================================================================
    public HttpResponse doCallout(
        String endpoint,
        String bcNS,
        String soapAction,
        String body) {
            try {
                // ── Basic Auth from custom setting ─────────────────────────────
                // Object : DRC_NBC_BC_Integration__c
                // Fields : DRC_NBC_Username__c, DRC_NBC_Password__c
                DRC_NBC_BC_Integration__c authConfig = DRC_NBC_BC_Integration__c.getInstance();
                String username = authConfig.DRC_NBC_Username__c;
                String password = authConfig.DRC_NBC_Password__c;
                String basicAuth = 'Basic ' + EncodingUtil.base64Encode(
                    Blob.valueOf(username + ':' + password)
                );
                
                HttpRequest req = new HttpRequest();
                req.setEndpoint(endpoint);
                req.setMethod('POST');
                req.setHeader('Content-Type',  'text/xml; charset=utf-8');
                req.setHeader('SOAPAction',    '"' + bcNS + '/' + soapAction + '"');
                req.setHeader('Authorization', basicAuth);
                req.setBody(body);
                req.setTimeout(120000);
                return new Http().send(req);
            } catch (Exception e) {
                System.debug('doCallout [' + soapAction + '] error: ' + e.getMessage());
                return null;
            }
        }
    
    // =========================================================================
    // LOGGING
    // =========================================================================
    public void flushLogs(List<Map<String, Object>> entries, String endpoint) {
        for (Map<String, Object> entry : entries) {
            String status    = (String) entry.get('status');
            String operation = (String) entry.get('operation');
            String statusStr = (String) entry.get('statusCode');
            
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Account_SOAP_Queueable',
                endpoint,
                (String) entry.get('requestBody'),
                operation,
                (String) entry.get('responseBody'),
                (statusStr != null && statusStr != 'null')
                ? Integer.valueOf(statusStr) : null,
                null,
                status,
                accountId
            );
            
            if (status == 'Error') {
                DRC_NBC_API_Log_Handler.createApiLog(
                    'DRC_NBC_Account_SOAP_Queueable',
                    endpoint,
                    null,
                    'QueueableJob',
                    operation + ' failed. Status: ' + statusStr,
                    null,
                    null,
                    'Error',
                    accountId
                );
            }
        }
    }
    
    // =========================================================================
    // UTILITIES
    // =========================================================================
    
    /** Parse <Key> from SOAP Read response. Returns null if not found. */
    public String parseKey(HttpResponse res) {
        if (res == null || res.getStatusCode() != 200) return null;
        try {
            Dom.XmlNode root    = res.getBodyDocument().getRootElement();
            Dom.XmlNode keyNode = findNode(root, 'Key');
            return (keyNode != null) ? keyNode.getText() : null;
        } catch (Exception e) {
            System.debug('parseKey error: ' + e.getMessage());
            return null;
        }
    }
    
    /** Depth-first search for a node by local name. */
    private Dom.XmlNode findNode(Dom.XmlNode node, String localName) {
        if (node == null) return null;
        if (node.getName() == localName) return node;
        for (Dom.XmlNode child : node.getChildElements()) {
            Dom.XmlNode found = findNode(child, localName);
            if (found != null) return found;
        }
        return null;
    }
    
    /** Null-safe string — returns empty string instead of null. */
    private String nullSafe(String s) {
        return s != null ? s : '';
    }
    
    /** Escape special XML characters. */
    private String escapeXml(String s) {
        if (s == null) return '';
        return s.replace('&',  '&amp;')
            .replace('<',  '&lt;')
            .replace('>',  '&gt;')
            .replace('"',  '&quot;')
            .replace('\'', '&apos;');
    }
    
    /**
* Inline salesperson BC callout — uses accountId, no API log created.
*/
    /**
* Inline salesperson BC callout — uses accountId, no API log created.
*/
    public void callSalesPerson(Id accountId, SalesPerson_Code__mdt spMdt) {
        try {
            // ── 1. Build payload ───────────────────────────────────────────────
            Map<String, Object> payloadMap = new Map<String, Object>{
                'Code'     => spMdt.MasterLabel,
                    'Name'     => spMdt.Name__c,
                    'Phone_No' => spMdt.Phone__c,
                    'E_Mail'   => spMdt.Email__c
                    };
                        String payload = JSON.serialize(payloadMap);
            System.debug('SalesPersonCode Payload: ' + payload);
            
            // ── 2. Load config ─────────────────────────────────────────────────
            DRC_NBC_BC_Integration__c config = DRC_NBC_BC_Integration__c.getInstance();
            String username = config.DRC_NBC_Username__c;
            String password = config.DRC_NBC_Password__c;
            String basicAuth = 'Basic ' + EncodingUtil.base64Encode(
                Blob.valueOf(username + ':' + password)
            );
            String endpoint = config.DRC_NBC_SalesPerson_Code__c; // full endpoint URL
            
            // ── 3. Build & fire HTTP request ───────────────────────────────────
            HttpRequest req = new HttpRequest();
            String fullEndpoint = DRC_NBC_BC_Callout_Utility.getFullEndpoint(endpoint);
            req.setEndpoint(fullEndpoint);
            req.setMethod('POST');
            req.setTimeout(120000);
            req.setHeader('Content-Type',  'application/json');
            req.setHeader('Authorization', basicAuth);
            req.setBody(payload);
            
            HttpResponse res = new Http().send(req);
            
            // ── 4. Debug only — no API log created ────────────────────────────
            System.debug('SalesPersonCode Status : ' + res.getStatusCode());
            System.debug('SalesPersonCode Response: ' + res.getBody());
            
        } catch (Exception e) {
            System.debug('callSalesPerson error: ' + e.getMessage());
        }
    }
}