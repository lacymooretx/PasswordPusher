# frozen_string_literal: true

require "yaml"

module Pwpush
  class Config
    CONFIG_FILE = File.expand_path("~/.pwpush.yml")

    attr_accessor :server_url, :api_token, :email

    def initialize
      load_from_env
      load_from_file if File.exist?(CONFIG_FILE)
      # Env vars take precedence over file
      load_from_env
    end

    def valid?
      server_url.present? && api_token.present?
    end

    def save!
      data = {
        "server_url" => server_url,
        "api_token" => api_token,
        "email" => email
      }.compact

      File.write(CONFIG_FILE, data.to_yaml)
      File.chmod(0o600, CONFIG_FILE)
    end

    private

    def load_from_env
      self.server_url = ENV["PWPUSH_SERVER_URL"] if ENV["PWPUSH_SERVER_URL"]
      self.api_token = ENV["PWPUSH_API_TOKEN"] if ENV["PWPUSH_API_TOKEN"]
      self.email = ENV["PWPUSH_EMAIL"] if ENV["PWPUSH_EMAIL"]
    end

    def load_from_file
      data = YAML.safe_load_file(CONFIG_FILE)
      return unless data.is_a?(Hash)

      self.server_url ||= data["server_url"]
      self.api_token ||= data["api_token"]
      self.email ||= data["email"]
    rescue Psych::SyntaxError
      # Ignore malformed config
    end
  end
end

# Polyfill for String#present? outside Rails
unless String.method_defined?(:present?)
  class String
    def present?
      !nil? && !empty?
    end
  end
end

unless NilClass.method_defined?(:present?)
  class NilClass
    def present?
      false
    end
  end
end
