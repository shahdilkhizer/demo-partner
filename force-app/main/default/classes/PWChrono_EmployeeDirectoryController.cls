public inherited sharing class PWChrono_EmployeeDirectoryController {
  /**
   * Lightweight, user-facing exception for this controller.
   * (Used instead of AuraHandledException to avoid IDE type resolution issues.)
   */
  public class EmployeeDirectoryException extends Exception {
  }

  @AuraEnabled(cacheable=true)
  public static List<SObject> searchEmployees(String searchTerm) {
    try {
      String query = 'SELECT Id, Name, Email__c, Department__c, Designation__c, Phone__c, Reports_To__r.Name FROM Portal_Users__c';

      if (String.isNotBlank(searchTerm)) {
        String key = String.escapeSingleQuotes(searchTerm) + '%';
        // Note: Leading wildcard removed to prevent non-selective query
        query += ' WHERE Name LIKE :key OR Email__c LIKE :key OR Department__c LIKE :key';
      }

      query +=
        ' ORDER BY Name ASC LIMIT ' + PWChrono_Constants.DASHBOARD_QUERY_LIMIT;
      return Database.query(query);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      throw new EmployeeDirectoryException('Error searching employees.');
    }
  }

  /**
   * @description Check if current user has read access to a Portal_Users record
   * @param recordId The Portal_Users record ID to check access for
   * @return True if user has read access, false otherwise
   */
  @AuraEnabled
  public static Boolean checkRecordAccess(Id recordId) {
    try {
      // Security Check

      // Check if the record exists and is readable by the current user
      String query = 'SELECT Id FROM Portal_Users__c WHERE Id = :recordId LIMIT 1';
      List<SObject> records = Database.query(query);

      // If the query returns a record, user has read access
      return !records.isEmpty();
    } catch (QueryException e) {
      // Query failed due to access restrictions
      return false;
    } catch (Exception e) {
      // Other exceptions - return false for safety
      PWChrono_Logger.error('Error checking record access', e);
      return false;
    }
  }
}