({
    doInit: function(component, event, helper) {
        let recordId = component.get("v.recordId");
        
        // If recordId not set, try to get from URL
        if (!recordId) {
            let urlParams = new URLSearchParams(window.location.search);
            if (urlParams.has("recordId")) {
                recordId = urlParams.get("recordId");
            }
            else if (urlParams.has("inContextOfRef")) {
                try {
                    let ref = urlParams.get("inContextOfRef");
                    let decoded = JSON.parse(atob(ref));
                    recordId = decoded.attributes.recordId;
                } catch (e) {
                    console.error("Error decoding inContextOfRef:", e);
                }
            }
            component.set("v.recordId", recordId);
        }
        
        console.log("✔ Final Record ID: " + recordId);
        
        // Check if Quote using helper
        if (recordId) {
            helper.checkIfQuote(component, recordId);
        } else {
            component.set("v.isLoaded", true);
        }
    },
    
    handleRecordLoaded: function(component, event, helper) {
        // This gets called when force:recordData loads the record
        var record = component.get("v.record");
        if (record && record.attributes) {
            var objectType = record.attributes.type;
            var isQuote = (objectType === "Quote");
            
            console.log("✔ Object Type from recordData: " + objectType);
            console.log("✔ Is Quote: " + isQuote);
            
            component.set("v.isQuote", isQuote);
            component.set("v.isLoaded", true);
        }
    },
    
    handleLWCCancel: function(component, event, helper) {
        var recordId = component.get("v.recordId");
        
        console.log('✔ Cancel event received from LWC, navigating to:', recordId);
        
        $A.get("e.force:closeQuickAction").fire();
        
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            recordId: recordId,
            slideDevName: "detail"
        });
        navEvt.fire();
        
        setTimeout(function() {
            $A.get('e.force:refreshView').fire();
        }, 100);
    }
})