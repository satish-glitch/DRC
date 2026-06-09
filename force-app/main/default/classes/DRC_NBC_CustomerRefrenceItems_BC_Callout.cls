public class DRC_NBC_CustomerRefrenceItems_BC_Callout {

    public static DRC_NBC_Integration_Payload.CustomerItemReferencePayload mapToPayload(
        DRC_NBC_Restricted_Product__c rp,
        String customerNumber,
        Account acc
    ) {
        DRC_NBC_Integration_Payload.CustomerItemReferencePayload payload =
            new DRC_NBC_Integration_Payload.CustomerItemReferencePayload();

        payload.Reference_Type_No   = customerNumber;
        payload.Item_No             = rp.DRC_NBC_Product__r.DRC_NBC_FG_Code__c;
        payload.Unit_of_Measure     = 'KGS';
        payload.Reference_Type      = acc.Type;
        payload.Reference_No        = rp.Name;
        payload.Reference_Type_Name = acc.Name;
        payload.Description         = rp.DRC_NBC_Customer_s_Product_code__c;
        payload.Description_2       = '';

        System.debug(LoggingLevel.DEBUG, 'MAPPED CUSTOMER ITEM REF PAYLOAD >>> ' + JSON.serialize(payload, true));

        return payload;
    }
}