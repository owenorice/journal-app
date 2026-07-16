import { Controller } from "@hotwired/stimulus"

// Full-screen preview for entry icon images. Lives on <body>; any element can
// trigger it with data-action="click->lightbox#open" plus src/caption params.
export default class extends Controller {
  static targets = ["overlay", "image", "caption"]

  open(event) {
    this.imageTarget.src = event.params.src
    this.imageTarget.alt = event.params.caption || ""
    this.captionTarget.textContent = event.params.caption || ""
    this.overlayTarget.hidden = false
  }

  close() {
    if (this.overlayTarget.hidden) return
    this.overlayTarget.hidden = true
    this.imageTarget.src = ""
  }
}
