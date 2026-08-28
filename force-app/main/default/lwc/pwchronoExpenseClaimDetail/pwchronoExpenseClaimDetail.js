import { LightningElement, api, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getEmployeeId, getSessionToken } from "c/pwchronoSession";
import getExpenseClaimDetail from "@salesforce/apex/PWChrono_ExpenseController.getExpenseClaimDetail";
import getExpenseComments from "@salesforce/apex/PWChrono_ExpenseController.getExpenseComments";
import getExpenseFiles from "@salesforce/apex/PWChrono_ExpenseController.getExpenseFiles";
import addExpenseComment from "@salesforce/apex/PWChrono_ExpenseController.addExpenseComment";
import uploadExpenseFile from "@salesforce/apex/PWChrono_ExpenseController.uploadExpenseFile";
import processExpenseClaimApproval from "@salesforce/apex/PWChrono_ExpenseController.processExpenseClaimApproval";
import cancelExpenseClaim from "@salesforce/apex/PWChrono_ExpenseController.cancelExpenseClaim";
import submitExpenseClaim from "@salesforce/apex/PWChrono_ExpenseController.submitExpenseClaim";

export default class PwchronoExpenseClaimDetail extends LightningElement {
  static renderMode = "light";

  _claimId;

  @api
  get claimId() {
    return this._claimId;
  }
  set claimId(value) {
    this._claimId = value;
    if (value && this.employeeId && this.sessionToken) {
      this.loadDetail();
    }
  }

  @track isLoading = true;
  @track loadError = null;
  @track claim = null;
  @track lineItems = [];
  @track comments = [];
  @track files = [];

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();

  connectedCallback() {
    if (this.claimId) {
      this.loadDetail();
    }
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  async loadDetail() {
    this.isLoading = true;
    this.loadError = null;
    try {
      const [claim, comments, files] = await Promise.all([
        getExpenseClaimDetail({
          claimId: this.claimId,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        }),
        getExpenseComments({
          claimId: this.claimId,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        }),
        getExpenseFiles({
          claimId: this.claimId,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        })
      ]);

      this.claim = claim;
      this.comments = comments || [];
      this.files = files || [];

      // Map sub-queried items → editor DTO format for read-only display
      const rawItems = claim?.Expense_Items__r || [];
      this.lineItems = rawItems.map((item) => ({
        itemId: item.Id,
        expenseDate: item.Date__c,
        itemType: item.Type__c,
        description: item.Description__c || "",
        merchant: item.Merchant__c || "",
        amount: item.Amount__c,
        receiptReference: item.Receipt_Reference__c || ""
      }));
    } catch (err) {
      this.loadError =
        err?.body?.message || err?.message || "Failed to load claim details.";
    } finally {
      this.isLoading = false;
    }
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  get hasData() {
    return !this.isLoading && !this.loadError && this.claim;
  }
  get hasItems() {
    return this.lineItems && this.lineItems.length > 0;
  }
  get hasFiles() {
    return this.files && this.files.length > 0;
  }
  get claimName() {
    return this.claim?.Name || "";
  }
  get claimStatus() {
    return this.claim?.Status__c || "";
  }

  get employeeName() {
    return this.claim?.Employees__r?.Name || "";
  }
  get approverName() {
    return this.claim?.Approvers__r?.Name || "—";
  }
  get claimDate() {
    return this.claim?.Claim_Date__c || "";
  }
  get appliedDate() {
    return this.claim?.Applied_Date__c || "";
  }
  get approvalDate() {
    return this.claim?.Approval_Date__c || null;
  }
  get description() {
    return this.claim?.Description__c || "";
  }
  get businessPurpose() {
    return this.claim?.Business_Purpose__c || "";
  }
  get totalAmount() {
    return this.claim?.Total_Amount__c || 0;
  }
  get rejectionReason() {
    return this.claim?.Rejection_Reason__c || null;
  }
  get cancelledReason() {
    return this.claim?.Cancelled_Reason__c || null;
  }
  get approverComments() {
    return this.claim?.Approver_Comments__c || null;
  }

  get isOwner() {
    return this.claim?.Employees__c === this.employeeId;
  }
  get isApprover() {
    return this.claim?.Approvers__c === this.employeeId;
  }
  get canComment() {
    return this.isOwner || this.isApprover;
  }
  get canUploadFiles() {
    return this.isOwner;
  }

  get canEdit() {
    const s = this.claim?.Status__c;
    return this.isOwner && (s === "Draft" || s === "Rejected");
  }

  get canResubmit() {
    return this.isOwner && this.claim?.Status__c === "Draft";
  }

  // Timeline from comments
  get timelineEntries() {
    if (this.comments?.length) {
      return this.comments.map((c) => ({
        key: c.commentId,
        authorName: c.authorName,
        text: c.text,
        displayDate: this.fmtDateTime(c.createdDate),
        type: c.commentType === "Comment" ? "Comment" : "System"
      }));
    }
    const entries = [];
    if (this.appliedDate) {
      entries.push({
        key: "submit-fallback",
        authorName: this.employeeName,
        text: `Expense claim submitted.`,
        displayDate: this.appliedDate,
        type: "System"
      });
    }
    return entries;
  }

  // ── Action handlers ───────────────────────────────────────────────────────

  async handleRequestAction(event) {
    const { action, comments } = event.detail;
    this.isLoading = true;

    try {
      if (action === "Cancel") {
        await cancelExpenseClaim({
          claimId: this.claimId,
          cancelReason: comments,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        });
        this.showToast("Success", "Expense claim cancelled.", "success");
      } else {
        await processExpenseClaimApproval({
          claimId: this.claimId,
          action,
          comments,
          employeeId: this.employeeId,
          sessionToken: this.sessionToken
        });
        const label = action === "Approve" ? "approved" : "rejected";
        this.showToast("Success", `Expense claim ${label}.`, "success");
      }
      await this.loadDetail();
      this.dispatchEvent(
        new CustomEvent("claimactioned", { bubbles: true, composed: true })
      );
    } catch (err) {
      this.showToast(
        "Error",
        err?.body?.message || err?.message || "Action failed.",
        "error"
      );
      this.isLoading = false;
    }
  }

  handleEdit() {
    this.dispatchEvent(
      new CustomEvent("editclaim", {
        detail: { claimId: this.claimId },
        bubbles: true,
        composed: true
      })
    );
  }

  async handleResubmit() {
    this.isLoading = true;
    try {
      await submitExpenseClaim({
        claimId: this.claimId,
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      this.showToast("Submitted", "Claim submitted for approval.", "success");
      await this.loadDetail();
    } catch (err) {
      this.showToast(
        "Error",
        err?.body?.message || err?.message || "Submit failed.",
        "error"
      );
      this.isLoading = false;
    }
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  async handleNewComment(event) {
    try {
      await addExpenseComment({
        claimId: this.claimId,
        commentText: event.detail?.text,
        employeeId: this.employeeId,
        sessionToken: this.sessionToken
      });
      await this.loadDetail();
    } catch (err) {
      this.showToast(
        "Error",
        err?.body?.message || err?.message || "Comment failed.",
        "error"
      );
    }
  }

  // ── File upload ───────────────────────────────────────────────────────────

  async handleFilesSelected(event) {
    const files = event.detail?.files || [];
    if (!files.length) {
      return;
    }
    this.isLoading = true;
    try {
      await Promise.all(
        Array.from(files).map(async (file) => {
          const base64Data = await this.readFileAsBase64(file);
          return uploadExpenseFile({
            claimId: this.claimId,
            fileName: file.name,
            base64Data,
            contentType: file.type || "",
            employeeId: this.employeeId,
            sessionToken: this.sessionToken
          });
        })
      );
      this.showToast(
        "Uploaded",
        "Attachment(s) uploaded successfully.",
        "success"
      );
      await this.loadDetail();
    } catch (err) {
      this.showToast(
        "Error",
        err?.body?.message || err?.message || "Upload failed.",
        "error"
      );
      this.isLoading = false;
    }
  }

  // ── Back ──────────────────────────────────────────────────────────────────

  handleBack() {
    this.dispatchEvent(
      new CustomEvent("back", { bubbles: true, composed: true })
    );
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const parts =
          typeof reader.result === "string" ? reader.result.split(",") : [];
        resolve(parts.length > 1 ? parts[1] : "");
      };
      reader.onerror = () =>
        reject(reader.error || new Error("File read failed"));
      reader.readAsDataURL(file);
    });
  }

  fmtDateTime(value) {
    if (!value) {
      return "";
    }
    try {
      return new Intl.DateTimeFormat("en", {
        year: "numeric",
        month: "short",
        day: "2-digit",
        hour: "2-digit",
        minute: "2-digit"
      }).format(new Date(value));
    } catch {
      return value;
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}