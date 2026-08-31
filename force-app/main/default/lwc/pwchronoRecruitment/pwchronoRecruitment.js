import { LightningElement, track, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import getRecruitmentDashboardMetrics from "@salesforce/apex/PWChrono_RecruitmentController.getRecruitmentDashboardMetrics";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";

export default class PwchronoRecruitment extends LightningElement {
  static renderMode = "light";

  @track activeTab = "pipeline";
  @track portalUserId = getEmployeeId();
  @track sessionToken = getSessionToken();

  @track metrics = {
    openJobsCount: 0,
    requisitionsCount: 0,
    staffingPlansCount: 0,
    totalApplicantsCount: 0,
    interviewingCount: 0,
    offersExtendedCount: 0,
    hiredCount: 0,
    referralsCount: 0
  };

  _wiredMetricsResult;

  connectedCallback() {
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  @wire(getRecruitmentDashboardMetrics, {
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredMetrics(result) {
    this._wiredMetricsResult = result;
    if (result.data) {
      const data = result.data;
      this.metrics = {
        openJobsCount: data.openJobsCount || 0,
        requisitionsCount: data.requisitionsCount || 0,
        staffingPlansCount: data.staffingPlansCount || 0,
        totalApplicantsCount: data.totalApplicantsCount || 0,
        interviewingCount: data.interviewingCount || 0,
        offersExtendedCount: data.offersExtendedCount || 0,
        hiredCount: data.hiredCount || 0,
        referralsCount: data.referralsCount || 0
      };
    }
  }

  handleTabClick(event) {
    const tab = event?.currentTarget?.dataset?.tab;
    if (tab) {
      this.activeTab = tab;
      if (this._wiredMetricsResult) {
        refreshApex(this._wiredMetricsResult);
      }
    }
  }

  get isPipelineTab() {
    return this.activeTab === "pipeline";
  }

  get isOpeningsTab() {
    return this.activeTab === "openings";
  }

  get isRequisitionsTab() {
    return this.activeTab === "requisitions";
  }

  get isStaffingTab() {
    return this.activeTab === "staffing";
  }

  get isInterviewsTab() {
    return this.activeTab === "interviews";
  }

  get isOffersTab() {
    return this.activeTab === "offers";
  }

  get isReferralsTab() {
    return this.activeTab === "referrals";
  }

  get pipelineTabClass() {
    return `nav-link ${this.isPipelineTab ? "active" : ""}`;
  }

  get openingsTabClass() {
    return `nav-link ${this.isOpeningsTab ? "active" : ""}`;
  }

  get requisitionsTabClass() {
    return `nav-link ${this.isRequisitionsTab ? "active" : ""}`;
  }

  get staffingTabClass() {
    return `nav-link ${this.isStaffingTab ? "active" : ""}`;
  }

  get interviewsTabClass() {
    return `nav-link ${this.isInterviewsTab ? "active" : ""}`;
  }

  get offersTabClass() {
    return `nav-link ${this.isOffersTab ? "active" : ""}`;
  }

  get referralsTabClass() {
    return `nav-link ${this.isReferralsTab ? "active" : ""}`;
  }
}