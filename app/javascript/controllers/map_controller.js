import { Controller } from "@hotwired/stimulus"

const MIN_SCALE = 0.5
const MAX_SCALE = 5
const ZOOM_STEP = 0.25

export default class extends Controller {
  static targets = ["viewport", "canvas", "pins", "entryList", "entryExpand"]
  static values  = { createUrl: String }

  // -- Transform state --
  #scale = 1
  #panX  = 0
  #panY  = 0

  // -- Drag state --
  #dragging   = false
  #wasDragged = false
  #dragStartX = 0
  #dragStartY = 0
  #panStartX  = 0
  #panStartY  = 0

  // -- Image natural dimensions (cached) --
  #natW = 0
  #natH = 0

  // -- Pin placement --
  #placingEntryId = null

  // -- Expand panel --
  #expandedEntryId = null

  // -- MutationObserver for new pins --
  #pinObserver = null

  connect() {
    const vp = this.viewportTarget
    vp.addEventListener("pointerdown", this.#onPointerDown)
    vp.addEventListener("pointermove", this.#onPointerMove)
    vp.addEventListener("pointerup",   this.#onPointerUp)
    vp.addEventListener("pointerleave", this.#onPointerUp)
    vp.addEventListener("wheel",       this.#onWheel, { passive: false })
    vp.addEventListener("click",       this.#handleMapClick)
    document.addEventListener("keydown", this.#handleKeydown)

    // Watch for Turbo Stream pin additions/removals
    this.#pinObserver = new MutationObserver(() => this.#repositionPins())
    this.#pinObserver.observe(this.pinsTarget, { childList: true, subtree: true })

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
    this.#pinObserver?.disconnect()
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

  highlight({ params: { entryId } }) {
    this.#setHighlight(entryId, true)
  }

  unhighlight({ params: { entryId } }) {
    this.#setHighlight(entryId, false)
  }

  expandEntry({ params: { entryId } }) {
    // Hide the list, show the expand container
    this.entryListTarget.style.display = "none"
    this.entryExpandTarget.style.display = ""

    // Hide all panels, show the one for this entry
    for (const panel of this.entryExpandTarget.querySelectorAll(".entry-expand__panel")) {
      panel.style.display = "none"
    }
    const panel = document.getElementById(`entry-panel-${entryId}`)
    if (panel) panel.style.display = ""

    // Highlight the entry's pin on the map
    this.#setHighlight(entryId, true)
    this.#expandedEntryId = entryId
  }

  collapseEntry() {
    this.entryListTarget.style.display = ""
    this.entryExpandTarget.style.display = "none"
    if (this.#expandedEntryId) {
      this.#setHighlight(this.#expandedEntryId, false)
      this.#expandedEntryId = null
    }
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
    if (this.#wasDragged) return
    if (!this.#placingEntryId) return

    // Convert viewport click → image-percentage coordinates
    const vpRect = this.viewportTarget.getBoundingClientRect()
    const clickVpX = e.clientX - vpRect.left
    const clickVpY = e.clientY - vpRect.top
    const xPct = ((clickVpX - this.#panX) / (this.#natW * this.#scale)) * 100
    const yPct = ((clickVpY - this.#panY) / (this.#natH * this.#scale)) * 100

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
    const r = this.viewportTarget.getBoundingClientRect()
    this.#zoomAt(delta, r.left + r.width / 2, r.top + r.height / 2)
  }

  #zoomAt(delta, clientX, clientY) {
    const prev = this.#scale
    this.#scale = Math.min(MAX_SCALE, Math.max(MIN_SCALE, prev + delta))
    const ratio = this.#scale / prev

    const vpRect = this.viewportTarget.getBoundingClientRect()
    const cx = clientX - vpRect.left
    const cy = clientY - vpRect.top
    this.#panX = cx - ratio * (cx - this.#panX)
    this.#panY = cy - ratio * (cy - this.#panY)
    this.#applyTransform()
  }

  #applyTransform() {
    this.canvasTarget.style.transform =
      `translate(${this.#panX}px, ${this.#panY}px) scale(${this.#scale})`
    this.#repositionPins()
  }

  // Position each pin in viewport space — never inside the canvas transform,
  // so pins are always rasterized at native screen resolution.
  #repositionPins() {
    const pins = this.pinsTarget.querySelectorAll(".map-pin")
    for (const pin of pins) {
      const xPct = parseFloat(pin.dataset.xPct)
      const yPct = parseFloat(pin.dataset.yPct)
      if (isNaN(xPct) || isNaN(yPct)) continue
      pin.style.left = `${this.#panX + (xPct / 100) * this.#natW * this.#scale}px`
      pin.style.top  = `${this.#panY + (yPct / 100) * this.#natH * this.#scale}px`
    }
  }

  #setHighlight(entryId, on) {
    const card = document.getElementById(`entry-card-${entryId}`)
    const pin  = this.pinsTarget.querySelector(`[data-entry-id="${entryId}"]`)
    const method = on ? "add" : "remove"
    card?.classList[method]("border-primary", "shadow")
    pin?.classList[method]("map-pin--highlighted")
  }

  #fitToView() {
    const vp  = this.viewportTarget
    const img = this.canvasTarget.querySelector(".map-canvas__image")
    if (!img || !img.naturalWidth) return

    this.#natW = img.naturalWidth
    this.#natH = img.naturalHeight

    this.canvasTarget.style.width  = `${this.#natW}px`
    this.canvasTarget.style.height = `${this.#natH}px`

    const scaleX = vp.clientWidth  / this.#natW
    const scaleY = vp.clientHeight / this.#natH
    this.#scale  = Math.min(scaleX, scaleY)

    const scaledW = this.#natW * this.#scale
    const scaledH = this.#natH * this.#scale
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
