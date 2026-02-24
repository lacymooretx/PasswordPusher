# frozen_string_literal: true

class UserPoliciesController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled

  def edit
    @user_policy = current_user.user_policy || current_user.build_user_policy
  end

  def update
    @user_policy = current_user.user_policy || current_user.build_user_policy
    @user_policy.assign_attributes(user_policy_params)

    if @user_policy.save
      redirect_to edit_user_policy_path, notice: I18n._("Your push defaults have been saved.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_user_policies) && Settings.enable_user_policies
      redirect_to root_path, notice: I18n._("This feature is not enabled.")
    end
  end

  def user_policy_params
    params.require(:user_policy).permit(
      :pw_expire_after_days, :pw_expire_after_views,
      :pw_retrieval_step, :pw_deletable_by_viewer,
      :url_expire_after_days, :url_expire_after_views,
      :url_retrieval_step,
      :file_expire_after_days, :file_expire_after_views,
      :file_retrieval_step, :file_deletable_by_viewer,
      :qr_expire_after_days, :qr_expire_after_views,
      :qr_retrieval_step, :qr_deletable_by_viewer
    )
  end
end
