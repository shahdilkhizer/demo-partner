import { LightningElement, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import getPendingApprovals from "@salesforce/apex/PWChrono_ApprovalController.getPendingApprovals";
import processRequest from "@salesforce/apex/PWChrono_ApprovalController.processRequest";

export default class PwchronoManagerApprovalDashboard extends NavigationMixin(
  LightningElement
) {
  @track allApprovals = [];
  @track approvals = [];
  @track isLoading = true;
  wiredApprovalsResult;

  // Pagination
  @track currentPage = 1;
  @track pageSize = 9;

  get pageSizeOptions() {
    return [
      { label: "6 per page", value: "6" },
      { label: "9 per page", value: "9" },
      { label: "18 per page", value: "18" },
      { label: "36 per page", value: "36" }
    ];
  }

  // Modal state
  @track isModalOpen = false;
  @track selectedWorkItemId;
  @track selectedAction; // 'Approve' or 'Reject'
  @track commentValue = "";

  get modalTitle() {
    return this.selectedAction === "Approve"
      ? "Approve Request"
      : "Reject Request";
  }

  get modalButtonLabel() {
    return this.selectedAction === "Approve" ? "Approve" : "Reject";
  }

  get modalButtonVariant() {
    return this.selectedAction === "Approve" ? "brand" : "destructive";
  }

  get hasApprovals() {
    return this.allApprovals && this.allApprovals.length > 0;
  }

  get totalCount() {
    return this.allApprovals.length;
  }

  @wire(getPendingApprovals)
  wiredGetApprovals(result) {
    this.wiredApprovalsResult = result;
    if (result.data) {
      this.allApprovals = result.data;
      this.currentPage = 1;
      this.applyPagination();
      this.isLoading = false;
    } else if (result.error) {
      this.showToast("Error", "Error loading pending approvals", "error");
      this.isLoading = false;
    }
  }

  applyPagination() {
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    this.approvals = this.allApprovals.slice(start, end);
  }

  get totalPages() {
    return Math.ceil(this.allApprovals.length / this.pageSize) || 1;
  }

  get isPrevDisabled() {
    return this.currentPage <= 1;
  }

  get isNextDisabled() {
    return this.currentPage >= this.totalPages;
  }

  get pageInfo() {
    const start = (this.currentPage - 1) * this.pageSize + 1;
    const end = Math.min(
      this.currentPage * this.pageSize,
      this.allApprovals.length
    );
    return `${start}–${end} of ${this.allApprovals.length}`;
  }

  handlePageSizeChange(event) {
    this.pageSize = Number.parseInt(event.detail.value, 10);
    this.currentPage = 1;
    this.applyPagination();
  }

  handlePrevPage() {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.applyPagination();
    }
  }

  handleNextPage() {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
      this.applyPagination();
    }
  }

  handleApprove(event) {
    this.selectedWorkItemId = event.target.dataset.id;
    this.selectedAction = "Approve";
    this.commentValue = "";
    this.isModalOpen = true;
  }

  handleReject(event) {
    this.selectedWorkItemId = event.target.dataset.id;
    this.selectedAction = "Reject";
    this.commentValue = "";
    this.isModalOpen = true;
  }

  handleNavigate(event) {
    event.preventDefault();
    const recordId = event.currentTarget?.dataset?.recordId;
    if (!recordId) return;

    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId,
        actionName: "view"
      }
    });
  }

  closeModal() {
    this.isModalOpen = false;
  }

  handleCommentChange(event) {
    this.commentValue = event.target.value;
  }

  handleProcess() {
    this.isLoading = true;
    this.isModalOpen = false;

    processRequest({
      workItemId: this.selectedWorkItemId,
      action: this.selectedAction,
      comments: this.commentValue
    })
      .then(() => {
        this.showToast(
          "Success",
          `Request ${this.selectedAction}d successfully`,
          "success"
        );
        return refreshApex(this.wiredApprovalsResult);
      })
      .catch((error) => {
        this.showToast("Error", error.body.message, "error");
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleRefresh() {
    this.isLoading = true;
    refreshApex(this.wiredApprovalsResult).finally(() => {
      this.isLoading = false;
    });
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