# frozen_string_literal: true

class Api::V1::ReportsController < Api::BaseController
  before_action :require_admin
  before_action :check_feature_enabled

  resource_description do
    name "Reports"
    short "Usage and compliance reporting."
  end

  api :GET, "/api/v1/reports.json", "Get usage and compliance statistics."
  param :period, :number, desc: "Number of days to report on (default: 30)."
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 403, desc: "Admin access required."
  def index
    period = (params[:period] || 30).to_i
    since = period.days.ago

    render json: {
      overview: {
        total_users: User.count,
        total_pushes: Push.count,
        active_pushes: Push.where(expired: false).count,
        total_views: AuditLog.where(kind: [:view, :failed_view]).count
      },
      period: {
        days: period,
        pushes: Push.where("created_at >= ?", since).count,
        views: AuditLog.where(kind: [:view, :failed_view]).where("created_at >= ?", since).count,
        new_users: User.where("created_at >= ?", since).count
      },
      pushes_by_kind: Push.where("created_at >= ?", since).group(:kind).count,
      daily_pushes: Push.where("created_at >= ?", since).group_by_day,
      daily_views: AuditLog.where(kind: [:view, :failed_view]).where("created_at >= ?", since).group_by_day,
      security: {
        expirations: AuditLog.where(kind: :expire).where("created_at >= ?", since).count,
        failed_passphrases: AuditLog.where(kind: :failed_passphrase).where("created_at >= ?", since).count
      }
    }
  end

  private

  def require_admin
    unless current_user&.admin?
      render json: {error: "Admin access required"}, status: :forbidden
    end
  end

  def check_feature_enabled
    unless Settings.respond_to?(:enable_reports) && Settings.enable_reports
      render json: {error: "Reports feature is not enabled"}, status: :not_found
    end
  end
end
