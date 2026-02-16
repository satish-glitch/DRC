/**
* @File Name : DRC_NBC_AccountSummary.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : September 2, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 2, 2025 |   | Initial Version
**/

public class DRC_NBC_AccountSummary {
	@AuraEnabled(cacheable=true)
    public static DRC_NBC_AccountMetricWrapper getAccountMetrics(Id accountId) {
        Set<Id> accountIds = new Set<Id>();
        accountIds.add(accountId);
        accountIds.addAll(getAllChildAccountIds(accountId));

        List<Account> accountsWithOpps = [
            SELECT Id,
                (SELECT Id, StageName, IsClosed, Amount FROM Opportunities),
                (SELECT Id, Status, DRC_NBC_Total_Amount__c FROM Orders),
                (SELECT Id, DRC_NBC_Overdue_Amount__c, DRC_NBC_Invoice_Amount__c,DRC_NBC_Current_Balance__c FROM Invoices__r)
            FROM Account
            WHERE Id IN :accountIds
        ];

        DRC_NBC_AccountMetricWrapper wrapper = new DRC_NBC_AccountMetricWrapper();

        for (Account acc : accountsWithOpps) {
            for (Opportunity opp : acc.Opportunities) {
                wrapper.totalOpps++;
                if (!opp.IsClosed) {
                    wrapper.activeOpps++;
                    wrapper.activeAmount += opp.Amount != null ? opp.Amount : 0;
                }
                if (opp.StageName == 'Closed Won') {
                    wrapper.closedWonOpps++;
                    wrapper.wonAmount += opp.Amount != null ? opp.Amount : 0;
                }
                if (opp.IsClosed && opp.StageName != 'Closed Won') {
                    wrapper.lostOpps++;
                    wrapper.lostAmount += opp.Amount != null ? opp.Amount : 0;
                }
                if (opp.Amount != null) {
                    wrapper.totalAmount += opp.Amount;
                }
            }
            for (Order ord : acc.orders) {
                if (ord.Status == 'Delivered') {
                    wrapper.totalClosedOrdersCount++;
                    wrapper.totalClosedOrdersAmount += ord.DRC_NBC_Total_Amount__c != null ? ord.DRC_NBC_Total_Amount__c : 0;
                }
                if (ord.Status == 'Draft') {
                    wrapper.totalDraftOrdersCount++;
                    wrapper.totalDraftOrdersAmount += ord.DRC_NBC_Total_Amount__c != null ? ord.DRC_NBC_Total_Amount__c : 0;
                }
                if (ord.Status == 'Cancelled') {
                    wrapper.totalCancelledOrdersCount++;
                    wrapper.totalCancelledOrdersAmount += ord.DRC_NBC_Total_Amount__c != null ? ord.DRC_NBC_Total_Amount__c : 0;
                }
                if (ord.Status == 'Activated' || ord.Status == 'Submitted') {
                    wrapper.totalOpenOrdersCount++;
                    wrapper.totalOpenOrdersAmount += ord.DRC_NBC_Total_Amount__c != null ? ord.DRC_NBC_Total_Amount__c : 0;
                }
            }

            for(DRC_NBC_invoice__c invoice : acc.Invoices__r){
                wrapper.totalInvoiceCount++ ;

                if(invoice.DRC_NBC_Overdue_Amount__c != NULL && invoice.DRC_NBC_Overdue_Amount__c > 0){
                    wrapper.totalOverdueCount++ ;
                    wrapper.totalOverdueAmount += invoice.DRC_NBC_Overdue_Amount__c ;
                }
                if(invoice.DRC_NBC_Invoice_Amount__c != NULL && invoice.DRC_NBC_Invoice_Amount__c > 0){
                    wrapper.totalInvoiceAmount += invoice.DRC_NBC_Invoice_Amount__c ;
                }
                if(invoice.DRC_NBC_Current_Balance__c != NULL && invoice.DRC_NBC_Current_Balance__c > 0){
                    wrapper.totalCurrentCount++ ;
                    wrapper.totalCurrentBalance += invoice.DRC_NBC_Current_Balance__c ;
                }

            } 
        }
        return wrapper;  
    }

    private static Set<Id> getAllChildAccountIds(Id parentId) {
        Set<Id> result = new Set<Id>();
        List<Account> children = [SELECT Id FROM Account WHERE ParentId = :parentId];
        for (Account child : children) {
            result.add(child.Id);
            result.addAll(getAllChildAccountIds(child.Id));
        }
        return result;
    }

	public class DRC_NBC_AccountMetricWrapper {
        //opportunityWrap
		@AuraEnabled public Integer totalOpps =0;
		@AuraEnabled public Integer activeOpps=0;
		@AuraEnabled public Integer closedWonOpps=0;
		@AuraEnabled public Integer lostOpps=0;

		@AuraEnabled public Decimal totalAmount=0;
		@AuraEnabled public Decimal activeAmount=0;
		@AuraEnabled public Decimal wonAmount=0;
		@AuraEnabled public Decimal lostAmount=0;

        // orderWrap
        @AuraEnabled public Integer totalDraftOrdersCount = 0;
		@AuraEnabled public Decimal totalDraftOrdersAmount = 0;

		@AuraEnabled public Integer totalClosedOrdersCount = 0;
		@AuraEnabled public Decimal totalClosedOrdersAmount = 0;

        @AuraEnabled public Integer totalOpenOrdersCount = 0;
		@AuraEnabled public Decimal totalOpenOrdersAmount = 0;

        @AuraEnabled public Integer totalCancelledOrdersCount = 0;
		@AuraEnabled public Decimal totalCancelledOrdersAmount = 0;


        // invoiceWrap
        @AuraEnabled public Integer totalInvoiceCount = 0;
        @AuraEnabled public Integer totalOverdueCount= 0;
        @AuraEnabled public Integer totalCurrentCount= 0;
		@AuraEnabled public Decimal totalOverdueAmount= 0;
        @AuraEnabled public Decimal totalInvoiceAmount = 0;
        @AuraEnabled public Decimal totalCurrentBalance = 0;
	}

}