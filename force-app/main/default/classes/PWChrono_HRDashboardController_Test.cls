@IsTest
private class PWChrono_HRDashboardController_Test {
  @IsTest
  static void getDashboardSummary_notNull() {
    Test.startTest();
    PWChrono_HRDashboardController.HRDashboardDTO dto = PWChrono_HRDashboardController.getDashboardSummary(
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, dto, 'DTO should not be null');
    System.assertNotEquals(
      null,
      dto.attendanceLabels,
      'Attendance labels should be present'
    );
    System.assertEquals(
      7,
      dto.attendanceLabels.size(),
      'Attendance labels should contain 7 days'
    );
    System.assertNotEquals(
      null,
      dto.distributionToday,
      'Distribution today should be present'
    );
    System.assertEquals(
      4,
      dto.distributionToday.size(),
      'Distribution should contain 4 categories'
    );
    System.assertNotEquals(
      null,
      dto.lateArrivals,
      'Late arrivals list should be initialized'
    );
    System.assertNotEquals(
      null,
      dto.pendingApprovals,
      'Pending approvals list should be initialized'
    );
    System.assertNotEquals(
      null,
      dto.upcomingInterviews,
      'Upcoming interviews list should be initialized'
    );
    System.assertNotEquals(
      null,
      dto.topEmployees,
      'Top employees list should be initialized'
    );
    System.assertNotEquals(
      null,
      dto.deductionSparkline,
      'Deduction sparkline should be initialized'
    );
    System.assertEquals(
      6,
      dto.deductionSparkline.size(),
      'Sparkline should have 6 points'
    );
  }
}