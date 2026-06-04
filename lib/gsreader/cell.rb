# frozen_string_literal: true

module GsReader
  # A thin wrapper around `Google::Apis::SheetsV4::CellData` that exposes
  # the bits of formatting we care about (background color, checkbox
  # state, value).
  #
  # @example
  #   cell = format_reader["A1"]
  #   cell.background_color   # => "#ff0000"
  #   cell.checked?           # => true
  #   cell.value              # => true / "hello" / 42 / nil
  class Cell
    # @return [Google::Apis::SheetsV4::CellData, nil] the underlying API object
    attr_reader :cell_data

    # Wrap a `CellData` returned by the Sheets API. `nil` is allowed and
    # represents an empty/absent cell; all accessors handle it gracefully.
    #
    # @param cell_data [Google::Apis::SheetsV4::CellData, nil]
    #
    # @example
    #   GsReader::Cell.new(nil).value # => nil
    def initialize(cell_data)
      @cell_data = cell_data
    end

    # Background color of the cell as a 6-digit `#rrggbb` hex string,
    # or `nil` if the cell has no background set.
    #
    # Google's API gives colors as red/green/blue floats in `[0.0, 1.0]`.
    # Unspecified channels mean 0 (so a missing color is `#000000` —
    # which is why we treat "no format at all" as `nil` instead).
    #
    # @return [String, nil]
    #
    # @example
    #   cell.background_color # => "#ff0000"
    def background_color
      fmt = effective_format
      return nil unless fmt

      color = fmt.background_color_style&.rgb_color || fmt.background_color
      return nil unless color
      # Sheets returns plain white (#ffffff) for "no background"; keep that
      # explicit rather than collapsing it to nil — callers who want to
      # treat white as "unset" can compare to "#ffffff" themselves.

      rgb_to_hex(color)
    end

    # Is this cell a checkbox? (i.e. has a BOOLEAN data validation rule)
    #
    # @return [Boolean]
    #
    # @example
    #   cell.checkbox? # => true
    def checkbox?
      cond = cell_data&.data_validation&.condition
      !cond.nil? && cond.type == 'BOOLEAN'
    end

    # Is this cell a *checked* checkbox? Returns false for unchecked
    # checkboxes and for cells that aren't checkboxes at all.
    #
    # @return [Boolean]
    #
    # @example
    #   cell.checked? # => true
    def checked?
      return false unless checkbox?

      cell_data.effective_value&.bool_value == true
    end

    # The cell's evaluated value (after formulas), or nil if empty.
    # Returns a String, Numeric, Boolean, or nil depending on the cell.
    #
    # @return [String, Numeric, Boolean, nil]
    #
    # @example
    #   cell.value # => 42
    def value
      ev = cell_data&.effective_value
      return nil unless ev

      return ev.string_value  unless ev.string_value.nil?
      return ev.number_value  unless ev.number_value.nil?
      return ev.bool_value    unless ev.bool_value.nil?

      ev.formula_value
    end

    # The cell's display string as Sheets would render it (respects
    # number/date formatting). May be nil for empty cells.
    #
    # @return [String, nil]
    #
    # @example
    #   # underlying number 1234.5 with currency format
    #   cell.formatted_value # => "$1,234.50"
    def formatted_value
      cell_data&.formatted_value
    end

    private

    # @return [Google::Apis::SheetsV4::CellFormat, nil]
    def effective_format
      cell_data&.effective_format
    end

    # Convert a Sheets `Color` (red/green/blue floats in `[0.0, 1.0]`)
    # to a `"#rrggbb"` hex string.
    #
    # @param color [Google::Apis::SheetsV4::Color]
    # @return [String]
    def rgb_to_hex(color)
      r = ((color.red   || 0.0) * 255).round
      g = ((color.green || 0.0) * 255).round
      b = ((color.blue  || 0.0) * 255).round
      format('#%02x%02x%02x', r, g, b)
    end
  end
end
