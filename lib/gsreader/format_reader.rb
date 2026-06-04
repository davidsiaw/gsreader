# frozen_string_literal: true

module GsReader
  # Read-only client that exposes per-cell *formatting* (background color,
  # checkbox state, etc) via {GsReader::Cell}. Indexing returns a single
  # `Cell` for an `"A1"`-style range and a 2D array of `Cell`s for an
  # `"A1:B3"`-style range.
  #
  # @example
  #   fr = GsReader::FormatReader.new(id, "service_account.json")
  #   fr["A1"].background_color   # => "#ff0000"
  #   fr["A1"].checked?           # => true
  #   fr["A1:B2"].map { |row| row.map(&:background_color) }
  class FormatReader < Sheet
    def initialize(spreadsheet_id, credentials, **opts)
      super(spreadsheet_id, credentials, scope: GsReader::READ_SCOPE, **opts)
    end

    # Look up a cell or range by A1 notation.
    #
    # @param range [String]
    # @return [GsReader::Cell, Array<Array<GsReader::Cell>>]
    def [](range)
      grid = fetch_grid(range)
      rows = grid_to_cells(grid, range)

      if single_cell?(range)
        rows.dig(0, 0) || Cell.new(nil)
      else
        rows
      end
    end

    private

    # Returns the first (and only) GridData from a single-range
    # `getSpreadsheet` call with `includeGridData: true`.
    def fetch_grid(range)
      ss = service.get_spreadsheet(
        spreadsheet_id,
        ranges: [qualify_range(range)],
        include_grid_data: true
      )
      sheet = ss.sheets&.first
      sheet&.data&.first
    end

    # Turn a GridData into a 2D array of {Cell}s, padding with empty
    # cells if the API omits trailing empty cells/rows.
    def grid_to_cells(grid, range)
      width, height = range_dimensions(range)
      raw_rows = grid&.row_data || []

      # For unbounded ranges ("A:A", whole column / row) the API itself
      # decides the shape; fall back to what it returned.
      height = raw_rows.length if height == Float::INFINITY
      width = (raw_rows.map { |r| (r&.values || []).length }.max || 0) if width == Float::INFINITY

      Array.new(height) do |r|
        row_cells = (raw_rows[r]&.values) || []
        Array.new(width) { |c| Cell.new(row_cells[c]) }
      end
    end

    # Estimate the (width, height) of an A1 range so we can pad missing
    # cells. For unbounded or whole-column ranges we fall back to the
    # actual returned dimensions.
    def range_dimensions(range)
      cell_part = range.to_s.split('!').last || ''
      if cell_part.include?(':')
        a, b = cell_part.split(':', 2)
        ca, ra = parse_a1(a)
        cb, rb = parse_a1(b)
        if ca && cb && ra && rb
          [(cb - ca).abs + 1, (rb - ra).abs + 1]
        else
          [Float::INFINITY, Float::INFINITY] # let raw rows decide
        end
      else
        [1, 1]
      end
    end

    # Parse "B7" -> [col_index(0-based), row_index(0-based)]
    # Returns nils for unbounded refs like "A" or "1".
    def parse_a1(ref)
      m = ref.match(/\A([A-Za-z]+)?(\d+)?\z/)
      return [nil, nil] unless m

      col = m[1] ? column_letters_to_index(m[1]) : nil
      row = m[2] ? m[2].to_i - 1 : nil
      [col, row]
    end

    def column_letters_to_index(letters)
      letters.upcase.each_char.reduce(0) { |acc, ch| acc * 26 + (ch.ord - 'A'.ord + 1) } - 1
    end
  end
end
