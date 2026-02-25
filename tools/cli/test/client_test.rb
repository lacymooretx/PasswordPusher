# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  def setup
    @config = Pwpush::Config.new
    @config.server_url = "https://pwpush.example.com"
    @config.api_token = "test-token-123"
    @config.email = "test@example.com"
    @client = Pwpush::Client.new(@config)
  end

  def test_create_push
    stub_request(:post, "https://pwpush.example.com/p.json")
      .with(
        headers: {
          "X-User-Email" => "test@example.com",
          "X-User-Token" => "test-token-123",
          "Content-Type" => "application/json"
        }
      )
      .to_return(
        status: 201,
        body: {url_token: "abc123", days_remaining: 7, views_remaining: 10}.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = @client.create_push("my secret")
    assert_equal "abc123", result["url_token"]
    assert_equal 7, result["days_remaining"]
    assert_equal 10, result["views_remaining"]
  end

  def test_get_push
    stub_request(:get, "https://pwpush.example.com/p/abc123.json")
      .to_return(
        status: 200,
        body: {url_token: "abc123", payload: "my secret", expired: false}.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = @client.get_push("abc123")
    assert_equal "my secret", result["payload"]
    assert_equal false, result["expired"]
  end

  def test_get_push_with_passphrase
    stub_request(:get, "https://pwpush.example.com/p/abc123.json?passphrase=secret")
      .to_return(
        status: 200,
        body: {url_token: "abc123", payload: "my secret"}.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = @client.get_push("abc123", passphrase: "secret")
    assert_equal "my secret", result["payload"]
  end

  def test_expire_push
    stub_request(:delete, "https://pwpush.example.com/p/abc123.json")
      .to_return(
        status: 200,
        body: {url_token: "abc123", expired: true}.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = @client.expire_push("abc123")
    assert_equal true, result["expired"]
  end

  def test_active_pushes
    stub_request(:get, "https://pwpush.example.com/p/active.json?page=1")
      .to_return(
        status: 200,
        body: [{url_token: "abc123", days_remaining: 5}].to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = @client.active_pushes
    assert_equal 1, result.length
    assert_equal "abc123", result.first["url_token"]
  end

  def test_expired_pushes
    stub_request(:get, "https://pwpush.example.com/p/expired.json?page=1")
      .to_return(
        status: 200,
        body: [{url_token: "xyz789", expired: true}].to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = @client.expired_pushes
    assert_equal 1, result.length
    assert_equal "xyz789", result.first["url_token"]
  end

  def test_version
    stub_request(:get, "https://pwpush.example.com/api/v1/version.json")
      .to_return(
        status: 200,
        body: {version: "1.68.2"}.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = @client.version
    assert_equal "1.68.2", result["version"]
  end

  def test_authentication_error
    stub_request(:post, "https://pwpush.example.com/p.json")
      .to_return(status: 401, body: "Unauthorized")

    assert_raises(Pwpush::Client::ApiError) do
      @client.create_push("test")
    end
  end

  def test_bearer_auth_when_no_email
    config = Pwpush::Config.new
    config.server_url = "https://pwpush.example.com"
    config.api_token = "bearer-token"
    client = Pwpush::Client.new(config)

    stub_request(:get, "https://pwpush.example.com/api/v1/version.json")
      .with(headers: {"Authorization" => "Bearer bearer-token"})
      .to_return(
        status: 200,
        body: {version: "1.0"}.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    result = client.version
    assert_equal "1.0", result["version"]
  end

  def test_validation_error
    stub_request(:post, "https://pwpush.example.com/p.json")
      .to_return(
        status: 422,
        body: {errors: ["Payload is required."]}.to_json,
        headers: {"Content-Type" => "application/json"}
      )

    error = assert_raises(Pwpush::Client::ApiError) do
      @client.create_push("")
    end
    assert_includes error.message, "Payload is required"
  end
end
