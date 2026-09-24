import getOpenJobs from "@salesforce/apex/PWChrono_CareerPortalController.getOpenJobs";
import getJobById from "@salesforce/apex/PWChrono_CareerPortalController.getJobById";
import getActiveDepartments from "@salesforce/apex/PWChrono_CareerPortalController.getActiveDepartments";
import submitApplication from "@salesforce/apex/PWChrono_CareerPortalController.submitApplication";
import { LightningElement, track } from "lwc";

const EMPLOYMENT_TYPE_BADGE = {
  "Full Time": "badge bg-primary-subtle text-primary me-2",
  "Part Time": "badge bg-info-subtle text-info me-2",
  Contract: "badge bg-warning-subtle text-warning me-2",
  Internship: "badge bg-success-subtle text-success me-2"
};

const emptyApplication = (jobId) => ({
  Job_Opening__c: jobId || "",
  Name: "",
  Email__c: "",
  Phone__c: "",
  Country__c: "",
  Source__c: "Website",
  Expected_Salary__c: null,
  Lower_Salary_Range__c: null,
  Upper_Salary_Range__c: null,
  Resume__c: "",
  Cover_Letter__c: ""
});

export default class PwchronoCareerPortal extends LightningElement {
  static renderMode = "light";

  @track jobs = [];
  @track departmentOptions = [];
  @track isLoading = true;

  @track isDetailOpen = false;
  @track isApplyOpen = false;
  @track selectedJob = null;

  @track applyRecord = emptyApplication();
  @track applyError = "";
  @track isSubmitting = false;
  @track showSuccessToast = false;

  @track filters = {
    keyword: "",
    departmentId: "",
    company: "",
    employmentType: "",
    location: ""
  };

  connectedCallback() {
    this._loadDepartments();
    this._loadJobs();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────────────────────────────────

  _loadDepartments() {
    getActiveDepartments()
      .then((depts) => {
        this.departmentOptions = depts.map((d) => ({ label: d.Name, value: d.Id }));
      })
      .catch(() => {});
  }

  _loadJobs() {
    this.isLoading = true;
    getOpenJobs({
      keyword: this.filters.keyword || null,
      departmentId: this.filters.departmentId || null,
      company: this.filters.company || null,
      employmentType: this.filters.employmentType || null,
      location: this.filters.location || null
    })
      .then((records) => {
        this.jobs = records.map((r) => this._enrichJob(r));
      })
      .catch(() => {
        this.jobs = [];
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  _enrichJob(r) {
    const closing = r.Closing_Date__c
      ? new Date(r.Closing_Date__c).toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
          year: "numeric"
        })
      : "Open";
    const desc = r.Job_Description__c || "";
    return {
      ...r,
      departmentName: r.Department__r?.Name ?? "—",
      designationName: r.Designation__r?.Name ?? "—",
      formattedClosingDate: closing,
      descriptionPreview: desc.length > 120 ? desc.substring(0, 120) + "…" : desc,
      employmentTypeBadge:
        EMPLOYMENT_TYPE_BADGE[r.Employment_Type__c] ||
        "badge bg-secondary-subtle text-secondary me-2",
      positionsPlural: r.No_of_Positions__c !== 1 ? "s" : ""
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────────────────

  get jobCount() {
    return this.jobs.length;
  }

  get jobCountPlural() {
    return this.jobs.length !== 1 ? "s" : "";
  }

  get isEmpty() {
    return !this.isLoading && this.jobs.length === 0;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter handlers
  // ─────────────────────────────────────────────────────────────────────────

  handleFilterChange(event) {
    const field = event.currentTarget.dataset.field;
    this.filters = { ...this.filters, [field]: event.target.value };
  }

  handleSearch() {
    this._loadJobs();
  }

  handleClearFilters() {
    this.filters = {
      keyword: "",
      departmentId: "",
      company: "",
      employmentType: "",
      location: ""
    };
    this._loadJobs();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Job detail
  // ─────────────────────────────────────────────────────────────────────────

  handleViewJob(event) {
    const jobId = event.currentTarget.dataset.id;
    getJobById({ jobOpeningId: jobId })
      .then((job) => {
        this.selectedJob = this._enrichJob(job);
        this.isDetailOpen = true;
      })
      .catch(() => {});
  }

  handleCloseDetail() {
    this.isDetailOpen = false;
    this.selectedJob = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Apply modal
  // ─────────────────────────────────────────────────────────────────────────

  handleOpenApply() {
    this.applyRecord = emptyApplication(this.selectedJob?.Id);
    this.applyError = "";
    this.isDetailOpen = false;
    this.isApplyOpen = true;
  }

  handleCloseApply() {
    this.isApplyOpen = false;
    this.applyError = "";
  }

  handleApplyChange(event) {
    const field = event.currentTarget.dataset.field;
    const value = event.target.value;
    this.applyRecord = { ...this.applyRecord, [field]: value };
  }

  handleSubmitApplication() {
    this.applyError = "";
    if (!this._validateApplication()) return;

    this.isSubmitting = true;
    submitApplication({ applicationJson: JSON.stringify(this.applyRecord) })
      .then(() => {
        this.isApplyOpen = false;
        this.showSuccessToast = true;
        // Auto-dismiss toast after 5 s
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
          this.showSuccessToast = false;
        }, 5000);
      })
      .catch((err) => {
        this.applyError =
          err?.body?.message || "An error occurred while submitting your application.";
      })
      .finally(() => {
        this.isSubmitting = false;
      });
  }

  handleDismissToast() {
    this.showSuccessToast = false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────────────────────────────────

  _validateApplication() {
    if (!this.applyRecord.Name?.trim()) {
      this.applyError = "Applicant Name is required.";
      return false;
    }
    if (!this.applyRecord.Email__c?.trim()) {
      this.applyError = "Email Address is required.";
      return false;
    }
    const emailRe = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRe.test(this.applyRecord.Email__c.trim())) {
      this.applyError = "Please enter a valid email address.";
      return false;
    }
    return true;
  }
}