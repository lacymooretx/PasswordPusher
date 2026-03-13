# frozen_string_literal: true

require "test_helper"

class TeamsNotifierTest < ActiveSupport::TestCase
  test "build_card returns valid MessageCard" do
    notifier = TeamsNotifier.new("https://example.com/webhook")
    push = pushes(:test_push)

    card = notifier.send(:build_card, "push.created", push, {})
    assert_equal "MessageCard", card["@type"]
    assert card["sections"].is_a?(Array)
    assert card["sections"].first["facts"].any? { |f| f[:name] == "Kind" }
  end

  test "notify skips when no webhook_url" do
    notifier = TeamsNotifier.new(nil)
    push = pushes(:test_push)

    # Should not raise, just return nil
    assert_nil notifier.notify("push.created", push)
  end
end
