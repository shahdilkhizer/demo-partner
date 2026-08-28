/**
 * @description Data controller for Help Desk Dashboard LWC.
 */
public inherited sharing class PWChrono_HelpDeskDashboardController {
  public class HelpDeskDashboardDTO {
    @AuraEnabled
    public Integer totalTickets;
    @AuraEnabled
    public Integer openTickets;
    @AuraEnabled
    public Integer resolvedToday;
    @AuraEnabled
    public Integer overdueTickets;
    @AuraEnabled
    public Decimal avgResolutionHours;
    @AuraEnabled
    public Integer activeAgents;

    @AuraEnabled
    public List<String> trendLabels;
    @AuraEnabled
    public List<Integer> createdTrend;
    @AuraEnabled
    public List<Integer> resolvedTrend;

    @AuraEnabled
    public Map<String, Integer> statusCounts;
    @AuraEnabled
    public Map<String, Integer> categoryCounts;
  }

  @AuraEnabled(cacheable=true)
  public static HelpDeskDashboardDTO getDashboardSummary() {
    HelpDeskDashboardDTO dto = new HelpDeskDashboardDTO();
    dto.statusCounts = new Map<String, Integer>{
      'open' => 0,
      'inProgress' => 0,
      'onHold' => 0,
      'closed' => 0
    };
    dto.categoryCounts = new Map<String, Integer>{
      'itSupport' => 0,
      'hr' => 0,
      'payroll' => 0,
      'access' => 0,
      'hardware' => 0,
      'other' => 0
    };

    dto.totalTickets = 0;
    dto.openTickets = 0;
    dto.resolvedToday = 0;

    try {
      dto.totalTickets = (Integer) Database.countQuery(
        'SELECT COUNT() FROM Case'
      );
      dto.openTickets = (Integer) Database.countQuery(
        'SELECT COUNT() FROM Case WHERE IsClosed = false'
      );
      dto.resolvedToday = (Integer) Database.countQuery(
        'SELECT COUNT() FROM Case WHERE IsClosed = true AND ClosedDate = TODAY'
      );
    } catch (Exception e) {
      dto.totalTickets = 0;
      dto.openTickets = 0;
      dto.resolvedToday = 0;
    }

    dto.overdueTickets = getOverdueTicketsCount();
    dto.avgResolutionHours = getAverageResolutionHoursLast30Days();
    dto.activeAgents = getActiveAgentsCount();

    try {
      populateTrend(dto);
    } catch (Exception e) {
      dto.trendLabels = new List<String>();
      dto.createdTrend = new List<Integer>();
      dto.resolvedTrend = new List<Integer>();
    }

    try {
      populateStatusBuckets(dto);
    } catch (Exception e) {
      dto.statusCounts = new Map<String, Integer>{
        'open' => 0,
        'inProgress' => 0,
        'onHold' => 0,
        'closed' => 0
      };
    }

    try {
      populateCategoryBuckets(dto);
    } catch (Exception e) {
      dto.categoryCounts = new Map<String, Integer>{
        'itSupport' => 0,
        'hr' => 0,
        'payroll' => 0,
        'access' => 0,
        'hardware' => 0,
        'other' => 0
      };
    }

    return dto;
  }

  private static Integer getOverdueTicketsCount() {
    try {
      Map<String, Schema.SObjectField> fields = Schema.SObjectType.Case.fields.getMap();
      if (!fields.containsKey('Due_Date__c')) {
        return 0;
      }
      return (Integer) Database.countQuery(
        'SELECT COUNT() FROM Case WHERE IsClosed = false AND Due_Date__c < TODAY'
      );
    } catch (Exception e) {
      return 0;
    }
  }

  private static Decimal getAverageResolutionHoursLast30Days() {
    try {
      List<Case> closedCases = [
        SELECT CreatedDate, ClosedDate
        FROM Case
        WHERE IsClosed = TRUE AND ClosedDate = LAST_N_DAYS:30
        ORDER BY ClosedDate DESC
        LIMIT 2000
      ];

      if (closedCases.isEmpty()) {
        return 0;
      }

      Long totalMillis = 0;
      Integer counted = 0;
      for (Case c : closedCases) {
        if (c.CreatedDate == null || c.ClosedDate == null)
          continue;
        totalMillis += (c.ClosedDate.getTime() - c.CreatedDate.getTime());
        counted++;
      }
      if (counted == 0) {
        return 0;
      }
      Decimal avgHours =
        (Decimal.valueOf(totalMillis) / (1000 * 60 * 60)) / counted;
      return avgHours.setScale(1);
    } catch (Exception e) {
      return 0;
    }
  }

  private static Integer getActiveAgentsCount() {
    try {
      Integer agents = 0;
      for (AggregateResult ar : [
        SELECT OwnerId oid
        FROM Case
        WHERE IsClosed = FALSE
        GROUP BY OwnerId
      ]) {
        if (ar.get('oid') != null) {
          agents++;
        }
      }
      return agents;
    } catch (Exception e) {
      return 0;
    }
  }

  private static void populateTrend(HelpDeskDashboardDTO dto) {
    Date today = Date.today();

    List<Date> days = new List<Date>();
    for (Integer i = 6; i >= 0; i--) {
      days.add(today.addDays(-i));
    }

    Map<Date, Integer> createdByDay = new Map<Date, Integer>();
    for (AggregateResult ar : [
      SELECT DAY_ONLY(CreatedDate) d, COUNT(Id) c
      FROM Case
      WHERE CreatedDate = LAST_N_DAYS:7
      GROUP BY DAY_ONLY(CreatedDate)
    ]) {
      Date d = (Date) ar.get('d');
      Integer c = (Integer) ar.get('c');
      if (d != null)
        createdByDay.put(d, c == null ? 0 : c);
    }

    Map<Date, Integer> resolvedByDay = new Map<Date, Integer>();
    for (AggregateResult ar : [
      SELECT DAY_ONLY(ClosedDate) d, COUNT(Id) c
      FROM Case
      WHERE IsClosed = TRUE AND ClosedDate = LAST_N_DAYS:7
      GROUP BY DAY_ONLY(ClosedDate)
    ]) {
      Date d = (Date) ar.get('d');
      Integer c = (Integer) ar.get('c');
      if (d != null)
        resolvedByDay.put(d, c == null ? 0 : c);
    }

    dto.trendLabels = new List<String>();
    dto.createdTrend = new List<Integer>();
    dto.resolvedTrend = new List<Integer>();

    for (Date d : days) {
      dto.trendLabels.add(formatDateLabel(d, 'EEE'));
      dto.createdTrend.add(
        createdByDay.containsKey(d) ? createdByDay.get(d) : 0
      );
      dto.resolvedTrend.add(
        resolvedByDay.containsKey(d) ? resolvedByDay.get(d) : 0
      );
    }
  }

  private static String formatDateLabel(Date value, String pattern) {
    if (value == null) {
      return '';
    }
    return Datetime.newInstance(value, Time.newInstance(0, 0, 0, 0))
      .format(pattern);
  }

  private static void populateStatusBuckets(HelpDeskDashboardDTO dto) {
    Integer closedCount = (Integer) Database.countQuery(
      'SELECT COUNT() FROM Case WHERE IsClosed = true'
    );
    dto.statusCounts.put('closed', closedCount);

    for (AggregateResult ar : [
      SELECT Status st, COUNT(Id) c
      FROM Case
      WHERE IsClosed = FALSE
      GROUP BY Status
    ]) {
      String st = (String) ar.get('st');
      Integer c = (Integer) ar.get('c');
      Integer cnt = (c == null ? 0 : c);

      String bucket = bucketStatus(st);
      dto.statusCounts.put(
        bucket,
        (dto.statusCounts.get(bucket) == null
          ? 0
          : dto.statusCounts.get(bucket)) + cnt
      );
    }
  }

  private static String bucketStatus(String status) {
    String s = (status == null) ? '' : status.trim().toLowerCase();
    if (s.contains('hold') || s.contains('pending'))
      return 'onHold';
    if (
      s.contains('progress') ||
      s.contains('working') ||
      s.contains('investig')
    )
      return 'inProgress';
    return 'open';
  }

  private static void populateCategoryBuckets(HelpDeskDashboardDTO dto) {
    for (AggregateResult ar : [
      SELECT Type tp, COUNT(Id) c
      FROM Case
      GROUP BY Type
    ]) {
      String tp = (String) ar.get('tp');
      Integer c = (Integer) ar.get('c');
      Integer cnt = (c == null ? 0 : c);
      String bucket = bucketCategory(tp);
      dto.categoryCounts.put(
        bucket,
        (dto.categoryCounts.get(bucket) == null
          ? 0
          : dto.categoryCounts.get(bucket)) + cnt
      );
    }
  }

  private static String bucketCategory(String typeValue) {
    String s = (typeValue == null) ? '' : typeValue.trim().toLowerCase();
    if (s.contains('it'))
      return 'itSupport';
    if (s.contains('hr'))
      return 'hr';
    if (s.contains('pay'))
      return 'payroll';
    if (s.contains('access'))
      return 'access';
    if (s.contains('hard'))
      return 'hardware';
    return 'other';
  }
}