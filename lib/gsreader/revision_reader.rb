# frozen_string_literal: true

module GsReader
  # Answers the question: **"When was this checkbox last checked?"**
  #
  # The Google Sheets v4 API exposes *no* per-cell edit timestamp — only
  # the UI's "Show edit history" knows that, and there's a long-standing
  # open feature request for an API
  # (https://issuetracker.google.com/issues/144151809).
  #
  # So instead of polling, this reads the file's **Drive revision
  # history**: `revisions.list` gives a timestamp per saved revision, and
  # the Sheets `export` endpoint can render *any past revision* of a
  # single cell to CSV. A checkbox exports as the literal text `TRUE` /
  # `FALSE`, so we can reconstruct the cell's checked-state over time and
  # find exactly when it flipped on.
  #
  # ## Important caveats
  #
  # * Drive **merges/prunes** revisions — it is NOT a keystroke-level log.
  #   The returned timestamp is the revision in which the box became
  #   checked, which is as precise as Drive's own version history.
  # * Requires the **Drive API** to be enabled on your Google Cloud
  #   project and the read scope below to be granted to the service
  #   account / credentials.
  # * One CSV export per revision: O(revisions) HTTP calls. Fine for the
  #   typical "tens of revisions" sheet; pass `since:` to bound the work.
  #
  # @example
  #   rr = GsReader::RevisionReader.new(spreadsheet_id, creds, gid: 0)
  #   rr.last_checked_at("B2")
  #   # => #<Time 2026-06-10 ...>  (when B2 last went unchecked -> checked)
  #   rr.last_checked_at("B2") # => nil if it was never checked in history
  class RevisionReader < Sheet
    # Read scope covering both the spreadsheet export and Drive metadata.
    HISTORY_SCOPE = [
      'https://www.googleapis.com/auth/drive.readonly'
    ].freeze

    # @param spreadsheet_id [String] the ID from the sheet URL
    # @param credentials [String, Hash, Object] see {GsReader.build_credentials}
    # @param transport [GsReader::HttpTransport, nil] injectable HTTP
    #   layer (tests pass a fake); built from credentials if omitted
    # @param opts [Hash] forwarded to {GsReader::Sheet#initialize}
    #   (notably `gid:` / `sheet:`)
    def initialize(spreadsheet_id, credentials, transport: nil, **opts)
      super(spreadsheet_id, credentials, scope: HISTORY_SCOPE, **opts)
      @transport = transport ||
                   HttpTransport.new(GsReader.build_credentials(credentials, scope: HISTORY_SCOPE))
    end

    # The full checked/unchecked history of a single checkbox cell.
    #
    # @param range [String] a single-cell A1 reference, e.g. `"B2"` or
    #   `"Sheet2!B2"`
    # @param since [Time, nil] ignore revisions strictly older than this
    # @return [Array<Hash>] chronological `{ at: Time, checked: Boolean }`
    #   entries, one per inspected revision
    #
    # @example
    #   rr.history("B2")
    #   # => [{ at: t0, checked: false }, { at: t1, checked: true }, ...]
    def history(range, since: nil)
      raise ArgumentError, "#{range.inspect} is not a single cell" unless single_cell?(range)

      bare = bare_range(range)
      gid = revision_gid(range)

      revisions_after(since).map do |rev|
        csv = @transport.export_csv(spreadsheet_id, gid: gid, range: bare, revision: rev[:id])
        { at: parse_time(rev[:modified_time]), checked: csv_checked?(csv) }
      end
    end

    # When did this checkbox most recently transition from unchecked to
    # checked?
    #
    # Returns the timestamp of the earliest revision in the current
    # contiguous "checked" streak (i.e. the moment it last became
    # checked and stayed that way through the latest revision).
    #
    # `nil` means exactly one thing: **the box is not currently
    # checked** (or there is no history at all). A non-`nil` result is
    # therefore a reliable "it's checked" signal. See {#last_checked}
    # if you also need to know whether the timestamp is exact or just a
    # lower bound (the box may have been checked before the oldest
    # revision Drive still keeps).
    #
    # @param range [String] single-cell A1 reference
    # @param since [Time, nil] only consider revisions at/after this time
    # @return [Time, nil]
    #
    # @example
    #   rr.last_checked_at("B2") # => 2026-06-10 14:03:00 UTC, or nil
    def last_checked_at(range, since: nil)
      last_checked(range, since: since)&.fetch(:at)
    end

    # Like {#last_checked_at}, but returns a hash that also tells you how
    # much to trust the timestamp:
    #
    #   { at: Time, exact: true }   # we saw the unchecked -> checked flip
    #   { at: Time, exact: false }  # checked since the oldest revision we
    #                               # have; the real flip may be earlier
    #   nil                         # not currently checked / no history
    #
    # `exact: false` happens when the box is already checked in the
    # earliest revision Drive still keeps (Drive merges/prunes old
    # revisions), so the returned `at` is a *lower bound* ("checked at or
    # before this") rather than the precise moment.
    #
    # @param range [String] single-cell A1 reference
    # @param since [Time, nil] only consider revisions at/after this time
    # @return [Hash{Symbol => Object, nil}] `{ at: Time, exact: Boolean }`
    #
    # @example
    #   rr.last_checked("B2") # => { at: 2026-06-10 ..., exact: true }
    def last_checked(range, since: nil)
      timeline = history(range, since: since)
      return nil if timeline.empty?
      return nil unless timeline.last[:checked]

      last_unchecked = timeline.rindex { |e| !e[:checked] }
      first_checked_index = last_unchecked.nil? ? 0 : last_unchecked + 1
      { at: timeline[first_checked_index][:at], exact: !last_unchecked.nil? }
    end

    # Is the checkbox checked in the latest revision?
    #
    # @param range [String] single-cell A1 reference
    # @return [Boolean]
    def currently_checked?(range)
      timeline = history(range)
      !timeline.empty? && timeline.last[:checked]
    end

    private

    # Revisions (oldest first), optionally filtered to those at/after
    # `since`.
    #
    # @param since [Time, nil]
    # @return [Array<Hash>]
    def revisions_after(since)
      revs = @transport.list_revisions(spreadsheet_id)
      return revs unless since

      revs.select { |r| parse_time(r[:modified_time]) >= since }
    end

    # The `gid` to export. Prefer an explicit `Sheet!` prefix resolved to
    # a sheetId; otherwise fall back to the configured default gid, or 0.
    #
    # @param range [String]
    # @return [Integer]
    def revision_gid(range)
      r = range.to_s
      if r.include?('!')
        gid_for_title(r.split('!').first.delete("'"))
      else
        Integer(@default_gid || 0)
      end
    end

    # Resolve a tab title to its numeric sheetId.
    #
    # @param title [String]
    # @return [Integer]
    # @raise [ArgumentError] if no tab has that title
    def gid_for_title(title)
      match = spreadsheet.sheets.find { |s| s.properties.title == title }
      raise ArgumentError, "no sheet titled #{title.inspect}" unless match

      match.properties.sheet_id
    end

    # Strip any `Sheet!` qualifier, leaving the bare A1 ref the export
    # endpoint wants (it scopes by `gid` separately).
    #
    # @param range [String]
    # @return [String]
    def bare_range(range)
      range.to_s.split('!').last
    end

    # Does a one-cell CSV body represent a checked checkbox? Sheets
    # exports a checked box as `TRUE` (case-insensitive).
    #
    # @param csv [String]
    # @return [Boolean]
    def csv_checked?(csv)
      row = CSV.parse(csv.to_s).find { |r| r && !r.empty? }
      cell = row&.first
      cell.to_s.strip.casecmp('true').zero?
    end

    # Parse an RFC3339 timestamp from the Drive API into a Time.
    #
    # @param str [String, nil]
    # @return [Time, nil]
    def parse_time(str)
      str && Time.parse(str)
    end
  end
end
