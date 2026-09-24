// Option constants for Probation Management. Records, employees and reviewers
// always come from PWChrono_ProbationController; nothing here is sample data.

export const STATUS = {
  PENDING: "Pending",
  IN_REVIEW: "In Review",
  EXTENDED: "Extended",
  COMPLETED: "Completed",
  FAILED: "Failed"
};

/** Stages that can still be edited or decided. */
export const OPEN_STATUSES = [
  STATUS.PENDING,
  STATUS.IN_REVIEW,
  STATUS.EXTENDED
];

/** Stages an administrator may delete. */
export const DELETABLE_STATUSES = [STATUS.PENDING, STATUS.IN_REVIEW];

/** Portal roles treated as administrators in the UI (the server decides). */
export const ADMIN_ROLES = ["HR Admin", "System Administrator", "System Admin"];

const BADGE_BASE = "d-inline-flex align-items-center badge-xs badge";
export const STATUS_BADGE_CLASSES = {
  [STATUS.PENDING]: `${BADGE_BASE} badge-soft-info`,
  [STATUS.IN_REVIEW]: `${BADGE_BASE} badge-soft-warning`,
  [STATUS.EXTENDED]: `${BADGE_BASE} badge-soft-secondary`,
  [STATUS.COMPLETED]: `${BADGE_BASE} badge-soft-success`,
  [STATUS.FAILED]: `${BADGE_BASE} badge-soft-danger`
};

export const SORT_OPTIONS = [
  { value: "endAsc", label: "End date (soonest)" },
  { value: "nameAsc", label: "Name A-Z" },
  { value: "nameDesc", label: "Name Z-A" }
];

/** Administrator decisions offered for an open probation. */
export const STATUS_ACTIONS = {
  review: {
    status: STATUS.IN_REVIEW,
    title: "Start Review",
    message: "Move this probation to In Review.",
    confirmLabel: "Start Review",
    buttonClass: "btn btn-primary"
  },
  extend: {
    status: STATUS.EXTENDED,
    title: "Extend Probation",
    message: "Choose a new end date later than the current one.",
    confirmLabel: "Extend",
    buttonClass: "btn btn-primary",
    needsEndDate: true
  },
  confirm: {
    status: STATUS.COMPLETED,
    title: "Confirm Employee",
    message:
      "Mark the probation as completed. The confirmation date is set to today and the record can no longer be changed.",
    confirmLabel: "Confirm",
    buttonClass: "btn btn-success"
  },
  fail: {
    status: STATUS.FAILED,
    title: "Mark Probation Failed",
    message:
      "Mark the probation as failed. The record can no longer be changed.",
    confirmLabel: "Mark Failed",
    buttonClass: "btn btn-danger"
  }
};

export const EMPLOYEE_AVATAR_PATH = "/assets/img/users/user-11.jpg";
export const REVIEWER_AVATAR_PATH = "/assets/img/users/user-01.jpg";
export const DEFAULT_PROBATION_DAYS = 90;
export const PAGE_SIZE = 10;