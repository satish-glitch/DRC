/**
* @File Name : DRC_NBC_Product_Domain.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : September 3, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | September 3, 2025 |   | Initial Version
**/

public class DRC_NBC_Product_Domain {
	public static Map<Id, product2> getProductByProductCodes(Set<String> productCodes) {
		return new map<Id, product2>([
			SELECT
				Id,
				Name,
				DRC_NBC_Product_Code__c
			FROM
				Product2
			WHERE
				DRC_NBC_Product_Code__c In : productCodes
		]);
	}

	public static Map<String, Product2> getProductGroupByCode(Set<String> productCodes) {
		Map<String, Product2> codeToProduct = new  Map<String, Product2>();
		for(Product2 currentProduct : getProductByProductCodes(productCodes).values()) {
			codeToProduct.put(currentProduct.DRC_NBC_Product_Code__c, currentProduct);
		}
		return codeToProduct;
	}
}