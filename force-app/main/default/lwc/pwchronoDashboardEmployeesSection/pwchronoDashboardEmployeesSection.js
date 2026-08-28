import { LightningElement, api } from "lwc";

export default class PwchronoDashboardEmployeesSection extends LightningElement {
  @api employeesByDepartment;
  @api employeeTrend;

  get hasEmployeeTrend() {
    return !!this.employeeTrend;
  }

  get employeeTrendIsPositive() {
    const t = (this.employeeTrend || "").toString().trim();
    return !t.startsWith("-");
  }

  get employeeTrendIcon() {
    return this.employeeTrendIsPositive ? "↗" : "↘";
  }

  get employeeTrendIconClass() {
    return this.employeeTrendIsPositive
      ? "text-success me-1"
      : "text-danger me-1";
  }

  get employeeTrendValueClass() {
    return this.employeeTrendIsPositive
      ? "text-success fw-bold"
      : "text-danger fw-bold";
  }

  get departmentData() {
    if (
      !Array.isArray(this.employeesByDepartment) ||
      this.employeesByDepartment.length === 0
    ) {
      return [];
    }

    const maxCount = Math.max(
      ...this.employeesByDepartment.map((d) => d.value || 0),
      1
    );
    return this.employeesByDepartment.map((dept) => {
      const percent = Math.max(
        0,
        Math.min(100, Math.round(((dept.value || 0) / maxCount) * 100))
      );
      const widthClass = this.percentToWidthClass(percent);
      return {
        name: dept.label,
        count: dept.value,
        percent,
        widthClass,
        barClass: `${widthClass} progress-bar bg-primary`
      };
    });
  }

  percentToWidthClass(percent) {
    // Avoid inline styles. Use coarse Bootstrap width utility steps.
    if (percent >= 88) return "w-100";
    if (percent >= 63) return "w-75";
    if (percent >= 38) return "w-50";
    if (percent >= 13) return "w-25";
    return "w-0";
  }
}