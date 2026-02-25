# frozen_string_literal: true

namespace :swagger do
  desc "Generate Swagger JSON specification from Apipie"
  task generate: :environment do
    puts "Generating Swagger JSON from Apipie..."

    Rake::Task["apipie:static_swagger_json"].invoke

    # Find the generated file and copy to public/
    output_path = Rails.root.join("public", "apipie_swagger.json")
    candidates = [
      Rails.root.join("doc", "apidoc", "schema_swagger.json"),
      Rails.root.join("doc", "apipie_swagger.json"),
      Rails.root.join("public", "apipie", "schema_swagger.json")
    ]

    source = candidates.find { |p| File.exist?(p) }

    if source
      FileUtils.cp(source, output_path)
      puts "Swagger spec written to #{output_path}"
    else
      puts "Warning: Could not locate generated swagger file."
      puts "Searched: #{candidates.join(", ")}"
    end
  end
end
