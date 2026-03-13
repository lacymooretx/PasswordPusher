# frozen_string_literal: true

require "test_helper"

class Api::V1::CspTenantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Settings.enable_csp_integration = true
    @admin = users(:mr_admin)
    sign_in @admin
  end

  teardown do
    Settings.enable_csp_integration = false
  end

  # --- index ---

  test "index returns tenants" do
    get api_v1_csp_tenants_path(format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert json.is_a?(Array)
    assert json.any? { |t| t["name"] == "Acme Corp" }
  end

  # --- show ---

  test "show returns tenant" do
    tenant = csp_tenants(:acme_tenant)
    get api_v1_csp_tenant_path(tenant, format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Acme Corp", json["name"]
    assert_equal true, json["sso_enabled"]
  end

  # --- update ---

  test "update tenant" do
    tenant = csp_tenants(:acme_tenant)
    patch api_v1_csp_tenant_path(tenant, format: :json), params: {
      csp_tenant: {contact_email: "new@acme.com", sso_enabled: false}
    }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "new@acme.com", json["contact_email"]
    assert_equal false, json["sso_enabled"]
  end

  # --- destroy ---

  test "destroy tenant" do
    tenant = csp_tenants(:disabled_tenant)
    assert_difference("CspTenant.count", -1) do
      delete api_v1_csp_tenant_path(tenant, format: :json)
    end
    assert_response :no_content
  end

  # --- toggle_sso ---

  test "toggle_sso toggles" do
    tenant = csp_tenants(:contoso_tenant)
    post toggle_sso_api_v1_csp_tenant_path(tenant, format: :json)
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["sso_enabled"]
  end

  # --- onboard ---

  test "onboard sends email" do
    tenant = csp_tenants(:contoso_tenant)
    assert_enqueued_emails 1 do
      post onboard_api_v1_csp_tenant_path(tenant, format: :json)
    end
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["tenant"]["onboarded"]
  end

  test "onboard fails without contact email" do
    tenant = csp_tenants(:disabled_tenant)
    post onboard_api_v1_csp_tenant_path(tenant, format: :json)
    assert_response :unprocessable_content
  end

  # --- access control ---

  test "non-admin gets forbidden" do
    sign_in users(:one)
    get api_v1_csp_tenants_path(format: :json)
    assert_response :forbidden
  end

  test "feature disabled returns not found" do
    Settings.enable_csp_integration = false
    get api_v1_csp_tenants_path(format: :json)
    assert_response :not_found
  end
end
