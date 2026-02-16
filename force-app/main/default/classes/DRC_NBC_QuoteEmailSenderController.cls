public class DRC_NBC_QuoteEmailSenderController {
    public Quote quoteRecord {get; set;}
    public String toAddresses {get; set;}
    public String ccAddresses {get; set;}
    public String bccAddresses {get; set;}
    public String emailSubject {get; set;}
    public String emailBody {get; set;}
    public Boolean hasLoadedDocs {get; set;}
    public List<ContentDocumentWrapper> contentDocuments {get; set;}
    private Id quoteId;
    
    // Constructor
    public DRC_NBC_QuoteEmailSenderController(ApexPages.StandardController stdController) {
        this.quoteId = stdController.getId();
        this.hasLoadedDocs = false;
        this.contentDocuments = new List<ContentDocumentWrapper>();
        
        // Load Quote data
        loadQuoteData();
        
        // Initialize email fields
        initializeEmailFields();
        
        // Generate email body from template
        generateEmailBody();
    }
    
    // Load Quote and related data
    private void loadQuoteData() {
        quoteRecord = [
            SELECT Id, Name, QuoteNumber, Account.Name, Status, ExpirationDate, 
                   CurrencyIsoCode, Subtotal, TotalPrice, GrandTotal, 
                   DRC_NBC_Grand_Total__c, DRC_NBC_Inco_terms__c, Owner.Name, Owner.Title, Owner.Email,
                   Description,
                   (SELECT Id, Product2.Name, Quantity, UnitPrice, TotalPrice, 
                           Product2.DRC_NBC_HSN_SAC_Code__c, DRC_NBC_GST__c 
                    FROM QuoteLineItems 
                    ORDER BY CreatedDate)
            FROM Quote 
            WHERE Id = :quoteId 
            LIMIT 1
        ];
    }
    
    // Initialize email fields with default values
    private void initializeEmailFields() {
        // Default To address - get all contact emails from the account
        List<String> defaultToEmails = new List<String>();
        
        // Get all contact emails from the related account
        List<Contact> contacts = [
            SELECT Email 
            FROM Contact 
            WHERE AccountId = :quoteRecord.Account.Id 
            AND Email != null
            ORDER BY CreatedDate
        ];
        
        for (Contact cont : contacts) {
            if (String.isNotBlank(cont.Email)) {
                defaultToEmails.add(cont.Email);
            }
        }
        
        this.toAddresses = String.join(defaultToEmails, '; ');
        this.ccAddresses = '';
        this.bccAddresses = '';
        
        // Updated subject to include "Quotation" and Description
        String subjectLine = 'Quotation – ' + quoteRecord.Name;
        if (String.isNotBlank(quoteRecord.Description)) {
            subjectLine += ' - ' + quoteRecord.Description;
        }
        this.emailSubject = subjectLine;
    }
    
    // Generate HTML email body based on your template
    private void generateEmailBody() {
        String htmlBody = '';
        
        // Greeting
        htmlBody += '<p>Dear ' + quoteRecord.Account.Name + ',</p>';
        htmlBody += '<p>As discussed, please find below a brief summary of our quotation for your ready reference.</p>';
        
        // Line Items Table with center-aligned text
        htmlBody += '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse: collapse; width: 100%; text-align: center;">';
        htmlBody += '<tr style="background-color: #f2f2f2;">';
        htmlBody += '<th style="text-align: center;">Description</th>';
        htmlBody += '<th style="text-align: center;">Product Name</th>';
        htmlBody += '<th style="text-align: center;">Rate / Unit</th>';
        htmlBody += '<th style="text-align: center;">Quantity</th>';
        htmlBody += '<th style="text-align: center;">GST</th>';
        htmlBody += '<th style="text-align: center;">Total</th>';
        htmlBody += '</tr>';
        
        for (QuoteLineItem item : quoteRecord.QuoteLineItems) {
            htmlBody += '<tr>';
            htmlBody += '<td style="text-align: center;">' + (String.isNotBlank(item.Product2.DRC_NBC_HSN_SAC_Code__c) ? item.Product2.DRC_NBC_HSN_SAC_Code__c : '-') + '</td>';
            htmlBody += '<td style="text-align: center;">' + item.Product2.Name + '</td>';
            htmlBody += '<td style="text-align: center;">' + quoteRecord.CurrencyIsoCode + ' ' + formatNumber(item.UnitPrice) + '</td>';
            htmlBody += '<td style="text-align: center;">' + formatNumber(item.Quantity) + '</td>';
            htmlBody += '<td style="text-align: center;">' + (item.DRC_NBC_GST__c != null ? formatNumber(item.DRC_NBC_GST__c) + '%' : '-') + '</td>';
            htmlBody += '<td style="text-align: center;">' + quoteRecord.CurrencyIsoCode + ' ' + formatNumber(item.TotalPrice) + '</td>';
            htmlBody += '</tr>';
        }
        htmlBody += '</table>';
        
        // Summary Information
        htmlBody += '<p><strong>Grand Total: ' + quoteRecord.CurrencyIsoCode + ' ' + formatNumber(quoteRecord.DRC_NBC_Grand_Total__c) + '</strong></p>';
        htmlBody += '<p><strong>Quotation Validity: ' + formatDate(quoteRecord.ExpirationDate) + '</strong></p>';
        htmlBody += '<p><strong>Currency: ' + quoteRecord.CurrencyIsoCode + '</strong></p>';
        
        // Add Delivery Terms if available
        if (String.isNotBlank(quoteRecord.DRC_NBC_Inco_terms__c)) {
            htmlBody += '<p><strong>Delivery Terms: ' + quoteRecord.DRC_NBC_Inco_terms__c + '</strong></p>';
        }
        
        // Note about attached documents
        htmlBody += '<p>Kindly note that the attached quotation document contains the complete commercial terms and conditions and shall be treated as the final and conclusive offer.</p>';
        
        // Signature
        htmlBody += '<p>Warm regards, <br/>';
        htmlBody += quoteRecord.Owner.Name + ' <br/>';
        if (String.isNotBlank(quoteRecord.Owner.Title)) {
            htmlBody += quoteRecord.Owner.Title + ' <br/>';
        }
        htmlBody += 'D. R. Coats Inks &amp; Resins Pvt. Ltd.</p>';
        
        htmlBody += '<hr/>';
        
        this.emailBody = htmlBody;
    }
    
    // Load Content Documents attached to the Quote
    public PageReference loadContentDocuments() {
        hasLoadedDocs = true;
        contentDocuments.clear();
        
        try {
            List<ContentDocumentLink> docLinks = [
                SELECT ContentDocumentId, ContentDocument.Title, 
                       ContentDocument.FileType, ContentDocument.ContentSize, 
                       ContentDocument.LastModifiedDate
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :quoteId 
                ORDER BY ContentDocument.LastModifiedDate DESC
            ];
            
            for (ContentDocumentLink link : docLinks) {
                ContentDocumentWrapper wrapper = new ContentDocumentWrapper();
                wrapper.documentId = link.ContentDocumentId;
                wrapper.fileName = link.ContentDocument.Title;
                wrapper.fileType = link.ContentDocument.FileType;
                wrapper.fileSize = formatFileSize(link.ContentDocument.ContentSize);
                wrapper.lastModifiedDate = link.ContentDocument.LastModifiedDate;
                wrapper.isSelected = false;
                contentDocuments.add(wrapper);
            }
            
            if (contentDocuments.isEmpty()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 
                    'No files found. Please upload files to the Quote record first.'));
            }
            
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                'Error loading files: ' + e.getMessage()));
        }
        
        return null;
    }
    
    // Send Email Action
    public PageReference sendEmail() {
        try {
            // Validate email addresses
            if (String.isBlank(toAddresses)) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                    'Please enter at least one To email address.'));
                return null;
            }
            
            // Validate that at least one file is selected
            Boolean hasAttachment = false;
            for (ContentDocumentWrapper wrapper : contentDocuments) {
                if (wrapper.isSelected) {
                    hasAttachment = true;
                    break;
                }
            }
            
            if (!hasAttachment) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 
                    'No files selected. Email will be sent without attachments.'));
            }
            
            // Create email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Set recipients
            email.setToAddresses(parseEmailAddresses(toAddresses));
            if (String.isNotBlank(ccAddresses)) {
                email.setCcAddresses(parseEmailAddresses(ccAddresses));
            }
            if (String.isNotBlank(bccAddresses)) {
                email.setBccAddresses(parseEmailAddresses(bccAddresses));
            }
            
            // Set subject and body
            email.setSubject(emailSubject);
            email.setHtmlBody(emailBody);
            
            // Set WhatId to associate email with Quote
            email.setWhatId(quoteId);
            
            // Save email as activity
            email.setSaveAsActivity(true);
            
            // Add selected Content Documents as attachments
            List<Messaging.EmailFileAttachment> attachments = getSelectedContentDocumentAttachments();
            if (!attachments.isEmpty()) {
                email.setFileAttachments(attachments);
            }
            
            // Send email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
            if (results[0].isSuccess()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.CONFIRM, 
                    'Email sent successfully to ' + toAddresses + 
                    (attachments.isEmpty() ? ' (no attachments)' : ' with ' + attachments.size() + ' attachment(s)')));
                
                // Redirect back to Quote after showing message
                PageReference quotePage = new PageReference('/' + quoteId);
                quotePage.setRedirect(true);
                return quotePage;
            } else {
                String errorMsg = 'Error sending email: ';
                for (Messaging.SendEmailError err : results[0].getErrors()) {
                    errorMsg += err.getMessage() + ' ';
                }
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, errorMsg));
                return null;
            }
            
        } catch (Exception e) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                'Unexpected error: ' + e.getMessage() + ' | Line: ' + e.getLineNumber()));
            return null;
        }
    }
    
    // Get selected Content Document attachments
    private List<Messaging.EmailFileAttachment> getSelectedContentDocumentAttachments() {
        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        List<Id> selectedDocIds = new List<Id>();
        
        for (ContentDocumentWrapper wrapper : contentDocuments) {
            if (wrapper.isSelected) {
                selectedDocIds.add(wrapper.documentId);
            }
        }
        
        if (selectedDocIds.isEmpty()) {
            return attachments;
        }
        
        // Get the latest version of each selected document
        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, VersionData 
            FROM ContentVersion 
            WHERE ContentDocumentId IN :selectedDocIds 
            AND IsLatest = true
        ];
        
        for (ContentVersion version : versions) {
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            String fileName = version.Title;
            if (String.isNotBlank(version.FileExtension)) {
                fileName += '.' + version.FileExtension;
            }
            attachment.setFileName(fileName);
            attachment.setBody(version.VersionData);
            attachments.add(attachment);
        }
        
        return attachments;
    }
    
    // Parse email addresses from string
    private List<String> parseEmailAddresses(String emailString) {
        List<String> emails = new List<String>();
        if (String.isBlank(emailString)) {
            return emails;
        }
        
        // Split by semicolon or comma
        String[] parts = emailString.split('[;,]');
        for (String part : parts) {
            String trimmed = part.trim();
            if (String.isNotBlank(trimmed)) {
                emails.add(trimmed);
            }
        }
        
        return emails;
    }
    
    // Format number with 2 decimal places
    private String formatNumber(Decimal num) {
        if (num == null) return '0.00';
        return String.valueOf(num.setScale(2));
    }
    
    // Format date
    private String formatDate(Date dt) {
        if (dt == null) return '';
        DateTime dateTimeValue = DateTime.newInstance(dt.year(), dt.month(), dt.day());
        return dateTimeValue.format('dd-MMM-yyyy');
    }
    
    // Format file size
    private String formatFileSize(Integer bytes) {
        if (bytes == null || bytes == 0) return '0 B';
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1024 * 1024) return String.valueOf(bytes / 1024) + ' KB';
        return String.valueOf(bytes / (1024 * 1024)) + ' MB';
    }
    
    // Cancel action
    public PageReference cancel() {
        PageReference quotePage = new PageReference('/' + quoteId);
        quotePage.setRedirect(true);
        return quotePage;
    }
    
    // Wrapper class for Content Documents
    public class ContentDocumentWrapper {
        public Id documentId {get; set;}
        public String fileName {get; set;}
        public String fileType {get; set;}
        public String fileSize {get; set;}
        public DateTime lastModifiedDate {get; set;}
        public Boolean isSelected {get; set;}
    }
}