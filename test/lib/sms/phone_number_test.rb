# frozen_string_literal: true

require "test_helper"

class Sms::PhoneNumberTest < ActiveSupport::TestCase
  test "normalizes common US formats to E.164" do
    %w[
      7138750817
      713-875-0817
      (713)875-0817
    ].each do |input|
      assert_equal "+17138750817", Sms::PhoneNumber.normalize(input), "failed for #{input}"
    end

    assert_equal "+17138750817", Sms::PhoneNumber.normalize("(713) 875-0817")
    assert_equal "+17138750817", Sms::PhoneNumber.normalize("1 713 875 0817")
  end

  test "keeps an explicitly international number" do
    assert_equal "+447911123456", Sms::PhoneNumber.normalize("+44 7911 123456")
    assert_equal "+17138750817", Sms::PhoneNumber.normalize("+1 (713) 875-0817")
  end

  test "honours a non-US default country code" do
    assert_equal "+447911123456", Sms::PhoneNumber.normalize("7911123456", default_country_code: "44")
  end

  test "rejects values that cannot be phone numbers" do
    ["", "   ", nil, "abc", "12345", "+123"].each do |input|
      assert_nil Sms::PhoneNumber.normalize(input), "expected nil for #{input.inspect}"
      assert_not Sms::PhoneNumber.valid?(input)
    end
  end

  test "normalize_list splits, normalizes and dedupes" do
    list = Sms::PhoneNumber.normalize_list("713-875-0817, (713) 875-0817; +447911123456 nonsense")

    assert_equal ["+17138750817", "+447911123456"], list
  end

  test "normalize_list accepts an array" do
    assert_equal ["+17138750817"], Sms::PhoneNumber.normalize_list(["713.875.0817"])
  end
end
