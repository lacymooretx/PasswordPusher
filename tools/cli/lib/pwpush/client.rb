# frozen_string_literal: true

require "faraday"
require "json"

module Pwpush
  class Client
    class ApiError < StandardError
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        @status = status
        @body = body
        super(message)
      end
    end

    def initialize(config)
      @config = config
      @conn = Faraday.new(url: config.server_url) do |f|
        f.request :url_encoded
        f.headers["Content-Type"] = "application/json"
        f.headers["Accept"] = "application/json"

        if config.email.present?
          f.headers["X-User-Email"] = config.email
          f.headers["X-User-Token"] = config.api_token
        else
          f.headers["Authorization"] = "Bearer #{config.api_token}"
        end
      end
    end

    # Create a text push
    def create_push(payload, options = {})
      body = {
        password: {
          payload: payload,
          kind: options[:kind] || "text",
          expire_after_days: options[:expire_after_days],
          expire_after_views: options[:expire_after_views],
          passphrase: options[:passphrase],
          name: options[:name],
          note: options[:note],
          deletable_by_viewer: options[:deletable_by_viewer],
          retrieval_step: options[:retrieval_step]
        }.compact
      }

      response = @conn.post("/p.json", body.to_json)
      handle_response(response)
    end

    # Create a file push (multipart)
    def create_file_push(file_path, options = {})
      conn = Faraday.new(url: @config.server_url) do |f|
        f.request :multipart
        f.request :url_encoded
        f.headers["Accept"] = "application/json"

        if @config.email.present?
          f.headers["X-User-Email"] = @config.email
          f.headers["X-User-Token"] = @config.api_token
        else
          f.headers["Authorization"] = "Bearer #{@config.api_token}"
        end
      end

      payload = {
        "password[kind]" => "file",
        "password[files][]" => Faraday::Multipart::FilePart.new(file_path, "application/octet-stream")
      }
      payload["password[note]"] = options[:note] if options[:note]
      payload["password[name]"] = options[:name] if options[:name]
      payload["password[expire_after_days]"] = options[:expire_after_days].to_s if options[:expire_after_days]
      payload["password[expire_after_views]"] = options[:expire_after_views].to_s if options[:expire_after_views]

      response = conn.post("/p.json", payload)
      handle_response(response)
    end

    # Retrieve a push
    def get_push(url_token, passphrase: nil)
      path = "/p/#{url_token}.json"
      path += "?passphrase=#{CGI.escape(passphrase)}" if passphrase
      response = @conn.get(path)
      handle_response(response)
    end

    # Expire a push
    def expire_push(url_token)
      response = @conn.delete("/p/#{url_token}.json")
      handle_response(response)
    end

    # List active pushes
    def active_pushes(page: 1)
      response = @conn.get("/p/active.json", {page: page})
      handle_response(response)
    end

    # List expired pushes
    def expired_pushes(page: 1)
      response = @conn.get("/p/expired.json", {page: page})
      handle_response(response)
    end

    # Get server version
    def version
      response = @conn.get("/api/v1/version.json")
      handle_response(response)
    end

    private

    def handle_response(response)
      case response.status
      when 200..299
        JSON.parse(response.body)
      when 401
        raise ApiError.new("Authentication failed. Check your API token.", status: response.status, body: response.body)
      when 403
        raise ApiError.new("Access denied.", status: response.status, body: response.body)
      when 404
        raise ApiError.new("Not found.", status: response.status, body: response.body)
      when 422
        error_body = begin
          JSON.parse(response.body)
        rescue
          {}
        end
        message = error_body["errors"]&.join(", ") || error_body["error"] || "Validation failed"
        raise ApiError.new(message, status: response.status, body: response.body)
      else
        raise ApiError.new("API error (HTTP #{response.status})", status: response.status, body: response.body)
      end
    end
  end
end
