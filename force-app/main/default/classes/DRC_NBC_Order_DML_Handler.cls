public class DRC_NBC_Order_DML_Handler implements Queueable {
    
    private Id orderId;
    private Boolean needsShipToCode;
    private Boolean needsOrderNumber;
    
    public DRC_NBC_Order_DML_Handler(Id orderId, Boolean needsShipToCode, Boolean needsOrderNumber) {
        this.orderId = orderId;
        this.needsShipToCode = needsShipToCode;
        this.needsOrderNumber = needsOrderNumber;
    }
    
    public void execute(QueueableContext context) {
        try {
            System.debug('=== DML Handler Started ===');
            System.debug('Need Ship-To Code: ' + needsShipToCode);
            System.debug('Need Order Number: ' + needsOrderNumber);
            
            // STEP 1: Generate Ship-To Code if needed (DML)
            if (needsShipToCode) {
                System.debug('Generating Ship-To Code...');
                DRC_NBC_ShipToCodeGenerator.assignShipToCode(orderId);
                System.debug('Ship-To Code generated successfully');
            }
            
            // STEP 2: Generate Order Number if needed (DML)
            if (needsOrderNumber) {
                System.debug('Generating Order Number...');
                DRC_NBC_OrderNumberGenerator_Helper.generateOrderNumbersSync(orderId);
                System.debug('Order Number generated successfully');
            }
            
            System.debug('=== DML Handler Completed - Chaining to Callout Handler ===');
            
            // STEP 3: Chain to callout-only Queueable
            // This new Queueable will do shipping + order callouts ONLY
            System.enqueueJob(new DRC_NBC_Order_Callout_Handler(orderId));
            
        } catch (Exception e) {
            System.debug('DML Handler → FAILURE: ' + e.getMessage());
            DRC_NBC_API_Log_Handler.createApiLog(
                'DRC_NBC_Order_DML_Handler',
                null, null, 'Queueable',
                'DML Error: ' + e.getMessage(), 
                null, e.getStackTraceString(),
                'Error', orderId
            );
        }
    }
}