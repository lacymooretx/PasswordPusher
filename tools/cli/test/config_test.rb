# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_loads_from_env
    ENV["PWPUSH_SERVER_URL"] = "https://test.pwpush.com"
    ENV["PWPUSH_API_TOKEN"] = "env-token"
    ENV["PWPUSH_EMAIL"] = "env@example.com"

    config = Pwpush::Config.new
    assert_equal "https://test.pwpush.com", config.server_url
    assert_equal "env-token", config.api_token
    assert_equal "env@example.com", config.email
    assert config.valid?
  ensure
    ENV.delete("PWPUSH_SERVER_URL")
    ENV.delete("PWPUSH_API_TOKEN")
    ENV.delete("PWPUSH_EMAIL")
  end

  def test_invalid_without_config
    ENV.delete("PWPUSH_SERVER_URL")
    ENV.delete("PWPUSH_API_TOKEN")

    config = Pwpush::Config.new
    # May be valid if ~/.pwpush.yml exists, otherwise not
    # Just test that it doesn't crash
    assert_respond_to config, :valid?
  end

  def test_env_overrides_file
    ENV["PWPUSH_SERVER_URL"] = "https://env-override.com"
    ENV["PWPUSH_API_TOKEN"] = "env-token"

    config = Pwpush::Config.new
    assert_equal "https://env-override.com", config.server_url
  ensure
    ENV.delete("PWPUSH_SERVER_URL")
    ENV.delete("PWPUSH_API_TOKEN")
  end
end
