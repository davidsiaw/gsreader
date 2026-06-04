# frozen_string_literal: true

module GsReader
  # Read/write client for a Google Sheet.
  #
  # @example
  #   writer = GsReader::Writer.new("1abc...XYZ", "service_account.json")
  #   writer["A1"]      = "Hello"
  #   writer["A1:B2"]   = [["a", "b"], ["c", "d"]]
  #   writer.append("Sheet1!A:B", [["x", "y"], ["z", "w"]])
  #   writer.clear("A1:B2")
  class Writer < Sheet
    # How input is parsed by Google Sheets. `USER_ENTERED` lets formulas like
    # "=SUM(A1:A2)" and dates be interpreted just like a human typing them in.
    # Use `RAW` to store strings verbatim.
    DEFAULT_VALUE_INPUT_OPTION = 'USER_ENTERED'

    # @return [String] value input option used by `[]=` and `append`
    attr_accessor :value_input_option

    # Build a read/write client for a given spreadsheet.
    #
    # @param spreadsheet_id [String] the ID from the sheet URL
    # @param credentials [String, Hash, Object] see {GsReader.build_credentials}
    # @param value_input_option [String] how Sheets parses written
    #   values; either `"USER_ENTERED"` (default) or `"RAW"`
    # @param opts [Hash] forwarded to {GsReader::Sheet#initialize}
    #
    # @example
    #   writer = GsReader::Writer.new(id, "service_account.json")
    #   writer["A1"] = "Hello"
    #
    # @example Store strings verbatim (no formula evaluation)
    #   writer = GsReader::Writer.new(id, creds, value_input_option: "RAW")
    #   writer["A1"] = "=NOT_A_FORMULA()"
    def initialize(spreadsheet_id, credentials, value_input_option: DEFAULT_VALUE_INPUT_OPTION, **opts)
      super(spreadsheet_id, credentials, scope: GsReader::WRITE_SCOPE, **opts)
      @value_input_option = value_input_option
    end

    # Write a value (or 2D array of values) to a range.
    #
    # @param range [String] A1 notation, e.g. "A1", "A1:B2", "Sheet2!A1"
    # @param value [Object, Array, Array<Array>] scalar or 2D array
    # @return [Google::Apis::SheetsV4::UpdateValuesResponse]
    #
    # @example Write a scalar
    #   writer["A1"] = "Hello"
    #
    # @example Write a 2D block
    #   writer["A1:B2"] = [["a", "b"], ["c", "d"]]
    def []=(range, value)
      values = normalize_values(value)
      body = Google::Apis::SheetsV4::ValueRange.new(values: values)
      service.update_spreadsheet_value(
        spreadsheet_id,
        range,
        body,
        value_input_option: value_input_option
      )
    end

    # Append rows to the bottom of an existing table.
    #
    # @param range [String] a range that locates the table, e.g. "Sheet1!A:B"
    # @param values [Array<Array>] rows to append
    # @return [Google::Apis::SheetsV4::AppendValuesResponse]
    #
    # @example
    #   writer.append("Sheet1!A:B", [["x", "y"], ["z", "w"]])
    def append(range, values)
      body = Google::Apis::SheetsV4::ValueRange.new(values: normalize_values(values))
      service.append_spreadsheet_value(
        spreadsheet_id,
        range,
        body,
        value_input_option: value_input_option
      )
    end

    # Clear the contents (but not formatting) of a range.
    #
    # @param range [String] A1 notation
    # @return [Google::Apis::SheetsV4::ClearValuesResponse]
    #
    # @example
    #   writer.clear("A1:B2")
    def clear(range)
      service.clear_values(
        spreadsheet_id,
        range,
        Google::Apis::SheetsV4::ClearValuesRequest.new
      )
    end

    private

    # Coerce assorted inputs into the 2D array Google's API expects.
    #
    # @param value [Object, Array, Array<Array>]
    # @return [Array<Array>]
    def normalize_values(value)
      case value
      when Array
        if value.empty?
          [[]]
        elsif value.first.is_a?(Array)
          value
        else
          [value]
        end
      else
        [[value]]
      end
    end
  end
end
