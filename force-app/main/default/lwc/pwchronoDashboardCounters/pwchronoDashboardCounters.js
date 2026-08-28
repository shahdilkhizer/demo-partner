import { LightningElement, api } from "lwc";

export default class PwchronoDashboardCounters extends LightningElement {
  @api showBanner = false;

  @api userName;
  @api pendingApprovals;
  @api leaveRequests;
  @api employeesByDepartment = [];
  @api employeeTrend;

  @api cards = [];

  get gridClass() {
    const base = "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6";
    return this.showBanner ? `${base} mt-6` : base;
  }

  get normalizedCards() {
    return Array.isArray(this.cards) ? this.cards : [];
  }
}