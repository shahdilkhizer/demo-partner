import { LightningElement, track } from "lwc";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import getMyExpenseClaimList from "@salesforce/apex/PWChrono_ExpenseController.getMyExpenseClaimList";

const PAGE_SIZE = 10;

export default class PwchronoExpenseClaimList extends LightningElement {
  static renderMode = "light";

  @track isLoading = true;
  @track error     = null;
  @track allClaims = [];
  @track claims    = [];
  @track currentPage = 1;

  // Filters
  @track statusFilter = "";
  @track monthFilter  = "";

  employeeId   = getEmployeeId();
  sessionToken = getSessionToken();

  statusOptions = [
    { label: "All Statuses", value: "" },
    { label: "Draft",        value: "Draft" },
    { label: "Submitted",    value: "Submitted" },
    { label: "Approved",     value: "Approved" },
    { label: "Rejected",     value: "Rejected" },
    { label: "Cancelled",    value: "Cancelled" }
  ];

  connectedCallback() {
    this.loadClaims();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  loadClaims() {
    this.isLoading = true;
    this.error     = null;

    const { startDate, endDate } = this.getMonthRange();

    getMyExpenseClaimList({
      statusFilter: this.statusFilter || null,
      startDate,
      endDate,
      employeeId:   this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((data) => {
        this.allClaims = data || [];
        this.currentPage = 1;
        this.applyPage();
      })
      .catch((err) => {
        this.error = err?.body?.message || err?.message || "Error loading claims.";
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  applyPage() {
    const start = (this.currentPage - 1) * PAGE_SIZE;
    this.claims = this.allClaims.slice(start, start + PAGE_SIZE);
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  get totalRecords() { return this.allClaims.length; }
  get totalPages()   { return Math.ceil(this.totalRecords / PAGE_SIZE) || 1; }
  get startRecord()  { return this.totalRecords === 0 ? 0 : (this.currentPage - 1) * PAGE_SIZE + 1; }
  get endRecord()    { return Math.min(this.currentPage * PAGE_SIZE, this.totalRecords); }
  get paginationInfo() { return `${this.startRecord}–${this.endRecord} of ${this.totalRecords}`; }
  get isPrevDisabled() { return this.currentPage <= 1; }
  get isNextDisabled() { return this.currentPage >= this.totalPages; }
  get hasClaims()      { return this.claims && this.claims.length > 0; }
  get hasNoClaims()    { return !this.isLoading && this.claims.length === 0; }

  // ── Filter handlers ───────────────────────────────────────────────────────

  handleStatusFilter(event) {
    this.statusFilter = event.detail.value;
    this.loadClaims();
  }

  handleMonthFilter(event) {
    this.monthFilter = event.target.value;
    this.loadClaims();
  }

  handlePrevPage() {
    if (this.currentPage > 1) { this.currentPage--; this.applyPage(); }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) { this.currentPage++; this.applyPage(); }
  }

  // ── User actions ──────────────────────────────────────────────────────────

  handleNewClaim() {
    this.dispatchEvent(new CustomEvent("newclaim", { bubbles: true, composed: true }));
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

  // ── Utilities ─────────────────────────────────────────────────────────────

  getMonthRange() {
    if (!this.monthFilter) { return { startDate: null, endDate: null }; }
    const [year, month] = this.monthFilter.split("-").map(Number);
    const first = new Date(year, month - 1, 1);
    const last  = new Date(year, month, 0);
    return {
      startDate: this.fmt(first),
      endDate:   this.fmt(last)
    };
  }

  fmt(d) {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
  }
}