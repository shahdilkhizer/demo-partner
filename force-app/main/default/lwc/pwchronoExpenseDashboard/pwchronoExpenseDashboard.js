import { LightningElement, track } from "lwc";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import getExpenseDashboardSummary from "@salesforce/apex/PWChrono_ExpenseController.getExpenseDashboardSummary";

const MONTH_NAMES = [
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"
];

export default class PwchronoExpenseDashboard extends LightningElement {
  static renderMode = "light";

  @track isLoading = true;
  @track error = null;
  @track recentClaims = [];
  @track counts = { draft: 0, submitted: 0, approved: 0, rejected: 0, total: 0 };

  currentDate = new Date();
  currentMonth;
  currentYear;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  connectedCallback() {
    this.currentMonth = this.currentDate.getMonth();
    this.currentYear  = this.currentDate.getFullYear();
    this.loadDashboard();
  }

  // ── Data ─────────────────────────────────────────────────────────────────

  loadDashboard() {
    this.isLoading = true;
    this.error     = null;

    const firstDay  = new Date(this.currentYear, this.currentMonth, 1);
    const lastDay   = new Date(this.currentYear, this.currentMonth + 1, 0);

    getExpenseDashboardSummary({
      startDate:    this.formatDate(firstDay),
      endDate:      this.formatDate(lastDay),
      employeeId:   this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((summary) => {
        this.counts = {
          draft:     summary?.draftCount     || 0,
          submitted: summary?.submittedCount || 0,
          approved:  summary?.approvedCount  || 0,
          rejected:  summary?.rejectedCount  || 0,
          total:     summary?.totalClaims    || 0
        };
        this.recentClaims = summary?.recentClaims || [];
      })
      .catch((err) => {
        this.error = err?.body?.message || err?.message || "Error loading expense data.";
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  get monthLabel() {
    return `${MONTH_NAMES[this.currentMonth]} ${this.currentYear}`;
  }

  get skeletonRange() {
    return [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }];
  }

  get hasRecentClaims() {
    return this.recentClaims && this.recentClaims.length > 0;
  }

  // ── Month navigation ──────────────────────────────────────────────────────

  handlePrevMonth() {
    if (this.currentMonth === 0) {
      this.currentMonth = 11;
      this.currentYear--;
    } else {
      this.currentMonth--;
    }
    this.loadDashboard();
  }

  handleNextMonth() {
    if (this.currentMonth === 11) {
      this.currentMonth = 0;
      this.currentYear++;
    } else {
      this.currentMonth++;
    }
    this.loadDashboard();
  }

  // ── User actions ──────────────────────────────────────────────────────────

  handleNewClaim() {
    this.dispatchEvent(new CustomEvent("newclaim", { bubbles: true, composed: true }));
  }

  handleViewAll() {
    this.dispatchEvent(new CustomEvent("viewall", { bubbles: true, composed: true }));
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

  formatDate(d) {
    const yyyy = d.getFullYear();
    const mm   = String(d.getMonth() + 1).padStart(2, "0");
    const dd   = String(d.getDate()).padStart(2, "0");
    return `${yyyy}-${mm}-${dd}`;
  }
}