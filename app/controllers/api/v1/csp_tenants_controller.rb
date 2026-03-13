# frozen_string_literal: true

class Api::V1::CspTenantsController < Api::BaseController
  before_action :require_admin
  before_action :check_feature_enabled
  before_action :set_csp_tenant, only: [:show, :update, :destroy, :onboard, :toggle_sso]

  resource_description do
    name "CSP Tenants"
    short "Manage CSP client tenants discovered via CIPP."
  end

  api :GET, "/api/v1/csp_tenants.json", "List all CSP tenants."
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 403, desc: "Admin access required."
  def index
    tenants = CspTenant.order(:name)
    render json: tenants.map { |t| tenant_json(t) }
  end

  api :GET, "/api/v1/csp_tenants/:id.json", "Show a CSP tenant."
  param :id, :number, desc: "Tenant record ID.", required: true
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 404, desc: "Tenant not found."
  def show
    render json: tenant_json(@csp_tenant)
  end

  api :PATCH, "/api/v1/csp_tenants/:id.json", "Update a CSP tenant."
  param :id, :number, desc: "Tenant record ID.", required: true
  param :csp_tenant, Hash, desc: "Tenant attributes.", required: true do
    param :contact_email, String, desc: "Contact email."
    param :sso_enabled, :boolean, desc: "Enable SSO for this tenant."
  end
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 422, desc: "Validation failed."
  def update
    if @csp_tenant.update(csp_tenant_params)
      render json: tenant_json(@csp_tenant)
    else
      render json: {errors: @csp_tenant.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :DELETE, "/api/v1/csp_tenants/:id.json", "Delete a CSP tenant."
  param :id, :number, desc: "Tenant record ID.", required: true
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 404, desc: "Tenant not found."
  def destroy
    @csp_tenant.destroy
    head :no_content
  end

  api :POST, "/api/v1/csp_tenants/sync.json", "Sync tenants from CIPP API."
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  def sync
    result = CippClient.new.sync_tenants!
    render json: result
  rescue CippClient::Error => e
    render json: {error: e.message}, status: :service_unavailable
  end

  api :POST, "/api/v1/csp_tenants/:id/onboard.json", "Send onboarding email to tenant."
  param :id, :number, desc: "Tenant record ID.", required: true
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 422, desc: "No contact email set."
  def onboard
    unless @csp_tenant.contact_email.present?
      render json: {error: "No contact email set for this tenant"}, status: :unprocessable_content
      return
    end

    ClientMailer.onboarding_email(@csp_tenant, @csp_tenant.contact_email).deliver_later
    @csp_tenant.mark_onboarded!
    render json: {message: "Onboarding email sent", tenant: tenant_json(@csp_tenant)}
  end

  api :POST, "/api/v1/csp_tenants/:id/toggle_sso.json", "Toggle SSO for a tenant."
  param :id, :number, desc: "Tenant record ID.", required: true
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  def toggle_sso
    @csp_tenant.update!(sso_enabled: !@csp_tenant.sso_enabled)
    render json: tenant_json(@csp_tenant)
  end

  private

  def require_admin
    unless current_user&.admin?
      render json: {error: "Admin access required"}, status: :forbidden
    end
  end

  def check_feature_enabled
    unless Settings.respond_to?(:enable_csp_integration) && Settings.enable_csp_integration
      render json: {error: "CSP integration is not enabled"}, status: :not_found
    end
  end

  def set_csp_tenant
    @csp_tenant = CspTenant.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Tenant not found"}, status: :not_found
  end

  def csp_tenant_params
    params.require(:csp_tenant).permit(:contact_email, :sso_enabled)
  end

  def tenant_json(tenant)
    {
      id: tenant.id,
      tenant_id: tenant.tenant_id,
      name: tenant.name,
      domain: tenant.domain,
      sso_enabled: tenant.sso_enabled,
      contact_email: tenant.contact_email,
      user_count: tenant.user_count,
      onboarded: tenant.onboarded?,
      onboarded_at: tenant.onboarded_at&.iso8601,
      last_synced_at: tenant.last_synced_at&.iso8601,
      created_at: tenant.created_at.iso8601,
      updated_at: tenant.updated_at.iso8601
    }
  end
end
