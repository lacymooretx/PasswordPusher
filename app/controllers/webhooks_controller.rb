# frozen_string_literal: true

class WebhooksController < BaseController
  before_action :authenticate_user!
  before_action :check_feature_enabled
  before_action :set_webhook, only: [:show, :edit, :update, :destroy]

  def index
    @webhooks = current_user.webhooks.order(created_at: :desc)
  end

  def show
    @deliveries = @webhook.webhook_deliveries.recent.page(params[:page]).per(20)
  end

  def new
    @webhook = current_user.webhooks.build(events: [])
  end

  def create
    @webhook = current_user.webhooks.build(webhook_params)

    max_webhooks = if Settings.respond_to?(:webhooks) && Settings.webhooks.respond_to?(:max_per_user)
      Settings.webhooks.max_per_user
    else
      10
    end

    if current_user.webhooks.count >= max_webhooks
      flash.now[:alert] = _("You have reached the maximum number of webhooks (%{max}).") % {max: max_webhooks}
      render :new, status: :unprocessable_content
      return
    end

    if @webhook.save
      redirect_to @webhook, notice: _("Webhook created successfully.")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @webhook.update(webhook_params)
      redirect_to @webhook, notice: _("Webhook updated successfully.")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @webhook.destroy
    redirect_to webhooks_path, notice: _("Webhook deleted successfully.")
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_webhooks) && Settings.enable_webhooks
      redirect_to root_path
    end
  end

  def set_webhook
    @webhook = current_user.webhooks.find(params[:id])
  end

  def webhook_params
    params.require(:webhook).permit(:url, :enabled, events: [])
  end
end
