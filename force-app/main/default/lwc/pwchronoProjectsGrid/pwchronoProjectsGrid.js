import { LightningElement } from "lwc";
import listRecords from "@salesforce/apex/PWChrono_PortalApi.getProjectOpportunities";
import getDetail from "@salesforce/apex/PWChrono_PortalApi.getProjectOpportunity";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
export default class PwchronoProjectsGrid extends LightningElement {
  static renderMode = "light";
  records = [];
  total = 0;
  stages = [];
  search = "";
  stage = "";
  loading = true;
  error = "";
  authorized = false;
  hasMore = false;
  selected;
  detailLoading = false;
  detailError = "";
  request = 0;
  detailRequest = 0;
  refreshSession = () => {
    this.authorized = false;
    this.records = [];
    this.closeDetails();
    this.load();
  };
  connectedCallback() {
    window.addEventListener(SESSION_CHANGED_EVENT, this.refreshSession);
    this.load();
  }
  disconnectedCallback() {
    window.removeEventListener(SESSION_CHANGED_EVENT, this.refreshSession);
    this.request++;
    this.detailRequest++;
  }
  get credentials() {
    return { portalUserId: getEmployeeId(), sessionToken: getSessionToken() };
  }
  get hasRecords() {
    return this.records.length > 0;
  }
  get empty() {
    return !this.loading && !this.error && !this.hasRecords;
  }
  get shown() {
    return this.records.length;
  }
  get showDialog() {
    return this.detailLoading || this.selected || this.detailError;
  }
  get stageOptions() {
    return [
      { label: "All stages", value: "" },
      ...this.stages.map((value) => ({ label: value, value }))
    ];
  }
  async load(more = false) {
    const request = ++this.request;
    this.loading = true;
    this.error = "";
    if (!more) this.records = [];
    try {
      const result = await listRecords({
        ...this.credentials,
        searchTerm: this.search,
        stage: this.stage,
        afterId: more ? this.records.at(-1)?.Id : null
      });
      if (request !== this.request) return;
      this.authorized = true;
      const rows = result.records.map((row) => ({
        ...row,
        accountName: row.Account?.Name || "No account",
        ownerName: row.Owner?.Name || "Unassigned",
        badge: row.IsWon
          ? "stage won"
          : row.IsClosed
            ? "stage closed"
            : "stage open"
      }));
      this.records = more ? [...this.records, ...rows] : rows;
      this.total = result.total;
      this.stages = result.stages;
      this.hasMore = result.hasMore;
    } catch (error) {
      if (request === this.request) {
        this.error =
          error?.body?.message ||
          error?.message ||
          "Unable to load opportunities.";
        this.records = [];
        this.total = 0;
        this.hasMore = false;
        this.authorized = false;
      }
    } finally {
      if (request === this.request) this.loading = false;
    }
  }
  handleSearch(event) {
    this.search = event.target.value;
  }
  handleStage(event) {
    this.stage = event.detail.value;
    this.load();
  }
  handleSubmit(event) {
    event.preventDefault();
    this.load();
  }
  refresh() {
    this.load();
  }
  loadMore() {
    this.load(true);
  }
  async openDetails(event) {
    const request = ++this.detailRequest;
    this.returnFocus = event.currentTarget;
    this.detailLoading = true;
    this.detailError = "";
    this.selected = null;
    try {
      const record = await getDetail({
        ...this.credentials,
        opportunityId: event.currentTarget.dataset.id
      });
      if (request === this.detailRequest)
        this.selected = {
          ...record,
          accountName: record.Account?.Name || "No account",
          ownerName: record.Owner?.Name || "Unassigned",
          description: record.Description || "No description provided.",
          nextStep: record.NextStep || "Not specified"
        };
    } catch (error) {
      if (request === this.detailRequest)
        this.detailError =
          error?.body?.message ||
          error?.message ||
          "Unable to load opportunity.";
    } finally {
      if (request === this.detailRequest) this.detailLoading = false;
    }
  }
  renderedCallback() {
    if (this.showDialog && !this.dialogFocused) {
      this.querySelector(".close-detail")?.focus();
      this.dialogFocused = true;
    }
  }
  closeDetails() {
    this.detailRequest++;
    this.selected = null;
    this.detailLoading = false;
    this.detailError = "";
    this.dialogFocused = false;
    this.returnFocus?.focus();
  }
  handleDialogKey(event) {
    if (event.key === "Escape") this.closeDetails();
    if (event.key === "Tab") {
      event.preventDefault();
      this.querySelector(".close-detail")?.focus();
    }
  }
}