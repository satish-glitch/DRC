public class DRC_NBC_CheckShiipingDetails {
    
    // Custom Setting Instance
    private static DRC_NBC_BC_Integration__c bcSettings = DRC_NBC_BC_Integration__c.getInstance();
    
    // BC Endpoints from Custom Setting
    private static final String Shipping_Endpoint  = bcSettings.DRC_NBC_Shipping_Endpoint__c;
    private static final String Shipping_Namespace = bcSettings.DRC_NBC_Shipping_Name_Space__c;
    
    // Authentication credentials from Custom Setting
    private static final String BC_USERNAME = bcSettings.DRC_NBC_Username__c;
    private static final String BC_PASSWORD = bcSettings.DRC_NBC_Password__c;
    
    
    /**
* Checks if a Ship-To address already exists in Business Central.
* @param orderId   - Salesforce Order Id
* @param accountId - Salesforce Account Id
* @return Boolean  - true if NOT found in BC (safe to create), false if already exists
*/
    public static Boolean checkShippingExists(Id orderId, Id accountId) {
        
        // ── 1. Fetch CustomerNo from Account ──────────────────────────────────
        List<Account> accounts = [
            SELECT Id, DRC_NBC_Customer_Number__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        
        if (accounts.isEmpty() || String.isBlank(accounts[0].DRC_NBC_Customer_Number__c)) {
            System.debug('No Account or Customer Number found for AccountId: ' + accountId);
            return true; // Treat as not found — allow creation to proceed
        }
        
        String customerNo = accounts[0].DRC_NBC_Customer_Number__c;
        
        // ── 2. Fetch ShipToCode from the Order's linked Shipping Address ───────
        List<Order> orders = [
            SELECT Id, DRC_NBC_Shipping_Address__c
            FROM Order
            WHERE Id = :orderId
            LIMIT 1
        ];
        
        if (orders.isEmpty() || orders[0].DRC_NBC_Shipping_Address__c == null) {
            System.debug('No Order or Shipping Address linked for OrderId: ' + orderId);
            return true;
        }
        
        Id shippingAddressId = orders[0].DRC_NBC_Shipping_Address__c;
        
        List<DRC_NBC_Addresses__c> addresses = [
            SELECT Id, DRC_NBC_Ship_To_Code__c
            FROM DRC_NBC_Addresses__c
            WHERE Id = :shippingAddressId
            AND DRC_NBC_Type__c = 'Shipping'
            LIMIT 1
        ];
        
        if (addresses.isEmpty() || String.isBlank(addresses[0].DRC_NBC_Ship_To_Code__c)) {
            System.debug('No Shipping Address or ShipToCode found for AddressId: ' + shippingAddressId);
            return true;
        }
        
        String shipToCode = addresses[0].DRC_NBC_Ship_To_Code__c;
        
        // ── 3. Build SOAP Payload ──────────────────────────────────────────────
        String soapBody =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">' +
            '<Body>' +
            '<Read xmlns="' + Shipping_Namespace + '">' +
            '<CustomerNo>' + escapeXml(customerNo) + '</CustomerNo>' +
            '<ShiptoCode>' + escapeXml(shipToCode) + '</ShiptoCode>' +
            '</Read>' +
            '</Body>' +
            '</Envelope>';
        
        System.debug('SOAP Request Body: ' + soapBody);
        
        // ── 4. Make the HTTP Callout ───────────────────────────────────────────
        HttpRequest req = new HttpRequest();
        req.setEndpoint(Shipping_Endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader('SOAPAction', '""');
        
        // Basic Auth
        Blob credentials = Blob.valueOf(BC_USERNAME + ':' + BC_PASSWORD);
        req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(credentials));
        
        req.setBody(soapBody);
        req.setTimeout(120000);
        
        HttpResponse res;
        try {
            Http http = new Http();
            res = http.send(req);
        } catch (Exception e) {
            System.debug('Callout Exception: ' + e.getMessage());
            return true; // Treat as not found on error
        }
        
        System.debug('SOAP Response Status: ' + res.getStatusCode());
        System.debug('SOAP Response Body: '   + res.getBody());
        
        // ── 5. Evaluate Response ───────────────────────────────────────────────
        // BC returns 200 with a body when the record is found
        // BC returns a SOAP Fault (500) when NOT found
        if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
            
            String responseBody = res.getBody();
            
            // Check if Body is empty — <Soap:Body/> or <Soap:Body></Soap:Body>
            Boolean isEmptyBody = responseBody.containsIgnoreCase('<Soap:Body/>') || 
                responseBody.containsIgnoreCase('<Soap:Body></Soap:Body>');
            
            if (isEmptyBody) {
                System.debug('BC returned empty Soap:Body — Ship-To NOT FOUND. Safe to create.');
                return true; // Empty body = record does not exist → proceed to create
            }
            
            System.debug('BC returned data in Soap:Body — Ship-To EXISTS. Skipping creation.');
            return false; // Has content = record already exists → skip
        }
        System.debug('Non-200 response or error — treating as NOT FOUND. Safe to create.');
        return true;
        
    }
    
    // ── Helper: basic XML character escaping ──────────────────────────────────
    private static String escapeXml(String input) {
        if (String.isBlank(input)) return '';
        return input
            .replace('&',  '&amp;')
            .replace('<',  '&lt;')
            .replace('>',  '&gt;')
            .replace('"',  '&quot;')
            .replace('\'', '&apos;');
    }
}