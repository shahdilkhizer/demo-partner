import { LightningElement, api, track } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";
import chartjs from "@salesforce/resourceUrl/chartjs";

export default class PwchronoDashboardSalesProjectsSection extends LightningElement {
  @api salesOverview;
  @api projects;
  @track chart;
  chartjsLoaded = false;
  lastSalesSignature;

  /**
   * Clean up Chart.js instance to prevent memory leaks
   */
  disconnectedCallback() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
  }

  renderedCallback() {
    if (!this.chartjsLoaded) {
      this.chartjsLoaded = true;
      loadScript(this, chartjs)
        .then(() => {
          this.tryCreateSalesChart();
        })
        .catch(() => {
          /* Chart.js load failed */
        });
      return;
    }
    this.tryCreateSalesChart();
  }

  tryCreateSalesChart() {
    if (!globalThis.Chart) return;
    if (!Array.isArray(this.salesOverview) || this.salesOverview.length === 0)
      return;

    const signature = this.salesOverview
      .map((s) => `${s.label ?? ""}:${s.value ?? ""}`)
      .join("|");

    if (this.chart && signature === this.lastSalesSignature) return;
    this.lastSalesSignature = signature;
    this.createSalesChart();
  }

  createSalesChart() {
    const canvas = this.template.querySelector('[data-chart="sales"]');
    if (
      !canvas ||
      !Array.isArray(this.salesOverview) ||
      this.salesOverview.length === 0
    )
      return;

    if (this.chart) {
      this.chart.destroy();
    }

    const ctx = canvas.getContext("2d");

    const values = this.salesOverview
      .map((s) => Number(s.value))
      .filter((v) => Number.isFinite(v));

    const maxValue = values.length ? Math.max(...values) : 0;
    const stepSize = maxValue <= 50 ? 10 : 20;
    const yMax = Math.max(stepSize, Math.ceil(maxValue / stepSize) * stepSize);

    this.chart = new globalThis.Chart(ctx, {
      type: "bar",
      data: {
        labels: this.salesOverview.map((s) => s.label),
        datasets: [
          {
            label: "Income",
            data: this.salesOverview.map((s) => s.value),
            backgroundColor: "#f97316",
            borderRadius: 6,
            barThickness: 35
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (context) => `Income: $${context.parsed.y}k`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { font: { size: 12 } }
          },
          y: {
            beginAtZero: true,
            max: yMax,
            ticks: {
              stepSize,
              font: { size: 12 },
              callback: (value) => value
            },
            grid: {
              display: true,
              color: "#f3f4f6"
            }
          }
        }
      }
    });
  }

  handleFilterDepartments() {
    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: { page: "sales", filter: "departments" },
        bubbles: true,
        composed: true
      })
    );
  }
}