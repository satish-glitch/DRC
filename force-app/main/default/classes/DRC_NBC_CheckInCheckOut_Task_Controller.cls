/**
* @File Name : DRC_NBC_CheckInCheckOut_Task_Controller.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : September 4, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 4, 2025 |   | Initial Version
**/

public class DRC_NBC_CheckInCheckOut_Task_Controller {

@AuraEnabled
    public static Task getTaskRecord(String recordId) {
        try {
            return [
                SELECT Id, WhoId, DRC_NBC_Is_CheckedIn__c, 
                       Account.BillingLatitude, Account.BillingLongitude,
                       Account.BillingStreet, Account.BillingCity, Account.BillingState
                FROM Task 
                WHERE Id = :recordId 
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching task: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> updateTask(
        String recordId, 
        Decimal latitude, 
        Decimal longitude, 
        String commnent, 
        Boolean comp
    ) {
        try {
            Task taskToUpdate = [
                SELECT Id, DRC_NBC_Is_CheckedIn__c, WhoId,
                       Account.BillingLatitude, Account.BillingLongitude
                FROM Task 
                WHERE Id = :recordId 
                LIMIT 1
            ];
            
            // Calculate distance using Salesforce's Location class
            String calculatedDistance = calculateDistanceWithLocationClass(
                latitude, 
                longitude, 
                taskToUpdate
            );
            
            // Determine if checking in or out
            if (taskToUpdate.DRC_NBC_Is_CheckedIn__c) {
                // Checking out
                taskToUpdate.DRC_NBC_Is_CheckedIn__c = false;
                taskToUpdate.DRC_NBC_Check_Out_Date_Time__c = System.now();
                taskToUpdate.DRC_NBC_Check_Out_Latitude__c = String.valueOf(latitude);
                taskToUpdate.DRC_NBC_Check_Out_Longitude__c = String.valueOf(longitude);
                taskToUpdate.DRC_NBC_Distance__c = calculatedDistance;
                taskToUpdate.DRC_NBC_Check_out_Comment__c = commnent;
                taskToUpdate.DRC_NBC_Non_Compliance__c = !comp; // Inverted because comp=true means non-compliant
            } else {
                // Checking in
                taskToUpdate.DRC_NBC_Is_CheckedIn__c = true;
                taskToUpdate.DRC_NBC_Check_In_Date_Time__c = System.now();
                taskToUpdate.DRC_NBC_Check_In_Latitude__c = String.valueOf(latitude);
                taskToUpdate.DRC_NBC_Check_In_Longitude__c = String.valueOf(longitude);
                taskToUpdate.DRC_NBC_Distance__c = calculatedDistance;
                taskToUpdate.DRC_NBC_Check_In_Comment__c = commnent;
                taskToUpdate.DRC_NBC_Non_Compliance__c = !comp; // Inverted because comp=true means non-compliant
            }
            
            update taskToUpdate;
            
            return new Map<String, Object>{
                'success' => true,
                'distance' => calculatedDistance
            };
            
        } catch (Exception e) {
            throw new AuraHandledException('Error updating task: ' + e.getMessage());
        }
    }
    
    /**
     * Calculate distance using Salesforce's built-in Location class
     * This ensures consistency with Salesforce's geocoding system
     */
    private static String calculateDistanceWithLocationClass(
        Decimal userLat, 
        Decimal userLong, 
        Task taskRecord
    ) {
        try {
            Decimal targetLat;
            Decimal targetLong;
            
            // Determine which location to use (Account or WhoId)
            if (taskRecord.WhoId != null && 
                (String.valueOf(taskRecord.WhoId).startsWith('00Q') || 
                 String.valueOf(taskRecord.WhoId).startsWith('003'))) {
                // Get lat/long from Lead or Contact
                Map<String, Decimal> whoIdLocation = getLatLongFromWhoId(
                    taskRecord.WhoId.getSObjectType().getDescribe().getName(),
                    taskRecord.WhoId
                );
                targetLat = whoIdLocation.get('Latitude');
                targetLong = whoIdLocation.get('Longitude');
            } else if (taskRecord.Account != null) {
                // Use Account billing address
                targetLat = taskRecord.Account.BillingLatitude;
                targetLong = taskRecord.Account.BillingLongitude;
            } else {
                return 'N/A';
            }
            
            // Validate coordinates exist
            if (targetLat == null || targetLong == null) {
                return 'N/A';
            }
            
            // Create Location instances
            System.Location userLocation = System.Location.newInstance(userLat, userLong);
            System.Location targetLocation = System.Location.newInstance(targetLat, targetLong);
            
            // Calculate distance using Salesforce's built-in method
            Double distanceInKm = System.Location.getDistance(userLocation, targetLocation, 'km');
            Decimal distanceDecimal = Decimal.valueOf(distanceInKm);
            return distanceDecimal.setScale(2) + ' KM';

            
        } catch (Exception e) {
            System.debug('Error calculating distance: ' + e.getMessage());
            return 'Error';
        }
    }
    
    /**
     * Get coordinates from Lead or Contact record
     */
    private static Map<String, Decimal> getLatLongFromWhoId(String sObjectName, Id recordId) {
        Map<String, Decimal> result = new Map<String, Decimal>();
        
        try {
            if (sObjectName == 'Lead') {
                Lead leadRecord = [
                    SELECT Latitude, Longitude 
                    FROM Lead 
                    WHERE Id = :recordId 
                    LIMIT 1
                ];
                result.put('Latitude', leadRecord.Latitude);
                result.put('Longitude', leadRecord.Longitude);
            } else if (sObjectName == 'Contact') {
                Contact contactRecord = [
                    SELECT MailingLatitude, MailingLongitude 
                    FROM Contact 
                    WHERE Id = :recordId 
                    LIMIT 1
                ];
                result.put('Latitude', contactRecord.MailingLatitude);
                result.put('Longitude', contactRecord.MailingLongitude);
            }
        } catch (Exception e) {
            System.debug('Error fetching coordinates: ' + e.getMessage());
        }
        
        return result;
    }
   
}