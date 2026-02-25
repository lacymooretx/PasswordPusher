class BaseController < ApplicationController
  include TeamTwoFactorEnforcement

  rescue_from ActionController::ParameterMissing do |exception|
    respond_to do |format|
      format.html { render plain: _("Missing Parameters"), status: :bad_request }
      format.any { head :bad_request }
    end
  end

  rescue_from ActionController::UnknownFormat do |exception|
    respond_to do |format|
      format.html { render plain: _("Unsupported format"), status: :unsupported_media_type }
      format.any { head :unsupported_media_type }
    end
  end

  rescue_from ActionController::BadRequest do |exception|
    Rails.logger.error "Invalid request parameters: #{exception.message}"
    respond_to do |format|
      format.html { render plain: _("Invalid request parameters"), status: :bad_request }
      format.json { render json: {error: _("Invalid request parameters")}, status: :bad_request }
      format.any { head :bad_request }
    end
  end
end
