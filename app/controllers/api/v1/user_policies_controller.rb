# frozen_string_literal: true

class Api::V1::UserPoliciesController < Api::BaseController
  before_action :check_feature_enabled

  api :GET, "/api/v1/user_policy.json", "Retrieve your push defaults"
  formats ["json"]
  description "Returns the current user's personal push default settings."
  def show
    @user_policy = current_user.user_policy
    if @user_policy
      render json: @user_policy.as_json(except: [:id, :user_id, :created_at, :updated_at])
    else
      render json: {}
    end
  end

  api :PUT, "/api/v1/user_policy.json", "Update your push defaults"
  formats ["json"]
  description "Update the current user's personal push default settings. Only provided fields are updated."
  param :user_policy, Hash, desc: "User policy attributes", required: true do
    param :pw_expire_after_days, Integer, desc: "Default days for password pushes", required: false
    param :pw_expire_after_views, Integer, desc: "Default views for password pushes", required: false
    param :pw_retrieval_step, [true, false], desc: "Default retrieval step for password pushes", required: false
    param :pw_deletable_by_viewer, [true, false], desc: "Default deletable for password pushes", required: false
    param :url_expire_after_days, Integer, desc: "Default days for URL pushes", required: false
    param :url_expire_after_views, Integer, desc: "Default views for URL pushes", required: false
    param :url_retrieval_step, [true, false], desc: "Default retrieval step for URL pushes", required: false
    param :file_expire_after_days, Integer, desc: "Default days for file pushes", required: false
    param :file_expire_after_views, Integer, desc: "Default views for file pushes", required: false
    param :file_retrieval_step, [true, false], desc: "Default retrieval step for file pushes", required: false
    param :file_deletable_by_viewer, [true, false], desc: "Default deletable for file pushes", required: false
    param :qr_expire_after_days, Integer, desc: "Default days for QR pushes", required: false
    param :qr_expire_after_views, Integer, desc: "Default views for QR pushes", required: false
    param :qr_retrieval_step, [true, false], desc: "Default retrieval step for QR pushes", required: false
    param :qr_deletable_by_viewer, [true, false], desc: "Default deletable for QR pushes", required: false
  end
  def update
    @user_policy = current_user.user_policy || current_user.build_user_policy
    @user_policy.assign_attributes(user_policy_params)

    if @user_policy.save
      render json: @user_policy.as_json(except: [:id, :user_id, :created_at, :updated_at])
    else
      render json: {errors: @user_policy.errors.full_messages}, status: :unprocessable_content
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_user_policies) && Settings.enable_user_policies
      render json: {error: "User policies are not enabled."}, status: :not_found
    end
  end

  def current_user
    @current_user ||= user_from_token
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
