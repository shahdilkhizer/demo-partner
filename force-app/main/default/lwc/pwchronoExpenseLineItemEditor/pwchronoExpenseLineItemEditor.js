import { LightningElement, api, track } from "lwc";

const TYPE_OPTIONS = [
  { label: "Travel", value: "Travel" },
  { label: "Food", value: "Food" },
  { label: "Lodging", value: "Lodging" },
  { label: "Communication", value: "Communication" },
  { label: "Training", value: "Training" },
  { label: "Entertainment", value: "Entertainment" },
  { label: "Other", value: "Other" }
];

export default class PwchronoExpenseLineItemEditor extends LightningElement {
  static renderMode = "light";

  @api readOnly = false;

  @track items = [];

  get typeOptions() {
    return TYPE_OPTIONS;
  }

  /**
   * @description Parent sets the initial items array (new claim → empty,
   *              edit → existing items pre-loaded).
   *              We clone to avoid mutating parent state directly.
   */
  @api
  get value() {
    return this.items;
  }
  set value(incoming) {
    if (Array.isArray(incoming)) {
      this.items = incoming.map((item, idx) => ({
        ...item,
        _key: item.itemId || `new-${idx}-${Date.now()}`
      }));
    } else {
      this.items = [];
    }
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  get totalAmount() {
    return this.items.reduce((sum, item) => {
      const amt = Number.parseFloat(item.amount) || 0;
      return sum + (amt > 0 ? amt : 0);
    }, 0);
  }

  get hasItems() {
    return this.items && this.items.length > 0;
  }

  get showEmptyRow() {
    return !this.readOnly && this.items.length === 0;
  }

  // ── Add / Remove ──────────────────────────────────────────────────────────

  handleAddItem() {
    const today = new Date().toISOString().split("T")[0];
    this.items = [
      ...this.items,
      {
        _key: `new-${Date.now()}`,
        itemId: null,
        expenseDate: today,
        itemType: "Other",
        description: "",
        merchant: "",
        amount: null,
        receiptReference: ""
      }
    ];
    this.notifyParent();
  }

  handleRemoveItem(event) {
    const key = event.currentTarget.dataset.key;
    this.items = this.items.filter((item) => item._key !== key);
    this.notifyParent();
  }

  // ── Field changes ─────────────────────────────────────────────────────────

  handleFieldChange(event) {
    const key = event.currentTarget.dataset.key;
    const field = event.currentTarget.dataset.field;
    let value = event.target.value;

    // Coerce amount to number
    if (field === "amount") {
      value = value === "" ? null : Number.parseFloat(value);
    }

    this.items = this.items.map((item) => {
      if (item._key === key) {
        return { ...item, [field]: value };
      }
      return item;
    });
    this.notifyParent();
  }

  // ── Dispatch ──────────────────────────────────────────────────────────────

  notifyParent() {
    this.dispatchEvent(
      new CustomEvent("itemschange", {
        detail: {
          items: this.items.map((item) => {
            const cleanItem = { ...item };
            delete cleanItem._key;
            return cleanItem;
          })
        }
      })
    );
  }
}