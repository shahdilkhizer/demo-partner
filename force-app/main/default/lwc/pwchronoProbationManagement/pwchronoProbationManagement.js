import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import getProbations from "@salesforce/apex/PWChrono_ProbationController.getProbations";
import getProbationOptions from "@salesforce/apex/PWChrono_ProbationController.getProbationOptions";
import saveProbation from "@salesforce/apex/PWChrono_ProbationController.saveProbation";
import updateProbationStatus from "@salesforce/apex/PWChrono_ProbationController.updateProbationStatus";
import deleteProbations from "@salesforce/apex/PWChrono_ProbationController.deleteProbations";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { downloadCsv } from "c/pwchronoCsv";
import {
  ADMIN_ROLES,
  DEFAULT_PROBATION_DAYS,
  DELETABLE_STATUSES,
  EMPLOYEE_AVATAR_PATH,
  OPEN_STATUSES,
  PAGE_SIZE,
  REVIEWER_AVATAR_PATH,
  SORT_OPTIONS,
  STATUS,
  STATUS_ACTIONS,
  STATUS_BADGE_CLASSES
} from "./pwchronoProbationConstants";

const MONTHS = [
  "Jan",
  "Feb",
  "Mar",
  "Apr",
  "May",
  "Jun",
  "Jul",
  "Aug",
  "Sep",
  "Oct",
  "Nov",
  "Dec"
];

/** Parses an Apex Date ("YYYY-MM-DD") without time zone shifts. */
function parseIsoDate(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value || "");
  if (!match) return null;
  return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
}

function toIsoDate(date) {
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${date.getFullYear()}-${month}-${day}`;
}

function addDays(isoDate, days) {
  const date = parseIsoDate(isoDate);
  if (!date) return "";
  date.setDate(date.getDate() + days);
  return toIsoDate(date);
}

function formatDate(value) {
  const date = parseIsoDate(value);
  if (!date) return "";
  const day = String(date.getDate()).padStart(2, "0");
  return `${day} ${MONTHS[date.getMonth()]} ${date.getFullYear()}`;
}

function describeRemaining(daysRemaining) {
  if (daysRemaining === null || daysRemaining === undefined) return "";
  if (daysRemaining === 0) return "Ends today";
  if (daysRemaining < 0) {
    const overdue = Math.abs(daysRemaining);
    return `${overdue} day${overdue === 1 ? "" : "s"} overdue`;
  }
  return `${daysRemaining} day${daysRemaining === 1 ? "" : "s"} left`;
}

function reduceError(error) {
  if (!error) return "Unexpected error. Please try again.";
  if (Array.isArray(error.body)) {
    return error.body.map((item) => item.message).join(", ");
  }
  return (
    error.body?.message ||
    error.message ||
    "Unexpected error. Please try again."
  );
}

function emptyAddForm() {
  return {
    employeeId: "",
    startDate: "",
    endDate: "",
    reviewerId: "",
    notes: "",
    endDateTouched: false
  };
}

export default class PwchronoProbationManagement extends LightningElement {
  @track records = [];
  @track employees = [];
  @track selectedIds = [];
  @track addForm = emptyAddForm();
  @track editForm = {};
  @track statusForm = {};

  isLoading = true;
  loadError = "";
  isSaving = false;
  defaultProbationDays = DEFAULT_PROBATION_DAYS;
  serverIsAdmin = null;

  searchKeyword = "";
  selectedDesignation = "";
  currentSort = SORT_OPTIONS[0].value;
  currentPage = 1;

  isExportOpen = false;
  isDesigOpen = false;
  isSortOpen = false;
  isCollapsed = false;

  isDetailsOpen = false;
  isAddModalOpen = false;
  isEditModalOpen = false;
  isStatusModalOpen = false;
  isDeleteModalOpen = false;

  activeRecordId = null;
  deletingIds = [];
  pendingNotesPrefill = false;

  connectedCallback() {
    this.loadAll();
  }

  renderedCallback() {
    // Native textareas ignore a value binding, so prefill the administrator's
    // notes editor once each time the Edit modal opens.
    if (this.pendingNotesPrefill && this.isEditModalOpen) {
      const notes = this.template.querySelector('textarea[data-field="notes"]');
      if (notes) {
        notes.value = this.editForm.notes || "";
      }
      this.pendingNotesPrefill = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  get session() {
    return getSession() || {};
  }

  get portalUserId() {
    const session = this.session;
    return session.user?.Id || session.portalUserId || null;
  }

  get sessionParams() {
    return {
      portalUserId: this.portalUserId,
      sessionToken: getSessionToken()
    };
  }

  get role() {
    const session = this.session;
    return session.user?.Role__c || session.user?.role || session.role || "";
  }

  /** The server decides; the session role is only used until it answers. */
  get isAdmin() {
    if (typeof this.serverIsAdmin === "boolean") {
      return this.serverIsAdmin;
    }
    return ADMIN_ROLES.includes(this.role);
  }

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  async loadAll() {
    this.isLoading = true;
    this.loadError = "";
    try {
      const [rows, options] = await Promise.all([
        getProbations(this.sessionParams),
        getProbationOptions(this.sessionParams)
      ]);
      this.applyOptions(options);
      this.applyRecords(rows);
    } catch (error) {
      this.loadError = reduceError(error);
      this.showToast("Error", this.loadError, "error");
    } finally {
      this.isLoading = false;
    }
  }

  async refreshRecords() {
    try {
      this.applyRecords(await getProbations(this.sessionParams));
    } catch (error) {
      this.showToast("Error", reduceError(error), "error");
    }
  }

  applyOptions(options) {
    this.employees = Array.isArray(options?.employees) ? options.employees : [];
    if (Number(options?.defaultProbationDays) > 0) {
      this.defaultProbationDays = Number(options.defaultProbationDays);
    }
    if (typeof options?.isAdmin === "boolean") {
      this.serverIsAdmin = options.isAdmin;
    }
  }

  applyRecords(rows) {
    this.records = (Array.isArray(rows) ? rows : []).map((row) =>
      this.toViewRow(row)
    );
    const ids = new Set(this.records.map((row) => row.id));
    const deletable = new Set(
      this.records.filter((row) => row.canDelete).map((row) => row.id)
    );
    this.selectedIds = this.selectedIds.filter((id) => deletable.has(id));
    if (this.activeRecordId && !ids.has(this.activeRecordId)) {
      this.closeDetails();
    }
    this.clampPage();
  }

  toViewRow(row) {
    const status = row.status || STATUS.PENDING;
    const isOpen = OPEN_STATUSES.includes(status);
    const remaining = isOpen ? describeRemaining(row.daysRemaining) : "";
    return {
      ...row,
      status,
      employeeName: row.employeeName || "Unassigned employee",
      designation: row.designation || "",
      department: row.department || "",
      reviewerName: row.reviewerName || "",
      notes: row.notes || "",
      avatarUrl: row.photoUrl || `${smarthrAssets}${EMPLOYEE_AVATAR_PATH}`,
      reviewerAvatarUrl:
        row.reviewerPhotoUrl || `${smarthrAssets}${REVIEWER_AVATAR_PATH}`,
      badgeClass:
        STATUS_BADGE_CLASSES[status] || STATUS_BADGE_CLASSES[STATUS.PENDING],
      startDateLabel: formatDate(row.startDate),
      endDateLabel: formatDate(row.endDate),
      originalEndDateLabel: formatDate(row.originalEndDate),
      joiningDateLabel: formatDate(row.dateOfJoining),
      confirmationDateLabel: formatDate(row.confirmationDate),
      remainingLabel: remaining,
      remainingClass:
        row.daysRemaining < 0
          ? "d-block fs-12 text-danger"
          : "d-block fs-12 text-muted",
      isOpen,
      canDelete: DELETABLE_STATUSES.includes(status),
      canStartReview: status === STATUS.PENDING
    };
  }

  // ---------------------------------------------------------------------------
  // Table view
  // ---------------------------------------------------------------------------

  get hasLoadError() {
    return !this.isLoading && !!this.loadError;
  }

  get isReady() {
    return !this.isLoading && !this.loadError;
  }

  /** Adding needs the employee list, so it waits for a successful load. */
  get addDisabled() {
    return !this.isReady;
  }

  get hasRecords() {
    return this.records.length > 0;
  }

  get showNoRecords() {
    return this.isReady && !this.hasRecords;
  }

  get showNoMatches() {
    return this.isReady && this.hasRecords && this.filteredCount === 0;
  }

  get showTable() {
    return this.isReady && this.filteredCount > 0;
  }

  get isExpanded() {
    return !this.isCollapsed;
  }

  get collapseIcon() {
    return this.isCollapsed ? "ti ti-chevrons-down" : "ti ti-chevrons-up";
  }

  get designationOptions() {
    const values = new Set();
    this.records.forEach((row) => {
      if (row.designation) values.add(row.designation);
    });
    return [...values].sort((a, b) => a.localeCompare(b));
  }

  get selectedDesignationLabel() {
    return this.selectedDesignation || "Designation";
  }

  get sortOptions() {
    return SORT_OPTIONS;
  }

  get currentSortLabel() {
    return (
      SORT_OPTIONS.find((option) => option.value === this.currentSort)?.label ||
      SORT_OPTIONS[0].label
    );
  }

  get filteredRecords() {
    let list = [...this.records];
    const query = (this.searchKeyword || "").toLowerCase().trim();
    if (query) {
      list = list.filter((row) =>
        [
          row.employeeName,
          row.probationNumber,
          row.designation,
          row.department,
          row.reviewerName,
          row.status
        ].some((value) => (value || "").toLowerCase().includes(query))
      );
    }
    if (this.selectedDesignation) {
      list = list.filter((row) => row.designation === this.selectedDesignation);
    }
    if (this.currentSort === "nameAsc") {
      list.sort((a, b) => a.employeeName.localeCompare(b.employeeName));
    } else if (this.currentSort === "nameDesc") {
      list.sort((a, b) => b.employeeName.localeCompare(a.employeeName));
    } else {
      list.sort((a, b) => {
        if (!a.endDate && !b.endDate) return 0;
        if (!a.endDate) return 1;
        if (!b.endDate) return -1;
        return a.endDate.localeCompare(b.endDate);
      });
    }
    return list;
  }

  get filteredCount() {
    return this.filteredRecords.length;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.filteredCount / PAGE_SIZE));
  }

  get displayedRecords() {
    const selected = new Set(this.selectedIds);
    const isAdmin = this.isAdmin;
    const start = (this.currentPage - 1) * PAGE_SIZE;
    return this.filteredRecords.slice(start, start + PAGE_SIZE).map((row) => {
      const selectable = isAdmin && row.canDelete;
      return {
        ...row,
        selected: selectable && selected.has(row.id),
        selectDisabled: !selectable,
        showDelete: selectable,
        showEdit: this.canEditRow(row)
      };
    });
  }

  /** Non-administrators never edit their own probation (the server agrees). */
  canEditRow(row) {
    if (!row?.isOpen) return false;
    return this.isAdmin || row.employeeId !== this.portalUserId;
  }

  get selectableRowsOnPage() {
    return this.displayedRecords.filter((row) => !row.selectDisabled);
  }

  get selectAllDisabled() {
    return this.selectableRowsOnPage.length === 0;
  }

  get pageStart() {
    return this.filteredCount === 0
      ? 0
      : (this.currentPage - 1) * PAGE_SIZE + 1;
  }

  get pageEnd() {
    return Math.min(this.currentPage * PAGE_SIZE, this.filteredCount);
  }

  get isFirstPage() {
    return this.currentPage <= 1;
  }

  get isLastPage() {
    return this.currentPage >= this.totalPages;
  }

  get prevButtonClass() {
    return `btn btn-white border${this.isFirstPage ? " disabled" : ""}`;
  }

  get nextButtonClass() {
    return `btn btn-white border${this.isLastPage ? " disabled" : ""}`;
  }

  get isAllSelected() {
    const list = this.selectableRowsOnPage;
    return list.length > 0 && list.every((row) => row.selected);
  }

  get selectedCount() {
    return this.selectedIds.length;
  }

  get showBulkDelete() {
    return this.isAdmin && this.selectedCount > 0;
  }

  clampPage() {
    if (this.currentPage > this.totalPages) {
      this.currentPage = this.totalPages;
    }
    if (this.currentPage < 1) {
      this.currentPage = 1;
    }
  }

  toggleCollapse() {
    this.isCollapsed = !this.isCollapsed;
  }

  toggleExportDropdown() {
    this.isExportOpen = !this.isExportOpen;
  }

  toggleDesigDropdown() {
    this.isDesigOpen = !this.isDesigOpen;
    this.isSortOpen = false;
  }

  toggleSortDropdown() {
    this.isSortOpen = !this.isSortOpen;
    this.isDesigOpen = false;
  }

  selectDesignation(event) {
    this.selectedDesignation = event.currentTarget.dataset.desig || "";
    this.isDesigOpen = false;
    this.currentPage = 1;
  }

  selectSort(event) {
    this.currentSort =
      event.currentTarget.dataset.sort || SORT_OPTIONS[0].value;
    this.isSortOpen = false;
    this.currentPage = 1;
  }

  handleSearch(event) {
    this.searchKeyword = event.target.value;
    this.currentPage = 1;
  }

  previousPage() {
    if (!this.isFirstPage) this.currentPage -= 1;
  }

  nextPage() {
    if (!this.isLastPage) this.currentPage += 1;
  }

  handleSelectAll(event) {
    const checked = event.target.checked;
    const selected = new Set(this.selectedIds);
    // Only rows an administrator can delete are selectable.
    this.selectableRowsOnPage.forEach((row) => {
      if (checked) {
        selected.add(row.id);
      } else {
        selected.delete(row.id);
      }
    });
    this.selectedIds = [...selected];
  }

  handleSelectRow(event) {
    const id = event.target.dataset.id;
    const row = this.records.find((item) => item.id === id);
    const selected = new Set(this.selectedIds);
    if (event.target.checked && this.isAdmin && row?.canDelete) {
      selected.add(id);
    } else {
      selected.delete(id);
    }
    this.selectedIds = [...selected];
  }

  // ---------------------------------------------------------------------------
  // Details
  // ---------------------------------------------------------------------------

  get activeRecord() {
    return this.records.find((row) => row.id === this.activeRecordId) || null;
  }

  get showStatusActions() {
    return this.isAdmin && !!this.activeRecord?.isOpen;
  }

  get activeCanEdit() {
    return this.canEditRow(this.activeRecord);
  }

  openDetails(event) {
    this.activeRecordId = event.currentTarget.dataset.id;
    this.isDetailsOpen = !!this.activeRecord;
  }

  closeDetails() {
    this.isDetailsOpen = false;
    this.activeRecordId = null;
  }

  // ---------------------------------------------------------------------------
  // Add
  // ---------------------------------------------------------------------------

  get employeesWithOpenProbation() {
    return new Set(
      this.records.filter((row) => row.isOpen).map((row) => row.employeeId)
    );
  }

  get addEmployeeOptions() {
    const busy = this.employeesWithOpenProbation;
    const self = this.isAdmin ? null : this.portalUserId;
    return this.employees
      .filter((employee) => !busy.has(employee.id) && employee.id !== self)
      .map((employee) => ({
        value: employee.id,
        label: employee.designation
          ? `${employee.name} - ${employee.designation}`
          : employee.name,
        selected: employee.id === this.addForm.employeeId
      }));
  }

  get noAddEmployeeOptions() {
    return this.addEmployeeOptions.length === 0;
  }

  get addReviewerOptions() {
    return this.reviewerOptionsFor(
      this.addForm.employeeId,
      this.addForm.reviewerId
    );
  }

  get addSelectedEmployee() {
    return (
      this.employees.find(
        (employee) => employee.id === this.addForm.employeeId
      ) || null
    );
  }

  get addEmployeeDepartment() {
    return this.addSelectedEmployee?.department || "";
  }

  get addEmployeeJoiningLabel() {
    return formatDate(this.addSelectedEmployee?.dateOfJoining);
  }

  get addReviewerHint() {
    const employee = this.addSelectedEmployee;
    if (!employee) return "";
    return employee.reportsToId &&
      employee.reportsToId === this.addForm.reviewerId
      ? "Defaults to the employee's reporting manager."
      : "";
  }

  reviewerOptionsFor(employeeId, reviewerId) {
    return this.employees
      .filter((employee) => employee.id !== employeeId)
      .map((employee) => ({
        value: employee.id,
        label: employee.name,
        selected: employee.id === reviewerId
      }));
  }

  openAddModal() {
    this.addForm = emptyAddForm();
    this.isAddModalOpen = true;
  }

  closeAddModal() {
    if (this.isSaving) return;
    this.isAddModalOpen = false;
  }

  handleAddEmployeeChange(event) {
    const employeeId = event.target.value;
    const employee = this.employees.find((item) => item.id === employeeId);
    const startDate = employee?.dateOfJoining || toIsoDate(new Date());
    const managerIsReviewer =
      employee?.reportsToId &&
      employee.reportsToId !== employeeId &&
      this.employees.some((item) => item.id === employee.reportsToId);
    this.addForm = {
      ...this.addForm,
      employeeId,
      startDate: employee ? startDate : "",
      endDate: employee ? addDays(startDate, this.defaultProbationDays) : "",
      reviewerId: managerIsReviewer ? employee.reportsToId : "",
      endDateTouched: false
    };
  }

  handleAddFormChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.value;
    const next = { ...this.addForm, [field]: value };
    if (field === "endDate") {
      next.endDateTouched = true;
    }
    if (field === "startDate" && !this.addForm.endDateTouched && value) {
      next.endDate = addDays(value, this.defaultProbationDays);
    }
    this.addForm = next;
  }

  async saveNewProbation() {
    const form = this.addForm;
    const problem = this.validateForm(form, true);
    if (problem) {
      this.showToast("Check the form", problem, "error");
      return;
    }
    const saved = await this.persist({
      probationId: null,
      employeeId: form.employeeId,
      startDate: form.startDate,
      endDate: form.endDate,
      reviewerId: form.reviewerId || null,
      notes: form.notes || null,
      recordVersion: null
    });
    if (saved) {
      this.isAddModalOpen = false;
      this.showToast(
        "Probation added",
        `${saved.probationNumber || "Probation"} created for ${saved.employeeName || "the employee"}.`,
        "success"
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Edit
  // ---------------------------------------------------------------------------

  get editReviewerOptions() {
    return this.reviewerOptionsFor(
      this.editForm.employeeId,
      this.editForm.reviewerId
    );
  }

  get editReplacesNotes() {
    return !!this.editForm.replaceNotes;
  }

  get editExistingNotes() {
    return this.editForm.original?.notes || "";
  }

  get editReviewerMissing() {
    // Keep an inactive current reviewer visible until it is changed.
    const { reviewerId } = this.editForm;
    return (
      !!reviewerId &&
      !this.employees.some((employee) => employee.id === reviewerId)
    );
  }

  openEditModal(event) {
    const id = event.currentTarget.dataset.id;
    const row = this.records.find((item) => item.id === id);
    if (!row) return;
    if (!row.isOpen) {
      this.showToast(
        "Not editable",
        `${row.status} probations can no longer be edited.`,
        "warning"
      );
      return;
    }
    if (!this.canEditRow(row)) {
      this.showToast(
        "Not editable",
        "You cannot manage your own probation. Ask an HR administrator.",
        "warning"
      );
      return;
    }
    const original = {
      startDate: row.startDate || "",
      endDate: row.endDate || "",
      reviewerId: row.reviewerId || "",
      notes: row.notes || ""
    };
    this.editForm = {
      ...original,
      original,
      id: row.id,
      probationNumber: row.probationNumber,
      recordVersion: row.recordVersion || null,
      employeeId: row.employeeId,
      employeeName: row.employeeName,
      reviewerName: row.reviewerName,
      // Administrators rewrite the notes; everyone else adds a dated entry.
      replaceNotes: this.isAdmin,
      newNote: ""
    };
    this.isDetailsOpen = false;
    this.isEditModalOpen = true;
    this.pendingNotesPrefill = this.editForm.replaceNotes;
  }

  closeEditModal() {
    if (this.isSaving) return;
    this.isEditModalOpen = false;
  }

  handleEditFormChange(event) {
    const field = event.target.dataset.field;
    this.editForm = { ...this.editForm, [field]: event.target.value };
  }

  /**
   * Only the values the user changed are sent (null means "leave as is"), and
   * the version loaded with the row lets the server reject the save when
   * someone else changed the probation in the meantime.
   */
  buildEditChanges(form) {
    const original = form.original || {};
    let notes = null;
    if (form.replaceNotes) {
      notes = form.notes !== original.notes ? form.notes || "" : null;
    } else if ((form.newNote || "").trim()) {
      notes = form.newNote;
    }
    return {
      startDate: form.startDate !== original.startDate ? form.startDate : null,
      endDate: form.endDate !== original.endDate ? form.endDate : null,
      reviewerChanged: (form.reviewerId || "") !== (original.reviewerId || ""),
      notes
    };
  }

  async saveEditProbation() {
    const form = this.editForm;
    const problem = this.validateForm(form, false);
    if (problem) {
      this.showToast("Check the form", problem, "error");
      return;
    }
    const changes = this.buildEditChanges(form);
    if (
      !changes.startDate &&
      !changes.endDate &&
      !changes.reviewerChanged &&
      changes.notes === null
    ) {
      this.isEditModalOpen = false;
      this.showToast("No changes", "There was nothing to save.", "info");
      return;
    }
    const saved = await this.persist({
      probationId: form.id,
      employeeId: form.employeeId,
      startDate: changes.startDate,
      endDate: changes.endDate,
      reviewerId: form.reviewerId || null,
      notes: changes.notes,
      recordVersion: form.recordVersion
    });
    if (saved) {
      this.isEditModalOpen = false;
      this.showToast(
        "Probation updated",
        `${saved.probationNumber || "Probation"} was saved.`,
        "success"
      );
      return;
    }
    // Reload so the latest values are shown; if the probation changed since
    // the form opened, close it so the user reopens it on current data.
    await this.refreshRecords();
    const latest = this.records.find((row) => row.id === form.id);
    if (!latest || latest.recordVersion !== form.recordVersion) {
      this.isEditModalOpen = false;
    }
  }

  validateForm(form, requireEmployee) {
    if (requireEmployee && !form.employeeId) {
      return "Select an employee.";
    }
    if (!form.startDate || !form.endDate) {
      return "Probation start and end dates are required.";
    }
    if (form.endDate < form.startDate) {
      return "The probation end date cannot be before the start date.";
    }
    if (form.reviewerId && form.reviewerId === form.employeeId) {
      return "An employee cannot review their own probation.";
    }
    return null;
  }

  async persist(values) {
    this.isSaving = true;
    try {
      const saved = await saveProbation({ ...values, ...this.sessionParams });
      await this.refreshRecords();
      return saved || {};
    } catch (error) {
      this.showToast("Unable to save", reduceError(error), "error");
      return null;
    } finally {
      this.isSaving = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Status decisions (administrators)
  // ---------------------------------------------------------------------------

  get statusNeedsEndDate() {
    return !!this.statusForm.needsEndDate;
  }

  get statusMinEndDate() {
    return this.statusForm.currentEndDate
      ? addDays(this.statusForm.currentEndDate, 1)
      : "";
  }

  openStatusModal(event) {
    const action = STATUS_ACTIONS[event.currentTarget.dataset.action];
    const row = this.activeRecord;
    if (!action || !row || !this.isAdmin) return;
    this.statusForm = {
      ...action,
      id: row.id,
      employeeName: row.employeeName,
      probationNumber: row.probationNumber,
      currentEndDate: row.endDate,
      currentEndDateLabel: row.endDateLabel,
      newEndDate: action.needsEndDate
        ? addDays(row.endDate || toIsoDate(new Date()), 30)
        : "",
      notes: ""
    };
    // The details panel sits above modals; close it while deciding.
    this.isDetailsOpen = false;
    this.isStatusModalOpen = true;
  }

  closeStatusModal() {
    if (this.isSaving) return;
    this.isStatusModalOpen = false;
  }

  handleStatusFormChange(event) {
    const field = event.target.dataset.field;
    this.statusForm = { ...this.statusForm, [field]: event.target.value };
  }

  async confirmStatusChange() {
    const form = this.statusForm;
    if (form.needsEndDate) {
      if (!form.newEndDate) {
        this.showToast(
          "Check the form",
          "Enter the new end date to extend the probation.",
          "error"
        );
        return;
      }
      if (form.currentEndDate && form.newEndDate <= form.currentEndDate) {
        this.showToast(
          "Check the form",
          "The new end date must be later than the current end date.",
          "error"
        );
        return;
      }
    }
    this.isSaving = true;
    try {
      const saved = await updateProbationStatus({
        probationId: form.id,
        newStatus: form.status,
        newEndDate: form.needsEndDate ? form.newEndDate : null,
        notes: form.notes || null,
        ...this.sessionParams
      });
      this.isStatusModalOpen = false;
      this.showToast(
        "Probation updated",
        `${form.probationNumber || "Probation"} is now ${saved?.status || form.status}.`,
        "success"
      );
      await this.refreshRecords();
    } catch (error) {
      this.showToast("Unable to update status", reduceError(error), "error");
    } finally {
      this.isSaving = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Delete (administrators)
  // ---------------------------------------------------------------------------

  get deleteMessage() {
    const count = this.deletingIds.length;
    return count === 1
      ? "You want to delete this probation record. This can't be undone."
      : `You want to delete ${count} probation records. This can't be undone.`;
  }

  openDeleteModal(event) {
    if (!this.isAdmin) return;
    this.deletingIds = [event.currentTarget.dataset.id];
    this.isDeleteModalOpen = true;
  }

  openBulkDeleteModal() {
    if (!this.isAdmin) return;
    const deletable = new Set(
      this.records.filter((row) => row.canDelete).map((row) => row.id)
    );
    const ids = this.selectedIds.filter((id) => deletable.has(id));
    if (ids.length === 0) return;
    this.deletingIds = ids;
    this.isDeleteModalOpen = true;
  }

  closeDeleteModal() {
    if (this.isSaving) return;
    this.isDeleteModalOpen = false;
    this.deletingIds = [];
  }

  async confirmDelete() {
    const ids = [...this.deletingIds];
    if (ids.length === 0) return;
    this.isSaving = true;
    try {
      const deleted = await deleteProbations({
        probationIds: ids,
        ...this.sessionParams
      });
      const removed = new Set(ids);
      this.selectedIds = this.selectedIds.filter((id) => !removed.has(id));
      this.isDeleteModalOpen = false;
      this.deletingIds = [];
      const count = Number(deleted) || ids.length;
      this.showToast(
        "Deleted",
        `${count} probation record${count === 1 ? "" : "s"} deleted.`,
        "success"
      );
      await this.refreshRecords();
    } catch (error) {
      this.showToast("Unable to delete", reduceError(error), "error");
    } finally {
      this.isSaving = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  exportPDF() {
    this.isExportOpen = false;
    window.print();
  }

  exportExcel() {
    this.isExportOpen = false;
    const rows = this.filteredRecords;
    if (rows.length === 0) {
      this.showToast(
        "Nothing to export",
        "No probation records to export.",
        "info"
      );
      return;
    }
    downloadCsv(
      `probations-${toIsoDate(new Date())}.csv`,
      [
        "Probation ID",
        "Employee",
        "Designation",
        "Department",
        "Date of Joining",
        "Start Date",
        "End Date",
        "Original End Date",
        "Reviewer",
        "Status",
        "Confirmation Date",
        "Days Remaining",
        "Notes"
      ],
      rows.map((row) => [
        row.probationNumber,
        row.employeeName,
        row.designation,
        row.department,
        row.dateOfJoining || "",
        row.startDate || "",
        row.endDate || "",
        row.originalEndDate || "",
        row.reviewerName,
        row.status,
        row.confirmationDate || "",
        row.daysRemaining ?? "",
        row.notes
      ])
    );
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}