import { Controller } from "@hotwired/stimulus"

const MIN_SCALE = 0.5
const MAX_SCALE = 5
const ZOOM_STEP = 0.25

export default class extends Controller {
  static targets = ["viewport", "canvas"]
  static values  = { createUrl: String }

  // -- Transform state --
  #scale = 1
  #panX  = 0  // px offset of canvas origin
  #panY  = 0

  // -- Drag state --
  #dragging   = false
  #wasDragged = false
  #dragStartX = 0
  #dragStartY = 0
  #panStartX  = 0
  #panStartY  = 0

  // -- Pin placement --
  #placingEntryId = null

  connect() {
    const vp = this.viewportTarget
    vp.addEventListener("pointerdown", this.#onPointerDown)
    vp.addEventListener("pointermove", this.#onPointerMove)
    vp.addEventListener("pointerup",   this.#onPointerUp)
    vp.addEventListener("pointerleave", this.#onPointerUp)
    vp.addEventListener("wheel",       this.#onWheel, { passive: false })
    vp.addEventListener("click",       this.#handleMapClick)
    document.addEventListener("keydown", this.#handleKeydown)

    // Fit image into viewport once loaded
    const img = this.canvasTarget.querySelector(".map-canvas__image")
    if (img.complete) {
      requestAnimationFrame(() => this.#fitToView())
    } else {
      img.addEventListener("load", () => this.#fitToView(), { once: true })
    }
  }

  disconnect() {
    const vp = this.viewportTarget
    vp.removeEventListener("pointerdown", this.#onPointerDown)
    vp.removeEventListener("pointermove", this.#onPointerMove)
    vp.removeEventListener("pointerup",   this.#onPointerUp)
    vp.removeEventListener("pointerleave", this.#onPointerUp)
    vp.removeEventListener("wheel",       this.#onWheel)
    vp.removeEventListener("click",       this.#handleMapClick)
    document.removeEventListener("keydown", this.#handleKeydown)
    this.#exitPlacingMode()
  }

  // ── Public actions ──

  zoomIn()    { this.#zoomBy(ZOOM_STEP) }
  zoomOut()   { this.#zoomBy(-ZOOM_STEP) }
  resetView() { this.#fitToView() }

  startPlacing({ params: { entryId } }) {
    this.#placingEntryId = entryId
    this.viewportTarget.classList.add("map-viewport--placing")
    document.getElementById("map-hint").style.display = ""
  }

  highlightEntry(event) {
    const id = event.currentTarget.dataset.entryId
    document.getElementById(`entry-card-${id}`)?.classList.add("border-primary", "shadow")
  }

  unhighlightEntry(event) {
    const id = event.currentTarget.dataset.entryId
    document.getElementById(`entry-card-${id}`)?.classList.remove("border-primary", "shadow")
  }

  highlightPin({ params: { entryId } }) {
    this.canvasTarget.querySelector(`[data-entry-id="${entryId}"]`)
      ?.classList.add("map-pin--highlighted")
  }

  unhighlightPin({ params: { entryId } }) {
    this.canvasTarget.querySelector(`[data-entry-id="${entryId}"]`)
      ?.classList.remove("map-pin--highlighted")
  }

  // ── Drag-to-pan ──

  #onPointerDown = (e) => {
    if (e.target.closest(".map-controls") || e.target.closest(".map-pin")) return
    this.#dragging   = true
    this.#wasDragged = false
    this.#dragStartX = e.clientX
    this.#dragStartY = e.clientY
    this.#panStartX  = this.#panX
    this.#panStartY  = this.#panY
    this.viewportTarget.setPointerCapture(e.pointerId)
    this.viewportTarget.style.cursor = "grabbing"
  }

  #onPointerMove = (e) => {
    if (!this.#dragging) return
    const dx = e.clientX - this.#dragStartX
    const dy = e.clientY - this.#dragStartY
    if (Math.abs(dx) > 3 || Math.abs(dy) > 3) this.#wasDragged = true
    this.#panX = this.#panStartX + dx
    this.#panY = this.#panStartY + dy
    this.#applyTransform()
  }

  #onPointerUp = (e) => {
    if (!this.#dragging) return
    this.#dragging = false
    this.viewportTarget.releasePointerCapture(e.pointerId)
    this.viewportTarget.style.cursor = ""
  }

  // ── Wheel zoom (centred on cursor) ──

  #onWheel = (e) => {
    e.preventDefault()
    const delta = e.deltaY > 0 ? -ZOOM_STEP : ZOOM_STEP
    this.#zoomAt(delta, e.clientX, e.clientY)
  }

  // ── Pin placement click ──

  #handleMapClick = (e) => {
    if (e.target.closest(".map-pin") || e.target.closest(".map-controls")) return
    if (this.#wasDragged) return           // was a drag, not a click
    if (!this.#placingEntryId) return       // not in placement mode

    // Convert viewport click → canvas-relative percentages
    const vpRect     = this.viewportTarget.getBoundingClientRect()
    const canvasRect = this.canvasTarget.getBoundingClientRect()
    const xOnCanvas  = e.clientX - canvasRect.left
    const yOnCanvas  = e.clientY - canvasRect.top
    const xPct       = (xOnCanvas / canvasRect.width)  * 100
    const yPct       = (yOnCanvas / canvasRect.height) * 100

    // Clamp to image bounds
    if (xPct < 0 || xPct > 100 || yPct < 0 || yPct > 100) return

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
    .then(res => { if (res.ok) return res.text() })
    .then(html => {
      if (html) Turbo.renderStreamMessage(html)
      const btn = document.getElementById(`place-pin-btn-${entryId}`)
      if (btn) btn.textContent = "🗺️ Move Pin"
    })
  }

  #handleKeydown = (e) => {
    if (e.key === "Escape") this.#exitPlacingMode()
  }

  // ── Helpers ──

  #zoomBy(delta) {
    // Zoom toward viewport centre
    const r = this.viewportTarget.getBoundingClientRect()
    this.#zoomAt(delta, r.left + r.width / 2, r.top + r.height / 2)
  }

  #zoomAt(delta, clientX, clientY) {
    const prev = this.#scale
    this.#scale = Math.min(MAX_SCALE, Math.max(MIN_SCALE, prev + delta))
    const ratio = this.#scale / prev

    // Keep the point under the cursor stationary
    const vpRect = this.viewportTarget.getBoundingClientRect()
    const cx = clientX - vpRect.left  // cursor relative to viewport
    const cy = clientY - vpRect.top
    this.#panX = cx - ratio * (cx - this.#panX)
    this.#panY = cy - ratio * (cy - this.#panY)
    this.#applyTransform()
  }

  #applyTransform() {
    this.canvasTarget.style.transform =
      `translate(${this.#panX}px, ${this.#panY}px) scale(${this.#scale})`
  }

  #fitToView() {
    const vp  = this.viewportTarget
    const img = this.canvasTarget.querySelector(".map-canvas__image")
    if (!img || !img.naturalWidth) return

    // Size the canvas to the image's natural pixel dimensions
    // so percentage-based pins remain accurate
    this.canvasTarget.style.width  = `${img.naturalWidth}px`
    this.canvasTarget.style.height = `${img.naturalHeight}px`

    const scaleX = vp.clientWidth  / img.naturalWidth
    const scaleY = vp.clientHeight / img.naturalHeight
    this.#scale  = Math.min(scaleX, scaleY)

    // Centre the scaled image in the viewport
    const scaledW = img.naturalWidth  * this.#scale
    const scaledH = img.naturalHeight * this.#scale
    this.#panX = (vp.clientWidth  - scaledW) / 2
    this.#panY = (vp.clientHeight - scaledH) / 2
    this.#applyTransform()
  }

  #exitPlacingMode() {
    this.#placingEntryId = null
    this.viewportTarget?.classList.remove("map-viewport--placing")
    const hint = document.getElementById("map-hint")
    if (hint) hint.style.display = "none"
  }
}
