# frozen_string_literal: true

# Authenticated CRUD for intake request links. Users create requests that
# generate public URLs for third parties to submit secrets via
# RequestSubmissionsController. Destroy soft-expires the request rather
# than deleting it. Requires Settings.enable_requests.
class RequestsController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled
  before_action :set_request, only: %i[show edit update destroy]

  def index
    @requests = current_user.requests.order(created_at: :desc).page(params[:page])
  end

  def show
  end

  def new
    @request = current_user.requests.build
  end

  def create
    @request = current_user.requests.build(request_params)

    if @request.save
      redirect_to @request, notice: I18n._("Request link created successfully.")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @request.update(request_params)
      redirect_to @request, notice: I18n._("Request updated successfully.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @request.update!(expired: true)
    redirect_to requests_path, notice: I18n._("Request link deactivated.")
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_requests) && Settings.enable_requests
      redirect_to root_path, notice: I18n._("This feature is not enabled.")
    end
  end

  def set_request
    @request = current_user.requests.find_by!(url_token: params[:id])
  end

  def request_params
    params.require(:request).permit(
      :name, :description, :allow_text, :allow_files, :allow_url,
      :push_expire_after_days, :push_expire_after_views,
      :max_submissions, :expire_after_days
    )
  end
end
