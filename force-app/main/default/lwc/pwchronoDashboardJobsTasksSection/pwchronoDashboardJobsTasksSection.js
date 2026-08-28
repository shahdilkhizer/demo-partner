import { LightningElement, api } from "lwc";

export default class PwchronoDashboardJobsTasksSection extends LightningElement {
  @api jobApplicants;
  @api todoTasks;

  get hasJobApplicants() {
    return Array.isArray(this.jobApplicants) && this.jobApplicants.length > 0;
  }

  get hasTodoTasks() {
    return Array.isArray(this.todoTasks) && this.todoTasks.length > 0;
  }

  handleTodoToggle(event) {
    const todoId = event.target.dataset.id;
    const todo = this.todoTasks.find((t) => t.id === todoId);
    if (todo) {
      todo.done = event.target.checked;
    }
  }

  handleViewAllApplicants() {
    this.dispatchEvent(
      new CustomEvent("navigate", {
        detail: { page: "job-applicants" },
        bubbles: true,
        composed: true
      })
    );
  }
}