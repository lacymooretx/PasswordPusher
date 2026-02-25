# frozen_string_literal: true

module AccessRestriction
  extend ActiveSupport::Concern

  private

  def check_ip_restriction(push)
    return unless Settings.respond_to?(:enable_ip_allowlisting) && Settings.enable_ip_allowlisting
    return if push.allowed_ips.blank?

    unless push.ip_allowed?(request.remote_ip)
      respond_to do |format|
        format.html { render template: "pushes/show_expired", layout: "application", status: :forbidden }
        format.json { render json: {error: "Access denied"}, status: :forbidden }
      end
    end
  end

  def check_geo_restriction(push)
    return unless Settings.respond_to?(:enable_geofencing) && Settings.enable_geofencing
    return if push.allowed_countries.blank?

    unless push.country_allowed?(request.remote_ip)
      respond_to do |format|
        format.html { render template: "pushes/show_expired", layout: "application", status: :forbidden }
        format.json { render json: {error: "Access denied"}, status: :forbidden }
      end
    end
  end
end
