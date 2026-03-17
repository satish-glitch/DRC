({
    doInit: function(component, event, helper) {
        let recordId = component.get("v.recordId");

        // Resolve recordId from URL if not already set
        if (!recordId) {
            let urlParams = new URLSearchParams(window.location.search);
            if (urlParams.has("recordId")) {
                recordId = urlParams.get("recordId");
            } else if (urlParams.has("inContextOfRef")) {
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

        // Navigation info
        let urlParams = new URLSearchParams(window.location.search);
        let navigationLocation = urlParams.get('navigationLocation');
        component.set("v.navigationLocation", navigationLocation);

        // Show Quote LWC when coming from Related List
        let isQuote = false;
        if (navigationLocation && navigationLocation.includes('RELATED_LIST')) {
            isQuote = true;
        }
        if (navigationLocation && navigationLocation.includes('LIST_VIEW_ROW')) {
            isQuote = true;
        }

        console.log("✔ Final Record ID: " + recordId);
        console.log("✔ Navigation Location: " + navigationLocation);
        console.log("✔ Is Quote: " + isQuote);

        component.set("v.isQuote", isQuote);
        component.set("v.isLoaded", true);
    },

    handleLWCCancel: function(component, event, helper) {
        let recordId = component.get("v.recordId");

        console.log("✔ Cancel event received, navigating to:", recordId);

        $A.get("e.force:closeQuickAction").fire();

        $A.get("e.force:navigateToSObject").setParams({
            recordId: recordId,
            slideDevName: "detail"
        }).fire();

        setTimeout(function() {
            $A.get("e.force:refreshView").fire();
        }, 100);
    }
})