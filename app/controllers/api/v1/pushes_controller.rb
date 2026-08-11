# frozen_string_literal: true

class Api::V1::PushesController < Api::BaseController
  include SetPushAttributes
  include LogEvents
  include AccessRestriction

  before_action :set_push, only: %i[show preview audit destroy dispatch_push dispatches]
  before_action :check_access_restrictions, only: %i[show]

  resource_description do
    name "Pushes"
    short "Interact directly with pushes."
  end

  api :GET, "/p/:url_token.json", "Retrieve a push."
  param :url_token, String, desc: "Secret URL token of a previously created push.", required: true
  formats ["JSON"]
  description <<-EOS
    == Retrieving a Push

    Retrieves a push and its payload. If the push is active, this request will count as a view and be logged in the audit log.

    === Security Features

    * Passphrase protection - Requires a passphrase to view.

      Provide the passphrase as a GET parameter: ?passphrase=xxx

    == Language Specific Examples

    For language-specific examples and detailed API documentation, see:
    https://docs.pwpush.com/docs/json-api/
  EOS
  def show
    # This push may have expired since the last view.  Validate the url
    # expiration before doing anything.
    @push.check_limits

    if @push.expired
      log_view(@push)
      render template: "pushes/show", status: :ok
      return
    end

    # Passphrase handling
    if @push.passphrase.present?
      # JSON requests must pass the passphrase in the params
      has_passphrase = ActiveSupport::SecurityUtils.secure_compare(@push.passphrase.to_s, params[:passphrase].to_s)

      unless has_passphrase
        log_failed_passphrase(@push)

        # Passphrase hasn't been provided or is incorrect
        render json: {
          error: "That passphrase is incorrect.",
          message: "This push requires a passphrase. Please provide it using the 'passphrase' parameter (e.g. ?passphrase=mysecret)",
          status: :unauthorized
        }, status: :unauthorized
        return
      end
    end

    log_view(@push)
    expires_now

    render template: "pushes/show", status: :ok

    # If files are attached, we can't expire immediately as the viewer still needs
    # to download the files.  In the case of files, this push will be expired on the
    # next ExpirePushesJob run or next view attempt.  Whichever comes first.
    if !@push.files.attached? && !@push.views_remaining.positive?
      # Expire if this is the last view for this push
      @push.expire!
    end
  end

  api :POST, "/p.json", "Create a new push."
  param :password, Hash, "Push details", required: true do
    param :payload, String, desc: "The URL encoded password or secret text to share.", required: true
    param :files, Array, desc: "File(s) to upload and attach to the push."
    param :passphrase, String, desc: "Require recipients to enter this passphrase to view the created push."
    param :name, String, desc: "A name shown in the dashboard, notifications and emails.", allow_blank: true
    param :note, String, desc: "If authenticated, the URL encoded note for this push.  Visible only to the push creator.", allow_blank: true
    param :expire_after_days, Integer, desc: "Expire secret link and delete after this many days."
    param :expire_after_views, Integer, desc: "Expire secret link and delete after this many views."
    param :deletable_by_viewer, %w[true false], desc: "Allow users to delete passwords once retrieved."
    param :retrieval_step, %w[true false], desc: "Helps to avoid chat systems and URL scanners from eating up views."
    param :kind, %w[text file url qr], desc: "The kind of push to create. Defaults to 'text'.", required: false
  end
  formats ["JSON"]
  description <<-EOS
    == Creating a New Push

    Creates a new push (secret URL) containing the provided payload. The payload can be:

    * Text/password (default)
    * File attachments (requires authentication & subscription)
    * URLs
    * QR codes

    === Required Parameters

    The push must be created with a payload parameter containing the secret content.
    All other parameters are optional and will use system defaults if not specified.

    === Expiration Settings

    Pushes can be configured to expire after:

    * A number of views (expire_after_views)
    * A number of days (expire_after_days)
    * Both views and days (first trigger wins)

    === Security Options

    * Passphrase protection requires viewers to enter a secret phrase
    * Retrieval step helps prevent automated URL scanners from burning views
    * Deletable by viewer allows recipients to manually expire the push

    == Language Specific Examples

    See language specific examples in the docs: https://docs.pwpush.com/docs/json-api/

    == Example Request

      curl -X POST \\
        -H "X-User-Email: user@example.com" \\
        -H "X-User-Token: MyAPIToken" \\
        -H "Content-Type: application/json" \\
        -d '{"password": {"payload": "secret_text"}}' \\
        https://pwpush.com/p.json

    == Example Response

      {
        "url_token": "fkwjfvhall92",
        "html_url": "https://pwpush.com/p/fkwjfvhall92",
        "json_url": "https://pwpush.com/p/fkwjfvhall92.json",
        "created_at": "2023-10-20T15:32:01Z",
        "expires_at": "2023-10-20T15:32:01Z",
        "views_remaining": 10,
        "views_total": 10,
        "files": [],
        "passphrase": null,
        "name": null,
        "note": null,
        "expire_after_days": null,
      }
  EOS
  def create
    permitted_params = push_params

    # Require authentication when anonymous creation is disabled, or when
    # creating a file push / uploading attachments. This prevents
    # unauthenticated file storage abuse even when anonymous text pushes
    # are allowed (allow_anonymous: true). See GH #4381.
    authenticate_user! if requires_authentication_for_create?(permitted_params)

    @push = Push.new(permitted_params)

    if !permitted_params[:kind].present?
      # These are used to determine the default kind based on the request path
      # for old push records. Their paths are generated based on their kind.
      # And, QR code pushes are created by using `/p/` path.
      # So, it is not necessary to check for a special path.
      @push.kind = if request.path.include?("/f.json")
        "file"
      elsif request.path.include?("/r.json")
        "url"
      elsif request.path.include?("/p.json") && permitted_params.key?(:files)
        "file"
      else
        "text"
      end
    end

    @push.user = current_user if user_signed_in?

    assign_deletable_by_viewer(@push, permitted_params)
    assign_retrieval_step(@push, permitted_params)

    if @push.save
      log_creation(@push)

      # Optional inline dispatch: email/SMS the secret link on creation so a
      # caller does not have to follow up with a second request.
      @dispatch_result = dispatch_from_params(@push)

      render template: "pushes/show", status: :created
    else
      render json: @push.errors, status: :unprocessable_content
    end
  end

  api :POST, "/p/bulk.json", "Create multiple pushes in a single request."
  param :pushes, Array, desc: "Array of push objects (max 50).", required: true
  formats ["JSON"]
  description "Creates up to 50 pushes in a single API call. Each push object uses the same parameters as the single create endpoint. Returns an array of results."
  error code: 401, desc: "Unauthorized."
  error code: 422, desc: "Validation failed."
  def bulk_create
    authenticate_user!

    items = params[:pushes]
    unless items.is_a?(Array) && items.size.between?(1, 50)
      render json: {error: "Must provide 1-50 pushes"}, status: :unprocessable_content
      return
    end

    results = items.map do |push_data|
      push = Push.new(push_data.permit(:kind, :name, :payload, :expire_after_days, :expire_after_views,
        :retrieval_step, :deletable_by_viewer, :passphrase, :note, :custom_url_token))
      push.kind ||= "text"
      push.user = current_user

      assign_deletable_by_viewer(push, push_data)
      assign_retrieval_step(push, push_data)

      if push.save
        log_creation(push)
        {
          url_token: push.url_token,
          custom_url_token: push.custom_url_token,
          html_url: helpers.secret_url(push),
          kind: push.kind,
          expire_after_days: push.expire_after_days,
          expire_after_views: push.expire_after_views,
          created_at: push.created_at.iso8601
        }
      else
        {error: push.errors.full_messages}
      end
    end

    render json: {results: results}, status: :created
  end

  api :GET, "/p/:url_token/preview.json", "Helper endpoint to retrieve the fully qualified secret URL of a push."
  param :url_token, String, desc: "Secret URL token of a previously created push.", required: true
  formats ["JSON"]
  description <<-EOS
    == Preview a Push

    This method retrieves the preview URL of a push.  This is useful for getting the
    fully qualified URL of a push before sharing it with others.

    == Language Specific Examples

    For language-specific examples and detailed API documentation, see:
    https://docs.pwpush.com/docs/json-api/
  EOS
  def preview
    @secret_url = helpers.secret_url(@push)
    render json: {url: @secret_url}, status: :ok
  end

  api :GET, "/p/:url_token/audit.json", "Retrieve the audit log for a push."
  param :url_token, String, desc: "Secret URL token of a previously created push.", required: true
  formats ["JSON"]
  description <<-EOS
    == Push Audit Log Retrieval

    Returns the audit log for a push, containing an array of view events with metadata including:
    - IP address of viewer
    - User agent
    - Referrer URL
    - Timestamp
    - Event type (view, failed_view, expire, etc)

    Results are paginated with a maximum of 50 audit log entries per page and 200 pages total.

    Authentication is required. Only the owner of the push can retrieve its audit log.
    Requests for pushes not owned by the authenticated user will receive a 403 Forbidden response.

    == Parameters

    * +page+ - Page number (default: 1)

    == Example Request

      curl -X GET \\
        -H "X-User-Email: user@example.com" \\
        -H "X-User-Token: MyAPIToken" \\
        https://pwpush.com/p/fk27vnslkd/audit.json?page=1

    == Example Response

      {
        "views": [
          {
            "ip": "x.x.x.x",
            "user_agent": "Mozilla/5.0...",
            "referrer": "https://example.com",
            "created_at": "2023-10-20T15:32:01Z",
            "kind": "view"
          }
        ]
      }

    == Language Specific Examples

    For language-specific examples and detailed API documentation, see:
    https://docs.pwpush.com/docs/json-api/
  EOS
  def audit
    if @push.user != current_user
      render json: {error: I18n._("That push doesn't belong to you.")}, status: :forbidden
      return
    end

    page = validate_page_parameter
    return if page.nil?

    @audit_logs = @push.audit_logs
      .order(created_at: :desc)
      .page(page)
      .per(Settings.api.per_page)

    @secret_url = helpers.secret_url(@push)
    render json: {views: @audit_logs}.to_json(except: %i[user_id push_id id])
  end

  api :DELETE, "/p/:url_token.json", "Expire a push: delete the payload and expire the secret URL."
  param :url_token, String, desc: "Secret URL token of a previously created push.", required: true
  formats ["JSON"]
  description <<-EOS
    == Push Expiration

    Expires a push immediately.  Must be authenticated & owner of the push _or_ the push must
    have been created with _deleteable_by_viewer_.

    == Example Request

      curl -X DELETE \\
        -H "X-User-Email: user@example.com" \\
        -H "X-User-Token: MyAPIToken" \\
        https://pwpush.com/p/fkwjfvhall92.json

    == Example Response

      {
        "expired": true,
        "expired_on": "2023-10-20T15:32:01Z"
      }

    == Language Specific Examples

    For language-specific examples and detailed API documentation, see:
    https://docs.pwpush.com/docs/json-api/
  EOS
  def destroy
    if (@push.user == current_user) || @push.deletable_by_viewer
      unless @push.expired?
        # Deletable by the owner or viewer
        @push.expire!
        log_expire(@push)
      end

      render template: "pushes/show", status: :ok
    else
      notice = I18n._("That push is not deletable by viewers.")
      render json: {error: notice}, status: :unauthorized
    end
  end

  api :POST, "/p/:url_token/dispatch.json", "Send a push's secret link by email and/or SMS."
  param :url_token, String, desc: "Secret URL token of a previously created push.", required: true
  param :dispatch, Hash, desc: "Delivery targets.", required: true do
    param :emails, Array, desc: "Recipient email address(es). Also accepts a comma-separated string."
    param :phones, Array, desc: "Recipient mobile number(s) for SMS. E.164 preferred; US numbers may omit the country code."
    param :supervisor_email, String, desc: "Optional supervisor / manager email address."
    param :supervisor_phone, String, desc: "Optional supervisor / manager mobile number for SMS."
  end
  formats ["JSON"]
  description <<-EOS
    == Dispatching a Secret Link

    Queues delivery of this push's secret URL to one or more recipients over
    email (SMTP2GO) and/or SMS (Clerk Chat).

    Requires authentication, and the push must belong to the authenticated user.

    === Supervisor

    +supervisor_email+ / +supervisor_phone+ receive the *same* secret link as the
    primary recipient, flagged in the message as a supervisor copy. Every person
    who opens the link consumes one view, so set +expire_after_views+ high enough
    to cover everybody you dispatch to.

    === Feature flags

    * +enable_auto_dispatch+ must be on for any dispatch.
    * +enable_sms_dispatch+ must also be on for +phones+ / +supervisor_phone+.

    Requests naming a disabled channel still succeed for the enabled channels;
    the refused ones are listed in +errors+.

    === Limits

    Capped by +auto_dispatch.max_recipients+ (email) and
    +auto_dispatch.max_sms_recipients+ (SMS). Addresses beyond the cap, and any
    that fail validation, are reported in +errors+ rather than silently dropped.

    == Example Request

      curl -X POST \\
        -H "X-User-Email: user@example.com" \\
        -H "X-User-Token: MyAPIToken" \\
        -H "Content-Type: application/json" \\
        -d '{"dispatch": {"emails": ["alice@example.com"], "phones": ["713-875-0817"], "supervisor_email": "boss@example.com"}}' \\
        https://pwpush.com/p/fkwjfvhall92/dispatch.json

    == Example Response

      {
        "url_token": "fkwjfvhall92",
        "queued": 3,
        "errors": [],
        "dispatches": [
          {"id": 1, "channel": "email", "role": "recipient",  "destination": "al***@example.com", "status": "pending"},
          {"id": 2, "channel": "sms",   "role": "recipient",  "destination": "********0817",      "status": "pending"},
          {"id": 3, "channel": "email", "role": "supervisor", "destination": "bo**@example.com",  "status": "pending"}
        ]
      }
  EOS
  error code: 401, desc: "Unauthorized."
  error code: 403, desc: "The push does not belong to the authenticated user."
  error code: 422, desc: "Nothing could be dispatched."
  def dispatch_push
    return unless authorize_push_owner!

    if @push.expired?
      render json: {error: I18n._("That push has already expired.")}, status: :unprocessable_content
      return
    end

    result = PushDispatcher.call(
      push: @push,
      secret_url: helpers.secret_url(@push),
      spec: dispatch_spec_params
    )

    status = result.any? ? :created : :unprocessable_content
    render json: dispatch_payload(result), status: status
  end

  api :GET, "/p/:url_token/dispatches.json", "List the delivery log for a push's secret link."
  param :url_token, String, desc: "Secret URL token of a previously created push.", required: true
  formats ["JSON"]
  description <<-EOS
    == Dispatch Delivery Log

    Returns every email/SMS delivery of this push's secret link, with the status
    of each: +pending+, +sent+ or +failed+.

    Destinations are masked (+al***@example.com+, +********0817+) -- the full
    address is encrypted at rest and is never returned by the API.

    Authentication is required and the push must belong to the authenticated user.

    == Example Response

      {
        "url_token": "fkwjfvhall92",
        "dispatches": [
          {
            "id": 1,
            "channel": "email",
            "role": "recipient",
            "destination": "al***@example.com",
            "status": "sent",
            "sent_at": "2026-08-11T18:04:11Z",
            "provider_message_id": "<abc@pwpush>",
            "error": null,
            "created_at": "2026-08-11T18:04:09Z"
          }
        ]
      }
  EOS
  error code: 401, desc: "Unauthorized."
  error code: 403, desc: "The push does not belong to the authenticated user."
  def dispatches
    return unless authorize_push_owner!

    render json: {
      url_token: @push.url_token,
      dispatches: @push.push_dispatches.map { |d| serialize_dispatch(d) }
    }, status: :ok
  end

  api :GET, "/p/active.json", "Retrieve your active pushes."
  formats ["JSON"]
  description <<-EOS
    == Active Pushes Retrieval

    Returns the list of pushes that are still active.
    Results are paginated with a maximum of 50 pushes per page and 200 pages total.

    == Parameters

    * +page+ - Page number (default: 1)

    == Example Request

      curl -X GET \\
        -H "X-User-Email: user@example.com" \\
        -H "X-User-Token: MyAPIToken" \\
        https://pwpush.com/p/active.json

    == Example Response

        [
          {
            "url_token": "fkwjfvhall92",
            "html_url": "https://pwpush.com/p/fkwjfvhall92",
            "json_url": "https://pwpush.com/p/fkwjfvhall92.json",
            "created_at": "2023-10-20T15:32:01Z",
            "expires_at": "2023-10-20T15:32:01Z",
            ...
          },
          ...
        ]

    == Language Specific Examples

    For language-specific examples and detailed API documentation, see:
    https://docs.pwpush.com/docs/json-api/
  EOS
  def active
    unless Settings.enable_logins
      render json: {error: I18n._("You must be logged in to view your active pushes.")}, status: :unauthorized
      return
    end

    page = validate_page_parameter
    return if page.nil?

    @pushes = Push.includes(:audit_logs)
      .where(user_id: current_user.id, expired: false)
      .page(page)
      .per(Settings.api.per_page)
      .order(created_at: :desc)

    render template: "pushes/index", status: :ok
  end

  api :GET, "/p/expired.json", "Retrieve your expired pushes."
  formats ["JSON"]
  description <<-EOS
    == Expired Pushes Retrieval

    Returns the list of pushes that have expired.
    Results are paginated with a maximum of 50 pushes per page and 200 pages total.

    == Parameters

    * +page+ - Page number (default: 1)

    == Example Request

      curl -X GET \\
        -H "X-User-Email: user@example.com" \\
        -H "X-User-Token: MyAPIToken" \\
        https://pwpush.com/p/expired.json

    == Example Response

      [
        {
          "url_token": "fkwjfvhall92",
          "html_url": "https://pwpush.com/p/fkwjfvhall92",
          "json_url": "https://pwpush.com/p/fkwjfvhall92.json",
          "created_at": "2023-10-20T15:32:01Z",
          "expires_at": "2023-10-20T15:32:01Z",
          ...
        },
        ...
      ]

    == Language Specific Examples

    For language-specific examples and detailed API documentation, see:
    https://docs.pwpush.com/docs/json-api/
  EOS
  def expired
    unless Settings.enable_logins
      render json: {error: I18n._("You must be logged in to view your expired pushes.")}, status: :unauthorized
      return
    end

    page = validate_page_parameter
    return if page.nil?

    @pushes = Push.includes(:audit_logs)
      .where(user_id: current_user.id, expired: true)
      .page(page)
      .per(Settings.api.per_page)
      .order(created_at: :desc)

    render template: "pushes/index", status: :ok
  end

  private

  # requires_authentication_for_create?
  #
  # Determines whether a push creation request must be authenticated.
  # Authentication is required when:
  #   - anonymous creation is disabled (allow_anonymous: false), or
  #   - the request creates a file push / uploads attachments (the /f
  #     endpoint, /p.json with a files key, or an explicit file kind).
  # File pushes are always gated so that enabling anonymous text pushes
  # does not also open unauthenticated file storage uploads. See GH #4381.
  #
  # @return [Boolean] true if authenticate_user! should be enforced
  def requires_authentication_for_create?(permitted_params)
    # No authentication system is available when logins are disabled.
    return false unless Settings.enable_logins
    return true unless Settings.allow_anonymous
    return true if request.path.start_with?("/f")

    (request.path.include?("/p.json") && permitted_params.key?(:files)) ||
      permitted_params[:kind] == "file"
  end

  # validate_page_parameter
  #
  # Validates and sanitizes the page parameter for pagination
  # Returns the validated page number or renders an error response
  #
  # @return [Integer, nil] validated page number or nil if error rendered
  def validate_page_parameter
    begin
      page = Integer(params[:page] || 1)
      page = [page, 1].max  # Ensure minimum of 1
    rescue ArgumentError, TypeError
      render json: {error: "Invalid page parameter"}, status: :bad_request
      return nil
    end

    if page > Settings.api.max_page
      render json: {error: "Invalid page parameter"}, status: :bad_request
      return nil
    end

    page
  end

  def check_access_restrictions
    return unless @push

    check_ip_restriction(@push)
    check_geo_restriction(@push)
  end

  # -- dispatch helpers ----------------------------------------------------

  # Only the push owner may make the server send its secret link somewhere.
  # Renders the error response and returns false when the check fails.
  def authorize_push_owner!
    if !user_signed_in?
      head :unauthorized
      return false
    end

    if @push.user_id != current_user.id
      render json: {error: I18n._("That push doesn't belong to you.")}, status: :forbidden
      return false
    end

    true
  end

  # Accepts the `dispatch` object on create and on the dispatch endpoint.
  # Arrays and comma-separated strings are both valid for emails/phones.
  def dispatch_spec_params
    raw = params[:dispatch]
    return {} if raw.blank?

    permitted = raw.permit(:supervisor_email, :supervisor_phone, :emails, :phones,
      emails: [], phones: [])

    {
      emails: permitted[:emails],
      phones: permitted[:phones],
      supervisor_email: permitted[:supervisor_email],
      supervisor_phone: permitted[:supervisor_phone]
    }
  end

  # Inline dispatch during #create. Silently a no-op for anonymous callers:
  # an unauthenticated request must not be able to make the server email or
  # text arbitrary addresses.
  def dispatch_from_params(push)
    return nil if params[:dispatch].blank?
    return nil unless user_signed_in?

    PushDispatcher.call(push: push, secret_url: helpers.secret_url(push), spec: dispatch_spec_params)
  end

  def dispatch_payload(result)
    {
      url_token: @push.url_token,
      queued: result.dispatches.size,
      errors: result.errors,
      dispatches: result.dispatches.map { |d| serialize_dispatch(d) }
    }
  end

  # Destinations are masked: the full address is recipient PII, encrypted at
  # rest, and the caller already knows what they asked us to send to.
  def serialize_dispatch(dispatch)
    {
      id: dispatch.id,
      channel: dispatch.channel,
      role: dispatch.role,
      destination: dispatch.masked_destination,
      status: dispatch.status,
      sent_at: dispatch.sent_at&.iso8601,
      provider_message_id: dispatch.provider_message_id,
      error: dispatch.error,
      created_at: dispatch.created_at.iso8601
    }
  end

  def set_push
    @push = Push.includes(:audit_logs).find_by_token!(params[:id])
  rescue ActiveRecord::RecordNotFound
    # Showing a 404 reveals that this Secret URL never existed
    # which is an information leak (not a secret anymore)
    # We also don't want data in general. We entirely delete old pushes that:
    # 1. have expired (payloads already deleted long ago)
    # 2. are anonymous/not linked to a user account (audit log not needed)
    # Old, expired & anonymous pushes have no value to anybody.
    # When not found, show the 'expired' page so even very old secret URLs
    # when clicked they will be accurate - this secret URL has expired.
    # No easy fix for JSON unfortunately as we don't have a record to show.
    respond_to do |format|
      format.json { render json: {error: "not-found"}.to_json, status: :not_found }
    end
  end

  def push_params
    if request.path.start_with?("/f")
      params.require(:file_push).permit(:name, :expire_after_days, :expire_after_views, :deletable_by_viewer,
        :retrieval_step, :payload, :note, :passphrase, :allowed_ips, :allowed_countries, :file_encryption_key, files: [])
    elsif request.path.start_with?("/r")
      params.require(:url).permit(:name, :expire_after_days, :expire_after_views,
        :retrieval_step, :payload, :note, :passphrase, :allowed_ips, :allowed_countries)
    else
      # https://docs.pwpush.com/docs/json-api/#curl
      # curl -X POST -H "X-User-Email: <email>" -H "X-User-Token: MyAPIToken"
      # -F "password[payload]=my_secure_payload"
      # -F "password[note]=For New Employee ID 12345"
      # -F "password[files][]=@/path/to/file/file1.extension"
      # -F "password[files][]=@/path/to/file/file2.extension"
      # https://pwpush.com/p.json
      # There is a differences between the premium and OSS features.
      # It is allowed to create password pushes by using files on the premium one.
      # To respond same request, password[files] are allowed, but it will create a file push.
      #
      # More, kind can be used to create different kind pushes.
      params.require(:password).permit(:name, :kind, :expire_after_days, :expire_after_views, :deletable_by_viewer,
        :retrieval_step, :payload, :note, :passphrase, :allowed_ips, :allowed_countries, :file_encryption_key, files: [])
    end
  rescue => e
    Rails.logger.error("Error in push_params: #{e.message}")

    raise e
  end
end
