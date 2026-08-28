import { LightningElement, track } from "lwc";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import getTeamExpenseClaimsForApproval from "@salesforce/apex/PWChrono_ExpenseController.getTeamExpenseClaimsForApproval";
import getTeamExpenseClaims from "@salesforce/apex/PWChrono_ExpenseController.getTeamExpenseClaims";

const VIEW_PENDING = "pending";
const VIEW_ALL     = "all";
const PAGE_SIZE    = 10;

export default class PwchronoExpenseClaimAdmin extends LightningElement {
  static renderMode = "light";

  @track isLoading     = true;
  @track error         = null;
  @track allClaims     = [];
  @track claims        = [];
  @track activeView    = VIEW_PENDING;
  @track statusFilter  = "";
  @track currentPage   = 1;

  employeeId   = getEmployeeId();
  sessionToken = getSessionToken();

  statusOptions = [
    { label: "All Statuses",  value: "" },
    { label: "Submitted",     value: "Submitted" },
    { label: "Approved",      value: "Approved" },
    { label: "Rejected",      value: "Rejected" },
    { label: "Cancelled",     value: "Cancelled" }
  ];

  connectedCallback() {
    this.loadClaims();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  loadClaims() {
    this.isLoading = true;
    this.error     = null;

    const call = this.activeView === VIEW_PENDING
      ? getTeamExpenseClaimsForApproval({
          employeeId:   this.employeeId,
          sessionToken: this.sessionToken
        })
      : getTeamExpenseClaims({
          statusFilter: this.statusFilter || null,
          employeeId:   this.employeeId,
          sessionToken: this.sessionToken
        });

    call
      .then((data) => {
        this.allClaims   = data || [];
        this.currentPage = 1;
        this.applyPage();
      })
      .catch((err) => {
        this.error = err?.body?.message || err?.message || "Error loading team claims.";
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  applyPage() {
    const start   = (this.currentPage - 1) * PAGE_SIZE;
    this.claims   = this.allClaims.slice(start, start + PAGE_SIZE);
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  get totalRecords()    { return this.allClaims.length; }
  get totalPages()      { return Math.ceil(this.totalRecords / PAGE_SIZE) || 1; }
  get startRecord()     { return this.totalRecords === 0 ? 0 : (this.currentPage - 1) * PAGE_SIZE + 1; }
  get endRecord()       { return Math.min(this.currentPage * PAGE_SIZE, this.totalRecords); }
  get paginationInfo()  { return `${this.startRecord}–${this.endRecord} of ${this.totalRecords}`; }
  get isPrevDisabled()  { return this.currentPage <= 1; }
  get isNextDisabled()  { return this.currentPage >= this.totalPages; }
  get hasClaims()       { return this.claims && this.claims.length > 0; }
  get hasNoClaims()     { return !this.isLoading && this.claims.length === 0; }
  get isPendingView()   { return this.activeView === VIEW_PENDING; }
  get isAllView()       { return this.activeView === VIEW_ALL; }

  get pendingTabClass() { return `nav-link${this.activeView === VIEW_PENDING ? " active fw-medium" : ""}`; }
  get allTabClass()     { return `nav-link${this.activeView === VIEW_ALL     ? " active fw-medium" : ""}`; }

  // ── Handlers ──────────────────────────────────────────────────────────────

  handleViewPending() {
    this.activeView   = VIEW_PENDING;
    this.statusFilter = "";
    this.loadClaims();
  }

  handleViewAll() {
    this.activeView = VIEW_ALL;
    this.loadClaims();
  }

  handleStatusFilter(event) {
    this.statusFilter = event.detail.value;
    this.loadClaims();
  }

  handlePrevPage() {
    if (this.currentPage > 1) { this.currentPage--; this.applyPage(); }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) { this.currentPage++; this.applyPage(); }
  }

  handleRowClick(event) {
    const claimId = event.currentTarget.dataset.id;
    this.dispatchEvent(
      new CustomEvent("viewdetail", {
        detail: { claimId },
        bubbles: true,
        composed: true
      })
    );
  }
}