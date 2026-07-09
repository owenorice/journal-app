import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    requestAnimationFrame(() => {
      this.element.classList.add("app-toast-container--visible")
    })

    this.timeout = setTimeout(() => this.dismiss(), 3000)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.remove("app-toast-container--visible")
    this.element.classList.add("app-toast-container--hiding")
    this.element.addEventListener("transitionend", () => {
      this.element.remove()
    }, { once: true })
  }
}
