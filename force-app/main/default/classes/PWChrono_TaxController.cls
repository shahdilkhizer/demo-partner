/**
 * @description Controller for Tax Declaration LWC Components
 * @author PWChrono Team
 */
public inherited sharing class PWChrono_TaxController {
  /**
   * @description Get tax declarations for current employee
   * @return List of tax declarations
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Tax_Declaration__c> getMyTaxDeclarations(
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id employeeId;
      if (UserInfo.getUserType() == 'Guest') {
        employeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          portalUserId,
          sessionToken
        );
      } else {
        Id currentUserId = UserInfo.getUserId();
        employeeId = PWChrono_Utils.getCurrentEmployeeId(currentUserId);
      }

      if (employeeId == null) {
        AuraHandledException ahe = new AuraHandledException(
          'No employee record found for current user.'
        );
        ahe.setMessage('No employee record found for current user.');
        throw ahe;
      }

      return [
        SELECT
          Id,
          Name,
          Fiscal_Year__c,
          Status__c,
          Section_80C__c,
          HRA__c,
          Medical_Insurance__c,
          NPS__c,
          Total_Declared_Amount__c,
          CreatedDate
        FROM PWChrono_Tax_Declaration__c
        WHERE Employees__c = :employeeId
        ORDER BY CreatedDate DESC
      ];
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching tax declarations: '
      );
      ahe.setMessage('Error fetching tax declarations: ');
      throw ahe;
    }
  }

  /**
   * @description Save or Update Tax Declaration
   * @param declaration Tax Declaration record
   * @return Saved record
   */
  @AuraEnabled
  public static PWChrono_Tax_Declaration__c saveTaxDeclaration(
    PWChrono_Tax_Declaration__c declaration,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id employeeId;
      if (UserInfo.getUserType() == 'Guest') {
        employeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          portalUserId,
          sessionToken
        );
      } else {
        Id currentUserId = UserInfo.getUserId();
        employeeId = PWChrono_Utils.getCurrentEmployeeId(currentUserId);
      }

      if (employeeId == null) {
        AuraHandledException ahe = new AuraHandledException(
          'No employee record found for current user.'
        );
        ahe.setMessage('No employee record found for current user.');
        throw ahe;
      }

      if (declaration.Id == null) {
        declaration.Employees__c = employeeId;
        declaration.Status__c = PWChrono_Constants.STATUS_DRAFT;
        insert declaration;
      } else {
        validateUpdate(declaration.Id, employeeId);
        update declaration;
      }

      return declaration;
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error saving tax declaration: '
      );
      ahe.setMessage('Error saving tax declaration: ');
      throw ahe;
    }
  }

  private static void validateUpdate(Id declarationId, Id employeeId) {
    List<PWChrono_Tax_Declaration__c> existing = [
      SELECT Id, Status__c
      FROM PWChrono_Tax_Declaration__c
      WHERE Id = :declarationId AND Employees__c = :employeeId
    ];
    if (existing.isEmpty()) {
      throw new AuraHandledException('Access Denied.');
    }
    if (
      existing[0].Status__c != PWChrono_Constants.STATUS_DRAFT &&
      existing[0].Status__c != PWChrono_Constants.STATUS_REJECTED
    ) {
      throw new AuraHandledException(
        'Cannot edit submitted or approved declarations.'
      );
    }
  }

  /**
   * @description Submit Tax Declaration for approval
   * @param declarationId Record ID
   */
  @AuraEnabled
  public static void submitTaxDeclaration(
    Id declarationId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      Id employeeId;
      if (UserInfo.getUserType() == 'Guest') {
        employeeId = PWChrono_GuestSession.requireVerifiedPortalUserId(
          portalUserId,
          sessionToken
        );
      } else {
        Id currentUserId = UserInfo.getUserId();
        employeeId = PWChrono_Utils.getCurrentEmployeeId(currentUserId);
      }

      PWChrono_Tax_Declaration__c declaration = [
        SELECT Id, Status__c
        FROM PWChrono_Tax_Declaration__c
        WHERE Id = :declarationId AND Employees__c = :employeeId
        LIMIT 1
      ];

      if (declaration.Status__c != PWChrono_Constants.STATUS_DRAFT) {
        AuraHandledException ahe = new AuraHandledException(
          'Only Draft declarations can be submitted.'
        );
        ahe.setMessage('Only Draft declarations can be submitted.');
        throw ahe;
      }

      declaration.Status__c = PWChrono_Constants.STATUS_SUBMITTED;
      update declaration;

      // Ideally, trigger an approval process here
      // Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
      // req.setObjectId(declaration.Id);
      // Approval.process(req);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error submitting tax declaration: '
      );
      ahe.setMessage('Error submitting tax declaration: ');
      throw ahe;
    }
  }
}