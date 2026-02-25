# frozen_string_literal: true

# JSON API for querying audit logs. Token-authenticated via Api::BaseController.
# Requires Settings.enable_audit_dashboard. Returns audit logs for pushes
# owned by the authenticated user, with optional filtering.
class Api::V1::AuditLogsController < Api::BaseController
  before_action :check_feature_enabled

  resource_description do
    name "Audit Logs"
    short "Query audit logs for your pushes."
  end

  api :GET, "/api/v1/audit_logs.json", "List audit logs for your pushes."
  param :kind, String, desc: "Filter by audit log kind (e.g. creation, view, expire, failed_passphrase)."
  param :ip, String, desc: "Filter by IP address."
  param :push_token, String, desc: "Filter by push URL token."
  param :page, :number, desc: "Page number for pagination (50 per page)."
  formats ["JSON"]
  description <<-EOS
    Returns audit log entries for all pushes owned by the authenticated user,
    ordered by creation date descending. Supports filtering by kind, IP address,
    and push token. Paginated at 50 entries per page.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Audit dashboard feature is not enabled."
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

    @audit_logs = @audit_logs.page(params[:page]).per(50)

    render json: {
      audit_logs: @audit_logs.map { |log| audit_log_json(log) },
      page: @audit_logs.current_page,
      total_pages: @audit_logs.total_pages,
      total_count: @audit_logs.total_count
    }
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_audit_dashboard) && Settings.enable_audit_dashboard
      render json: {error: "Audit dashboard feature is not enabled"}, status: :not_found
    end
  end

  def audit_log_json(log)
    {
      id: log.id,
      kind: log.kind,
      ip: log.ip,
      user_agent: log.user_agent,
      referrer: log.referrer,
      push_url_token: log.push&.url_token,
      push_kind: log.push&.kind,
      created_at: log.created_at.iso8601
    }
  end
end
