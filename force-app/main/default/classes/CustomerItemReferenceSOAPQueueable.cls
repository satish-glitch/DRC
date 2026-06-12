/**
* @File Name : CustomerItemReferenceSOAPQueueable.cls
* @Description : Self-contained Queueable for BC CustomerItemReference SOAP sync.
*
* Flow inside execute()
* ──────────────────────
*  1. Query Account  → BC Customer Number, Name, Type
*  2. Query Restricted Products for the Account
*  3. Early-exit if no products
*  4. ReadMultiple from BC filtered by Reference_Type_No → build a
*     Map<Item_No|Reference_No (uppercased), Key>
*  5. For each product → if Key exists → toUpdate, else → toCreate
*  6. SOAP CreateMultiple  (if toCreate non-empty)
*  7. SOAP UpdateMultiple  (if toUpdate non-empty)
*  8. Write all API logs   (DML only AFTER all callouts)
*
* Rules respected
* ────────────────
*  • SOAP_NS  = loaded from DRC_NBC_BC_Integration__c.CustomerItemRef_SOAP_NS__c
*  • BC_NS    = loaded from DRC_NBC_BC_Integration__c.CustomerItemRef_BC_NS__c
*  • Endpoint = loaded from DRC_NBC_BC_Integration__c.CustomerItemReferenceSOAPEndpoint__c
*  • Zero DML inside any callout loop
*  • All callouts finish before any DML
*
* @Author : Satish YADAV
* @Last Modified On : June 12, 2026
*/
public class CustomerItemReferenceSOAPQueueable
implements System.Queueable, Database.AllowsCallouts {
    
    // ─────────────────────────────────────────────────────────────────────────
    // SOAP namespace constants — loaded once from custom setting
    // ─────────────────────────────────────────────────────────────────────────
    
    private static String SOAP_NS {
        get {
            if (SOAP_NS == null) {
                SOAP_NS = DRC_NBC_BC_Integration__c.getInstance()
                    .CustomerItemRef_SOAP_NS__c;
            }
            return SOAP_NS;
        }
        set;
    }
    
    private static String BC_NS {
        get {
            if (BC_NS == null) {
                BC_NS = DRC_NBC_BC_Integration__c.getInstance()
                    .CustomerItemRef_BC_NS__c;
            }
            return BC_NS;
        }
        set;
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // Inner DTO
    // ─────────────────────────────────────────────────────────────────────────
    
    private class ItemRefPayload {
        String Key;                  // populated only for Update (from ReadMultiple response)
        String Reference_Type;
        String Reference_Type_No;
        String Reference_Type_Name;
        String Reference_No;
        String Item_No;
        String Description;
        String Description_2;
        String Unit_of_Measure;
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // Fields
    // ─────────────────────────────────────────────────────────────────────────
    
    public Id accountId;
    
    public CustomerItemReferenceSOAPQueueable(Id accountId) {
        this.accountId = accountId;
    }
    
    // =========================================================================
    // EXECUTE
    // =========================================================================
    
    public void execute(System.QueueableContext context) {
        
        String endpoint = DRC_NBC_BC_Integration__c.getInstance()
            .customer_item_ref_endpoint__c;
        
        List<Map<String, Object>> logEntries = new List<Map<String, Object>>();
        
        try {
            
            // ── 1. Account ────────────────────────────────────────────────
            Account acc = [
                SELECT Id, Name, Type, DRC_NBC_Customer_Number__c
                FROM   Account
                WHERE  Id = :accountId
                LIMIT  1
            ];
            String custNo = acc.DRC_NBC_Customer_Number__c;
            
            // ── 2. Restricted Products ────────────────────────────────────
            List<DRC_NBC_Restricted_Product__c> products = [
                SELECT Id, Name,
                DRC_NBC_Product__r.DRC_NBC_FG_Code__c,
                DRC_NBC_Customer_s_Product_code__c
                FROM   DRC_NBC_Restricted_Product__c
                WHERE  DRC_NBC_Customer__c = :accountId
            ];
            
            // ── 3. Early-exit ─────────────────────────────────────────────
            if (products == null || products.isEmpty()) {
                System.debug('No restricted products for account: ' + accountId);
                return;
            }
            
            System.debug('SOAP CustomerItemReference Endpoint >>>> ' + endpoint);
            System.debug('SOAP_NS >>>> ' + SOAP_NS);
            System.debug('BC_NS   >>>> ' + BC_NS);
            
            // ── 4. ReadMultiple ───────────────────────────────────────────
            // One callout retrieves everything filtered by Reference_Type_No.
            // Returns Map<Item_No|Reference_No (uppercased), Key>
            String      readRequest = buildReadMultipleEnvelope(custNo);
            HttpResponse readRes    = doCallout(endpoint, 'ReadMultiple', readRequest);
            
            logEntries.add(new Map<String, Object>{
                'operation'    => 'ReadMultiple',
                    'requestBody'  => readRequest,
                    'responseBody' => readRes != null ? readRes.getBody()                    : 'null',
                        'statusCode'   => readRes != null ? String.valueOf(readRes.getStatusCode()) : 'null',
                            'status'       => (readRes != null && readRes.getStatusCode() == 200)    ? 'Success' : 'Error',
                                'itemNos'      => custNo
                                });
            
            // Parse ReadMultiple response → Map<Item_No|Reference_No (uppercased), Key>
            Map<String, String> bcRefKeyMap = parseReadMultiple(readRes);
            
            // ── 5. Segregate into Create / Update ─────────────────────────
            List<ItemRefPayload> toCreate = new List<ItemRefPayload>();
            List<ItemRefPayload> toUpdate = new List<ItemRefPayload>();
            
            for (DRC_NBC_Restricted_Product__c rp : products) {
                
                String itemNo = rp.DRC_NBC_Product__r.DRC_NBC_FG_Code__c;
                if (String.isBlank(itemNo)) continue;
                
                ItemRefPayload p      = new ItemRefPayload();
                p.Reference_Type_No   = custNo;
                p.Item_No             = itemNo;
                p.Unit_of_Measure     = 'KGS';
                p.Reference_Type      = acc.Type;
                p.Reference_No        = rp.Name;
                p.Reference_Type_Name = acc.Name;
                p.Description         = rp.DRC_NBC_Customer_s_Product_code__c;
                p.Description_2       = '';
                
                String mapKey      = buildMapKey(itemNo, rp.Name);
                String existingKey = bcRefKeyMap.get(mapKey);
                
                if (String.isBlank(existingKey)) {
                    toCreate.add(p);
                } else {
                    p.Key = existingKey;
                    toUpdate.add(p);
                }
            }
            
            // ── 6. CreateMultiple ─────────────────────────────────────────
            if (!toCreate.isEmpty()) {
                String       createRequest = buildCreateEnvelope(toCreate);
                HttpResponse createRes     = doCallout(endpoint, 'CreateMultiple', createRequest);
                
                logEntries.add(new Map<String, Object>{
                    'operation'    => 'CreateMultiple',
                        'requestBody'  => createRequest,
                        'responseBody' => createRes != null ? createRes.getBody()                    : 'null',
                            'statusCode'   => createRes != null ? String.valueOf(createRes.getStatusCode()) : 'null',
                                'status'       => (createRes != null && createRes.getStatusCode() == 200)    ? 'Success' : 'Error',
                                    'itemNos'      => String.join(collectItemNos(toCreate), ', ')
                                    });
            }
            
            // ── 7. UpdateMultiple ─────────────────────────────────────────
            if (!toUpdate.isEmpty()) {
                String       updateRequest = buildUpdateEnvelope(toUpdate);
                HttpResponse updateRes     = doCallout(endpoint, 'UpdateMultiple', updateRequest);
                
                logEntries.add(new Map<String, Object>{
                    'operation'    => 'UpdateMultiple',
                        'requestBody'  => updateRequest,
                        'responseBody' => updateRes != null ? updateRes.getBody()                    : 'null',
                            'statusCode'   => updateRes != null ? String.valueOf(updateRes.getStatusCode()) : 'null',
                                'status'       => (updateRes != null && updateRes.getStatusCode() == 200)    ? 'Success' : 'Error',
                                    'itemNos'      => String.join(collectItemNos(toUpdate), ', ')
                                    });
            }
            
        } catch (Exception e) {
            System.debug('CustomerItemReference SOAP Queueable exception: ' + e.getMessage() +
                         '\n' + e.getStackTraceString());
            logEntries.add(new Map<String, Object>{
                'operation'    => 'QueueableJob',
                    'requestBody'  => null,
                    'responseBody' => e.getMessage(),
                    'statusCode'   => 'null',
                    'status'       => 'Error',
                    'itemNos'      => ''
                    });
        } finally {
            // ── 8. Flush all logs (DML after ALL callouts) ─────────────────
            flushLogs(logEntries, endpoint);
        }
    }
    
    // =========================================================================
    // SOAP ENVELOPE BUILDERS
    // =========================================================================
    
    /**
* ReadMultiple — filter by Reference_Type_No to fetch all existing BC
* CustomerItemReference records for this customer in one callout.
*/
    private String buildReadMultipleEnvelope(String custNo) {
        return '<soapenv:Envelope xmlns:soapenv="' + SOAP_NS + '">'  +
            '<soapenv:Body>'                                    +
            '<ReadMultiple xmlns="' + BC_NS + '">'         +
            '<filter>'                                  +
            '<Field>Reference_Type_No</Field>'      +
            '<Criteria>' + escapeXml(custNo) + '</Criteria>' +
            '</filter>'                                 +
            '<bookmarkKey></bookmarkKey>'               +
            '<setSize>100</setSize>'                      +  // 0 = return all
            '</ReadMultiple>'                               +
            '</soapenv:Body>'                                   +
            '</soapenv:Envelope>';
    }
    
    private String buildCreateEnvelope(List<ItemRefPayload> payloads) {
        return '<soapenv:Envelope xmlns:soapenv="' + SOAP_NS + '">'       +
            '<soapenv:Body>'                                         +
            '<CreateMultiple xmlns="' + BC_NS + '">'            +
            '<CUstomerItemReference_List>'                   +
            buildItemNodes(payloads, false)              +
            '</CUstomerItemReference_List>'                  +
            '</CreateMultiple>'                                  +
            '</soapenv:Body>'                                        +
            '</soapenv:Envelope>';
    }
    
    private String buildUpdateEnvelope(List<ItemRefPayload> payloads) {
        return '<soapenv:Envelope xmlns:soapenv="' + SOAP_NS + '">'       +
            '<soapenv:Body>'                                         +
            '<UpdateMultiple xmlns="' + BC_NS + '">'            +
            '<CUstomerItemReference_List>'                   +
            buildItemNodes(payloads, true)               +
            '</CUstomerItemReference_List>'                  +
            '</UpdateMultiple>'                                  +
            '</soapenv:Body>'                                        +
            '</soapenv:Envelope>';
    }
    
    /**
* @param includeKey  true for Update (Key required), false for Create
*/
    private String buildItemNodes(List<ItemRefPayload> payloads, Boolean includeKey) {
        String xml = '';
        for (ItemRefPayload p : payloads) {
            xml += '<CUstomerItemReference>';
            
            if (includeKey && String.isNotBlank(p.Key))
                xml += '<Key>'                 + escapeXml(p.Key)                 + '</Key>';
            
            if (String.isNotBlank(p.Reference_Type))
                xml += '<Reference_Type>'      + escapeXml(p.Reference_Type)      + '</Reference_Type>';
            
            if (String.isNotBlank(p.Reference_Type_No))
                xml += '<Reference_Type_No>'   + escapeXml(p.Reference_Type_No)   + '</Reference_Type_No>';
            
            if (String.isNotBlank(p.Reference_Type_Name))
                xml += '<Reference_Type_Name>' + escapeXml(p.Reference_Type_Name) + '</Reference_Type_Name>';
            
            if (String.isNotBlank(p.Reference_No))
                xml += '<Reference_No>'        + escapeXml(p.Reference_No)        + '</Reference_No>';
            
            if (String.isNotBlank(p.Item_No))
                xml += '<Item_No>'             + escapeXml(p.Item_No)             + '</Item_No>';
            
            if (String.isNotBlank(p.Description))
                xml += '<Description>'         + escapeXml(p.Description)         + '</Description>';
            
            if (p.Description_2 != null)
                xml += '<Description_2>'       + escapeXml(p.Description_2)       + '</Description_2>';
            
            if (String.isNotBlank(p.Unit_of_Measure))
                xml += '<Unit_of_Measure>'     + escapeXml(p.Unit_of_Measure)     + '</Unit_of_Measure>';
            
            xml += '</CUstomerItemReference>';
        }
        return xml;
    }
    
    // =========================================================================
    // HTTP CALLOUT
    // =========================================================================
    
    /* private HttpResponse doCallout(String endpoint, String soapAction, String body) {
try {
DRC_NBC_BC_Integration__c authConfig = DRC_NBC_BC_Integration__c.getInstance();
String basicAuth = 'Basic ' + EncodingUtil.base64Encode(
Blob.valueOf(authConfig.DRC_NBC_Username__c + ':' + authConfig.DRC_NBC_Password__c)
);

HttpRequest req = new HttpRequest();
req.setEndpoint(endpoint);
req.setMethod('POST');
req.setHeader('Content-Type',  'text/xml; charset=utf-8');
req.setHeader('SOAPAction',    soapAction);
req.setHeader('Authorization', basicAuth);
req.setBody(body);
req.setTimeout(120000);

return new Http().send(req);

} catch (Exception e) {
System.debug('doCallout [' + soapAction + '] error: ' + e.getMessage());
return null;
}
}*/
    private HttpResponse doCallout(String endpoint, String soapAction, String body) {
        try {
            DRC_NBC_BC_Integration__c authConfig = DRC_NBC_BC_Integration__c.getInstance();
            
            String basicAuth = 'Basic ' + EncodingUtil.base64Encode(
                Blob.valueOf(authConfig.DRC_NBC_Username__c + ':' + authConfig.DRC_NBC_Password__c)
            );
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            
            // Important for Business Central SOAP
            req.setHeader('SOAPAction', BC_NS + ':' + soapAction);
            
            req.setHeader('Authorization', basicAuth);
            req.setBody(body);
            req.setTimeout(120000);
            
            System.debug('SOAP Endpoint >>> ' + endpoint);
            System.debug('SOAP Action >>> ' + BC_NS + ':' + soapAction);
            System.debug('SOAP Request Body >>> ' + body);
            
            HttpResponse res = new Http().send(req);
            
            System.debug('SOAP Status Code >>> ' + res.getStatusCode());
            System.debug('SOAP Status >>> ' + res.getStatus());
            System.debug('SOAP Response Body >>> ' + res.getBody());
            
            return res;
            
        } catch (Exception e) {
            System.debug('doCallout [' + soapAction + '] Exception Message >>> ' + e.getMessage());
            System.debug('doCallout [' + soapAction + '] Stack Trace >>> ' + e.getStackTraceString());
            
            throw e;
        }
    }
    
    // =========================================================================
    // LOGGING — all DML deferred here, called from finally block
    // =========================================================================
    
    private void flushLogs(List<Map<String, Object>> entries, String endpoint) {
        for (Map<String, Object> entry : entries) {
            
            String status    = (String) entry.get('status');
            String operation = (String) entry.get('operation');
            String statusStr = (String) entry.get('statusCode');
            
            // Primary log — one per operation
            DRC_NBC_API_Log_Handler.createApiLog(
                endpoint,
                (String) entry.get('requestBody'),
                (String) entry.get('responseBody'),
                operation,
                status == 'Error' ? (String) entry.get('responseBody') : null,
                (statusStr != null && statusStr != 'null') ? Integer.valueOf(statusStr) : null,
                null,
                status,
                String.valueOf(accountId)
            );
            
            // Secondary error-detail log
            if (status == 'Error') {
                DRC_NBC_API_Log_Handler.createApiLog(
                    endpoint,
                    null,
                    operation + ' failed. Status: ' + statusStr +
                    ' | Items: ' + (String) entry.get('itemNos'),
                    'QueueableJob',
                    operation + ' failed. Status: ' + statusStr,
                    null,
                    null,
                    'Error',
                    String.valueOf(accountId)
                );
            }
        }
    }
    
    // =========================================================================
    // PARSE ReadMultiple RESPONSE
    // =========================================================================
    
    /**
* Parses the ReadMultiple SOAP response and returns a map of
* "ITEMNO|REFERENCENO" (uppercased) → Key so the caller can quickly
* look up whether a given FG Code + Reference_No combination already
* exists in BC.
*/
    private Map<String, String> parseReadMultiple(HttpResponse res) {
        Map<String, String> result = new Map<String, String>();
        if (res == null || res.getStatusCode() != 200) return result;
        
        try {
            Dom.XmlNode root = res.getBodyDocument().getRootElement();
            collectCustomerItemRefs(root, result);
        } catch (Exception e) {
            System.debug('parseReadMultiple error: ' + e.getMessage());
        }
        return result;
    }
    
    /**
* Recursive walker — finds every <CUstomerItemReference> node and
* extracts its <Key>, <Item_No> and <Reference_No> children into the map.
*/
    private void collectCustomerItemRefs(Dom.XmlNode node, Map<String, String> result) {
        if (node == null) return;
        
        if (node.getName() == 'CUstomerItemReference') {
            String key         = null;
            String itemNo      = null;
            String referenceNo = null;
            
            for (Dom.XmlNode child : node.getChildElements()) {
                if      (child.getName() == 'Key')          key         = child.getText();
                else if (child.getName() == 'Item_No')      itemNo      = child.getText();
                else if (child.getName() == 'Reference_No') referenceNo = child.getText();
            }
            
            if (String.isNotBlank(itemNo) && String.isNotBlank(key)) {
                result.put(buildMapKey(itemNo, referenceNo), key);
            }
            return; // no need to recurse inside a record node
        }
        
        for (Dom.XmlNode child : node.getChildElements()) {
            collectCustomerItemRefs(child, result);
        }
    }
    
    // =========================================================================
    // UTILITIES
    // =========================================================================
    
    /**
* Builds a normalized lookup key combining Item_No and Reference_No.
* Both segments are uppercased and null-safe so records can be matched
* between SF Restricted Product list and BC ReadMultiple response
* regardless of casing.
*/
    private String buildMapKey(String itemNo, String referenceNo) {
        String left  = String.isNotBlank(itemNo)      ? itemNo.toUpperCase()      : '';
        String right = String.isNotBlank(referenceNo) ? referenceNo.toUpperCase() : '';
        return left + '|' + right;
    }
    
    private List<String> collectItemNos(List<ItemRefPayload> payloads) {
        List<String> nos = new List<String>();
        for (ItemRefPayload p : payloads) {
            if (String.isNotBlank(p.Item_No)) nos.add(p.Item_No);
        }
        return nos;
    }
    
    private String escapeXml(String s) {
        if (s == null) return '';
        return s.replace('&',  '&amp;')
            .replace('<',  '&lt;')
            .replace('>',  '&gt;')
            .replace('"',  '&quot;')
            .replace('\'', '&apos;');
    }
}