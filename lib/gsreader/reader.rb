# frozen_string_literal: true

module GsReader
  # Read-only client for a Google Sheet.
  #
  # @example
  #   reader = GsReader::Reader.new("1abc...XYZ", "service_account.json")
  #   reader["A1"]            # => "Hello"
  #   reader["Sheet1!A1:B2"]  # => [["a", "b"], ["c", "d"]]
  class Reader < Sheet
    def initialize(spreadsheet_id, credentials, **opts)
      super(spreadsheet_id, credentials, scope: GsReader::READ_SCOPE, **opts)
    end
  end
end
