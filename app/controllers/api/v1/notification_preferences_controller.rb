# frozen_string_literal: true

# JSON API for managing push notification email preferences.
# Token-authenticated via Api::BaseController. Requires Settings.enable_push_notifications.
class Api::V1::NotificationPreferencesController < Api::BaseController
  before_action :check_feature_enabled

  resource_description do
    name "Notification Preferences"
    short "Manage push notification email preferences."
  end

  api :GET, "/api/v1/account/notifications.json", "Get notification preferences."
  formats ["JSON"]
  description <<-EOS
    Returns the current user's email notification preferences for push events.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Push notifications feature is not enabled."
  def show
    render json: notification_json
  end

  api :PATCH, "/api/v1/account/notifications.json", "Update notification preferences."
  param :notify_on_view, [true, false], desc: "Email when a push is viewed."
  param :notify_on_expire, [true, false], desc: "Email when a push expires."
  param :notify_on_expiring_soon, [true, false], desc: "Email when a push is about to expire."
  formats ["JSON"]
  description <<-EOS
    Updates the current user's email notification preferences. Only the
    provided fields will be updated.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Push notifications feature is not enabled."
  error code: 422, desc: "Validation failed."
  def update
    if current_user.update(notification_params)
      render json: notification_json
    else
      render json: {errors: current_user.errors.full_messages}, status: :unprocessable_content
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_push_notifications) && Settings.enable_push_notifications
      render json: {error: "Push notifications feature is not enabled"}, status: :not_found
    end
  end

  def notification_params
    params.permit(:notify_on_view, :notify_on_expire, :notify_on_expiring_soon)
  end

  def notification_json
    {
      notify_on_view: current_user.notify_on_view,
      notify_on_expire: current_user.notify_on_expire,
      notify_on_expiring_soon: current_user.notify_on_expiring_soon
    }
  end
end
