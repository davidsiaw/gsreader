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
  # Base error class for all `GsReader`-specific errors. Catch this if
  # you want to rescue any failure originating from this gem (as opposed
  # to errors raised by the underlying `google-api-client`).
  #
  # @example
  #   begin
  #     GsReader::Reader.new(id, "missing.json")
  #   rescue GsReader::Error => e
  #     warn "gsreader failed: #{e.message}"
  #   end
  class Error < StandardError; end

  # Raised by {GsReader.build_credentials} when the `credentials`
  # argument can't be turned into a usable Google::Auth credentials
  # object — e.g. the String is neither JSON nor an existing file path,
  # or the value is of an unsupported type.
  #
  # @example
  #   begin
  #     GsReader::Reader.new(id, "/no/such/file.json")
  #   rescue GsReader::CredentialError => e
  #     warn "bad credentials: #{e.message}"
  #   end
  class CredentialError < Error; end

  # OAuth scopes used by the reader (read-only) and writer (read/write).
  READ_SCOPE  = ['https://www.googleapis.com/auth/spreadsheets.readonly'].freeze
  WRITE_SCOPE = ['https://www.googleapis.com/auth/spreadsheets'].freeze

  # Build a Google::Auth credentials object from a variety of inputs.
  #
  # Accepts a path to a JSON key file, a JSON string, a Hash parsed from
  # a JSON key, or any object that already responds to
  # `#fetch_access_token!` (which is returned untouched).
  #
  # @param credentials [String, Hash, #fetch_access_token!] credential source
  # @param scope [Array<String>] OAuth scopes to request
  # @return [Object] something that responds to `#fetch_access_token!`
  # @raise [CredentialError] if `credentials` cannot be interpreted
  #
  # @example From a JSON key file path
  #   creds = GsReader.build_credentials("service_account.json",
  #                                      scope: GsReader::READ_SCOPE)
  #
  # @example From an inline Hash
  #   creds = GsReader.build_credentials(
  #     JSON.parse(ENV.fetch("GOOGLE_KEY_JSON")),
  #     scope: GsReader::WRITE_SCOPE
  #   )
  def self.build_credentials(credentials, scope:)
    return credentials if credentials.respond_to?(:fetch_access_token!)

    json = credentials_to_json(credentials)
    Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(json),
      scope: scope
    )
  end

  def self.credentials_to_json(credentials)
    case credentials
    when Hash
      JSON.dump(credentials)
    when String
      string_to_json(credentials)
    else
      raise CredentialError, "unsupported credentials type: #{credentials.class}"
    end
  end

  def self.string_to_json(credentials)
    if credentials.lstrip.start_with?('{')
      credentials
    elsif File.file?(credentials)
      File.read(credentials)
    else
      raise CredentialError, "credentials string is neither JSON nor an existing file path: #{credentials.inspect}"
    end
  end
  private_class_method :credentials_to_json, :string_to_json
end

require 'gsreader/sheet'
require 'gsreader/reader'
require 'gsreader/writer'
require 'gsreader/cell'
require 'gsreader/format_reader'
