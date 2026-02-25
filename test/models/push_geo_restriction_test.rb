# frozen_string_literal: true

require "test_helper"

class PushGeoRestrictionTest < ActiveSupport::TestCase
  test "country_allowed? returns true when no restrictions" do
    push = pushes(:test_push)
    assert push.country_allowed?("1.2.3.4")
  end

  test "country_allowed? returns true when lookup returns nil" do
    push = pushes(:test_push)
    push.allowed_countries = "US, GB"
    # GeoipLookup.country_code returns nil when no DB available
    assert push.country_allowed?("1.2.3.4")
  end

  test "country_allowed? matches country code" do
    push = pushes(:test_push)
    push.allowed_countries = "US, GB"

    GeoipLookup.stub :country_code, "US" do
      assert push.country_allowed?("1.2.3.4")
    end

    GeoipLookup.stub :country_code, "GB" do
      assert push.country_allowed?("1.2.3.4")
    end

    GeoipLookup.stub :country_code, "DE" do
      assert_not push.country_allowed?("1.2.3.4")
    end
  end

  test "country_allowed? is case insensitive" do
    push = pushes(:test_push)
    push.allowed_countries = "us, gb"

    GeoipLookup.stub :country_code, "US" do
      assert push.country_allowed?("1.2.3.4")
    end
  end
end
