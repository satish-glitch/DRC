// DRC_NBC_AddProductsWrapperController.js
({
    doInit: function(component, event, helper) {
        var recordId = component.get("v.recordId");
        console.log('[Aura doInit] recordId:', recordId);

        if (recordId) {
            // Find the LWC child by aura:id and set recordId directly on it.
            // This fires the LWC @api setter AFTER the component is fully rendered.
            var lwcChild = component.find("lwcChild");
            if (lwcChild) {
                lwcChild.set("v.recordId", recordId);
                console.log('[Aura doInit] set recordId on LWC child:', recordId);
            } else {
                console.error('[Aura doInit] LWC child not found');
            }
        } else {
            console.error('[Aura doInit] recordId is blank on Aura component');
        }
    }
})