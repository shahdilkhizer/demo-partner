/**
 * @description Controller for Recruitment Management LWC Components
 * @author PWChrono Team
 */
@SuppressWarnings('PMD.CognitiveComplexity')
public without sharing class PWChrono_RecruitmentController {
  @TestVisible
  private static Boolean forceGuestCheckForTest = false;

  @TestVisible
  private static Boolean hasFeature(String accessFeatures, String featureName) {
    if (String.isBlank(accessFeatures) || String.isBlank(featureName)) {
      return false;
    }
    for (String part : accessFeatures.split('\\s*;\\s*')) {
      if (part.equalsIgnoreCase(featureName)) {
        return true;
      }
    }
    return false;
  }

  @TestVisible
  private static void requireRecruitmentAccessForGuest(
    String portalUserId,
    String sessionToken
  ) {
    Id actorId = UserInfo.getUserType() == 'Guest'
      ? PWChrono_GuestSession.requireVerifiedPortalUserId(
          portalUserId,
          sessionToken
        )
      : (String.isBlank(portalUserId)
          ? null
          : PWChrono_RequestValidator.resolveEmployeeId(
              portalUserId,
              sessionToken
            ));
    PWChrono_AccessController.requireFeature(actorId, 'Recruitment');
  }

  /**
   * @description Get job openings
   * @param statusFilter Status filter (All, Open, Closed, On Hold)
   * @return List of job openings
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Job_Opening__c> getJobOpenings(
    String statusFilter
  ) {
    try {
      return PWChrono_RecruitmentService.getJobOpenings(statusFilter);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching job openings: '
      );
      ahe.setMessage('Error fetching job openings: ');
      throw ahe;
    }
  }

  /**
   * @description Get job applicants by status
   * @param jobOpeningId Optional job opening filter
   * @param statusFilter Status filter
   * @return List of job applicants
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Job_Applicant__c> getJobApplicants(
    Id jobOpeningId,
    String statusFilter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireRecruitmentAccessForGuest(portalUserId, sessionToken);
      return PWChrono_RecruitmentService.getJobApplicants(
        jobOpeningId,
        statusFilter
      );
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      if (e instanceof AuraHandledException) {
        throw e;
      }
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching applicants: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching applicants: ' + e.getMessage());
      throw ahe;
    }
  }

  /**
   * @description Update applicant status (for kanban drag-drop)
   * @param applicantId Applicant ID
   * @param newStatus New status value
   * @return Updated applicant record
   */
  @AuraEnabled
  public static PWChrono_Job_Applicant__c updateApplicantStatus(
    Id applicantId,
    String newStatus,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireRecruitmentAccessForGuest(portalUserId, sessionToken);
      return PWChrono_RecruitmentService.updateApplicantStatus(
        applicantId,
        newStatus
      );
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      if (e instanceof AuraHandledException) {
        throw e;
      }
      AuraHandledException ahe = new AuraHandledException(
        'Error updating applicant status: ' + e.getMessage()
      );
      ahe.setMessage('Error updating applicant status: ' + e.getMessage());
      throw ahe;
    }
  }

  /**
   * @description Get interviews for an applicant
   * @param applicantId Job applicant ID
   * @return List of interviews
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Interview__c> getApplicantInterviews(
    Id applicantId,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireRecruitmentAccessForGuest(portalUserId, sessionToken);
      return PWChrono_RecruitmentService.getApplicantInterviews(applicantId);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching interviews: '
      );
      ahe.setMessage('Error fetching interviews: ');
      throw ahe;
    }
  }

  /**
   * @description Schedule interview
   * @param interview Interview record
   * @return Saved interview record
   */
  @AuraEnabled
  public static PWChrono_Interview__c scheduleInterview(
    PWChrono_Interview__c interview,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireRecruitmentAccessForGuest(portalUserId, sessionToken);
      return PWChrono_RecruitmentService.scheduleInterview(interview);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      if (e instanceof AuraHandledException) {
        throw e;
      }
      AuraHandledException ahe = new AuraHandledException(
        'Error scheduling interview: ' + e.getMessage()
      );
      ahe.setMessage('Error scheduling interview: ' + e.getMessage());
      throw ahe;
    }
  }

  /**
   * @description Generate offer letter
   * @param offerLetter Offer letter record
   * @return Saved offer letter
   */
  @AuraEnabled
  public static PWChrono_Offer_Letter__c generateOfferLetter(
    PWChrono_Offer_Letter__c offerLetter,
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireRecruitmentAccessForGuest(portalUserId, sessionToken);
      return PWChrono_RecruitmentService.generateOfferLetter(offerLetter);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      if (e instanceof AuraHandledException) {
        throw e;
      }
      AuraHandledException ahe = new AuraHandledException(
        'Error generating offer letter: ' + e.getMessage()
      );
      ahe.setMessage('Error generating offer letter: ' + e.getMessage());
      throw ahe;
    }
  }

  /**
   * @description Get active departments for dropdown
   * @return List of departments
   */
  @AuraEnabled(cacheable=false)
  public static List<PWChrono_Department__c> getActiveDepartments(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireRecruitmentAccessForGuest(portalUserId, sessionToken);
      return PWChrono_RecruitmentService.getActiveDepartments();
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      if (e instanceof AuraHandledException) {
        throw e;
      }
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching departments: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching departments: ' + e.getMessage());
      throw ahe;
    }
  }

  /**
   * @description Get active designations for dropdown
   * @return List of designations
   */
  @AuraEnabled(cacheable=true)
  public static List<PWChrono_Designation__c> getActiveDesignations(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireRecruitmentAccessForGuest(portalUserId, sessionToken);
      return PWChrono_RecruitmentService.getActiveDesignations();
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      if (e instanceof AuraHandledException) {
        throw e;
      }
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching designations: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching designations: ' + e.getMessage());
      throw ahe;
    }
  }

  /**
   * @description Get potential interviewers (employees)
   * @return List of employees
   */
  @AuraEnabled(cacheable=true)
  public static List<Portal_Users__c> getPotentialInterviewers(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireRecruitmentAccessForGuest(portalUserId, sessionToken);
      return PWChrono_RecruitmentService.getPotentialInterviewers();
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      if (e instanceof AuraHandledException) {
        throw e;
      }
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching interviewers: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching interviewers: ' + e.getMessage());
      throw ahe;
    }
  }

  /**
   * @description Refer a candidate for a job
   * @param jobId Job Opening ID
   * @param firstName Candidate First Name
   * @param lastName Candidate Last Name
   * @param email Candidate Email
   * @param phone Candidate Phone
   * @param experience Experience in Years
   */
  @AuraEnabled
  @SuppressWarnings('PMD.ExcessiveParameterList')
  public static void referCandidate(
    Id jobId,
    String firstName,
    String lastName,
    String email,
    String phone,
    Decimal experience,
    String portalUserId,
    String sessionToken
  ) {
    try {
      if (UserInfo.getUserType() == 'Guest') {
        requireRecruitmentAccessForGuest(portalUserId, sessionToken);
      }

      PWChrono_RecruitmentService.CandidateWrapper candidate = new PWChrono_RecruitmentService.CandidateWrapper();
      candidate.jobId = jobId;
      candidate.firstName = firstName;
      candidate.lastName = lastName;
      candidate.email = email;
      candidate.phone = phone;
      candidate.experience = experience;
      candidate.portalUserId = portalUserId;

      PWChrono_RecruitmentService.referCandidate(candidate);
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      if (e instanceof AuraHandledException) {
        throw e;
      }
      AuraHandledException ahe = new AuraHandledException(
        'Error referring candidate: ' + e.getMessage()
      );
      ahe.setMessage('Error referring candidate: ' + e.getMessage());
      throw ahe;
    }
  }

  /**
   * @description Get aggregate metrics across recruitment process
   * @return Map with counts for requisitions, openings, applicants, offers, referrals
   */
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getRecruitmentDashboardMetrics(
    String portalUserId,
    String sessionToken
  ) {
    try {
      requireRecruitmentAccessForGuest(portalUserId, sessionToken);
      return PWChrono_RecruitmentService.getRecruitmentDashboardMetrics();
    } catch (Exception e) {
      PWChrono_Logger.error('An error occurred', e);
      if (e instanceof AuraHandledException) {
        throw e;
      }
      AuraHandledException ahe = new AuraHandledException(
        'Error fetching recruitment metrics: ' + e.getMessage()
      );
      ahe.setMessage('Error fetching recruitment metrics: ' + e.getMessage());
      throw ahe;
    }
  }
}