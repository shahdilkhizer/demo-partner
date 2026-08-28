/**
 * @description Tests for PWChrono_ExpenseService.
 *              Covers: saveClaim, submitClaim, processApproval,
 *              cancelClaim, getDashboardSummary, and error paths.
 */
@IsTest
private class PWChrono_ExpenseService_Test {
  @TestSetup
  static void setup() {
    PWChrono_ExpenseTestDataFactory.setupStandardTestData();
  }

  // ─────────────────────── saveClaim (new) ──────────────────────────────────

  @IsTest
  static void testSaveClaim_newClaim_createsDraftWithItems() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    Date claimDate = Date.today().addDays(-3);
    PWChrono_ExpenseValidator.ExpenseClaimDTO dto = PWChrono_ExpenseTestDataFactory.buildClaimDTO(
      null,
      claimDate
    );

    Test.startTest();
    PWChrono_Expense_Claim__c result = PWChrono_ExpenseService.saveClaim(
      dto,
      emp.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, result.Id, 'Should return a saved claim');
    System.assertEquals('Draft', result.Status__c, 'New claim should be Draft');
    System.assertEquals(emp.Id, result.Employees__c, 'Employee should match');
    System.assertEquals(
      claimDate,
      result.Claim_Date__c,
      'Claim date should match'
    );
    System.assertEquals(
      165.00,
      result.Total_Amount__c,
      'Total should be sum of items'
    );

    List<PWChrono_Expense_Item__c> items = [
      SELECT Id
      FROM PWChrono_Expense_Item__c
      WHERE Expense_Claim__c = :result.Id
    ];
    System.assertEquals(2, items.size(), 'Should have created 2 items');
  }

  @IsTest
  static void testSaveClaim_editExisting_replacesItems() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c draft = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Draft' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    // Add an initial item
    PWChrono_ExpenseTestDataFactory.createItem(
      draft.Id,
      Date.today().addDays(-5),
      'Food',
      50.00
    );

    // Now save with 1 new item replacing the old one
    PWChrono_ExpenseValidator.ExpenseClaimDTO dto = PWChrono_ExpenseTestDataFactory.buildClaimDTO(
      draft.Id,
      Date.today().addDays(-5)
    );
    dto.items = new List<PWChrono_ExpenseValidator.ExpenseItemDTO>{
      new PWChrono_ExpenseValidator.ExpenseItemDTO()
    };
    dto.items[0].expenseDate = Date.today().addDays(-5);
    dto.items[0].itemType = 'Travel';
    dto.items[0].description = 'Single replacement item';
    dto.items[0].merchant = 'Taxi';
    dto.items[0].amount = 99.00;

    Test.startTest();
    PWChrono_Expense_Claim__c result = PWChrono_ExpenseService.saveClaim(
      dto,
      emp.Id
    );
    Test.stopTest();

    List<PWChrono_Expense_Item__c> remaining = [
      SELECT Id
      FROM PWChrono_Expense_Item__c
      WHERE Expense_Claim__c = :draft.Id
    ];
    System.assertEquals(
      1,
      remaining.size(),
      'Old items should be replaced by 1 new item'
    );
    System.assertEquals(
      99.00,
      result.Total_Amount__c,
      'Total should reflect replacement item'
    );
  }

  @IsTest
  static void testSaveClaim_validationFails_throwsException() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_ExpenseValidator.ExpenseClaimDTO dto = PWChrono_ExpenseTestDataFactory.buildClaimDTO(
      null,
      Date.today().addDays(5)
    ); // future date

    Test.startTest();
    try {
      PWChrono_ExpenseService.saveClaim(dto, emp.Id);
      System.assert(false, 'Should have thrown for future date');
    } catch (AuraHandledException e) {
      System.assert(e.getMessage().length() > 0, 'Should have error message');
    }
    Test.stopTest();
  }

  // ─────────────────────── submitClaim ──────────────────────────────────────

  @IsTest
  static void testSubmitClaim_draftWithItems_setsSubmitted() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c draft = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Draft' AND Employees__c = :emp.Id
      LIMIT 1
    ];
    // Add required items
    PWChrono_ExpenseTestDataFactory.createItem(
      draft.Id,
      Date.today().addDays(-10),
      'Food',
      80.00
    );

    Test.startTest();
    PWChrono_Expense_Claim__c result = PWChrono_ExpenseService.submitClaim(
      draft.Id,
      emp.Id
    );
    Test.stopTest();

    System.assertEquals(
      'Submitted',
      result.Status__c,
      'Should transition to Submitted'
    );
    System.assertEquals(
      Date.today(),
      result.Applied_Date__c,
      'Applied date should be today'
    );
    System.assertNotEquals(
      null,
      result.Approvers__c,
      'Approver should be assigned'
    );
  }

  @IsTest
  static void testSubmitClaim_notOwner_throwsException() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c draft = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Draft'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_ExpenseService.submitClaim(draft.Id, mgr.Id);
      System.assert(false, 'Non-owner should not be able to submit');
    } catch (AuraHandledException e) {
      System.assert(e.getMessage().length() > 0);
    }
    Test.stopTest();
  }

  @IsTest
  static void testSubmitClaim_alreadySubmitted_throwsException() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c submitted = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Submitted' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_ExpenseService.submitClaim(submitted.Id, emp.Id);
      System.assert(false, 'Should throw for invalid status transition');
    } catch (AuraHandledException e) {
      System.assert(e.getMessage().length() > 0);
    }
    Test.stopTest();
  }

  // ─────────────────────── processApproval ─────────────────────────────────

  @IsTest
  static void testProcessApproval_approve_setsApproved() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c submitted = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Expense_Claim__c result = PWChrono_ExpenseService.processApproval(
      submitted.Id,
      'Approve',
      'Great expenses.',
      mgr.Id
    );
    Test.stopTest();

    System.assertEquals('Approved', result.Status__c, 'Should be Approved');
    System.assertEquals(
      Date.today(),
      result.Approval_Date__c,
      'Approval date should be today'
    );
    System.assertEquals(
      'Great expenses.',
      result.Approver_Comments__c,
      'Comments should be stored'
    );
  }

  @IsTest
  static void testProcessApproval_reject_setsRejected() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c submitted = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Expense_Claim__c result = PWChrono_ExpenseService.processApproval(
      submitted.Id,
      'Reject',
      'Missing receipts.',
      mgr.Id
    );
    Test.stopTest();

    System.assertEquals('Rejected', result.Status__c, 'Should be Rejected');
    System.assertEquals(
      'Missing receipts.',
      result.Rejection_Reason__c,
      'Rejection reason stored'
    );
    System.assertEquals(
      Date.today(),
      result.Approval_Date__c,
      'Approval date should be today'
    );
  }

  @IsTest
  static void testProcessApproval_notApprover_throwsException() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c submitted = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_ExpenseService.processApproval(
        submitted.Id,
        'Approve',
        null,
        emp.Id
      );
      System.assert(false, 'Non-approver should not be able to approve');
    } catch (AuraHandledException e) {
      System.assert(e.getMessage().length() > 0);
    }
    Test.stopTest();
  }

  @IsTest
  static void testProcessApproval_reject_missingReason_throwsException() {
    Portal_Users__c mgr = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Manager'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c submitted = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Submitted'
      LIMIT 1
    ];

    Test.startTest();
    try {
      PWChrono_ExpenseService.processApproval(
        submitted.Id,
        'Reject',
        null,
        mgr.Id
      );
      System.assert(false, 'Reject without reason should throw');
    } catch (AuraHandledException e) {
      System.assert(e.getMessage().length() > 0);
    }
    Test.stopTest();
  }

  // ─────────────────────── cancelClaim ──────────────────────────────────────

  @IsTest
  static void testCancelClaim_draft_setsCancelled() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c draft = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Draft' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Expense_Claim__c result = PWChrono_ExpenseService.cancelClaim(
      draft.Id,
      'No longer needed.',
      emp.Id
    );
    Test.stopTest();

    System.assertEquals('Cancelled', result.Status__c, 'Should be cancelled');
    System.assertEquals(
      'No longer needed.',
      result.Cancelled_Reason__c,
      'Reason stored'
    );
  }

  @IsTest
  static void testCancelClaim_submitted_setsCancelled() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c submitted = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Submitted' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Expense_Claim__c result = PWChrono_ExpenseService.cancelClaim(
      submitted.Id,
      'Incorrect items.',
      emp.Id
    );
    Test.stopTest();

    System.assertEquals(
      'Cancelled',
      result.Status__c,
      'Submitted claim should be cancellable'
    );
  }

  @IsTest
  static void testCancelClaim_approved_setsCancelled() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];
    PWChrono_Expense_Claim__c approved = [
      SELECT Id
      FROM PWChrono_Expense_Claim__c
      WHERE Status__c = 'Approved' AND Employees__c = :emp.Id
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_Expense_Claim__c result = PWChrono_ExpenseService.cancelClaim(
      approved.Id,
      'Trying to cancel approved.',
      emp.Id
    );
    Test.stopTest();

    System.assertEquals(
      'Cancelled',
      result.Status__c,
      'Approved claim should be cancellable'
    );
  }

  // ─────────────────────── getDashboardSummary ──────────────────────────────

  @IsTest
  static void testGetDashboardSummary_returnsAllCounts() {
    Portal_Users__c emp = [
      SELECT Id
      FROM Portal_Users__c
      WHERE Role__c = 'Employee'
      LIMIT 1
    ];

    Test.startTest();
    PWChrono_ExpenseService.ExpenseDashboardDTO result = PWChrono_ExpenseService.getDashboardSummary(
      emp.Id,
      null,
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'Should return dashboard DTO');
    System.assert(
      result.totalClaims >= 4,
      'Should count all test claims as total'
    );
    System.assertEquals(1, result.draftCount, 'Should count 1 Draft');
    System.assertEquals(1, result.submittedCount, 'Should count 1 Submitted');
    System.assertEquals(1, result.approvedCount, 'Should count 1 Approved');
    System.assertEquals(1, result.rejectedCount, 'Should count 1 Rejected');
    System.assertNotEquals(
      null,
      result.recentClaims,
      'Recent claims should not be null'
    );
  }
}