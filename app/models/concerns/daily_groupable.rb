# frozen_string_literal: true

# Provides a `group_by_day` scope that groups records by date.
# Returns an array of [date_string, count] pairs.
module DailyGroupable
  extend ActiveSupport::Concern

  included do
    scope :group_by_day, -> {
      if connection.adapter_name.downcase.include?("sqlite")
        group("date(created_at)").order("date(created_at)").count
      else
        group("DATE(created_at)").order("DATE(created_at)").count
      end
    }
  end
end
