# frozen_string_literal: true
require "google/apis/drive_v3"
require "stringio"

FILE_FIELDS = "id,name,mimeType,modifiedTime,parents,sha256Checksum"
LIST_FIELDS = "nextPageToken,incompleteSearch,files(#{FILE_FIELDS})"

API_KEY =
  ENV.fetch("GOOGLE_API_KEY") { raise KeyError, "GOOGLE_API_KEY is required" }

def list_folder_files(folder_id:)
  drive = Google::Apis::DriveV3::DriveService.new
  drive.key = API_KEY

  files = []
  page_token = nil

  loop do
    file_list =
      drive.list_files(
        corpora: "user",
        fields: LIST_FIELDS,
        include_items_from_all_drives: true,
        order_by: "folder,name_natural",
        page_size: 1000,
        page_token: page_token,
        q: "'#{folder_id}' in parents and trashed = false",
        spaces: "drive",
        supports_all_drives: true
      )

    files.concat(file_list.files)

    page_token = file_list.next_page_token
    break if page_token.nil?
  end

  files
end

def download_file(file_id:)
  # drive = Google::Apis::DriveV3::DriveService.new
  # drive.key = API_KEY
  #
  # content = StringIO.new
  # drive.get_file(file_id, supports_all_drives: true, download_dest: content)
  # content.string
  HTTP.get(
    "https://drive.usercontent.google.com/download",
    params: {
      id: file_id,
      export: "download",
      authuser: 0,
      confirm: "t"
    }
  ).to_s
end
