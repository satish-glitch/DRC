public with sharing class DRC_NBC_CustomerItems_StatusCtrl {

    public String  accountName   { get; private set; }
    public String  syncTime      { get; private set; }
    public Boolean jobEnqueued   { get; private set; }
    public Boolean showResults   { get; private set; }

    public String  readStatus    { get; private set; }
    public String  createStatus  { get; private set; }
    public String  updateStatus  { get; private set; }

    public Boolean readSuccess   { get; private set; }
    public Boolean createSuccess { get; private set; }
    public Boolean updateSuccess { get; private set; }

    private Id accountId;

    public DRC_NBC_CustomerItems_StatusCtrl() {
        accountId   = ApexPages.currentPage().getParameters().get('id');
        jobEnqueued = false;
        showResults = false;

        List<Account> accs = [SELECT Name FROM Account WHERE Id = :accountId LIMIT 1];
        accountName = accs.isEmpty() ? '' : accs[0].Name;
    }

    // Called on page load via <apex:page action>
    public PageReference onLoad() {
        try {
            System.enqueueJob(new DRC_NBC_CustomerItems_SOAP_Queueable(accountId));
            jobEnqueued = true;
        } catch (Exception e) {
            jobEnqueued = false;
            System.debug('Enqueue failed: ' + e.getMessage());
        }
        return null;
    }

    // Called by the JS poll via <apex:actionFunction>
    public void checkResults() {
        List<DRC_NBC_API_Log__c> logs = [
            SELECT DRC_NBC_Method_Name__c,
                   DRC_NBC_Log_Type__c,
                   DRC_NBC_Timestamp__c
            FROM   DRC_NBC_API_Log__c
            WHERE  DRC_NBC_Created_Updated_SF_Id__c = :accountId
              AND  DRC_NBC_Method_Name__c IN ('ReadMultiple','CreateMultiple','UpdateMultiple')
            ORDER BY DRC_NBC_Timestamp__c DESC
            LIMIT  3
        ];

        if (logs.isEmpty()) return;

        // Only show results if logs are recent (within last 3 minutes)
        DateTime cutoff = DateTime.now().addMinutes(-3);
        if (logs[0].DRC_NBC_Timestamp__c < cutoff) return;

        syncTime   = logs[0].DRC_NBC_Timestamp__c.format('dd MMM yyyy, HH:mm');
        showResults = true;

        for (DRC_NBC_API_Log__c log : logs) {
            Boolean ok = (log.DRC_NBC_Log_Type__c == 'Success');
            String  op = log.DRC_NBC_Method_Name__c;
            if (op == 'ReadMultiple')   { readStatus   = log.DRC_NBC_Log_Type__c; readSuccess   = ok; }
            if (op == 'CreateMultiple') { createStatus  = log.DRC_NBC_Log_Type__c; createSuccess = ok; }
            if (op == 'UpdateMultiple') { updateStatus  = log.DRC_NBC_Log_Type__c; updateSuccess = ok; }
        }

        if (readStatus   == null) { readStatus   = 'Skipped'; readSuccess   = true; }
        if (createStatus == null) { createStatus = 'Skipped'; createSuccess = true; }
        if (updateStatus == null) { updateStatus = 'Skipped'; updateSuccess = true; }
    }

    public PageReference goBack() {
        return new PageReference('/' + accountId);
    }
}