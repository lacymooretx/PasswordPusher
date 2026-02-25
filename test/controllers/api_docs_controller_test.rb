# frozen_string_literal: true

require "test_helper"

class ApiDocsControllerTest < ActionDispatch::IntegrationTest
  test "index renders swagger UI page" do
    get api_docs_path
    assert_response :success
    assert_select "#swagger-ui"
  end

  test "swagger json returns spec when file exists" do
    spec_path = Rails.root.join("public", "apipie_swagger.json")
    File.write(spec_path, '{"swagger":"2.0","info":{"title":"PasswordPusher API"}}')

    get api_docs_swagger_path
    assert_response :success

    File.delete(spec_path) if File.exist?(spec_path)
  end

  test "swagger json returns 404 when spec missing" do
    spec_path = Rails.root.join("public", "apipie_swagger.json")
    File.delete(spec_path) if File.exist?(spec_path)

    get api_docs_swagger_path
    assert_response :not_found
    json = JSON.parse(response.body)
    assert json["error"].include?("Swagger specification not found")
  end
end
