import { LightningElement, track } from "lwc";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import getMyAttendanceRequestList from "@salesforce/apex/PWChrono_AttendanceController.getMyAttendanceRequestList";

const PAGE_SIZE = 10;

export default class PwchronoAttendanceRequestList extends LightningElement {
  static renderMode = "light";

  @track allRequests  = [];
  @track isLoading    = true;
  @track error        = null;
  @track currentPage  = 1;
  @track selectedStatus = "All";
  @track selectedMonth;

  employeeId   = getEmployeeId();
  sessionToken = getSessionToken();

  get statusOptions() {
    const opts = ["All", "Draft", "Submitted", "Approved", "Rejected", "Cancelled"];
    return opts.map((s) => ({
      label: s,
      value: s,
      selected: this.selectedStatus === s
    }));
  }

  get paginatedRequests() {
    const start = (this.currentPage - 1) * PAGE_SIZE;
    return this.allRequests.slice(start, start + PAGE_SIZE);
  }

  get hasRequests() {
    return this.allRequests.length > 0;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.allRequests.length / PAGE_SIZE));
  }

  get showPagination() {
    return this.allRequests.length > PAGE_SIZE;
  }

  get isFirstPage() { return this.currentPage === 1; }
  get isLastPage()  { return this.currentPage >= this.totalPages; }

  get paginationLabel() {
    const start = (this.currentPage - 1) * PAGE_SIZE + 1;
    const end   = Math.min(this.currentPage * PAGE_SIZE, this.allRequests.length);
    return `Showing ${start}–${end} of ${this.allRequests.length}`;
  }

  connectedCallback() {
    // Default to current month
    const now = new Date();
    this.selectedMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
    this.loadRequests();
  }

  loadRequests() {
    this.isLoading = true;
    this.error     = null;

    const { startDate, endDate } = this.monthDateRange();

    getMyAttendanceRequestList({
      statusFilter: this.selectedStatus,
      startDate,
      endDate,
      employeeId:   this.employeeId,
      sessionToken: this.sessionToken
    })
      .then((data) => {
        this.allRequests = data || [];
        this.currentPage = 1;
      })
      .catch((err) => {
        this.error = err?.body?.message || err?.message || "Error loading requests.";
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  monthDateRange() {
    if (!this.selectedMonth) return { startDate: null, endDate: null };
    const [year, month] = this.selectedMonth.split("-").map(Number);
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

  // ── Handlers ──────────────────────────────────────────────────────────────

  handleStatusFilter(event) {
    this.selectedStatus = event.target.value;
    this.loadRequests();
  }

  handleMonthFilter(event) {
    this.selectedMonth = event.target.value;
    this.loadRequests();
  }

  handleRowClick(event) {
    const requestId = event.currentTarget.dataset.id;
    this.dispatchEvent(
      new CustomEvent("viewdetail", {
        detail: { requestId },
        bubbles: true,
        composed: true
      })
    );
  }

  handleRowAction(event) {
    // rowaction from pwchronoRequestListRow — forward up
    this.dispatchEvent(
      new CustomEvent("rowaction", {
        detail: event.detail,
        bubbles: true,
        composed: true
      })
    );
  }

  handleNewRequest() {
    this.dispatchEvent(new CustomEvent("newrequest", { bubbles: true, composed: true }));
  }

  handlePrevPage() {
    if (!this.isFirstPage) this.currentPage--;
  }

  handleNextPage() {
    if (!this.isLastPage) this.currentPage++;
  }
}