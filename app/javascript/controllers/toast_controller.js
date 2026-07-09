import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    // Fade in
    requestAnimationFrame(() => {
      this.element.classList.add("toast-container--visible")
    })

    // Auto-dismiss after 3 seconds
    this.timeout = setTimeout(() => this.dismiss(), 3000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.remove("toast-container--visible")
    this.element.classList.add("toast-container--hiding")
    this.element.addEventListener("transitionend", () => {
      this.element.remove()
    }, { once: true })
  }
}
