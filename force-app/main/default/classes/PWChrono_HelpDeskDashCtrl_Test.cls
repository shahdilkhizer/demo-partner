@IsTest
private class PWChrono_HelpDeskDashCtrl_Test {
  @IsTest
  static void testSummaryBasic() {
    System.runAs(new User(Id = UserInfo.getUserId())) {
      List<Case> cases = new List<Case>();
      cases.add(
        new Case(Subject = 'Open Ticket', Status = 'New', Origin = 'Phone')
      );
      cases.add(
        new Case(
          Subject = 'In Progress Ticket',
          Status = 'Working',
          Origin = 'Phone'
        )
      );
      cases.add(
        new Case(
          Subject = 'On Hold Ticket',
          Status = 'On Hold',
          Origin = 'Phone'
        )
      );
      insert cases;

      // Close one
      Case c = cases[0];
      c.Status = 'Closed';
      update c;

      Test.startTest();
      PWChrono_HelpDeskDashboardController.HelpDeskDashboardDTO dto = PWChrono_HelpDeskDashboardController.getDashboardSummary();
      Test.stopTest();

      System.assertNotEquals(null, dto, 'DTO should not be null');
      System.assert(
        dto.totalTickets >= 3,
        'Total should include created cases'
      );
      System.assert(dto.statusCounts != null, 'statusCounts should exist');
      System.assert(
        dto.trendLabels != null && dto.trendLabels.size() == 7,
        'trendLabels size'
      );
      System.assert(
        dto.createdTrend != null && dto.createdTrend.size() == 7,
        'createdTrend size'
      );
      System.assert(
        dto.resolvedTrend != null && dto.resolvedTrend.size() == 7,
        'resolvedTrend size'
      );
    }
  }
}