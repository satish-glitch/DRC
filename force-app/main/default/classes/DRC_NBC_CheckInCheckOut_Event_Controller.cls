public with sharing class DRC_NBC_CheckInCheckOut_Event_Controller {
    
    @AuraEnabled
    public static Event getEventRecord(String recordId) {
        try {
            return [
                SELECT Id, WhoId, DRC_NBC_Is_CheckedIn__c, DRC_NBC_Is_Checked_Out__c,
                       Account.BillingLatitude, Account.BillingLongitude,
                       Account.BillingStreet, Account.BillingCity, Account.BillingState
                FROM Event
                WHERE Id = :recordId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching event: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> updateEvent(
        String recordId,
        Decimal latitude,
        Decimal longitude,
        String distance,
        String commnent,
        Boolean comp
    ) {
        try {
            Event eventToUpdate = [
                SELECT Id, DRC_NBC_Is_CheckedIn__c, DRC_NBC_Is_Checked_Out__c
                FROM Event
                WHERE Id = :recordId
                LIMIT 1
            ];

            // ✅ Handle distance
            String calculatedDistance = String.isNotBlank(distance) ? distance : '0.00';
            String distanceWithUnit = calculatedDistance + ' KM';
            Decimal distanceValue = Decimal.valueOf(calculatedDistance);

            // ✅ Determine compliance
            Boolean isNonCompliant = (distanceValue > 2);

            // ✅ Check-In / Check-Out logic
            if (!eventToUpdate.DRC_NBC_Is_CheckedIn__c) {
                // 🔄 CHECK-IN
                eventToUpdate.DRC_NBC_Is_CheckedIn__c = true;
                eventToUpdate.DRC_NBC_Check_In_Date_Time__c = System.now();
                eventToUpdate.DRC_NBC_Check_In_Latitude__c = String.valueOf(latitude);
                eventToUpdate.DRC_NBC_Check_In_Longitude__c = String.valueOf(longitude);
                eventToUpdate.DRC_NBC_Check_In_Comment__c = commnent;
            } 
            else {
                // 🔄 CHECK-OUT
                eventToUpdate.DRC_NBC_Is_Checked_Out__c = true;
                eventToUpdate.DRC_NBC_Check_Out_Date_Time__c = System.now();
                eventToUpdate.DRC_NBC_Check_Out_Latitude__c = String.valueOf(latitude);
                eventToUpdate.DRC_NBC_Check_Out_Longitude__c = String.valueOf(longitude);
                eventToUpdate.DRC_NBC_Check_Out_Comment__c = commnent;
            }

            // ✅ Common fields
            eventToUpdate.DRC_NBC_Distance__c = distanceWithUnit;
            eventToUpdate.DRC_NBC_Non_Compliance__c = isNonCompliant;

            update eventToUpdate;

            return new Map<String, Object>{
                'success' => true,
                'distance' => distanceWithUnit,
                'isCheckedIn' => eventToUpdate.DRC_NBC_Is_CheckedIn__c,
                'isCheckedOut' => eventToUpdate.DRC_NBC_Is_Checked_Out__c,
                'isNonCompliant' => isNonCompliant
            };

        } catch (Exception e) {
            throw new AuraHandledException('Error updating event: ' + e.getMessage());
        }
    }
}