import getInvoices from "@salesforce/apex/PWChrono_AdminController.getInvoices";
import { logError } from "c/pwchronoErrorHandler";
import { LightningElement, track, wire } from "lwc";

export default class PwchronoDashboardInvoicesTable extends LightningElement {
  static renderMode = "light";

  @track invoices = [];

  @wire(getInvoices)
  wiredInvoices({ error, data }) {
    if (Array.isArray(data)) {
      this.invoices = data.map((inv) => this.mapInvoice(inv));
    } else if (error) {
      logError("pwchronoDashboardInvoicesTable.wiredInvoices", error);
      this.invoices = [];
    }
  }

  get showEmptyState() {
    return !this.invoices || this.invoices.length === 0;
  }

  mapInvoice(inv) {
    const statusRaw = (inv?.Status__c || "").toString().trim();
    const status = statusRaw || "—";

    let badgeClass =
      "badge badge-secondary-transparent badge-xs d-inline-flex align-items-center";
    if (/paid/i.test(statusRaw)) {
      badgeClass =
        "badge badge-success-transparent badge-xs d-inline-flex align-items-center";
    } else if (/unpaid|overdue/i.test(statusRaw)) {
      badgeClass =
        "badge badge-danger-transparent badge-xs d-inline-flex align-items-center";
    }

    const title =
      (inv?.Description__c || "").toString().trim() ||
      (inv?.Name || "").toString().trim() ||
      "Invoice";

    const invoiceId = (inv?.Name || "").toString().trim();
    const client = (inv?.Account__r?.Name || "").toString().trim() || "—";

    const amountNumber = Number(inv?.Amount__c);
    const amount = Number.isFinite(amountNumber)
      ? new Intl.NumberFormat(undefined, {
          style: "currency",
          currency: "USD",
          maximumFractionDigits: 0
        }).format(amountNumber)
      : "—";

    return {
      id: inv?.Id,
      title,
      invoiceId: invoiceId ? `#${invoiceId}` : "—",
      client,
      amount,
      status,
      badgeClass,
      avatarUrl: "",
      initials: this.getInitials(client || title)
    };
  }

  getInitials(name) {
    const n = (name || "").toString().trim();
    if (!n) return "";
    const parts = n.split(/\s+/).filter(Boolean);
    const first = parts[0]?.[0] || "";
    const last = parts.length > 1 ? parts[parts.length - 1]?.[0] || "" : "";
    return (first + last).toUpperCase();
  }
}