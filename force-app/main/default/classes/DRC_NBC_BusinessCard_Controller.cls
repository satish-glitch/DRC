public with sharing class DRC_NBC_BusinessCard_Controller {
   @AuraEnabled
public static String processBusinessCard(String imageUrl) {
    try {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('https://business-card-scanner.p.rapidapi.com/processDocument');
        request.setMethod('POST');
        request.setHeader('x-rapidapi-key', '6957a48d5bmshb73734443712998p1826a9jsne5252fdd32e7');
        request.setHeader('x-rapidapi-host', 'business-card-scanner.p.rapidapi.com');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeOut(120000);
        
        String body = '{"extractionDetails": {"name": "Business Card - Extraction","language": "English","fields": [{"key": "name"},{"key": "job_title"},{"key": "company_name"},{"key": "address"},{"key": "phone_numbers"},{"key": "email_addresses"},{"key": "website_url"},{"key" :"city"},{"key" :"country"}, {"key" :"postal_code"},{"key" :"state"},{"key" :"street"}]},"file": "' + imageUrl + '"}';
        request.setBody(body);

        HttpResponse response = http.send(request);
        
        // Handle different status codes
        if (response.getStatusCode() == 200) {
            return response.getBody();
        } else if (response.getStatusCode() == 429) {
            throw new AuraHandledException('Rate limit exceeded. Please try again later or upgrade your API plan.');
        } else if (response.getStatusCode() == 401 || response.getStatusCode() == 403) {
            throw new AuraHandledException('API authentication failed. Please check your API key.');
        } else {
            throw new AuraHandledException('API Error (' + response.getStatusCode() + '): ' + response.getStatus() + ' - ' + response.getBody());
        }
    } catch (Exception e) {
        if (e instanceof AuraHandledException) {
            throw e;
        }
        throw new AuraHandledException('API Call failed: ' + e.getMessage());
    }
}
        // Wrapper class for Lead details
    public class LeadWrapper {
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public String jobTitle { get; set; }
        @AuraEnabled
        public String companyName { get; set; }
        @AuraEnabled
        public String address { get; set; }
        @AuraEnabled
        public String phoneNumber { get; set; }
        @AuraEnabled
        public String email { get; set; }
        @AuraEnabled
        public String websiteUrl { get; set; }
        @AuraEnabled
        public String country { get; set; }
        @AuraEnabled
        public String street { get; set; }
        @AuraEnabled
        public String postalCode { get; set; }
        @AuraEnabled
        public String city { get; set; }
        @AuraEnabled
        public String state { get; set; }
    }

    // Method to create a new Lead
   /* @AuraEnabled
    public static Id createLead(LeadWrapper leadWrapper) {
        Lead newLead = new Lead();
        String[] names = leadWrapper.name.split(' ', 2); // Split the name into first and last

        newLead.FirstName = names[0]; // First part of the name
        newLead.LastName = names.size() > 1 ? names[1] : ''; // Last part of the name
        newLead.Title = leadWrapper.jobTitle;
        newLead.Company = leadWrapper.companyName;
        // newLead.Address = leadWrapper.address;
        newLead.Phone = leadWrapper.phoneNumber;
        newLead.Email = leadWrapper.email;
        newLead.Website = leadWrapper.websiteUrl;
        newLead.country = leadWrapper.country;
        newLead.city = leadWrapper.city;
        newlead.street = leadWrapper.street;
        newLead.postalCode = leadWrapper.postalCode;
        newLead.state = leadWrapper.state;

        insert newLead;
        return newLead.Id;
    }*/

    @AuraEnabled
    public static String createLead(LeadWrapper leadWrapper) {
        // Check for existing Lead by Email or Phone
        List<Lead> existingLeads = [
            SELECT Id, FirstName, LastName, Email, Phone
            FROM Lead
            WHERE (Email = :leadWrapper.email AND Email != null)
            OR (Phone = :leadWrapper.phoneNumber AND Phone != null)
            LIMIT 1
        ];

        if (!existingLeads.isEmpty()) {
            // Return a JSON response indicating duplicate
            return JSON.serialize(new Map<String, String>{
                'status' => 'duplicate',
                'message' => 'A lead with the same information already exists.',
                'leadId' => existingLeads[0].Id
            });
        }

        // If no duplicate, create new Lead
        Lead newLead = new Lead();
        String[] names = leadWrapper.name != null ? leadWrapper.name.split(' ', 2) : new String[0];

        newLead.FirstName = names.size() > 0 ? names[0] : '';
        newLead.LastName = names.size() > 1 ? names[1] : 'Unknown';
        newLead.Title = leadWrapper.jobTitle;
        newLead.Company = leadWrapper.companyName;
        newLead.Phone = leadWrapper.phoneNumber;
        newLead.Email = leadWrapper.email;
        newLead.Website = leadWrapper.websiteUrl;
        newLead.Country = leadWrapper.country;
        newLead.City = leadWrapper.city;
        newLead.Street = leadWrapper.street;
        newLead.PostalCode = leadWrapper.postalCode;
        newLead.State = leadWrapper.state;

        insert newLead;

        return JSON.serialize(new Map<String, String>{
            'status' => 'success',
            'message' => 'Lead created successfully.',
            'leadId' => newLead.Id
        });
    }
}