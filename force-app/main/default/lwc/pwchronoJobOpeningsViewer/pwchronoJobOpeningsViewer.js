import { LightningElement, wire, track } from "lwc";
import getJobOpenings from "@salesforce/apex/PWChrono_RecruitmentController.getJobOpenings";
import referCandidate from "@salesforce/apex/PWChrono_RecruitmentController.referCandidate";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoJobOpeningsViewer extends LightningElement {
  static renderMode = "light";
  @track jobs;
  @track error;
  @track isLoading = true;
  searchTerm = "";
  isSaving = false;
  get filteredJobs() {
    const query = this.searchTerm.trim().toLowerCase();
    return (this.jobs || []).filter(
      (job) =>
        !query ||
        `${job.designationName} ${job.departmentName} ${job.Job_Description__c || ""}`
          .toLowerCase()
          .includes(query)
    );
  }
  handleSearch(event) {
    this.searchTerm = event.target.value;
  }
  handleResetSearch() {
    this.searchTerm = "";
  }

  @track isModalOpen = false;
  @track selectedJobId;
  @track selectedJobTitle;

  @track referral = {
    firstName: "",
    lastName: "",
    email: "",
    phone: "",
    experience: ""
  };

  @wire(getJobOpenings, { statusFilter: "Open" })
  wiredJobs({ error, data }) {
    this.isLoading = false;
    if (data) {
      // Precompute safe display fields to avoid template CallExpression
      this.jobs = data.map((job) => ({
        ...job,
        designationName:
          job?.Designation__r?.Name || job?.Name || "Open Position",
        departmentName: job?.Department__r?.Name || "General"
      }));
      this.error = undefined;
    } else if (error) {
      this.error =
        error?.body?.message ||
        error?.message ||
        "Unable to load job openings.";
      this.jobs = undefined;
    }
  }

  get hasJobs() {
    return this.filteredJobs.length > 0;
  }
  get showEmptyState() {
    return !this.error && !this.hasJobs;
  }

  handleRefer(event) {
    this._referralOpener = event.currentTarget;
    this._focusReferral = true;
    this.selectedJobId = event.currentTarget.dataset.id;
    this.selectedJobTitle = event.currentTarget.dataset.title;
    this.referral = {
      firstName: "",
      lastName: "",
      email: "",
      phone: "",
      experience: ""
    };
    this.isModalOpen = true;
  }

  handleFieldChange(event) {
    this.referral[event.target.name] = event.target.value;
  }

  handleSubmit() {
    if (this.isSaving) return;
    // Validate Light-DOM-safely
    const root = this;
    const inputs = root.querySelectorAll
      ? [...root.querySelectorAll("input")]
      : [];
    const allValid = inputs.reduce((validSoFar, inputCmp) => {
      inputCmp.reportValidity();
      return validSoFar && inputCmp.checkValidity();
    }, true);

    if (!allValid) return;
    this.isSaving = true;

    referCandidate({
      jobId: this.selectedJobId,
      firstName: this.referral.firstName,
      lastName: this.referral.lastName,
      email: this.referral.email,
      phone: this.referral.phone,
      experience: parseFloat(this.referral.experience) || 0,
      portalUserId: getEmployeeId(),
      sessionToken: getSessionToken()
    })
      .then(() => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Candidate referred successfully",
            variant: "success"
          })
        );
        this.isModalOpen = false;
      })
      .catch((error) => {
        const errorMsg =
          error?.body?.message || error?.message || "Failed to refer candidate";
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error referring candidate",
            message: errorMsg,
            variant: "error"
          })
        );
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  closeModal() {
    if (this.isSaving) return;
    this.isModalOpen = false;
    this._referralOpener?.focus();
  }

  renderedCallback() {
    if (this._focusReferral && this.isModalOpen) {
      this.querySelector('input[name="firstName"]')?.focus();
      this._focusReferral = false;
    }
  }

  handleModalKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault();
      this.closeModal();
    } else if (event.key === "Tab") {
      const controls = [
        ...this.querySelectorAll(
          ".modal button:not(:disabled), .modal input:not(:disabled)"
        )
      ];
      const first = controls[0];
      const last = controls[controls.length - 1];
      if (event.shiftKey && event.target === first) {
        event.preventDefault();
        last?.focus();
      } else if (!event.shiftKey && event.target === last) {
        event.preventDefault();
        first?.focus();
      }
    }
  }
}