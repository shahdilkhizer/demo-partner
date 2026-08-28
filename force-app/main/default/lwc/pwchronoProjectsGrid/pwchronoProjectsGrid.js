import { refreshApex } from "@salesforce/apex";
import deleteProjectController from "@salesforce/apex/PWChrono_AdminController.deleteProject";
import getProjectClients from "@salesforce/apex/PWChrono_AdminController.getProjectClients";
import getProjects from "@salesforce/apex/PWChrono_AdminController.getProjects";
import saveProject from "@salesforce/apex/PWChrono_AdminController.saveProject";
import uploadProjectLogo from "@salesforce/apex/PWChrono_AdminController.uploadProjectLogo";
import { logError } from "c/pwchronoErrorHandler";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, wire } from "lwc";

export default class PwchronoProjectsGrid extends LightningElement {
  @track projects = [];
  @track isLoading = true;
  @track showProjectModal = false;
  @track modalTitle = "Add Project";
  @track currentProject = {};
  @track isListView = false;
  @track showExportDropdown = false;
  @track showFilterDropdown = false;
  @track showSortDropdown = false;
  @track selectedStatusFilter = "All";
  @track selectedSort = "Recent";
  @track showDeleteModal = false;
  @track projectIdPendingDelete = null;

  @track clientOptions = [];
  @track clientsLoading = true;

  portalUserId = getEmployeeId();
  sessionToken = getSessionToken();

  @track openActionMenuForId = null;
  sessionChangedHandler;
  documentClickHandler;

  get isGridView() {
    return !this.isListView;
  }

  get projectsWithMenuState() {
    const openId = this.openActionMenuForId;
    const base = Array.isArray(this.projects) ? [...this.projects] : [];

    // Filter
    const filter = this.selectedStatusFilter;
    const filtered =
      filter && filter !== "All"
        ? base.filter((p) => String(p?.status) === String(filter))
        : base;

    // Sort
    const sort = this.selectedSort;
    if (sort === "Name A-Z") {
      filtered.sort((a, b) =>
        String(a?.name || "").localeCompare(String(b?.name || ""))
      );
    } else if (sort === "Name Z-A") {
      filtered.sort((a, b) =>
        String(b?.name || "").localeCompare(String(a?.name || ""))
      );
    } else if (sort === "Deadline ↑") {
      filtered.sort((a, b) => {
        const da = a?.rawEndDate
          ? new Date(a.rawEndDate).getTime()
          : Number.MAX_SAFE_INTEGER;
        const db = b?.rawEndDate
          ? new Date(b.rawEndDate).getTime()
          : Number.MAX_SAFE_INTEGER;
        return da - db;
      });
    } else if (sort === "Deadline ↓") {
      filtered.sort((a, b) => {
        const da = a?.rawEndDate ? new Date(a.rawEndDate).getTime() : 0;
        const db = b?.rawEndDate ? new Date(b.rawEndDate).getTime() : 0;
        return db - da;
      });
    }

    return filtered.map((p) => ({
      ...p,
      isMenuOpen: Boolean(openId) && p.id === openId,
      showProjectLogo: Boolean(p?.logoUrl) && !p?.logoErrored
    }));
  }

  handleProjectLogoError(event) {
    const id = event?.target?.dataset?.id;
    if (!id) return;
    this.projects = (this.projects || []).map((p) => {
      return p?.id === id ? { ...p, logoErrored: true } : p;
    });
  }

  // ---- Modal select helpers (LWC templates can't inline-compare) ----
  get isClientBlank() {
    return !this.currentProject?.Account__c;
  }

  get clientOptionsWithSelected() {
    const selectedId = this.currentProject?.Account__c;
    return (this.clientOptions || []).map((opt) => ({
      ...opt,
      selected: Boolean(selectedId) && opt.value === selectedId
    }));
  }

  get statusOptions() {
    return [
      { label: "Active", value: "Active" },
      { label: "On Hold", value: "On Hold" },
      { label: "Completed", value: "Completed" }
    ];
  }

  get priorityOptions() {
    return [
      { label: "High", value: "High" },
      { label: "Medium", value: "Medium" },
      { label: "Low", value: "Low" }
    ];
  }

  get isPriorityHigh() {
    return this.currentProject?.Priority__c === "High";
  }
  get isPriorityMedium() {
    const p = this.currentProject?.Priority__c;
    return !p || p === "Medium";
  }
  get isPriorityLow() {
    return this.currentProject?.Priority__c === "Low";
  }

  get isStatusActive() {
    const s = this.currentProject?.Status__c;
    return !s || s === "Active";
  }
  get isStatusOnHold() {
    return this.currentProject?.Status__c === "On Hold";
  }
  get isStatusCompleted() {
    return this.currentProject?.Status__c === "Completed";
  }

  // Helper strings for ARIA attributes avoiding boolean type strictness issues
  get isListViewStr() {
    return String(this.isListView);
  }

  get isGridViewStr() {
    return String(this.isGridView);
  }

  get showExportDropdownStr() {
    return String(this.showExportDropdown);
  }

  get showFilterDropdownStr() {
    return String(this.showFilterDropdown);
  }

  get showSortDropdownStr() {
    return String(this.showSortDropdown);
  }

  get isBasicTabStr() {
    return String(this.isBasicTab);
  }

  get isMembersTabStr() {
    return String(this.isMembersTab);
  }

  get computedExtraTime() {
    const total = Number(this.currentProject?.Total_Hours__c ?? 0);
    const logged = Number(this.currentProject?.Hours_Logged__c ?? 0);
    const extra = logged - total;
    return Number.isFinite(extra) && extra > 0 ? extra : 0;
  }

  get hasCurrentProjectId() {
    return Boolean(this.currentProject?.Id);
  }

  get logoUploadDisabled() {
    return this.isLoading || !this.hasCurrentProjectId;
  }

  // SmartHR-style icon list button classes
  get tableViewButtonClass() {
    const base = "btn btn-icon btn-sm me-1";
    return this.isListView ? `${base} active bg-primary text-white` : base;
  }

  get gridViewButtonClass() {
    const base = "btn btn-icon btn-sm";
    return this.isListView ? base : `${base} active bg-primary text-white`;
  }

  // Backwards-compat (older markup referenced this)
  get listViewButtonClass() {
    return this.tableViewButtonClass;
  }

  handleViewToggle(event) {
    this.isListView = event.currentTarget.dataset.view === "list";
    this.showExportDropdown = false;
    this.showFilterDropdown = false;
    this.showSortDropdown = false;
    this.openActionMenuForId = null;
  }

  toggleExportDropdown(event) {
    event?.stopPropagation?.();
    this.showExportDropdown = !this.showExportDropdown;
    // Keep behavior consistent: only one menu open at a time.
    this.openActionMenuForId = null;
    this.showFilterDropdown = false;
    this.showSortDropdown = false;
  }

  handleExportMenuContainerClick(event) {
    // Prevent click-outside handler from immediately closing the dropdown.
    event?.stopPropagation?.();
  }

  get exportDropdownClass() {
    return this.showExportDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  handleExportPdf() {
    // UI parity: PDF export not implemented yet.
    this.showExportDropdown = false;
    this.showToast(
      "Info",
      "PDF export isn't available yet. Use Excel export for now.",
      "info"
    );
  }

  handleExportExcel() {
    // Excel can open CSV; keep label consistent with SmartHR template.
    this.handleExportCsv();
  }

  handleExportCsv() {
    try {
      this.showExportDropdown = false;

      const rows = Array.isArray(this.projects) ? this.projects : [];
      if (!rows.length) {
        this.showToast("Info", "No projects to export.", "info");
        return;
      }

      const headers = [
        "Name",
        "Client",
        "Leader",
        "Deadline",
        "Priority",
        "Status",
        "Team Size",
        "Hours Logged",
        "Total Hours",
        "Amount"
      ];

      const escapeCell = (v) => {
        const s = v === null || v === undefined ? "" : String(v);
        const needsQuotes = /[\n\r",]/.test(s);
        const escaped = s.replaceAll('"', '""');
        return needsQuotes ? `"${escaped}"` : escaped;
      };

      const csvLines = [headers.join(",")];
      for (const p of rows) {
        csvLines.push(
          [
            p?.name,
            p?.clientName,
            p?.leaderName,
            p?.deadline,
            p?.priority,
            p?.status,
            p?.teamSize,
            p?.hoursLogged,
            p?.hours,
            p?.amount
          ]
            .map(escapeCell)
            .join(",")
        );
      }

      const csv = csvLines.join("\r\n");
      const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `projects_${new Date().toISOString().slice(0, 10)}.csv`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    } catch (e) {
      // Keep export failures non-fatal.
      logError("pwchronoProjectsGrid.exportCsv", e);
      this.showToast("Error", "Export failed. Please try again.", "error");
    }
  }

  // ---- Filter / Sort dropdowns (SmartHR table header parity) ----
  get filterLabel() {
    return this.selectedStatusFilter || "All";
  }

  get sortLabel() {
    return this.selectedSort || "Recent";
  }

  toggleFilterDropdown(event) {
    event?.stopPropagation?.();
    this.showFilterDropdown = !this.showFilterDropdown;
    this.showExportDropdown = false;
    this.showSortDropdown = false;
    this.openActionMenuForId = null;
  }

  toggleSortDropdown(event) {
    event?.stopPropagation?.();
    this.showSortDropdown = !this.showSortDropdown;
    this.showExportDropdown = false;
    this.showFilterDropdown = false;
    this.openActionMenuForId = null;
  }

  handleFilterMenuContainerClick(event) {
    event?.stopPropagation?.();
  }

  handleSortMenuContainerClick(event) {
    event?.stopPropagation?.();
  }

  get filterDropdownClass() {
    return this.showFilterDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  get sortDropdownClass() {
    return this.showSortDropdown
      ? "dropdown-menu dropdown-menu-end p-3 show"
      : "dropdown-menu dropdown-menu-end p-3";
  }

  handleFilterSelect(event) {
    const value = event?.currentTarget?.dataset?.value;
    if (value) {
      this.selectedStatusFilter = value;
    }
    this.showFilterDropdown = false;
  }

  handleSortSelect(event) {
    const value = event?.currentTarget?.dataset?.value;
    if (value) {
      this.selectedSort = value;
    }
    this.showSortDropdown = false;
  }

  wiredProjectsResult;

  connectedCallback() {
    this.refreshSessionFromStore();

    this.sessionChangedHandler = () => {
      const priorUserId = this.portalUserId;
      const priorToken = this.sessionToken;
      this.refreshSessionFromStore();

      if (
        priorUserId !== this.portalUserId ||
        priorToken !== this.sessionToken
      ) {
        refreshApex(this.wiredProjectsResult);
      }
    };

    try {
      const w = globalThis?.window ?? globalThis;
      w?.addEventListener?.(SESSION_CHANGED_EVENT, this.sessionChangedHandler);
    } catch {
      // no-op
    }

    // Close any open action menu when clicking elsewhere.
    this.documentClickHandler = () => {
      this.openActionMenuForId = null;
      this.showExportDropdown = false;
      this.showFilterDropdown = false;
      this.showSortDropdown = false;
    };

    // Close menus on Escape key (a11y)
    this.documentKeydownHandler = (event) => {
      if (event.key === "Escape") {
        this.openActionMenuForId = null;
        this.showExportDropdown = false;
        this.showFilterDropdown = false;
        this.showSortDropdown = false;
      }
    };

    try {
      const w = globalThis?.window ?? globalThis;
      w?.addEventListener?.("click", this.documentClickHandler);
      w?.addEventListener?.("keydown", this.documentKeydownHandler);
    } catch {
      // no-op
    }
  }

  disconnectedCallback() {
    try {
      const w = globalThis?.window ?? globalThis;
      w?.removeEventListener?.(
        SESSION_CHANGED_EVENT,
        this.sessionChangedHandler
      );
    } catch {
      // no-op
    }

    try {
      const w = globalThis?.window ?? globalThis;
      w?.removeEventListener?.("click", this.documentClickHandler);
      w?.removeEventListener?.("keydown", this.documentKeydownHandler);
    } catch {
      // no-op
    }

    this.sessionChangedHandler = null;
    this.documentClickHandler = null;
    this.documentKeydownHandler = null;
  }

  refreshSessionFromStore() {
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  @wire(getProjects, {
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredProjects(result) {
    this.wiredProjectsResult = result;
    const { error, data } = result;
    this.isLoading = false;
    if (Array.isArray(data)) {
      this.projects = data.map((proj) => this.mapRecordToProject(proj));
    } else if (error) {
      logError("pwchronoProjectsGrid.wiredProjects", error);
      this.projects = [];
    }
  }

  @wire(getProjectClients, {
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredClients(result) {
    const { data, error } = result;
    this.clientsLoading = false;
    if (Array.isArray(data)) {
      this.clientOptions = data.map((a) => ({
        label: a?.Name,
        value: a?.Id
      }));
    } else if (error) {
      // Don't block the page if Accounts cannot be loaded.
      logError("pwchronoProjectsGrid.wiredClients", error);
      this.clientOptions = [];
    }
  }

  mapRecordToProject(proj) {
    const status = proj?.Status__c || "Active";
    const statusClassMap = {
      Completed: "badge bg-success-transparent",
      Active: "badge bg-info-transparent",
      "On Hold": "badge bg-warning-transparent"
    };
    const statusPillClassMap = {
      "On Hold":
        "badge badge-warning d-inline-flex align-items-center badge-xs",
      Active: "badge badge-success d-inline-flex align-items-center badge-xs",
      Completed: "badge badge-success d-inline-flex align-items-center badge-xs"
    };
    const statusClass =
      statusClassMap[status] || "badge bg-primary-transparent";
    const statusPillClass =
      statusPillClassMap[status] ||
      "badge badge-success d-inline-flex align-items-center badge-xs";

    const priority = proj?.Priority__c || "Medium";
    const priorityClassMap = {
      High: "badge badge-sm badge-danger",
      Medium: "badge badge-sm badge-warning",
      Low: "badge badge-sm badge-info"
    };
    const priorityPillClassMap = {
      High: "badge badge-sm badge-danger d-inline-flex align-items-center",
      Medium: "badge badge-sm badge-warning d-inline-flex align-items-center",
      Low: "badge badge-sm badge-success d-inline-flex align-items-center"
    };
    const priorityClass =
      priorityClassMap[priority] || "badge badge-sm badge-info";
    const priorityPillClass =
      priorityPillClassMap[priority] ||
      "badge badge-sm badge-info d-inline-flex align-items-center";

    const leaderName = proj?.Project_Leader__c || proj?.CreatedBy?.Name;
    const leaderInitials = this.getInitials(leaderName);

    const logoVersionId = proj?.Project_Logo_ContentVersion_Id__c;
    const logoUrl = logoVersionId
      ? `/sfc/servlet.shepherd/version/download/${logoVersionId}`
      : null;

    const totalHours = Number(proj?.Total_Hours__c ?? 0);
    const hoursLogged = Number(proj?.Hours_Logged__c ?? 0);
    const extraTime = Math.max(0, hoursLogged - totalHours);

    const id = proj?.Id;
    const shortId = id ? String(id).slice(-6) : "";

    const membersRaw = String(proj?.Project_Members__c || "").trim();
    const members = membersRaw
      ? membersRaw
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean)
      : [];
    const teamPreview = members.slice(0, 3).map((name, idx) => ({
      key: `${shortId || "proj"}-${idx}`,
      name
    }));
    const teamExtraCount = Math.max(0, members.length - teamPreview.length);

    return {
      id,
      shortId,
      name: proj?.Name || "Untitled Project",
      projectInitials: this.getInitials(proj?.Name || "Project"),
      description: proj?.Description__c || "No description available.",
      deadline: proj?.End_Date__c
        ? new Date(proj.End_Date__c).toLocaleDateString("en-GB", {
            day: "numeric",
            month: "short",
            year: "numeric"
          })
        : "No Date",
      hours: totalHours ? `${totalHours} hrs` : "0 hrs",
      hoursLogged: hoursLogged ? `${hoursLogged} hrs` : "0 hrs",
      totalHours,
      extraTime,
      teamSize: proj?.Team_Size__c ?? null,
      priority,
      priorityClass: priorityClass,
      priorityPillClass,
      clientName: proj?.Account__r?.Name || "Internal",
      leaderName: leaderName || "Project Leader",
      leaderInitials,
      status: status,
      statusClass: statusClass,
      statusPillClass,
      amount: proj?.Amount__c || 0,

      teamPreview,
      teamExtraCount,
      hasTeamExtra: teamExtraCount > 0,

      logoUrl,
      logoErrored: false,

      // Raw fields for editing
      rawStatus: status,
      rawStartDate: proj?.Start_Date__c,
      rawEndDate: proj?.End_Date__c,
      rawPriority: proj?.Priority__c,
      rawAmount: proj?.Amount__c,
      rawAccountId: proj?.Account__c,
      rawTeamSize: proj?.Team_Size__c,
      rawHoursLogged: proj?.Hours_Logged__c,
      rawTotalHours: proj?.Total_Hours__c,
      rawDescription: proj?.Description__c,
      rawTeamMembers: proj?.Project_Members__c,
      rawTeamLeader: proj?.Project_Leader__c,
      rawProjectManager: proj?.Project_Manager_Name__c,
      rawTags: proj?.Project_Tags__c,
      rawLogoVersionId: proj?.Project_Logo_ContentVersion_Id__c
    };
  }

  getInitials(name) {
    const safe = (name || "").trim();
    if (!safe) return "PL";
    const parts = safe.split(/\s+/).filter(Boolean);
    const first = parts[0]?.[0] || "";
    const last = parts.length > 1 ? parts[parts.length - 1]?.[0] : "";
    return (first + last).toUpperCase() || "PL";
  }

  @track activeTab = "basic";

  get isBasicTab() {
    return this.activeTab === "basic";
  }

  get isMembersTab() {
    return this.activeTab === "members";
  }

  get basicTabClass() {
    return this.activeTab === "basic" ? "nav-link active" : "nav-link";
  }
  get membersTabClass() {
    return this.activeTab === "members" ? "nav-link active" : "nav-link";
  }

  handleTabChange(event) {
    event.preventDefault();
    this.activeTab = event.target.dataset.tab;
  }

  handleAddProject() {
    this.openActionMenuForId = null;
    this.activeTab = "basic";
    this.currentProject = {
      Name: "",
      Description__c: "",
      Status__c: "Active",
      Priority__c: "Medium",
      Account__c: "",
      Start_Date__c: new Date().toISOString().slice(0, 10),
      End_Date__c: new Date(new Date().setDate(new Date().getDate() + 30))
        .toISOString()
        .slice(0, 10),
      Amount__c: null,
      Team_Size__c: null,
      Hours_Logged__c: null,
      Total_Hours__c: null,
      Project_Members__c: "",
      Project_Leader__c: "",
      Project_Manager_Name__c: "",
      Project_Tags__c: "",
      Project_Logo_ContentVersion_Id__c: ""
    };
    this.modalTitle = "Add Project";
    this.showProjectModal = true;
  }

  handleEditProject(event) {
    this.openActionMenuForId = null;
    this.activeTab = "basic";
    const projectId = event.currentTarget.dataset.id;
    const project = this.projects.find((p) => p.id === projectId);
    if (project) {
      this.currentProject = {
        Id: project.id,
        Name: project.name,
        Description__c: project.rawDescription || "",
        Status__c: project.rawStatus,
        Start_Date__c: project.rawStartDate,
        End_Date__c: project.rawEndDate,
        Priority__c: project.rawPriority,
        Amount__c: project.rawAmount,
        Account__c: project.rawAccountId || "",
        Team_Size__c: project.rawTeamSize,
        Hours_Logged__c: project.rawHoursLogged,
        Total_Hours__c: project.rawTotalHours,
        Project_Members__c: project.rawTeamMembers || "",
        Project_Leader__c: project.rawTeamLeader || "",
        Project_Manager_Name__c: project.rawProjectManager || "",
        Project_Tags__c: project.rawTags || "",
        Project_Logo_ContentVersion_Id__c: project.rawLogoVersionId || ""
      };
      this.modalTitle = "Edit Project";
      this.showProjectModal = true;
    }
  }

  handleDeleteProject(event) {
    this.openActionMenuForId = null;
    this.projectIdPendingDelete = event.currentTarget.dataset.id;
    this.showDeleteModal = true;
  }

  handleToggleActions(event) {
    event.preventDefault();
    event.stopPropagation();
    const projectId = event.currentTarget.dataset.id;
    this.openActionMenuForId =
      this.openActionMenuForId === projectId ? null : projectId;
    this.showExportDropdown = false;
    this.showFilterDropdown = false;
    this.showSortDropdown = false;
  }

  handleMenuContainerClick(event) {
    // Prevent click-outside handler from immediately closing the menu.
    event.stopPropagation();
  }

  closeDeleteModal() {
    this.showDeleteModal = false;
    this.projectIdPendingDelete = null;
  }

  confirmDeleteProject() {
    const projectId = this.projectIdPendingDelete;
    if (!projectId) return;

    this.isLoading = true;
    deleteProjectController({
      projectId,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast("Success", "Project deleted successfully", "success");
        this.closeDeleteModal();
        return refreshApex(this.wiredProjectsResult);
      })
      .catch((error) => {
        this.showToast(
          "Error",
          "Error deleting project: " + (error?.body?.message || "Unknown"),
          "error"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  closeModal() {
    this.showProjectModal = false;
  }

  handleFieldChange(event) {
    const field = event.target.dataset.field;
    // Support both native inputs and lightning-* components
    const val = event.detail?.value ?? event.target.value;
    this.currentProject[field] = val;
  }

  handleLogoSelected(event) {
    const files = event?.target?.files;
    if (!files?.length) return;

    if (!this.currentProject?.Id) {
      this.showToast(
        "Info",
        "Save the project first to enable logo upload.",
        "info"
      );
      return;
    }

    const file = files[0];
    const maxBytes = 4 * 1024 * 1024;
    if (file.size > maxBytes) {
      this.showToast("Error", "Logo must be below 4 MB", "error");
      return;
    }

    this.isLoading = true;
    const reader = new FileReader();
    reader.onload = () => {
      const result = typeof reader.result === "string" ? reader.result : "";
      if (!result) {
        this.isLoading = false;
        this.showToast("Error", "Could not read file", "error");
        return;
      }
      const base64 = result.includes(",") ? result.split(",")[1] : result;
      uploadProjectLogo({
        projectId: this.currentProject.Id,
        fileName: file.name,
        base64Data: base64,
        contentType: file.type,
        portalUserId: this.portalUserId,
        sessionToken: this.sessionToken
      })
        .then((contentVersionId) => {
          this.currentProject.Project_Logo_ContentVersion_Id__c =
            contentVersionId;
          this.showToast("Success", "Logo uploaded successfully", "success");
          return refreshApex(this.wiredProjectsResult);
        })
        .catch((error) => {
          this.showToast(
            "Error",
            "Error uploading logo: " + (error?.body?.message || "Unknown"),
            "error"
          );
        })
        .finally(() => {
          this.isLoading = false;
        });
    };
    reader.onerror = () => {
      this.isLoading = false;
      this.showToast("Error", "Could not read file", "error");
    };
    reader.readAsDataURL(file);
  }

  saveProject() {
    if (!this.currentProject.Name) {
      this.showToast("Error", "Project Name is required", "error");
      return;
    }

    this.isLoading = true;
    saveProject({
      projectData: this.currentProject,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast("Success", "Project saved successfully", "success");
        this.closeModal();
        return refreshApex(this.wiredProjectsResult);
      })
      .catch((error) => {
        this.showToast(
          "Error",
          "Error saving project: " + (error?.body?.message || "Unknown"),
          "error"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }
}