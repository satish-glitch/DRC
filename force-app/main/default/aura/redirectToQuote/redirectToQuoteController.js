({
    invoke : function(component, event, helper) {
        
        var recordId = component.get("v.recordId");
        
        return new Promise(function(resolve, reject) {
            if (recordId) {
                
                var workspaceAPI = component.find("workspace");
                
                if (workspaceAPI) {
                    
                    workspaceAPI.isConsoleNavigation().then(function(isConsole) {
                        if (isConsole) {
                            
                            workspaceAPI.openTab({
                                recordId: recordId,
                                focus: true
                            }).then(function() {
                                resolve();
                            }).catch(function(error) {
                                
                                helper.navigateToRecord(component, recordId);
                                
                                var toastEvent = $A.get("e.force:showToast");
                    			toastEvent.setParams({
                    				"title": "Success",
                    				"message": "Quote has been successfully cloned.",
                    				"type": "success"
                    	 		});                    
                				toastEvent.fire();
                                
                                resolve();
                            });
                        } else {
                           
                            helper.navigateToRecord(component, recordId);
                            
                            var toastEvent = $A.get("e.force:showToast");
                    		toastEvent.setParams({
                    			"title": "Success",
                    			"message": "Quote has been successfully cloned.",
                    			"type": "success"
                    	 	});                    
                			toastEvent.fire();
                            
                            resolve();
                        }
                    }).catch(function(error) {
                        
                        helper.navigateToRecord(component, recordId);
                        
                        var toastEvent = $A.get("e.force:showToast");
                    	toastEvent.setParams({
                    		"title": "Success",
                    		"message": "Quote has been successfully cloned.",
                    		"type": "success"
                    	 });                    
                		toastEvent.fire();
                        
                        resolve();
                    });
                } else {
                    
                    helper.navigateToRecord(component, recordId);
                    
                    var toastEvent = $A.get("e.force:showToast");
                    toastEvent.setParams({
                    	"title": "Success",
                    	"message": "Quote has been successfully cloned.",
                    	"type": "success"
                     });                    
                	toastEvent.fire();
                    
                    resolve();
                }
            } else {
                
                var toastEvent = $A.get("e.force:showToast");
                toastEvent.setParams({
                    "title": "Error",
                    "message": "No record ID was provided for redirection.",
                    "type": "error"
                });
                toastEvent.fire();
                resolve();
            }
        });
    }
})