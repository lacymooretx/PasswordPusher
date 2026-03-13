# frozen_string_literal: true

require "test_helper"

class CspTenantTest < ActiveSupport::TestCase
  test "valid tenant" do
    tenant = CspTenant.new(tenant_id: "new-id", name: "Test", domain: "test.com")
    assert tenant.valid?
  end

  test "requires tenant_id" do
    tenant = CspTenant.new(name: "Test", domain: "test.com")
    assert_not tenant.valid?
  end

  test "requires name" do
    tenant = CspTenant.new(tenant_id: "id", domain: "test.com")
    assert_not tenant.valid?
  end

  test "requires domain" do
    tenant = CspTenant.new(tenant_id: "id", name: "Test")
    assert_not tenant.valid?
  end

  test "tenant_id must be unique" do
    existing = csp_tenants(:acme_tenant)
    duplicate = CspTenant.new(tenant_id: existing.tenant_id, name: "Dup", domain: "dup.com")
    assert_not duplicate.valid?
  end

  test "sso_enabled scope" do
    enabled = CspTenant.sso_enabled
    assert enabled.all?(&:sso_enabled?)
    assert_includes enabled, csp_tenants(:acme_tenant)
    assert_not_includes enabled, csp_tenants(:contoso_tenant)
  end

  test "onboarded? returns true when onboarded_at set" do
    tenant = csp_tenants(:acme_tenant)
    tenant.update!(onboarded_at: Time.current)
    assert tenant.onboarded?
  end

  test "mark_onboarded! sets timestamp" do
    tenant = csp_tenants(:contoso_tenant)
    assert_nil tenant.onboarded_at
    tenant.mark_onboarded!
    assert_not_nil tenant.reload.onboarded_at
  end
end
