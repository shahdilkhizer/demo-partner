@isTest
private class PWChrono_PMDashboardController_Test {
  @TestSetup
  static void makeData() {
    User pmUser = PWChrono_TestDataFactory.createTestUser('ProjectManager');
    Portal_Users__c pm = PWChrono_TestDataFactory.createTestEmployee(pmUser.Id);
    pm.Role__c = PWChrono_Constants.ROLE_PROJECT_MANAGER;
    update pm;

    User empUser = PWChrono_TestDataFactory.createTestUser('RegularEmployee');
    // Default role for createTestEmployee is Employee.
    PWChrono_TestDataFactory.createTestEmployee(empUser.Id);

    List<PWChrono_Project__c> projects = new List<PWChrono_Project__c>{
      new PWChrono_Project__c(
        Name = 'Active High Priority',
        Status__c = PWChrono_Constants.STATUS_ACTIVE,
        Priority__c = 'High',
        End_Date__c = Date.today().addDays(7),
        Total_Hours__c = 100,
        Hours_Logged__c = 50,
        Amount__c = 10000,
        Team_Size__c = 5
      ),
      new PWChrono_Project__c(
        Name = 'Active Medium Priority',
        Status__c = PWChrono_Constants.STATUS_ACTIVE,
        Priority__c = 'Medium',
        End_Date__c = Date.today().addDays(30),
        Total_Hours__c = 80,
        Hours_Logged__c = 20,
        Amount__c = 20000,
        Team_Size__c = 3
      ),
      new PWChrono_Project__c(
        Name = 'Active Overrun',
        Status__c = PWChrono_Constants.STATUS_ACTIVE,
        Priority__c = 'Low',
        End_Date__c = Date.today().addDays(10),
        Total_Hours__c = 10,
        Hours_Logged__c = 15,
        Amount__c = 5000,
        Team_Size__c = 2
      ),
      new PWChrono_Project__c(
        Name = 'Inactive Project',
        Status__c = 'Inactive',
        Priority__c = 'Low',
        End_Date__c = Date.today().addDays(7),
        Total_Hours__c = 10,
        Hours_Logged__c = 1,
        Amount__c = 1000,
        Team_Size__c = 1
      )
    };
    insert projects;
  }

  @isTest
  static void testGetDashboardData_ProjectManagerAllowed() {
    User pmUser = [
      SELECT Id
      FROM User
      WHERE LastName = 'ProjectManager'
      LIMIT 1
    ];

    System.runAs(pmUser) {
      Test.startTest();
      PWChrono_PMDashboardController.DashboardDTO dto = PWChrono_PMDashboardController.getDashboardData(
        null,
        null
      );
      Test.stopTest();

      System.assertNotEquals(null, dto, 'DTO should be returned');
      System.assertEquals(4, dto.totalProjects, 'Total projects should match');
      System.assertEquals(
        3,
        dto.activeProjects,
        'Active projects should match'
      );
      System.assertEquals(
        1,
        dto.highPriorityActiveProjects,
        'High priority active projects should match'
      );
      System.assertEquals(
        2,
        dto.endingSoonProjects,
        'Ending soon projects should match'
      );
      System.assertNotEquals(
        null,
        dto.recentProjects,
        'Recent projects should be returned'
      );
      System.assert(
        dto.recentProjects.size() > 0,
        'Recent projects should not be empty'
      );

      // New PM metrics
      System.assertEquals(
        35000,
        dto.activeProjectValue,
        'Active project value should sum'
      );
      System.assertEquals(
        85,
        dto.activeHoursLogged,
        'Active hours logged should sum'
      );
      System.assertEquals(
        190,
        dto.activeHoursPlanned,
        'Active planned hours should sum'
      );
      System.assertEquals(
        10,
        dto.activeTeamSize,
        'Active team size should sum'
      );
      System.assertEquals(1, dto.atRiskProjects, 'At-risk count should match');
      System.assertEquals(1, dto.overrunProjects, 'Overrun count should match');
      System.assertEquals(
        true,
        dto.atRiskProjectRows != null && dto.atRiskProjectRows.size() > 0,
        'At-risk rows should be returned'
      );
      System.assertEquals(
        true,
        dto.overrunProjectRows != null && dto.overrunProjectRows.size() > 0,
        'Overrun rows should be returned'
      );
    }
  }

  @isTest
  static void testGetDashboardData_EmployeeDenied() {
    User empUser = [
      SELECT Id
      FROM User
      WHERE LastName = 'RegularEmployee'
      LIMIT 1
    ];

    System.runAs(empUser) {
      Test.startTest();
      Boolean threw = false;
      try {
        PWChrono_PMDashboardController.getDashboardData(null, null);
      } catch (Exception e) {
        threw = true;
      }
      Test.stopTest();
      System.assert(threw, 'Non-project manager users should be denied');
    }
  }
}