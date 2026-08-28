import { LightningElement, api } from "lwc";

const DEFAULT_MAX_SIZE = 5 * 1024 * 1024; // 5 MB

export default class PwchronoFileUploadPanel extends LightningElement {
  static renderMode = "light";

  /** Array of { id, name, sizeLabel, downloadUrl } */
  @api files = [];

  /** Whether to show the upload area */
  @api allowUpload = false;

  /** Whether to show remove buttons */
  @api allowRemove = false;

  /** Max file size in bytes (default 5 MB) */
  @api maxFileSize = DEFAULT_MAX_SIZE;

  /** Accept attribute for file input (e.g., ".pdf,.jpg,.png") */
  @api accept = "";

  /** Allow multiple file selection */
  @api multiple = false;

  get hasFiles() {
    return this.files && this.files.length > 0;
  }

  get fileCount() {
    return this.files ? this.files.length : 0;
  }

  get maxSizeLabel() {
    if (!this.maxFileSize) {
      return "";
    }
    const mb = this.maxFileSize / (1024 * 1024);
    return mb >= 1 ? `${mb} MB` : `${this.maxFileSize / 1024} KB`;
  }

  handleFileSelected(event) {
    const fileList = event.target.files;
    if (!fileList || fileList.length === 0) {
      return;
    }
    this._processFiles(fileList);
    event.target.value = "";
  }

  handleDragOver(event) {
    event.preventDefault();
    event.stopPropagation();
  }

  handleDrop(event) {
    event.preventDefault();
    event.stopPropagation();
    const fileList = event.dataTransfer.files;
    if (fileList && fileList.length > 0) {
      this._processFiles(fileList);
    }
  }

  handleRemoveFile(event) {
    const fileId = event.currentTarget.dataset.id;
    this.dispatchEvent(
      new CustomEvent("removefile", { detail: { fileId } })
    );
  }

  _processFiles(fileList) {
    const validFiles = [];
    for (const file of fileList) {
      if (this.maxFileSize && file.size > this.maxFileSize) {
        this.dispatchEvent(
          new CustomEvent("fileerror", {
            detail: {
              fileName: file.name,
              message: `File "${file.name}" exceeds maximum size of ${this.maxSizeLabel}.`
            }
          })
        );
        continue;
      }
      validFiles.push(file);
    }

    if (validFiles.length > 0) {
      this.dispatchEvent(
        new CustomEvent("filesselected", {
          detail: { files: validFiles }
        })
      );
    }
  }
}