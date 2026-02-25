# frozen_string_literal: true

require "thor"
require "tty-table"

module Pwpush
  class CLI < Thor
    package_name "pwpush"

    desc "push TEXT", "Create a text push"
    long_desc "Creates a new text push with the given payload and returns the secret URL."
    option :days, type: :numeric, aliases: "-d", desc: "Expire after N days"
    option :views, type: :numeric, aliases: "-v", desc: "Expire after N views"
    option :passphrase, type: :string, aliases: "-p", desc: "Require passphrase to view"
    option :name, type: :string, aliases: "-n", desc: "Name for the push (visible in dashboard)"
    option :note, type: :string, desc: "Private note (only visible to creator)"
    option :deletable, type: :boolean, default: true, desc: "Allow viewers to delete"
    option :retrieval_step, type: :boolean, default: false, desc: "Add a retrieval step"
    def push(text)
      with_client do |client|
        result = client.create_push(text,
          expire_after_days: options[:days],
          expire_after_views: options[:views],
          passphrase: options[:passphrase],
          name: options[:name],
          note: options[:note],
          deletable_by_viewer: options[:deletable],
          retrieval_step: options[:retrieval_step])
        display_push_created(result)
      end
    end

    desc "file PATH", "Create a file push"
    option :days, type: :numeric, aliases: "-d", desc: "Expire after N days"
    option :views, type: :numeric, aliases: "-v", desc: "Expire after N views"
    option :name, type: :string, aliases: "-n", desc: "Name for the push"
    option :note, type: :string, desc: "Private note"
    def file(path)
      unless File.exist?(path)
        say_error "File not found: #{path}"
        return
      end

      with_client do |client|
        result = client.create_file_push(path,
          expire_after_days: options[:days],
          expire_after_views: options[:views],
          name: options[:name],
          note: options[:note])
        display_push_created(result)
      end
    end

    desc "url URL", "Create a URL push"
    option :days, type: :numeric, aliases: "-d", desc: "Expire after N days"
    option :views, type: :numeric, aliases: "-v", desc: "Expire after N views"
    option :name, type: :string, aliases: "-n", desc: "Name for the push"
    def url(url_value)
      with_client do |client|
        result = client.create_push(url_value,
          kind: "url",
          expire_after_days: options[:days],
          expire_after_views: options[:views],
          name: options[:name])
        display_push_created(result)
      end
    end

    desc "list", "List your pushes"
    option :expired, type: :boolean, default: false, desc: "Show expired pushes"
    option :page, type: :numeric, default: 1, aliases: "-p", desc: "Page number"
    def list
      with_client do |client|
        pushes = if options[:expired]
          client.expired_pushes(page: options[:page])
        else
          client.active_pushes(page: options[:page])
        end

        if pushes.empty?
          say "No #{options[:expired] ? "expired" : "active"} pushes found."
          return
        end

        table = TTY::Table.new(
          header: ["URL Token", "Days Left", "Views Left", "Created"],
          rows: pushes.map { |p|
            [
              p["url_token"],
              p["days_remaining"] || "-",
              p["views_remaining"] || "-",
              p["created_at"]&.split("T")&.first || "-"
            ]
          }
        )

        puts table.render(:unicode, padding: [0, 1])
      end
    end

    desc "expire URL_TOKEN", "Expire a push"
    def expire(url_token)
      with_client do |client|
        result = client.expire_push(url_token)
        say "Push expired successfully."
        say "  URL Token: #{result["url_token"]}" if result["url_token"]
      end
    end

    desc "get URL_TOKEN", "Retrieve a push"
    option :passphrase, type: :string, aliases: "-p", desc: "Passphrase if required"
    def get(url_token)
      with_client do |client|
        result = client.get_push(url_token, passphrase: options[:passphrase])

        if result["expired"]
          say "This push has expired."
        elsif result["payload"]
          say result["payload"]
        else
          say "Push retrieved (no payload visible — may require passphrase or be owner-only)."
        end
      end
    end

    desc "version", "Show CLI and server version"
    def version
      say "pwpush-cli #{Pwpush::VERSION}"

      config = Config.new
      if config.valid?
        begin
          client = Client.new(config)
          result = client.version
          say "Server: #{result["version"] || "unknown"}" if result
        rescue Client::ApiError => e
          say "Server version unavailable: #{e.message}"
        end
      else
        say "Server: not configured (run `pwpush config` to set up)"
      end
    end

    desc "config", "Configure server connection"
    def config
      say "PasswordPusher CLI Configuration"
      say "=" * 40

      cfg = Config.new

      print "Server URL [#{cfg.server_url || "https://pwpush.com"}]: "
      input = $stdin.gets.chomp
      cfg.server_url = input.empty? ? (cfg.server_url || "https://pwpush.com") : input

      print "API Token [#{cfg.api_token ? "****#{cfg.api_token[-4..]}" : "none"}]: "
      input = $stdin.gets.chomp
      cfg.api_token = input unless input.empty?

      print "Email (optional, for legacy auth) [#{cfg.email || "none"}]: "
      input = $stdin.gets.chomp
      cfg.email = input.empty? ? cfg.email : input

      cfg.save!
      say "\nConfiguration saved to #{Config::CONFIG_FILE}"
    end

    private

    def with_client
      config = Config.new
      unless config.valid?
        say_error "Not configured. Run `pwpush config` or set PWPUSH_SERVER_URL and PWPUSH_API_TOKEN environment variables."
        return
      end

      client = Client.new(config)
      yield client
    rescue Client::ApiError => e
      say_error e.message
    rescue Faraday::ConnectionFailed => e
      say_error "Connection failed: #{e.message}"
    end

    def display_push_created(result)
      token = result["url_token"]
      config = Config.new
      base = config.server_url.chomp("/")

      say "Push created successfully!"
      say "  URL Token: #{token}"
      say "  Secret URL: #{base}/p/#{token}"
      say "  Days Remaining: #{result["days_remaining"]}" if result["days_remaining"]
      say "  Views Remaining: #{result["views_remaining"]}" if result["views_remaining"]
    end

    def say_error(message)
      warn "Error: #{message}"
    end
  end
end
