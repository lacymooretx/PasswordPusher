# frozen_string_literal: true

require "maxminddb"

# GeoIP country lookup using MaxMind GeoLite2 database.
# Returns ISO 3166-1 alpha-2 country codes (US, GB, DE, etc.).
# Gracefully returns nil on any error (missing DB, invalid IP, etc.).
class GeoipLookup
  class << self
    def country_code(ip)
      return nil unless database_available?

      result = database.lookup(ip)
      return nil unless result&.found?

      result.country&.iso_code
    rescue => e
      Rails.logger.warn("GeoIP lookup failed for #{ip}: #{e.message}")
      nil
    end

    def database_available?
      database_path.present? && File.exist?(database_path)
    end

    private

    def database_path
      @database_path ||= if Settings.respond_to?(:geofencing) && Settings.geofencing.respond_to?(:database_path)
        Settings.geofencing.database_path
      else
        ""
      end
    end

    def database
      @database ||= MaxMindDB.new(database_path)
    end
  end
end
