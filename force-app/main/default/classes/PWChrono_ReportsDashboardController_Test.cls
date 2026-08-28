@isTest
private class PWChrono_ReportsDashboardController_Test {
  @isTest
  static void testGetDashboardSummary_DefaultNoDataState() {
    Test.startTest();
    PWChrono_ReportsDashboardController.DashboardSummary summary = PWChrono_ReportsDashboardController.getDashboardSummary(
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, summary, 'Summary should be returned.');
    System.assertNotEquals(
      null,
      summary.leaveMetrics,
      'Leave metrics should be initialized.'
    );
    System.assertNotEquals(
      null,
      summary.attendanceMetrics,
      'Attendance metrics should be initialized.'
    );
    System.assertNotEquals(
      null,
      summary.employeeMetrics,
      'Employee metrics should be initialized.'
    );
    System.assertNotEquals(
      null,
      summary.performanceMetrics,
      'Performance metrics should be initialized.'
    );
    System.assertNotEquals(
      null,
      summary.expenseMetrics,
      'Expense metrics should be initialized.'
    );
    System.assertNotEquals(
      null,
      summary.trainingMetrics,
      'Training metrics should be initialized.'
    );
    System.assertNotEquals(
      null,
      summary.recruitmentMetrics,
      'Recruitment metrics should be initialized.'
    );
  }

  @isTest
  static void testIndividualMetricEndpoints_DefaultNoDataState() {
    Test.startTest();
    PWChrono_ReportsDashboardController.LeaveMetrics leaveMetrics = PWChrono_ReportsDashboardController.getLeaveMetrics();
    PWChrono_ReportsDashboardController.AttendanceMetrics attendanceMetrics = PWChrono_ReportsDashboardController.getAttendanceMetrics();
    PWChrono_ReportsDashboardController.EmployeeMetrics employeeMetrics = PWChrono_ReportsDashboardController.getEmployeeMetrics();
    PWChrono_ReportsDashboardController.PerformanceMetrics performanceMetrics = PWChrono_ReportsDashboardController.getPerformanceMetrics();
    PWChrono_ReportsDashboardController.ExpenseMetrics expenseMetrics = PWChrono_ReportsDashboardController.getExpenseMetrics();
    PWChrono_ReportsDashboardController.TrainingMetrics trainingMetrics = PWChrono_ReportsDashboardController.getTrainingMetrics();
    PWChrono_ReportsDashboardController.RecruitmentMetrics recruitmentMetrics = PWChrono_ReportsDashboardController.getRecruitmentMetrics();
    Test.stopTest();

    System.assertNotEquals(null, leaveMetrics);
    System.assertNotEquals(null, attendanceMetrics);
    System.assertNotEquals(null, employeeMetrics);
    System.assertNotEquals(null, performanceMetrics);
    System.assertNotEquals(null, expenseMetrics);
    System.assertNotEquals(null, trainingMetrics);
    System.assertNotEquals(null, recruitmentMetrics);
  }
}