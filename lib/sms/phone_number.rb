# frozen_string_literal: true

module Sms
  # E.164 normalisation for operator-typed mobile numbers.
  #
  # Clerk Chat requires strict E.164 (+15551234567). Humans type
  # "(713) 875-0817", "713-875-0817", "1 713 875 0817" and "+1 713 875 0817",
  # so normalise before hitting the API rather than bouncing the form.
  #
  # Numbers already carrying a "+" are trusted as international and only
  # stripped of separators -- we do not attempt per-country length rules.
  # Bare national numbers are interpreted against +default_country_code+.
  module PhoneNumber
    module_function

    # Returns the E.164 string, or nil when the input cannot be a phone number.
    def normalize(value, default_country_code: nil)
      raw = value.to_s.strip
      return nil if raw.blank?

      international = raw.start_with?("+")
      digits = raw.gsub(/\D/, "")
      return nil if digits.blank?

      if international
        # 7 digits is the shortest plausible subscriber number worldwide;
        # 15 is the E.164 maximum.
        return nil unless digits.length.between?(8, 15)
        return "+#{digits}"
      end

      cc = (default_country_code.presence || country_code_setting).to_s.gsub(/\D/, "")
      cc = "1" if cc.blank?

      case digits.length
      when 10
        # Bare national number, e.g. 7138750817 -> prepend the default country code.
        "+#{cc}#{digits}"
      when 11..15
        # Long enough to already carry a country code, e.g. 17138750817.
        "+#{digits}"
      end
    end

    def valid?(value, default_country_code: nil)
      normalize(value, default_country_code: default_country_code).present?
    end

    # Splits an operator-entered list ("+1555..., 713-875-0817") into
    # normalised numbers, dropping anything unparseable. Order is preserved and
    # duplicates removed so a number typed twice is only texted once.
    def normalize_list(value, default_country_code: nil)
      tokens = value.is_a?(Array) ? value : value.to_s.split(/[,;\s]+/)
      tokens.filter_map { |t| normalize(t, default_country_code: default_country_code) }.uniq
    end

    def country_code_setting
      return nil unless defined?(Settings) && Settings.respond_to?(:clerk_chat) && Settings.clerk_chat
      Settings.clerk_chat.respond_to?(:default_country_code) ? Settings.clerk_chat.default_country_code : nil
    end
  end
end
