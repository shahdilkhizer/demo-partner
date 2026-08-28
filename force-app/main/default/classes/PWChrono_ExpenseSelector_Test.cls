/**
 * @description Tests for PWChrono_ExpenseSelector.
 *              Verifies each query method returns correct results and respects filters.
 */
@IsTest
private class PWChrono_ExpenseSelector_Test {

  @TestSetup
  static void setup() {
    PWChrono_ExpenseTestDataFactory.setupStandardTestData();
  }

  // ─────────────────────── getClaimById ─────────────────────────────────────

  @IsTest
  static void testGetClaimById_existingRecord_returnsFullClaim() {
    PWChrono_Expense_Claim__c expected = [SELECT Id FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Submitted' LIMIT 1];

    Test.startTest();
    PWChrono_Expense_Claim__c result = PWChrono_ExpenseSelector.getClaimById(expected.Id);
    Test.stopTest();

    System.assertEquals(expected.Id, result.Id, 'Should return matching record');
    System.assertNotEquals(null, result.Employees__r, 'Should join employee relationship');
  }

  @IsTest
  static void testGetClaimById_nullId_returnsNull() {
    Test.startTest();
    PWChrono_Expense_Claim__c result = PWChrono_ExpenseSelector.getClaimById(null);
    Test.stopTest();
    System.assertEquals(null, result, 'Null Id should return null');
  }

  // ─────────────────────── getClaimsByEmployee ──────────────────────────────

  @IsTest
  static void testGetClaimsByEmployee_noFilters_returnsAllForEmployee() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];

    Test.startTest();
    List<PWChrono_Expense_Claim__c> result =
      PWChrono_ExpenseSelector.getClaimsByEmployee(emp.Id, null, null, null);
    Test.stopTest();

    System.assert(result.size() >= 4, 'Should return at least 4 test claims');
    for (PWChrono_Expense_Claim__c c : result) {
      System.assertEquals(emp.Id, c.Employees__c, 'All claims should belong to this employee');
    }
  }

  @IsTest
  static void testGetClaimsByEmployee_statusFilter_returnsFiltered() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];

    Test.startTest();
    List<PWChrono_Expense_Claim__c> result =
      PWChrono_ExpenseSelector.getClaimsByEmployee(emp.Id, 'Draft', null, null);
    Test.stopTest();

    for (PWChrono_Expense_Claim__c c : result) {
      System.assertEquals('Draft', c.Status__c, 'Should only return Draft claims');
    }
  }

  @IsTest
  static void testGetClaimsByEmployee_dateRange_filters() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];
    Date start   = Date.today().addDays(-30);
    Date endDate = Date.today();

    Test.startTest();
    List<PWChrono_Expense_Claim__c> result =
      PWChrono_ExpenseSelector.getClaimsByEmployee(emp.Id, null, start, endDate);
    Test.stopTest();

    for (PWChrono_Expense_Claim__c c : result) {
      System.assert(c.Claim_Date__c >= start && c.Claim_Date__c <= endDate,
        'Claim date should be within range');
    }
  }

  // ─────────────────────── getRecentClaimsByEmployee ────────────────────────

  @IsTest
  static void testGetRecentClaimsByEmployee_returnsRecentClaims() {
    Portal_Users__c emp = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Employee' LIMIT 1];

    Test.startTest();
    List<PWChrono_Expense_Claim__c> result =
      PWChrono_ExpenseSelector.getRecentClaimsByEmployee(emp.Id);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should not return null');
    System.assert(result.size() <= 5, 'Should return at most 5 recent claims');
  }

  // ─────────────────────── getTeamClaimsForApproval ────────────────────────

  @IsTest
  static void testGetTeamClaimsForApproval_returnsSubmittedClaims() {
    Portal_Users__c mgr = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Manager' LIMIT 1];

    Test.startTest();
    List<PWChrono_Expense_Claim__c> result =
      PWChrono_ExpenseSelector.getTeamClaimsForApproval(mgr.Id);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return a list');
    for (PWChrono_Expense_Claim__c c : result) {
      System.assertEquals('Submitted', c.Status__c, 'Should only return Submitted claims');
      System.assertEquals(mgr.Id, c.Approvers__c, 'Should only return claims for this approver');
    }
  }

  // ─────────────────────── getTeamClaims ───────────────────────────────────

  @IsTest
  static void testGetTeamClaims_noFilter_returnsAllTeamClaims() {
    Portal_Users__c mgr = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Manager' LIMIT 1];

    Test.startTest();
    List<PWChrono_Expense_Claim__c> result =
      PWChrono_ExpenseSelector.getTeamClaims(mgr.Id, null);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return a list');
    System.assert(result.size() >= 4, 'Should return all test team claims');
  }

  @IsTest
  static void testGetTeamClaims_withStatusFilter_returnsFiltered() {
    Portal_Users__c mgr = [SELECT Id FROM Portal_Users__c WHERE Role__c = 'Manager' LIMIT 1];

    Test.startTest();
    List<PWChrono_Expense_Claim__c> result =
      PWChrono_ExpenseSelector.getTeamClaims(mgr.Id, 'Approved');
    Test.stopTest();

    for (PWChrono_Expense_Claim__c c : result) {
      System.assertEquals('Approved', c.Status__c, 'Should only return Approved claims');
    }
  }

  // ─────────────────────── getItemsByClaimId ───────────────────────────────

  @IsTest
  static void testGetItemsByClaimId_returnsItems() {
    PWChrono_Expense_Claim__c claim = [SELECT Id FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Submitted' LIMIT 1];

    Test.startTest();
    List<PWChrono_Expense_Item__c> result =
      PWChrono_ExpenseSelector.getItemsByClaimId(claim.Id);
    Test.stopTest();

    System.assert(result.size() >= 1, 'Should return at least 1 item');
    for (PWChrono_Expense_Item__c item : result) {
      System.assertEquals(claim.Id, item.Expense_Claim__c, 'Items should belong to the claim');
    }
  }

  @IsTest
  static void testGetItemsByClaimId_noItems_returnsEmpty() {
    PWChrono_Expense_Claim__c emptyClaim = [SELECT Id FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Draft' LIMIT 1];

    Test.startTest();
    List<PWChrono_Expense_Item__c> result =
      PWChrono_ExpenseSelector.getItemsByClaimId(emptyClaim.Id);
    Test.stopTest();

    System.assertEquals(0, result.size(), 'Draft claim with no items should return empty list');
  }
}