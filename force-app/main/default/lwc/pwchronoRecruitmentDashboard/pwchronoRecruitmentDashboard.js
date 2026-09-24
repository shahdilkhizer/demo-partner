import getDashboardData from "@salesforce/apex/PWChrono_RecruitmentDashboardController.getDashboardData";
import { LightningElement, track } from "lwc";
import { getSession, getSessionToken } from "c/pwchronoSession";

const OFFER_STATUS_BADGE = {
  Pending: "badge bg-warning-subtle text-warning",
  Extended: "badge bg-info-subtle text-info",
  Accepted: "badge bg-success-subtle text-success",
  Declined: "badge bg-danger-subtle text-danger",
  Withdrawn: "badge bg-secondary-subtle text-secondary"
};

const FUNNEL_COLORS = [
  "progress-bar bg-primary",
  "progress-bar bg-info",
  "progress-bar bg-warning",
  "progress-bar bg-success"
];

function toBarChartRows(items) {
  if (!items || items.length === 0) return [];
  const max = Math.max(...items.map((i) => i.count));
  return items.map((i) => {
    const pct = max > 0 ? Math.round((i.count / max) * 100) : 0;
    return { ...i, pct, barStyle: `width:${pct}%` };
  });
}

export default class PwchronoRecruitmentDashboard extends LightningElement {
  static renderMode = "light";

  @track data = null;
  @track isLoading = true;
  @track loadError = "";

  _portalUserId;
  _sessionToken;

  connectedCallback() {
    const session = getSession();
    this._portalUserId = session?.user?.Id ?? null;
    this._sessionToken = getSessionToken();
    this._load();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Load
  // ─────────────────────────────────────────────────────────────────────────

  _load() {
    this.isLoading = true;
    this.loadError = "";
    getDashboardData({
      portalUserId: this._portalUserId,
      sessionToken: this._sessionToken
    })
      .then((result) => {
        // Enrich offer status badges
        const enrichedOffers = (result.offersByStatus || []).map((r) => ({
          ...r,
          badgeClass: OFFER_STATUS_BADGE[r.label] || "badge bg-secondary-subtle text-secondary"
        }));
        this.data = { ...result, offersByStatus: enrichedOffers };
      })
      .catch((err) => {
        this.loadError = err?.body?.message || "Failed to load dashboard data.";
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  handleRefresh() {
    this._load();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Computed — Hiring Funnel
  // ─────────────────────────────────────────────────────────────────────────

  get funnelStages() {
    if (!this.data) return [];
    const stages = [
      { label: "Applied", count: this.data.funnelApplied || 0 },
      { label: "Interview", count: this.data.funnelInterview || 0 },
      { label: "Offer Extended", count: this.data.funnelOffer || 0 },
      { label: "Accepted", count: this.data.funnelAccepted || 0 }
    ];
    const maxCount = stages[0].count || 1;
    return stages.map((s, idx) => {
      const pct = maxCount > 0 ? Math.round((s.count / maxCount) * 100) : 0;
      return {
        ...s,
        pct,
        pctLabel: pct > 8 ? `${pct}%` : "",
        barStyle: `width:${pct}%`,
        barClass: FUNNEL_COLORS[idx] || "progress-bar bg-primary"
      };
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Computed — Bar Charts
  // ─────────────────────────────────────────────────────────────────────────

  get applicantsByStatusChart() {
    return toBarChartRows(this.data?.applicantsByStatus);
  }

  get applicantsBySourceChart() {
    return toBarChartRows(this.data?.applicantsBySource);
  }

  get deptWiseChart() {
    return toBarChartRows(this.data?.deptWiseOpenings);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Computed — has-data guards
  // ─────────────────────────────────────────────────────────────────────────

  get hasApplicantsByStatus() {
    return this.data?.applicantsByStatus?.length > 0;
  }

  get hasApplicantsBySource() {
    return this.data?.applicantsBySource?.length > 0;
  }

  get hasApplicantsByJobOpening() {
    return this.data?.applicantsByJobOpening?.length > 0;
  }

  get hasOffersByStatus() {
    return this.data?.offersByStatus?.length > 0;
  }

  get hasDeptWiseOpenings() {
    return this.data?.deptWiseOpenings?.length > 0;
  }
}