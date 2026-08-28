import getTasks from "@salesforce/apex/PWChrono_ProjectController.getTasks";
import { getRecord } from "lightning/uiRecordApi";
import { LightningElement, api, wire } from "lwc";

const OPPORTUNITY_FIELDS = [
  "Opportunity.Name",
  "Opportunity.CloseDate",
  "Opportunity.Amount",
  "Opportunity.OwnerId"
];

export default class PwChronoProjectDetails extends LightningElement {
  @api recordId;

  @wire(getRecord, { recordId: "$recordId", fields: OPPORTUNITY_FIELDS })
  project;

  @wire(getTasks, { projectId: "$recordId" })
  tasks;

  get tasksList() {
    return this.tasks?.data ?? [];
  }

  get hasTasks() {
    return this.tasksList.length > 0;
  }

  get projectErrorMessage() {
    return this.normalizeWireError(this.project?.error);
  }

  get tasksErrorMessage() {
    return this.normalizeWireError(this.tasks?.error);
  }

  handleBack(event) {
    // Keep navigation simple and framework-agnostic.
    // Works in Experience Cloud and Lightning as a fallback.
    event?.preventDefault?.();
    globalThis.history?.back?.();
  }

  normalizeWireError(error) {
    if (!error) return "";

    // LDS/UI API errors often show up as { body: { message } } or { body: [ { message } ] }
    const body = error?.body;
    if (typeof body === "string") return body;
    if (Array.isArray(body)) {
      return body
        .map((e) => e?.message)
        .filter(Boolean)
        .join("; ");
    }
    if (typeof body?.message === "string") return body.message;
    if (typeof error?.message === "string") return error.message;

    try {
      return JSON.stringify(error);
    } catch {
      // no-op, use fallback
    }
    return "Unknown error";
  }
}