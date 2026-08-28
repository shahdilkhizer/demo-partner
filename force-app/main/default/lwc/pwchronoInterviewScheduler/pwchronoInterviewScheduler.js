import { refreshApex } from "@salesforce/apex";
import getApplicantInterviews from "@salesforce/apex/PWChrono_RecruitmentController.getApplicantInterviews";
import getJobApplicants from "@salesforce/apex/PWChrono_RecruitmentController.getJobApplicants";
import getPotentialInterviewers from "@salesforce/apex/PWChrono_RecruitmentController.getPotentialInterviewers";
import scheduleInterview from "@salesforce/apex/PWChrono_RecruitmentController.scheduleInterview";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, wire } from "lwc";

export default class PwchronoInterviewScheduler extends LightningElement {
  @track selectedApplicantId;
  @track applicantOptions = [];
  @track interviewerOptions = [];
  @track interviews = [];
  @track isModalOpen = false;
  @track isLoading = true;
  @track isInterviewsLoading = false;

  @track currentInterview = {};

  wiredInterviewsResult;

  roundOptions = [
    { label: "Screening", value: "Screening" },
    { label: "Technical Round 1", value: "Technical Round 1" },
    { label: "Technical Round 2", value: "Technical Round 2" },
    { label: "HR Round", value: "HR Round" },
    { label: "Final Round", value: "Final Round" }
  ];

  @wire(getJobApplicants, { jobOpeningId: null, statusFilter: "All" })
  wiredApplicants({ error, data }) {
    this.isLoading = false;
    if (data) {
      this.applicantOptions = data.map((app) => ({
        label: `${app.Applicant_Name__c} - ${app.Job_Opening__r?.Name || "General"}`,
        value: app.Id
      }));
    } else if (error) {
      this.showToast("Error", "Error loading applicants", "error");
    }
  }

  @wire(getPotentialInterviewers)
  wiredInterviewers({ error, data }) {
    if (data) {
      this.interviewerOptions = data.map((emp) => ({
        label: emp.Name,
        value: emp.Id
      }));
    } else if (error) {
      this.showToast("Error", "Error loading interviewers", "error");
    }
  }

  @wire(getApplicantInterviews, { applicantId: "$selectedApplicantId" })
  wiredInterviews(result) {
    this.wiredInterviewsResult = result;
    this.isInterviewsLoading = false;
    if (result.data) {
      this.interviews = result.data.map((inv) => ({
        ...inv,
        interviewerName: inv.Interviewer__r
          ? inv.Interviewer__r.Name
          : "Not Assigned",
        formattedDate: inv.Interview_Date__c
          ? new Date(inv.Interview_Date__c).toLocaleString()
          : "TBD",
        statusClass: this.getStatusClass(inv.Result__c)
      }));
    } else if (result.error) {
      this.interviews = [];
      // Don't show error if no applicant selected
      if (this.selectedApplicantId) {
        this.showToast("Error", "Error loading interviews", "error");
      }
    }
  }

  get isScheduleDisabled() {
    return !this.selectedApplicantId;
  }

  handleApplicantChange(event) {
    this.isInterviewsLoading = true;
    this.selectedApplicantId = event.detail.value;
  }

  handleNewInterview() {
    if (!this.selectedApplicantId) {
      this.showToast("Warning", "Please select an applicant first", "warning");
      return;
    }
    this.currentInterview = {
      Job_Applicant__c: this.selectedApplicantId,
      Round__c: "Screening",
      Interview_Date__c: null,
      Interviewer__c: null
    };
    this.isModalOpen = true;
  }

  closeModal() {
    this.isModalOpen = false;
  }

  handleInputChange(event) {
    const field = event.target.name;
    this.currentInterview[field] = event.target.value;
  }

  handleSaveInterview() {
    if (!this.validateForm()) {
      return;
    }

    this.isLoading = true;
    scheduleInterview({ interview: this.currentInterview })
      .then(() => {
        this.showToast(
          "Success",
          "Interview scheduled successfully",
          "success"
        );
        this.isModalOpen = false;
        return refreshApex(this.wiredInterviewsResult);
      })
      .catch((error) => {
        this.showToast("Error", error.body.message, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  validateForm() {
    const allValid = [
      ...this.template.querySelectorAll(".interview-input")
    ].reduce((validSoFar, inputCmp) => {
      inputCmp.reportValidity();
      return validSoFar && inputCmp.checkValidity();
    }, true);
    return allValid;
  }

  getStatusClass(result) {
    if (result === "Pass") return "text-green-600";
    if (result === "Fail") return "text-red-600";
    return "text-gray-500";
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