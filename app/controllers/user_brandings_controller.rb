# frozen_string_literal: true

# Settings page for per-user branding customization (logo, colors, text).
# Builds or finds the user's UserBranding record. Requires Settings.enable_user_branding.
class UserBrandingsController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled

  def edit
    @user_branding = current_user.user_branding || current_user.build_user_branding
  end

  def update
    @user_branding = current_user.user_branding || current_user.build_user_branding
    @user_branding.assign_attributes(user_branding_params)

    if @user_branding.save
      redirect_to edit_user_branding_path, notice: I18n._("Your branding settings have been saved.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_user_branding) && Settings.enable_user_branding
      redirect_to root_path, notice: I18n._("This feature is not enabled.")
    end
  end

  def user_branding_params
    params.require(:user_branding).permit(
      :delivery_heading, :delivery_message, :delivery_footer,
      :white_label, :brand_title, :brand_tagline,
      :primary_color, :background_color, :logo, :dark_logo
    )
  end
end
