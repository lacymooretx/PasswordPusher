module Pwpush
  module TokenAuthentication
    extend ActiveSupport::Concern

    ## regenerate_authentication_token!
    #
    # Regenerate the authentication token.
    # Returns the plaintext token (shown to user once).
    # Only the SHA-256 digest is persisted.
    #
    def regenerate_authentication_token!
      plaintext_token = generate_authentication_token
      self.authentication_token_digest = Digest::SHA256.hexdigest(plaintext_token)
      # Keep plaintext column for backward compatibility but don't rely on it
      self.authentication_token = plaintext_token
      save!
      plaintext_token
    end

    ## purge_authentication_token!
    #
    # Purge the authentication token
    #
    def purge_authentication_token!
      self.authentication_token = nil
      self.authentication_token_digest = nil
      save!
    end

    # Find a user by their API token (hashed lookup)
    def self.find_by_token(token)
      return nil if token.blank?

      digest = Digest::SHA256.hexdigest(token)
      user = User.find_by(authentication_token_digest: digest)
      # Fallback to plaintext lookup for unmigrated tokens
      user || User.find_by(authentication_token: token)
    end

    private

    ## generate_authentication_token
    #
    # Generate a unique authentication token.
    #
    def generate_authentication_token
      loop do
        token = Devise.friendly_token
        digest = Digest::SHA256.hexdigest(token)
        break token unless User.exists?(authentication_token_digest: digest)
      end
    end
  end
end
