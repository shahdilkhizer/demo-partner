/**
 * @description Test data factory for Expense Claims module tests.
 *              Mirrors PWChrono_AttendanceTestDataFactory pattern.
 */
@IsTest
public class PWChrono_ExpenseTestDataFactory {
  // ─────────────────────── Portal user builders ─────────────────────────────

  public static Portal_Users__c createEmployee(String name, Boolean isActive) {
    Portal_Users__c emp = new Portal_Users__c(
      Name = name,
      Email__c = name.deleteWhitespace().toLowerCase() + '@example.com',
      Is_Active__c = isActive,
      Role__c = 'Employee',
      Date_Of_Joining__c = Date.today().addYears(-1)
    );
    insert emp;
    return emp;
  }

  public static Portal_Users__c createManager(String name) {
    Portal_Users__c mgr = new Portal_Users__c(
      Name = name,
      Is_Active__c = true,
      Role__c = 'Manager',
      Date_Of_Joining__c = Date.today().addYears(-2)
    );
    insert mgr;
    return mgr;
  }

  public static Portal_Users__c createAdmin(String name) {
    Portal_Users__c admin = new Portal_Users__c(
      Name = name,
      Is_Active__c = true,
      Role__c = 'HR Admin',
      Date_Of_Joining__c = Date.today().addYears(-3)
    );
    insert admin;
    return admin;
  }

  // ─────────────────────── Expense record builders ──────────────────────────

  public static PWChrono_Expense_Claim__c createClaim(
    Id employeeId,
    Id approverId,
    Date claimDate,
    String status
  ) {
    PWChrono_Expense_Claim__c claim = new PWChrono_Expense_Claim__c(
      Employees__c = employeeId,
      Approvers__c = approverId,
      Claim_Date__c = claimDate,
      Description__c = 'Test expense claim for ' + status,
      Business_Purpose__c = 'Test business purpose',
      Status__c = status
    );
    if (status == 'Submitted' || status == 'Approved' || status == 'Rejected') {
      claim.Applied_Date__c = claimDate.addDays(1);
    }
    if (status == 'Approved') {
      claim.Approval_Date__c = claimDate.addDays(2);
    }
    if (status == 'Rejected') {
      claim.Rejection_Reason__c = 'Test rejection reason.';
      claim.Approval_Date__c = claimDate.addDays(2);
    }
    if (status == 'Cancelled') {
      claim.Cancelled_Reason__c = 'Test cancellation reason.';
    }
    insert claim;
    return claim;
  }

  public static PWChrono_Expense_Item__c createItem(
    Id claimId,
    Date itemDate,
    String itemType,
    Decimal amount
  ) {
    PWChrono_Expense_Item__c item = new PWChrono_Expense_Item__c(
      Expense_Claim__c = claimId,
      Date__c = itemDate,
      Type__c = itemType,
      Description__c = 'Test item: ' + itemType,
      Merchant__c = 'Test Merchant',
      Amount__c = amount,
      Receipt_Reference__c = 'REC-TEST-001'
    );
    insert item;
    return item;
  }

  // ─────────────────────── DTO builders ────────────────────────────────────

  public static PWChrono_ExpenseValidator.ExpenseClaimDTO buildClaimDTO(
    Id claimId,
    Date claimDate
  ) {
    PWChrono_ExpenseValidator.ExpenseClaimDTO dto = new PWChrono_ExpenseValidator.ExpenseClaimDTO();
    dto.claimId = claimId;
    dto.claimDate = claimDate;
    dto.description = 'Test claim description';
    dto.businessPurpose = 'Client meeting expenses';
    dto.items = buildItemDTOs(claimDate);
    return dto;
  }

  public static List<PWChrono_ExpenseValidator.ExpenseItemDTO> buildItemDTOs(
    Date itemDate
  ) {
    List<PWChrono_ExpenseValidator.ExpenseItemDTO> items = new List<PWChrono_ExpenseValidator.ExpenseItemDTO>();

    PWChrono_ExpenseValidator.ExpenseItemDTO item1 = new PWChrono_ExpenseValidator.ExpenseItemDTO();
    item1.expenseDate = itemDate;
    item1.itemType = 'Travel';
    item1.description = 'Taxi to client office';
    item1.merchant = 'Grab';
    item1.amount = 45.00;
    item1.receiptReference = 'REC-001';
    items.add(item1);

    PWChrono_ExpenseValidator.ExpenseItemDTO item2 = new PWChrono_ExpenseValidator.ExpenseItemDTO();
    item2.expenseDate = itemDate;
    item2.itemType = 'Food';
    item2.description = 'Client lunch';
    item2.merchant = 'Restaurant ABC';
    item2.amount = 120.00;
    item2.receiptReference = 'REC-002';
    items.add(item2);

    return items;
  }

  // ─────────────────────── Standard bundle ─────────────────────────────────

  public class TestDataBundle {
    public Portal_Users__c manager;
    public Portal_Users__c employee;
    public Portal_Users__c admin;
    public PWChrono_Expense_Claim__c draftClaim;
    public PWChrono_Expense_Claim__c submittedClaim;
    public PWChrono_Expense_Claim__c approvedClaim;
    public PWChrono_Expense_Claim__c rejectedClaim;
    public PWChrono_Expense_Item__c submittedItem;
  }

  public static TestDataBundle setupStandardTestData() {
    TestDataBundle bundle = new TestDataBundle();

    bundle.manager = createManager('Test Manager');
    bundle.employee = createEmployee('Test Employee', true);
    bundle.admin = createAdmin('Test Admin');

    bundle.employee.Reports_To__c = bundle.manager.Id;
    update bundle.employee;

    Date claimDate = Date.today().addDays(-10);

    bundle.draftClaim = createClaim(
      bundle.employee.Id,
      bundle.manager.Id,
      claimDate,
      'Draft'
    );
    bundle.submittedClaim = createClaim(
      bundle.employee.Id,
      bundle.manager.Id,
      claimDate.addDays(-5),
      'Submitted'
    );
    bundle.approvedClaim = createClaim(
      bundle.employee.Id,
      bundle.manager.Id,
      claimDate.addDays(-20),
      'Approved'
    );
    bundle.rejectedClaim = createClaim(
      bundle.employee.Id,
      bundle.manager.Id,
      claimDate.addDays(-15),
      'Rejected'
    );

    bundle.submittedItem = createItem(
      bundle.submittedClaim.Id,
      claimDate.addDays(-5),
      'Travel',
      150.00
    );

    return bundle;
  }
}