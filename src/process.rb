# frozen_string_literal: true
require "digest/xxhash"

def process_folder(
  context:,
  id:,
  author:,
  author_id:,
  versioning:,
  license:,
  recursive:
)
  files = list_folder_files(folder_id: id)
  puts "Found #{files.size} files in folder #{id}"
  files.map do |file|
    case file.mime_type
    when "application/vnd.google-apps.folder"
      if recursive
        process_folder(
          context:,
          id: file.id,
          author:,
          author_id:,
          versioning:,
          license:,
          recursive:
        )
      else
        puts "Skipping folder #{file.name} (#{file.id}) because recursive processing is disabled."
      end
    else
      process_file(context:, file:, author:, author_id:, versioning:, license:)
    end
  end
end

SCRIPT_EXTENSIONS = %w[anm2 scn2 obj2 tra2 cam2 mod2].freeze
PLUGIN_EXTENSIONS = %w[aui2 auo2 aux2 auf2].freeze

def xxh3128_hash(context:, file:)
  context
    .known_hashes
    .fetch(file.sha256_checksum) do
      puts "New hash for file #{file.name} (#{file.id}): #{file.sha256_checksum}"
      downloaded_content = download_file(file_id: file.id)
      context.known_hashes[
        file.sha256_checksum
      ] = Digest::XXH3_128bits.hexdigest(downloaded_content)
    end
end

def dir_for_file(file)
  if file.name.end_with?(*SCRIPT_EXTENSIONS)
    "{scriptsDir}"
  elsif file.name.end_with?(*PLUGIN_EXTENSIONS)
    "{pluginsDir}"
  else
    raise ArgumentError,
          "Unknown file extension for file #{file.name} (#{file.id})"
  end
end
def path_for_file(file)
  "#{dir_for_file(file)}/#{file.name}"
end

def process_file(context:, file:, author:, author_id:, versioning:, license:)
  puts "Processing file: #{file.name} (#{file.id})"
  if versioning == "date"
    version = file.modified_time.strftime("%Y.%m.%d")
  else
    raise ArgumentError, "Unknown versioning type: #{versioning}"
  end
  existing =
    context.packages.find do |pkg|
      pkg.dig("installer", "source", "GoogleDrive", "id") == file.id
    end
  if existing
    puts "File #{file.name} (#{file.id}) already exists in the catalog."
    xxh3 = xxh3128_hash(context:, file:)
    puts "XXH3 hash for file #{file.name} (#{file.id}): #{xxh3}"
    latest_version = existing["version"][-1]
    if latest_version["file"][0]["XXH3_128"] == xxh3
      puts "File #{file.name} (#{file.id}) is up to date."
    else
      puts "File #{file.name} (#{file.id}) has changed, updating the catalog."
      return(
        {
          "id" => existing["id"],
          "version" => [
            {
              "version" => version,
              "release_date" => file.modified_time.strftime("%Y-%m-%d"),
              "file" => ["path" => path_for_file(file), "XXH3_128" => xxh3]
            }
          ]
        }
      )
    end
  else
    puts "File #{file.name} (#{file.id}) is new, adding to the catalog."
    return(
      {
        "id" => "#{author_id}.#{file.id}",
        "name" => file.name.match(/^@?(?<name>.+)\.[^.]+$/)[:name],
        "author" => author,
        "licenses" => [license],
        "type" =>
          if file.name.end_with?(*SCRIPT_EXTENSIONS)
            "スクリプト"
          elsif file.name.end_with?(*PLUGIN_EXTENSIONS)
            "プラグイン"
          else
            nil
          end,
        "version" => [
          {
            "version" => version,
            "release_date" => file.modified_time.strftime("%Y-%m-%d"),
            "file" => [
              "path" => path_for_file(file),
              "XXH3_128" => xxh3128_hash(context:, file:)
            ]
          }
        ],
        "installer" => {
          "source" => {
            "GoogleDrive" => {
              "id" => file.id
            }
          },
          "install" => [
            { "action" => "download" },
            {
              "action" => "copy",
              "from" => "{tmp}/#{file.name}",
              "to" => path_for_file(file)
            }
          ],
          "uninstall" => [
            { "action" => "delete", "path" => path_for_file(file) }
          ]
        }
      }
    )
  end
end
