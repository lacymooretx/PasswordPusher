# frozen_string_literal: true

class Api::V1::UserBrandingsController < Api::BaseController
  before_action :check_feature_enabled

  resource_description do
    name "User Branding"
    short "Manage per-user branding settings."
  end

  api :GET, "/api/v1/user_branding.json", "Get your branding settings."
  formats ["JSON"]
  description <<-EOS
    Retrieves the branding settings for the authenticated user. Returns
    default values if no branding has been configured yet.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "User branding feature is not enabled."
  def show
    branding = current_user.user_branding || current_user.build_user_branding
    render json: branding_json(branding)
  end

  api :PUT, "/api/v1/user_branding.json", "Update your branding settings."
  param :user_branding, Hash, desc: "Branding attributes.", required: true do
    param :brand_title, String, desc: "Custom title displayed on push delivery pages."
    param :brand_tagline, String, desc: "Custom tagline displayed below the title."
    param :primary_color, String, desc: "Primary color hex code (e.g. '#3B82F6')."
    param :background_color, String, desc: "Background color hex code."
    param :delivery_heading, String, desc: "Custom heading on the push delivery page."
    param :delivery_message, String, desc: "Custom message body on delivery pages."
    param :delivery_footer, String, desc: "Custom footer text on delivery pages."
    param :white_label, [true, false], desc: "Remove PasswordPusher branding when true."
  end
  formats ["JSON"]
  description <<-EOS
    Updates branding settings for the authenticated user. These settings
    customize the appearance of push delivery pages for your recipients.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "User branding feature is not enabled."
  error code: 422, desc: "Validation failed."
  def update
    branding = current_user.user_branding || current_user.build_user_branding

    if branding.update(branding_params)
      render json: branding_json(branding)
    else
      render json: {errors: branding.errors.full_messages}, status: :unprocessable_content
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_user_branding) && Settings.enable_user_branding
      render json: {error: "User branding feature is not enabled"}, status: :not_found
    end
  end

  def branding_params
    params.require(:user_branding).permit(
      :brand_title, :brand_tagline, :primary_color, :background_color,
      :delivery_heading, :delivery_message, :delivery_footer, :white_label
    )
  end

  def branding_json(branding)
    {
      brand_title: branding.brand_title,
      brand_tagline: branding.brand_tagline,
      primary_color: branding.primary_color,
      background_color: branding.background_color,
      delivery_heading: branding.delivery_heading,
      delivery_message: branding.delivery_message,
      delivery_footer: branding.delivery_footer,
      white_label: branding.white_label,
      has_logo: branding.logo.attached?
    }
  end
end
