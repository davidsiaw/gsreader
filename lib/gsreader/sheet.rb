# frozen_string_literal: true

module GsReader
  # Shared plumbing for {GsReader::Reader} and {GsReader::Writer}.
  class Sheet
    # @return [String] the spreadsheet ID
    attr_reader :spreadsheet_id

    # @return [Google::Apis::SheetsV4::SheetsService]
    attr_reader :service

    # @param spreadsheet_id [String] the ID from the sheet URL
    #   (the long random-looking part between `/d/` and `/edit`)
    # @param credentials [String, Hash, Object] see {GsReader} module docs
    # @param scope [Array<String>] OAuth scopes for this client
    # @param application_name [String] optional UA string
    # @param sheet [String, nil] default tab/sheet *title* to use when a
    #   bare A1 range (e.g. `"R6"`) is passed without a `Sheet!` prefix.
    #   If nil, Google's API defaults to the first tab.
    # @param gid [Integer, String, nil] default tab to use, identified by
    #   `sheetId` (the `gid=...` value in the URL). Resolved to a title
    #   on first use. Takes precedence over `sheet:` if both are given.
    # @param service [Google::Apis::SheetsV4::SheetsService, nil] test double or nil
    #
    # @example Subclasses use this via `super`
    #   class MyClient < GsReader::Sheet
    #     def initialize(id, creds, **opts)
    #       super(id, creds, scope: GsReader::READ_SCOPE, **opts)
    #     end
    #   end
    # rubocop:disable Metrics/ParameterLists
    def initialize(spreadsheet_id, credentials, scope:, application_name: 'gsreader',
                   sheet: nil, gid: nil, service: nil)
      @spreadsheet_id = spreadsheet_id
      @raw_credentials = credentials
      @default_sheet = sheet
      @default_gid = gid
      @service = service || build_service
      @service.client_options.application_name = application_name
      @service.authorization = GsReader.build_credentials(credentials, scope: scope)
    end
    # rubocop:enable Metrics/ParameterLists

    def build_service
      Google::Apis::SheetsV4::SheetsService.new
    end

    # Title of the tab that bare ranges will be resolved against, or nil
    # if no default was configured (in which case the first tab wins).
    #
    # @return [String, nil]
    #
    # @example
    #   reader = GsReader::Reader.new(id, creds, gid: 123456789)
    #   reader.default_sheet_title # => "Inventory"
    def default_sheet_title
      return @default_sheet_title if defined?(@default_sheet_title)

      @default_sheet_title =
        if @default_gid
          resolve_gid_to_title(@default_gid)
        else
          @default_sheet
        end
    end

    # Read a range using A1 notation. Returns a 2D array for multi-cell ranges,
    # a scalar for single-cell ranges, or `nil` if the cell is empty.
    #
    # @param range [String] A1 notation, e.g. "A1", "A1:B3", "Sheet2!A1:A10"
    # @return [String, Array<Array<String>>, nil]
    #
    # @example Single cell
    #   sheet["A1"] # => "Hello"
    #
    # @example Multi-cell range
    #   sheet["A1:B2"] # => [["a", "b"], ["c", "d"]]
    def [](range)
      response = service.get_spreadsheet_values(spreadsheet_id, qualify_range(range))
      values = response.values || []

      if single_cell?(range)
        values.dig(0, 0)
      else
        values
      end
    end

    # Fetch the raw {Google::Apis::SheetsV4::ValueRange} for advanced use.
    #
    # @param range [String] A1 notation
    # @return [Google::Apis::SheetsV4::ValueRange]
    #
    # @example
    #   vr = sheet.get_range("A1:B2")
    #   vr.values # => [["a", "b"], ["c", "d"]]
    def get_range(range)
      service.get_spreadsheet_values(spreadsheet_id, qualify_range(range))
    end

    # Return spreadsheet metadata (titles of tabs, etc).
    #
    # @return [Google::Apis::SheetsV4::Spreadsheet]
    #
    # @example
    #   sheet.spreadsheet.properties.title # => "My Workbook"
    def spreadsheet
      service.get_spreadsheet(spreadsheet_id)
    end

    # Convenience: list of sheet/tab titles.
    #
    # @return [Array<String>]
    #
    # @example
    #   sheet.sheet_titles # => ["Sheet1", "Inventory", "Archive"]
    def sheet_titles
      spreadsheet.sheets.map { |s| s.properties.title }
    end

    private

    # Heuristic: a range with no `:` refers to a single cell.
    #
    # @param range [String]
    # @return [Boolean]
    def single_cell?(range)
      cell = range.to_s.split('!').last || ''
      !cell.include?(':')
    end

    # Prefix `range` with the configured default sheet title if the
    # caller didn't already include a `Sheet!` qualifier. Sheet titles
    # with spaces or non-ASCII chars get wrapped in single quotes (with
    # any embedded `'` doubled per A1 notation rules).
    #
    # @param range [String]
    # @return [String]
    def qualify_range(range)
      r = range.to_s
      return r if r.include?('!')

      title = default_sheet_title
      return r unless title && !title.empty?

      "#{quote_sheet_title(title)}!#{r}"
    end

    # Wrap a sheet title in single quotes for use in A1 notation,
    # doubling any embedded single quotes per the A1 escaping rules.
    #
    # @param title [String]
    # @return [String]
    def quote_sheet_title(title)
      "'#{title.gsub("'", "''")}'"
    end

    # Resolve a numeric `gid` (from a sheet URL) to the corresponding
    # tab's title.
    #
    # @param gid [Integer, String]
    # @return [String]
    # @raise [ArgumentError] if no tab in this spreadsheet has that gid
    def resolve_gid_to_title(gid)
      gid_i = Integer(gid)
      match = spreadsheet.sheets.find { |s| s.properties.sheet_id == gid_i }
      raise ArgumentError, "no sheet with gid=#{gid_i} in spreadsheet #{spreadsheet_id}" unless match

      match.properties.title
    end
  end
end
