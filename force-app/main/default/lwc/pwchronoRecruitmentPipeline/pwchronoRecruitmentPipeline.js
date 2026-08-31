import { refreshApex } from "@salesforce/apex";
import getUserAccessById from "@salesforce/apex/PWChrono_AccessController.getUserAccessById";
import getJobApplicants from "@salesforce/apex/PWChrono_RecruitmentController.getJobApplicants";
import updateApplicantStatus from "@salesforce/apex/PWChrono_RecruitmentController.updateApplicantStatus";
import { logError } from "c/pwchronoErrorHandler";
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
          jobTitle: app.Job_Opening__r
            ? app.Job_Opening__r.Name
            : "General Application",
          formattedDate: app.CreatedDate
            ? new Date(app.CreatedDate).toLocaleDateString()
            : "N/A"
        });
        column.count++;
      } else {
        // Handle unknown status or map to closest?
        // For now, ignore or maybe add to 'Applied' if null?
        // Assuming status matches picklist values
      }
    });

    this.columns = newColumns;
  }

  handleDragStart(event) {
    const draggable = event.currentTarget;
    this.draggedApplicantId = draggable?.dataset?.id;
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", this.draggedApplicantId);
    draggable?.classList?.add("dragging");
  }

  handleDragEnd(event) {
    const draggable = event.currentTarget;
    draggable?.classList?.remove("dragging");
    this.template.querySelectorAll(".drop-zone-active").forEach((el) => {
      el.classList.remove("drop-zone-active");
    });
  }

  handleDragOver(event) {
    event.preventDefault();
    event.dataTransfer.dropEffect = "move";
    const columnContent = event.currentTarget;
    columnContent.classList.add("drop-zone-active");
  }

  handleDragLeave(event) {
    const columnContent = event.currentTarget;
    columnContent.classList.remove("drop-zone-active");
  }

  handleDrop(event) {
    event.preventDefault();
    const columnContent = event.currentTarget;
    columnContent.classList.remove("drop-zone-active");

    const newStatus = columnContent.dataset.status;
    const applicantId = this.draggedApplicantId;

    if (!applicantId || !newStatus) return;

    // Find current status to check if it actually changed
    let currentStatus;
    this.columns.forEach((col) => {
      if (col.applicants.some((a) => a.Id === applicantId)) {
        currentStatus = col.value;
      }
    });

    if (currentStatus === newStatus) return;

    this.isLoading = true;
    updateApplicantStatus({
      applicantId: applicantId,
      newStatus: newStatus,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast("Success", "Status updated successfully", "success");
        return refreshApex(this.wiredApplicantsResult);
      })
      .catch((error) => {
        const errorMsg =
          error?.body?.message || error?.message || "Failed to update status";
        this.showToast("Error updating status", errorMsg, "error");
        this.isLoading = false;
      });
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