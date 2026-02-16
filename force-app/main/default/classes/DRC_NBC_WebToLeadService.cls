@RestResource(urlMapping='/WebToLeadService')
global with sharing class DRC_NBC_WebToLeadService {
    @HttpPost
    global static void createLead() {
        String payload = RestContext.request.requestBody.toString(); 
        DRC_NBC_Integration_Payload.WebToLeadPayLoad requestedPayload = validatePayload(payload);
        
        List<DRC_NBC_Lead_Product__c> productsToInsert = new List<DRC_NBC_Lead_Product__c>();
        Lead newLead;
        Set<String> interestedChemistries = new Set<String>();
        
        try {
            // Prepare chemistry set
            if (requestedPayload.interestedChemistry != null && !requestedPayload.interestedChemistry.isEmpty()) {
                for (String val : requestedPayload.interestedChemistry) {
                    if (!String.isBlank(val)) {
                        interestedChemistries.add(val.trim());
                    }
                }
            }
            
            // Create Lead record
            newLead = new Lead();
            newLead.FirstName = requestedPayload.firstName;
            newLead.LastName = requestedPayload.lastName;
            newLead.Company = requestedPayload.company;
            newLead.Email = requestedPayload.email;
            newLead.Country = requestedPayload.country;
            newLead.Description = requestedPayload.message;
            newLead.Phone = requestedPayload.phone;
            newLead.LeadSource = 'Website';
            newLead.DRC_NBC_Interested_Chemistry__c = String.join(new List<String>(interestedChemistries), ';');
            newLead.DRC_NBC_Application_Area__c = 
                requestedPayload.applicationArea != null ? String.join(new List<String>(requestedPayload.applicationArea), ';') : null;
            newLead.DRC_NBC_Others_Custom_Product__c = 
                !String.isBlank(requestedPayload.otherProduct) ? requestedPayload.otherProduct : null;
            // ------------------ APPLY LEAD ASSIGNMENT RULE ----------------------
            Database.DMLOptions dmo = new Database.DMLOptions();
            dmo.assignmentRuleHeader.useDefaultRule = true;
            newLead.setOptions(dmo);
            
            insert newLead;
            
            // ------------------ SEND EMAIL TO LEAD ----------------------
            EmailTemplate template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'DRC_NBC_EmailTemplateForLead'LIMIT 1];
            // Get Org-Wide Email Address
            OrgWideEmailAddress owe = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'ganesh@novabiz.co.in' LIMIT 1];

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTargetObjectId(newLead.Id);        
            email.setTemplateId(template.Id);           
            email.setSaveAsActivity(false);             
            email.setTreatTargetObjectAsRecipient(true);
            email.setOrgWideEmailAddressId(owe.Id);

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });

            
            // Match interested chemistry with Product2.Name
           /* if (!interestedChemistries.isEmpty()) {
                List<Product2> matchedProducts = [
                    SELECT Id, Name, DRC_NBC_Product_Code__c
                    FROM Product2
                    WHERE Name IN :interestedChemistries
                ];
                for (Product2 prod : matchedProducts) {
                    DRC_NBC_Lead_Product__c newProduct = new DRC_NBC_Lead_Product__c(
                        DRC_NBC_Lead__c = newLead.Id,
                        DRC_NBC_Product__c = prod.Id
                    );
                    productsToInsert.add(newProduct);
                }
                if (!productsToInsert.isEmpty()) {
                    insert productsToInsert;
                }
            }*/
            
            RestContext.response.statusCode = 200;
           // RestContext.response.responseBody = Blob.valueOf('{"Result":"Success", "SfId":"' + newLead.Id + '"}');
            RestContext.response.responseBody = Blob.valueOf('{"Result":"Success"}');
        }
        catch (DRC_NBC_CustomException e) {
            RestContext.response.statusCode = 400;
            RestContext.response.responseBody = Blob.valueOf('{"Result":"Error", "Message":"' + e.getMessage() + '"}');
        }
        catch (Exception e) {
            RestContext.response.statusCode = 500;
            
            // Handle duplicates gracefully
            if (e.getMessage().contains('DUPLICATES_DETECTED')) {
                RestContext.response.statusCode = 200;
                
                List<Product2> matchedProducts = [
                    SELECT Id, Name, DRC_NBC_Product_Code__c
                    FROM Product2
                    WHERE Name IN :interestedChemistries
                ];
                
                for (Product2 prod : matchedProducts) {
                    DRC_NBC_Lead_Product__c newProduct = new DRC_NBC_Lead_Product__c(
                        DRC_NBC_Lead__c = newLead.Id,
                        DRC_NBC_Product__c = prod.Id
                    );
                    productsToInsert.add(newProduct);
                }
                
                if (!productsToInsert.isEmpty()) {
                    insert productsToInsert;
                }
                
                RestContext.response.responseBody = Blob.valueOf('{"Result":"Success", "SfId":"' + newLead.Id + '"}');
            } else {
                RestContext.response.responseBody = Blob.valueOf(
                    '{"Result":"Error", "Message":"Internal Server Error: ' + e.getMessage() + '"}'
                );
            }
        }
    }
    
    // ---------------------- Payload Validation ----------------------
    public static DRC_NBC_Integration_Payload.WebToLeadPayLoad validatePayload(String payload) {
        if (String.isBlank(payload)) {
            throw new DRC_NBC_CustomException('Payload cannot be null or empty');
        }
        
        DRC_NBC_Integration_Payload.WebToLeadPayLoad requestData;
        try {
            requestData = (DRC_NBC_Integration_Payload.WebToLeadPayLoad) 
                JSON.deserialize(payload, DRC_NBC_Integration_Payload.WebToLeadPayLoad.class);
        } catch (Exception e) {
            throw new DRC_NBC_CustomException('Invalid JSON format: ' + e.getMessage());
        }
        
        // Field-level validations
        if (String.isBlank(requestData.company)) {
            throw new DRC_NBC_CustomException('Company cannot be null or empty');
        }
        if (String.isBlank(requestData.firstName)) {
            throw new DRC_NBC_CustomException('FirstName cannot be null or empty');
        }
        if (String.isBlank(requestData.lastName)) {
            throw new DRC_NBC_CustomException('LastName cannot be null or empty');
        }
        if (String.isBlank(requestData.email)) {
            throw new DRC_NBC_CustomException('Email cannot be null or empty');
        }
        if (String.isBlank(requestData.message)) {
            throw new DRC_NBC_CustomException('Message cannot be null or empty');
        }
        if (String.isBlank(requestData.country)) {
            throw new DRC_NBC_CustomException('Country cannot be null or empty');
        }
        if (requestData.interestedChemistry == null || requestData.interestedChemistry.isEmpty()) {
            throw new DRC_NBC_CustomException('Interested Chemistry list cannot be null or empty');
        }
        
        return requestData;
    }
}