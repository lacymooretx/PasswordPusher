# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Register a custom driver that respects CHROME_BIN environment variable.
  # This allows CI to pin a specific Chrome version to avoid flaky tests.
  Capybara.register_driver :headless_chrome_custom do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_argument("--window-size=1400,1400")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")

    # Use custom Chrome binary if specified (for CI pinning)
    if ENV["CHROME_BIN"].present?
      options.binary = ENV["CHROME_BIN"]
    end

    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  end

  driven_by :headless_chrome_custom

  # Include Devise test helpers for system tests
  include Warden::Test::Helpers

  # Set up any specific system test configuration here
  setup do
    # Any setup needed for all system tests
  end

  teardown do
    # Any teardown needed for all system tests
  end

  # Expands the collapsible "Additional Options" section on push forms so its
  # controls (retrieval step, deletable-by-viewer, passphrase) become visible
  # and interactable. No-op if already expanded. See GH #4348.
  def reveal_additional_options
    return if has_css?("#additionalOptionsCollapse.show", wait: 0)
    find("button[data-bs-target='#additionalOptionsCollapse']").click
    assert_selector "#additionalOptionsCollapse.show"
  end
end
