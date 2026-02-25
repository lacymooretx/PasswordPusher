# frozen_string_literal: true

require "test_helper"

class GeoipLookupTest < ActiveSupport::TestCase
  test "returns nil when database not available" do
    assert_nil GeoipLookup.country_code("1.2.3.4")
  end

  test "database_available? returns false when no path configured" do
    assert_not GeoipLookup.database_available?
  end
end
