# frozen_string_literal: true

class Api::V1::RequestsController < Api::BaseController
  before_action :check_feature_enabled
  before_action :set_request, only: [:show, :update, :destroy]

  resource_description do
    name "Requests"
    short "Manage intake request forms."
  end

  api :GET, "/api/v1/requests.json", "List your requests."
  formats ["JSON"]
  description <<-EOS
    Returns all intake request forms owned by the authenticated user,
    ordered by most recently created.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Requests feature is not enabled."
  def index
    @requests = current_user.requests.order(created_at: :desc)
    render json: @requests.map { |r| request_json(r) }
  end

  api :GET, "/api/v1/requests/:url_token.json", "Get request details."
  param :url_token, String, desc: "The unique URL token of the request.", required: true
  formats ["JSON"]
  description <<-EOS
    Retrieves detailed information about a specific intake request, including
    configuration and submission counts.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Request not found or requests feature is not enabled."
  def show
    render json: request_json(@request, detail: true)
  end

  api :POST, "/api/v1/requests.json", "Create a request."
  param :request, Hash, desc: "Request attributes.", required: true do
    param :name, String, desc: "A descriptive name for the request form.", required: true
    param :description, String, desc: "Instructions displayed to submitters."
    param :allow_text, [true, false], desc: "Allow text/password submissions."
    param :allow_files, [true, false], desc: "Allow file uploads."
    param :allow_url, [true, false], desc: "Allow URL submissions."
    param :max_submissions, Integer, desc: "Maximum number of submissions before auto-expiry."
    param :expire_after_days, Integer, desc: "Expire the request form after this many days."
    param :push_expire_after_days, Integer, desc: "Default expiration days for submitted pushes."
    param :push_expire_after_views, Integer, desc: "Default expiration views for submitted pushes."
  end
  formats ["JSON"]
  description <<-EOS
    Creates a new intake request form. Submitters can use the form's URL
    to securely send passwords, files, or URLs to the form owner.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Requests feature is not enabled."
  error code: 422, desc: "Validation failed."
  def create
    @request = current_user.requests.build(request_params)

    if @request.save
      render json: request_json(@request), status: :created
    else
      render json: {errors: @request.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :PUT, "/api/v1/requests/:url_token.json", "Update a request."
  param :url_token, String, desc: "The unique URL token of the request.", required: true
  param :request, Hash, desc: "Request attributes to update.", required: true do
    param :name, String, desc: "A descriptive name for the request form."
    param :description, String, desc: "Instructions displayed to submitters."
    param :allow_text, [true, false], desc: "Allow text/password submissions."
    param :allow_files, [true, false], desc: "Allow file uploads."
    param :allow_url, [true, false], desc: "Allow URL submissions."
    param :max_submissions, Integer, desc: "Maximum number of submissions before auto-expiry."
    param :expire_after_days, Integer, desc: "Expire the request form after this many days."
    param :push_expire_after_days, Integer, desc: "Default expiration days for submitted pushes."
    param :push_expire_after_views, Integer, desc: "Default expiration views for submitted pushes."
  end
  formats ["JSON"]
  description <<-EOS
    Updates an existing intake request form. Only the request owner can
    update it.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Request not found or requests feature is not enabled."
  error code: 422, desc: "Validation failed."
  def update
    if @request.update(request_params)
      render json: request_json(@request)
    else
      render json: {errors: @request.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :DELETE, "/api/v1/requests/:url_token.json", "Expire a request."
  param :url_token, String, desc: "The unique URL token of the request.", required: true
  formats ["JSON"]
  description <<-EOS
    Expires an intake request form. The form will no longer accept new
    submissions. Previously submitted pushes are not affected.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Request not found or requests feature is not enabled."
  def destroy
    @request.update!(expired: true)
    render json: request_json(@request)
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_requests) && Settings.enable_requests
      render json: {error: "Requests feature is not enabled"}, status: :not_found
    end
  end

  def set_request
    @request = current_user.requests.find_by!(url_token: params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Request not found"}, status: :not_found
  end

  def request_params
    params.require(:request).permit(
      :name, :description, :allow_text, :allow_files, :allow_url,
      :max_submissions, :expire_after_days,
      :push_expire_after_days, :push_expire_after_views
    )
  end

  def request_json(req, detail: false)
    json = {
      url_token: req.url_token,
      name: req.name,
      active: req.active?,
      expired: req.expired?,
      submission_count: req.submission_count,
      created_at: req.created_at.iso8601
    }
    if detail
      json.merge!(
        description: req.description,
        allow_text: req.allow_text,
        allow_files: req.allow_files,
        allow_url: req.allow_url,
        max_submissions: req.max_submissions,
        expire_after_days: req.expire_after_days,
        expires_at: req.expires_at&.iso8601,
        push_expire_after_days: req.push_expire_after_days,
        push_expire_after_views: req.push_expire_after_views
      )
    end
    json
  end
end
