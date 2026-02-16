trigger DRC_NBC_ClearQuoteAddresses on Quote (before insert) {
    for (Quote q : Trigger.new) {
        if (String.isNotBlank(q.BillingStreet) || 
            String.isNotBlank(q.BillingCity) ||
            String.isNotBlank(q.BillingPostalCode) ||
            String.isNotBlank(q.BillingStateCode) ||
            String.isNotBlank(q.BillingCountryCode)) {
            
            q.BillingStreet = null;
            q.BillingCity = null;
            q.BillingPostalCode = null;
            q.BillingStateCode = null;
            q.BillingCountryCode = null;
        }

        if (String.isNotBlank(q.ShippingStreet) ||
            String.isNotBlank(q.ShippingCity) ||
            String.isNotBlank(q.ShippingPostalCode) ||
            String.isNotBlank(q.ShippingStateCode) ||
            String.isNotBlank(q.ShippingCountryCode)) {
            
            q.ShippingStreet = null;
            q.ShippingCity = null;
            q.ShippingPostalCode = null;
            q.ShippingStateCode = null;
            q.ShippingCountryCode = null;
        }
    }

}