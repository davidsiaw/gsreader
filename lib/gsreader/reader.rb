# frozen_string_literal: true

module GsReader
  # Read-only client for a Google Sheet.
  #
  # @example
  #   reader = GsReader::Reader.new("1abc...XYZ", "service_account.json")
  #   reader["A1"]            # => "Hello"
  #   reader["Sheet1!A1:B2"]  # => [["a", "b"], ["c", "d"]]
  class Reader < Sheet
    # Build a read-only client for a given spreadsheet.
    #
    # @param spreadsheet_id [String] the ID from the sheet URL
    # @param credentials [String, Hash, Object] see {GsReader.build_credentials}
    # @param opts [Hash] forwarded to {GsReader::Sheet#initialize}
    #   (e.g. `sheet:`, `gid:`, `application_name:`)
    #
    # @example Read a single cell
    #   reader = GsReader::Reader.new("1abc...XYZ", "service_account.json")
    #   reader["A1"] # => "Hello"
    #
    # @example Default to a specific tab
    #   reader = GsReader::Reader.new(id, creds, sheet: "Sheet2")
    #   reader["A1:B2"] # => values from Sheet2
    def initialize(spreadsheet_id, credentials, **opts)
      super(spreadsheet_id, credentials, scope: GsReader::READ_SCOPE, **opts)
    end
  end
end
