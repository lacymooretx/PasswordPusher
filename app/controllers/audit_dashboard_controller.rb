# frozen_string_literal: true

class AuditDashboardController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled

  def index
    @audit_logs = AuditLog.joins(:push)
      .where(pushes: {user_id: current_user.id})
      .includes(:push)
      .order(created_at: :desc)

    # Filters
    @audit_logs = @audit_logs.where(kind: params[:kind]) if params[:kind].present?
    @audit_logs = @audit_logs.where(ip: params[:ip]) if params[:ip].present?
    if params[:push_token].present?
      @audit_logs = @audit_logs.joins(:push).where(pushes: {url_token: params[:push_token]})
    end

    @audit_logs = @audit_logs.page(params[:page]).per(25)
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_audit_dashboard) && Settings.enable_audit_dashboard
      redirect_to root_path, alert: "This feature is not enabled."
    end
  end
end
