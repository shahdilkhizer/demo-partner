// Roles the server treats as administrators. The server is authoritative;
// this list only decides which actions the page offers.
export const ADMIN_ROLES = ["HR Admin", "System Administrator", "System Admin"];

// Default notice length used to prefill the last working day.
export const DEFAULT_NOTICE_DAYS = 30;

export const PAGE_SIZE = 10;

export const REASON_MAX_LENGTH = 255;

const BADGE_BASE = "d-inline-flex align-items-center badge-xs badge";

export const BADGE_CLASSES = {
  Active: `${BADGE_BASE} badge-soft-success`,
  "Closing Soon": `${BADGE_BASE} badge-soft-danger`,
  Completed: `${BADGE_BASE} badge-soft-dark text-dark`
};

export const SORT_OPTIONS = [
  { value: "lastWorkingDay", label: "Last Working Day" },
  { value: "startDesc", label: "Newest Notice" },
  { value: "progressDesc", label: "Most Progress" },
  { value: "nameAsc", label: "Name (A-Z)" },
  { value: "nameDesc", label: "Name (Z-A)" }
];

export const CSV_HEADERS = [
  "Notice ID",
  "Employee",
  "Designation",
  "Department",
  "Notice Start",
  "Last Working Day",
  "Total Days",
  "Completed Days",
  "Remaining Days",
  "Progress %",
  "Notice Status",
  "Separation Status",
  "Reason"
];