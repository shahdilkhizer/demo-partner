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
      this.error = error.body.message;
      this.jobs = undefined;
    }
  }

  get hasJobs() {
    return this.jobs && this.jobs.length > 0;
  }

  handleRefer(event) {
    this.selectedJobId = event.target.dataset.id;
    this.selectedJobTitle = event.target.dataset.title;
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
    // Validate
    const allValid = [
      ...this.template.querySelectorAll("lightning-input")
    ].reduce((validSoFar, inputCmp) => {
      inputCmp.reportValidity();
      return validSoFar && inputCmp.checkValidity();
    }, true);

    if (!allValid) return;

    referCandidate({
      jobId: this.selectedJobId,
      firstName: this.referral.firstName,
      lastName: this.referral.lastName,
      email: this.referral.email,
      phone: this.referral.phone,
      experience: Number.parseInt(this.referral.experience, 10),
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
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Error referring candidate",
            message: error.body.message,
            variant: "error"
          })
        );
      });
  }

  closeModal() {
    this.isModalOpen = false;
  }
}