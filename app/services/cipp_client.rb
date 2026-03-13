# frozen_string_literal: true

# Service client for the CIPP (CyberDrain Improved Partner Portal) API.
# Uses OAuth 2.0 Client Credentials flow to authenticate.
#
# Required environment variables:
#   CIPP_API_URL      - Base URL (e.g. https://cippt7cnx.azurewebsites.net)
#   CIPP_TENANT_ID    - Azure AD tenant hosting CIPP
#   CIPP_CLIENT_ID    - App registration client ID
#   CIPP_CLIENT_SECRET - App registration client secret
#
class CippClient
  TOKEN_EXPIRY_BUFFER = 300 # Refresh 5 minutes before expiration

  class Error < StandardError; end
  class AuthenticationError < Error; end
  class ApiError < Error; end

  def initialize
    @api_url = ENV.fetch("CIPP_API_URL")
    @tenant_id = ENV.fetch("CIPP_TENANT_ID")
    @client_id = ENV.fetch("CIPP_CLIENT_ID")
    @client_secret = ENV.fetch("CIPP_CLIENT_SECRET")
    @token = nil
    @token_expires_at = Time.at(0)
  end

  # List all CSP tenants
  def list_tenants
    get("/api/ListTenants")
  end

  # List users for a specific tenant
  def list_users(tenant_filter)
    get("/api/ListUsers", tenantFilter: tenant_filter)
  end

  # List users with MFA info for a specific tenant
  def list_mfa_users(tenant_filter)
    get("/api/ListMFAUsers", tenantFilter: tenant_filter)
  end

  # Sync all CSP tenants into the local database.
  # Creates new CspTenant records and updates existing ones.
  # Returns {created: N, updated: N, total: N}
  def sync_tenants!
    tenants = list_tenants
    created = 0
    updated = 0

    tenants.each do |t|
      tid = t["customerId"] || t["tenantId"] || t["defaultDomainName"]
      next if tid.blank?

      name = t["displayName"] || t["defaultDomainName"] || "Unknown"
      domain = t["defaultDomainName"] || ""

      record = CspTenant.find_or_initialize_by(tenant_id: tid)
      is_new = record.new_record?
      record.assign_attributes(
        name: name,
        domain: domain,
        last_synced_at: Time.current
      )
      record.save!

      is_new ? created += 1 : updated += 1
    end

    {created: created, updated: updated, total: tenants.size}
  end

  private

  def get(path, params = {})
    ensure_token!
    uri = URI("#{@api_url}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{@token}"
    request["Content-Type"] = "application/json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.open_timeout = 10
      http.read_timeout = 30
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise ApiError, "CIPP API error: #{response.code} #{response.body&.truncate(200)}"
    end

    JSON.parse(response.body)
  end

  def ensure_token!
    return if @token && Time.current < @token_expires_at

    uri = URI("https://login.microsoftonline.com/#{@tenant_id}/oauth2/v2.0/token")

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(
      "client_id" => @client_id,
      "client_secret" => @client_secret,
      "scope" => "api://#{@client_id}/.default",
      "grant_type" => "client_credentials"
    )

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.open_timeout = 10
      http.read_timeout = 10
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      raise AuthenticationError, "Failed to authenticate with CIPP: #{response.code}"
    end

    data = JSON.parse(response.body)
    @token = data["access_token"]
    @token_expires_at = Time.current + data.fetch("expires_in", 3599).to_i - TOKEN_EXPIRY_BUFFER
  end
end
