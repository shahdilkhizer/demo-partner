import { LightningElement, track } from "lwc";

const TAB_DASHBOARD  = "dashboard";
const TAB_MY_CLAIMS  = "myclaims";
const TAB_APPROVALS  = "approvals";

export default class PwchronoExpenseManagement extends LightningElement {
  static renderMode = "light";

  @track activeTab        = TAB_DASHBOARD;
  @track selectedClaimId  = null;
  @track showClaimForm    = false;
  @track editClaimId      = null;   // null = new claim, Id = edit existing

  // ── Routing ───────────────────────────────────────────────────────────────

  get isDetailView()    { return !!this.selectedClaimId; }
  get isDashboardTab()  { return !this.isDetailView && this.activeTab === TAB_DASHBOARD; }
  get isMyClaimsTab()   { return !this.isDetailView && this.activeTab === TAB_MY_CLAIMS; }
  get isApprovalsTab()  { return !this.isDetailView && this.activeTab === TAB_APPROVALS; }

  tabClass(tab) {
    return `nav-link${this.activeTab === tab ? " active fw-medium" : ""}`;
  }
  get dashboardTabClass() { return this.tabClass(TAB_DASHBOARD); }
  get myClaimsTabClass()  { return this.tabClass(TAB_MY_CLAIMS); }
  get approvalsTabClass() { return this.tabClass(TAB_APPROVALS); }

  // ── Tab handlers ──────────────────────────────────────────────────────────

  handleTabDashboard()  { this.activeTab = TAB_DASHBOARD; }
  handleTabMyClaims()   { this.activeTab = TAB_MY_CLAIMS; }
  handleTabApprovals()  { this.activeTab = TAB_APPROVALS; }

  // ── Claim form modal ──────────────────────────────────────────────────────

  handleNewClaim() {
    this.editClaimId    = null;
    this.showClaimForm  = true;
  }

  handleEditClaim(event) {
    this.editClaimId    = event.detail?.claimId || null;
    this.showClaimForm  = true;
  }

  handleFormCancel() {
    this.showClaimForm = false;
    this.editClaimId   = null;
  }

  handleClaimSubmitted(event) {
    this.showClaimForm    = false;
    this.editClaimId      = null;
    const claimId = event.detail?.claimId;
    if (claimId) {
      this.selectedClaimId = claimId;
    }
  }

  // ── Detail navigation ─────────────────────────────────────────────────────

  handleViewDetail(event) {
    this.selectedClaimId = event.detail?.claimId;
  }

  handleViewAll() {
    this.activeTab = TAB_MY_CLAIMS;
  }

  handleBack() {
    this.selectedClaimId = null;
  }

  handleClaimActioned() {
    this.selectedClaimId = null;
  }
}