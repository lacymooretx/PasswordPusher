# frozen_string_literal: true

require "test_helper"

class FileScanJobTest < ActiveJob::TestCase
  setup do
    @original_enable_clamav = Settings.enable_clamav
    @original_enable_file_pushes = Settings.enable_file_pushes
    @original_enable_logins = Settings.enable_logins
    Settings.enable_clamav = true
    Settings.enable_file_pushes = true
    Settings.enable_logins = true # file pushes require logins to be on as well

    @push = Push.create!(kind: "file", user: users(:luca), payload: "file push")
    @push.files.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test-file.txt")),
      filename: "test-file.txt"
    )
  end

  teardown do
    Settings.enable_clamav = @original_enable_clamav
    Settings.enable_file_pushes = @original_enable_file_pushes
    Settings.enable_logins = @original_enable_logins
  end

  test "does nothing when clamav is disabled" do
    Settings.enable_clamav = false

    called = false
    ClamavScanner.stub(:scan, ->(*) { called = true }) do
      FileScanJob.perform_now(@push.id)
    end

    assert_not called
  end

  test "leaves a clean push alone" do
    clean = ClamavScanner::Result.new(clean: true, virus: nil)

    ClamavScanner.stub(:scan, clean) do
      FileScanJob.perform_now(@push.id)
    end

    assert_not @push.reload.expired
  end

  test "expires and audits a push when a virus is found" do
    infected = ClamavScanner::Result.new(clean: false, virus: "Eicar-Test-Signature")

    ClamavScanner.stub(:scan, infected) do
      FileScanJob.perform_now(@push.id)
    end

    assert @push.reload.expired, "infected push should be expired"
    assert @push.audit_logs.where(user_agent: "ClamAV: Eicar-Test-Signature").exists?
  end

  # This is the regression that let ClamAV sit dead for ~3 months: the job
  # exhausted its retries and vanished, leaving the push live and unscanned with
  # nothing recorded anywhere.
  test "surfaces an exhausted retry instead of giving up silently" do
    # A real logger over a StringIO: a bare stub object with a catch-all
    # method_missing looks callable to Minitest#stub and gets invoked instead of
    # returned.
    log_io = StringIO.new
    test_logger = ActiveSupport::Logger.new(log_io)

    refused = ->(*) { raise ClamavScanner::ConnectionError, "Connection refused" }

    Rails.stub(:logger, test_logger) do
      ClamavScanner.stub(:scan, refused) do
        # Reuse one job instance so ActiveJob's own per-exception retry counter
        # advances naturally: attempts 1 and 2 re-enqueue, the 3rd exhausts
        # retry_on and runs the give-up block. Driving it this way avoids
        # hardcoding ActiveJob's internal exception_executions key.
        job = FileScanJob.new(@push.id)
        3.times { assert_nothing_raised { job.perform_now } }
      end
    end

    logged = log_io.string

    assert_match(/gave up scanning push #{@push.id}/, logged,
      "expected a loud error on give-up")
    assert_match(/UNSCANNED/, logged)
    assert_enqueued_with(job: ClamavHealthCheckJob)
    assert_not @push.reload.expired, "give-up must not silently expire the user's push"
  end
end
