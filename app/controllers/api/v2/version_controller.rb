# frozen_string_literal: true

class Api::V2::VersionController < Api::BaseController
  api :GET, "/api/v2/version.json", "Get the version details of the application and the API."
  formats ["JSON"]
  description <<-EOS
    == Version Information

    Retrieves the current application version, API version and edition.

    === Example Response

      {
        "application_version": "2.1.0",
        "api_version": "2.0",
        "edition": "oss"
      }
  EOS
  def show
    render json: {
      application_version: Version.current.to_s,
      api_version: "2.0",
      edition: "oss"
    }
  end
end
