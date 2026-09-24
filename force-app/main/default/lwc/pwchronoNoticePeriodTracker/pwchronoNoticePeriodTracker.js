import { LightningElement } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin } from "lightning/navigation";
import getNoticeRecords from "@salesforce/apex/PWChrono_NoticePeriodController.getNoticeRecords";
import getNoticeOptions from "@salesforce/apex/PWChrono_NoticePeriodController.getNoticeOptions";
import saveNotice from "@salesforce/apex/PWChrono_NoticePeriodController.saveNotice";
import withdrawNotices from "@salesforce/apex/PWChrono_NoticePeriodController.withdrawNotices";
import { getSession, getSessionToken } from "c/pwchronoSession";
import { downloadCsv } from "c/pwchronoCsv";
import {
  ADMIN_ROLES,
  BADGE_CLASSES,
  CSV_HEADERS,
  DEFAULT_NOTICE_DAYS,
  PAGE_SIZE,
  REASON_MAX_LENGTH,
  SORT_OPTIONS
} from "./pwchronoNoticeConstants";

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

function pad(value) {
  return String(value).padStart(2, "0");
}

function toIsoDate(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function parseIsoDate(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value || "");
  return match
    ? new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
    : null;
}

function todayIso() {
  return toIsoDate(new Date());
}

function addDaysIso(value, days) {
  const date = parseIsoDate(value);
  if (!date) {
    return "";
  }
  date.setDate(date.getDate() + days);
  return toIsoDate(date);
}

function formatDate(value) {
  const date = parseIsoDate(value);
  return date
    ? `${pad(date.getDate())} ${MONTHS[date.getMonth()]} ${date.getFullYear()}`
    : "-";
}

function numberLabel(value) {
  return value === null || value === undefined ? "-" : String(value);
}

function initialsOf(name) {
  return (
    String(name || "")
      .split(/\s+/)
      .filter(Boolean)
      .slice(0, 2)
      .map((part) => part.charAt(0).toUpperCase())
      .join("") || "?"
  );
}

function reduceError(error, fallback) {
  const body = error?.body;
  if (Array.isArray(body)) {
    const text = body
      .map((item) => item?.message)
      .filter(Boolean)
      .join("; ");
    return text || fallback;
  }
  return (
    body?.message ||
    body?.pageErrors?.[0]?.message ||
    error?.message ||
    fallback
  );
}

// Nulls always sort last, whatever the direction.
function compareNullable(a, b, direction) {
  const aMissing = a === null || a === undefined || a === "";
  const bMissing = b === null || b === undefined || b === "";
  if (aMissing || bMissing) {
    return Number(aMissing) - Number(bMissing);
  }
  if (a === b) {
    return 0;
  }
  return (a < b ? -1 : 1) * direction;
}

const byName = (a, b) => a.employeeName.localeCompare(b.employeeName);

const isFinished = (record) => record.noticeStatus === "Completed";

// Current notices first, soonest last working day first; finished notices
// after them, most recent last working day first. Old history therefore never
// pushes the notices people are still serving off the first page.
function byLastWorkingDay(a, b) {
  const aFinished = isFinished(a);
  const group = Number(aFinished) - Number(isFinished(b));
  if (group !== 0) {
    return group;
  }
  return (
    compareNullable(a.endDate, b.endDate, aFinished ? -1 : 1) ||
    compareNullable(a.startDate, b.startDate, aFinished ? -1 : 1) ||
    byName(a, b)
  );
}

const SORTERS = {
  lastWorkingDay: byLastWorkingDay,
  startDesc: (a, b) =>
    compareNullable(a.startDate, b.startDate, -1) || byName(a, b),
  progressDesc: (a, b) =>
    compareNullable(a.progress, b.progress, -1) ||
    compareNullable(a.endDate, b.endDate, 1) ||
    byName(a, b),
  nameAsc: (a, b) => byName(a, b),
  nameDesc: (a, b) => byName(b, a)
};

export default class PwchronoNoticePeriodTracker extends NavigationMixin(
  LightningElement
) {
  portalUserId = null;
  sessionToken = null;
  role = "";

  records = [];
  isLoading = true;
  loadError = null;
  isSaving = false;

  searchKeyword = "";
  selectedDesignation = "";
  currentSort = "lastWorkingDay";
  currentPage = 1;
  selectedIds = [];

  isExportOpen = false;
  isDesigOpen = false;
  isSortOpen = false;
  isCollapsed = false;

  isDetailsOpen = false;
  isAddModalOpen = false;
  isEditModalOpen = false;
  isWithdrawModalOpen = false;

  activeRecord = null;
  withdrawIds = [];

  addForm = {};
  endDateTouched = false;
  employeeOptions = [];
  isOptionsLoading = false;
  optionsError = null;

  editForm = {};
  pendingReason = null;

  connectedCallback() {
    this.readSession();
    this.loadRecords();
  }

  // A textarea's content is a DOM property, not an attribute, so the edit
  // modal's reason is written once the freshly rendered field exists.
  renderedCallback() {
    if (this.pendingReason === null) {
      return;
    }
    const area = this.template.querySelector('textarea[data-field="reason"]');
    if (area) {
      area.value = this.pendingReason;
      this.pendingReason = null;
    }
  }

  readSession() {
    const session = getSession() || {};
    const user = session.user || {};
    this.portalUserId = user.Id || session.portalUserId || null;
    this.role = user.Role__c || user.role || session.role || "";
    this.sessionToken = getSessionToken();
  }

  get sessionParams() {
    return {
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    };
  }

  get isAdmin() {
    return ADMIN_ROLES.includes(this.role);
  }

  // ─── Data ──────────────────────────────────────────────────────────────

  async loadRecords() {
    this.isLoading = true;
    this.loadError = null;
    try {
      const data = await getNoticeRecords(this.sessionParams);
      this.records = (data || []).map((record) => this.decorate(record));
      // Keep only selections that can still be withdrawn: a row completed
      // elsewhere in the meantime is disabled and could not be unticked.
      const withdrawable = new Set(
        this.records
          .filter((record) => record.canWithdraw)
          .map((record) => record.id)
      );
      this.selectedIds = this.selectedIds.filter((id) => withdrawable.has(id));
      // Refresh the details panel only when it is on screen.
      if (this.isDetailsOpen && this.activeRecord) {
        this.activeRecord = this.findRecord(this.activeRecord.id);
        this.isDetailsOpen = Boolean(this.activeRecord);
      } else {
        this.activeRecord = null;
      }
    } catch (error) {
      this.records = [];
      this.loadError = reduceError(
        error,
        "Notice periods could not be loaded."
      );
      this.showToast("Error", this.loadError, "error");
    } finally {
      this.isLoading = false;
    }
  }

  decorate(record) {
    const progress = Math.min(
      100,
      Math.max(0, Number(record.progressPercent) || 0)
    );
    const employeeName = record.employeeName || "Unknown employee";
    const isOpen = record.isOpen === true;
    return {
      ...record,
      employeeName,
      initials: initialsOf(employeeName),
      hasPhoto: Boolean(record.photoUrl),
      designationLabel: record.designation || "-",
      departmentLabel: record.department || "-",
      startDateLabel: formatDate(record.startDate),
      endDateLabel: formatDate(record.endDate),
      totalDaysLabel: numberLabel(record.totalDays),
      completedDaysLabel: numberLabel(record.completedDays),
      remainingDaysLabel: numberLabel(record.remainingDays),
      reasonLabel: record.reason || "Not recorded",
      separationStatusLabel: record.separationStatus || "-",
      noticeStatus: record.noticeStatus || "Active",
      badgeClass: BADGE_CLASSES[record.noticeStatus] || BADGE_CLASSES.Active,
      progress,
      progressLabel: `${progress}%`,
      progressStyle: `width: ${progress}%;`,
      canEdit: isOpen,
      canWithdraw: isOpen && this.isAdmin,
      selectDisabled: !isOpen,
      searchText: [
        employeeName,
        record.recordNumber,
        record.designation,
        record.department
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase()
    };
  }

  // ─── Derived view state ────────────────────────────────────────────────

  get hasRecords() {
    return this.records.length > 0;
  }

  // Refreshes after a save keep the table on screen; only the first load
  // (or a reload with nothing to show) replaces it with the loading state.
  get showLoading() {
    return this.isLoading && !this.hasRecords;
  }

  get showEmptyState() {
    return !this.isLoading && !this.loadError && !this.hasRecords;
  }

  get isExpanded() {
    return !this.isCollapsed;
  }

  get collapseIcon() {
    return this.isCollapsed ? "ti ti-chevrons-down" : "ti ti-chevrons-up";
  }

  get designationOptions() {
    const names = new Set(
      this.records.map((record) => record.designation).filter(Boolean)
    );
    return [...names].sort((a, b) => a.localeCompare(b));
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
    const query = (this.searchKeyword || "").trim().toLowerCase();
    let list = this.records;
    if (query) {
      list = list.filter((record) => record.searchText.includes(query));
    }
    if (this.selectedDesignation) {
      list = list.filter(
        (record) => record.designation === this.selectedDesignation
      );
    }
    return [...list].sort(SORTERS[this.currentSort] || byLastWorkingDay);
  }

  get filteredCount() {
    return this.filteredRecords.length;
  }

  get hasFilteredRecords() {
    return this.filteredCount > 0;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.filteredCount / PAGE_SIZE));
  }

  get pageNumber() {
    return Math.min(Math.max(1, this.currentPage), this.totalPages);
  }

  get displayedRecords() {
    const start = (this.pageNumber - 1) * PAGE_SIZE;
    const selected = new Set(this.selectedIds);
    return this.filteredRecords
      .slice(start, start + PAGE_SIZE)
      .map((record) => ({ ...record, selected: selected.has(record.id) }));
  }

  get pageStart() {
    return this.filteredCount === 0 ? 0 : (this.pageNumber - 1) * PAGE_SIZE + 1;
  }

  get pageEnd() {
    return Math.min(this.pageNumber * PAGE_SIZE, this.filteredCount);
  }

  get isFirstPage() {
    return this.pageNumber <= 1;
  }

  get isLastPage() {
    return this.pageNumber >= this.totalPages;
  }

  get selectableOnPage() {
    return this.displayedRecords.filter((record) => record.canWithdraw);
  }

  get isAllSelected() {
    const selectable = this.selectableOnPage;
    return selectable.length > 0 && selectable.every((row) => row.selected);
  }

  get isSelectAllDisabled() {
    return this.selectableOnPage.length === 0;
  }

  get selectedCount() {
    return this.selectedIds.length;
  }

  get showBulkWithdraw() {
    return this.isAdmin && this.selectedCount > 0;
  }

  get tableColumnCount() {
    return this.isAdmin ? 11 : 10;
  }

  // ─── Toolbar ───────────────────────────────────────────────────────────

  toggleCollapse() {
    this.isCollapsed = !this.isCollapsed;
  }

  toggleExportDropdown() {
    this.isExportOpen = !this.isExportOpen;
    this.isDesigOpen = false;
    this.isSortOpen = false;
  }

  toggleDesigDropdown() {
    this.isDesigOpen = !this.isDesigOpen;
    this.isExportOpen = false;
    this.isSortOpen = false;
  }

  toggleSortDropdown() {
    this.isSortOpen = !this.isSortOpen;
    this.isExportOpen = false;
    this.isDesigOpen = false;
  }

  selectDesignation(event) {
    this.selectedDesignation = event.currentTarget.dataset.desig || "";
    this.isDesigOpen = false;
    this.currentPage = 1;
  }

  selectSort(event) {
    this.currentSort = event.currentTarget.dataset.sort;
    this.isSortOpen = false;
    this.currentPage = 1;
  }

  handleSearch(event) {
    this.searchKeyword = event.target.value;
    this.currentPage = 1;
  }

  clearFilters() {
    this.searchKeyword = "";
    this.selectedDesignation = "";
    this.currentPage = 1;
  }

  handlePreviousPage() {
    if (!this.isFirstPage) {
      this.currentPage = this.pageNumber - 1;
    }
  }

  handleNextPage() {
    if (!this.isLastPage) {
      this.currentPage = this.pageNumber + 1;
    }
  }

  handleRetry() {
    this.loadRecords();
  }

  handleImageError(event) {
    const id = event.target.dataset.id;
    this.records = this.records.map((record) => {
      return record.id === id ? { ...record, hasPhoto: false } : record;
    });
    if (this.activeRecord?.id === id) {
      this.activeRecord = { ...this.activeRecord, hasPhoto: false };
    }
  }

  goToSeparations() {
    this[NavigationMixin.Navigate]({
      type: "comm__namedPage",
      attributes: { name: "Separations__c" }
    });
  }

  // ─── Selection ─────────────────────────────────────────────────────────

  handleSelectAll(event) {
    const pageIds = this.selectableOnPage.map((record) => record.id);
    const current = new Set(this.selectedIds);
    const checked = event.target.checked;
    pageIds.forEach((id) => {
      if (checked) {
        current.add(id);
      } else {
        current.delete(id);
      }
    });
    this.selectedIds = [...current];
  }

  handleSelectRow(event) {
    const id = event.target.dataset.id;
    const current = new Set(this.selectedIds);
    if (event.target.checked) {
      current.add(id);
    } else {
      current.delete(id);
    }
    this.selectedIds = [...current];
  }

  // ─── Details ───────────────────────────────────────────────────────────

  findRecord(id) {
    return this.records.find((record) => record.id === id) || null;
  }

  openDetails(event) {
    const record = this.findRecord(event.currentTarget.dataset.id);
    if (record) {
      this.activeRecord = record;
      this.isDetailsOpen = true;
    }
  }

  closeDetails() {
    this.isDetailsOpen = false;
    this.activeRecord = null;
  }

  // ─── Add notice ────────────────────────────────────────────────────────

  get employeeSelectOptions() {
    return this.employeeOptions.map((option) => ({
      value: option.id,
      label: option.designation
        ? `${option.name} - ${option.designation}`
        : option.name,
      selected: option.id === this.addForm.employeeId
    }));
  }

  get hasEmployeeOptions() {
    return this.employeeOptions.length > 0;
  }

  get showNoEmployeeOptions() {
    return (
      !this.isOptionsLoading && !this.optionsError && !this.hasEmployeeOptions
    );
  }

  get isAddSaveDisabled() {
    return this.isSaving || this.isOptionsLoading || !this.hasEmployeeOptions;
  }

  get selectedEmployeeOption() {
    return (
      this.employeeOptions.find(
        (option) => option.id === this.addForm.employeeId
      ) || null
    );
  }

  get reasonMaxLength() {
    return REASON_MAX_LENGTH;
  }

  async openAddModal() {
    const start = todayIso();
    this.addForm = {
      employeeId: "",
      startDate: start,
      endDate: addDaysIso(start, DEFAULT_NOTICE_DAYS),
      reason: ""
    };
    this.endDateTouched = false;
    this.isAddModalOpen = true;
    await this.loadEmployeeOptions();
  }

  async loadEmployeeOptions() {
    this.isOptionsLoading = true;
    this.optionsError = null;
    try {
      this.employeeOptions = (await getNoticeOptions(this.sessionParams)) || [];
    } catch (error) {
      this.employeeOptions = [];
      this.optionsError = reduceError(error, "Employees could not be loaded.");
      this.showToast("Error", this.optionsError, "error");
    } finally {
      this.isOptionsLoading = false;
    }
  }

  closeAddModal() {
    if (!this.isSaving) {
      this.isAddModalOpen = false;
    }
  }

  handleAddFormChange(event) {
    const field = event.target.dataset.field;
    const value = event.target.value;
    const next = { ...this.addForm, [field]: value };
    if (field === "endDate") {
      this.endDateTouched = true;
    }
    if (field === "startDate" && !this.endDateTouched && value) {
      next.endDate = addDaysIso(value, DEFAULT_NOTICE_DAYS);
    }
    this.addForm = next;
  }

  async saveNewNotice() {
    const form = this.addForm;
    const problem = !form.employeeId
      ? "Select the employee who is serving notice."
      : this.validateNoticeForm(form);
    if (problem) {
      this.showToast("Check the form", problem, "error");
      return;
    }
    const saved = await this.persist(
      {
        noticeId: null,
        employeeId: form.employeeId,
        startDate: form.startDate,
        endDate: form.endDate,
        reason: (form.reason || "").trim() || null
      },
      "Notice recorded. A pending separation was started for the employee."
    );
    if (saved) {
      this.isAddModalOpen = false;
    }
  }

  // ─── Edit notice ───────────────────────────────────────────────────────

  openEditModal(event) {
    const record = this.findRecord(event.currentTarget.dataset.id);
    if (!record) {
      return;
    }
    if (!record.canEdit) {
      this.showToast(
        "Not editable",
        `${record.recordNumber} is ${String(record.separationStatus).toLowerCase()} and can no longer be edited.`,
        "warning"
      );
      return;
    }
    this.editForm = {
      id: record.id,
      employeeId: record.employeeId,
      employeeName: record.employeeName,
      recordNumber: record.recordNumber,
      startDate: record.startDate || "",
      endDate: record.endDate || "",
      reason: record.reason || ""
    };
    this.pendingReason = this.editForm.reason;
    this.closeDetails();
    this.isEditModalOpen = true;
  }

  closeEditModal() {
    if (!this.isSaving) {
      this.isEditModalOpen = false;
    }
  }

  handleEditFormChange(event) {
    const field = event.target.dataset.field;
    this.editForm = { ...this.editForm, [field]: event.target.value };
  }

  async saveEditNotice() {
    const form = this.editForm;
    const problem = this.validateNoticeForm(form);
    if (problem) {
      this.showToast("Check the form", problem, "error");
      return;
    }
    const saved = await this.persist(
      {
        noticeId: form.id,
        employeeId: form.employeeId || null,
        startDate: form.startDate,
        endDate: form.endDate,
        reason: (form.reason || "").trim() || null
      },
      "Notice period updated."
    );
    if (saved) {
      this.isEditModalOpen = false;
    }
  }

  validateNoticeForm(form) {
    if (!form.startDate || !form.endDate) {
      return "Enter both the notice start date and the last working day.";
    }
    if (form.endDate < form.startDate) {
      return "The last working day cannot be before the notice start date.";
    }
    if ((form.reason || "").trim().length > REASON_MAX_LENGTH) {
      return `The reason must be ${REASON_MAX_LENGTH} characters or fewer.`;
    }
    return null;
  }

  async persist(params, successMessage) {
    this.isSaving = true;
    try {
      await saveNotice({ ...params, ...this.sessionParams });
      this.showToast("Saved", successMessage, "success");
      await this.loadRecords();
      return true;
    } catch (error) {
      this.showToast(
        "Could not save",
        reduceError(error, "The notice could not be saved."),
        "error"
      );
      return false;
    } finally {
      this.isSaving = false;
    }
  }

  // ─── Withdraw (administrators) ─────────────────────────────────────────

  get withdrawSummary() {
    if (this.withdrawIds.length === 1) {
      const record = this.findRecord(this.withdrawIds[0]);
      return record
        ? `${record.employeeName} (${record.recordNumber})`
        : "this notice";
    }
    return `${this.withdrawIds.length} selected notices`;
  }

  get withdrawButtonLabel() {
    return this.isSaving ? "Withdrawing..." : "Yes, withdraw";
  }

  openWithdrawModal(event) {
    const record = this.findRecord(event.currentTarget.dataset.id);
    if (!record || !record.canWithdraw) {
      return;
    }
    this.withdrawIds = [record.id];
    this.closeDetails();
    this.isWithdrawModalOpen = true;
  }

  openBulkWithdraw() {
    if (!this.isAdmin || this.selectedIds.length === 0) {
      return;
    }
    this.withdrawIds = [...this.selectedIds];
    this.isWithdrawModalOpen = true;
  }

  closeWithdrawModal() {
    if (!this.isSaving) {
      this.isWithdrawModalOpen = false;
      this.withdrawIds = [];
    }
  }

  async confirmWithdraw() {
    if (!this.isAdmin || this.withdrawIds.length === 0) {
      return;
    }
    this.isSaving = true;
    try {
      const count = await withdrawNotices({
        noticeIds: this.withdrawIds,
        ...this.sessionParams
      });
      const withdrawn = new Set(this.withdrawIds);
      this.selectedIds = this.selectedIds.filter((id) => !withdrawn.has(id));
      this.isWithdrawModalOpen = false;
      this.withdrawIds = [];
      this.showToast(
        "Notice withdrawn",
        count === 1
          ? "1 notice was withdrawn and its separation cancelled."
          : `${count || 0} notices were withdrawn and their separations cancelled.`,
        "success"
      );
      await this.loadRecords();
    } catch (error) {
      this.showToast(
        "Could not withdraw",
        reduceError(error, "The notice could not be withdrawn."),
        "error"
      );
    } finally {
      this.isSaving = false;
    }
  }

  // ─── Export ────────────────────────────────────────────────────────────

  exportPDF() {
    this.isExportOpen = false;
    window.print();
  }

  exportExcel() {
    this.isExportOpen = false;
    const rows = this.filteredRecords.map((record) => [
      record.recordNumber,
      record.employeeName,
      record.designation || "",
      record.department || "",
      record.startDate || "",
      record.endDate || "",
      record.totalDays ?? "",
      record.completedDays ?? "",
      record.remainingDays ?? "",
      record.progress,
      record.noticeStatus,
      record.separationStatus || "",
      record.reason || ""
    ]);
    if (rows.length === 0) {
      this.showToast(
        "Nothing to export",
        "No notice periods match the current filters.",
        "info"
      );
      return;
    }
    downloadCsv(`notice-period-tracker-${todayIso()}.csv`, CSV_HEADERS, rows);
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}