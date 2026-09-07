import { refreshApex } from "@salesforce/apex";
import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import getJobApplicants from "@salesforce/apex/PWChrono_RecruitmentController.getJobApplicants";
import updateApplicantStatus from "@salesforce/apex/PWChrono_RecruitmentController.updateApplicantStatus";
import { logError } from "c/pwchronoErrorHandler";
import { downloadCsv } from "c/pwchronoCsv";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, wire } from "lwc";

export default class PwchronoRecruitmentPipeline extends LightningElement {
  static renderMode = "light";
  @track portalUserId = getEmployeeId();
  @track sessionToken = getSessionToken();

  @track hasAccess = true;
  @track accessLoaded = true;
  @track columns = [
    { label: "Applied", value: "Applied", applicants: [], count: 0 },
    { label: "Screening", value: "Screening", applicants: [], count: 0 },
    {
      label: "Interview",
      value: "Interview Scheduled",
      applicants: [],
      count: 0
    },
    {
      label: "Interview Cleared",
      value: "Selected",
      applicants: [],
      count: 0
    },
    { label: "Offer", value: "Offer Extended", applicants: [], count: 0 },
    { label: "Hired", value: "Accepted", applicants: [], count: 0 },
    { label: "Rejected", value: "Rejected", applicants: [], count: 0 }
  ];

  @track isLoading = true;
  @track error = null;
  wiredApplicantsResult;
  draggedApplicantId;
  viewMode = "grid";
  searchTerm = "";
  statusFilter = "All";
  sortOrder = "newest";
  visibleCount = 12;

  get isGridView() {
    return this.viewMode === "grid";
  }

  get viewTitle() {
    return this.isGridView ? "Candidates Grid" : "Candidates Board";
  }
  get isBoardView() {
    return this.viewMode === "board";
  }
  get showBoardContainer() {
    return this.isLoading || Boolean(this.error) || this.isBoardView;
  }
  renderedCallback() {
    this.querySelectorAll("select[name]").forEach((select) => {
      const value = this[select.name];
      if (select.value !== value) select.value = value;
    });
  }
  get gridButtonClass() {
    return `btn btn-icon btn-sm ${this.isGridView ? "bg-primary text-white" : "btn-white"}`;
  }
  get boardButtonClass() {
    return `btn btn-icon btn-sm ${this.isBoardView ? "bg-primary text-white" : "btn-white"}`;
  }
  get statusOptions() {
    return this.columns.map((c) => ({ label: c.label, value: c.value }));
  }
  get filteredCandidates() {
    const query = this.searchTerm.trim().toLowerCase();
    const items = this.columns
      .flatMap((c) => c.applicants)
      .filter(
        (a) =>
          (this.statusFilter === "All" || a.Status__c === this.statusFilter) &&
          (!query ||
            `${a.applicantName} ${a.Email__c || ""} ${a.jobTitle}`
              .toLowerCase()
              .includes(query))
      );
    const colors = {
      Applied: "purple",
      Screening: "info",
      "Interview Scheduled": "pink",
      Selected: "success",
      "Offer Extended": "warning",
      Accepted: "success",
      Rejected: "danger"
    };
    return items
      .sort((a, b) => {
        return this.sortOrder === "name"
          ? a.applicantName.localeCompare(b.applicantName)
          : new Date(b.CreatedDate || 0) - new Date(a.CreatedDate || 0);
      })
      .map((a) => ({
        ...a,
        statusBadge: `badge bg-${colors[a.Status__c] || "secondary"}`,
        emailLabel: a.Email__c || "Email not provided"
      }));
  }
  get visibleCandidates() {
    return this.filteredCandidates.slice(0, this.visibleCount);
  }
  get hasCandidates() {
    return this.filteredCandidates.length > 0;
  }
  get hasMoreCandidates() {
    return this.filteredCandidates.length > this.visibleCount;
  }
  handleCandidateFilter(event) {
    this[event.currentTarget.name] = event.currentTarget.value;
    this.visibleCount = 12;
  }
  handleCandidateView(event) {
    this.viewMode = event.currentTarget.dataset.view;
  }
  handleLoadMore() {
    this.visibleCount += 12;
  }
  handleExport() {
    downloadCsv(
      "candidates.csv",
      ["Name", "Email", "Applied Role", "Applied Date", "Status"],
      this.filteredCandidates.map((c) => [
        c.applicantName,
        c.Email__c,
        c.jobTitle,
        c.formattedDate,
        c.Status__c
      ])
    );
  }
  handleResetFilters() {
    this.searchTerm = "";
    this.statusFilter = "All";
    this.sortOrder = "newest";
    this.visibleCount = 12;
  }

  connectedCallback() {
    this.checkAccess();
  }

  async checkAccess() {
    try {
      const employeeId = getEmployeeId();
      const data = await getUserAccessById({
        employeeId: employeeId,
        sessionToken: this.sessionToken
      });
      if (data) {
        const isAllowed =
          data.isSalesforceUser ||
          data.role === "HR Admin" ||
          data.role === "System Admin" ||
          data.role === "Guest" ||
          !data.role ||
          data.features?.includes("Recruitment");
        this.hasAccess = isAllowed !== false;
      }
    } catch (error) {
      logError("pwchronoRecruitmentPipeline.checkAccess", error);
      this.hasAccess = true;
    }
  }

  @wire(getJobApplicants, {
    jobOpeningId: null,
    statusFilter: "All",
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredApplicants(result) {
    this.wiredApplicantsResult = result;
    if (result.data) {
      this.processApplicants(result.data);
      this.isLoading = false;
      this.error = null;
    } else if (result.error) {
      this.showToast("Error", "Error loading applicants", "error");
      this.error =
        result.error?.body?.message ||
        result.error?.message ||
        "Failed to load applicants";
      this.isLoading = false;
    }
  }

  processApplicants(data) {
    // Reset columns
    const newColumns = this.columns.map((col) => ({
      ...col,
      applicants: [],
      count: 0
    }));

    data.forEach((app) => {
      const status = app.Status__c;
      const column = newColumns.find((col) => col.value === status);
      if (column) {
        column.applicants.push({
          ...app,
          applicantName: app.Name || app.Applicant_Name__c || "Candidate",
          jobTitle: app.Job_Opening__r
            ? app.Job_Opening__r.Name
            : "General Application",
          formattedDate: app.CreatedDate
            ? new Date(app.CreatedDate).toLocaleDateString(undefined, {
                day: "2-digit",
                month: "short",
                year: "numeric"
              })
            : "N/A"
        });
        column.count++;
      }
    });

    this.columns = newColumns;
  }

  handleDragStart(event) {
    const draggable = event.currentTarget;
    this.draggedApplicantId = draggable?.dataset?.id;
    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move";
      event.dataTransfer.setData("text/plain", this.draggedApplicantId || "");
    }
    draggable?.classList?.add("dragging");
  }

  handleDragEnd(event) {
    const draggable = event.currentTarget;
    draggable?.classList?.remove("dragging");
    const root = this;
    if (root && root.querySelectorAll) {
      root.querySelectorAll(".drop-zone-active").forEach((el) => {
        el.classList.remove("drop-zone-active");
      });
    }
  }

  handleDragOver(event) {
    event.preventDefault();
    if (event.dataTransfer) {
      event.dataTransfer.dropEffect = "move";
    }
    const dropTarget = event.currentTarget;
    dropTarget?.classList?.add("drop-zone-active");
  }

  handleDragLeave(event) {
    const dropTarget = event.currentTarget;
    dropTarget?.classList?.remove("drop-zone-active");
  }

  handleDrop(event) {
    event.preventDefault();
    const dropTarget = event.currentTarget;
    dropTarget?.classList?.remove("drop-zone-active");

    const root = this;
    if (root && root.querySelectorAll) {
      root.querySelectorAll(".drop-zone-active").forEach((el) => {
        el.classList.remove("drop-zone-active");
      });
    }

    const newStatus = dropTarget?.dataset?.status;
    const applicantId = this.draggedApplicantId;

    if (!applicantId || !newStatus) return;

    // Find current status to check if it actually changed
    let currentStatus = null;
    if (this.columns) {
      for (const col of this.columns) {
        if (
          col.applicants &&
          col.applicants.some((a) => a.Id === applicantId)
        ) {
          currentStatus = col.value;
          break;
        }
      }
    }

    if (currentStatus === newStatus) return;

    // Move card in UI immediately (optimistic update)
    this.optimisticMove(applicantId, currentStatus, newStatus);

    updateApplicantStatus({
      applicantId: applicantId,
      newStatus: newStatus,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast(
          "Success",
          "Candidate status updated to " + newStatus,
          "success"
        );
        return refreshApex(this.wiredApplicantsResult);
      })
      .catch((error) => {
        const errorMsg =
          error?.body?.message || error?.message || "Failed to update status";
        this.showToast("Error updating status", errorMsg, "error");
        return refreshApex(this.wiredApplicantsResult);
      })
      .finally(() => {
        this.draggedApplicantId = null;
      });
  }

  optimisticMove(applicantId, fromStatus, toStatus) {
    try {
      let movedApplicant = null;
      const updatedCols = this.columns.map((col) => {
        const newCol = { ...col, applicants: [...col.applicants] };
        if (col.value === fromStatus) {
          const idx = newCol.applicants.findIndex((a) => a.Id === applicantId);
          if (idx !== -1) {
            movedApplicant = { ...newCol.applicants[idx], Status__c: toStatus };
            newCol.applicants.splice(idx, 1);
            newCol.count = newCol.applicants.length;
          }
        }
        return newCol;
      });

      if (movedApplicant) {
        const targetCol = updatedCols.find((col) => col.value === toStatus);
        if (targetCol) {
          targetCol.applicants.push(movedApplicant);
          targetCol.count = targetCol.applicants.length;
        }
        this.columns = updatedCols;
      }
    } catch (e) {
      console.warn("Optimistic move warning", e);
    }
  }

  handleRefresh() {
    this.isLoading = true;
    refreshApex(this.wiredApplicantsResult).finally(() => {
      this.isLoading = false;
    });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}