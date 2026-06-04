# frozen_string_literal: true

require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/service_account'
require 'json'
require 'stringio'

require 'gsreader/version'

# `GsReader::Reader` and `GsReader::Writer` are tiny convenience wrappers
# around the Google Sheets v4 API that let you treat a spreadsheet like a
# Hash keyed by A1 notation:
#
#   reader = GsReader::Reader.new("<spreadsheet_id>", credentials)
#   reader["A1"]              # => single-cell value
#   reader["A1:B3"]           # => 2D array of values
#   reader["Sheet2!A1:A10"]   # => values from a specific tab
#
#   writer = GsReader::Writer.new("<spreadsheet_id>", credentials)
#   writer["A1"] = "hello"
#   writer["A1:B2"] = [["a", "b"], ["c", "d"]]
#
# `credentials` may be:
#   * a path to a service-account JSON key file
#   * the JSON key contents as a String
#   * a Hash parsed from the JSON key
#   * an already-built Google::Auth credentials object (anything that
#     responds to `#fetch_access_token!`)
module GsReader
  class Error < StandardError; end
  class CredentialError < Error; end

  # OAuth scopes used by the reader (read-only) and writer (read/write).
  READ_SCOPE  = ['https://www.googleapis.com/auth/spreadsheets.readonly'].freeze
  WRITE_SCOPE = ['https://www.googleapis.com/auth/spreadsheets'].freeze

  # Build a Google::Auth credentials object from a variety of inputs.
  #
  # @param credentials [String, Hash, #fetch_access_token!]
  # @param scope [Array<String>] OAuth scopes to request
  # @return [Object] something that responds to `#fetch_access_token!`
  def self.build_credentials(credentials, scope:)
    return credentials if credentials.respond_to?(:fetch_access_token!)

    json =
      case credentials
      when Hash
        JSON.dump(credentials)
      when String
        if credentials.lstrip.start_with?('{')
          credentials
        elsif File.file?(credentials)
          File.read(credentials)
        else
          raise CredentialError,
                "credentials string is neither JSON nor an existing file path: #{credentials.inspect}"
        end
      else
        raise CredentialError, "unsupported credentials type: #{credentials.class}"
      end

    Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(json),
      scope: scope
    )
  end
end

require 'gsreader/sheet'
require 'gsreader/reader'
require 'gsreader/writer'
require 'gsreader/cell'
require 'gsreader/format_reader'
