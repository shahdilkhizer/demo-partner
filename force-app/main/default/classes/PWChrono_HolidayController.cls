/**
 * @description Controller for Holiday Calendar LWC Components
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_HolidayController {
  /**
   * @description Get upcoming holidays
   * @return List of holidays
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Holiday__c> getUpcomingHolidays() {
    try {
      Date today = Date.today();
      return [
        SELECT Id, Name, Holiday_Date__c, Description__c, Is_Weekly_Off__c
        FROM PWChrono_Holiday__c
        WHERE Holiday_Date__c >= :today
        ORDER BY Holiday_Date__c ASC
        LIMIT 50
      ];
    } catch (Exception e) {
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching holidays: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching holidays: ' + e.getMessage());
      throw ahe;
    }
  }
}