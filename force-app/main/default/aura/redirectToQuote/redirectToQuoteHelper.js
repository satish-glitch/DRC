({
    navigateToRecord: function(component, recordId) {
        var navService = component.find("navService");
        
        navService.navigate({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Quote',
                actionName: 'view'
            }
        });
    }
})