# frozen_string_literal: true

class Api::V1::PushTemplatesController < Api::BaseController
  before_action :check_feature_enabled
  before_action :set_push_template, only: [:show, :update, :destroy]

  resource_description do
    name "Push Templates"
    short "Manage reusable push setting presets."
  end

  api :GET, "/api/v1/push_templates.json", "List all push templates."
  formats ["JSON"]
  description "Returns all push templates available to the authenticated user, including team-shared templates."
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  def index
    templates = PushTemplate.available_to(current_user).order(created_at: :desc)
    render json: templates.map { |t| template_json(t) }
  end

  api :GET, "/api/v1/push_templates/:id.json", "Show a push template."
  param :id, :number, desc: "Template ID.", required: true
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 404, desc: "Template not found."
  def show
    render json: template_json(@push_template)
  end

  api :POST, "/api/v1/push_templates.json", "Create a push template."
  param :push_template, Hash, desc: "Template attributes.", required: true do
    param :name, String, desc: "Template name.", required: true
    param :kind, %w[text file url qr], desc: "Push kind.", required: true
    param :expire_after_days, :number, desc: "Days until expiration."
    param :expire_after_views, :number, desc: "Views until expiration."
    param :retrieval_step, :boolean, desc: "Enable 1-click retrieval step."
    param :deletable_by_viewer, :boolean, desc: "Allow viewer deletion."
    param :passphrase, String, desc: "Default passphrase."
    param :team_id, :number, desc: "Share with team (optional)."
  end
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 422, desc: "Validation failed."
  def create
    @push_template = current_user.push_templates.build(push_template_params)

    max = if Settings.respond_to?(:push_templates) && Settings.push_templates.respond_to?(:max_per_user)
      Settings.push_templates.max_per_user
    else
      25
    end

    if current_user.push_templates.count >= max
      render json: {error: "Maximum templates reached (#{max})"}, status: :unprocessable_content
      return
    end

    if @push_template.save
      render json: template_json(@push_template), status: :created
    else
      render json: {errors: @push_template.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :PATCH, "/api/v1/push_templates/:id.json", "Update a push template."
  param :id, :number, desc: "Template ID.", required: true
  param :push_template, Hash, desc: "Template attributes.", required: true do
    param :name, String, desc: "Template name."
    param :expire_after_days, :number, desc: "Days until expiration."
    param :expire_after_views, :number, desc: "Views until expiration."
    param :retrieval_step, :boolean, desc: "Enable 1-click retrieval step."
    param :deletable_by_viewer, :boolean, desc: "Allow viewer deletion."
    param :passphrase, String, desc: "Default passphrase."
    param :team_id, :number, desc: "Share with team (optional)."
  end
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 404, desc: "Template not found."
  error code: 422, desc: "Validation failed."
  def update
    if @push_template.update(push_template_params)
      render json: template_json(@push_template)
    else
      render json: {errors: @push_template.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :DELETE, "/api/v1/push_templates/:id.json", "Delete a push template."
  param :id, :number, desc: "Template ID.", required: true
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 404, desc: "Template not found."
  def destroy
    @push_template.destroy
    head :no_content
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_push_templates) && Settings.enable_push_templates
      render json: {error: "Push templates feature is not enabled"}, status: :not_found
    end
  end

  def set_push_template
    @push_template = current_user.push_templates.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Push template not found"}, status: :not_found
  end

  def push_template_params
    params.require(:push_template).permit(
      :name, :kind, :expire_after_days, :expire_after_views,
      :retrieval_step, :deletable_by_viewer, :passphrase, :team_id
    )
  end

  def template_json(template)
    {
      id: template.id,
      name: template.name,
      kind: template.kind,
      expire_after_days: template.expire_after_days,
      expire_after_views: template.expire_after_views,
      retrieval_step: template.retrieval_step,
      deletable_by_viewer: template.deletable_by_viewer,
      passphrase: template.passphrase,
      team_id: template.team_id,
      user_id: template.user_id,
      created_at: template.created_at.iso8601,
      updated_at: template.updated_at.iso8601
    }
  end
end
