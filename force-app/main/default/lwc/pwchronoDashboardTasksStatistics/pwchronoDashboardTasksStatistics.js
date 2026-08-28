import chartjs from "@salesforce/resourceUrl/chartjs";
import getTaskStatistics from "@salesforce/apex/PWChrono_AdminController.getTaskStatistics";
import { logError } from "c/pwchronoErrorHandler";
import { loadScript } from "lightning/platformResourceLoader";
import { LightningElement, api, wire } from "lwc";

export default class PwchronoDashboardTasksStatistics extends LightningElement {
  static renderMode = "light";

  chart;
  chartjsLoaded = false;
  chartCtor;
  _chartData = [];

  // Normalized counts for the Sample.html layout
  counts = {
    ongoing: 0,
    onHold: 0,
    overdue: 0,
    completed: 0
  };

  // If a parent provides explicit chartData, we still support it.

  @api
  get chartData() {
    return this._chartData;
  }
  set chartData(value) {
    this._chartData = value || [];
    this.normalizeCountsFromPoints();
    if (this.chartjsLoaded) {
      this.renderChart();
    }
  }

  @wire(getTaskStatistics)
  wiredTaskStatistics({ error, data }) {
    if (Array.isArray(data)) {
      this._chartData = data;
      this.normalizeCountsFromPoints();
      if (this.chartjsLoaded) {
        this.renderChart();
      }
    } else if (error) {
      logError("pwchronoDashboardTasksStatistics.wiredTaskStatistics", error);
      this._chartData = [];
      this.normalizeCountsFromPoints();
    }
  }

  disconnectedCallback() {
    if (this.chart) {
      this.chart.destroy();
    }
  }

  renderedCallback() {
    if (this.chartjsLoaded) return;
    this.chartjsLoaded = true;
    loadScript(this, chartjs)
      .then(() => {
        this.chartCtor = this.resolveChartCtor();
        this.renderChart();
      })
      .catch((error) => {
        logError(
          "pwchronoDashboardTasksStatistics: Error loading Chart.js",
          error
        );
      });
  }

  resolveChartCtor() {
    const g = globalThis;
    const w = g?.window ?? g;
    const candidates = [
      g?.Chart,
      w?.Chart,
      g?.Chart?.Chart,
      g?.Chart?.default,
      w?.Chart?.Chart,
      w?.Chart?.default
    ];
    return candidates.find((c) => typeof c === "function" && !!c.prototype);
  }

  normalizeCountsFromPoints() {
    const points = Array.isArray(this._chartData) ? this._chartData : [];

    const byKey = new Map();
    points.forEach((p) => {
      const raw = (p?.label ?? "").toString().trim();
      if (!raw) return;
      const v = Number(p?.value ?? 0);
      byKey.set(raw.toLowerCase(), Number.isFinite(v) ? v : 0);
    });

    const getAny = (keys) =>
      keys.reduce((sum, k) => sum + (byKey.get(k) ?? 0), 0);

    const completed = getAny(["completed", "complete", "done"]);
    const overdue = getAny(["overdue"]);
    const onHold = getAny(["on hold", "hold", "paused"]);
    const total = Array.from(byKey.values()).reduce((s, v) => s + v, 0);
    const ongoing = Math.max(0, total - completed - overdue - onHold);

    this.counts = { ongoing, onHold, overdue, completed };
  }

  get totalCount() {
    const c = this.counts;
    return (
      (c?.ongoing ?? 0) +
      (c?.onHold ?? 0) +
      (c?.overdue ?? 0) +
      (c?.completed ?? 0)
    );
  }

  pct(part) {
    const t = this.totalCount;
    const p = Number(part ?? 0);
    if (!t || !Number.isFinite(p)) return 0;
    return Math.round((p / t) * 100);
  }

  get ongoingPct() {
    return this.pct(this.counts?.ongoing);
  }
  get onHoldPct() {
    return this.pct(this.counts?.onHold);
  }
  get overduePct() {
    return this.pct(this.counts?.overdue);
  }
  get completedPct() {
    return this.pct(this.counts?.completed);
  }

  get totalTasksDisplay() {
    return `${this.counts?.completed ?? 0}/${this.totalCount}`;
  }

  get summaryLine() {
    // Keep the same visual slot as the sample without inventing hours.
    return `${this.counts?.completed ?? 0}/${this.totalCount} tasks`;
  }

  renderChart() {
    const canvas = this.querySelector("canvas.chart");
    if (!canvas) return;

    // Prepare data
    // Expecting _chartData to be [{ label: '...', count: 10 }, ...] (from Apex ChartPoint wrapper? No, Apex returns wrapper with label, value/count)
    // Apex Wrapper: public String label; public Integer value;
    // LWC sees { label: '...', value: ... }

    const labels = ["Ongoing", "On Hold", "Overdue", "Completed"];
    const data = [
      this.counts?.ongoing ?? 0,
      this.counts?.onHold ?? 0,
      this.counts?.overdue ?? 0,
      this.counts?.completed ?? 0
    ];

    // Color mapping
    const colorMap = {
      Ongoing: "#FFC107",
      "On Hold": "#0dcaf0",
      Overdue: "#dc3545",
      Completed: "#198754",
      "In Progress": "#FFC107",
      New: "#6f42c1"
    };
    const defaultColors = ["#fd7e14", "#20c997", "#0d6efd", "#6610f2"];

    const backgroundColors = labels.map(
      (l, i) => colorMap[l] || defaultColors[i % defaultColors.length]
    );

    // Destroy existing chart if updating
    if (this.chart) {
      this.chart.destroy();
    }

    const ChartCtor = this.chartCtor || this.resolveChartCtor();
    if (!ChartCtor) return;

    const ctx = canvas.getContext("2d");
    this.chart = new ChartCtor(ctx, {
      type: "doughnut",
      data: {
        labels: labels,
        datasets: [
          {
            data: data,
            backgroundColor: backgroundColors,
            borderWidth: 0,
            cutout: "85%"
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        circumference: 180,
        rotation: -90,
        plugins: {
          legend: { display: false },
          tooltip: { enabled: true }
        }
      }
    });
  }
}