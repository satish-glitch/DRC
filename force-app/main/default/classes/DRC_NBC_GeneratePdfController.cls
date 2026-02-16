/**
* @File Name : DRC_NBC_GeneratePdfController.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : November 4, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | November 4, 2025 |   | Initial Version
**/

public class DRC_NBC_GeneratePdfController {
	@AuraEnabled
    public static void saveOrderPdfToContent(String recordId, String vfPageUrl) {
        try {
            // Step 1: Fetch the Order record
            Order ord = [
                SELECT Id, Name, DRC_NBC_Type__c,
                       DRC_NBC_Import_Starting_Sequence__c,
                       DRC_NBC_Invoice_Export_Sequence_Number__c,
                       Account.Name
                FROM Order
                WHERE Id = :recordId
                LIMIT 1
            ];

            String accountName = ord.Account != null && ord.Account.Name != null ? ord.Account.Name : 'NoAccount';
           // String formattedDate = DateTime.now().format().replace('/', '-').replace(':', '-');
            String formattedDate = DateTime.now().format('yyyy-MM-dd_HH:mm');
            String fileName = 'Order_' + accountName + '_' + formattedDate;

            // Step 2: Generate PDF
            PageReference pdfPage = new PageReference(vfPageUrl);
            Blob pdfBlob;

            if (!Test.isRunningTest()) {
                System.debug('Generating PDF for Order ID: ' + recordId);
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

            System.debug('PDF saved. Now updating Order sequence number.');

            // Step 4: Assign sequence number after PDF is saved
            assignOrderSequenceNumber(ord);

        } catch (Exception ex) {
            String msg = ex.getMessage() != null ? ex.getMessage() : 'Unknown error';
            System.debug('Exception: ' + ex);
            throw new AuraHandledException('Error saving PDF: ' + msg);
        }
    }

    public static void assignOrderSequenceNumber(Order ord) {
        Boolean shouldUpdateOrder = false;
        Integer newSequenceNumber;

        // Assign for Domestic Orders
        if (ord.DRC_NBC_Type__c == 'Domestic' &&
            ord.DRC_NBC_Import_Starting_Sequence__c == null) {

            AggregateResult[] result = [
                SELECT MAX(DRC_NBC_Import_Starting_Sequence__c) maxSeq
                FROM Order
                WHERE DRC_NBC_Type__c = 'Domestic'
            ];

            Decimal maxDecimal = (result.size() > 0 && result[0].get('maxSeq') != null)
                ? (Decimal) result[0].get('maxSeq')
                : Decimal.valueOf(Label.DRC_NBC_Import_Starting_Sequence);

            Integer lastUsed = maxDecimal.intValue();
            newSequenceNumber = lastUsed + 1;

            ord.DRC_NBC_Import_Starting_Sequence__c = Decimal.valueOf(newSequenceNumber);
            shouldUpdateOrder = true;
        }

        // Assign for Export Orders
        if (ord.DRC_NBC_Type__c == 'Export' &&
            ord.DRC_NBC_Invoice_Export_Sequence_Number__c == null) {

            AggregateResult[] result = [
                SELECT MAX(DRC_NBC_Invoice_Export_Sequence_Number__c) maxSeq
                FROM Order
                WHERE DRC_NBC_Type__c = 'Export'
            ];

            Decimal maxDecimal = (result.size() > 0 && result[0].get('maxSeq') != null)
                ? (Decimal) result[0].get('maxSeq')
                : Decimal.valueOf(Label.DRC_NBC_Export_Starting_Sequence);

            Integer lastUsed = maxDecimal.intValue();
            newSequenceNumber = lastUsed + 1;

            ord.DRC_NBC_Invoice_Export_Sequence_Number__c = Decimal.valueOf(newSequenceNumber);
            shouldUpdateOrder = true;
        }

        if (shouldUpdateOrder) {
            update ord;
            System.debug('Order updated with new sequence number: ' + newSequenceNumber);
        }
    }

    @AuraEnabled
    public static void saveSampleOrderPdfToContent(String recordId, String vfPageUrl) {
        try {
            // Step 1: Fetch the Order record
            Order ord = [
                SELECT Id, Name, Type,
                       DRC_NBC_Sample_Sequence_Number__c,
                       Account.Name
                FROM Order
                WHERE Id = :recordId
                LIMIT 1
            ];

            String accountName = ord.Account != null && ord.Account.Name != null ? ord.Account.Name : 'NoAccount';
            String formattedDate = DateTime.now().format().replace('/', '-').replace(':', '-');
            String fileName = 'Order_' + accountName + '_' + formattedDate;

            // Step 2: Generate PDF
            PageReference pdfPage = new PageReference(vfPageUrl);
            Blob pdfBlob;

            if (!Test.isRunningTest()) {
                System.debug('Generating PDF for Order ID: ' + recordId);
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

            System.debug('PDF saved. Now updating Order sequence number.');

            // Step 4: Assign sequence number after PDF is saved
            assignOrderSequenceNumberSample(ord);

        } catch (Exception ex) {
            String msg = ex.getMessage() != null ? ex.getMessage() : 'Unknown error';
            System.debug('Exception: ' + ex);
            throw new AuraHandledException('Error saving PDF: ' + msg);
        }
    }

    public static void assignOrderSequenceNumberSample(Order ord) {
        Boolean shouldUpdateOrder = false;
        Integer newSequenceNumber;

        // Assign for Domestic Orders
        if (ord.Type == 'Sample order' &&
            ord.DRC_NBC_Sample_Sequence_Number__c == null) {

            AggregateResult[] result = [
                SELECT MAX(DRC_NBC_Sample_Sequence_Number__c) maxSeq
                FROM Order
                WHERE Type = 'Sample order'
            ];

            Decimal maxDecimal = (result.size() > 0 && result[0].get('maxSeq') != null)
                ? (Decimal) result[0].get('maxSeq')
                : Decimal.valueOf(Label.DRC_NBC_Import_Starting_Sequence);

            Integer lastUsed = maxDecimal.intValue();
            newSequenceNumber = lastUsed + 1;

            ord.DRC_NBC_Sample_Sequence_Number__c = Decimal.valueOf(newSequenceNumber);
            shouldUpdateOrder = true;
        }
 
        if (shouldUpdateOrder) {
            update ord;
            System.debug('Order updated with new sequence number: ' + newSequenceNumber);
        }
    }
}