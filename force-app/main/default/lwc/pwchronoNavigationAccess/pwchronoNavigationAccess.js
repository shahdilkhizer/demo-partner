// Menu visibility is keyed on the navigation item label. A group stays visible
// while at least one of its children is visible. This is a visibility aid only;
// Apex remains the authority for every page and action.
const EMPLOYEE_LIFECYCLE_FEATURES = ["Employee Lifecycle"];

const MENU_FEATURE_MAP = {
  Dashboard: ["Dashboard"],
  "Admin Dashboard": ["Admin Settings", "Configuration"],
  "Manager Dashboard": ["Manager Dashboard"],
  "Employee Dashboard": ["Dashboard"],
  "My Profile": ["My Profile"],
  "Attendance Management": ["Attendance Management"],
  "Attendance Employee": ["Attendance Management"],
  "Attendance (Admin)": ["Attendance Team", "Attendance Administration"],
  Overtime: ["Attendance Management"],
  "WFH Management": ["Attendance Management"],
  Timesheets: ["Attendance Management"],
  "Shift Roster": ["Attendance Management"],
  "Attendance Settings": ["Attendance Administration"],
  "Leave Management": ["Leave Management"],
  "Leaves (Employee)": ["Leave Management"],
  "Leaves Admin": ["Leave Management"],
  "Leave Settings": ["Admin Settings", "Configuration"],
  Approvals: ["Approvals"],
  Holidays: ["Holidays"],
  "Company Policies": ["Company Policies"],
  "Employee Directory": ["Employee Directory"],
  Recruitment: ["Recruitment"],
  Onboarding: ["Onboarding"],
  Performance: ["Performance Management", "Appraisal", "Goals"],
  Goals: ["Goals", "Performance Management"],
  Appraisals: ["Appraisal", "Performance Management"],
  Training: ["Training Management"],
  "Employee Lifecycle": EMPLOYEE_LIFECYCLE_FEATURES,
  "Probation Management": EMPLOYEE_LIFECYCLE_FEATURES,
  Promotions: EMPLOYEE_LIFECYCLE_FEATURES,
  Transfers: EMPLOYEE_LIFECYCLE_FEATURES,
  "Notice Period Tracker": EMPLOYEE_LIFECYCLE_FEATURES,
  Separations: EMPLOYEE_LIFECYCLE_FEATURES,
  "Exit Interviews": EMPLOYEE_LIFECYCLE_FEATURES,
  "Full & Final Settlement": EMPLOYEE_LIFECYCLE_FEATURES,
  "Projects List": ["Projects", "Dashboard"],
  Projects: ["Projects", "Dashboard"],
  "Expense Management": ["Expense Management"],
  Payroll: ["Payroll"],
  "Payroll & Payslips": ["Payroll"],
  "Tax Declaration": ["Tax Declaration"],
  Configuration: ["Admin Settings", "Configuration"],
  Administration: ["Admin Settings", "Configuration"],
  "Reports Dashboard": ["Reports Dashboard", "Admin Settings", "Configuration"],
  "Role Feature Mapping": ["Admin Settings", "Configuration"],
  "Admin Settings": ["Admin Settings"]
};

function hasMenuAccess(item, featureSet) {
  const requiredFeatures = MENU_FEATURE_MAP[item?.label];
  return Boolean(requiredFeatures?.some((feature) => featureSet.has(feature)));
}

export function filterMenuItemsByFeatures(items, features, role) {
  const featureSet = new Set(features || []);
  return (items || []).reduce((visibleItems, item) => {
    if (
      ["Projects", "Projects List"].includes(item.label) &&
      !["HR Admin", "System Administrator", "System Admin"].includes(role)
    )
      return visibleItems;
    const children = filterMenuItemsByFeatures(
      item.children || [],
      features,
      role
    );
    if (!hasMenuAccess(item, featureSet) && children.length === 0) {
      return visibleItems;
    }
    visibleItems.push({ ...item, children });
    return visibleItems;
  }, []);
}

// Keep only the items that can open a page in the current shell. A group keeps
// its openable children; a group left with none stays only when it can open a
// page itself (it then renders as a plain link).
export function filterMenuItemsByReachability(items, canOpen) {
  return (items || []).reduce((reachableItems, item) => {
    const children = filterMenuItemsByReachability(item.children, canOpen);
    if (children.length || canOpen(item)) {
      reachableItems.push({ ...item, children });
    }
    return reachableItems;
  }, []);
}

// Search only an already authorized menu tree, preserving matching descendants.
export function filterMenuItemsBySearch(items, searchTerm) {
  const query = String(searchTerm || "")
    .trim()
    .toLowerCase();
  if (!query) return items || [];
  return (items || []).reduce((matches, item) => {
    const children = filterMenuItemsBySearch(item.children, query);
    if (
      String(item.label || "")
        .toLowerCase()
        .includes(query)
    )
      matches.push(item);
    else if (children.length) matches.push({ ...item, children });
    return matches;
  }, []);
}