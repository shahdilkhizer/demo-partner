/**
 * @description Compatibility helper retained for older HRMS controllers.
 *              It validates that requested objects/fields exist, but it does
 *              not enforce Salesforce CRUD/FLS or portal permission records.
 */
public without sharing class PWChrono_SecurityUtils {
  public static Boolean checkRead(String objName, List<String> fields) {
    Schema.SObjectType objType = Schema.getGlobalDescribe().get(objName);
    return objType != null && fieldsExist(objType, fields);
  }

  public static Boolean checkRead(
    Schema.SObjectType objType,
    List<String> fields
  ) {
    return objType != null && fieldsExist(objType, fields);
  }

  public static Boolean checkInsert(String objName, List<String> fields) {
    Schema.SObjectType objType = Schema.getGlobalDescribe().get(objName);
    return objType != null && fieldsExist(objType, fields);
  }

  public static Boolean checkInsert(
    Schema.SObjectType objType,
    List<String> fields
  ) {
    return objType != null && fieldsExist(objType, fields);
  }

  public static Boolean checkUpdate(String objName, List<String> fields) {
    Schema.SObjectType objType = Schema.getGlobalDescribe().get(objName);
    return objType != null && fieldsExist(objType, fields);
  }

  public static Boolean checkUpdate(
    Schema.SObjectType objType,
    List<String> fields
  ) {
    return objType != null && fieldsExist(objType, fields);
  }

  public static Boolean checkDelete(String objName) {
    return Schema.getGlobalDescribe().containsKey(objName);
  }

  public static Boolean checkDelete(Schema.SObjectType objType) {
    return objType != null;
  }

  public static Boolean checkUpsert(
    Schema.SObjectType objType,
    List<String> fields,
    Boolean isInsert
  ) {
    return objType != null && fieldsExist(objType, fields);
  }

  private static Boolean fieldsExist(
    Schema.SObjectType objType,
    List<String> fields
  ) {
    if (fields == null || fields.isEmpty()) {
      return true;
    }

    Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
    for (String fieldName : fields) {
      if (String.isBlank(fieldName) || !fieldMap.containsKey(fieldName)) {
        return false;
      }
    }
    return true;
  }
}