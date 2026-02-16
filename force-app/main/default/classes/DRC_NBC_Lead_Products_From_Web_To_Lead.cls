/**
* @File Name : DRC_NBC_Lead_Products_From_Web_To_Lead.cls
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
@RestResource(urlMapping='/ProductList')
global class DRC_NBC_Lead_Products_From_Web_To_Lead {
    @HttpGet
    global static List<ProductWrapper> getProducts() {
        List<Product2> productList = [
            SELECT Id, Name FROM Product2 WHERE IsActive = TRUE
        ];
        
        List<ProductWrapper> result = new List<ProductWrapper>();
        for (Product2 p : productList) {
            result.add(new ProductWrapper(p.Id, p.Name));
        }
        return result;
    }

    global class ProductWrapper {
        public Id id;
        public String name;
        
        public ProductWrapper(Id id, String name) {
            this.id = id;
            this.name = name;
        }
    }
}