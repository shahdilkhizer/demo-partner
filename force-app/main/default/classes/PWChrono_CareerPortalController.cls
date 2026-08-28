/**
 * PWChrono_CareerPortalController
 * Public-facing career portal: browse open job postings and submit applications.
 * No HR-auth guard — portal is accessible to all (including guest users).
 */
public without sharing class PWChrono_CareerPortalController {
  // ─────────────────────────────────────────────────────────────────────────
  // Job Opening queries
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Returns open job postings with optional filters.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Job_Opening__c> getOpenJobs(
    String keyword,
    String departmentId,
    String company,
    String employmentType,
    String location
  ) {
    try {
      String companyLike = String.isNotBlank(company)
        ? '%' + company.trim() + '%'
        : null;
      String locationLike = String.isNotBlank(location)
        ? '%' + location.trim() + '%'
        : null;
      Integer queryLimit = PWChrono_Constants.DEFAULT_QUERY_LIMIT;
      String baseQuery =
        'SELECT Id, Name, Company__c, Location__c, Employment_Type__c, ' +
        'No_of_Positions__c, Closing_Date__c, Job_Description__c, ' +
        'Department__c, Department__r.Name, ' +
        'Designation__c, Designation__r.Name ' +
        'FROM PWChrono_Job_Opening__c ' +
        'WHERE Status__c = \'Open\'';

      if (String.isNotBlank(departmentId)) {
        baseQuery += ' AND Department__c = :departmentId';
      }
      if (companyLike != null) {
        baseQuery += ' AND Company__c LIKE :companyLike';
      }
      if (String.isNotBlank(employmentType)) {
        baseQuery += ' AND Employment_Type__c = :employmentType';
      }
      if (locationLike != null) {
        baseQuery += ' AND Location__c LIKE :locationLike';
      }

      baseQuery += ' ORDER BY CreatedDate DESC LIMIT :queryLimit';

      List<PWChrono_Job_Opening__c> jobs = Database.query(baseQuery);
      return filterJobsByKeyword(jobs, keyword);
    } catch (Exception e) {
      PWChrono_Logger.error('PWChrono_CareerPortalController.getOpenJobs', e);
      throw new AuraHandledException('Unable to load job openings.');
    }
  }

  private static List<PWChrono_Job_Opening__c> filterJobsByKeyword(
    List<PWChrono_Job_Opening__c> jobs,
    String keyword
  ) {
    if (String.isBlank(keyword)) {
      return jobs;
    }
    String normalizedKeyword = keyword.trim().toLowerCase();
    List<PWChrono_Job_Opening__c> filtered = new List<PWChrono_Job_Opening__c>();
    for (PWChrono_Job_Opening__c job : jobs) {
      String jobName = job.Name == null ? '' : job.Name.toLowerCase();
      String description = job.Job_Description__c == null
        ? ''
        : job.Job_Description__c.toLowerCase();
      if (
        jobName.contains(normalizedKeyword) ||
        description.contains(normalizedKeyword)
      ) {
        filtered.add(job);
      }
    }
    return filtered;
  }

  /**
   * Returns a single job opening by Id.
   */
  @AuraEnabled(cacheable=true)
  public static PWChrono_Job_Opening__c getJobById(String jobOpeningId) {
    try {
      List<PWChrono_Job_Opening__c> jobs = [
        SELECT
          Id,
          Name,
          Company__c,
          Location__c,
          Employment_Type__c,
          No_of_Positions__c,
          Closing_Date__c,
          Job_Description__c,
          Department__c,
          Department__r.Name,
          Designation__c,
          Designation__r.Name,
          Status__c
        FROM PWChrono_Job_Opening__c
        WHERE Id = :jobOpeningId AND Status__c = 'Open'
        LIMIT 1
      ];
      if (jobs.isEmpty()) {
        throw new AuraHandledException('Job opening not found.');
      }
      return jobs[0];
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      PWChrono_Logger.error('PWChrono_CareerPortalController.getJobById', e);
      throw new AuraHandledException('Unable to load job opening.');
    }
  }

  /**
   * Returns active departments for the filter dropdown.
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Department__c> getActiveDepartments() {
    try {
      return [
        SELECT Id, Name
        FROM PWChrono_Department__c
        WHERE Is_Active__c = TRUE
        ORDER BY Name ASC
        LIMIT 200
      ];
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_CareerPortalController.getActiveDepartments',
        e
      );
      throw new AuraHandledException(e.getMessage());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Application submission
  // ─────────────────────────────────────────────────────────────────────────

  /**
   * Inserts a Job Applicant record from the public application form.
   * @param applicationJson  JSON-serialised PWChrono_Job_Applicant__c fields.
   * @return  Id of the created record.
   */
  @AuraEnabled
  public static String submitApplication(String applicationJson) {
    try {
      if (String.isBlank(applicationJson)) {
        throw new AuraHandledException('Application data is required.');
      }
      if (!PWChrono_Job_Applicant__c.SObjectType.getDescribe().isCreateable()) {
        throw new AuraHandledException(
          'Applications are not available right now.'
        );
      }
      PWChrono_Job_Applicant__c applicant = (PWChrono_Job_Applicant__c) JSON.deserialize(
        applicationJson,
        PWChrono_Job_Applicant__c.class
      );
      validateApplication(applicant);
      applicant.Id = null; // always insert
      applicant.Status__c = 'Applied';
      applicant.Email__c = applicant.Email__c.trim().toLowerCase();

      List<PWChrono_Job_Applicant__c> duplicates = [
        SELECT Id
        FROM PWChrono_Job_Applicant__c
        WHERE
          Job_Opening__c = :applicant.Job_Opening__c
          AND Email__c = :applicant.Email__c
        LIMIT 1
      ];
      if (!duplicates.isEmpty()) {
        throw new AuraHandledException(
          'An application already exists for this job and email.'
        );
      }

      SObjectAccessDecision decision = Security.stripInaccessible(
        AccessType.CREATABLE,
        new List<SObject>{ applicant }
      );
      applicant = (PWChrono_Job_Applicant__c) decision.getRecords()[0];
      insert applicant;
      return applicant.Id;
    } catch (AuraHandledException e) {
      throw e;
    } catch (Exception e) {
      PWChrono_Logger.error(
        'PWChrono_CareerPortalController.submitApplication',
        e
      );
      throw new AuraHandledException('Unable to submit application.');
    }
  }

  private static void validateApplication(PWChrono_Job_Applicant__c applicant) {
    if (applicant == null) {
      throw new AuraHandledException('Application data is required.');
    }
    if (applicant.Job_Opening__c == null) {
      throw new AuraHandledException('Job opening is required.');
    }
    List<PWChrono_Job_Opening__c> openJobs = [
      SELECT Id
      FROM PWChrono_Job_Opening__c
      WHERE Id = :applicant.Job_Opening__c AND Status__c = 'Open'
      LIMIT 1
    ];
    if (openJobs.isEmpty()) {
      throw new AuraHandledException(
        'This job opening is no longer available.'
      );
    }
    if (String.isBlank(applicant.Name)) {
      throw new AuraHandledException('Applicant name is required.');
    }
    if (String.isBlank(applicant.Email__c)) {
      throw new AuraHandledException('Email is required.');
    }
    Pattern emailPattern = Pattern.compile('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$');
    if (!emailPattern.matcher(applicant.Email__c.trim()).matches()) {
      throw new AuraHandledException('Enter a valid email address.');
    }
  }
}