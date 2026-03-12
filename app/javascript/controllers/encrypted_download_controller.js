import { Controller } from "@hotwired/stimulus"

// Must match the upload format in encrypted_upload_controller.js
const HEADER_SIZE = 29
const GCM_TAG_SIZE = 16

export default class extends Controller {
  static values = {
    key: String // base64-encoded raw AES-256-GCM key
  }

  async download(event) {
    event.preventDefault()

    const link = event.currentTarget
    const url = link.dataset.encryptedUrl
    const filename = link.dataset.filename

    if (!this.keyValue) {
      alert("Encryption key not available. Cannot decrypt file.")
      return
    }

    // Show download state on the link
    const originalHTML = link.innerHTML
    link.innerHTML = `<span class="spinner-border spinner-border-sm me-1" role="status"></span> Downloading...`
    link.classList.add("disabled")

    try {
      // Import the encryption key
      const rawKey = this.base64ToArrayBuffer(this.keyValue)
      const key = await crypto.subtle.importKey(
        "raw", rawKey, { name: "AES-GCM" }, false, ["decrypt"]
      )

      // Fetch the encrypted file
      link.innerHTML = `<span class="spinner-border spinner-border-sm me-1" role="status"></span> Downloading encrypted file...`
      const response = await fetch(url)
      if (!response.ok) throw new Error(`Download failed: ${response.status}`)
      const encryptedData = await response.arrayBuffer()

      // Parse header
      link.innerHTML = `<span class="spinner-border spinner-border-sm me-1" role="status"></span> Decrypting...`
      const header = new DataView(encryptedData, 0, HEADER_SIZE)

      // Verify magic number
      const magic = new Uint8Array(encryptedData, 0, 4)
      if (magic[0] !== 0x50 || magic[1] !== 0x57 || magic[2] !== 0x50 || magic[3] !== 0x45) {
        // Not an encrypted file — download directly
        this.triggerDownload(new Blob([encryptedData]), filename)
        return
      }

      const version = header.getUint8(4)
      if (version !== 1) throw new Error(`Unsupported encryption format version: ${version}`)

      const chunkSize = header.getUint32(5, false)
      const originalSize = header.getFloat64(9, false)
      const baseIV = new Uint8Array(encryptedData, 17, 12)

      // Decrypt chunks
      const totalChunks = Math.ceil(originalSize / chunkSize)
      const decryptedParts = []
      let offset = HEADER_SIZE

      for (let i = 0; i < totalChunks; i++) {
        // Calculate expected chunk size
        const isLastChunk = (i === totalChunks - 1)
        const originalChunkSize = isLastChunk
          ? originalSize - (i * chunkSize)
          : chunkSize
        const encryptedChunkSize = originalChunkSize + GCM_TAG_SIZE

        // Extract encrypted chunk
        const encryptedChunk = encryptedData.slice(offset, offset + encryptedChunkSize)
        offset += encryptedChunkSize

        // Derive per-chunk IV
        const iv = new Uint8Array(baseIV)
        const idxBuf = new ArrayBuffer(4)
        new DataView(idxBuf).setUint32(0, i, false)
        const idxBytes = new Uint8Array(idxBuf)
        iv[8] ^= idxBytes[0]
        iv[9] ^= idxBytes[1]
        iv[10] ^= idxBytes[2]
        iv[11] ^= idxBytes[3]

        const decrypted = await crypto.subtle.decrypt(
          { name: "AES-GCM", iv: iv, tagLength: 128 },
          key,
          encryptedChunk
        )

        decryptedParts.push(new Uint8Array(decrypted))

        // Update progress
        const pct = Math.round(((i + 1) / totalChunks) * 100)
        link.innerHTML = `<span class="spinner-border spinner-border-sm me-1" role="status"></span> Decrypting... ${pct}%`
      }

      // Create decrypted blob and trigger download
      const decryptedBlob = new Blob(decryptedParts)
      this.triggerDownload(decryptedBlob, filename)

      // Restore the link
      link.innerHTML = originalHTML
      link.classList.remove("disabled")
    } catch (error) {
      console.error("Decryption error:", error)
      link.innerHTML = originalHTML
      link.classList.remove("disabled")
      alert(`Failed to decrypt file: ${error.message}`)
    }
  }

  triggerDownload(blob, filename) {
    const url = URL.createObjectURL(blob)
    const a = document.createElement("a")
    a.href = url
    a.download = filename
    document.body.appendChild(a)
    a.click()
    document.body.removeChild(a)
    URL.revokeObjectURL(url)
  }

  base64ToArrayBuffer(base64) {
    const binary = atob(base64)
    const bytes = new Uint8Array(binary.length)
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i)
    }
    return bytes.buffer
  }
}
