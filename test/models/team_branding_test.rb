# frozen_string_literal: true

require "test_helper"

class TeamBrandingTest < ActiveSupport::TestCase
  setup do
    @team = teams(:one_team)
    @empty_team = teams(:empty_team)
    @branding = TeamBranding.new(team: @empty_team)
  end

  test "valid with minimal attributes" do
    assert @branding.valid?
  end

  test "valid with all attributes" do
    @branding.assign_attributes(
      brand_title: "Acme Corp",
      brand_tagline: "Secure sharing",
      delivery_heading: "Secure message",
      delivery_message: "This message is secure.",
      delivery_footer: "© 2026 Acme Corp",
      primary_color: "#0d6efd",
      background_color: "#ffffff",
      white_label: true
    )
    assert @branding.valid?
  end

  test "requires team" do
    branding = TeamBranding.new
    assert_not branding.valid?
    assert branding.errors[:team].any?
  end

  test "validates delivery_heading max length" do
    @branding.delivery_heading = "x" * 201
    assert_not @branding.valid?
    assert @branding.errors[:delivery_heading].any?
  end

  test "allows blank delivery_heading" do
    @branding.delivery_heading = ""
    assert @branding.valid?
  end

  test "validates delivery_message max length" do
    @branding.delivery_message = "x" * 2001
    assert_not @branding.valid?
    assert @branding.errors[:delivery_message].any?
  end

  test "validates delivery_footer max length" do
    @branding.delivery_footer = "x" * 201
    assert_not @branding.valid?
    assert @branding.errors[:delivery_footer].any?
  end

  test "validates brand_title max length" do
    @branding.brand_title = "x" * 101
    assert_not @branding.valid?
    assert @branding.errors[:brand_title].any?
  end

  test "validates brand_tagline max length" do
    @branding.brand_tagline = "x" * 201
    assert_not @branding.valid?
    assert @branding.errors[:brand_tagline].any?
  end

  test "validates primary_color format" do
    @branding.primary_color = "not-a-color"
    assert_not @branding.valid?
    assert @branding.errors[:primary_color].any?
  end

  test "allows valid hex primary_color" do
    @branding.primary_color = "#336699"
    assert @branding.valid?
  end

  test "allows blank primary_color" do
    @branding.primary_color = ""
    assert @branding.valid?
  end

  test "validates background_color format" do
    @branding.background_color = "red"
    assert_not @branding.valid?
    assert @branding.errors[:background_color].any?
  end

  test "allows valid hex background_color" do
    @branding.background_color = "#f5f5f5"
    assert @branding.valid?
  end

  test "enforces uniqueness of team_id" do
    # one_team already has a branding via fixture
    duplicate = TeamBranding.new(team: @team)
    assert_not duplicate.valid?
    assert duplicate.errors[:team_id].any?
  end

  test "team has_one team_branding" do
    assert @team.respond_to?(:team_branding)
  end

  test "fixture loads correctly" do
    branding = team_brandings(:one)
    assert_equal "Test Brand", branding.brand_title
    assert_equal @team, branding.team
  end
end
