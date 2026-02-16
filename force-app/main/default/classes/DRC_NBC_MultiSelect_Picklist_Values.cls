/**
* @File Name : DRC_NBC_MultiSelect_Picklist_Values.cls
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

public without sharing class DRC_NBC_MultiSelect_Picklist_Values {
	  @InvocableMethod
   public static List<list<string>> CheckValues(List<string> values) {
      if(!(values.isEmpty())){
          string tempStr = values[0];
          List<String> lstnew = tempStr.split(';');
          list<list<string>> finalLst = new list<list<string>>();
          finalLst.add(lstnew);
          String valuesString = String.valueOf(values);
          if (valuesString == '()' || valuesString == 'null') {
              return null;
          } 
          return finalLst;
      }
      else return null;
   }
}