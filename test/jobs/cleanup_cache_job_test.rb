# frozen_string_literal: true

require "test_helper"

class CleanupCacheJobTest < ActiveJob::TestCase
  setup do
    @cache_dir = Rails.root.join("tmp", "cache", "test_cleanup")
    FileUtils.mkdir_p(@cache_dir)
  end

  teardown do
    FileUtils.rm_rf(@cache_dir)
  end

  test "deletes files older than 24 hours from tmp/cache" do
    old_file = File.join(@cache_dir, "old_cache_file.txt")
    File.write(old_file, "old data")
    FileUtils.touch(old_file, mtime: 25.hours.ago.to_time)

    assert File.exist?(old_file), "Old file should exist before job runs"

    CleanupCacheJob.perform_now

    assert_not File.exist?(old_file), "Old cache file should be deleted"
  end

  test "does not delete recent files from tmp/cache" do
    recent_file = File.join(@cache_dir, "recent_cache_file.txt")
    File.write(recent_file, "recent data")
    # File was just created, so mtime is now (well within 24 hours)

    CleanupCacheJob.perform_now

    assert File.exist?(recent_file), "Recent cache file should still exist"
  end

  test "does not raise error when cache directory does not exist" do
    # Remove the cache directory so it doesn't exist
    FileUtils.rm_rf(Rails.root.join("tmp", "cache"))
    FileUtils.rm_rf(Rails.root.join("tmp", "rack_attack_cache"))

    assert_nothing_raised do
      CleanupCacheJob.perform_now
    end
  ensure
    # Recreate cache dir so other tests aren't affected
    FileUtils.mkdir_p(Rails.root.join("tmp", "cache"))
  end
end
