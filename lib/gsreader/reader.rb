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

    # When did this checkbox most recently become checked? Delegates to a
    # {GsReader::RevisionReader} built lazily from the same credentials.
    #
    # Note: reading revision history needs the **Drive** read scope
    # (`drive.readonly`), which is broader than the `Reader`'s
    # spreadsheets-only scope. The delegate requests that wider scope
    # from your credentials on first use, so the Drive API must be
    # enabled and granted. See {GsReader::RevisionReader#last_checked_at}.
    #
    # @param range [String] single-cell A1 reference
    # @param since [Time, nil] only consider revisions at/after this time
    # @return [Time, nil] `nil` iff the box is not currently checked
    #
    # @example
    #   reader.last_checked_at("B2") # => 2026-06-10 14:03:00 UTC, or nil
    def last_checked_at(range, since: nil)
      revision_reader.last_checked_at(range, since: since)
    end

    # Like {#last_checked_at} but also reports whether the timestamp is
    # exact. See {GsReader::RevisionReader#last_checked}.
    #
    # @param range [String] single-cell A1 reference
    # @param since [Time, nil] only consider revisions at/after this time
    # @return [Hash{Symbol => Object, nil}] `{ at: Time, exact: Boolean }`
    def last_checked(range, since: nil)
      revision_reader.last_checked(range, since: since)
    end

    # The checked/unchecked history of a single checkbox cell. See
    # {GsReader::RevisionReader#history}.
    #
    # @param range [String] single-cell A1 reference
    # @param since [Time, nil] only consider revisions at/after this time
    # @return [Array<Hash>] `{ at: Time, checked: Boolean }` entries
    def checkbox_history(range, since: nil)
      revision_reader.history(range, since: since)
    end

    # A {GsReader::RevisionReader} sharing this reader's spreadsheet,
    # credentials and default tab. Built once and memoized.
    #
    # @return [GsReader::RevisionReader]
    def revision_reader
      @revision_reader ||= RevisionReader.new(
        spreadsheet_id, @raw_credentials, sheet: @default_sheet, gid: @default_gid
      )
    end
  end
end
