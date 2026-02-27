import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]

  connect() {
    this.prefersDarkScheme = window.matchMedia("(prefers-color-scheme: dark)")
    this.mode = localStorage.getItem("theme") || "system"
    this.applyTheme()
    this._handleSystemChange = this.handleSystemChange.bind(this)
    this.prefersDarkScheme.addEventListener("change", this._handleSystemChange)
  }

  disconnect() {
    this.prefersDarkScheme.removeEventListener("change", this._handleSystemChange)
  }

  toggle() {
    if (this.mode === "system") {
      this.mode = this.prefersDarkScheme.matches ? "light" : "dark"
    } else if (this.mode === "light") {
      this.mode = "dark"
    } else {
      this.mode = "system"
    }
    localStorage.setItem("theme", this.mode)
    this.applyTheme()
  }

  applyTheme() {
    let isDark
    if (this.mode === "system") {
      isDark = this.prefersDarkScheme.matches
    } else {
      isDark = this.mode === "dark"
    }
    document.documentElement.setAttribute("data-bs-theme", isDark ? "dark" : "light")
    this.updateIcon(isDark)
  }

  handleSystemChange() {
    if (this.mode === "system") this.applyTheme()
  }

  updateIcon(isDark) {
    if (this.hasIconTarget) {
      this.iconTarget.className = isDark ? "bi bi-moon-fill" : "bi bi-sun-fill"
    }
  }
}
