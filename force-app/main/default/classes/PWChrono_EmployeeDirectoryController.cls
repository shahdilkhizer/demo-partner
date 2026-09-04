public inherited sharing class PWChrono_EmployeeDirectoryController {
  private static final String NOT_PROVIDED = 'Not provided';
  @TestVisible
  private static String testUserTypeOverride;
  @TestVisible
  private static Boolean testCanViewAllSensitiveOverride;

  public class EmployeeDirectoryException extends Exception {
  }

  private class DirectoryAccessContext {
    public Boolean canViewSensitive = false;
  }

  public class PersonalInfoWrapper {
    @AuraEnabled
    public String passportNo { get; set; }
    @AuraEnabled
    public String passportExpDate { get; set; }
    @AuraEnabled
    public String nationality { get; set; }
    @AuraEnabled
    public String religion { get; set; }
    @AuraEnabled
    public String maritalStatus { get; set; }
    @AuraEnabled
    public String spouseEmployment { get; set; }
    @AuraEnabled
    public String noOfChildren { get; set; }
  }

  public class BankInfoWrapper {
    @AuraEnabled
    public String bankName { get; set; }
    @AuraEnabled
    public String maskedAccountNumber { get; set; }
    @AuraEnabled
    public String swiftCode { get; set; }
    @AuraEnabled
    public String branch { get; set; }
    @AuraEnabled
    public Boolean hasBankInformation { get; set; }
  }

  public class EmergencyContactWrapper {
    @AuraEnabled
    public String primaryName { get; set; }
    @AuraEnabled
    public String primaryRelationship { get; set; }
    @AuraEnabled
    public String primaryPhone { get; set; }
    @AuraEnabled
    public String secondaryName { get; set; }
    @AuraEnabled
    public String secondaryRelationship { get; set; }
    @AuraEnabled
    public String secondaryPhone { get; set; }
  }

  public class FamilyInfoWrapper {
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String relationship { get; set; }
    @AuraEnabled
    public String dateOfBirth { get; set; }
    @AuraEnabled
    public String phone { get; set; }
  }

  public class AssetInfoWrapper {
    @AuraEnabled
    public String brand { get; set; }
    @AuraEnabled
    public String model { get; set; }
    @AuraEnabled
    public String processorType { get; set; }
    @AuraEnabled
    public String processorSpeed { get; set; }
    @AuraEnabled
    public String ram { get; set; }
    @AuraEnabled
    public String storage { get; set; }
    @AuraEnabled
    public String screenSize { get; set; }
    @AuraEnabled
    public String displayText { get; set; }
    @AuraEnabled
    public Boolean hasAssetInformation { get; set; }
  }

  public class EmployeeWrapper {
    @AuraEnabled
    public String id { get; set; }
    @AuraEnabled
    public String empId { get; set; }
    @AuraEnabled
    public String firstName { get; set; }
    @AuraEnabled
    public String lastName { get; set; }
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String title { get; set; }
    @AuraEnabled
    public String department { get; set; }
    @AuraEnabled
    public String email { get; set; }
    @AuraEnabled
    public String phone { get; set; }
    @AuraEnabled
    public String address { get; set; }
    @AuraEnabled
    public String joiningDate { get; set; }
    @AuraEnabled
    public String status { get; set; }
    @AuraEnabled
    public String statusClass { get; set; }
    @AuraEnabled
    public String initials { get; set; }
    @AuraEnabled
    public String avatarUrl { get; set; }
    @AuraEnabled
    public String managerName { get; set; }
    @AuraEnabled
    public String about { get; set; }
    @AuraEnabled
    public Integer projects { get; set; }
    @AuraEnabled
    public Integer done { get; set; }
    @AuraEnabled
    public Integer progress { get; set; }
    @AuraEnabled
    public Integer productivity { get; set; }
    @AuraEnabled
    public String productivityClass { get; set; }
    @AuraEnabled
    public String gender { get; set; }
    @AuraEnabled
    public String birthDateFormatted { get; set; }
    @AuraEnabled
    public String accountName { get; set; }
    @AuraEnabled
    public String experienceYears { get; set; }
    @AuraEnabled
    public Boolean canViewSensitive { get; set; }
    @AuraEnabled
    public PersonalInfoWrapper personalInfo { get; set; }
    @AuraEnabled
    public BankInfoWrapper bankInfo { get; set; }
    @AuraEnabled
    public EmergencyContactWrapper emergencyContact { get; set; }
    @AuraEnabled
    public FamilyInfoWrapper familyInfo { get; set; }
    @AuraEnabled
    public AssetInfoWrapper assetInfo { get; set; }
  }

  private static final String SELECT_FIELDS =
    'SELECT Id, FirstName, LastName, Name, Title, Department, Email, Phone, MobilePhone, ' +
    'MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, ' +
    'Birthdate, CreatedDate, Description, ReportsToId, ReportsTo.Name, Account.Name, ' +
    'GenderIdentity, Employee_ID__c, Date_of_Joining__c, Experience_Years__c, ' +
    'Bank_Name__c, Account_Number__c, SWIFT_Code__c, Branch_Name_Code__c, ' +
    'Passport_No__c, Passport_Exp_Date__c, Nationality__c, Religion__c, ' +
    'Marital_Status__c, Employment_of_Spouse__c, No_of_Children__c, ' +
    'Emergency_Contact_Name__c, Emergency_Contact_Relationship__c, Emergency_Contact_Number__c, ' +
    'Secondary_Emergency_Contact_Name__c, Secondary_Emergency_Contact_Relationship__c, ' +
    'Secondary_Emergency_Contact_Number__c, Family_Member_Name__c, ' +
    'Family_Member_Relationship__c, Family_Member_DOB__c, Family_Member_Phone__c, ' +
    'Laptop_Brand__c, Model__c, Processor_Type__c, Processor_Speed_GHz__c, RAM_GB__c, ' +
    'Storage__c, Screen_Size_inches__c, ' +
    '(SELECT Id, Photo_Url__c, Is_Active__c FROM Portal_Users__r ORDER BY CreatedDate DESC LIMIT 1) ' +
    'FROM Contact ';

  private static DirectoryAccessContext requireDirectoryAccess(
    String callerPortalUserId,
    String sessionToken,
    String operation,
    Id targetContactId
  ) {
    DirectoryAccessContext context = new DirectoryAccessContext();
    if (!isGuestRuntime()) {
      Schema.DescribeSObjectResult contactDescribe = Contact.SObjectType.getDescribe();
      Boolean allowed = operation == 'create'
        ? contactDescribe.isCreateable()
        : operation == 'edit'
            ? contactDescribe.isUpdateable()
            : operation == 'delete'
                ? contactDescribe.isDeletable()
                : contactDescribe.isAccessible();
      if (!allowed) {
        throw new AuraHandledException(
          'You do not have permission to access employee records.'
        );
      }
      // Contact read access alone must not expose payroll, identity, or family
      // details for every employee. Allow sensitive detail only for the
      // current employee's own Contact or an explicitly authorized payroll
      // manager. stripInaccessible() still enforces field-level visibility.
      context.canViewSensitive =
        targetContactId != null &&
        (canViewAllSensitiveEmployeeData() ||
        targetContactId == resolveCurrentUserContactId());
      return context;
    }

    Id verifiedPortalUserId = PWChrono_GuestSession.requireVerifiedPortalUserId(
      callerPortalUserId,
      sessionToken
    );
    List<Portal_Users__c> callers = [
      SELECT Id, Contact__c, Portal_User_Profile__c
      FROM Portal_Users__c
      WHERE Id = :verifiedPortalUserId
      LIMIT 1
    ];
    if (callers.isEmpty() || callers[0].Portal_User_Profile__c == null) {
      throw new AuraHandledException('Unauthorized.');
    }

    List<Portal_Object_Permission__c> permissions = [
      SELECT
        Can_View__c,
        Can_View_All__c,
        Can_Create__c,
        Can_Edit__c,
        Can_Delete__c,
        Can_Modify_All__c
      FROM Portal_Object_Permission__c
      WHERE
        Portal_User_Profile__c = :callers[0].Portal_User_Profile__c
        AND Portal_Object__r.Object_API_Name__c = 'Contact'
      LIMIT 1
    ];
    if (permissions.isEmpty()) {
      throw new AuraHandledException('Unauthorized.');
    }

    Portal_Object_Permission__c permission = permissions[0];
    Boolean isOwnContact =
      targetContactId != null &&
      callers[0].Contact__c == targetContactId;
    Boolean allowed = operation == 'create'
      ? permission.Can_Create__c
      : operation == 'edit'
          ? (permission.Can_Modify_All__c ||
            (permission.Can_Edit__c && isOwnContact))
          : operation == 'delete'
              ? (permission.Can_Modify_All__c ||
                (permission.Can_Delete__c && isOwnContact))
              : targetContactId == null
                  ? (permission.Can_View_All__c || permission.Can_Modify_All__c)
                  : (permission.Can_View_All__c ||
                    permission.Can_Modify_All__c ||
                    (permission.Can_View__c && isOwnContact));
    if (!allowed) {
      throw new AuraHandledException('Unauthorized.');
    }

    context.canViewSensitive =
      targetContactId != null && (isOwnContact || permission.Can_Modify_All__c);
    return context;
  }

  private static Boolean isGuestRuntime() {
    String userType = Test.isRunningTest() && testUserTypeOverride != null
      ? testUserTypeOverride
      : UserInfo.getUserType();
    return userType == 'Guest';
  }

  private static Id resolveCurrentUserContactId() {
    Id portalUserId = PWChrono_Utils.getCurrentEmployeeId(UserInfo.getUserId());
    if (portalUserId == null) {
      return null;
    }

    List<Portal_Users__c> portalUsers = [
      SELECT Contact__c
      FROM Portal_Users__c
      WHERE Id = :portalUserId
      LIMIT 1
    ];
    return portalUsers.isEmpty() ? null : portalUsers[0].Contact__c;
  }

  private static Boolean canViewAllSensitiveEmployeeData() {
    if (Test.isRunningTest() && testCanViewAllSensitiveOverride != null) {
      return testCanViewAllSensitiveOverride;
    }
    return FeatureManagement.checkPermission('PWChrono_Send_Payslips');
  }

  private static List<Contact> sanitizeContactsForRead(List<Contact> contacts) {
    if (isGuestRuntime()) {
      return contacts;
    }
    return (List<Contact>) Security.stripInaccessible(
        System.AccessType.READABLE,
        contacts
      )
      .getRecords();
  }

  /**
   * @description Get employees list with optional filters and sorting
   */
  @AuraEnabled
  public static List<EmployeeWrapper> getEmployees(
    String searchTerm,
    String designationFilter,
    String statusFilter,
    String sortBy,
    String callerPortalUserId,
    String sessionToken
  ) {
    try {
      requireDirectoryAccess(callerPortalUserId, sessionToken, 'read', null);
      String query = SELECT_FIELDS;

      List<String> conditions = new List<String>();

      if (String.isNotBlank(searchTerm)) {
        String key = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
        conditions.add(
          '(Name LIKE \'' +
            key +
            '\' OR Email LIKE \'' +
            key +
            '\' OR Title LIKE \'' +
            key +
            '\' OR Department LIKE \'' +
            key +
            '\')'
        );
      }

      if (String.isNotBlank(designationFilter) && designationFilter != 'All') {
        String desig = String.escapeSingleQuotes(designationFilter);
        conditions.add('Title = \'' + desig + '\'');
      }

      if (!conditions.isEmpty()) {
        query += ' WHERE ' + String.join(conditions, ' AND ');
      }

      // Sorting
      if (sortBy == 'Ascending') {
        query += ' ORDER BY Name ASC ';
      } else if (sortBy == 'Descending') {
        query += ' ORDER BY Name DESC ';
      } else if (sortBy == 'Recently Added') {
        query += ' ORDER BY CreatedDate DESC ';
      } else {
        query += ' ORDER BY CreatedDate DESC, Name ASC ';
      }

      query += ' LIMIT 100';

      List<Contact> contacts = sanitizeContactsForRead(Database.query(query));
      List<EmployeeWrapper> results = new List<EmployeeWrapper>();
      Integer index = 1;

      for (Contact c : contacts) {
        EmployeeWrapper w = buildEmployeeWrapper(c, index, false);

        // Filter by status if specified
        if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
          if (w.status != statusFilter) {
            index++;
            continue;
          }
        }

        results.add(w);
        index++;
      }

      return results;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching employees', e);
      throw new EmployeeDirectoryException(
        'Error fetching employees: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Get directory metrics (Total, Active, Inactive, New Joiners)
   */
  @AuraEnabled
  public static Map<String, Object> getEmployeeDirectoryMetrics(
    String callerPortalUserId,
    String sessionToken
  ) {
    try {
      requireDirectoryAccess(callerPortalUserId, sessionToken, 'read', null);
      Map<String, Object> metrics = new Map<String, Object>();

      Integer total = [SELECT COUNT() FROM Contact];
      Date thirtyDaysAgo = Date.today().addDays(-30);
      Integer newJoiners = [
        SELECT COUNT()
        FROM Contact
        WHERE Date_of_Joining__c >= :thirtyDaysAgo
      ];
      Integer active = [
        SELECT COUNT()
        FROM Contact
        WHERE
          Id IN (
            SELECT Contact__c
            FROM Portal_Users__c
            WHERE Contact__c != NULL AND Is_Active__c = TRUE
          )
      ];
      Integer inactive = Math.max(0, total - active);

      metrics.put('total', total);
      metrics.put('active', active);
      metrics.put('inactive', inactive);
      metrics.put('newJoiners', newJoiners);

      return metrics;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching metrics', e);
      throw new EmployeeDirectoryException(
        'Error fetching directory metrics: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Get distinct active designations from Contact records
   */
  @AuraEnabled
  public static List<String> getEmployeeDesignations(
    String callerPortalUserId,
    String sessionToken
  ) {
    try {
      requireDirectoryAccess(callerPortalUserId, sessionToken, 'read', null);
      Set<String> titles = new Set<String>();
      for (AggregateResult ar : [
        SELECT Title
        FROM Contact
        WHERE Title != NULL
        GROUP BY Title
        LIMIT 50
      ]) {
        String t = (String) ar.get('Title');
        if (String.isNotBlank(t)) {
          titles.add(t);
        }
      }
      List<String> result = new List<String>(titles);
      result.sort();
      return result;
    } catch (Exception e) {
      PWChrono_Logger.error('Error fetching employee designations', e);
      return new List<String>();
    }
  }

  /**
   * @description Get a single Contact with full detail
   */
  @AuraEnabled
  public static EmployeeWrapper getEmployeeDetail(
    Id contactId,
    String callerPortalUserId,
    String sessionToken
  ) {
    try {
      if (
        contactId == null ||
        contactId.getSObjectType() != Contact.SObjectType
      ) {
        throw new EmployeeDirectoryException('Employee detail not found.');
      }
      DirectoryAccessContext access = requireDirectoryAccess(
        callerPortalUserId,
        sessionToken,
        'read',
        contactId
      );
      String query = SELECT_FIELDS + ' WHERE Id = :contactId LIMIT 1';
      List<Contact> contacts = sanitizeContactsForRead(Database.query(query));
      if (contacts.isEmpty()) {
        throw new EmployeeDirectoryException('Employee detail not found.');
      }

      return buildEmployeeWrapper(contacts[0], 1, access.canViewSensitive);
    } catch (Exception e) {
      PWChrono_Logger.error('Error getting employee detail', e);
      throw new EmployeeDirectoryException('Employee detail not found.');
    }
  }

  /**
   * @description Save (insert or update) an employee contact
   */
  @AuraEnabled
  public static Contact saveEmployee(
    Contact contactRecord,
    String callerPortalUserId,
    String sessionToken
  ) {
    try {
      if (contactRecord == null) {
        throw new EmployeeDirectoryException(
          'Employee information is required.'
        );
      }
      requireDirectoryAccess(
        callerPortalUserId,
        sessionToken,
        contactRecord.Id == null ? 'create' : 'edit',
        contactRecord.Id
      );
      Contact safeContact = new Contact(
        Id = contactRecord.Id,
        FirstName = contactRecord.FirstName,
        LastName = contactRecord.LastName,
        Email = contactRecord.Email,
        Phone = contactRecord.Phone,
        Title = contactRecord.Title,
        Department = contactRecord.Department
      );
      if (!isGuestRuntime()) {
        System.AccessType accessType = safeContact.Id == null
          ? System.AccessType.CREATABLE
          : System.AccessType.UPDATABLE;
        safeContact = (Contact) Security.stripInaccessible(
            accessType,
            new List<Contact>{ safeContact }
          )
          .getRecords()[0];
      }
      if (String.isBlank(safeContact.LastName)) {
        throw new EmployeeDirectoryException('Last Name is required.');
      }
      if (contactRecord.Id == null) {
        insert safeContact;
      } else {
        update safeContact;
      }
      return safeContact;
    } catch (Exception e) {
      PWChrono_Logger.error('Error saving employee', e);
      throw new EmployeeDirectoryException(
        'Error saving employee: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Delete an employee contact
   */
  @AuraEnabled
  public static void deleteEmployee(
    Id contactId,
    String callerPortalUserId,
    String sessionToken
  ) {
    try {
      if (
        contactId == null ||
        contactId.getSObjectType() != Contact.SObjectType
      ) {
        throw new EmployeeDirectoryException('Employee was not found.');
      }
      requireDirectoryAccess(
        callerPortalUserId,
        sessionToken,
        'delete',
        contactId
      );
      delete [SELECT Id FROM Contact WHERE Id = :contactId LIMIT 1];
    } catch (Exception e) {
      PWChrono_Logger.error('Error deleting employee', e);
      throw new EmployeeDirectoryException(
        'Error deleting employee: ' + e.getMessage()
      );
    }
  }

  /**
   * @description Helper to format an EmployeeWrapper from Contact
   */
  private static EmployeeWrapper buildEmployeeWrapper(
    Contact c,
    Integer idx,
    Boolean canViewSensitive
  ) {
    EmployeeWrapper w = new EmployeeWrapper();
    w.id = c.Id;

    String numStr = String.valueOf(idx);
    while (numStr.length() < 3) {
      numStr = '0' + numStr;
    }
    w.empId = String.isNotBlank(c.Employee_ID__c)
      ? c.Employee_ID__c
      : 'Emp-' + numStr;

    w.firstName = c.FirstName != null ? c.FirstName : '';
    w.lastName = c.LastName != null ? c.LastName : '';
    w.name = c.Name;
    w.title = displayValue(c.Title);
    w.department = displayValue(c.Department);
    w.email = displayValue(c.Email);
    w.phone = String.isNotBlank(c.Phone)
      ? c.Phone
      : displayValue(c.MobilePhone);

    // Formatted Address
    List<String> addrParts = new List<String>();
    if (String.isNotBlank(c.MailingStreet))
      addrParts.add(c.MailingStreet);
    if (String.isNotBlank(c.MailingCity))
      addrParts.add(c.MailingCity);
    if (String.isNotBlank(c.MailingState))
      addrParts.add(c.MailingState);
    if (String.isNotBlank(c.MailingPostalCode))
      addrParts.add(c.MailingPostalCode);
    if (String.isNotBlank(c.MailingCountry))
      addrParts.add(c.MailingCountry);
    w.address = addrParts.isEmpty()
      ? NOT_PROVIDED
      : String.join(addrParts, ', ');

    // Joining Date
    w.joiningDate = c.Date_of_Joining__c != null
      ? formatDate(c.Date_of_Joining__c)
      : (c.CreatedDate != null
          ? c.CreatedDate.format('dd MMM yyyy')
          : NOT_PROVIDED);

    Boolean hasPortalUser =
      c.Portal_Users__r != null && !c.Portal_Users__r.isEmpty();
    Boolean isActive = hasPortalUser && c.Portal_Users__r[0].Is_Active__c;
    w.status = hasPortalUser
      ? (isActive ? 'Active' : 'Inactive')
      : 'Unassigned';
    w.statusClass = isActive
      ? 'badge badge-success d-inline-flex align-items-center badge-xs'
      : 'badge badge-secondary d-inline-flex align-items-center badge-xs';

    // Initials
    String init = '';
    if (String.isNotBlank(c.FirstName)) {
      init += c.FirstName.substring(0, 1).toUpperCase();
    }
    if (String.isNotBlank(c.LastName)) {
      init += c.LastName.substring(0, 1).toUpperCase();
    }
    if (String.isBlank(init) && String.isNotBlank(c.Name)) {
      init = c.Name.substring(0, Math.min(2, c.Name.length())).toUpperCase();
    }
    w.initials = String.isNotBlank(init) ? init : 'EM';

    w.avatarUrl = hasPortalUser ? c.Portal_Users__r[0].Photo_Url__c : null;
    w.managerName = c.ReportsTo != null
      ? displayValue(c.ReportsTo.Name)
      : NOT_PROVIDED;
    w.about = displayValue(c.Description);
    w.accountName = c.Account != null
      ? displayValue(c.Account.Name)
      : NOT_PROVIDED;

    // Project metrics require a separate project relationship and are not inferred.
    w.projects = 0;
    w.done = 0;
    w.progress = 0;
    w.productivity = 0;
    w.productivityClass = 'bg-secondary';

    w.gender = displayValue(c.GenderIdentity);
    w.birthDateFormatted = c.Birthdate != null
      ? formatDate(c.Birthdate)
      : NOT_PROVIDED;
    w.experienceYears = displayValue(c.Experience_Years__c);
    w.canViewSensitive = canViewSensitive;
    w.assetInfo = buildAssetInfo(c);

    if (canViewSensitive) {
      w.personalInfo = buildPersonalInfo(c);
      w.bankInfo = buildBankInfo(c);
      w.emergencyContact = buildEmergencyContact(c);
      w.familyInfo = buildFamilyInfo(c);
    }

    return w;
  }

  private static PersonalInfoWrapper buildPersonalInfo(Contact c) {
    PersonalInfoWrapper info = new PersonalInfoWrapper();
    info.passportNo = maskValue(c.Passport_No__c);
    info.passportExpDate = c.Passport_Exp_Date__c == null
      ? NOT_PROVIDED
      : formatDate(c.Passport_Exp_Date__c);
    info.nationality = displayValue(c.Nationality__c);
    info.religion = displayValue(c.Religion__c);
    info.maritalStatus = displayValue(c.Marital_Status__c);
    info.spouseEmployment = displayValue(c.Employment_of_Spouse__c);
    info.noOfChildren = c.No_of_Children__c == null
      ? NOT_PROVIDED
      : String.valueOf(c.No_of_Children__c.setScale(0));
    return info;
  }

  private static BankInfoWrapper buildBankInfo(Contact c) {
    BankInfoWrapper info = new BankInfoWrapper();
    info.bankName = displayValue(c.Bank_Name__c);
    info.maskedAccountNumber = maskValue(c.Account_Number__c);
    info.swiftCode = displayValue(c.SWIFT_Code__c);
    info.branch = displayValue(c.Branch_Name_Code__c);
    info.hasBankInformation =
      String.isNotBlank(c.Bank_Name__c) ||
      String.isNotBlank(c.Account_Number__c) ||
      String.isNotBlank(c.SWIFT_Code__c) ||
      String.isNotBlank(c.Branch_Name_Code__c);
    return info;
  }

  private static EmergencyContactWrapper buildEmergencyContact(Contact c) {
    EmergencyContactWrapper info = new EmergencyContactWrapper();
    info.primaryName = displayValue(c.Emergency_Contact_Name__c);
    info.primaryRelationship = displayValue(
      c.Emergency_Contact_Relationship__c
    );
    info.primaryPhone = displayValue(c.Emergency_Contact_Number__c);
    info.secondaryName = displayValue(c.Secondary_Emergency_Contact_Name__c);
    info.secondaryRelationship = displayValue(
      c.Secondary_Emergency_Contact_Relationship__c
    );
    info.secondaryPhone = displayValue(c.Secondary_Emergency_Contact_Number__c);
    return info;
  }

  private static FamilyInfoWrapper buildFamilyInfo(Contact c) {
    FamilyInfoWrapper info = new FamilyInfoWrapper();
    info.name = displayValue(c.Family_Member_Name__c);
    info.relationship = displayValue(c.Family_Member_Relationship__c);
    info.dateOfBirth = c.Family_Member_DOB__c == null
      ? NOT_PROVIDED
      : formatDate(c.Family_Member_DOB__c);
    info.phone = displayValue(c.Family_Member_Phone__c);
    return info;
  }

  private static AssetInfoWrapper buildAssetInfo(Contact c) {
    AssetInfoWrapper info = new AssetInfoWrapper();
    info.brand = displayValue(c.Laptop_Brand__c);
    info.model = displayValue(c.Model__c);
    info.processorType = displayValue(c.Processor_Type__c);
    info.processorSpeed = c.Processor_Speed_GHz__c == null
      ? NOT_PROVIDED
      : String.valueOf(c.Processor_Speed_GHz__c) + ' GHz';
    info.ram = displayValue(c.RAM_GB__c);
    info.storage = displayValue(c.Storage__c);
    info.screenSize = displayValue(c.Screen_Size_inches__c);
    info.hasAssetInformation =
      String.isNotBlank(c.Laptop_Brand__c) ||
      String.isNotBlank(c.Model__c) ||
      String.isNotBlank(c.Processor_Type__c) ||
      c.Processor_Speed_GHz__c != null ||
      String.isNotBlank(c.RAM_GB__c) ||
      String.isNotBlank(c.Storage__c) ||
      String.isNotBlank(c.Screen_Size_inches__c);

    List<String> parts = new List<String>();
    if (String.isNotBlank(c.Laptop_Brand__c)) {
      parts.add(c.Laptop_Brand__c);
    }
    if (String.isNotBlank(c.Model__c)) {
      parts.add(c.Model__c);
    }
    if (String.isNotBlank(c.RAM_GB__c)) {
      parts.add(c.RAM_GB__c);
    }
    info.displayText = parts.isEmpty()
      ? NOT_PROVIDED
      : String.join(parts, ' - ');
    return info;
  }

  private static String displayValue(String value) {
    return String.isBlank(value) ? NOT_PROVIDED : value.trim();
  }

  private static String maskValue(String value) {
    if (String.isBlank(value)) {
      return NOT_PROVIDED;
    }
    String normalized = value.trim();
    Integer visibleLength = Math.min(4, normalized.length());
    return '**** ' + normalized.right(visibleLength);
  }

  private static String formatDate(Date value) {
    return DateTime.newInstance(value, Time.newInstance(0, 0, 0, 0))
      .format('dd MMM yyyy');
  }

  /**
   * Backwards compatible search method for legacy calls
   */
  @AuraEnabled(cacheable=true)
  public static List<Contact> searchEmployees(
    String searchTerm,
    String callerPortalUserId,
    String sessionToken
  ) {
    try {
      requireDirectoryAccess(callerPortalUserId, sessionToken, 'read', null);
      String query = 'SELECT Id, Name, Email, Department, Title, Phone FROM Contact';
      if (String.isNotBlank(searchTerm)) {
        String key = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
        query += ' WHERE Name LIKE :key OR Email LIKE :key OR Department LIKE :key';
      }
      query += ' ORDER BY Name ASC LIMIT 50';
      return sanitizeContactsForRead((List<Contact>) Database.query(query));
    } catch (Exception e) {
      return new List<Contact>();
    }
  }

  @AuraEnabled
  public static Boolean checkRecordAccess(
    Id recordId,
    String callerPortalUserId,
    String sessionToken
  ) {
    try {
      if (
        recordId == null ||
        recordId.getSObjectType() != Contact.SObjectType
      ) {
        return false;
      }
      requireDirectoryAccess(
        callerPortalUserId,
        sessionToken,
        'read',
        recordId
      );
      List<Contact> records = [
        SELECT Id
        FROM Contact
        WHERE Id = :recordId
        LIMIT 1
      ];
      return !records.isEmpty();
    } catch (Exception e) {
      return false;
    }
  }
}