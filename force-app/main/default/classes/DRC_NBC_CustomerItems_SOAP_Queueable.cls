/**
* DRC_NBC_CustomerItems_SOAP_Queueable
* ─────────────────────────────────────────────────────────────────────────────
* Self-contained Queueable for BC CustomerItemListSF SOAP sync.
*
* Flow inside execute()
* ──────────────────────
*  1. Query Account  → BC Customer Number
*  2. Query Restricted Products for the Account
*  3. Early-exit if no products
*  4. ReadMultiple from BC filtered by Cust_No → build a Map<Item_No, Key>
*  5. For each product → if Key exists → toUpdate, else → toCreate
*  6. SOAP CreateMultiple  (if toCreate non-empty)
*  7. SOAP UpdateMultiple  (if toUpdate non-empty)
*  8. Write all API logs   (DML only AFTER all callouts)
*
* Rules respected
* ────────────────
*  • SOAP_NS  = "http://schemas.xmlsoap.org/soap/envelope/"   (envelope NS)
*  • BC_NS    = "urn:microsoft-dynamics-schemas/page/customersalesforce"
*               ← this is what the BC service actually expects
*  • Both loaded from DRC_NBC_BC_Integration__c custom setting
*      Fields: Customeritems_SOAP_NS__c  → SOAP envelope namespace
*              Customer_BC_NS__c         → BC page namespace
*  • Zero DML inside any callout loop
*  • All callouts finish before any DML
*/
public class DRC_NBC_CustomerItems_SOAP_Queueable
implements System.Queueable, Database.AllowsCallouts {
    
    // ─────────────────────────────────────────────────────────────────────────
    // SOAP namespace constants — loaded once from custom setting
    //
    //  Customeritems_SOAP_NS__c  →  http://schemas.xmlsoap.org/soap/envelope/
    //  Customer_BC_NS__c         →  urn:microsoft-dynamics-schemas/page/customersalesforce
    //
    // ─────────────────────────────────────────────────────────────────────────
    private static String SOAP_NS {
        get {
            if (SOAP_NS == null) {
                SOAP_NS = DRC_NBC_BC_Integration__c.getInstance()
                    .Customeritems_SOAP_NS__c;
            }
            return SOAP_NS;
        }
        set;
    }
    
    private static String BC_NS {
        get {
            if (BC_NS == null) {
                BC_NS = DRC_NBC_BC_Integration__c.getInstance()
                    .Customer_BC_NS__c;
            }
            return BC_NS;
        }
        set;
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // Inner DTO
    // ─────────────────────────────────────────────────────────────────────────
    private class ItemPayload {
        String  Key;            // populated only for Update (from ReadMultiple response)
        String  Cust_No;
        String  Item_No;
        String  UOM;
        Decimal Unit_Price;
        Decimal Quantity_Month;
        Decimal Amount;
        String  Remarks;
    }
    
    // ─────────────────────────────────────────────────────────────────────────
    // Fields
    // ─────────────────────────────────────────────────────────────────────────
    public Id accountId;
    
    public DRC_NBC_CustomerItems_SOAP_Queueable(Id accountId) {
        this.accountId = accountId;
    }
    
    // =========================================================================
    // EXECUTE
    // =========================================================================
    /* public void execute(System.QueueableContext context) {

String endpoint = DRC_NBC_BC_Integration__c.getInstance()
.CustomerItemSOAPEndpoint__c;

List<Map<String, Object>> logEntries = new List<Map<String, Object>>();

try {

// ── 1. Account ────────────────────────────────────────────────
Account acc = [
SELECT Id, DRC_NBC_Customer_Number__c
FROM   Account
WHERE  Id = :accountId
LIMIT  1
];
String custNo = acc.DRC_NBC_Customer_Number__c;

// ── 2. Restricted Products ────────────────────────────────────
List<DRC_NBC_Restricted_Product__c> products = [
SELECT Id,
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

System.debug('SOAP CustomerItems Endpoint >>>> ' + endpoint);
System.debug('SOAP_NS >>>> ' + SOAP_NS);
System.debug('BC_NS   >>>> ' + BC_NS);

// ── 4. ReadMultiple — fetch all existing BC records for Cust_No ─
//    One callout retrieves everything; avoids N callouts per item.
//    Returns Map<Item_No, Key>
// ─────────────────────────────────────────────────────────────────
String readRequest = buildReadMultipleEnvelope(custNo);
HttpResponse readRes = doCallout(endpoint, 'ReadMultiple', readRequest);

logEntries.add(new Map<String, Object>{
'operation'    => 'ReadMultiple',
'requestBody'  => readRequest,
'responseBody' => readRes != null ? readRes.getBody() : 'null',
'statusCode'   => readRes != null ? String.valueOf(readRes.getStatusCode()) : 'null',
'status'       => (readRes != null && readRes.getStatusCode() == 200) ? 'Success' : 'Error',
'itemNos'      => custNo
});

// Parse ReadMultiple response → Map<Item_No (uppercased), Key>
Map<String, String> bcItemKeyMap = parseReadMultiple(readRes);

// ── 5. Segregate into Create / Update ─────────────────────────
List<ItemPayload> toCreate = new List<ItemPayload>();
List<ItemPayload> toUpdate = new List<ItemPayload>();

for (DRC_NBC_Restricted_Product__c rp : products) {

String itemNo = rp.DRC_NBC_Product__r.DRC_NBC_FG_Code__c;
if (String.isBlank(itemNo)) continue;

ItemPayload p    = new ItemPayload();
p.Cust_No        = custNo;
p.Item_No        = itemNo;
p.UOM            = 'KGS';
p.Unit_Price     = 0;
p.Quantity_Month = 0;
p.Amount         = 0;
p.Remarks        = rp.DRC_NBC_Customer_s_Product_code__c;

String existingKey = bcItemKeyMap.get(itemNo.toUpperCase());

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
'responseBody' => createRes != null ? createRes.getBody() : 'null',
'statusCode'   => createRes != null ? String.valueOf(createRes.getStatusCode()) : 'null',
'status'       => (createRes != null && createRes.getStatusCode() == 200) ? 'Success' : 'Error',
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
'responseBody' => updateRes != null ? updateRes.getBody() : 'null',
'statusCode'   => updateRes != null ? String.valueOf(updateRes.getStatusCode()) : 'null',
'status'       => (updateRes != null && updateRes.getStatusCode() == 200) ? 'Success' : 'Error',
'itemNos'      => String.join(collectItemNos(toUpdate), ', ')
});
}

} catch (Exception e) {
System.debug('SOAP Queueable exception: ' + e.getMessage() +
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
}*/
    public void execute(QueueableContext context) {
        
        Boolean isSuccess = false;
        
        String endpoint = DRC_NBC_BC_Integration__c.getInstance()
            .CustomerItemSOAPEndpoint__c;
        
        List<Map<String, Object>> logEntries = new List<Map<String, Object>>();
        
        try {
            
            // -----------------------------------------------------------------
            // 1. Query Account
            // -----------------------------------------------------------------
            Account acc = [
                SELECT Id, Name, Type, DRC_NBC_Customer_Number__c
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];
            
            String customerNo = acc.DRC_NBC_Customer_Number__c;
            
            if (String.isBlank(customerNo)) {
                throw new AuraHandledException('BC Customer Number is blank for Account: ' + accountId);
            }
            
            // -----------------------------------------------------------------
            // 2. Query Customer Items / Restricted Products
            // -----------------------------------------------------------------
            List<DRC_NBC_Restricted_Product__c> restrictedProducts = [
                SELECT Id,
                Name,
                DRC_NBC_Customer__c,
                DRC_NBC_Customer_s_Product_code__c,
                DRC_NBC_Product__c,
                DRC_NBC_Product__r.Name,
                DRC_NBC_Product__r.DRC_NBC_FG_Code__c
                FROM DRC_NBC_Restricted_Product__c
                WHERE DRC_NBC_Customer__c = :accountId
            ];
            
            // -----------------------------------------------------------------
            // 3. If no records, mark success and continue chaining
            // -----------------------------------------------------------------
            if (restrictedProducts.isEmpty()) {
                System.debug('No Customer Items found for Account: ' + accountId);
                isSuccess = true;
                return;
            }
            
            // -----------------------------------------------------------------
            // 4. Existing SOAP logic
            // -----------------------------------------------------------------
            // Keep your existing CustomerItems SOAP code here:
            // - ReadMultiple
            // - CreateMultiple
            // - UpdateMultiple
            // - Delete logic
            // - Add log entries into logEntries list
            //
            // Example:
            //
            String readRequest = buildReadMultipleEnvelope(customerNo);
            HttpResponse readResponse = doCallout(endpoint, 'ReadMultiple', readRequest);
            
            logEntries.add(new Map<String, Object>{
                'operation'    => 'ReadMultiple',
                    'requestBody'  => readRequest,
                    'responseBody' => readResponse != null ? readResponse.getBody() : 'null',
                        'statusCode'   => readResponse != null ? String.valueOf(readResponse.getStatusCode()) : 'null',
                            'status'       => (readResponse != null && readResponse.getStatusCode() == 200) ? 'Success' : 'Error',
                                'itemNos'      => customerNo
                                });
            
            // -----------------------------------------------------------------
            // 5. Mark success only after all SOAP callouts are completed
            // -----------------------------------------------------------------
            isSuccess = true;
            
        } catch (Exception e) {
            
            System.debug(
                'DRC_NBC_CustomerItems_SOAP_Queueable Error: ' +
                e.getMessage() + '\n' + e.getStackTraceString()
            );
            
            logEntries.add(new Map<String, Object>{
                'operation'    => 'QueueableJob',
                    'requestBody'  => null,
                    'responseBody' => e.getMessage(),
                    'statusCode'   => 'null',
                    'status'       => 'Error',
                    'itemNos'      => ''
                    });
            
        } finally {
            
            // -----------------------------------------------------------------
            // 6. Insert logs after all callouts
            // -----------------------------------------------------------------
            if (!logEntries.isEmpty()) {
                flushLogs(logEntries, endpoint);
            }
        }
        
        // ---------------------------------------------------------------------
        // 7. Chain CustomerItemReferenceSOAPQueueable after current job success
        // ---------------------------------------------------------------------
        if (isSuccess) {
            System.enqueueJob(new CustomerItemReferenceSOAPQueueable(accountId));
        }
    }
    
    // =========================================================================
    // SOAP ENVELOPE BUILDERS
    // =========================================================================
    
    /**
* ReadMultiple — filter by Cust_No to fetch all existing BC records
* for this customer in one callout.
*
* Namespace used in Body: BC_NS
* (must match what the service advertises — customersalesforce, NOT customeritemlistsf)
*/
    private String buildReadMultipleEnvelope(String custNo) {
        return  '<soapenv:Envelope xmlns:soapenv="' + SOAP_NS + '">' +
            '<soapenv:Body>' +
            '<ReadMultiple xmlns="' + BC_NS + '">' +
            '<filter>' +
            '<Field>Cust_No</Field>' +
            '<Criteria>' + escapeXml(custNo) + '</Criteria>' +
            '</filter>' +
            '<bookmarkKey></bookmarkKey>' +
            '<setSize>0</setSize>' +   // 0 = return all records
            '</ReadMultiple>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }
    
    private String buildCreateEnvelope(List<ItemPayload> payloads) {
        return  '<soapenv:Envelope xmlns:soapenv="' + SOAP_NS + '">' +
            '<soapenv:Body>' +
            '<CreateMultiple xmlns="' + BC_NS + '">' +
            '<CustomerItemListSF_List>' +
            buildItemNodes(payloads, false) +
            '</CustomerItemListSF_List>' +
            '</CreateMultiple>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }
    
    private String buildUpdateEnvelope(List<ItemPayload> payloads) {
        return  '<soapenv:Envelope xmlns:soapenv="' + SOAP_NS + '">' +
            '<soapenv:Body>' +
            '<UpdateMultiple xmlns="' + BC_NS + '">' +
            '<CustomerItemListSF_List>' +
            buildItemNodes(payloads, true) +
            '</CustomerItemListSF_List>' +
            '</UpdateMultiple>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }
    
    /**
* @param includeKey  true for Update (Key required), false for Create
*
* Note: Item_Description is intentionally omitted per requirements.
*/
    private String buildItemNodes(List<ItemPayload> payloads, Boolean includeKey) {
        String xml = '';
        for (ItemPayload p : payloads) {
            xml += '<CustomerItemListSF>';
            if (includeKey && String.isNotBlank(p.Key))
                xml += '<Key>'            + escapeXml(p.Key)     + '</Key>';
            if (String.isNotBlank(p.Cust_No))
                xml += '<Cust_No>'        + escapeXml(p.Cust_No) + '</Cust_No>';
            if (String.isNotBlank(p.Item_No))
                xml += '<Item_No>'        + escapeXml(p.Item_No) + '</Item_No>';
            if (String.isNotBlank(p.UOM))
                xml += '<UOM>'            + escapeXml(p.UOM)     + '</UOM>';
            if (p.Unit_Price != null)
                xml += '<Unit_Price>'     + p.Unit_Price          + '</Unit_Price>';
            if (p.Quantity_Month != null)
                xml += '<Quantity_Month>' + p.Quantity_Month      + '</Quantity_Month>';
            if (p.Amount != null)
                xml += '<Amount>'         + p.Amount              + '</Amount>';
            if (String.isNotBlank(p.Remarks))
                xml += '<Remarks>'        + escapeXml(p.Remarks)  + '</Remarks>';
            xml += '</CustomerItemListSF>';
        }
        return xml;
    }
    
    // =========================================================================
    // HTTP CALLOUT
    // =========================================================================
    private HttpResponse doCallout(String endpoint, String soapAction, String body) {
        try {
            DRC_NBC_BC_Integration__c authConfig = DRC_NBC_BC_Integration__c.getInstance();
            String basicAuth = 'Basic ' + EncodingUtil.base64Encode(
                Blob.valueOf(authConfig.DRC_NBC_Username__c + ':' + authConfig.DRC_NBC_Password__c)
            );
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            
            req.setHeader('Content-Type',  'text/xml; charset=utf-8');
            req.setHeader('SOAPAction',    soapAction);   // explicitly set action
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
    private void flushLogs(List<Map<String, Object>> entries, String endpoint) {
        for (Map<String, Object> entry : entries) {
            String status    = (String) entry.get('status');
            String operation = (String) entry.get('operation');
            String statusStr = (String) entry.get('statusCode');
            
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_CustomerItems_SOAP_Queueable',
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
                    'DRC_NBC_CustomerItems_SOAP_Queueable',
                    endpoint,
                    null,
                    'QueueableJob',
                    operation + ' failed. Status: ' + statusStr +
                    ' | Items: ' + (String) entry.get('itemNos'),
                    null,
                    null,
                    'Error',
                    accountId
                );
            }
        }
    }
    
    // =========================================================================
    // PARSE ReadMultiple RESPONSE
    // =========================================================================
    /**
* Parses the ReadMultiple SOAP response and returns a map of
* Item_No (uppercased) → Key so the caller can quickly look up
* whether a given FG Code already exists in BC.
*/
    private Map<String, String> parseReadMultiple(HttpResponse res) {
        Map<String, String> result = new Map<String, String>();
        if (res == null || res.getStatusCode() != 200) return result;
        
        try {
            Dom.XmlNode root = res.getBodyDocument().getRootElement();
            // Walk the tree and collect every <CustomerItemListSF> element
            collectCustomerItems(root, result);
        } catch (Exception e) {
            System.debug('parseReadMultiple error: ' + e.getMessage());
        }
        return result;
    }
    
    /**
* Recursive walker — finds every <CustomerItemListSF> node and
* extracts its <Key> and <Item_No> children into the map.
*/
    private void collectCustomerItems(Dom.XmlNode node, Map<String, String> result) {
        if (node == null) return;
        
        if (node.getName() == 'CustomerItemListSF') {
            String key    = null;
            String itemNo = null;
            for (Dom.XmlNode child : node.getChildElements()) {
                if (child.getName() == 'Key')     key    = child.getText();
                if (child.getName() == 'Item_No') itemNo = child.getText();
            }
            if (String.isNotBlank(itemNo) && String.isNotBlank(key)) {
                result.put(itemNo.toUpperCase(), key);
            }
            return; // no need to recurse inside a record node
        }
        
        for (Dom.XmlNode child : node.getChildElements()) {
            collectCustomerItems(child, result);
        }
    }
    
    // =========================================================================
    // UTILITIES
    // =========================================================================
    private List<String> collectItemNos(List<ItemPayload> payloads) {
        List<String> nos = new List<String>();
        for (ItemPayload p : payloads) {
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