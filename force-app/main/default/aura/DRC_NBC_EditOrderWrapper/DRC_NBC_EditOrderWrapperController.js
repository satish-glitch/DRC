({
    doInit: function(component, event, helper) {
        let url = window.location.href;
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

        let showLWC = false;
        if (navigationLocation && navigationLocation.includes('RELATED_LIST')) {
            showLWC = true;
        }

        component.set("v.showLWC", showLWC);
        component.set("v.isOrder", showLWC);
        component.set("v.isLoaded", true); // Just mark as loaded now
    },

    handleSave: function (component, event, helper) {
        let record = component.get("v.simpleRecord");
        let rejectionText = record.DRC_NBC_Reject_Reason_Text__c;

        // Validation: Check if text is entered
        if (!rejectionText || rejectionText.trim() === "") {
            $A.get("e.force:showToast").setParams({
                title: "Error",
                message: "Please provide a rejection reason",
                type: "error"
            }).fire();
            return;
        }

        // Set Status to Rejected
        record.Status = 'Rejected';
        component.set("v.simpleRecord", record);

        // Save record
        component.find("recordLoader").saveRecord(function (saveResult) {
            if (saveResult.state === "SUCCESS" || saveResult.state === "DRAFT") {
                $A.get("e.force:showToast").setParams({
                    title: "Success",
                    message: "Order has been rejected successfully.",
                    type: "success"
                }).fire();

                $A.get("e.force:navigateToSObject").setParams({
                    recordId: component.get("v.recordId"),
                    slideDevName: "detail"
                }).fire();

            } else {
                let msg = saveResult.error && saveResult.error[0]
                    ? saveResult.error[0].message
                    : "Unknown error occurred during save.";

                $A.get("e.force:showToast").setParams({
                    title: "Error",
                    message: msg,
                    type: "error"
                }).fire();
            }
        });
    },

    handleLWCCancel: function(component, event, helper) {
        let recordId = component.get("v.recordId");
        $A.get("e.force:navigateToSObject").setParams({
            recordId: recordId,
            slideDevName: "detail"
        }).fire();
    },

    handleCancel: function (component, event, helper) {
        let recordId = component.get("v.recordId");
        $A.get("e.force:navigateToSObject").setParams({
            recordId: recordId,
            slideDevName: "detail"
        }).fire();
    }
})