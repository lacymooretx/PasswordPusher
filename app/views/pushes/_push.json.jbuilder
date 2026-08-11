json.extract! push, :expire_after_views,
  :expired,
  :url_token,
  :deletable_by_viewer,
  :retrieval_step,
  :expired_on,
  :passphrase,
  :created_at,
  :updated_at,
  :expire_after_days,
  :days_remaining,
  :views_remaining,
  :deleted

json.json_url secret_url(push) + ".json"
json.html_url secret_url(push)

if %w[create active expired].include?(controller.action_name)
  json.note push.note
  json.name push.name
end

# Inline dispatch summary: only present when the create request carried a
# `dispatch` object, so existing clients see an unchanged response shape.
if controller.action_name == "create" && (result = controller.instance_variable_get(:@dispatch_result))
  json.dispatch do
    json.queued result.dispatches.size
    json.errors result.errors
    json.dispatches result.dispatches.map { |d|
      {
        id: d.id,
        channel: d.channel,
        role: d.role,
        destination: d.masked_destination,
        status: d.status
      }
    }
  end
end

if controller.action_name == "show"
  json.payload push.payload

  json.files_encrypted push.files_encrypted?
  if push.files_encrypted?
    json.file_encryption_key push.file_encryption_key
  end

  json.files do
    json.array! push.files do |file|
      json.filename file.filename.to_s
      json.content_type file.content_type
      json.byte_size file.byte_size
      json.url rails_blob_url(file)
    end
  end
end
