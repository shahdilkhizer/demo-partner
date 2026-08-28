/**
 * @description       :
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             :
 * @last modified on  : 06-04-2026
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 **/
public inherited sharing class PWChrono_FullFinalSettlementController {
  // ─── Getters ────────────────────────────────────────────────────────────

  @AuraEnabled
  public static List<PWChrono_Full_Final_Settlement__c> getSettlements(
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
      Portal_Users__c caller = [
        SELECT Id, Role__c
        FROM Portal_Users__c
        WHERE Id = :portalUserId
        LIMIT 1
      ];
      Boolean isHR = caller.Role__c == PWChrono_Constants.ROLE_HR_ADMIN;
      Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;

      String q =
        'SELECT Id, Name, Employee__c, Employee__r.Name, Employee_Name__c, ' +
        'Company__c, Department__c, Department__r.Name, Designation__c, Designation__r.Name, ' +
        'Separation__c, Separation__r.Name, Date_of_Joining__c, Relieving_Date__c, ' +
        'Status__c, Total_Payable__c, Total_Receivable__c, Net_Payable__c ' +
        'FROM PWChrono_Full_Final_Settlement__c ';

      List<String> whereClauses = new List<String>();
      if (!isHR) {
        whereClauses.add('Employee__c = :portalUserId');
      }
      if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
        whereClauses.add('Status__c = :statusFilter');
      }
      if (!whereClauses.isEmpty()) {
        q += 'WHERE ' + String.join(whereClauses, ' AND ') + ' ';
      }
      q += 'ORDER BY CreatedDate DESC LIMIT :queryLimit';
      return Database.query(q);
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_FullFinalSettlementController.getSettlements',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static PWChrono_Full_Final_Settlement__c getSettlementById(
    String settlementId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
      return [
        SELECT
          Id,
          Name,
          Employee__c,
          Employee__r.Name,
          Employee_Name__c,
          Company__c,
          Department__c,
          Department__r.Name,
          Designation__c,
          Designation__r.Name,
          Separation__c,
          Separation__r.Name,
          Date_of_Joining__c,
          Relieving_Date__c,
          Status__c,
          Total_Payable__c,
          Total_Receivable__c,
          Net_Payable__c
        FROM PWChrono_Full_Final_Settlement__c
        WHERE Id = :settlementId
        LIMIT 1
      ];
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_FullFinalSettlementController.getSettlementById',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<PWChrono_Settlement_Payable__c> getPayables(
    String settlementId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
      return [
        SELECT
          Id,
          Name,
          Settlement__c,
          Component__c,
          Reference_Document__c,
          Account__c,
          Amount__c,
          Status__c
        FROM PWChrono_Settlement_Payable__c
        WHERE Settlement__c = :settlementId
        ORDER BY CreatedDate ASC
      ];
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_FullFinalSettlementController.getPayables',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<PWChrono_Settlement_Receivable__c> getReceivables(
    String settlementId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
      return [
        SELECT
          Id,
          Name,
          Settlement__c,
          Component__c,
          Reference_Document__c,
          Account__c,
          Amount__c,
          Status__c
        FROM PWChrono_Settlement_Receivable__c
        WHERE Settlement__c = :settlementId
        ORDER BY CreatedDate ASC
      ];
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_FullFinalSettlementController.getReceivables',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ─── Save (upsert parent + replace children) ────────────────────────────

  @AuraEnabled
  public static String saveSettlement(
    String settlementJson,
    String payablesJson,
    String receivablesJson,
    String portalUserId,
    String sessionToken
  ) {
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );

      Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(
        settlementJson
      );
      PWChrono_Full_Final_Settlement__c rec = new PWChrono_Full_Final_Settlement__c();

      String recId = (String) raw.get('Id');
      if (String.isNotBlank(recId)) {
        rec.Id = recId;
      }
      if (raw.get('Employee__c') != null) {
        rec.Employee__c = (String) raw.get('Employee__c');
      }
      if (raw.get('Employee_Name__c') != null) {
        rec.Employee_Name__c = (String) raw.get('Employee_Name__c');
      }
      if (raw.get('Company__c') != null) {
        rec.Company__c = (String) raw.get('Company__c');
      }
      if (raw.get('Department__c') != null) {
        rec.Department__c = (String) raw.get('Department__c');
      }
      if (raw.get('Designation__c') != null) {
        rec.Designation__c = (String) raw.get('Designation__c');
      }
      if (raw.get('Separation__c') != null) {
        rec.Separation__c = (String) raw.get('Separation__c');
      }
      if (raw.get('Date_of_Joining__c') != null) {
        rec.Date_of_Joining__c = Date.valueOf(
          (String) raw.get('Date_of_Joining__c')
        );
      }
      if (raw.get('Relieving_Date__c') != null) {
        rec.Relieving_Date__c = Date.valueOf(
          (String) raw.get('Relieving_Date__c')
        );
      }
      if (raw.get('Status__c') != null) {
        rec.Status__c = (String) raw.get('Status__c');
      }

      // Calculate totals from line items
      List<Object> payablesList = (List<Object>) JSON.deserializeUntyped(
        payablesJson
      );
      List<Object> receivablesList = (List<Object>) JSON.deserializeUntyped(
        receivablesJson
      );

      Decimal totalPayable = 0;
      for (Object obj : payablesList) {
        Map<String, Object> line = (Map<String, Object>) obj;
        if (line.get('Amount__c') != null) {
          totalPayable += Decimal.valueOf(
            String.valueOf(line.get('Amount__c'))
          );
        }
      }
      Decimal totalReceivable = 0;
      for (Object obj : receivablesList) {
        Map<String, Object> line = (Map<String, Object>) obj;
        if (line.get('Amount__c') != null) {
          totalReceivable += Decimal.valueOf(
            String.valueOf(line.get('Amount__c'))
          );
        }
      }
      rec.Total_Payable__c = totalPayable;
      rec.Total_Receivable__c = totalReceivable;
      rec.Net_Payable__c = totalPayable - totalReceivable;

      upsert rec;

      // Replace payables
      List<PWChrono_Settlement_Payable__c> oldPayables = [
        SELECT Id
        FROM PWChrono_Settlement_Payable__c
        WHERE Settlement__c = :rec.Id
      ];
      delete oldPayables;
      List<PWChrono_Settlement_Payable__c> newPayables = new List<PWChrono_Settlement_Payable__c>();
      for (Object obj : payablesList) {
        Map<String, Object> line = (Map<String, Object>) obj;
        PWChrono_Settlement_Payable__c p = new PWChrono_Settlement_Payable__c();
        p.Settlement__c = rec.Id;
        p.Name = line.get('Name') != null
          ? (String) line.get('Name')
          : 'Payable Item';
        p.Component__c = (String) line.get('Component__c');
        p.Reference_Document__c = (String) line.get('Reference_Document__c');
        p.Account__c = (String) line.get('Account__c');
        if (line.get('Amount__c') != null) {
          p.Amount__c = Decimal.valueOf(String.valueOf(line.get('Amount__c')));
        }
        p.Status__c = line.get('Status__c') != null
          ? (String) line.get('Status__c')
          : 'Pending';
        newPayables.add(p);
      }
      if (!newPayables.isEmpty()) {
        insert newPayables;
      }

      // Replace receivables
      List<PWChrono_Settlement_Receivable__c> oldReceivables = [
        SELECT Id
        FROM PWChrono_Settlement_Receivable__c
        WHERE Settlement__c = :rec.Id
      ];
      delete oldReceivables;
      List<PWChrono_Settlement_Receivable__c> newReceivables = new List<PWChrono_Settlement_Receivable__c>();
      for (Object obj : receivablesList) {
        Map<String, Object> line = (Map<String, Object>) obj;
        PWChrono_Settlement_Receivable__c r = new PWChrono_Settlement_Receivable__c();
        r.Settlement__c = rec.Id;
        r.Name = line.get('Name') != null
          ? (String) line.get('Name')
          : 'Receivable Item';
        r.Component__c = (String) line.get('Component__c');
        r.Reference_Document__c = (String) line.get('Reference_Document__c');
        r.Account__c = (String) line.get('Account__c');
        if (line.get('Amount__c') != null) {
          r.Amount__c = Decimal.valueOf(String.valueOf(line.get('Amount__c')));
        }
        r.Status__c = line.get('Status__c') != null
          ? (String) line.get('Status__c')
          : 'Pending';
        newReceivables.add(r);
      }
      if (!newReceivables.isEmpty()) {
        insert newReceivables;
      }

      return rec.Id;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_FullFinalSettlementController.saveSettlement',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ─── Status update (HR only) ─────────────────────────────────────────────

  @AuraEnabled
  public static void updateSettlementStatus(
    String settlementId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
      Portal_Users__c caller = [
        SELECT Id, Role__c
        FROM Portal_Users__c
        WHERE Id = :portalUserId
        LIMIT 1
      ];
      if (caller.Role__c != PWChrono_Constants.ROLE_HR_ADMIN) {
        throw new AuraHandledException('Insufficient permissions.');
      }
      PWChrono_Full_Final_Settlement__c rec = new PWChrono_Full_Final_Settlement__c(
        Id = settlementId,
        Status__c = newStatus
      );
      update rec;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_FullFinalSettlementController.updateSettlementStatus',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ─── Delete (HR only) ────────────────────────────────────────────────────

  @AuraEnabled
  public static void deleteSettlement(
    String settlementId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
      Portal_Users__c caller = [
        SELECT Id, Role__c
        FROM Portal_Users__c
        WHERE Id = :portalUserId
        LIMIT 1
      ];
      if (caller.Role__c != PWChrono_Constants.ROLE_HR_ADMIN) {
        throw new AuraHandledException('Insufficient permissions.');
      }
      List<PWChrono_Full_Final_Settlement__c> settlements = [
        SELECT Id, Status__c
        FROM PWChrono_Full_Final_Settlement__c
        WHERE Id = :settlementId
        LIMIT 1
      ];
      if (settlements.isEmpty()) {
        throw new AuraHandledException('Settlement not found.');
      }
      if (settlements[0].Status__c != 'Draft') {
        throw new AuraHandledException(
          'Only draft settlements can be deleted.'
        );
      }
      delete settlements[0];
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_FullFinalSettlementController.deleteSettlement',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ─── Lookup helpers ──────────────────────────────────────────────────────

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Designation__c> getActiveDesignations() {
    return [
      SELECT Id, Name
      FROM PWChrono_Designation__c
      WHERE Is_Active__c = TRUE
      ORDER BY Name ASC
      LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Department__c> getActiveDepartments() {
    return [
      SELECT Id, Name
      FROM PWChrono_Department__c
      WHERE Is_Active__c = TRUE
      ORDER BY Name ASC
      LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<Portal_Users__c> getActiveEmployees() {
    return [
      SELECT Id, Name
      FROM Portal_Users__c
      WHERE Is_Active__c = TRUE
      ORDER BY Name ASC
      LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
    ];
  }

  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Employee_Separation__c> getActiveSeparations() {
    return [
      SELECT Id, Name, Employee__c, Employee__r.Name
      FROM PWChrono_Employee_Separation__c
      WHERE Status__c != 'Cancelled'
      ORDER BY CreatedDate DESC
      LIMIT :PWChrono_Constants.DEFAULT_QUERY_LIMIT
    ];
  }
}