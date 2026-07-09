import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "iconField", "fileInput", "purgeField", "removeBtn"]

  selectEmoji({ params: { emoji } }) {
    // Clear file input and mark image for purge
    if (this.hasFileInputTarget) this.fileInputTarget.value = ""
    this.purgeFieldTarget.value = "1"

    // Update hidden field
    this.iconFieldTarget.value = emoji

    // Update preview
    this.previewTarget.innerHTML = `<span class="icon-picker__emoji">${emoji}</span>`

    // Hide remove button
    this.removeBtnTarget.style.display = "none"

    // Update selected state
    for (const btn of this.element.querySelectorAll(".icon-picker__btn")) {
      btn.classList.toggle("icon-picker__btn--selected", btn.dataset.iconPickerEmojiParam === emoji)
    }
  }

  uploadImage() {
    const file = this.fileInputTarget.files[0]
    if (!file) return

    // Show image preview
    const url = URL.createObjectURL(file)
    this.previewTarget.innerHTML = `<img src="${url}" class="icon-picker__img">`

    // Don't purge — new upload replaces
    this.purgeFieldTarget.value = "0"

    // Clear emoji selection, show remove button
    this.iconFieldTarget.value = ""
    this.removeBtnTarget.style.display = ""
    for (const btn of this.element.querySelectorAll(".icon-picker__btn")) {
      btn.classList.remove("icon-picker__btn--selected")
    }
  }

  removeImage() {
    if (this.hasFileInputTarget) this.fileInputTarget.value = ""
    this.purgeFieldTarget.value = "1"
    this.removeBtnTarget.style.display = "none"

    const fallback = this.iconFieldTarget.value || "🌱"
    this.iconFieldTarget.value = fallback
    this.previewTarget.innerHTML = `<span class="icon-picker__emoji">${fallback}</span>`

    // Re-select the fallback emoji button
    for (const btn of this.element.querySelectorAll(".icon-picker__btn")) {
      btn.classList.toggle("icon-picker__btn--selected", btn.dataset.iconPickerEmojiParam === fallback)
    }
  }
}
