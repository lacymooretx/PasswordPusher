# frozen_string_literal: true

class PushTemplatesController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled
  before_action :set_push_template, only: [:show, :edit, :update, :destroy]

  def index
    @push_templates = current_user.push_templates.order(created_at: :desc)
  end

  def show
  end

  def new
    @push_template = current_user.push_templates.build(kind: params[:kind] || "text")
  end

  def create
    @push_template = current_user.push_templates.build(push_template_params)

    max = if Settings.respond_to?(:push_templates) && Settings.push_templates.respond_to?(:max_per_user)
      Settings.push_templates.max_per_user
    else
      25
    end

    if current_user.push_templates.count >= max
      flash.now[:alert] = _("You have reached the maximum number of templates (%{max}).") % {max: max}
      render :new, status: :unprocessable_content
      return
    end

    if @push_template.save
      redirect_to push_templates_path, notice: _("Template created successfully.")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @push_template.update(push_template_params)
      redirect_to push_templates_path, notice: _("Template updated successfully.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @push_template.destroy
    redirect_to push_templates_path, notice: _("Template deleted successfully.")
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_push_templates) && Settings.enable_push_templates
      redirect_to root_path
    end
  end

  def set_push_template
    @push_template = current_user.push_templates.find(params[:id])
  end

  def push_template_params
    params.require(:push_template).permit(
      :name, :kind, :expire_after_days, :expire_after_views,
      :retrieval_step, :deletable_by_viewer, :passphrase, :team_id
    )
  end
end
