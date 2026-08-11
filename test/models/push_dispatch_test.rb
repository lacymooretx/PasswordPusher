# frozen_string_literal: true

require "test_helper"

class PushDispatchTest < ActiveSupport::TestCase
  setup do
    @push = pushes(:test_push)
  end

  def build_dispatch(**attrs)
    PushDispatch.new({push: @push, channel: :email, role: :recipient, destination: "a@example.com"}.merge(attrs))
  end

  test "requires a destination" do
    dispatch = build_dispatch(destination: nil)

    assert_not dispatch.valid?
    assert_includes dispatch.errors[:destination], "can't be blank"
  end

  test "stores the destination encrypted at rest" do
    dispatch = build_dispatch(destination: "secret@example.com")
    dispatch.save!

    raw = PushDispatch.connection.select_value(
      "SELECT destination_ciphertext FROM push_dispatches WHERE id = #{dispatch.id}"
    )

    assert raw.present?
    assert_not_includes raw.to_s, "secret@example.com"
    assert_equal "secret@example.com", dispatch.reload.destination
  end

  test "mark_sent! records the timestamp and clears any prior error" do
    dispatch = build_dispatch
    dispatch.save!
    dispatch.mark_failed!("temporary glitch")

    dispatch.mark_sent!("msg_9")

    assert dispatch.sent?
    assert_equal "msg_9", dispatch.provider_message_id
    assert dispatch.sent_at.present?
    assert_nil dispatch.error
  end

  test "mark_failed! truncates long provider errors" do
    dispatch = build_dispatch
    dispatch.save!

    dispatch.mark_failed!("x" * 900)

    assert dispatch.failed?
    assert_equal 500, dispatch.error.length
  end

  test "masks email destinations for display" do
    dispatch = build_dispatch(destination: "alexander@example.com")

    assert_equal "al*******@example.com", dispatch.masked_destination
  end

  test "masks phone destinations to the last four digits" do
    dispatch = build_dispatch(channel: :sms, destination: "+17138750817")

    assert_equal "********0817", dispatch.masked_destination
  end

  test "is destroyed with its push" do
    dispatch = build_dispatch
    dispatch.save!

    assert_difference -> { PushDispatch.count }, -1 do
      @push.destroy
    end
  end
end
