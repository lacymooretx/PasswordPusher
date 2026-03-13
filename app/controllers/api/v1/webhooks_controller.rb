# frozen_string_literal: true

# JSON API for managing webhooks. Token-authenticated via Api::BaseController.
# Requires Settings.enable_webhooks. Users can list, view, create, update,
# and destroy their own webhooks.
class Api::V1::WebhooksController < Api::BaseController
  before_action :check_feature_enabled
  before_action :set_webhook, only: [:show, :update, :destroy]

  resource_description do
    name "Webhooks"
    short "Manage webhook endpoints for push event notifications."
  end

  api :GET, "/api/v1/webhooks.json", "List your webhooks."
  formats ["JSON"]
  description <<-EOS
    Returns all webhooks belonging to the authenticated user, ordered by
    creation date descending. Requires authentication via API token.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Webhooks feature is not enabled."
  def index
    @webhooks = current_user.webhooks.order(created_at: :desc)
    render json: @webhooks.map { |w| webhook_json(w) }
  end

  api :GET, "/api/v1/webhooks/:id.json", "Get webhook details with recent deliveries."
  param :id, :number, desc: "The webhook ID.", required: true
  formats ["JSON"]
  description <<-EOS
    Retrieves a specific webhook with its 20 most recent delivery attempts.
    The authenticated user must own the webhook.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Webhook not found or webhooks feature is not enabled."
  def show
    deliveries = @webhook.webhook_deliveries.recent.limit(20)
    render json: webhook_json(@webhook, deliveries: deliveries)
  end

  api :POST, "/api/v1/webhooks.json", "Create a webhook."
  param :webhook, Hash, desc: "Webhook attributes.", required: true do
    param :url, String, desc: "The HTTP(S) URL to receive POST notifications.", required: true
    param :enabled, [true, false], desc: "Whether the webhook is active. Defaults to true."
    param :events, Array, of: String, desc: "Array of event types to subscribe to (e.g. push.created, push.viewed).", required: true
  end
  formats ["JSON"]
  description <<-EOS
    Creates a new webhook for the authenticated user. A signing secret is
    auto-generated. The number of webhooks per user is limited.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Webhooks feature is not enabled."
  error code: 422, desc: "Validation failed or max webhook limit reached."
  def create
    @webhook = current_user.webhooks.build(webhook_params)

    max_webhooks = if Settings.respond_to?(:webhooks) && Settings.webhooks.respond_to?(:max_per_user)
      Settings.webhooks.max_per_user
    else
      10
    end

    if current_user.webhooks.count >= max_webhooks
      render json: {error: "You have reached the maximum number of webhooks (#{max_webhooks})."}, status: :unprocessable_content
      return
    end

    if @webhook.save
      render json: webhook_json(@webhook), status: :created
    else
      render json: {errors: @webhook.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :PUT, "/api/v1/webhooks/:id.json", "Update a webhook."
  param :id, :number, desc: "The webhook ID.", required: true
  param :webhook, Hash, desc: "Webhook attributes to update.", required: true do
    param :url, String, desc: "The HTTP(S) URL to receive POST notifications."
    param :enabled, [true, false], desc: "Whether the webhook is active."
    param :events, Array, of: String, desc: "Array of event types to subscribe to."
  end
  formats ["JSON"]
  description <<-EOS
    Updates an existing webhook. Only the webhook owner can perform this action.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Webhook not found or webhooks feature is not enabled."
  error code: 422, desc: "Validation failed."
  def update
    if @webhook.update(webhook_params)
      render json: webhook_json(@webhook)
    else
      render json: {errors: @webhook.errors.full_messages}, status: :unprocessable_content
    end
  end

  api :DELETE, "/api/v1/webhooks/:id.json", "Delete a webhook."
  param :id, :number, desc: "The webhook ID.", required: true
  formats ["JSON"]
  description <<-EOS
    Permanently deletes a webhook and all its delivery history.
    Only the webhook owner can perform this action.
  EOS
  error code: 401, desc: "Unauthorized - invalid or missing API token."
  error code: 404, desc: "Webhook not found or webhooks feature is not enabled."
  def destroy
    @webhook.destroy
    head :no_content
  end

  api :POST, "/api/v1/webhooks/:id/deliveries/:delivery_id/read.json", "Mark a webhook delivery as read."
  param :id, :number, desc: "Webhook ID.", required: true
  param :delivery_id, :number, desc: "Delivery ID.", required: true
  formats ["JSON"]
  error code: 401, desc: "Unauthorized."
  error code: 404, desc: "Not found."
  def mark_delivery_read
    webhook = current_user.webhooks.find(params[:id])
    delivery = webhook.deliveries.find(params[:delivery_id])
    delivery.mark_read!
    render json: {id: delivery.id, read_at: delivery.read_at.iso8601}
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Not found"}, status: :not_found
  end

  private

  def check_feature_enabled
    unless Settings.respond_to?(:enable_webhooks) && Settings.enable_webhooks
      render json: {error: "Webhooks feature is not enabled"}, status: :not_found
    end
  end

  def set_webhook
    @webhook = current_user.webhooks.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {error: "Webhook not found"}, status: :not_found
  end

  def webhook_params
    params.require(:webhook).permit(:url, :enabled, events: [])
  end

  def webhook_json(webhook, deliveries: nil)
    json = {
      id: webhook.id,
      url: webhook.url,
      enabled: webhook.enabled,
      events: webhook.events,
      failure_count: webhook.failure_count,
      last_success_at: webhook.last_success_at&.iso8601,
      last_failure_at: webhook.last_failure_at&.iso8601,
      last_failure_reason: webhook.last_failure_reason,
      created_at: webhook.created_at.iso8601,
      updated_at: webhook.updated_at.iso8601
    }

    if deliveries
      json[:deliveries] = deliveries.map do |d|
        {
          id: d.id,
          event: d.event,
          response_code: d.response_code,
          success: d.success,
          attempt: d.attempt,
          created_at: d.created_at.iso8601
        }
      end
    end

    json
  end
end
