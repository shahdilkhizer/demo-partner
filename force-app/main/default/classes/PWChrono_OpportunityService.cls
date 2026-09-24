/** Read-only Opportunity projection for verified portal administrators. */
public without sharing class PWChrono_OpportunityService {
  public class OpportunityPage {
    @AuraEnabled
    public List<Opportunity> records;
    @AuraEnabled
    public Integer total;
    @AuraEnabled
    public Boolean hasMore;
    @AuraEnabled
    public List<String> stages;
  }
  private static void authorize(String portalUserId, String sessionToken) {
    Id verified = PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    Id caller = PWChrono_RequestValidator.resolveEmployeeId(
      portalUserId,
      sessionToken
    );
    if (caller == null || caller != verified)
      throw new AuraHandledException(
        'Access denied. Administrator access is required.'
      );
    List<Portal_Users__c> users = [
      SELECT Role__c
      FROM Portal_Users__c
      WHERE Id = :caller AND Is_Active__c = TRUE
    ];
    if (
      users.isEmpty() ||
      !new Set<String>{ 'HR Admin', 'System Administrator', 'System Admin' }
        .contains(users[0].Role__c)
    ) {
      throw new AuraHandledException(
        'Access denied. Administrator access is required.'
      );
    }
  }
  public static OpportunityPage listRecords(
    String portalUserId,
    String sessionToken,
    String searchTerm,
    String stage,
    Id afterId
  ) {
    authorize(portalUserId, sessionToken);
    String term =
      '%' +
      (String.isBlank(searchTerm) ? '' : searchTerm.trim()) +
      '%';
    String whereClause = ' WHERE Name LIKE :term';
    if (String.isNotBlank(stage))
      whereClause += ' AND StageName = :stage';
    OpportunityPage result = new OpportunityPage();
    result.total = Database.countQuery(
      'SELECT COUNT() FROM Opportunity' + whereClause
    );
    if (afterId != null)
      whereClause += ' AND Id > :afterId';
    result.records = Database.query(
      'SELECT Id, Name, Account.Name, StageName, Amount, CloseDate, Owner.Name, IsClosed, IsWon FROM Opportunity' +
        whereClause +
        ' ORDER BY Id LIMIT 51'
    );
    result.hasMore = result.records.size() > 50;
    if (result.hasMore)
      result.records.remove(50);
    result.stages = new List<String>();
    for (AggregateResult row : [
      SELECT StageName
      FROM Opportunity
      GROUP BY StageName
      ORDER BY StageName
    ])
      result.stages.add((String) row.get('StageName'));
    return result;
  }
  public static Opportunity detail(
    String portalUserId,
    String sessionToken,
    Id opportunityId
  ) {
    authorize(portalUserId, sessionToken);
    List<Opportunity> rows = [
      SELECT
        Id,
        Name,
        Account.Name,
        StageName,
        Amount,
        CloseDate,
        Owner.Name,
        Probability,
        Description,
        NextStep,
        Type,
        LeadSource,
        IsClosed,
        IsWon
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];
    if (rows.isEmpty())
      throw new AuraHandledException('Opportunity not found.');
    return rows[0];
  }
}