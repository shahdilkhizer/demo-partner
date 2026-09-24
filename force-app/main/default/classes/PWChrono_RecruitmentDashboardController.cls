/**
 * @description Controller for the Recruitment Dashboard.
 *              Returns aggregated metrics across Job Openings, Job Applicants,
 *              and Job Requisitions in a single data transfer object.
 */
public inherited sharing class PWChrono_RecruitmentDashboardController {
  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * @description Returns all recruitment metrics for the dashboard.
   * @param portalUserId  Id of the authenticated Portal_Users__c record.
   * @param sessionToken  Guest session token (blank for non-guest users).
   * @return              DashboardData wrapper with all metric collections.
   */
  @AuraEnabled(cacheable=true)
  public static DashboardData getDashboardData(
    String portalUserId,
    String sessionToken
  ) {
    try {
      PWChrono_GuestSession.requireVerifiedPortalUserId(
        portalUserId,
        sessionToken
      );
      return buildDashboard();
    } catch (Exception ex) {
      PWChrono_Logger.error(
        'PWChrono_RecruitmentDashboardController.getDashboardData',
        ex
      );
      throw new AuraHandledException(ex.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private — build
  // ─────────────────────────────────────────────────────────────────────────

  private static DashboardData buildDashboard() {
    DashboardData data = new DashboardData();

    aggregateOpenings(data);
    aggregateApplicants(data);
    aggregateApplicantsBySource(data);
    aggregateApplicantsByJobOpening(data);
    aggregateOffersByStatus(data);
    aggregateDeptWiseOpenings(data);
    aggregateAvgTimeToFill(data);

    return data;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Aggregation helpers
  // ─────────────────────────────────────────────────────────────────────────

  private static void aggregateOpenings(DashboardData data) {
    for (AggregateResult ar : [
      SELECT Status__c status, COUNT(Id) cnt
      FROM PWChrono_Job_Opening__c
      GROUP BY Status__c
    ]) {
      String s = (String) ar.get('status');
      Integer c = (Integer) ar.get('cnt');
      data.totalJobOpenings += c;
      if (s == 'Open') {
        data.openJobOpenings = c;
      } else if (s == 'Closed') {
        data.closedJobOpenings = c;
      }
      data.openingsByStatus.add(new LabelCount(s, c));
    }
  }

  private static void aggregateApplicants(DashboardData data) {
    for (AggregateResult ar : [
      SELECT Status__c status, COUNT(Id) cnt
      FROM PWChrono_Job_Applicant__c
      GROUP BY Status__c
    ]) {
      String s = (String) ar.get('status');
      Integer c = (Integer) ar.get('cnt');
      data.totalApplicants += c;
      data.applicantsByStatus.add(new LabelCount(s, c));
      // Hiring funnel stages
      if (s == 'Applied') {
        data.funnelApplied += c;
      } else if (s == 'Screening') {
        data.funnelApplied += c; // screening still part of applied stage
      } else if (s == 'Interview Scheduled') {
        data.funnelInterview += c;
      } else if (s == 'Offer Extended' || s == 'Selected') {
        data.funnelOffer += c;
      } else if (s == 'Accepted') {
        data.funnelAccepted += c;
      }
    }
  }

  private static void aggregateApplicantsBySource(DashboardData data) {
    for (AggregateResult ar : [
      SELECT Source__c src, COUNT(Id) cnt
      FROM PWChrono_Job_Applicant__c
      GROUP BY Source__c
    ]) {
      String src = (String) ar.get('src');
      Integer c = (Integer) ar.get('cnt');
      data.applicantsBySource.add(
        new LabelCount(String.isBlank(src) ? 'Unknown' : src, c)
      );
    }
  }

  private static void aggregateApplicantsByJobOpening(DashboardData data) {
    for (AggregateResult ar : [
      SELECT Job_Opening__r.Name jobName, COUNT(Id) cnt
      FROM PWChrono_Job_Applicant__c
      WHERE Job_Opening__c != NULL
      GROUP BY Job_Opening__r.Name
      ORDER BY COUNT(Id) DESC
      LIMIT 10
    ]) {
      // NOPMD
      data.applicantsByJobOpening.add(
        new LabelCount((String) ar.get('jobName'), (Integer) ar.get('cnt'))
      );
    }
  }

  private static void aggregateOffersByStatus(DashboardData data) {
    for (AggregateResult ar : [
      SELECT Offer_Status__c offerStatus, COUNT(Id) cnt
      FROM PWChrono_Job_Applicant__c
      WHERE Offer_Status__c != NULL AND Offer_Status__c != ''
      GROUP BY Offer_Status__c
    ]) {
      data.offersByStatus.add(
        new LabelCount((String) ar.get('offerStatus'), (Integer) ar.get('cnt'))
      );
    }
  }

  private static void aggregateDeptWiseOpenings(DashboardData data) {
    for (AggregateResult ar : [
      SELECT Department__r.Name deptName, COUNT(Id) cnt
      FROM PWChrono_Job_Opening__c
      WHERE Department__c != NULL
      GROUP BY Department__r.Name
      ORDER BY COUNT(Id) DESC
      LIMIT 10
    ]) {
      // NOPMD
      data.deptWiseOpenings.add(
        new LabelCount((String) ar.get('deptName'), (Integer) ar.get('cnt'))
      );
    }
  }

  private static void aggregateAvgTimeToFill(DashboardData data) {
    List<AggregateResult> results = [
      SELECT AVG(Time_to_Fill__c) avgFill
      FROM PWChrono_Job_Requisition__c
      WHERE Time_to_Fill__c != NULL
    ];
    if (!results.isEmpty() && results[0].get('avgFill') != null) {
      data.avgTimeToFill = ((Decimal) results[0].get('avgFill')).setScale(1);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Inner types
  // ─────────────────────────────────────────────────────────────────────────

  public class DashboardData {
    @AuraEnabled
    public Integer totalJobOpenings = 0;
    @AuraEnabled
    public Integer openJobOpenings = 0;
    @AuraEnabled
    public Integer closedJobOpenings = 0;
    @AuraEnabled
    public Integer totalApplicants = 0;
    @AuraEnabled
    public Decimal avgTimeToFill = 0;
    @AuraEnabled
    public Integer funnelApplied = 0;
    @AuraEnabled
    public Integer funnelInterview = 0;
    @AuraEnabled
    public Integer funnelOffer = 0;
    @AuraEnabled
    public Integer funnelAccepted = 0;
    @AuraEnabled
    public List<LabelCount> openingsByStatus = new List<LabelCount>();
    @AuraEnabled
    public List<LabelCount> applicantsByStatus = new List<LabelCount>();
    @AuraEnabled
    public List<LabelCount> applicantsBySource = new List<LabelCount>();
    @AuraEnabled
    public List<LabelCount> applicantsByJobOpening = new List<LabelCount>();
    @AuraEnabled
    public List<LabelCount> offersByStatus = new List<LabelCount>();
    @AuraEnabled
    public List<LabelCount> deptWiseOpenings = new List<LabelCount>();
  }

  public class LabelCount {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Integer count;
    public LabelCount(String l, Integer c) {
      this.label = l;
      this.count = c;
    }
  }
}