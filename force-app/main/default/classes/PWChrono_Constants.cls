public inherited sharing class PWChrono_Constants {
  public static final String ROLE_HR_ADMIN = 'HR Admin';
  public static final String ROLE_EMPLOYEE = 'Employee';
  public static final String ROLE_MANAGER = 'Manager';
  public static final String ROLE_PROJECT_MANAGER = 'Project Manager';

  public static final String STATUS_DRAFT = 'Draft';
  public static final String STATUS_SUBMITTED = 'Submitted';
  public static final String STATUS_APPROVED = 'Approved';
  public static final String STATUS_REJECTED = 'Rejected';
  public static final String STATUS_CANCELLED = 'Cancelled';
  public static final String STATUS_COMPLETED = 'Completed';
  public static final String STATUS_ACCEPTED = 'Accepted';
  public static final String STATUS_OFFER_EXTENDED = 'Offer Extended';
  public static final String STATUS_APPLIED = 'Applied';
  public static final String STATUS_SCHEDULED = 'Scheduled';
  public static final String STATUS_PAID = 'Paid';
  public static final String STATUS_OPEN = 'Open';
  public static final String STATUS_ACTIVE = 'Active';
  public static final String STATUS_PENDING = 'Pending';
  public static final String STATUS_NOT_STARTED = 'Not Started';
  public static final String STATUS_IN_PROGRESS = 'In Progress';

  public static final Integer DEFAULT_QUERY_LIMIT = 100;
  public static final Integer DASHBOARD_QUERY_LIMIT = 50;
  public static final Integer DEFAULT_BATCH_SIZE = 200;

  public static final String FEATURE_DELIMITER = ';';

  public static final String CURRENCY_CODE = 'USD';
  public static final String COMPANY_NAME = 'TechCorp Solutions';

  public static String getEffectiveCurrencyCode() {
    String userCurrency = UserInfo.getDefaultCurrency();
    return String.isNotBlank(userCurrency) ? userCurrency : CURRENCY_CODE;
  }

  public static final Integer OTP_EXPIRATION_MINUTES = 10;
  public static final Integer OTP_RESEND_COOLDOWN_MINUTES = 1;
  public static final Integer OTP_COUNTDOWN_SECONDS = 60;

  // Portal session token lifetime after OTP verification (Guest runtime).
  // Keep this reasonably short; users can re-authenticate via OTP as needed.
  public static final Integer PORTAL_SESSION_EXPIRATION_MINUTES = 480; // 8 hours
  public static final Integer PORTAL_SESSION_MAX_FAILED_ATTEMPTS = 5;
  public static final Integer PORTAL_SESSION_LOCKOUT_MINUTES = 15;
}