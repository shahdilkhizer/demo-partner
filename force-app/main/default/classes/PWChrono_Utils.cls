/**
 * @description Utility class for common helper methods
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_Utils {
  /**
   * @description Get current employee ID from user ID
   * @param userId Current user ID
   * @return Employee Portal_Users__c record ID
   */
  public static Id getCurrentEmployeeId(Id userId) {
    if (userId == null) {
      return null;
    }

    List<Portal_Users__c> employees = [
      SELECT Id
      FROM Portal_Users__c
      WHERE User__c = :userId
      LIMIT 1
    ];
    return employees.isEmpty() ? null : employees[0].Id;
  }
}