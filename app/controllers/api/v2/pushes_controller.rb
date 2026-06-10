# frozen_string_literal: true

# APIv2 pushes endpoint.
#
# Inherits the full behaviour (and security gating) of the v1 controller and
# only changes the request shape: v2 accepts a single, consistent `push`
# parameter namespace (instead of v1's `password` / `file_push` / `url`),
# matching upstream GH #4371. File uploads imply a file push unless `kind`
# is given explicitly.
class Api::V2::PushesController < Api::V1::PushesController
  private

  def push_params
    permitted = params.require(:push).permit(:name, :kind, :expire_after_days, :expire_after_views,
      :deletable_by_viewer, :retrieval_step, :payload, :note, :passphrase,
      :allowed_ips, :allowed_countries, :file_encryption_key, :custom_url_token, files: [])

    # For v2 requests, file uploads imply a file push unless kind is explicit.
    if permitted[:kind].blank? && permitted[:files].present?
      permitted[:kind] = "file"
    end

    permitted
  rescue => e
    Rails.logger.error("Error in push_params: #{e.message}")
    raise e
  end
end
