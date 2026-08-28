/**
 * @description Data controller for Payroll Dashboard LWC.
 *              All SOQL runs in system context intentionally — guest user
 *              access is gated by requireHRAccess() session token validation
 *              before any data is returned.
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public inherited sharing class PWChrono_PayrollDashboardController {
  /** @description Data transfer object carrying Payroll Dashboard metrics. */
  public class PayrollDashboardDTO {
    @AuraEnabled
    public Decimal totalGross;
    @AuraEnabled
    public Decimal totalNet;
    @AuraEnabled
    public Decimal totalDeductions;
    @AuraEnabled
    public Decimal highestGross;
    @AuraEnabled
    public Decimal lowestGross;
    @AuraEnabled
    public Decimal averageGross;

    @AuraEnabled
    public List<String> salaryRangeLabels;
    @AuraEnabled
    public List<Integer> salaryRangeCounts;

    @AuraEnabled
    public List<String> trendLabels;
    @AuraEnabled
    public List<Decimal> taxTrend;
    @AuraEnabled
    public List<Decimal> deductionTrend;
  }

  private static void requireHRAccess(
    String portalUserId,
    String sessionToken
  ) {
    if (UserInfo.getUserType() != 'Guest') {
      return;
    }
    Id verifiedId = PWChrono_GuestSession.requireVerifiedPortalUserId(
      portalUserId,
      sessionToken
    );
    Portal_Users__c caller = [
      SELECT Role__c
      FROM Portal_Users__c
      WHERE Id = :verifiedId
      LIMIT 1
    ];
    if (caller.Role__c != PWChrono_Constants.ROLE_HR_ADMIN) {
      throw new AuraHandledException('Unauthorized.');
    }
  }

  /**
   * @description Returns payroll summary metrics for the current month.
   * @param portalUserId Id of the Portal_Users__c record for the requesting user
   * @param sessionToken Active session token for the requesting user
   * @return PayrollDashboardDTO with payroll summary and trend data
   */
  @AuraEnabled
  public static PayrollDashboardDTO getDashboardSummary(
    String portalUserId,
    String sessionToken
  ) {
    requireHRAccess(portalUserId, sessionToken);
    Date today = Date.today();
    Date startMonth = Date.newInstance(today.year(), today.month(), 1);
    Date endMonth = startMonth.addMonths(1).addDays(-1);

    PayrollDashboardDTO dto;
    try {
      dto = buildSummaryForRange(startMonth, endMonth);
    } catch (Exception e) {
      dto = createDefaultSummary();
    }

    try {
      populateSixMonthTrend(dto, startMonth);
    } catch (Exception e) {
      dto.trendLabels = new List<String>{
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
        'Jan'
      };
      dto.taxTrend = new List<Decimal>{ 0, 0, 0, 0, 0, 0 };
      dto.deductionTrend = new List<Decimal>{ 0, 0, 0, 0, 0, 0 };
    }

    return dto;
  }

  private static PayrollDashboardDTO createDefaultSummary() {
    PayrollDashboardDTO dto = new PayrollDashboardDTO();
    dto.totalGross = 0;
    dto.totalNet = 0;
    dto.totalDeductions = 0;
    dto.highestGross = 0;
    dto.lowestGross = 0;
    dto.averageGross = 0;
    dto.salaryRangeLabels = new List<String>{
      '$10k-$25k',
      '$25k-$50k',
      '$50k-$75k',
      '$75k-$100k',
      '$100k+'
    };
    dto.salaryRangeCounts = new List<Integer>{ 0, 0, 0, 0, 0 };
    dto.trendLabels = new List<String>{
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
      'Jan'
    };
    dto.taxTrend = new List<Decimal>{ 0, 0, 0, 0, 0, 0 };
    dto.deductionTrend = new List<Decimal>{ 0, 0, 0, 0, 0, 0 };
    return dto;
  }

  @SuppressWarnings('PMD.NcssMethodCount,PMD.CyclomaticComplexity,PMD.CognitiveComplexity')
  private static PayrollDashboardDTO buildSummaryForRange(
    Date startDate,
    Date endDate
  ) {
    PayrollDashboardDTO dto = new PayrollDashboardDTO();
    dto.totalGross = 0;
    dto.totalNet = 0;
    dto.totalDeductions = 0;
    dto.highestGross = 0;
    dto.lowestGross = 0;
    dto.averageGross = 0;

    List<PWChrono_Salary_Slip__c> slips = [
      SELECT Gross_Pay__c, Net_Pay__c, Total_Deductions__c, Payroll_Period__c
      FROM PWChrono_Salary_Slip__c
      WHERE Payroll_Period__c >= :startDate AND Payroll_Period__c <= :endDate
    ];

    Decimal highest = null;
    Decimal lowest = null;
    Decimal sumGross = 0;
    Integer counted = 0;

    List<Integer> bins = new List<Integer>{ 0, 0, 0, 0, 0 };

    for (PWChrono_Salary_Slip__c s : slips) {
      Decimal gross = (s.Gross_Pay__c == null ? 0 : s.Gross_Pay__c);
      Decimal net = (s.Net_Pay__c == null ? 0 : s.Net_Pay__c);
      Decimal ded = (s.Total_Deductions__c == null ? 0 : s.Total_Deductions__c);

      dto.totalGross += gross;
      dto.totalNet += net;
      dto.totalDeductions += ded;

      if (highest == null || gross > highest) {
        highest = gross;
      }
      if (lowest == null || gross < lowest) {
        lowest = gross;
      }
      sumGross += gross;
      counted++;

      Integer idx = salaryBinIndex(gross);
      if (idx >= 0 && idx < bins.size()) {
        bins[idx] = bins[idx] + 1;
      }
    }

    dto.highestGross = (highest == null ? 0 : highest);
    dto.lowestGross = (lowest == null ? 0 : lowest);
    dto.averageGross = (counted == 0 ? 0 : (sumGross / counted).setScale(0));

    dto.salaryRangeLabels = new List<String>{
      '$10k-$25k',
      '$25k-$50k',
      '$50k-$75k',
      '$75k-$100k',
      '$100k+'
    };
    dto.salaryRangeCounts = bins;

    return dto;
  }

  private static Integer salaryBinIndex(Decimal gross) {
    Decimal g = (gross == null ? 0 : gross);
    if (g < 25000) {
      return 0;
    } else if (g < 50000) {
      return 1;
    } else if (g < 75000) {
      return 2;
    } else if (g < 100000) {
      return 3;
    }
    return 4;
  }

  @SuppressWarnings('PMD.CognitiveComplexity')
  private static void populateSixMonthTrend(
    PayrollDashboardDTO dto,
    Date startMonth
  ) {
    Date start = startMonth.addMonths(-5);
    Date endDate = startMonth.addMonths(1).addDays(-1);

    Map<String, AggregateResult> byKey = new Map<String, AggregateResult>();
    for (AggregateResult ar : [
      SELECT
        CALENDAR_YEAR(Payroll_Period__c) y,
        CALENDAR_MONTH(Payroll_Period__c) m,
        SUM(Gross_Pay__c) g,
        SUM(Net_Pay__c) n,
        SUM(Total_Deductions__c) d
      FROM PWChrono_Salary_Slip__c
      WHERE Payroll_Period__c >= :start AND Payroll_Period__c <= :endDate
      GROUP BY
        CALENDAR_YEAR(Payroll_Period__c),
        CALENDAR_MONTH(Payroll_Period__c)
    ]) {
      Integer y = (Integer) ar.get('y');
      Integer m = (Integer) ar.get('m');
      if (y == null || m == null) {
        continue;
      }
      byKey.put(String.valueOf(y) + '-' + String.valueOf(m), ar);
    }

    dto.trendLabels = new List<String>();
    dto.taxTrend = new List<Decimal>();
    dto.deductionTrend = new List<Decimal>();

    for (Integer i = 0; i < 6; i++) {
      Date d = start.addMonths(i);
      String key = String.valueOf(d.year()) + '-' + String.valueOf(d.month());
      AggregateResult ar = byKey.get(key);

      Decimal tax = 0;
      Decimal ded = 0;
      if (ar != null) {
        Decimal g = (Decimal) ar.get('g');
        Decimal n = (Decimal) ar.get('n');
        Decimal dd = (Decimal) ar.get('d');
        tax = (dd == null ? 0 : dd);
        ded = ((g == null ? 0 : g) - (n == null ? 0 : n));
      }

      dto.trendLabels.add(formatDateLabel(d, 'MMM'));
      dto.taxTrend.add(tax.setScale(0));
      dto.deductionTrend.add(ded.setScale(0));
    }
  }

  private static String formatDateLabel(Date value, String pattern) {
    if (value == null) {
      return '';
    }
    return Datetime.newInstance(value, Time.newInstance(0, 0, 0, 0))
      .format(pattern);
  }
}