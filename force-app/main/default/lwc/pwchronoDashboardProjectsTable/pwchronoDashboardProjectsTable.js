import { refreshApex } from "@salesforce/apex";
import deleteProjectController from "@salesforce/apex/PWChrono_AdminController.deleteProject";
import getProjects from "@salesforce/apex/PWChrono_AdminController.getProjects";
import saveProject from "@salesforce/apex/PWChrono_AdminController.saveProject";
import { logError } from "c/pwchronoErrorHandler";
import {
  getEmployeeId,
  getSessionToken,
  SESSION_CHANGED_EVENT
} from "c/pwchronoSession";
import LightningConfirm from "lightning/confirm";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { LightningElement, track, wire } from "lwc";

export default class PwchronoDashboardProjectsTable extends LightningElement {
  static renderMode = "light";

  @track projects = [];
  @track isLoading = true;
  @track showModal = false;
  @track modalTitle = "Add Project";
  @track currentProject = {};

  portalUserId = getEmployeeId();
  sessionToken = getSessionToken();

  sessionChangedHandler;

  wiredProjectsResult;

  connectedCallback() {
    this.refreshSessionFromStore();

    this.sessionChangedHandler = () => {
      const priorUserId = this.portalUserId;
      const priorToken = this.sessionToken;
      this.refreshSessionFromStore();

      // If session becomes available after initial render, refresh wire.
      if (
        priorUserId !== this.portalUserId ||
        priorToken !== this.sessionToken
      ) {
        refreshApex(this.wiredProjectsResult);
      }
    };

    try {
      const w = globalThis?.window ?? globalThis;
      w?.addEventListener?.(SESSION_CHANGED_EVENT, this.sessionChangedHandler);
    } catch {
      // no-op
    }
  }

  disconnectedCallback() {
    try {
      const w = globalThis?.window ?? globalThis;
      w?.removeEventListener?.(
        SESSION_CHANGED_EVENT,
        this.sessionChangedHandler
      );
    } catch {
      // no-op
    }
    this.sessionChangedHandler = null;
  }

  refreshSessionFromStore() {
    this.portalUserId = getEmployeeId();
    this.sessionToken = getSessionToken();
  }

  @wire(getProjects, {
    portalUserId: "$portalUserId",
    sessionToken: "$sessionToken"
  })
  wiredProjects(result) {
    this.wiredProjectsResult = result;
    const { error, data } = result;
    this.isLoading = false;
    if (Array.isArray(data)) {
      this.projects = data.map((proj) => this.mapRecordToProject(proj));
    } else if (error) {
      logError("pwchronoDashboardProjectsTable.wiredProjects", error);
      this.projects = [];
    }
  }

  mapRecordToProject(proj) {
    const priority = (proj?.Priority__c || "Medium").toString();
    let priorityBadgeClass =
      "badge badge-pink d-inline-flex align-items-center badge-xs";
    if (priority === "High") {
      priorityBadgeClass =
        "badge badge-danger d-inline-flex align-items-center badge-xs";
    } else if (priority === "Low") {
      priorityBadgeClass =
        "badge badge-success d-inline-flex align-items-center badge-xs";
    }

    const totalHours = Number(proj?.Total_Hours__c ?? 0);
    const hoursLogged = Number(proj?.Hours_Logged__c ?? 0);
    const safeTotal =
      Number.isFinite(totalHours) && totalHours > 0 ? totalHours : 0;
    const safeLogged =
      Number.isFinite(hoursLogged) && hoursLogged > 0 ? hoursLogged : 0;
    const progressPct = safeTotal
      ? Math.max(0, Math.min(100, Math.round((safeLogged / safeTotal) * 100)))
      : 0;

    const members = this.parseTeamMembers(proj?.Project_Members__c);
    const teamSizeRaw = Number(proj?.Team_Size__c);
    const teamSize =
      Number.isFinite(teamSizeRaw) && teamSizeRaw > 0
        ? teamSizeRaw
        : members.length;

    const avatarColors = ["bg-primary", "bg-secondary", "bg-success"];
    const teamAvatars = members.slice(0, 3).map((name, idx) => ({
      key: `${proj?.Id || "proj"}-${idx}`,
      title: name,
      text: this.getInitials(name),
      className: `avatar avatar-rounded ${avatarColors[idx % avatarColors.length]} text-fixed-white fs-10 fw-medium border border-white`
    }));

    const moreCount = Math.max(0, (teamSize || 0) - teamAvatars.length);

    return {
      id: proj?.Id,
      code:
        "PRO-" + (proj?.Id ? proj.Id.substring(8, 13).toUpperCase() : "000"),
      name: proj?.Name || "Untitled Project",
      description: (proj?.Description__c || "").toString(),
      date: proj?.End_Date__c
        ? new Date(proj.End_Date__c).toLocaleDateString("en-GB", {
            day: "numeric",
            month: "short",
            year: "numeric"
          })
        : "—",
      hoursText: safeTotal
        ? `${safeLogged}/${safeTotal} Hrs`
        : `${safeLogged} Hrs`,
      progressPct,
      progressWidthStyle: `width: ${progressPct}%`,
      priority,
      priorityBadgeClass,
      teamAvatars,
      hasMoreMembers: moreCount > 0,
      moreCount,
      // Raw fields for editing
      rawStatus: proj?.Status__c,
      rawStartDate: proj?.Start_Date__c,
      rawEndDate: proj?.End_Date__c,
      rawPriority: proj?.Priority__c,
      rawAmount: proj?.Amount__c
    };
  }

  parseTeamMembers(value) {
    const v = (value || "").toString().trim();
    if (!v) return [];
    return v
      .split(/[\n,;]+/)
      .map((s) => s.trim())
      .filter(Boolean);
  }

  getInitials(name) {
    const n = (name || "").toString().trim();
    if (!n) return "";
    const parts = n.split(/\s+/).filter(Boolean);
    if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  handleAddProject() {
    this.currentProject = {
      Name: "",
      Description__c: "",
      Status__c: "Active",
      Priority__c: "Medium",
      Start_Date__c: new Date().toISOString().slice(0, 10),
      End_Date__c: new Date(new Date().setDate(new Date().getDate() + 30))
        .toISOString()
        .slice(0, 10),
      Amount__c: null,
      // Flags for UI state
      isActive: true,
      isCompleted: false,
      isInactive: false
    };
    this.modalTitle = "Add Project";
    this.showModal = true;
  }

  handleEditProject(event) {
    const projectId = event.currentTarget.dataset.id;
    const project = this.projects.find((p) => p.id === projectId);
    if (project) {
      this.currentProject = {
        Id: project.id,
        Name: project.name,
        Description__c: project.description || "",
        Status__c: project.rawStatus || "Active",
        Start_Date__c: project.rawStartDate,
        End_Date__c: project.rawEndDate,
        Priority__c: project.rawPriority || "Medium",
        Amount__c: project.rawAmount,
        // Helper flags
        isActive: project.rawStatus === "Active",
        isCompleted: project.rawStatus === "Completed",
        isInactive: project.rawStatus === "Inactive"
      };
      this.modalTitle = "Edit Project";
      this.showModal = true;
    }
  }

  handleOpenProject(event) {
    if (event && typeof event.preventDefault === "function") {
      event.preventDefault();
    }
    const projectId = event?.currentTarget?.dataset?.id;
    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: { page: "project", id: projectId },
        bubbles: true,
        composed: true
      })
    );
  }

  async handleDeleteProject(event) {
    const result = await LightningConfirm.open({
      message: "Are you sure you want to delete this project?",
      variant: "headerless",
      label: "Delete Project"
    });

    if (!result) return;

    const projectId = event.currentTarget.dataset.id;
    this.isLoading = true;

    deleteProjectController({
      projectId: projectId,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast("Success", "Project deleted successfully", "success");
        return refreshApex(this.wiredProjectsResult);
      })
      .catch((error) => {
        this.showToast(
          "Error",
          "Error deleting project: " + error.body.message,
          "error"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  closeModal() {
    this.showModal = false;
  }

  handleFieldChange(event) {
    const field = event.target.dataset.field;
    this.currentProject[field] = event.target.value;
  }

  saveProject() {
    if (!this.currentProject.Name) {
      this.showToast("Error", "Project Name is required", "error");
      return;
    }

    this.isLoading = true;
    saveProject({
      projectData: this.currentProject,
      portalUserId: this.portalUserId,
      sessionToken: this.sessionToken
    })
      .then(() => {
        this.showToast("Success", "Project saved successfully", "success");
        this.closeModal();
        return refreshApex(this.wiredProjectsResult);
      })
      .catch((error) => {
        this.showToast(
          "Error",
          "Error saving project: " + error.body.message,
          "error"
        );
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title: title,
        message: message,
        variant: variant
      })
    );
  }
}