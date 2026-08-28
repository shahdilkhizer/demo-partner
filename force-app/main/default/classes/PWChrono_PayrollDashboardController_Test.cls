@IsTest
private class PWChrono_PayrollDashboardController_Test {
  @IsTest
  static void testSummaryBasic() {
    Date period = Date.today();
    insert new List<PWChrono_Salary_Slip__c>{
      new PWChrono_Salary_Slip__c(
        Payroll_Period__c = period,
        Gross_Pay__c = 25000,
        Net_Pay__c = 20000,
        Total_Deductions__c = 5000,
        Status__c = 'Paid'
      ),
      new PWChrono_Salary_Slip__c(
        Payroll_Period__c = period,
        Gross_Pay__c = 60000,
        Net_Pay__c = 48000,
        Total_Deductions__c = 12000,
        Status__c = 'Paid'
      )
    };

    Test.startTest();
    PWChrono_PayrollDashboardController.PayrollDashboardDTO dto = PWChrono_PayrollDashboardController.getDashboardSummary();
    Test.stopTest();

    System.assertNotEquals(null, dto, 'DTO should not be null');
    System.assert(dto.totalGross > 0, 'Gross should be summed');
    System.assert(
      dto.salaryRangeLabels != null && dto.salaryRangeLabels.size() == 5,
      'Range labels'
    );
    System.assert(
      dto.salaryRangeCounts != null && dto.salaryRangeCounts.size() == 5,
      'Range counts'
    );
    System.assert(
      dto.trendLabels != null && dto.trendLabels.size() == 6,
      'Trend labels'
    );
  }
}