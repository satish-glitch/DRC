/**
* @File Name : DRC_NBC_GenerateQuotePdfController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : November 3, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 3, 2025 |   | Initial Version
**/

public with sharing class DRC_NBC_GenerateQuotePdfController {
    
    @AuraEnabled
    public static void saveQuotePdfToContent(String recordId, String vfPageUrl) {
        try {
            Quote quoteRec = [
                SELECT Id, Name, QuoteNumber, Account.Name,
                DRC_NBC_Type__c,
                DRC_NBC_Import_Starting_Sequence__c, Opportunity.Account.Name,
                DRC_NBC_Invoice_Export_Sequence_Number__c,DRC_NBC_Special_Requirements__c
                FROM Quote
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            String accountName = quoteRec.Opportunity.Account != null ? quoteRec.Opportunity.Account.Name : '';
            //String formattedDate = DateTime.now().format().replace('/', '-').replace(':', ':');
            String formattedDate = DateTime.now().format('yyyy-MM-dd_HH:mm');
            String fileName = 'Quote_' + accountName + '_' + formattedDate;
            
            // Step 2: Generate PDF
            PageReference pdfPage = new PageReference(vfPageUrl);
            Blob pdfBlob;
            
            if (!Test.isRunningTest()) {
                System.debug('Generating PDF for Quote ID: ' + recordId);
                pdfBlob = pdfPage.getContentAsPDF();
            } else {
                pdfBlob = Blob.valueOf('Unit test PDF');
            }
            
            // Step 3: Save to ContentVersion
            ContentVersion contentVersion = new ContentVersion();
            contentVersion.Title = fileName;
            contentVersion.PathOnClient = fileName + '.pdf';
            contentVersion.VersionData = pdfBlob;
            contentVersion.FirstPublishLocationId = recordId;
            insert contentVersion;
            
                    // Debug inserted ContentVersion fields
            System.debug('Inserted ContentVersion Id: ' + contentVersion.Id);
            System.debug('Inserted ContentVersion Title: ' + contentVersion.Title);

            // Optionally fetch related ContentDocument Id
            Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id].ContentDocumentId;
            System.debug('Related ContentDocument Id: ' + contentDocId);
            // Assign sequence number
            assignQuoteSequenceNumber(quoteRec);
            
        } catch (Exception ex) {
            throw new AuraHandledException('Error saving Quote PDF: ' + ex.getMessage());
        }
    }
    
    
    private static void assignQuoteSequenceNumber(Quote quoteRec) {
        Boolean shouldUpdate = false;
        Integer newSequenceNumber;
        
        // Domestic quote logic
        if (quoteRec.DRC_NBC_Type__c == 'Domestic' &&
            quoteRec.DRC_NBC_Import_Starting_Sequence__c == null) {
                
                AggregateResult[] result = [
                    SELECT MAX(DRC_NBC_Import_Starting_Sequence__c) maxSeq
                    FROM Quote
                    WHERE DRC_NBC_Type__c = 'Domestic'
                ];
                
                Decimal maxDecimal = (result.size() > 0 && result[0].get('maxSeq') != null)
                    ? (Decimal) result[0].get('maxSeq')
                    : Decimal.valueOf(Label.DRC_NBC_Import_Starting_Sequence);
                
                newSequenceNumber = maxDecimal.intValue() + 1;
                quoteRec.DRC_NBC_Import_Starting_Sequence__c = newSequenceNumber;
                shouldUpdate = true;
            }
        
        // Export quote logic
        if (quoteRec.DRC_NBC_Type__c == 'Export' &&
            quoteRec.DRC_NBC_Invoice_Export_Sequence_Number__c == null) {
                
                AggregateResult[] result = [
                    SELECT MAX(DRC_NBC_Invoice_Export_Sequence_Number__c) maxSeq
                    FROM Quote
                    WHERE DRC_NBC_Type__c = 'Export'
                ];
                
                Decimal maxDecimal = (result.size() > 0 && result[0].get('maxSeq') != null)
                    ? (Decimal) result[0].get('maxSeq')
                    : Decimal.valueOf(Label.DRC_NBC_Export_Starting_Sequence);
                
                newSequenceNumber = maxDecimal.intValue() + 1;
                quoteRec.DRC_NBC_Invoice_Export_Sequence_Number__c = newSequenceNumber;
                shouldUpdate = true;
            }
        
        if (shouldUpdate) {
            update quoteRec;
            System.debug('Quote updated with sequence number: ' + newSequenceNumber);
        }
    }
    
}