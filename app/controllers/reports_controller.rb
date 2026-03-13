# frozen_string_literal: true

class ReportsController < BaseController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :check_feature_enabled

  def index
    @period = params[:period] || "30"
    @since = @period.to_i.days.ago

    # Overall stats
    @total_users = User.count
    @total_pushes = Push.count
    @active_pushes = Push.where(expired: false).count
    @total_views = AuditLog.where(kind: [:view, :failed_view]).count

    # Period stats
    @period_pushes = Push.where("created_at >= ?", @since).count
    @period_views = AuditLog.where(kind: [:view, :failed_view]).where("created_at >= ?", @since).count
    @period_users = User.where("created_at >= ?", @since).count

    # Push breakdown by kind
    @pushes_by_kind = Push.where("created_at >= ?", @since).group(:kind).count

    # Daily push creation trend (last N days)
    @daily_pushes = Push.where("created_at >= ?", @since)
      .group_by_day
      .to_a

    # Daily views trend
    @daily_views = AuditLog.where(kind: [:view, :failed_view])
      .where("created_at >= ?", @since)
      .group_by_day
      .to_a

    # Top users by push count
    @top_users = Push.where("created_at >= ?", @since)
      .where.not(user_id: nil)
      .group(:user_id)
      .order("count_all DESC")
      .limit(10)
      .count
      .map { |uid, count| [User.find_by(id: uid)&.email || "Unknown", count] }

    # Compliance: 2FA adoption
    if Settings.respond_to?(:enable_two_factor) && Settings.enable_two_factor
      @two_fa_enabled = User.where(otp_required_for_login: true).count
      @two_fa_total = User.count
    end

    # CSP tenant stats (if enabled)
    if Settings.respond_to?(:enable_csp_integration) && Settings.enable_csp_integration
      @csp_tenants_total = CspTenant.count
      @csp_tenants_sso = CspTenant.sso_enabled.count
      @csp_tenants_onboarded = CspTenant.onboarded.count
    end

    # Expiration method breakdown
    @expired_by_views = AuditLog.where(kind: :expire).where("created_at >= ?", @since).count
    @failed_passphrases = AuditLog.where(kind: :failed_passphrase).where("created_at >= ?", @since).count
  end

  private

  def require_admin
    unless current_user.admin?
      redirect_to root_path, alert: _("Access denied.")
    end
  end

  def check_feature_enabled
    unless Settings.respond_to?(:enable_reports) && Settings.enable_reports
      redirect_to root_path
    end
  end
end
