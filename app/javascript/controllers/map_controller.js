import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  static values  = { createUrl: String }

  // -- State --
  #placingEntryId = null

  connect() {
    this.containerTarget.addEventListener("click", this.#handleMapClick)
    document.addEventListener("keydown", this.#handleKeydown)
  }

  disconnect() {
    this.containerTarget.removeEventListener("click", this.#handleMapClick)
    document.removeEventListener("keydown", this.#handleKeydown)
    this.#exitPlacingMode()
  }

  // Called by the "Place Pin" / "Move Pin" button on each entry card
  startPlacing({ params: { entryId } }) {
    this.#placingEntryId = entryId
    this.containerTarget.classList.add("map-placing-mode")
    document.getElementById("map-hint").style.display = ""
    this.containerTarget.scrollIntoView({ behavior: "smooth", block: "center" })
  }

  // Hover a pin → highlight its entry card
  highlightEntry(event) {
    const id = event.currentTarget.dataset.entryId
    document.getElementById(`entry-card-${id}`)?.classList.add("border-primary", "shadow")
  }

  unhighlightEntry(event) {
    const id = event.currentTarget.dataset.entryId
    document.getElementById(`entry-card-${id}`)?.classList.remove("border-primary", "shadow")
  }

  // Hover an entry card → highlight its pin on the map
  highlightPin({ params: { entryId } }) {
    const pin = this.containerTarget.querySelector(`[data-entry-id="${entryId}"]`)
    if (pin) pin.classList.add("map-pin--highlighted")
  }

  unhighlightPin({ params: { entryId } }) {
    const pin = this.containerTarget.querySelector(`[data-entry-id="${entryId}"]`)
    if (pin) pin.classList.remove("map-pin--highlighted")
  }

  // -- Private --

  #handleMapClick = (event) => {
    // Ignore clicks on existing pins or their delete buttons
    if (event.target.closest(".map-pin")) return
    // Only act when in placing mode
    if (!this.#placingEntryId) return

    const rect = this.containerTarget.getBoundingClientRect()
    const xPct = ((event.clientX - rect.left) / rect.width)  * 100
    const yPct = ((event.clientY - rect.top)  / rect.height) * 100

    const entryId = this.#placingEntryId
    this.#exitPlacingMode()

    const csrfToken = document.querySelector('meta[name="csrf-token"]').content

    fetch(this.createUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token":  csrfToken,
        "Accept":        "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ pin: { x_percent: xPct, y_percent: yPct, entry_id: entryId } })
    })
    .then(res => {
      if (!res.ok) return
      return res.text()
    })
    .then(html => {
      if (html) Turbo.renderStreamMessage(html)
      // Update the button label to "Move Pin"
      const btn = document.getElementById(`place-pin-btn-${entryId}`)
      if (btn) btn.textContent = "🗺️ Move Pin"
    })
  }

  #handleKeydown = (event) => {
    if (event.key === "Escape") this.#exitPlacingMode()
  }

  #exitPlacingMode() {
    this.#placingEntryId = null
    this.containerTarget?.classList.remove("map-placing-mode")
    const hint = document.getElementById("map-hint")
    if (hint) hint.style.display = "none"
  }
}
