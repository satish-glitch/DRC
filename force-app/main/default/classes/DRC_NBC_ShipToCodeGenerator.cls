public class DRC_NBC_ShipToCodeGenerator {

    private static Boolean isRunning = false;

    /**
     * Call this from DRC_NBC_Addresses__c after insert trigger
     */
    public static void assignShipToCodeSync(List<DRC_NBC_Addresses__c> newAddresses) {
        try {
            Set<Id> addressIds = new Set<Id>();
            for (DRC_NBC_Addresses__c addr : newAddresses) {
                if (addr.Id != null) {
                    addressIds.add(addr.Id);
                }
            }

            if (addressIds.isEmpty()) {
                return;
            }

            List<DRC_NBC_Addresses__c> addressesToProcess = [
                SELECT Id,
                       DRC_NBC_Type__c,
                       DRC_NBC_Ship_To_Code__c,
                       DRC_NBC_Ship_To_Seq__c
                FROM DRC_NBC_Addresses__c
                WHERE Id IN :addressIds
                  AND DRC_NBC_Type__c = 'Shipping'
                ORDER BY CreatedDate, Id
            ];

            if (addressesToProcess.isEmpty()) {
                System.debug('No shipping addresses found without Ship-To Code');
                return;
            }

            AggregateResult result = [
                SELECT MAX(DRC_NBC_Ship_To_Seq__c) maxSeq
                FROM DRC_NBC_Addresses__c
                WHERE DRC_NBC_Type__c = 'Shipping'
            ];

            Decimal maxDecimal = (Decimal) result.get('maxSeq');
            Integer currentMax = (maxDecimal != null) ? maxDecimal.intValue() : 0;

            for (DRC_NBC_Addresses__c address : addressesToProcess) {
                currentMax++;

                address.DRC_NBC_Ship_To_Seq__c = currentMax;
                address.DRC_NBC_Ship_To_Code__c = buildShipToCode(currentMax);

                System.debug('Generated Ship-To Code for Address ' + address.Id + ' => ' + address.DRC_NBC_Ship_To_Code__c);
            }

            update addressesToProcess;

            System.debug('Ship-To Codes successfully assigned');
        } catch (Exception ex) {
            System.debug('*** Exception in assignShipToCodeSync ***');
            System.debug('Exception Message: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            throw ex;
        } finally {
            isRunning = false;
        }
    }

    private static String buildShipToCode(Integer seq) {
        String paddedNumber = String.valueOf(seq);

        while (paddedNumber.length() < 4) {
            paddedNumber = '0' + paddedNumber;
        }

        return Label.DRC_NBC_Ship_To_Code + paddedNumber;
    }
}