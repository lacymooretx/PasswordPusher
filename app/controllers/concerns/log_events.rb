module LogEvents
  ##
  # log_view
  #
  # Record that a view is being made for a push
  # If the viewer is the owner or an admin, it won't count towards view limits
  #
  def log_view(push)
    if push.expired
      log_event(push, :failed_view)
    elsif user_signed_in? && current_user.admin?
      # Admin views take precedence over owner views
      log_event(push, :admin_view)
    elsif user_signed_in? && push.user_id == current_user.id
      log_event(push, :owner_view)
    else
      audit_log = log_event(push, :view)
      if Settings.respond_to?(:enable_push_notifications) && Settings.enable_push_notifications
        PushNotificationJob.perform_later(push.id, "view", audit_log.id) if push.user&.notify_on_view?
      end
      Push.dispatch_webhook("push.viewed", push)
    end
    push
  end

  def log_creation(push)
    log_event(push, :creation)
    Push.dispatch_webhook("push.created", push)
  end

  def log_update(push)
    log_event(push, :edit)
  end

  def log_failed_passphrase(push)
    log_event(push, :failed_passphrase)
    Push.dispatch_webhook("push.failed_passphrase", push)
  end

  def log_expire(push)
    log_event(push, :expire)
    if Settings.respond_to?(:enable_push_notifications) && Settings.enable_push_notifications
      PushNotificationJob.perform_later(push.id, "expire") if push.user&.notify_on_expire?
    end
    Push.dispatch_webhook("push.expired", push)
  end

  def log_event(push, kind)
    # Record the resolved client IP. request.remote_ip walks the
    # X-Forwarded-For chain using config.action_dispatch.trusted_proxies, so
    # with cloudflare_proxy enabled this yields the real visitor IP rather than
    # the full proxy chain (e.g. "<client>, <cloudflare-edge>").
    ip = request.remote_ip

    # Limit retrieved values to 256 characters
    user_agent = request.env["HTTP_USER_AGENT"].to_s[0, 255]
    referrer = request.env["HTTP_REFERER"].to_s[0, 255]

    push.audit_logs.create(kind: kind, user: current_user, ip:, user_agent:, referrer:)
  end
end
