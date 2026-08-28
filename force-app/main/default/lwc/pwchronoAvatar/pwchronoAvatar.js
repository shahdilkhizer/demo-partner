import { api, LightningElement, track } from "lwc";

export default class PwchronoAvatar extends LightningElement {
  static renderMode = "light";

  @api name;

  _imageUrl;

  @track imageErrored = false;

  /**
   * URL of the profile image.
   * If empty OR the image fails to load, initials will be shown.
   */
  @api
  get imageUrl() {
    return this._imageUrl;
  }
  set imageUrl(value) {
    this._imageUrl = value;
    // Reset error state when URL changes.
    this.imageErrored = false;
  }

  /** Optional explicit initials (overrides computed initials). */
  @api initials;

  /** Optional alt text override. Defaults to name. */
  @api altText;

  /** CSS classes for the outer avatar wrapper. */
  @api containerClass = "avatar";

  /** Inline style string for the outer avatar wrapper. */
  @api containerStyle;

  /** CSS classes for the <img>. */
  @api imageClass = "img-fluid rounded-circle";

  /** Inline style string for the <img>. */
  @api imageStyle;

  /** CSS classes for the initials bubble. */
  @api titleClass = "initial-wrap";

  /** Background class to apply when showing initials (if containerClass doesn't already include a bg-* class). */
  @api fallbackBgClass = "bg-primary";

  /** Text color class to apply when showing initials (if containerClass doesn't already include a text-* class). */
  @api fallbackTextClass = "text-fixed-white";

  /** Inline style string for the initials bubble. */
  @api titleStyle;

  get computedContainerClass() {
    const base = this.containerClass || "avatar";
    if (this.shouldRenderImage) return base;

    // When the image is missing/broken, ensure we have a readable background.
    // SmartHR's `.avatar` sets text color to white but does not set a background.
    const hasBg = /\bbg-/.test(base);
    const hasText = /\btext-/.test(base);

    let classes = base;
    if (!hasBg && this.fallbackBgClass) {
      classes += ` ${this.fallbackBgClass}`;
    }
    if (!hasText && this.fallbackTextClass) {
      classes += ` ${this.fallbackTextClass}`;
    }
    return classes;
  }

  get computedImageClass() {
    return this.imageClass || "img-fluid rounded-circle";
  }

  get computedTitleClass() {
    return this.titleClass || "initial-wrap";
  }

  get computedAltText() {
    return this.altText || this.name || "";
  }

  get computedInitials() {
    if (this.initials) {
      return String(this.initials).toUpperCase().slice(0, 2);
    }

    const name = (this.name || "").trim();
    if (!name) return "?";

    const parts = name.split(/\s+/).filter(Boolean);
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }

    return name.substring(0, 2).toUpperCase();
  }

  get shouldRenderImage() {
    return !!this.imageUrl && !this.imageErrored;
  }

  handleImgError() {
    this.imageErrored = true;
  }
}