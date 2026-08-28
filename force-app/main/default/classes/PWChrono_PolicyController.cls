/**
 * @description Controller for Company Policy LWC Components
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.ApexSOQLInjection')
public inherited sharing class PWChrono_PolicyController {
  /**
   * @description Get company policies
   * @param category Optional category filter
   * @return List of policies
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Company_Policy__c> getPolicies(String category) {
    try {
      String query =
        'SELECT Id, Name, Category__c, Description__c, Effective_Date__c, CreatedDate ' +
        'FROM PWChrono_Company_Policy__c ';

      if (String.isNotBlank(category) && category != 'All') {
        query += 'WHERE Category__c = :category ';
      }

      query += ' ORDER BY Effective_Date__c DESC, Name ASC';

      return Database.query(query);
    } catch (Exception e) {
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching policies: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching policies: ' + e.getMessage());
      throw ahe;
    }
  }
}