# frozen_string_literal: true

class CspTenantsController < BaseController
  before_action :authenticate_user!
  before_action :require_admin
  before_action :check_feature_enabled
  before_action :set_csp_tenant, only: [:show, :edit, :update, :destroy, :onboard, :toggle_sso]

  def index
    @csp_tenants = CspTenant.order(:name)
  end

  def show
  end

  def edit
  end

  def update
    if @csp_tenant.update(csp_tenant_params)
      redirect_to csp_tenants_path, notice: _("Tenant updated successfully.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @csp_tenant.destroy
    redirect_to csp_tenants_path, notice: _("Tenant removed.")
  end

  # POST /csp_tenants/sync — sync tenants from CIPP API
  def sync
    result = CippClient.new.sync_tenants!
    redirect_to csp_tenants_path, notice: _("Synced %{total} tenants (%{created} new, %{updated} updated).") % result
  rescue CippClient::Error => e
    redirect_to csp_tenants_path, alert: _("Sync failed: %{error}") % {error: e.message}
  end

  # POST /csp_tenants/:id/onboard — send onboarding email
  def onboard
    email = @csp_tenant.contact_email
    unless email.present?
      redirect_to csp_tenants_path, alert: _("No contact email set for this tenant.")
      return
    end

    ClientMailer.onboarding_email(@csp_tenant, email).deliver_later
    @csp_tenant.mark_onboarded!
    redirect_to csp_tenants_path, notice: _("Onboarding email sent to %{email}.") % {email: email}
  end

  # POST /csp_tenants/:id/toggle_sso — toggle SSO access
  def toggle_sso
    @csp_tenant.update!(sso_enabled: !@csp_tenant.sso_enabled)
    status = @csp_tenant.sso_enabled ? _("enabled") : _("disabled")
    redirect_to csp_tenants_path, notice: _("SSO %{status} for %{name}.") % {status: status, name: @csp_tenant.name}
  end

  private

  def require_admin
    unless current_user.admin?
      redirect_to root_path, alert: _("Access denied.")
    end
  end

  def check_feature_enabled
    unless Settings.respond_to?(:enable_csp_integration) && Settings.enable_csp_integration
      redirect_to root_path
    end
  end

  def set_csp_tenant
    @csp_tenant = CspTenant.find(params[:id])
  end

  def csp_tenant_params
    params.require(:csp_tenant).permit(:name, :domain, :contact_email, :sso_enabled)
  end
end
