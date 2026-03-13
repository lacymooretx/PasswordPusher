import { DirectUpload } from "@rails/activestorage"
import { Controller } from "@hotwired/stimulus"
import SparkMD5 from "spark-md5"

// Encrypted file format: [HEADER][CHUNK_0][CHUNK_1]...[CHUNK_N]
// Header (29 bytes): [4: magic "PWPE"][1: version][4: chunk_size][8: original_size][12: base_iv]
// Each chunk: AES-256-GCM ciphertext + 16-byte auth tag
const MAGIC = new Uint8Array([0x50, 0x57, 0x50, 0x45]) // "PWPE"
const FORMAT_VERSION = 1
const CHUNK_SIZE = 5 * 1024 * 1024 // 5 MB
const HEADER_SIZE = 29
const GCM_TAG_SIZE = 16
const MULTIPART_THRESHOLD = 100 * 1024 * 1024 // 100 MB — use multipart above this
const MULTIPART_PART_SIZE = 100 * 1024 * 1024 // 100 MB per part

function formatBytes(bytes, decimals = 2) {
  if (bytes === 0) return "0 Bytes"
  const k = 1024
  const dm = decimals < 0 ? 0 : decimals
  const sizes = ["Bytes", "KB", "MB", "GB", "TB"]
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + " " + sizes[i]
}

function csrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta ? meta.content : ""
}

export default class extends Controller {
  static values = {
    directUploadUrl: String,
    multipartUrl: String,
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

        // Phase 2: Upload
        this.updateProgress(progressItem, 40, `Uploading ${file.name}...`)
        const encryptedFile = new File([encryptedBlob], file.name, {
          type: "application/octet-stream"
        })

        let signedId
        console.log("Upload decision:", {
          fileSize: encryptedFile.size,
          threshold: MULTIPART_THRESHOLD,
          hasMultipartUrl: this.hasMultipartUrlValue,
          multipartUrl: this.multipartUrlValue,
          useMultipart: encryptedFile.size > MULTIPART_THRESHOLD && this.hasMultipartUrlValue
        })
        if (encryptedFile.size > MULTIPART_THRESHOLD && this.hasMultipartUrlValue) {
          signedId = await this.multipartUpload(encryptedFile, (pct) => {
            this.updateProgress(progressItem, 40 + pct * 0.6, `Uploading ${file.name}... ${Math.round(pct)}%`)
          })
        } else {
          signedId = await this.directUploadFile(encryptedFile, (pct) => {
            this.updateProgress(progressItem, 40 + pct * 0.6, `Uploading ${file.name}... ${Math.round(pct)}%`)
          })
        }

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

  // Single-part upload via ActiveStorage DirectUpload (for files <= 100MB)
  directUploadFile(file, onProgress) {
    return new Promise((resolve, reject) => {
      const upload = new DirectUpload(file, this.directUploadUrlValue, {
        directUploadWillStoreFileWithXHR: (request) => {
          request.upload.addEventListener("progress", (event) => {
            if (onProgress && event.total > 0) {
              onProgress((event.loaded / event.total) * 100)
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

  // Multipart upload for large files (> 100MB)
  async multipartUpload(file, onProgress) {
    const checksum = await this.computeChecksum(file)
    const baseUrl = this.multipartUrlValue

    // Step 1: Initiate multipart upload
    const initResponse = await fetch(baseUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken()
      },
      body: JSON.stringify({
        filename: file.name,
        byte_size: file.size,
        checksum: checksum,
        content_type: file.type || "application/octet-stream"
      })
    })

    if (!initResponse.ok) {
      const text = await initResponse.text()
      throw new Error(`Failed to initiate upload: ${initResponse.status} ${text}`)
    }

    const { upload_id, key, signed_id } = await initResponse.json()

    try {
      // Step 2: Upload parts
      const totalParts = Math.ceil(file.size / MULTIPART_PART_SIZE)
      const completedParts = []
      let totalUploaded = 0

      for (let partNumber = 1; partNumber <= totalParts; partNumber++) {
        const start = (partNumber - 1) * MULTIPART_PART_SIZE
        const end = Math.min(start + MULTIPART_PART_SIZE, file.size)
        const partBlob = file.slice(start, end)

        // Get presigned URL for this part
        const partUrlResponse = await fetch(`${baseUrl}/part_url`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": csrfToken()
          },
          body: JSON.stringify({
            key: key,
            upload_id: upload_id,
            part_number: partNumber
          })
        })

        if (!partUrlResponse.ok) {
          throw new Error(`Failed to get part URL: ${partUrlResponse.status}`)
        }

        const { url } = await partUrlResponse.json()

        // Upload the part directly to B2/S3
        const etag = await this.uploadPart(url, partBlob, (partPct) => {
          const partBytes = partPct / 100 * (end - start)
          const totalPct = (totalUploaded + partBytes) / file.size * 100
          if (onProgress) onProgress(totalPct)
        })

        completedParts.push({ etag: etag, part_number: partNumber })
        totalUploaded += (end - start)
        if (onProgress) onProgress(totalUploaded / file.size * 100)
      }

      // Step 3: Complete multipart upload
      const completeResponse = await fetch(`${baseUrl}/complete`, {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken()
        },
        body: JSON.stringify({
          key: key,
          upload_id: upload_id,
          parts: completedParts
        })
      })

      if (!completeResponse.ok) {
        const text = await completeResponse.text()
        throw new Error(`Failed to complete upload: ${completeResponse.status} ${text}`)
      }

      return signed_id
    } catch (error) {
      // Abort the multipart upload on failure
      try {
        await fetch(`${baseUrl}/abort`, {
          method: "DELETE",
          headers: {
            "Content-Type": "application/json",
            "X-CSRF-Token": csrfToken()
          },
          body: JSON.stringify({ key: key, upload_id: upload_id })
        })
      } catch (abortError) {
        console.error("Failed to abort multipart upload:", abortError)
      }
      throw error
    }
  }

  // Upload a single part to the presigned URL, return the ETag
  uploadPart(url, blob, onProgress) {
    return new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest()
      xhr.open("PUT", url)

      xhr.upload.addEventListener("progress", (event) => {
        if (onProgress && event.total > 0) {
          onProgress((event.loaded / event.total) * 100)
        }
      })

      xhr.onload = () => {
        if (xhr.status >= 200 && xhr.status < 300) {
          const etag = xhr.getResponseHeader("ETag")
          resolve(etag)
        } else {
          reject(new Error(`Part upload failed: ${xhr.status} ${xhr.statusText}`))
        }
      }

      xhr.onerror = () => {
        reject(new Error("Part upload network error"))
      }

      xhr.send(blob)
    })
  }

  // Compute MD5 checksum of a Blob using SparkMD5 (streaming)
  computeChecksum(blob) {
    return new Promise((resolve, reject) => {
      const md5 = new SparkMD5.ArrayBuffer()
      const reader = new FileReader()
      const chunkSize = 2 * 1024 * 1024 // 2 MB read chunks
      let offset = 0

      reader.onload = (event) => {
        md5.append(event.target.result)
        offset += event.target.result.byteLength
        if (offset < blob.size) {
          readNextChunk()
        } else {
          const rawDigest = md5.end(true) // raw binary string
          resolve(btoa(rawDigest))
        }
      }

      reader.onerror = () => reject(new Error("Failed to compute file checksum"))

      function readNextChunk() {
        const slice = blob.slice(offset, offset + chunkSize)
        reader.readAsArrayBuffer(slice)
      }

      readNextChunk()
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
