import { LightningElement } from "lwc";
import { loadScript } from "lightning/platformResourceLoader";

import smarthrAssets from "@salesforce/resourceUrl/smarthr_assets";
import chartjs from "@salesforce/resourceUrl/chartjs";
import getDashboardSummary from "@salesforce/apex/PWChrono_PayrollDashboardController.getDashboardSummary";
import {
  initBootstrapCompat,
  teardownBootstrapCompat
} from "c/pwchronoBootstrapCompat";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";

export default class PwchronoPayrollDashboard extends LightningElement {
  assetsBase = smarthrAssets;

  _isInitialized = false;
  _charts = [];
  summary;
  _summaryLoaded = false;
  _loading = false;

  employeeId = getEmployeeId();
  sessionToken = getSessionToken();
  _sessionChangedHandler;

  get bg04() {
    return `${this.assetsBase}/assets/img/bg/bg-04.png`;
  }

  connectedCallback() {
    this._sessionChangedHandler = () => {
      this.employeeId = getEmployeeId();
      this.sessionToken = getSessionToken();
      this.loadSummary();
    };
    try {
      window.addEventListener(SESSION_CHANGED_EVENT, this._sessionChangedHandler);
    } catch (e) {
      // ignore
    }
    this.loadSummary();
  }

  async loadSummary() {
    if (this._loading) return;
    this._loading = true;
    try {
      this.summary = await getDashboardSummary({
        portalUserId: this.employeeId,
        sessionToken: this.sessionToken
      });
      this._summaryLoaded = true;
      if (this._isInitialized) {
        this.initCharts();
      }
    } catch {
      this.summary = undefined;
      this._summaryLoaded = false;
    } finally {
      this._loading = false;
    }
  }

  money(value) {
    const n = Number(value ?? 0);
    const safe = Number.isFinite(n) ? n : 0;
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      maximumFractionDigits: 0
    }).format(safe);
  }

  get totalGrossFormatted() {
    return this.money(this.summary?.totalGross ?? 0);
  }
  get totalNetFormatted() {
    return this.money(this.summary?.totalNet ?? 0);
  }
  get totalDeductionsFormatted() {
    return this.money(this.summary?.totalDeductions ?? 0);
  }
  get highestGrossFormatted() {
    return this.money(this.summary?.highestGross ?? 0);
  }
  get lowestGrossFormatted() {
    return this.money(this.summary?.lowestGross ?? 0);
  }
  get averageGrossFormatted() {
    return this.money(this.summary?.averageGross ?? 0);
  }

  renderedCallback() {
    initBootstrapCompat(this);

    if (this._isInitialized) return;
    this._isInitialized = true;

    loadScript(this, chartjs)
      .then(() => {
        this.initCharts();
      })
      .catch(() => {
        // Ignore error
      });
  }

  disconnectedCallback() {
    try {
      window.removeEventListener(
        SESSION_CHANGED_EVENT,
        this._sessionChangedHandler
      );
    } catch (e) {
      // ignore
    }
    this._sessionChangedHandler = null;
    this.destroyCharts();
    teardownBootstrapCompat(this);
  }

  destroyCharts() {
    try {
      this._charts.forEach((c) => c && c.destroy && c.destroy());
    } catch {
      // ignore
    }
    this._charts = [];
  }

  initCharts() {
    const Chart = globalThis?.Chart;
    if (!Chart) return;

    this.destroyCharts();

    // Light touch defaults so SmartHR visual remains primary
    Chart.defaults.responsive = true;
    Chart.defaults.maintainAspectRatio = false;
    Chart.defaults.plugins.legend.display = false;

    this._charts.push(this.createSalaryRangeChart());
    this._charts.push(
      this.createBatchSparkline(
        "batchProcessChart1",
        [10, 14, 13, 18, 16, 20, 19]
      )
    );
    this._charts.push(
      this.createBatchSparkline("batchProcessChart2", [4, 6, 7, 8, 7, 9, 8])
    );
    this._charts.push(
      this.createBatchSparkline("batchProcessChart3", [5, 7, 8, 9, 9, 10, 11])
    );

    this._charts.push(this.createTrendChart());

    this._charts.push(
      this.createMiniBars("insuranceMiniChart", [3, 5, 4, 6, 5, 7, 6])
    );
    this._charts.push(
      this.createMiniBars("contributionMiniChart", [2, 3, 3, 4, 4, 5, 4])
    );
    this._charts.push(
      this.createMiniBars("healthMiniChart", [2, 2, 3, 3, 4, 4, 5])
    );
  }

  getCanvas(id) {
    return this.template.querySelector(`canvas#${id}`);
  }

  createSalaryRangeChart() {
    const canvas = this.getCanvas("salaryRangeChart");
    if (!canvas) return null;

    // match template height
    if (canvas.parentElement) canvas.parentElement.style.height = "255px";

    const labels = this.summary?.salaryRangeLabels || [
      "$10k-$25k",
      "$25k-$50k",
      "$50k-$75k",
      "$75k-$100k",
      "$100k+"
    ];
    const values = this.summary?.salaryRangeCounts || [120, 240, 400, 180, 60];

    return new globalThis.Chart(canvas.getContext("2d"), {
      type: "bar",
      data: {
        labels,
        datasets: [
          {
            label: "Employees",
            data: values,
            borderWidth: 0,
            borderRadius: 10,
            barThickness: 24
          }
        ]
      },
      options: {
        scales: {
          x: { grid: { display: false } },
          y: { beginAtZero: true }
        }
      }
    });
  }

  createBatchSparkline(canvasId, points) {
    const canvas = this.getCanvas(canvasId);
    if (!canvas) return null;

    if (canvas.parentElement) canvas.parentElement.style.height = "45px";

    return new globalThis.Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels: points.map((_, i) => `${i + 1}`),
        datasets: [
          {
            data: points,
            borderWidth: 2,
            tension: 0.35,
            pointRadius: 0,
            fill: true
          }
        ]
      },
      options: {
        plugins: { tooltip: { enabled: false } },
        scales: {
          x: { display: false, grid: { display: false } },
          y: { display: false, grid: { display: false } }
        }
      }
    });
  }

  createTrendChart() {
    const canvas = this.getCanvas("taxDeductionTrendChart");
    if (!canvas) return null;

    if (canvas.parentElement) canvas.parentElement.style.height = "220px";

    const labels = this.summary?.trendLabels || [
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
      "Jan"
    ];
    const tax = this.summary?.taxTrend || [120, 118, 122, 110, 108, 112];
    const deduction = this.summary?.deductionTrend || [90, 92, 93, 88, 85, 89];

    return new globalThis.Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            label: "Tax",
            data: tax,
            borderWidth: 2,
            tension: 0.35,
            pointRadius: 2,
            fill: false
          },
          {
            label: "Deduction",
            data: deduction,
            borderWidth: 2,
            tension: 0.35,
            pointRadius: 2,
            fill: false
          }
        ]
      },
      options: {
        scales: {
          x: { grid: { display: false } },
          y: { beginAtZero: false }
        }
      }
    });
  }

  createMiniBars(canvasId, points) {
    const canvas = this.getCanvas(canvasId);
    if (!canvas) return null;

    if (canvas.parentElement) canvas.parentElement.style.height = "40px";

    return new globalThis.Chart(canvas.getContext("2d"), {
      type: "bar",
      data: {
        labels: points.map((_, i) => `${i + 1}`),
        datasets: [
          {
            data: points,
            borderWidth: 0,
            borderRadius: 8,
            barThickness: 6
          }
        ]
      },
      options: {
        plugins: { tooltip: { enabled: false } },
        scales: {
          x: { display: false, grid: { display: false } },
          y: { display: false, grid: { display: false } }
        }
      }
    });
  }
}