import { Controller } from "@hotwired/stimulus"

// Applies push template defaults to the push form knobs
export default class extends Controller {
    static targets = ["select"]
    static values = {
        templates: Array
    }

    apply() {
        const templateId = this.selectTarget.value
        if (!templateId) return

        const template = this.templatesValue.find(t => t.id === parseInt(templateId))
        if (!template) return

        // Find the knobs controller on the parent container
        const container = this.element.closest('[data-controller*="knobs"]')
        if (!container) return

        // Apply days
        if (template.expire_after_days) {
            const daysRange = container.querySelector('[data-knobs-target="daysRange"]')
            if (daysRange) {
                daysRange.value = template.expire_after_days
                daysRange.dispatchEvent(new Event('input'))
            }
        }

        // Apply views
        if (template.expire_after_views) {
            const viewsRange = container.querySelector('[data-knobs-target="viewsRange"]')
            if (viewsRange) {
                viewsRange.value = template.expire_after_views
                viewsRange.dispatchEvent(new Event('input'))
            }
        }

        // Apply retrieval step
        if (template.retrieval_step !== null && template.retrieval_step !== undefined) {
            const checkbox = container.querySelector('[data-knobs-target="retrievalStepCheckbox"]')
            if (checkbox) {
                checkbox.checked = template.retrieval_step
            }
        }

        // Apply deletable by viewer
        if (template.deletable_by_viewer !== null && template.deletable_by_viewer !== undefined) {
            const checkbox = container.querySelector('[data-knobs-target="deletableByViewerCheckbox"]')
            if (checkbox) {
                checkbox.checked = template.deletable_by_viewer
            }
        }

        // Apply passphrase
        if (template.passphrase) {
            const passphraseField = container.querySelector('input[name="push[passphrase]"]')
            if (passphraseField) {
                passphraseField.value = template.passphrase
            }
        }
    }
}
