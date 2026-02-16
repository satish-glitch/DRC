/**
* @File Name : DRC_NBC_ShipToCodeGenerator.cls
* @Description : Generates Ship-To Codes for shipping addresses
* @Author : Satish
* @Last Modified On : February 04, 2026
* @Last Modified By : Claude (Added synchronous method)
**/
public class DRC_NBC_ShipToCodeGenerator {
    
    /**
    * Future method - for standalone async calls
    */
    @future
    public static void assignShipToCode(Id orderId) {
        System.debug('orderId at ShipTo code generator (async) >>> ' + orderId);
        assignShipToCodeSync(orderId);
    }
    
    /**
    * Synchronous method - can be called from Queueable or synchronous contexts
    * This is the method that should be called from ShippingAndOrderSyncQueueable
    */
    public static void assignShipToCodeSync(Id orderId) {
        System.debug('orderId at ShipTo code generator (sync) >>> ' + orderId);
        
        try {
            // Query the address record
            List<DRC_NBC_Addresses__c> addresses = [
                SELECT Id, DRC_NBC_Type__c, DRC_NBC_Ship_To_Code__c
                FROM DRC_NBC_Addresses__c
                WHERE DRC_NBC_Order__c = :orderId
                AND DRC_NBC_Type__c = 'Shipping'
                AND DRC_NBC_Ship_To_Code__c = null
                LIMIT 1
            ];
            
            if (addresses.isEmpty()) {
                System.debug('No shipping address found or Ship-To Code already exists');
                return;
            }
            
            DRC_NBC_Addresses__c address = addresses[0];
            
            if (address.DRC_NBC_Type__c != 'Shipping' || !String.isBlank(address.DRC_NBC_Ship_To_Code__c)) {
                System.debug('Address is not a shipping type or already has Ship-To Code');
                return;
            }
            
            // Get current max sequence
            AggregateResult result = [
                SELECT MAX(DRC_NBC_Ship_To_Seq__c) maxSeq
                FROM DRC_NBC_Addresses__c
                WHERE DRC_NBC_Type__c = 'Shipping'
            ];
            
            Decimal maxDecimal = (Decimal) result.get('maxSeq');
            Integer currentMax = (maxDecimal != null) ? maxDecimal.intValue() : 0;
            currentMax++; // Next sequence
            
            address.DRC_NBC_Ship_To_Seq__c = currentMax;
            
            // Generate padded code
            String paddedNumber = String.valueOf(currentMax);
            Integer paddingNeeded = 4 - paddedNumber.length();
            if (paddingNeeded > 0) {
                paddedNumber = '0'.repeat(paddingNeeded) + paddedNumber;
            }
            
            address.DRC_NBC_Ship_To_Code__c = 'SF-' + paddedNumber;
            
            System.debug('Generated Ship-To Code: ' + address.DRC_NBC_Ship_To_Code__c);
            
            // Perform DML
            update address;
            
            System.debug('Ship-To Code successfully assigned and saved');
            
        } catch (Exception ex) {
            System.debug('*** Exception in assignShipToCodeSync ***');
            System.debug('Exception Message: ' + ex.getMessage());
            System.debug('Stack Trace: ' + ex.getStackTraceString());
            throw ex; // Re-throw so caller can handle
        }
    }
}