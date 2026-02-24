# frozen_string_literal: true

# Public-facing intake form — no authentication required. Third parties visit
# /req/:url_token to submit secrets. The submitted content becomes a Push
# owned by the Request creator. Uses the "naked" layout (minimal chrome).
# Notifies the request owner via RequestMailer on each submission.
class RequestSubmissionsController < ApplicationController
  layout "naked"

  before_action :check_feature_enabled
  before_action :set_request
  before_action :check_request_active

  # GET /req/:url_token - Public intake form
  def show
  end

  # POST /req/:url_token - Submit content
  def create
    kind = determine_kind
    push = build_push(kind)

    if push.save
      @request.record_submission!
      RequestMailer.submission_received(@request, push).deliver_later if defined?(RequestMailer)
      render :thank_you
    else
      flash.now[:alert] = push.errors.full_messages.join(", ")
      render :show, status: :unprocessable_content
    end
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_requests) && Settings.enable_requests
      redirect_to root_path
    end
  end

  def set_request
    @request = Request.find_by!(url_token: params[:id])
  end

  def check_request_active
    @request.check_limits!
    unless @request.active?
      render :expired
    end
  end

  def determine_kind
    if params[:files].present? && @request.allow_files?
      "file"
    elsif params[:url].present? && @request.allow_url?
      "url"
    else
      "text"
    end
  end

  # Builds a Push from form params, assigns it to the request owner, and
  # applies the request's push expiration overrides if configured.
  def build_push(kind)
    push = Push.new(
      kind: kind,
      user: @request.user,
      request: @request
    )

    case kind
    when "text"
      push.payload = params[:payload]
    when "url"
      push.payload = params[:url]
    when "file"
      push.payload = params[:payload] if params[:payload].present?
      push.files.attach(params[:files]) if params[:files].present?
    end

    push.note = params[:note] if params[:note].present?

    # Apply request's push expiration defaults
    push.expire_after_days = @request.push_expire_after_days if @request.push_expire_after_days
    push.expire_after_views = @request.push_expire_after_views if @request.push_expire_after_views

    push
  end
end
