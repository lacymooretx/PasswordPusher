import { DirectUpload } from "@rails/activestorage"
import { Controller } from "@hotwired/stimulus"

// Encrypted file format: [HEADER][CHUNK_0][CHUNK_1]...[CHUNK_N]
// Header (29 bytes): [4: magic "PWPE"][1: version][4: chunk_size][8: original_size][12: base_iv]
// Each chunk: AES-256-GCM ciphertext + 16-byte auth tag
const MAGIC = new Uint8Array([0x50, 0x57, 0x50, 0x45]) // "PWPE"
const FORMAT_VERSION = 1
const CHUNK_SIZE = 5 * 1024 * 1024 // 5 MB
const HEADER_SIZE = 29
const GCM_TAG_SIZE = 16

function formatBytes(bytes, decimals = 2) {
  if (bytes === 0) return "0 Bytes"
  const k = 1024
  const dm = decimals < 0 ? 0 : decimals
  const sizes = ["Bytes", "KB", "MB", "GB", "TB"]
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i]
}

export default class extends Controller {
  static values = {
    directUploadUrl: String,
    enabled: { type: Boolean, default: false }
  }

  connect() {
    this.processing = false
  }

  async handleSubmit(event) {
    // Skip if encryption is disabled or we're in the final submission phase
    if (!this.enabledValue || this.processing) return

    // Collect all files from file inputs within the form
    const form = event.target
    const fileInputs = Array.from(form.querySelectorAll('input[type="file"]'))
    const allFiles = []

    fileInputs.forEach(input => {
      for (let i = 0; i < input.files.length; i++) {
        allFiles.push({ file: input.files[i], input: input })
      }
    })

    // If no files selected, let the form submit normally (validation will catch it)
    if (allFiles.length === 0) return

    // Prevent normal form submission — we handle it
    event.preventDefault()
    event.stopPropagation()

    const submitButton = form.querySelector('[data-form-target="pushit"]')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.textContent = "Encrypting..."
    }

    try {
      // Generate a per-push AES-256-GCM encryption key
      const key = await crypto.subtle.generateKey(
        { name: "AES-GCM", length: 256 },
        true,
        ["encrypt", "decrypt"]
      )
      const rawKey = await crypto.subtle.exportKey("raw", key)
      const keyBase64 = this.arrayBufferToBase64(rawKey)

      // Set the encryption key in the hidden form field
      let keyField = form.querySelector('input[name="push[file_encryption_key]"]')
      if (!keyField) {
        keyField = document.createElement("input")
        keyField.type = "hidden"
        keyField.name = "push[file_encryption_key]"
        form.appendChild(keyField)
      }
      keyField.value = keyBase64

      // Set up progress UI
      const progressBars = document.getElementById("progress-bars")
      const selectedFiles = document.getElementById("selected-files")
      if (selectedFiles) selectedFiles.style.display = "none"
      if (progressBars) progressBars.innerHTML = ""

      // Process each file: encrypt then upload
      const signedIds = []
      for (let i = 0; i < allFiles.length; i++) {
        const { file } = allFiles[i]

        // Create progress bar for this file
        const progressItem = this.createProgressItem(i, file.name, progressBars)

        // Phase 1: Encrypt
        this.updateProgress(progressItem, 0, `Encrypting ${file.name}...`)
        const encryptedBlob = await this.encryptFile(file, key, (pct) => {
          this.updateProgress(progressItem, pct * 0.4, `Encrypting ${file.name}... ${Math.round(pct)}%`)
        })

        // Phase 2: Upload via DirectUpload
        this.updateProgress(progressItem, 40, `Uploading ${file.name}...`)
        const encryptedFile = new File([encryptedBlob], file.name, {
          type: "application/octet-stream"
        })
        const signedId = await this.uploadFile(encryptedFile, (pct) => {
          this.updateProgress(progressItem, 40 + pct * 0.6, `Uploading ${file.name}... ${Math.round(pct)}%`)
        })

        signedIds.push(signedId)
        this.updateProgress(progressItem, 100, `${file.name} (${formatBytes(file.size)}) ✓`)
        progressItem.bar.classList.remove("progress-bar-animated")
        progressItem.bar.classList.add("bg-success")
      }

      // Remove all original file inputs (they contain unencrypted file references)
      fileInputs.forEach(input => {
        // Also remove the parent list item if it exists
        const listItem = input.closest(".selected-file")
        if (listItem) listItem.remove()
        else input.remove()
      })

      // Add hidden inputs with blob signed_ids
      signedIds.forEach(id => {
        const hidden = document.createElement("input")
        hidden.type = "hidden"
        hidden.name = "push[files][]"
        hidden.value = id
        form.appendChild(hidden)
      })

      // Submit the form (flag prevents re-entry)
      if (submitButton) submitButton.textContent = "Submitting..."
      this.processing = true
      form.submit()
    } catch (error) {
      console.error("Encryption/upload error:", error)
      if (submitButton) {
        submitButton.disabled = false
        submitButton.textContent = "Push It!"
      }
      alert(`Upload failed: ${error.message || error}. Please try again.`)
    }
  }

  async encryptFile(file, key, onProgress) {
    const baseIV = crypto.getRandomValues(new Uint8Array(12))
    const totalChunks = Math.ceil(file.size / CHUNK_SIZE)

    // Build header
    const header = new ArrayBuffer(HEADER_SIZE)
    const hView = new DataView(header)
    new Uint8Array(header, 0, 4).set(MAGIC)
    hView.setUint8(4, FORMAT_VERSION)
    hView.setUint32(5, CHUNK_SIZE, false)
    hView.setFloat64(9, file.size, false)
    new Uint8Array(header, 17, 12).set(baseIV)

    const encryptedParts = [new Uint8Array(header)]

    for (let i = 0; i < totalChunks; i++) {
      const start = i * CHUNK_SIZE
      const end = Math.min(start + CHUNK_SIZE, file.size)
      const chunk = await file.slice(start, end).arrayBuffer()

      // Derive per-chunk IV: base IV with last 4 bytes XORed with chunk index
      const iv = new Uint8Array(baseIV)
      const idxBuf = new ArrayBuffer(4)
      new DataView(idxBuf).setUint32(0, i, false)
      const idxBytes = new Uint8Array(idxBuf)
      iv[8] ^= idxBytes[0]
      iv[9] ^= idxBytes[1]
      iv[10] ^= idxBytes[2]
      iv[11] ^= idxBytes[3]

      const encrypted = await crypto.subtle.encrypt(
        { name: "AES-GCM", iv: iv, tagLength: 128 },
        key,
        chunk
      )

      encryptedParts.push(new Uint8Array(encrypted))

      if (onProgress) onProgress(((i + 1) / totalChunks) * 100)
    }

    return new Blob(encryptedParts)
  }

  uploadFile(file, onProgress) {
    return new Promise((resolve, reject) => {
      const upload = new DirectUpload(file, this.directUploadUrlValue, {
        directUploadWillStoreFileWithXHR: (request) => {
          request.upload.addEventListener("progress", (event) => {
            if (onProgress && event.total > 0) {
              onProgress((event.loaded / event.total) * 100)
            }
          })
          request.addEventListener("error", () => {
            console.error("DirectUpload XHR error:", request.status, request.statusText, request.responseText)
          })
          request.addEventListener("load", () => {
            if (request.status >= 400) {
              console.error("DirectUpload XHR failed:", request.status, request.statusText, request.responseText)
            }
          })
        }
      })
      upload.create((error, blob) => {
        if (error) {
          console.error("DirectUpload error:", error)
          reject(error)
        } else {
          resolve(blob.signed_id)
        }
      })
    })
  }

  createProgressItem(id, filename, container) {
    if (!container) return { bar: document.createElement("div") }

    const li = document.createElement("li")
    li.classList = "list-group-item list-group-item-primary small"
    li.setAttribute("id", `enc-progress-${id}`)

    const progress = document.createElement("div")
    progress.classList = "progress"
    progress.style = "height: 1.5rem"

    const bar = document.createElement("div")
    bar.classList = "progress-bar progress-bar-striped progress-bar-animated"
    bar.setAttribute("role", "progressbar")
    bar.setAttribute("aria-label", filename)
    bar.setAttribute("aria-valuenow", "0")
    bar.setAttribute("aria-valuemin", "0")
    bar.setAttribute("aria-valuemax", "100")
    bar.style.width = "0%"
    bar.textContent = filename

    progress.append(bar)
    li.append(progress)
    container.append(li)

    return { li, bar }
  }

  updateProgress(item, pct, label) {
    if (!item || !item.bar) return
    item.bar.style.width = `${pct}%`
    item.bar.setAttribute("aria-valuenow", Math.round(pct))
    if (label) item.bar.textContent = label
  }

  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i])
    }
    return btoa(binary)
  }
}
