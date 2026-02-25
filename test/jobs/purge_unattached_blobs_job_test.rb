# frozen_string_literal: true

require "test_helper"

class PurgeUnattachedBlobsJobTest < ActiveJob::TestCase
  test "calls system with the correct command" do
    called_with = nil

    PurgeUnattachedBlobsJob.define_method(:system) do |cmd|
      called_with = cmd
    end

    PurgeUnattachedBlobsJob.perform_now

    assert_equal "bin/pwpush active_storage:purge_unattached", called_with
  ensure
    PurgeUnattachedBlobsJob.remove_method(:system)
  end
end
