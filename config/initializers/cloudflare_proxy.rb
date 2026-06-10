require "net/http"

if Settings.cloudflare_proxy
  def fetch_with_timeout(url, timeout: 15)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: timeout, read_timeout: timeout) do |http|
      request = Net::HTTP::Get.new(uri)
      http.request(request).body
    end
  rescue => e
    Rails.logger.warn "Failed to fetch #{url}: #{e.message}"
    ""
  end

  Rails.logger.info "Fetching latest Cloudflare IPs..."

  cf_ipv4_url = "https://www.cloudflare.com/ips-v4"
  cf_ipv6_url = "https://www.cloudflare.com/ips-v6"

  # Static fallback list of Cloudflare ranges (https://www.cloudflare.com/ips/).
  # Used when the live fetch fails or returns nothing, so client-IP resolution
  # (and IP allowlisting / geofencing, which depend on it) stays correct even
  # if Cloudflare is unreachable at boot.
  cloudflare_fallback_ips = %w[
    173.245.48.0/20 103.21.244.0/22 103.22.200.0/22 103.31.4.0/22
    141.101.64.0/18 108.162.192.0/18 190.93.240.0/20 188.114.96.0/20
    197.234.240.0/22 198.41.128.0/17 162.158.0.0/15 104.16.0.0/13
    104.24.0.0/14 172.64.0.0/13 131.0.72.0/22
    2400:cb00::/32 2606:4700::/32 2803:f800::/32 2405:b500::/32
    2405:8100::/32 2a06:98c0::/29 2c0f:f248::/32
  ]

  begin
    # Fetch Cloudflare IP ranges with timeout
    ipv4 = fetch_with_timeout(cf_ipv4_url).split("\n")
    ipv6 = fetch_with_timeout(cf_ipv6_url).split("\n")
    cloudflare_ips = (ipv4 + ipv6).map(&:strip).reject(&:blank?)
  rescue => e
    Rails.logger.warn "Failed to fetch Cloudflare IPs: #{e.message}"
    cloudflare_ips = []
  end

  if cloudflare_ips.empty?
    Rails.logger.warn "Using static Cloudflare IP fallback list."
    cloudflare_ips = cloudflare_fallback_ips
  end

  # Add Cloudflare IPs to existing trusted proxies
  Rails.application.config.action_dispatch.trusted_proxies ||= []
  Rails.application.config.action_dispatch.trusted_proxies += cloudflare_ips.filter_map do |ip|
    IPAddr.new(ip)
  rescue ArgumentError => e
    Rails.logger.warn "Invalid IP format skipped: #{ip} (#{e.message})"
    nil
  end

  Rails.logger.info "Cloudflare IPs added to trusted proxies."
end
