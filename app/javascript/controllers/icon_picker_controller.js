import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "emojiDisplay", "iconField", "fileInput"]

  selectEmoji({ params: { emoji } }) {
    // Clear file input so emoji takes precedence
    if (this.hasFileInputTarget) this.fileInputTarget.value = ""

    // Update hidden field
    this.iconFieldTarget.value = emoji

    // Update preview
    this.previewTarget.innerHTML = `<span class="icon-picker__emoji">${emoji}</span>`

    // Update selected state on buttons
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

    // Clear emoji selection
    this.iconFieldTarget.value = ""
    for (const btn of this.element.querySelectorAll(".icon-picker__btn")) {
      btn.classList.remove("icon-picker__btn--selected")
    }
  }

  removeImage() {
    if (this.hasFileInputTarget) this.fileInputTarget.value = ""
    const fallback = this.iconFieldTarget.value || "🌱"
    this.iconFieldTarget.value = fallback
    this.previewTarget.innerHTML = `<span class="icon-picker__emoji">${fallback}</span>`
  }
}
