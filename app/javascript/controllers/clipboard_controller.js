import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { text: String }

  copy() {
    navigator.clipboard.writeText(this.textValue).then(() => {
      const originalText = this.element.textContent
      this.element.textContent = "Copied!"
      setTimeout(() => { this.element.textContent = originalText }, 2000)
    })
  }
}
