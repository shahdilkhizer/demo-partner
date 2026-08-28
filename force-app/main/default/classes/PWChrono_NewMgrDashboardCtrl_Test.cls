@isTest
public class PWChrono_NewMgrDashboardCtrl_Test {
  @isTest
  static void testGetDashboardData() {
    Test.startTest();
    String result = PWChrono_NewMgrDashboardCtrl.getDashboardData();
    Test.stopTest();

    System.assert(result != null, 'The result should not be null.');
  }
}