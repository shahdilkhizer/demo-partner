@isTest
private class PWChrono_NoticePeriodController_Test {
  private static final String ADMIN_EMAIL = 'notice.admin@test.com';
  private static final String HR_EMAIL = 'notice.hr@test.com';
  private static final String PLAIN_EMAIL = 'notice.plain@test.com';
  private static final String LEAVER_EMAIL = 'notice.leaver@test.com';
  private static final String OTHER_EMAIL = 'notice.other@test.com';
  private static final String INACTIVE_EMAIL = 'notice.inactive@test.com';
  private static final String ADMIN_TOKEN = 'notice-admin-token';

  @testSetup
  static void setup() {
    Portal_User_Profile__c hrProfile = new Portal_User_Profile__c(
      Profile_Type__c = 'HR Manager',
      Is_Active__c = true
    );
    insert hrProfile;
    insert new Portal_Profile_Feature__c(
      Portal_User_Profile__c = hrProfile.Id,
      Feature_Key__c = PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      Feature_Label__c = PWChrono_AccessController.FEATURE_EMPLOYEE_LIFECYCLE,
      Is_Enabled__c = true
    );

    Contact leaverContact = new Contact(
      LastName = 'Leaver',
      Department = 'Contact Department',
      Title = 'Contact Title'
    );
    insert leaverContact;

    insert new List<Portal_Users__c>{
      new Portal_Users__c(
        Name = 'Notice Admin',
        Email__c = ADMIN_EMAIL,
        Role__c = 'HR Admin',
        Is_Active__c = true,
        Session_Token__c = ADMIN_TOKEN,
        Session_Expires_At__c = System.now().addHours(2)
      ),
      new Portal_Users__c(
        Name = 'Notice HR Manager',
        Email__c = HR_EMAIL,
        Role__c = 'HR Manager',
        Is_Active__c = true,
        Portal_User_Profile__c = hrProfile.Id
      ),
      new Portal_Users__c(
        Name = 'Notice Plain Employee',
        Email__c = PLAIN_EMAIL,
        Role__c = 'Employee',
        Is_Active__c = true
      ),
      new Portal_Users__c(
        Name = 'Lena Leaver',
        Email__c = LEAVER_EMAIL,
        Role__c = 'Employee',
        Is_Active__c = true,
        Department__c = 'Finance',
        Designation__c = 'Accountant',
        Photo_Url__c = 'https://example.com/lena.png',
        Contact__c = leaverContact.Id
      ),
      new Portal_Users__c(
        Name = 'Oscar Other',
        Email__c = OTHER_EMAIL,
        Role__c = 'Employee',
        Is_Active__c = true,
        Contact__c = null,
        Google_Picture_URL__c = 'https://example.com/oscar.png'
      ),
      new Portal_Users__c(
        Name = 'Ivy Inactive',
        Email__c = INACTIVE_EMAIL,
        Role__c = 'Employee',
        Is_Active__c = false
      )
    };

    insert new PWChrono_Department__c(Name = 'Finance', Is_Active__c = true);
    insert new PWChrono_Designation__c(
      Name = 'Accountant',
      Is_Active__c = true
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────

  private static Id userId(String email) {
    return [SELECT Id FROM Portal_Users__c WHERE Email__c = :email LIMIT 1].Id;
  }

  private static PWChrono_Employee_Separation__c separation(
    Id employeeId,
    String status,
    Date startDate,
    Date endDate
  ) {
    return new PWChrono_Employee_Separation__c(
      Employee__c = employeeId,
      Employee_Name__c = 'Stored Name',
      Status__c = status,
      Resignation_Letter_Date__c = startDate,
      Relieving_Date__c = endDate,
      Reason_for_Leaving__c = 'Personal'
    );
  }

  private static PWChrono_Employee_Separation__c reload(Id separationId) {
    return [
      SELECT
        Id,
        Name,
        Employee__c,
        Employee_Name__c,
        Status__c,
        Resignation_Letter_Date__c,
        Relieving_Date__c,
        Reason_for_Leaving__c,
        Department__c,
        Designation__c
      FROM PWChrono_Employee_Separation__c
      WHERE Id = :separationId
    ];
  }

  private static String saveError(
    Id noticeId,
    Id employeeId,
    Date startDate,
    Date endDate,
    String reason
  ) {
    try {
      PWChrono_NoticePeriodController.saveNotice(
        noticeId,
        employeeId,
        startDate,
        endDate,
        reason,
        userId(HR_EMAIL),
        null
      );
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    Assert.fail('saveNotice should have been rejected.');
    return null;
  }

  private static String withdrawError(List<Id> ids, Id actorId) {
    try {
      PWChrono_NoticePeriodController.withdrawNotices(ids, actorId, null);
    } catch (AuraHandledException e) {
      return e.getMessage();
    }
    Assert.fail('withdrawNotices should have been rejected.');
    return null;
  }

  private static PWChrono_NoticePeriodController.NoticeRecord calculate(
    Date startDate,
    Date endDate,
    String separationStatus
  ) {
    PWChrono_NoticePeriodController.NoticeRecord notice = new PWChrono_NoticePeriodController.NoticeRecord();
    notice.startDate = startDate;
    notice.endDate = endDate;
    notice.separationStatus = separationStatus;
    PWChrono_NoticePeriodController.applyDayCounts(notice, Date.today());
    return notice;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Create
  // ─────────────────────────────────────────────────────────────────────

  @isTest
  static void createNoticeStartsPendingSeparationWithLookups() {
    Id leaverId = userId(LEAVER_EMAIL);
    Date startDate = Date.today();

    Test.startTest();
    Id noticeId = PWChrono_NoticePeriodController.saveNotice(
      null,
      leaverId,
      startDate,
      startDate.addDays(30),
      '  Relocating abroad  ',
      userId(HR_EMAIL),
      null
    );
    Test.stopTest();

    PWChrono_Employee_Separation__c saved = reload(noticeId);
    Assert.areEqual('Pending', saved.Status__c);
    Assert.areEqual(leaverId, saved.Employee__c);
    Assert.areEqual('Lena Leaver', saved.Employee_Name__c);
    Assert.areEqual(startDate, saved.Resignation_Letter_Date__c);
    Assert.areEqual(startDate.addDays(30), saved.Relieving_Date__c);
    Assert.areEqual('Relocating abroad', saved.Reason_for_Leaving__c);
    Assert.areEqual(
      [SELECT Id FROM PWChrono_Department__c WHERE Name = 'Finance'].Id,
      saved.Department__c
    );
    Assert.areEqual(
      [SELECT Id FROM PWChrono_Designation__c WHERE Name = 'Accountant'].Id,
      saved.Designation__c
    );
  }

  @isTest
  static void createNoticeSkipsLookupsWithoutActiveMatch() {
    update new PWChrono_Department__c(
      Id = [SELECT Id FROM PWChrono_Department__c LIMIT 1]
      .Id,
      Is_Active__c = false
    );

    Id noticeId = PWChrono_NoticePeriodController.saveNotice(
      null,
      userId(LEAVER_EMAIL),
      Date.today(),
      Date.today(),
      null,
      userId(HR_EMAIL),
      null
    );

    PWChrono_Employee_Separation__c saved = reload(noticeId);
    Assert.isNull(saved.Department__c, 'Inactive departments are not linked.');
    Assert.isNotNull(saved.Designation__c);
    Assert.isNull(saved.Reason_for_Leaving__c);
  }

  @isTest
  static void createNoticeRejectsDuplicateOpenSeparation() {
    Id leaverId = userId(LEAVER_EMAIL);
    PWChrono_Employee_Separation__c open = separation(
      leaverId,
      'In Process',
      Date.today().addDays(-5),
      Date.today().addDays(25)
    );
    insert open;
    String openName = reload(open.Id).Name;

    String message = saveError(
      null,
      leaverId,
      Date.today(),
      Date.today().addDays(30),
      'Second notice'
    );

    Assert.isTrue(message.contains('already has an open separation'), message);
    Assert.isTrue(message.contains(openName), message);
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM PWChrono_Employee_Separation__c
        WHERE Employee__c = :leaverId
      ]
    );
  }

  @isTest
  static void createNoticeAllowedAfterClosedSeparations() {
    Id leaverId = userId(LEAVER_EMAIL);
    insert new List<PWChrono_Employee_Separation__c>{
      separation(
        leaverId,
        'Completed',
        Date.today().addDays(-90),
        Date.today().addDays(-60)
      ),
      separation(
        leaverId,
        'Cancelled',
        Date.today().addDays(-30),
        Date.today().addDays(-1)
      )
    };

    Id noticeId = PWChrono_NoticePeriodController.saveNotice(
      null,
      leaverId,
      Date.today(),
      Date.today().addDays(14),
      'Rejoined and resigned again',
      userId(HR_EMAIL),
      null
    );

    Assert.areEqual('Pending', reload(noticeId).Status__c);
  }

  @isTest
  static void createNoticeValidatesInput() {
    Id leaverId = userId(LEAVER_EMAIL);
    Date today = Date.today();

    Assert.isTrue(
      saveError(null, null, today, today.addDays(1), null)
        .contains('Select the employee'),
      'Employee is required.'
    );
    Assert.isTrue(
      saveError(null, leaverId, null, today.addDays(1), null)
        .contains('Enter both'),
      'Start date is required.'
    );
    Assert.isTrue(
      saveError(null, leaverId, today, null, null).contains('Enter both'),
      'Last working day is required.'
    );
    Assert.isTrue(
      saveError(null, leaverId, today, today.addDays(-1), null)
        .contains('cannot be before'),
      'Last working day cannot precede the start.'
    );
    Assert.isTrue(
      saveError(null, leaverId, today, today, 'x'.repeat(256))
        .contains('255 characters'),
      'Reason length is limited.'
    );
    Assert.isTrue(
      saveError(null, userId(INACTIVE_EMAIL), today, today, null)
        .contains('inactive'),
      'Inactive employees are rejected.'
    );
    Id notAnEmployee = [SELECT Id FROM PWChrono_Department__c LIMIT 1].Id;
    Assert.isTrue(
      saveError(null, notAnEmployee, today, today, null).contains('not found'),
      'Unknown employees are rejected.'
    );
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Employee_Separation__c]);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Edit
  // ─────────────────────────────────────────────────────────────────────

  @isTest
  static void editNoticeUpdatesDatesAndReasonOnly() {
    Id leaverId = userId(LEAVER_EMAIL);
    PWChrono_Employee_Separation__c existing = separation(
      leaverId,
      'In Process',
      Date.today().addDays(-10),
      Date.today().addDays(20)
    );
    insert existing;

    Test.startTest();
    Id savedId = PWChrono_NoticePeriodController.saveNotice(
      existing.Id,
      leaverId,
      Date.today().addDays(-8),
      Date.today().addDays(40),
      'Extended handover',
      userId(HR_EMAIL),
      null
    );
    Test.stopTest();

    PWChrono_Employee_Separation__c saved = reload(savedId);
    Assert.areEqual(existing.Id, savedId);
    Assert.areEqual('In Process', saved.Status__c, 'Status is untouched.');
    Assert.areEqual(leaverId, saved.Employee__c);
    Assert.areEqual('Stored Name', saved.Employee_Name__c);
    Assert.areEqual(Date.today().addDays(-8), saved.Resignation_Letter_Date__c);
    Assert.areEqual(Date.today().addDays(40), saved.Relieving_Date__c);
    Assert.areEqual('Extended handover', saved.Reason_for_Leaving__c);
  }

  @isTest
  static void editNoticeRejectsClosedSeparationsAndEmployeeChange() {
    Id leaverId = userId(LEAVER_EMAIL);
    PWChrono_Employee_Separation__c completed = separation(
      leaverId,
      'Completed',
      Date.today().addDays(-60),
      Date.today().addDays(-30)
    );
    PWChrono_Employee_Separation__c cancelled = separation(
      leaverId,
      'Cancelled',
      Date.today().addDays(-20),
      Date.today().addDays(10)
    );
    PWChrono_Employee_Separation__c pending = separation(
      leaverId,
      'Pending',
      Date.today(),
      Date.today().addDays(30)
    );
    insert new List<PWChrono_Employee_Separation__c>{
      completed,
      cancelled,
      pending
    };
    Date today = Date.today();

    Assert.isTrue(
      saveError(completed.Id, leaverId, today, today, null)
        .contains('completed and can no longer be edited')
    );
    Assert.isTrue(
      saveError(cancelled.Id, null, today, today, null)
        .contains('cancelled and can no longer be edited')
    );
    Assert.isTrue(
      saveError(pending.Id, userId(OTHER_EMAIL), today, today, null)
        .contains('cannot be changed')
    );

    delete pending;
    Assert.isTrue(
      saveError(pending.Id, null, today, today, null).contains('not found')
    );
    Assert.areEqual(
      Date.today().addDays(-30),
      reload(completed.Id).Relieving_Date__c,
      'Completed separations keep their dates.'
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Read
  // ─────────────────────────────────────────────────────────────────────

  @isTest
  static void getNoticeRecordsCalculatesDaysStatusesAndOrder() {
    Id leaverId = userId(LEAVER_EMAIL);
    Id otherId = userId(OTHER_EMAIL);
    Date today = Date.today();

    PWChrono_Employee_Separation__c active = separation(
      leaverId,
      'Pending',
      today.addDays(-10),
      today.addDays(20)
    );
    active.Designation__c = [SELECT Id FROM PWChrono_Designation__c LIMIT 1].Id;
    PWChrono_Employee_Separation__c closing = separation(
      otherId,
      'In Process',
      today.addDays(-25),
      today.addDays(5)
    );
    PWChrono_Employee_Separation__c pastEnd = separation(
      leaverId,
      'In Process',
      today.addDays(-40),
      today.addDays(-2)
    );
    PWChrono_Employee_Separation__c completed = separation(
      otherId,
      'Completed',
      today.addDays(-5),
      today.addDays(50)
    );
    PWChrono_Employee_Separation__c startOnly = separation(
      null,
      'Pending',
      today.addDays(-3),
      null
    );
    PWChrono_Employee_Separation__c cancelled = separation(
      leaverId,
      'Cancelled',
      today.addDays(-1),
      today.addDays(1)
    );
    PWChrono_Employee_Separation__c noDates = separation(
      otherId,
      'Pending',
      null,
      null
    );
    insert new List<PWChrono_Employee_Separation__c>{
      active,
      closing,
      pastEnd,
      completed,
      startOnly,
      cancelled,
      noDates
    };

    Test.startTest();
    List<PWChrono_NoticePeriodController.NoticeRecord> notices = PWChrono_NoticePeriodController.getNoticeRecords(
      userId(HR_EMAIL),
      null
    );
    Test.stopTest();

    Assert.areEqual(5, notices.size(), 'Cancelled and undated are excluded.');
    // Current notices first, soonest last working day first, missing end
    // dates last; then finished notices, most recent last working day first.
    Assert.areEqual(closing.Id, notices[0].id, 'Current notices lead.');
    Assert.areEqual(active.Id, notices[1].id);
    Assert.areEqual(startOnly.Id, notices[2].id, 'Missing end dates last.');
    Assert.areEqual(completed.Id, notices[3].id, 'Finished notices follow.');
    Assert.areEqual(pastEnd.Id, notices[4].id);

    PWChrono_NoticePeriodController.NoticeRecord pastEndNotice = notices[4];
    Assert.areEqual(38, pastEndNotice.totalDays);
    Assert.areEqual(38, pastEndNotice.completedDays);
    Assert.areEqual(0, pastEndNotice.remainingDays);
    Assert.areEqual(100, pastEndNotice.progressPercent);
    Assert.areEqual('Completed', pastEndNotice.noticeStatus);
    Assert.areEqual('In Process', pastEndNotice.separationStatus);
    Assert.isTrue(pastEndNotice.isOpen);

    PWChrono_NoticePeriodController.NoticeRecord closingNotice = notices[0];
    Assert.areEqual(30, closingNotice.totalDays);
    Assert.areEqual(25, closingNotice.completedDays);
    Assert.areEqual(5, closingNotice.remainingDays);
    Assert.areEqual(83, closingNotice.progressPercent);
    Assert.areEqual('Closing Soon', closingNotice.noticeStatus);
    Assert.areEqual('Oscar Other', closingNotice.employeeName);
    Assert.areEqual('https://example.com/oscar.png', closingNotice.photoUrl);
    Assert.isNull(closingNotice.designation);

    PWChrono_NoticePeriodController.NoticeRecord activeNotice = notices[1];
    Assert.areEqual(30, activeNotice.totalDays);
    Assert.areEqual(10, activeNotice.completedDays);
    Assert.areEqual(20, activeNotice.remainingDays);
    Assert.areEqual(33, activeNotice.progressPercent);
    Assert.areEqual('Active', activeNotice.noticeStatus);
    Assert.areEqual('Lena Leaver', activeNotice.employeeName);
    Assert.areEqual(leaverId, activeNotice.employeeId);
    Assert.areEqual('Accountant', activeNotice.designation);
    Assert.areEqual('Finance', activeNotice.department);
    Assert.areEqual('https://example.com/lena.png', activeNotice.photoUrl);
    Assert.areEqual('Personal', activeNotice.reason);
    Assert.isTrue(activeNotice.recordNumber.startsWith('SEP-'));
    Assert.areEqual(today.addDays(-10), activeNotice.startDate);
    Assert.areEqual(today.addDays(20), activeNotice.endDate);

    PWChrono_NoticePeriodController.NoticeRecord completedNotice = notices[3];
    Assert.areEqual('Completed', completedNotice.noticeStatus);
    Assert.areEqual(100, completedNotice.progressPercent);
    Assert.isFalse(completedNotice.isOpen);

    PWChrono_NoticePeriodController.NoticeRecord startOnlyNotice = notices[2];
    Assert.isNull(startOnlyNotice.totalDays);
    Assert.areEqual(3, startOnlyNotice.completedDays);
    Assert.isNull(startOnlyNotice.remainingDays);
    Assert.areEqual(0, startOnlyNotice.progressPercent);
    Assert.areEqual('Active', startOnlyNotice.noticeStatus);
    Assert.areEqual('Stored Name', startOnlyNotice.employeeName);
    Assert.isNull(startOnlyNotice.photoUrl);
  }

  @isTest
  static void finishedHistoryNeverPushesCurrentNoticesBack() {
    Id leaverId = userId(LEAVER_EMAIL);
    Id otherId = userId(OTHER_EMAIL);
    Date today = Date.today();

    // Older history is inserted first and has earlier last working days, so
    // a plain "last working day ascending" order would list it first.
    PWChrono_Employee_Separation__c oldest = separation(
      otherId,
      'Completed',
      today.addDays(-400),
      today.addDays(-370)
    );
    PWChrono_Employee_Separation__c older = separation(
      otherId,
      'Completed',
      today.addDays(-200),
      today.addDays(-170)
    );
    PWChrono_Employee_Separation__c recent = separation(
      leaverId,
      'Completed',
      today.addDays(-40),
      today.addDays(-10)
    );
    PWChrono_Employee_Separation__c completedStartOnly = separation(
      leaverId,
      'Completed',
      today.addDays(-5),
      null
    );
    PWChrono_Employee_Separation__c overdueOpen = separation(
      otherId,
      'Pending',
      today.addDays(-35),
      today.addDays(-5)
    );
    PWChrono_Employee_Separation__c later = separation(
      leaverId,
      'Pending',
      today.addDays(-1),
      today.addDays(45)
    );
    PWChrono_Employee_Separation__c sooner = separation(
      otherId,
      'In Process',
      today.addDays(-20),
      today.addDays(10)
    );
    insert new List<PWChrono_Employee_Separation__c>{
      oldest,
      older,
      recent,
      completedStartOnly,
      overdueOpen,
      later,
      sooner
    };

    List<PWChrono_NoticePeriodController.NoticeRecord> notices = PWChrono_NoticePeriodController.getNoticeRecords(
      userId(ADMIN_EMAIL),
      null
    );

    List<Id> order = new List<Id>();
    for (PWChrono_NoticePeriodController.NoticeRecord notice : notices) {
      order.add(notice.id);
    }
    Assert.areEqual(
      new List<Id>{
        sooner.Id,
        later.Id,
        overdueOpen.Id,
        recent.Id,
        older.Id,
        oldest.Id,
        completedStartOnly.Id
      },
      order,
      'Current notices first; finished ones most recent first, undated last.'
    );
    Assert.areEqual('Active', notices[0].noticeStatus);
    Assert.areEqual('Completed', notices[2].noticeStatus);
    Assert.isTrue(notices[2].isOpen, 'An overdue open separation stays open.');
    Assert.isFalse(notices[3].isOpen);
  }

  @isTest
  static void blankStatusIsTreatedAsPending() {
    Id leaverId = userId(LEAVER_EMAIL);
    PWChrono_Employee_Separation__c legacy = separation(
      leaverId,
      'Pending',
      Date.today().addDays(-3),
      Date.today().addDays(27)
    );
    insert legacy;
    update new PWChrono_Employee_Separation__c(
      Id = legacy.Id,
      Status__c = null
    );
    Assert.isNull(reload(legacy.Id).Status__c, 'Precondition: blank status.');
    Id hrId = userId(HR_EMAIL);

    List<PWChrono_NoticePeriodController.NoticeRecord> notices = PWChrono_NoticePeriodController.getNoticeRecords(
      hrId,
      null
    );
    Assert.areEqual(1, notices.size());
    Assert.areEqual('Pending', notices[0].separationStatus);
    Assert.isTrue(notices[0].isOpen, 'Blank status is open.');

    Boolean offered = false;
    for (
      PWChrono_NoticePeriodController.EmployeeOption option : PWChrono_NoticePeriodController.getNoticeOptions(
        hrId,
        null
      )
    ) {
      offered = offered || option.id == leaverId;
    }
    Assert.isFalse(offered, 'A blank-status separation counts as open.');
    Assert.isTrue(
      saveError(null, leaverId, Date.today(), Date.today().addDays(30), null)
        .contains('already has an open separation'),
      'A second open separation is rejected.'
    );

    PWChrono_NoticePeriodController.saveNotice(
      legacy.Id,
      leaverId,
      Date.today().addDays(-3),
      Date.today().addDays(40),
      'Extended',
      hrId,
      null
    );
    Assert.areEqual(
      Date.today().addDays(40),
      reload(legacy.Id).Relieving_Date__c,
      'Blank-status separations can be edited.'
    );

    Test.startTest();
    Integer withdrawn = PWChrono_NoticePeriodController.withdrawNotices(
      new List<Id>{ legacy.Id },
      userId(ADMIN_EMAIL),
      null
    );
    Test.stopTest();
    Assert.areEqual(1, withdrawn, 'Blank-status separations can be withdrawn.');
    Assert.areEqual('Cancelled', reload(legacy.Id).Status__c);
  }

  @isTest
  static void finishedOrderComparesEndThenStartThenNumber() {
    Date today = Date.today();
    PWChrono_NoticePeriodController.NoticeRecord endsLater = finishedNotice(
      'SEP-0005',
      today.addDays(-40),
      today.addDays(-5)
    );
    PWChrono_NoticePeriodController.NoticeRecord startsLater = finishedNotice(
      'SEP-0004',
      today.addDays(-30),
      today.addDays(-10)
    );
    PWChrono_NoticePeriodController.NoticeRecord startsEarlier = finishedNotice(
      'SEP-0001',
      today.addDays(-60),
      today.addDays(-10)
    );
    PWChrono_NoticePeriodController.NoticeRecord twin = finishedNotice(
      'SEP-0002',
      today.addDays(-60),
      today.addDays(-10)
    );
    PWChrono_NoticePeriodController.NoticeRecord undatedEnd = finishedNotice(
      null,
      today.addDays(-3),
      null
    );
    PWChrono_NoticePeriodController.MostRecentFirst order = new PWChrono_NoticePeriodController.MostRecentFirst();

    Assert.areEqual(
      -1,
      order.compare(endsLater, startsLater),
      'Later end first.'
    );
    Assert.areEqual(1, order.compare(startsLater, endsLater));
    Assert.areEqual(
      -1,
      order.compare(startsLater, startsEarlier),
      'Same end: later start first.'
    );
    Assert.isTrue(
      order.compare(startsEarlier, twin) < 0,
      'Same dates: record number ascending.'
    );
    Assert.areEqual(0, order.compare(twin, twin));
    Assert.areEqual(1, order.compare(undatedEnd, endsLater), 'Undated last.');
    Assert.areEqual(-1, order.compare(endsLater, undatedEnd));

    List<PWChrono_NoticePeriodController.NoticeRecord> notices = new List<PWChrono_NoticePeriodController.NoticeRecord>{
      undatedEnd,
      twin,
      startsEarlier,
      endsLater,
      startsLater
    };
    notices.sort(order);
    Assert.areEqual(endsLater, notices[0]);
    Assert.areEqual(startsLater, notices[1]);
    Assert.areEqual(startsEarlier, notices[2]);
    Assert.areEqual(twin, notices[3]);
    Assert.areEqual(undatedEnd, notices[4]);
  }

  private static PWChrono_NoticePeriodController.NoticeRecord finishedNotice(
    String recordNumber,
    Date startDate,
    Date endDate
  ) {
    PWChrono_NoticePeriodController.NoticeRecord notice = new PWChrono_NoticePeriodController.NoticeRecord();
    notice.recordNumber = recordNumber;
    notice.startDate = startDate;
    notice.endDate = endDate;
    return notice;
  }

  @isTest
  static void dayCalculationsHandleEdgeCases() {
    Date today = Date.today();

    PWChrono_NoticePeriodController.NoticeRecord future = calculate(
      today.addDays(5),
      today.addDays(35),
      'Pending'
    );
    Assert.areEqual(30, future.totalDays);
    Assert.areEqual(0, future.completedDays, 'Future notices clamp to 0.');
    Assert.areEqual(35, future.remainingDays);
    Assert.areEqual(0, future.progressPercent);
    Assert.areEqual('Active', future.noticeStatus);

    PWChrono_NoticePeriodController.NoticeRecord sameDay = calculate(
      today,
      today,
      'Pending'
    );
    Assert.areEqual(0, sameDay.totalDays);
    Assert.areEqual(0, sameDay.completedDays);
    Assert.areEqual(0, sameDay.remainingDays);
    Assert.areEqual(100, sameDay.progressPercent);
    Assert.areEqual('Closing Soon', sameDay.noticeStatus);

    PWChrono_NoticePeriodController.NoticeRecord futureSameDay = calculate(
      today.addDays(3),
      today.addDays(3),
      'Pending'
    );
    Assert.areEqual(0, futureSameDay.progressPercent);
    Assert.areEqual('Closing Soon', futureSameDay.noticeStatus);

    PWChrono_NoticePeriodController.NoticeRecord endOnly = calculate(
      null,
      today.addDays(7),
      'In Process'
    );
    Assert.isNull(endOnly.totalDays);
    Assert.isNull(endOnly.completedDays);
    Assert.areEqual(7, endOnly.remainingDays);
    Assert.areEqual(0, endOnly.progressPercent);
    Assert.areEqual('Closing Soon', endOnly.noticeStatus, '7 days is soon.');

    PWChrono_NoticePeriodController.NoticeRecord eightDays = calculate(
      today.addDays(-2),
      today.addDays(8),
      'Pending'
    );
    Assert.areEqual('Active', eightDays.noticeStatus, '8 days is not soon.');
    Assert.areEqual(20, eightDays.progressPercent);

    PWChrono_NoticePeriodController.NoticeRecord reversed = calculate(
      today,
      today.addDays(-4),
      'Pending'
    );
    Assert.areEqual(0, reversed.totalDays, 'Total days never go negative.');
    Assert.areEqual('Completed', reversed.noticeStatus);
  }

  @isTest
  static void getNoticeOptionsListsActiveEmployeesWithoutOpenSeparation() {
    Id leaverId = userId(LEAVER_EMAIL);
    Id otherId = userId(OTHER_EMAIL);
    insert new List<PWChrono_Employee_Separation__c>{
      separation(leaverId, 'Pending', Date.today(), Date.today().addDays(30)),
      separation(
        otherId,
        'Completed',
        Date.today().addDays(-60),
        Date.today().addDays(-30)
      )
    };

    List<PWChrono_NoticePeriodController.EmployeeOption> options = PWChrono_NoticePeriodController.getNoticeOptions(
      userId(HR_EMAIL),
      null
    );

    Map<Id, PWChrono_NoticePeriodController.EmployeeOption> byId = new Map<Id, PWChrono_NoticePeriodController.EmployeeOption>();
    List<String> names = new List<String>();
    for (PWChrono_NoticePeriodController.EmployeeOption option : options) {
      byId.put(option.id, option);
      names.add(option.name);
    }
    Assert.isFalse(byId.containsKey(leaverId), 'Open separation excluded.');
    Assert.isFalse(byId.containsKey(userId(INACTIVE_EMAIL)));
    Assert.isTrue(byId.containsKey(otherId), 'Completed separation allowed.');
    Assert.isTrue(byId.containsKey(userId(ADMIN_EMAIL)));
    List<String> sorted = new List<String>(names);
    sorted.sort();
    Assert.areEqual(sorted, names, 'Options are sorted by name.');
  }

  @isTest
  static void getNoticeOptionsFallsBackToContactDetails() {
    Id leaverId = userId(LEAVER_EMAIL);
    update new Portal_Users__c(
      Id = leaverId,
      Department__c = null,
      Designation__c = null
    );

    PWChrono_NoticePeriodController.EmployeeOption leaver;
    for (
      PWChrono_NoticePeriodController.EmployeeOption option : PWChrono_NoticePeriodController.getNoticeOptions(
        userId(ADMIN_EMAIL),
        null
      )
    ) {
      if (option.id == leaverId) {
        leaver = option;
      }
    }
    Assert.isNotNull(leaver);
    Assert.areEqual('Contact Title', leaver.designation);
    Assert.areEqual('Contact Department', leaver.department);
  }

  // ─────────────────────────────────────────────────────────────────────
  // Withdraw
  // ─────────────────────────────────────────────────────────────────────

  @isTest
  static void adminWithdrawsOpenNotices() {
    Id leaverId = userId(LEAVER_EMAIL);
    Id otherId = userId(OTHER_EMAIL);
    PWChrono_Employee_Separation__c pending = separation(
      leaverId,
      'Pending',
      Date.today(),
      Date.today().addDays(30)
    );
    PWChrono_Employee_Separation__c inProcess = separation(
      otherId,
      'In Process',
      Date.today(),
      Date.today().addDays(30)
    );
    PWChrono_Employee_Separation__c alreadyCancelled = separation(
      otherId,
      'Cancelled',
      Date.today(),
      Date.today().addDays(30)
    );
    insert new List<PWChrono_Employee_Separation__c>{
      pending,
      inProcess,
      alreadyCancelled
    };

    Test.startTest();
    Integer withdrawn = PWChrono_NoticePeriodController.withdrawNotices(
      new List<Id>{ pending.Id, inProcess.Id, alreadyCancelled.Id, null },
      userId(ADMIN_EMAIL),
      null
    );
    Test.stopTest();

    Assert.areEqual(2, withdrawn);
    Assert.areEqual('Cancelled', reload(pending.Id).Status__c);
    Assert.areEqual('Cancelled', reload(inProcess.Id).Status__c);
    Assert.areEqual(
      0,
      PWChrono_NoticePeriodController.getNoticeRecords(
          userId(ADMIN_EMAIL),
          null
        )
        .size(),
      'Withdrawn notices leave the tracker.'
    );
  }

  @isTest
  static void withdrawRequiresAdministrator() {
    PWChrono_Employee_Separation__c pending = separation(
      userId(LEAVER_EMAIL),
      'Pending',
      Date.today(),
      Date.today().addDays(30)
    );
    insert pending;

    String message = withdrawError(
      new List<Id>{ pending.Id },
      userId(HR_EMAIL)
    );

    Assert.isTrue(message.contains('Only HR administrators'), message);
    Assert.areEqual('Pending', reload(pending.Id).Status__c);
  }

  @isTest
  static void withdrawRejectsCompletedSeparations() {
    PWChrono_Employee_Separation__c pending = separation(
      userId(LEAVER_EMAIL),
      'Pending',
      Date.today(),
      Date.today().addDays(30)
    );
    PWChrono_Employee_Separation__c completed = separation(
      userId(OTHER_EMAIL),
      'Completed',
      Date.today().addDays(-60),
      Date.today().addDays(-30)
    );
    insert new List<PWChrono_Employee_Separation__c>{ pending, completed };
    String completedName = reload(completed.Id).Name;

    String message = withdrawError(
      new List<Id>{ pending.Id, completed.Id },
      userId(ADMIN_EMAIL)
    );

    Assert.isTrue(message.contains('Completed separations cannot'), message);
    Assert.isTrue(message.contains(completedName), message);
    Assert.areEqual(
      'Pending',
      reload(pending.Id).Status__c,
      'Nothing changed.'
    );
    Assert.areEqual('Completed', reload(completed.Id).Status__c);
  }

  @isTest
  static void withdrawValidatesSelection() {
    Id adminId = userId(ADMIN_EMAIL);
    Assert.isTrue(
      withdrawError(new List<Id>(), adminId).contains('Select at least one')
    );
    Assert.isTrue(withdrawError(null, adminId).contains('Select at least one'));

    PWChrono_Employee_Separation__c pending = separation(
      userId(LEAVER_EMAIL),
      'Pending',
      Date.today(),
      Date.today().addDays(30)
    );
    insert pending;
    Id missingId = pending.Id;
    delete pending;
    Assert.isTrue(
      withdrawError(new List<Id>{ missingId }, adminId).contains('not found')
    );

    List<Id> tooMany = new List<Id>();
    for (Integer i = 0; i < 201; i++) {
      tooMany.add(
        Id.valueOf(
          PWChrono_Employee_Separation__c.SObjectType.getDescribe()
            .getKeyPrefix() + String.valueOf(i).leftPad(12, '0')
        )
      );
    }
    Assert.isTrue(withdrawError(tooMany, adminId).contains('at most 200'));
  }

  // ─────────────────────────────────────────────────────────────────────
  // Access
  // ─────────────────────────────────────────────────────────────────────

  @isTest
  static void everyMethodRequiresEmployeeLifecycleFeature() {
    Id plainId = userId(PLAIN_EMAIL);
    Integer denied = 0;

    try {
      PWChrono_NoticePeriodController.getNoticeRecords(plainId, null);
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Employee Lifecycle'));
      denied++;
    }
    try {
      PWChrono_NoticePeriodController.getNoticeOptions(plainId, null);
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Employee Lifecycle'));
      denied++;
    }
    try {
      PWChrono_NoticePeriodController.saveNotice(
        null,
        userId(LEAVER_EMAIL),
        Date.today(),
        Date.today().addDays(30),
        null,
        plainId,
        null
      );
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Employee Lifecycle'));
      denied++;
    }
    try {
      PWChrono_NoticePeriodController.withdrawNotices(
        new List<Id>{ plainId },
        plainId,
        null
      );
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Employee Lifecycle'));
      denied++;
    }

    Assert.areEqual(4, denied, 'All four methods must deny access.');
    Assert.areEqual(0, [SELECT COUNT() FROM PWChrono_Employee_Separation__c]);
  }

  @isTest
  static void guestRuntimeRequiresValidSessionToken() {
    Id adminId = userId(ADMIN_EMAIL);
    PWChrono_GuestSession.testUserTypeOverride = 'Guest';

    try {
      PWChrono_NoticePeriodController.getNoticeRecords(adminId, 'wrong-token');
      Assert.fail('An invalid session token must be rejected.');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Session'), e.getMessage());
    }

    Id noticeId = PWChrono_NoticePeriodController.saveNotice(
      null,
      userId(LEAVER_EMAIL),
      Date.today(),
      Date.today().addDays(30),
      'Guest runtime',
      adminId,
      ADMIN_TOKEN
    );
    Assert.areEqual(
      1,
      PWChrono_NoticePeriodController.getNoticeRecords(adminId, ADMIN_TOKEN)
        .size()
    );
    Assert.areEqual('Pending', reload(noticeId).Status__c);
  }
}