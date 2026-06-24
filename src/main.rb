#!/usr/bin/env ruby
# frozen_string_literal: true

require "dotenv/load"
require "dry-schema"
require "yaml"
require "http"
require "json"

require_relative "api_client"
require_relative "context"
require_relative "process"

module Types
  include Dry.Types()
end

FolderSchema =
  Types::Hash.schema(
    type: Types::String.enum("folder"),
    id: Types::String,
    author: Types::String,
    author_id: Types::String,
    versioning: Types::String.enum("date"),
    license: Types::Hash,
    recursive: Types::Bool.default(false)
  )

Targets = Types::Array.of(FolderSchema)

targets = Targets.call(YAML.load_file("targets.yml", symbolize_names: true))
packages =
  HTTP
    .headers(
      authorization: ENV["GITHUB_TOKEN"].then { |token| "Bearer #{token}" }
    )
    .get(
      "https://raw.githubusercontent.com/Neosku/aviutl2-catalog-data/refs/heads/main/index.json"
    )
    .parse(:json)
known_hashes = JSON.load_file("./data/known_hashes.json")
context = Context.new(ignore_on_missing: false, packages:, known_hashes:)
puts "Processing #{targets.size} targets..."
final_json =
  targets
    .map do |target|
      puts "Processing target: #{target[:id]} (#{target[:type]})"
      case target[:type]
      when "folder"
        process_folder(
          context:,
          id: target[:id],
          author: target[:author],
          author_id: target[:author_id],
          versioning: target[:versioning],
          license: target[:license],
          recursive: target[:recursive]
        )
      end
    end
    .flatten
    .compact

puts "Saving known hashes..."
File.write(
  "./data/known_hashes.json",
  JSON.pretty_generate(context.known_hashes)
)
puts "Saving final JSON..."
File.write("./final.json", JSON.pretty_generate(final_json))
puts "Done."
