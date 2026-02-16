/**
* @File Name : DRC_NBC_GeoapifyService.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : November 11, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 11, 2025 |   | Initial Version
**/

public class DRC_NBC_GeoapifyService {

	@AuraEnabled(cacheable=false)
    public static Map<String, Double> getCoordinatesForRecord(Id recordId) {
        Map<String, Double> coords = new Map<String, Double>();

        if (recordId == null) {
            System.debug('⚠️ Record ID is null');
            return coords;
        }

        String objectPrefix = String.valueOf(recordId).substring(0, 3);
        String address = '';

        try {
            // ------------------------------
            // 1️⃣ Task Record Handling
            // ------------------------------
            if (objectPrefix == '00T') {
                Task t = [
                    SELECT Id, WhoId, WhatId, AccountId
                    FROM Task
                    WHERE Id = :recordId
                    LIMIT 1
                ];

                if (t.WhoId != null && String.valueOf(t.WhoId).startsWith('00Q')) {
                    Lead l = [
                        SELECT Street, City, State, PostalCode, Country
                        FROM Lead
                        WHERE Id = :t.WhoId
                        LIMIT 1
                    ];
                    address = formatAddress(l.Street, l.City, l.State, l.PostalCode, l.Country);

                } else if (t.WhoId != null && String.valueOf(t.WhoId).startsWith('003')) {
                    Contact c = [
                        SELECT MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
                        FROM Contact
                        WHERE Id = :t.WhoId
                        LIMIT 1
                    ];
                    address = formatAddress(c.MailingStreet, c.MailingCity, c.MailingState, c.MailingPostalCode, c.MailingCountry);

                } else if (t.AccountId != null) {
                    Account a = [
                        SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
                        FROM Account
                        WHERE Id = :t.AccountId
                        LIMIT 1
                    ];
                    address = formatAddress(a.BillingStreet, a.BillingCity, a.BillingState, a.BillingPostalCode, a.BillingCountry);
                }
            }

            // ------------------------------
            // 2️⃣ Event Record Handling
            // ------------------------------
            else if (objectPrefix == '00U') {
                Event e = [
                    SELECT Id, WhoId, WhatId, AccountId
                    FROM Event
                    WHERE Id = :recordId
                    LIMIT 1
                ];

                if (e.WhoId != null && String.valueOf(e.WhoId).startsWith('00Q')) {
                    Lead l = [
                        SELECT Street, City, State, PostalCode, Country
                        FROM Lead
                        WHERE Id = :e.WhoId
                        LIMIT 1
                    ];
                    address = formatAddress(l.Street, l.City, l.State, l.PostalCode, l.Country);

                } else if (e.WhoId != null && String.valueOf(e.WhoId).startsWith('003')) {
                    Contact c = [
                        SELECT MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
                        FROM Contact
                        WHERE Id = :e.WhoId
                        LIMIT 1
                    ];
                    address = formatAddress(c.MailingStreet, c.MailingCity, c.MailingState, c.MailingPostalCode, c.MailingCountry);

                } else if (e.AccountId != null) {
                    Account a = [
                        SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry
                        FROM Account
                        WHERE Id = :e.AccountId
                        LIMIT 1
                    ];
                    address = formatAddress(a.BillingStreet, a.BillingCity, a.BillingState, a.BillingPostalCode, a.BillingCountry);
                }
            }

            System.debug('📍 Address to geocode: ' + address);

            if (String.isBlank(address)) {
                System.debug('⚠️ Address blank, skipping Geoapify call.');
                return coords;
            }

            // ------------------------------
            // 3️⃣ Call Geoapify API using Named Credential
            // ------------------------------
            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                'callout:DRC_NBC_Geoapify_NC/v1/geocode/search?text=' +
                EncodingUtil.urlEncode(address, 'UTF-8') +
                '&limit=1&format=json'
            );
            req.setMethod('GET');
            req.setTimeout(15000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                if (parsed.containsKey('results')) {
                    List<Object> results = (List<Object>) parsed.get('results');
                    if (!results.isEmpty()) {
                        Map<String, Object> first = (Map<String, Object>) results[0];
                        coords.put('latitude', Double.valueOf(String.valueOf(first.get('lat'))));
                        coords.put('longitude', Double.valueOf(String.valueOf(first.get('lon'))));
                        System.debug('✅ Coordinates found: ' + coords);
                    }
                }
            } else {
                System.debug('❌ API call failed: ' + res.getStatus() + ' ' + res.getBody());
            }

        } catch (Exception e) {
            System.debug('💥 Exception in GeoapifyService: ' + e.getMessage());
        }

        return coords;
    }

    // 🔹 Utility to safely format addresses
    private static String formatAddress(String street, String city, String state, String postal, String country) {
        List<String> parts = new List<String>{street, city, state, postal, country};
        List<String> cleanParts = new List<String>();
        for (String s : parts) {
            if (!String.isBlank(s)) cleanParts.add(s.trim());
        }
        return String.join(cleanParts, ', ');
    }
}