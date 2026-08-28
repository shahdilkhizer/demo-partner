/**
 * @description Service class for Recruitment operations
 */
public without sharing class PWChrono_RecruitmentService {
  public static List<PWChrono_Job_Opening__c> getJobOpenings(
    String statusFilter
  ) {
    Integer queryLimit = PWChrono_Constants.DASHBOARD_QUERY_LIMIT;
    if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
      return [
        SELECT
          Id,
          Name,
          Designation__c,
          Designation__r.Name,
          Department__c,
          Department__r.Name,
          No_of_Positions__c,
          Status__c,
          Closing_Date__c,
          Job_Description__c,
          CreatedDate
        FROM PWChrono_Job_Opening__c
        WHERE Status__c = :statusFilter
        ORDER BY CreatedDate DESC
        LIMIT :queryLimit
      ];
    }
    return [
      SELECT
        Id,
        Name,
        Designation__c,
        Designation__r.Name,
        Department__c,
        Department__r.Name,
        No_of_Positions__c,
        Status__c,
        Closing_Date__c,
        Job_Description__c,
        CreatedDate
      FROM PWChrono_Job_Opening__c
      ORDER BY CreatedDate DESC
      LIMIT :queryLimit
    ];
  }

  public static List<PWChrono_Job_Applicant__c> getJobApplicants(
    Id jobOpeningId,
    String statusFilter
  ) {
    Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
    Boolean hasStatusFilter =
      String.isNotBlank(statusFilter) && statusFilter != 'All';

    if (jobOpeningId != null && hasStatusFilter) {
      return [
        SELECT
          Id,
          Name,
          Email__c,
          Phone__c,
          Job_Opening__c,
          Job_Opening__r.Name,
          Status__c,
          Resume__c,
          CreatedDate
        FROM PWChrono_Job_Applicant__c
        WHERE Job_Opening__c = :jobOpeningId AND Status__c = :statusFilter
        ORDER BY CreatedDate DESC
        LIMIT :queryLimit
      ];
    }
    if (jobOpeningId != null) {
      return [
        SELECT
          Id,
          Name,
          Email__c,
          Phone__c,
          Job_Opening__c,
          Job_Opening__r.Name,
          Status__c,
          Resume__c,
          CreatedDate
        FROM PWChrono_Job_Applicant__c
        WHERE Job_Opening__c = :jobOpeningId
        ORDER BY CreatedDate DESC
        LIMIT :queryLimit
      ];
    }
    if (hasStatusFilter) {
      return [
        SELECT
          Id,
          Name,
          Email__c,
          Phone__c,
          Job_Opening__c,
          Job_Opening__r.Name,
          Status__c,
          Resume__c,
          CreatedDate
        FROM PWChrono_Job_Applicant__c
        WHERE Status__c = :statusFilter
        ORDER BY CreatedDate DESC
        LIMIT :queryLimit
      ];
    }
    return [
      SELECT
        Id,
        Name,
        Email__c,
        Phone__c,
        Job_Opening__c,
        Job_Opening__r.Name,
        Status__c,
        Resume__c,
        CreatedDate
      FROM PWChrono_Job_Applicant__c
      ORDER BY CreatedDate DESC
      LIMIT :queryLimit
    ];
  }

  public static PWChrono_Job_Applicant__c updateApplicantStatus(
    Id applicantId,
    String newStatus
  ) {
    List<PWChrono_Job_Applicant__c> applicants = [
      SELECT Id, Status__c
      FROM PWChrono_Job_Applicant__c
      WHERE Id = :applicantId
      LIMIT 1
    ];

    if (applicants.isEmpty()) {
      throw new AuraHandledException('Applicant not found.');
    }
    PWChrono_Job_Applicant__c applicant = applicants[0];

    // Validate status transition - prevent changes to finalized applicants
    if (
      applicant.Status__c == PWChrono_Constants.STATUS_ACCEPTED ||
      applicant.Status__c == PWChrono_Constants.STATUS_REJECTED
    ) {
      throw new AuraHandledException(
        'Cannot change status of finalized applicants (Accepted/Rejected).'
      );
    }

    applicant.Status__c = newStatus;
    update applicant;

    return applicant;
  }

  public static List<PWChrono_Interview__c> getApplicantInterviews(
    Id applicantId
  ) {
    return [
      SELECT
        Id,
        Name,
        Job_Applicant__c,
        Interview_Date__c,
        Round__c,
        Interviewers__c,
        Interviewers__r.Name,
        Result__c,
        Feedback__c
      FROM PWChrono_Interview__c
      WHERE Job_Applicant__c = :applicantId
      ORDER BY Interview_Date__c DESC
    ];
  }

  public static PWChrono_Interview__c scheduleInterview(
    PWChrono_Interview__c interview
  ) {
    if (interview.Id == null) {
      insert interview;
    } else {
      update interview;
    }

    return [
      SELECT
        Id,
        Name,
        Job_Applicant__c,
        Interview_Date__c,
        Round__c,
        Interviewers__c
      FROM PWChrono_Interview__c
      WHERE Id = :interview.Id
    ];
  }

  public static PWChrono_Offer_Letter__c generateOfferLetter(
    PWChrono_Offer_Letter__c offerLetter
  ) {
    if (offerLetter.Id == null) {
      insert offerLetter;
    } else {
      update offerLetter;
    }

    // Update applicant status to Offer Extended
    if (offerLetter.Job_Applicant__c != null) {
      List<PWChrono_Job_Applicant__c> applicants = [
        SELECT Id, Status__c
        FROM PWChrono_Job_Applicant__c
        WHERE Id = :offerLetter.Job_Applicant__c
        LIMIT 1
      ];
      if (!applicants.isEmpty()) {
        PWChrono_Job_Applicant__c applicant = applicants[0];
        applicant.Status__c = PWChrono_Constants.STATUS_OFFER_EXTENDED;
        update applicant;
      }
    }

    return [
      SELECT
        Id,
        Name,
        Job_Applicant__c,
        Designation__c,
        Offered_CTC__c,
        Joining_Date__c,
        Status__c
      FROM PWChrono_Offer_Letter__c
      WHERE Id = :offerLetter.Id
    ];
  }

  public class CandidateWrapper {
    @AuraEnabled
    public Id jobId;
    @AuraEnabled
    public String firstName;
    @AuraEnabled
    public String lastName;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public String phone;
    @AuraEnabled
    public Decimal experience;
  }

  public static void referCandidate(CandidateWrapper candidate) {
    Id currentUserId = UserInfo.getUserId();
    Id employeeId = PWChrono_Utils.getCurrentEmployeeId(currentUserId);

    if (employeeId == null) {
      throw new AuraHandledException(
        'No employee record found for current user.'
      );
    }

    // Check for duplicate email for this job
    List<PWChrono_Job_Applicant__c> existing = [
      SELECT Id
      FROM PWChrono_Job_Applicant__c
      WHERE Job_Opening__c = :candidate.jobId AND Email__c = :candidate.email
    ];

    if (!existing.isEmpty()) {
      throw new AuraHandledException(
        'Candidate with this email already applied for this job.'
      );
    }

    PWChrono_Job_Applicant__c applicant = new PWChrono_Job_Applicant__c(
      Name = candidate.firstName + ' ' + candidate.lastName,
      Job_Opening__c = candidate.jobId,
      Email__c = candidate.email,
      Phone__c = candidate.phone,
      Experience_Years__c = candidate.experience,
      Referrers__c = employeeId,
      Status__c = PWChrono_Constants.STATUS_APPLIED
    );
    insert applicant;
  }

  public static List<PWChrono_Department__c> getActiveDepartments() {
    return [
      SELECT Id, Name
      FROM PWChrono_Department__c
      WHERE Is_Active__c = TRUE
      ORDER BY Name
    ];
  }

  public static List<PWChrono_Designation__c> getActiveDesignations() {
    return [
      SELECT Id, Name
      FROM PWChrono_Designation__c
      WHERE Is_Active__c = TRUE
      ORDER BY Name
    ];
  }

  public static List<Portal_Users__c> getPotentialInterviewers() {
    Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
    return [
      SELECT Id, Name
      FROM Portal_Users__c
      ORDER BY Name
      LIMIT :queryLimit
    ];
  }
}