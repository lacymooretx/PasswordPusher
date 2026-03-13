# frozen_string_literal: true

# Scans uploaded files for malware using ClamAV.
# If a virus is detected, the push is expired and marked as quarantined.
class FileScanJob < ApplicationJob
  queue_as :default
  retry_on ClamavScanner::ConnectionError, wait: 1.minute, attempts: 3

  def perform(push_id)
    return unless Settings.respond_to?(:enable_clamav) && Settings.enable_clamav

    push = Push.find_by(id: push_id)
    return unless push&.files&.attached?

    push.files.each do |file|
      data = file.download
      result = ClamavScanner.scan(data)

      unless result.clean?
        Rails.logger.warn "ClamAV: Virus detected in push #{push.id}: #{result.virus}"

        # Expire the push to quarantine it
        push.expire!
        push.update_column(:note_ciphertext, nil) # Clear any note

        # Log the quarantine
        push.audit_logs.create!(
          kind: :expire,
          ip: "system",
          user_agent: "ClamAV: #{result.virus}"
        )

        break # No need to scan remaining files
      end
    end
  end
end
