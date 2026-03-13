# frozen_string_literal: true

require "test_helper"

class CspTenantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_csp_integration = true
    Settings.enable_logins = true
    @admin = users(:mr_admin)
    sign_in @admin
  end

  teardown do
    Settings.enable_csp_integration = false
  end

  # --- index ---

  test "index lists tenants" do
    get csp_tenants_path
    assert_response :success
    assert_match "Acme Corp", response.body
  end

  test "index requires admin" do
    sign_in users(:one)
    get csp_tenants_path
    assert_redirected_to root_path
  end

  test "index redirects when feature disabled" do
    Settings.enable_csp_integration = false
    get csp_tenants_path
    assert_redirected_to root_path
  end

  # --- show ---

  test "show displays tenant" do
    tenant = csp_tenants(:acme_tenant)
    get csp_tenant_path(tenant)
    assert_response :success
    assert_match "Acme Corp", response.body
  end

  # --- edit + update ---

  test "edit renders form" do
    tenant = csp_tenants(:acme_tenant)
    get edit_csp_tenant_path(tenant)
    assert_response :success
  end

  test "update tenant" do
    tenant = csp_tenants(:acme_tenant)
    patch csp_tenant_path(tenant), params: {csp_tenant: {contact_email: "new@acme.com"}}
    assert_redirected_to csp_tenants_path
    assert_equal "new@acme.com", tenant.reload.contact_email
  end

  # --- toggle_sso ---

  test "toggle_sso enables then disables" do
    tenant = csp_tenants(:contoso_tenant)
    assert_not tenant.sso_enabled?

    post toggle_sso_csp_tenant_path(tenant)
    assert_redirected_to csp_tenants_path
    assert tenant.reload.sso_enabled?

    post toggle_sso_csp_tenant_path(tenant)
    assert_not tenant.reload.sso_enabled?
  end

  # --- onboard ---

  test "onboard sends email and marks onboarded" do
    tenant = csp_tenants(:contoso_tenant)
    assert_nil tenant.onboarded_at

    assert_enqueued_emails 1 do
      post onboard_csp_tenant_path(tenant)
    end
    assert_redirected_to csp_tenants_path
    assert_not_nil tenant.reload.onboarded_at
  end

  test "onboard fails without contact email" do
    tenant = csp_tenants(:disabled_tenant)
    post onboard_csp_tenant_path(tenant)
    assert_redirected_to csp_tenants_path
    assert_match(/contact email/i, flash[:alert])
  end

  # --- destroy ---

  test "destroy removes tenant" do
    tenant = csp_tenants(:disabled_tenant)
    assert_difference("CspTenant.count", -1) do
      delete csp_tenant_path(tenant)
    end
    assert_redirected_to csp_tenants_path
  end
end
