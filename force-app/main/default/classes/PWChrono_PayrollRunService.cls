/**
 * @description Server-side payroll orchestration. Remote access is provided only
 *              through PWChrono_PayrollController after its payroll-admin gate.
 *              System-mode data access is intentional because verified portal
 *              administrators run under the Experience Cloud guest user.
 */
@SuppressWarnings(
  'PMD.ApexCRUDViolation,PMD.CognitiveComplexity,PMD.NcssMethodCount'
)
public without sharing class PWChrono_PayrollRunService {
  private static final String STATUS_CANCELLED = 'Cancelled';
  private static final String DELIVERY_NOT_GENERATED = 'Not Generated';
  private static final String DELIVERY_GENERATED = 'Generated';
  private static final String BASIC_COMPONENT = 'Basic';

  public class PayrollWorkspaceDTO {
    @AuraEnabled
    public Date periodStart;
    @AuraEnabled
    public Date periodEnd;
    @AuraEnabled
    public String periodLabel;
    @AuraEnabled
    public String currencyCode;
    @AuraEnabled
    public Integer activeEmployeeCount = 0;
    @AuraEnabled
    public Integer readyEmployeeCount = 0;
    @AuraEnabled
    public Integer missingAssignmentCount = 0;
    @AuraEnabled
    public Integer draftCount = 0;
    @AuraEnabled
    public Integer submittedCount = 0;
    @AuraEnabled
    public Integer paidCount = 0;
    @AuraEnabled
    public Decimal totalGross = 0;
    @AuraEnabled
    public Decimal totalDeductions = 0;
    @AuraEnabled
    public Decimal totalNet = 0;
    @AuraEnabled
    public Boolean configurationComplete = false;
    @AuraEnabled
    public List<PayrollEmployeeDTO> employees = new List<PayrollEmployeeDTO>();
  }

  public class PayrollEmployeeDTO {
    @AuraEnabled
    public Id portalUserId;
    @AuraEnabled
    public Id contactId;
    @AuraEnabled
    public Id assignmentId;
    @AuraEnabled
    public Id salarySlipId;
    @AuraEnabled
    public String salarySlipName;
    @AuraEnabled
    public String employeeName;
    @AuraEnabled
    public String employeeCode;
    @AuraEnabled
    public String department;
    @AuraEnabled
    public String designation;
    @AuraEnabled
    public Decimal baseSalary;
    @AuraEnabled
    public Decimal grossPay = 0;
    @AuraEnabled
    public Decimal totalDeductions = 0;
    @AuraEnabled
    public Decimal netPay = 0;
    @AuraEnabled
    public Decimal paidLeaveDays = 0;
    @AuraEnabled
    public Decimal unpaidLeaveDays = 0;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String readinessMessage;
    @AuraEnabled
    public String componentSummary;
    @AuraEnabled
    public Boolean ready = false;
    @AuraEnabled
    public Boolean salaryEditable = true;
  }

  public class PayrollMutationResult {
    @AuraEnabled
    public Integer createdCount = 0;
    @AuraEnabled
    public Integer updatedCount = 0;
    @AuraEnabled
    public Integer skippedCount = 0;
    @AuraEnabled
    public String message;
  }

  private class PayrollContext {
    public Date periodStart;
    public Date periodEnd;
    public List<Portal_Users__c> employees = new List<Portal_Users__c>();
    public Map<Id, Portal_Users__c> employeeByContact = new Map<Id, Portal_Users__c>();
    public Map<Id, PWChrono_Salary_Assignment__c> assignmentByContact = new Map<Id, PWChrono_Salary_Assignment__c>();
    public Map<Id, List<PWChrono_Structure_Component__c>> componentsByStructure = new Map<Id, List<PWChrono_Structure_Component__c>>();
    public Map<Id, List<Leave__c>> leavesByEmployee = new Map<Id, List<Leave__c>>();
    public Map<Id, PWChrono_Salary_Slip__c> slipByContact = new Map<Id, PWChrono_Salary_Slip__c>();
    public Id basicComponentId;
  }

  private class PayrollCalculation {
    public Boolean valid = true;
    public String validationMessage;
    public Decimal basicPay = 0;
    public Decimal grossPay = 0;
    public Decimal totalDeductions = 0;
    public Decimal netPay = 0;
    public Decimal totalDays = 0;
    public Decimal daysWorked = 0;
    public Decimal paidLeaveDays = 0;
    public Decimal unpaidLeaveDays = 0;
    public List<PayrollLineData> earnings = new List<PayrollLineData>();
    public List<PayrollLineData> deductions = new List<PayrollLineData>();
  }

  private class PayrollLineData {
    public Id componentId;
    public String name;
    public String type;
    public Decimal amount;
    public Boolean taxable;
    public Integer displayOrder;

    public PayrollLineData(
      Id componentId,
      String name,
      String type,
      Decimal amount,
      Boolean taxable,
      Integer displayOrder
    ) {
      this.componentId = componentId;
      this.name = name;
      this.type = type;
      this.amount = amount;
      this.taxable = taxable;
      this.displayOrder = displayOrder;
    }
  }

  /** Returns the authoritative payroll run state for a calendar month. */
  public static PayrollWorkspaceDTO getWorkspace(Date payrollPeriod) {
    PayrollContext context = loadContext(normalizePeriod(payrollPeriod));
    PayrollWorkspaceDTO workspace = new PayrollWorkspaceDTO();
    workspace.periodStart = context.periodStart;
    workspace.periodEnd = context.periodEnd;
    workspace.periodLabel = formatPeriod(context.periodStart);
    workspace.currencyCode = PWChrono_Constants.getEffectiveCurrencyCode();
    workspace.activeEmployeeCount = context.employees.size();

    for (Portal_Users__c employee : context.employees) {
      PayrollEmployeeDTO row = buildEmployeeRow(employee, context);
      workspace.employees.add(row);
      if (row.ready) {
        workspace.readyEmployeeCount++;
      } else {
        workspace.missingAssignmentCount++;
      }

      if (row.status == PWChrono_Constants.STATUS_DRAFT) {
        workspace.draftCount++;
      } else if (row.status == PWChrono_Constants.STATUS_SUBMITTED) {
        workspace.submittedCount++;
      } else if (row.status == PWChrono_Constants.STATUS_PAID) {
        workspace.paidCount++;
      }

      workspace.totalGross += nullToZero(row.grossPay);
      workspace.totalDeductions += nullToZero(row.totalDeductions);
      workspace.totalNet += nullToZero(row.netPay);
    }

    workspace.configurationComplete =
      workspace.activeEmployeeCount > 0 &&
      workspace.missingAssignmentCount == 0;
    return workspace;
  }

  /** Saves an effective-dated base salary while retaining assignment history. */
  public static PayrollMutationResult saveSalaryAssignment(
    Id contactId,
    Decimal baseSalary,
    Date effectiveDate
  ) {
    if (contactId == null) {
      throw handledException('Select an employee before saving salary setup.');
    }
    if (baseSalary == null || baseSalary <= 0) {
      throw handledException('Base salary must be greater than zero.');
    }
    Date startDate = effectiveDate == null ? Date.today() : effectiveDate;

    Portal_Users__c employee = findEmployeeByContact(contactId);
    Date effectiveMonth = Date.newInstance(
      startDate.year(),
      startDate.month(),
      1
    );
    if (
      [
        SELECT COUNT()
        FROM PWChrono_Salary_Slip__c
        WHERE
          Contact__c = :contactId
          AND Payroll_Period__c >= :effectiveMonth
          AND Status__c IN :new Set<String>{
            PWChrono_Constants.STATUS_SUBMITTED,
            PWChrono_Constants.STATUS_PAID
          }
      ] > 0
    ) {
      throw handledException(
        'A submitted or paid payroll period already exists on or after this effective date.'
      );
    }

    List<PWChrono_Salary_Assignment__c> activeAssignments = [
      SELECT
        Id,
        Base_Salary__c,
        From_Date__c,
        To_Date__c,
        Salary_Structure__c,
        Is_Active__c
      FROM PWChrono_Salary_Assignment__c
      WHERE Contact__c = :contactId AND Is_Active__c = TRUE
      ORDER BY From_Date__c DESC NULLS LAST, CreatedDate DESC
    ];

    PayrollMutationResult result = new PayrollMutationResult();
    PWChrono_Salary_Assignment__c current = activeAssignments.isEmpty()
      ? null
      : activeAssignments[0];

    if (
      current != null &&
      (current.From_Date__c == null ||
      startDate <= current.From_Date__c)
    ) {
      current.Base_Salary__c = baseSalary.setScale(2);
      current.From_Date__c = startDate;
      current.Change_Reason__c = 'Correction';
      update current;
      result.updatedCount = 1;
      result.message = 'Salary setup updated.';
      return result;
    }

    if (current != null) {
      current.Is_Active__c = false;
      current.To_Date__c = startDate.addDays(-1);
      update current;
    }

    PWChrono_Salary_Assignment__c nextAssignment = new PWChrono_Salary_Assignment__c(
      Contact__c = contactId,
      Employee__c = employee.Id,
      Employees__c = employee.Id,
      Portal_Users__c = employee.Id,
      Salary_Structure__c = current?.Salary_Structure__c,
      Base_Salary__c = baseSalary.setScale(2),
      Previous_Salary__c = current?.Base_Salary__c,
      From_Date__c = startDate,
      Is_Active__c = true,
      Change_Reason__c = current == null ? 'Initial Offer' : 'Correction'
    );
    insert nextAssignment;
    result.createdCount = 1;
    result.message = current == null
      ? 'Salary setup created.'
      : 'A new effective salary assignment was created.';
    return result;
  }

  /** Creates or recalculates unlocked draft slips for every configured employee. */
  public static PayrollMutationResult generateDrafts(Date payrollPeriod) {
    PayrollContext context = loadContext(normalizePeriod(payrollPeriod));
    if (context.employees.isEmpty()) {
      throw handledException('No active employees are available for payroll.');
    }

    PayrollMutationResult result = new PayrollMutationResult();
    List<PWChrono_Salary_Slip__c> slipsToSave = new List<PWChrono_Salary_Slip__c>();
    Map<Id, PayrollCalculation> calculationByContact = new Map<Id, PayrollCalculation>();
    Set<Id> draftSlipIds = new Set<Id>();

    for (Portal_Users__c employee : context.employees) {
      PWChrono_Salary_Assignment__c assignment = context.assignmentByContact.get(
        employee.Contact__c
      );
      if (
        assignment == null ||
        assignment.Base_Salary__c == null ||
        assignment.Base_Salary__c <= 0
      ) {
        result.skippedCount++;
        continue;
      }

      PWChrono_Salary_Slip__c existing = context.slipByContact.get(
        employee.Contact__c
      );
      if (
        existing != null &&
        (existing.Status__c == PWChrono_Constants.STATUS_SUBMITTED ||
        existing.Status__c == PWChrono_Constants.STATUS_PAID)
      ) {
        result.skippedCount++;
        continue;
      }

      PayrollCalculation calculation = calculatePayroll(
        employee,
        assignment,
        context
      );
      if (!calculation.valid) {
        throw handledException(
          employee.Contact__r.Name + ': ' + calculation.validationMessage
        );
      }

      PWChrono_Salary_Slip__c slip = existing == null
        ? new PWChrono_Salary_Slip__c()
        : existing;
      if (slip.Id != null) {
        draftSlipIds.add(slip.Id);
        result.updatedCount++;
      } else {
        result.createdCount++;
      }
      applySlipValues(slip, employee, assignment, calculation, context);
      slipsToSave.add(slip);
      calculationByContact.put(employee.Contact__c, calculation);
    }

    if (slipsToSave.isEmpty()) {
      throw handledException(
        result.skippedCount > 0
          ? 'No draft payroll records were generated. Complete salary setup or review finalized slips.'
          : 'No payroll records were available to generate.'
      );
    }

    upsert slipsToSave;
    if (!draftSlipIds.isEmpty()) {
      delete [
        SELECT Id
        FROM PWChrono_Salary_Slip_Line__c
        WHERE Salary_Slip__c IN :draftSlipIds
      ];
    }

    List<PWChrono_Salary_Slip_Line__c> lines = new List<PWChrono_Salary_Slip_Line__c>();
    for (PWChrono_Salary_Slip__c slip : slipsToSave) {
      PayrollCalculation calculation = calculationByContact.get(
        slip.Contact__c
      );
      addSlipLines(lines, slip.Id, calculation.earnings);
      addSlipLines(lines, slip.Id, calculation.deductions);
    }
    if (!lines.isEmpty()) {
      insert lines;
    }

    result.message =
      'Payroll drafts prepared: ' +
      result.createdCount +
      ' created, ' +
      result.updatedCount +
      ' refreshed, ' +
      result.skippedCount +
      ' skipped.';
    return result;
  }

  /** Locks every complete draft and publishes it to employee self service. */
  public static PayrollMutationResult submitPayroll(Date payrollPeriod) {
    Date periodStart = normalizePeriod(payrollPeriod);
    PayrollWorkspaceDTO workspace = getWorkspace(periodStart);
    validateCompleteRun(workspace, 'submit');

    List<PWChrono_Salary_Slip__c> drafts = [
      SELECT Id, Status__c, Snapshot_Locked__c, Delivery_Status__c
      FROM PWChrono_Salary_Slip__c
      WHERE
        Payroll_Period__c >= :workspace.periodStart
        AND Payroll_Period__c <= :workspace.periodEnd
        AND Status__c = :PWChrono_Constants.STATUS_DRAFT
      FOR UPDATE
    ];
    for (PWChrono_Salary_Slip__c slip : drafts) {
      slip.Status__c = PWChrono_Constants.STATUS_SUBMITTED;
      slip.Snapshot_Locked__c = true;
      slip.Delivery_Status__c = DELIVERY_GENERATED;
    }
    if (!drafts.isEmpty()) {
      update drafts;
    }

    PayrollMutationResult result = new PayrollMutationResult();
    result.updatedCount = drafts.size();
    result.skippedCount = workspace.submittedCount + workspace.paidCount;
    result.message = drafts.isEmpty()
      ? 'All payslips for this period were already submitted or paid.'
      : drafts.size() + ' payslip(s) finalized and published to employees.';
    return result;
  }

  /** Records payment completion. This does not initiate a bank transfer. */
  public static PayrollMutationResult markPayrollPaid(
    Date payrollPeriod,
    Date paymentDate,
    String paymentMethod
  ) {
    Date periodStart = normalizePeriod(payrollPeriod);
    PayrollWorkspaceDTO workspace = getWorkspace(periodStart);
    validateCompleteRun(workspace, 'pay');
    if (workspace.draftCount > 0) {
      throw handledException(
        'Finalize all draft payslips before marking payroll paid.'
      );
    }
    if (paymentDate == null || paymentDate < workspace.periodStart) {
      throw handledException(
        'Payment date must be on or after the payroll period start.'
      );
    }
    Set<String> allowedMethods = new Set<String>{
      'Bank Transfer',
      'Cash',
      'Cheque',
      'Other'
    };
    if (!allowedMethods.contains(paymentMethod)) {
      throw handledException('Select a valid payment method.');
    }

    List<PWChrono_Salary_Slip__c> submitted = [
      SELECT
        Id,
        Status__c,
        Payment_Date__c,
        Payment_Method__c,
        Snapshot_Locked__c
      FROM PWChrono_Salary_Slip__c
      WHERE
        Payroll_Period__c >= :workspace.periodStart
        AND Payroll_Period__c <= :workspace.periodEnd
        AND Status__c = :PWChrono_Constants.STATUS_SUBMITTED
      FOR UPDATE
    ];
    for (PWChrono_Salary_Slip__c slip : submitted) {
      slip.Status__c = PWChrono_Constants.STATUS_PAID;
      slip.Payment_Date__c = paymentDate;
      slip.Payment_Method__c = paymentMethod;
      slip.Snapshot_Locked__c = true;
    }
    if (!submitted.isEmpty()) {
      update submitted;
    }

    PayrollMutationResult result = new PayrollMutationResult();
    result.updatedCount = submitted.size();
    result.skippedCount = workspace.paidCount;
    result.message = submitted.isEmpty()
      ? 'All payslips for this period were already marked paid.'
      : submitted.size() +
        ' payslip(s) marked paid. No bank transfer was initiated.';
    return result;
  }

  private static PayrollContext loadContext(Date periodStart) {
    PayrollContext context = new PayrollContext();
    context.periodStart = periodStart;
    context.periodEnd = periodStart.addMonths(1).addDays(-1);

    for (Portal_Users__c employee : [
      SELECT
        Id,
        Name,
        Email__c,
        Contact__c,
        Date_of_Joining__c,
        Designation__c,
        Department__c,
        Contact__r.Name,
        Contact__r.Email,
        Contact__r.Employee_ID__c,
        Contact__r.Title,
        Contact__r.Department,
        Contact__r.Father_Name__c,
        Contact__r.Government_ID_Number__c,
        Contact__r.Bank_Name__c,
        Contact__r.Account_Number__c,
        Contact__r.Account_Title__c,
        Contact__r.Branch_Name_Code__c,
        Contact__r.IBAN_Code__c,
        Contact__r.SWIFT_Code__c,
        CreatedDate
      FROM Portal_Users__c
      WHERE Is_Active__c = TRUE AND Contact__c != NULL
      ORDER BY Contact__c, CreatedDate DESC
    ]) {
      if (!context.employeeByContact.containsKey(employee.Contact__c)) {
        context.employeeByContact.put(employee.Contact__c, employee);
        context.employees.add(employee);
      }
    }

    if (context.employeeByContact.isEmpty()) {
      return context;
    }
    Set<Id> contactIds = context.employeeByContact.keySet();
    Set<Id> employeeIds = new Set<Id>();
    for (Portal_Users__c employee : context.employees) {
      employeeIds.add(employee.Id);
    }

    Set<Id> structureIds = new Set<Id>();
    for (PWChrono_Salary_Assignment__c assignment : [
      SELECT
        Id,
        Contact__c,
        Employee__c,
        Employees__c,
        Portal_Users__c,
        Salary_Structure__c,
        Base_Salary__c,
        From_Date__c,
        To_Date__c,
        Is_Active__c
      FROM PWChrono_Salary_Assignment__c
      WHERE
        Contact__c IN :contactIds
        AND Is_Active__c = TRUE
        AND (From_Date__c = NULL
        OR From_Date__c <= :context.periodEnd)
        AND (To_Date__c = NULL
        OR To_Date__c >= :context.periodStart)
      ORDER BY From_Date__c DESC NULLS LAST, CreatedDate DESC
    ]) {
      if (!context.assignmentByContact.containsKey(assignment.Contact__c)) {
        context.assignmentByContact.put(assignment.Contact__c, assignment);
        if (assignment.Salary_Structure__c != null) {
          structureIds.add(assignment.Salary_Structure__c);
        }
      }
    }

    if (!structureIds.isEmpty()) {
      for (PWChrono_Structure_Component__c component : [
        SELECT
          Id,
          Salary_Structure__c,
          Salary_Component__c,
          Salary_Component__r.Name,
          Salary_Component__r.Component_Type__c,
          Salary_Component__r.Is_Active__c,
          Salary_Component__r.Is_Taxable__c,
          Amount__c
        FROM PWChrono_Structure_Component__c
        WHERE
          Salary_Structure__c IN :structureIds
          AND Salary_Component__r.Is_Active__c = TRUE
        ORDER BY Salary_Component__r.Component_Type__c, Salary_Component__r.Name
      ]) {
        if (
          !context.componentsByStructure.containsKey(
            component.Salary_Structure__c
          )
        ) {
          context.componentsByStructure.put(
            component.Salary_Structure__c,
            new List<PWChrono_Structure_Component__c>()
          );
        }
        context.componentsByStructure.get(component.Salary_Structure__c)
          .add(component);
      }
    }

    List<PWChrono_Salary_Component__c> basicComponents = [
      SELECT Id
      FROM PWChrono_Salary_Component__c
      WHERE
        Is_Active__c = TRUE
        AND Component_Type__c = 'Earning'
        AND Name IN ('Basic', 'Basic Salary')
      ORDER BY Name
      LIMIT 1
    ];
    context.basicComponentId = basicComponents.isEmpty()
      ? null
      : basicComponents[0].Id;

    for (Leave__c leaveRecord : [
      SELECT
        Id,
        Employees__c,
        From_Date__c,
        To_Date__c,
        Total_Days__c,
        Leave_Type__r.Is_Unpaid__c
      FROM Leave__c
      WHERE
        Employees__c IN :employeeIds
        AND Status__c = :PWChrono_Constants.STATUS_APPROVED
        AND From_Date__c <= :context.periodEnd
        AND To_Date__c >= :context.periodStart
    ]) {
      if (!context.leavesByEmployee.containsKey(leaveRecord.Employees__c)) {
        context.leavesByEmployee.put(
          leaveRecord.Employees__c,
          new List<Leave__c>()
        );
      }
      context.leavesByEmployee.get(leaveRecord.Employees__c).add(leaveRecord);
    }

    for (PWChrono_Salary_Slip__c slip : [
      SELECT
        Id,
        Name,
        Contact__c,
        Payroll_Period__c,
        Gross_Pay__c,
        Total_Deductions__c,
        Net_Pay__c,
        Status__c,
        Snapshot_Locked__c,
        Delivery_Status__c,
        CreatedDate
      FROM PWChrono_Salary_Slip__c
      WHERE
        Contact__c IN :contactIds
        AND Payroll_Period__c >= :context.periodStart
        AND Payroll_Period__c <= :context.periodEnd
      ORDER BY CreatedDate DESC
    ]) {
      if (!context.slipByContact.containsKey(slip.Contact__c)) {
        context.slipByContact.put(slip.Contact__c, slip);
      } else if (
        context.slipByContact.get(slip.Contact__c).Status__c ==
        STATUS_CANCELLED &&
        slip.Status__c != STATUS_CANCELLED
      ) {
        context.slipByContact.put(slip.Contact__c, slip);
      }
    }
    return context;
  }

  private static PayrollEmployeeDTO buildEmployeeRow(
    Portal_Users__c employee,
    PayrollContext context
  ) {
    PayrollEmployeeDTO row = new PayrollEmployeeDTO();
    row.portalUserId = employee.Id;
    row.contactId = employee.Contact__c;
    row.employeeName = employee.Contact__r.Name;
    row.employeeCode = String.isBlank(employee.Contact__r.Employee_ID__c)
      ? 'Not set'
      : employee.Contact__r.Employee_ID__c;
    row.department = firstNonBlank(
      employee.Contact__r.Department,
      employee.Department__c,
      'Not assigned'
    );
    row.designation = firstNonBlank(
      employee.Contact__r.Title,
      employee.Designation__c,
      'Not assigned'
    );

    PWChrono_Salary_Assignment__c assignment = context.assignmentByContact.get(
      employee.Contact__c
    );
    PWChrono_Salary_Slip__c slip = context.slipByContact.get(
      employee.Contact__c
    );
    if (
      assignment == null ||
      assignment.Base_Salary__c == null ||
      assignment.Base_Salary__c <= 0
    ) {
      row.status = 'Needs setup';
      row.readinessMessage = 'Enter an effective base salary.';
      row.componentSummary = BASIC_COMPONENT;
      return row;
    }

    row.assignmentId = assignment.Id;
    row.baseSalary = assignment.Base_Salary__c;
    PayrollCalculation calculation = calculatePayroll(
      employee,
      assignment,
      context
    );
    row.ready = calculation.valid;
    row.readinessMessage = calculation.valid
      ? 'Ready for payroll'
      : calculation.validationMessage;
    row.componentSummary = buildComponentSummary(calculation);
    row.paidLeaveDays = calculation.paidLeaveDays;
    row.unpaidLeaveDays = calculation.unpaidLeaveDays;

    if (slip == null || slip.Status__c == STATUS_CANCELLED) {
      row.status = calculation.valid ? 'Ready' : 'Needs review';
      row.grossPay = calculation.grossPay;
      row.totalDeductions = calculation.totalDeductions;
      row.netPay = calculation.netPay;
      return row;
    }

    row.salarySlipId = slip.Id;
    row.salarySlipName = slip.Name;
    row.status = slip.Status__c;
    row.grossPay = nullToZero(slip.Gross_Pay__c);
    row.totalDeductions = nullToZero(slip.Total_Deductions__c);
    row.netPay = nullToZero(slip.Net_Pay__c);
    row.salaryEditable = slip.Status__c == PWChrono_Constants.STATUS_DRAFT;
    return row;
  }

  private static PayrollCalculation calculatePayroll(
    Portal_Users__c employee,
    PWChrono_Salary_Assignment__c assignment,
    PayrollContext context
  ) {
    PayrollCalculation calculation = new PayrollCalculation();
    calculation.basicPay = nullToZero(assignment.Base_Salary__c).setScale(2);
    calculation.totalDays = Decimal.valueOf(
      Date.daysInMonth(context.periodStart.year(), context.periodStart.month())
    );

    if (calculation.basicPay <= 0) {
      calculation.valid = false;
      calculation.validationMessage = 'Base salary must be greater than zero.';
      return calculation;
    }

    Integer displayOrder = 1;
    calculation.earnings.add(
      new PayrollLineData(
        context.basicComponentId,
        BASIC_COMPONENT,
        'Earning',
        calculation.basicPay,
        true,
        displayOrder++
      )
    );
    calculation.grossPay = calculation.basicPay;

    List<PWChrono_Structure_Component__c> structureComponents = context.componentsByStructure.get(
      assignment.Salary_Structure__c
    );
    if (structureComponents != null) {
      for (PWChrono_Structure_Component__c component : structureComponents) {
        String componentName = component.Salary_Component__r.Name;
        if (isBasicComponent(componentName)) {
          continue;
        }
        Decimal amount = nullToZero(component.Amount__c);
        if (amount < 0) {
          calculation.valid = false;
          calculation.validationMessage =
            componentName + ' has a negative configured amount.';
          return calculation;
        }
        if (amount == 0) {
          continue;
        }
        PayrollLineData line = new PayrollLineData(
          component.Salary_Component__c,
          componentName,
          component.Salary_Component__r.Component_Type__c,
          amount.setScale(2),
          component.Salary_Component__r.Is_Taxable__c == true,
          displayOrder++
        );
        if (line.type == 'Deduction') {
          calculation.deductions.add(line);
          calculation.totalDeductions += line.amount;
        } else {
          calculation.earnings.add(line);
          calculation.grossPay += line.amount;
        }
      }
    }

    List<Leave__c> leaves = context.leavesByEmployee.get(employee.Id);
    if (leaves != null) {
      for (Leave__c leaveRecord : leaves) {
        Decimal periodDays = proratedLeaveDays(
          leaveRecord,
          context.periodStart,
          context.periodEnd
        );
        if (leaveRecord.Leave_Type__r?.Is_Unpaid__c == true) {
          calculation.unpaidLeaveDays += periodDays;
        } else {
          calculation.paidLeaveDays += periodDays;
        }
      }
    }

    if (calculation.unpaidLeaveDays > 0) {
      Decimal unpaidDeduction =
        (calculation.basicPay / calculation.totalDays) *
        calculation.unpaidLeaveDays;
      unpaidDeduction = unpaidDeduction.setScale(2);
      calculation.deductions.add(
        new PayrollLineData(
          null,
          'Unpaid leave',
          'Deduction',
          unpaidDeduction,
          false,
          displayOrder++
        )
      );
      calculation.totalDeductions += unpaidDeduction;
    }

    calculation.daysWorked =
      calculation.totalDays -
      calculation.paidLeaveDays -
      calculation.unpaidLeaveDays;
    if (calculation.daysWorked < 0) {
      calculation.daysWorked = 0;
    }
    calculation.grossPay = calculation.grossPay.setScale(2);
    calculation.totalDeductions = calculation.totalDeductions.setScale(2);
    calculation.netPay = calculation.grossPay - calculation.totalDeductions;
    if (calculation.netPay < 0) {
      calculation.valid = false;
      calculation.validationMessage = 'Deductions exceed gross pay.';
      return calculation;
    }
    calculation.netPay = calculation.netPay.setScale(2);
    return calculation;
  }

  private static void applySlipValues(
    PWChrono_Salary_Slip__c slip,
    Portal_Users__c employee,
    PWChrono_Salary_Assignment__c assignment,
    PayrollCalculation calculation,
    PayrollContext context
  ) {
    slip.Contact__c = employee.Contact__c;
    slip.Employee__c = employee.Id;
    slip.Employees__c = employee.Id;
    slip.Portal_Users__c = employee.Id;
    slip.Salary_Assignment__c = assignment.Id;
    slip.Payroll_Period__c = context.periodStart;
    slip.Period_Start__c = context.periodStart;
    slip.Period_End__c = context.periodEnd;
    slip.Basic_Pay__c = calculation.basicPay;
    slip.Gross_Pay__c = calculation.grossPay;
    slip.Total_Deductions__c = calculation.totalDeductions;
    slip.Net_Pay__c = calculation.netPay;
    slip.Total_Days__c = calculation.totalDays;
    slip.Days_Worked__c = calculation.daysWorked;
    slip.Paid_Leave_Days__c = calculation.paidLeaveDays;
    slip.Unpaid_Leave_Days__c = calculation.unpaidLeaveDays;
    slip.Currency_Code__c = PWChrono_Constants.getEffectiveCurrencyCode();
    slip.Status__c = PWChrono_Constants.STATUS_DRAFT;
    slip.Delivery_Status__c = DELIVERY_NOT_GENERATED;
    slip.Snapshot_Locked__c = false;
    slip.Snapshot_Version__c = 1;
    slip.Generated_At__c = System.now();
    slip.Generated_By__c = UserInfo.getUserId();
    slip.Document_Reference__c = buildDocumentReference(
      context.periodStart,
      employee.Contact__c
    );
    slip.Employee_Name_Snapshot__c = employee.Contact__r.Name;
    slip.Employee_Code_Snapshot__c = employee.Contact__r.Employee_ID__c;
    slip.Designation_Snapshot__c = firstNonBlank(
      employee.Contact__r.Title,
      employee.Designation__c,
      null
    );
    slip.Department_Snapshot__c = firstNonBlank(
      employee.Contact__r.Department,
      employee.Department__c,
      null
    );
    slip.Father_Name_Snapshot__c = employee.Contact__r.Father_Name__c;
    slip.Government_ID_Masked__c = maskValue(
      employee.Contact__r.Government_ID_Number__c
    );
    slip.Account_Title_Snapshot__c = employee.Contact__r.Account_Title__c;
    slip.Bank_Name_Snapshot__c = employee.Contact__r.Bank_Name__c;
    slip.Bank_Branch_Snapshot__c = employee.Contact__r.Branch_Name_Code__c;
    slip.Account_Number_Masked__c = maskValue(
      employee.Contact__r.Account_Number__c
    );
    slip.IBAN_Masked__c = maskValue(employee.Contact__r.IBAN_Code__c);
    slip.SWIFT_Snapshot__c = employee.Contact__r.SWIFT_Code__c;
    slip.Earning_Details__c = serializeLines(calculation.earnings);
    slip.Deduction_Details__c = serializeLines(calculation.deductions);
  }

  private static void addSlipLines(
    List<PWChrono_Salary_Slip_Line__c> target,
    Id salarySlipId,
    List<PayrollLineData> source
  ) {
    for (PayrollLineData line : source) {
      target.add(
        new PWChrono_Salary_Slip_Line__c(
          Salary_Slip__c = salarySlipId,
          Salary_Component__c = line.componentId,
          Label_Snapshot__c = line.name,
          Line_Type__c = line.type,
          Current_Amount__c = line.amount,
          Is_Taxable__c = line.taxable,
          Display_Order__c = line.displayOrder
        )
      );
    }
  }

  private static void validateCompleteRun(
    PayrollWorkspaceDTO workspace,
    String action
  ) {
    if (workspace.activeEmployeeCount == 0) {
      throw handledException('No active employees are available for payroll.');
    }
    if (workspace.missingAssignmentCount > 0) {
      throw handledException(
        'Complete salary setup for ' +
          workspace.missingAssignmentCount +
          ' employee(s) before you ' +
          action +
          ' payroll.'
      );
    }
    Integer recordedCount =
      workspace.draftCount +
      workspace.submittedCount +
      workspace.paidCount;
    if (recordedCount < workspace.readyEmployeeCount) {
      throw handledException(
        'Generate payroll drafts for every configured employee first.'
      );
    }
  }

  private static Portal_Users__c findEmployeeByContact(Id contactId) {
    List<Portal_Users__c> employees = [
      SELECT Id, Contact__c
      FROM Portal_Users__c
      WHERE Contact__c = :contactId AND Is_Active__c = TRUE
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    if (employees.isEmpty()) {
      throw handledException('The selected employee is not active.');
    }
    return employees[0];
  }

  private static Decimal proratedLeaveDays(
    Leave__c leaveRecord,
    Date periodStart,
    Date periodEnd
  ) {
    if (leaveRecord.From_Date__c == null || leaveRecord.To_Date__c == null) {
      return 0;
    }
    Date overlapStart = leaveRecord.From_Date__c < periodStart
      ? periodStart
      : leaveRecord.From_Date__c;
    Date overlapEnd = leaveRecord.To_Date__c > periodEnd
      ? periodEnd
      : leaveRecord.To_Date__c;
    if (overlapStart > overlapEnd) {
      return 0;
    }
    Decimal fullCalendarDays = Decimal.valueOf(
      leaveRecord.From_Date__c.daysBetween(leaveRecord.To_Date__c) + 1
    );
    Decimal overlapCalendarDays = Decimal.valueOf(
      overlapStart.daysBetween(overlapEnd) + 1
    );
    Decimal recordedDays = leaveRecord.Total_Days__c == null
      ? fullCalendarDays
      : leaveRecord.Total_Days__c;
    return ((recordedDays * overlapCalendarDays) / fullCalendarDays)
      .setScale(2);
  }

  private static String serializeLines(List<PayrollLineData> lines) {
    List<Map<String, Object>> payload = new List<Map<String, Object>>();
    for (PayrollLineData line : lines) {
      payload.add(
        new Map<String, Object>{ 'name' => line.name, 'amount' => line.amount }
      );
    }
    return JSON.serialize(payload);
  }

  private static String buildComponentSummary(PayrollCalculation calculation) {
    List<String> names = new List<String>();
    for (PayrollLineData line : calculation.earnings) {
      names.add(line.name);
    }
    for (PayrollLineData line : calculation.deductions) {
      names.add(line.name);
    }
    return String.join(names, ', ');
  }

  private static String buildDocumentReference(Date periodStart, Id contactId) {
    return 'PAY-' +
      String.valueOf(periodStart.year()) +
      '-' +
      String.valueOf(periodStart.month()).leftPad(2, '0') +
      '-' +
      String.valueOf(contactId);
  }

  private static Boolean isBasicComponent(String componentName) {
    if (String.isBlank(componentName)) {
      return false;
    }
    String normalized = componentName.trim().toLowerCase();
    return normalized == 'basic' || normalized == 'basic salary';
  }

  private static Date normalizePeriod(Date payrollPeriod) {
    Date value = payrollPeriod == null ? Date.today() : payrollPeriod;
    return Date.newInstance(value.year(), value.month(), 1);
  }

  private static String formatPeriod(Date value) {
    return Datetime.newInstance(value, Time.newInstance(0, 0, 0, 0))
      .format('MMMM yyyy');
  }

  private static String firstNonBlank(
    String first,
    String second,
    String fallback
  ) {
    if (String.isNotBlank(first)) {
      return first;
    }
    return String.isNotBlank(second) ? second : fallback;
  }

  private static String maskValue(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    String normalized = value.trim();
    Integer visibleLength = Math.min(4, normalized.length());
    return '**** ' + normalized.right(visibleLength);
  }

  private static Decimal nullToZero(Decimal value) {
    return value == null ? 0 : value;
  }

  private static AuraHandledException handledException(String message) {
    AuraHandledException exceptionValue = new AuraHandledException(message);
    exceptionValue.setMessage(message);
    return exceptionValue;
  }
}