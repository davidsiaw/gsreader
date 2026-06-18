# GsReader

> # ⚠️🚧 VIBE-CODED GEM 🚧⚠️
>
> ## 🚨 🤖 🎶 🧘 🌌 🤖 🚨
>
> **This gem was vibe-coded.** An LLM wrote most of it while the human
> mostly nodded along to the rhythm. It has tests and it works on the
> author's machine, but:
>
> - ⚠️ No production hardening, no rate-limit handling, no retries.
> - ⚠️ Edge cases around merged cells, unbounded ranges, exotic
>   color spaces, theme colors, etc. are best-effort at best.
> - ⚠️ The API surface may change on a whim if the vibes shift.
> - ⚠️ Read the source before trusting it with anything important.
>
> Use at your own risk. PRs welcome from humans, robots, and entities
> in between.
>
> ## 🚨 🤖 🎶 🧘 🌌 🤖 🚨

Tiny convenience wrappers around the Google Sheets v4 API. Treat a
spreadsheet like a Hash keyed by A1 notation.

```ruby
require 'gsreader'

reader = GsReader::Reader.new("1abc...XYZ", "service_account.json")
reader["A1"]              # => "Hello"
reader["A1:B3"]           # => [["a", "b"], ["c", "d"], ["e", "f"]]
reader["Sheet2!A1:A10"]   # => values from a specific tab
reader.last_checked_at("B2") # => Time the checkbox last became checked (nil iff unchecked)

writer = GsReader::Writer.new("1abc...XYZ", "service_account.json")
writer["A1"]    = "hello"
writer["A1:B2"] = [["a", "b"], ["c", "d"]]
writer.append("Sheet1!A:B", [["x", "y"], ["z", "w"]])
writer.clear("A1:B2")

fr = GsReader::FormatReader.new("1abc...XYZ", "service_account.json")
fr["A1"].background_color   # => "#ff0000" (or nil if no fill)
fr["A1"].checked?           # => true if it's a checked checkbox
fr["A1"].value              # => the cell's value (string / number / bool / nil)
fr["A1:B2"].map { |row| row.map(&:background_color) }

rr = GsReader::RevisionReader.new("1abc...XYZ", "service_account.json", gid: 0)
rr.last_checked_at("B2")    # => Time the box last became checked (nil iff unchecked)
rr.last_checked("B2")       # => { at: Time, exact: true } (exact: false = lower bound)
rr.currently_checked?("B2") # => true
rr.history("B2")            # => [{ at: Time, checked: false }, { at: Time, checked: true }]
```

## Installation

This gem was vibe coded so it has intentionally not been pushed to RubyGems. Rather, the recommended installation procedure is to vendor it into your project. Did I mention this was vibe coded?

```
git submodule add https://github.com/davidsiaw/gsreader
```

And then use it via a direct path to it:

```ruby
gem "gsreader", path: "gsreader" # yes the relative path works.
```

## Reference Docs

Available at https://davidsiaw.github.io/gsreader

## Getting credentials to read/write a Google Sheet

The simplest, most reliable way to use this gem is with a **Google Cloud
service account**. A service account is a robot user that owns its own
email address (e.g. `my-bot@my-project.iam.gserviceaccount.com`); you
share the sheet with that email just like you'd share it with a
colleague, and the bot inherits the same permissions.

### 1. Create (or pick) a Google Cloud project

1. Go to <https://console.cloud.google.com/>.
2. Click the project dropdown in the top bar → **New Project** (or pick
   an existing one).
3. Give it any name, e.g. `gsreader-sandbox`. Click **Create**.
4. Make sure that project is selected in the top-bar dropdown for the
   rest of the steps.

### 2. Enable the Google Sheets API

1. Open <https://console.cloud.google.com/apis/library/sheets.googleapis.com>.
2. Confirm the right project is selected at the top.
3. Click **Enable**.

(If you also want to look up sheets by name or list files, enable the
Google Drive API too: <https://console.cloud.google.com/apis/library/drive.googleapis.com>.
This gem itself only needs the Sheets API.)

### 3. Create a service account

1. Go to <https://console.cloud.google.com/iam-admin/serviceaccounts>.
2. Click **Create service account**.
3. **Name**: anything, e.g. `gsreader-bot`. The **service account ID**
   field will autofill — that becomes the email address.
4. Click **Create and continue**.
5. The "Grant this service account access to project" step is
   **optional** for this gem — you can skip it. (Sheet-level sharing,
   set in step 5, is what controls access.)
6. Click **Done**.

### 4. Create a JSON key for the service account

1. From the service-accounts list, click the account you just made.
2. Open the **Keys** tab → **Add key** → **Create new key**.
3. Choose **JSON** → **Create**. A `*.json` file will download.
4. Treat this file like a password. **Don't commit it to git.** Add it
   to `.gitignore`, store it in a secret manager, or load it from an
   environment variable in production.

The downloaded file looks like:

```json
{
  "type": "service_account",
  "project_id": "...",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "gsreader-bot@my-project.iam.gserviceaccount.com",
  "client_id": "...",
  ...
}
```

Note the `client_email` value — that's the email you'll share the sheet
with in the next step.

### 5. Share the spreadsheet with the service account

1. Open the Google Sheet in your browser.
2. Click **Share** in the top right.
3. Paste the service account's `client_email`
   (e.g. `gsreader-bot@my-project.iam.gserviceaccount.com`).
4. Pick a role:
   - **Viewer** is enough for `GsReader::Reader`.
   - **Editor** is required for `GsReader::Writer`.
5. Untick "Notify people" (the bot has no inbox) and click **Share**.

### 6. Find the spreadsheet ID

The ID is the long random-looking segment in the URL between `/d/` and
the next `/`:

```
https://docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789/edit#gid=0
                                       └────────────── this is the ID ─────────────┘
```

### 7. Use it

```ruby
require 'gsreader'

SPREADSHEET_ID = '1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789'

reader = GsReader::Reader.new(SPREADSHEET_ID, 'path/to/service_account.json')
puts reader["A1"]
```

You can pass credentials in a few different shapes:

```ruby
# 1. A path to the JSON key file
GsReader::Reader.new(id, 'path/to/key.json')

# 2. The JSON key contents as a String (handy with ENV vars)
GsReader::Reader.new(id, ENV.fetch('GOOGLE_SERVICE_ACCOUNT_JSON'))

# 3. The JSON key parsed into a Hash
creds = JSON.parse(ENV.fetch('GOOGLE_SERVICE_ACCOUNT_JSON'))
GsReader::Reader.new(id, creds)

# 4. A pre-built Google::Auth credentials object
require 'googleauth'
auth = Google::Auth.get_application_default(GsReader::READ_SCOPE)
GsReader::Reader.new(id, auth)
```

### Troubleshooting

- **`Google::Apis::ClientError: forbidden`** — you forgot to share the
  sheet with the service account's email, or the role is too low
  (Viewer can't write).
- **`Google::Apis::ClientError: ... Google Sheets API has not been used
  in project ... before or it is disabled`** — re-do step 2.
- **`unsupported credentials type` / `credentials string is neither
  JSON nor an existing file path`** — the value you passed isn't a
  JSON string, a Hash, a credentials object, or a real path on disk.

## API

### `GsReader::Reader.new(spreadsheet_id, credentials)`

Read-only client. Uses the
`https://www.googleapis.com/auth/spreadsheets.readonly` scope.

- `reader[range]` → for a single-cell range (`"A1"`, `"Sheet2!C3"`)
  returns the scalar value or `nil`. For a multi-cell range
  (`"A1:B3"`) returns a 2D array (rows × columns).
- `reader.get_range(range)` → raw `Google::Apis::SheetsV4::ValueRange`.
- `reader.spreadsheet` → spreadsheet metadata.
- `reader.sheet_titles` → array of tab names.
- `reader.last_checked_at(range, since: nil)` → `Time` a checkbox last
  became checked, or `nil` if it isn't currently checked. Convenience
  delegate to {GsReader::RevisionReader}.
- `reader.last_checked(range, since: nil)` → `{ at:, exact: }` (see
  `RevisionReader`).
- `reader.checkbox_history(range, since: nil)` → chronological
  `{ at:, checked: }` entries.
- `reader.revision_reader` → the memoized {GsReader::RevisionReader}
  backing the three methods above.

  **Heads up:** these revision methods need the broader **Drive** read
  scope (`drive.readonly`), not the spreadsheets-only scope `Reader`
  itself uses. The delegate requests it from your credentials on first
  use, so the Drive API must be enabled and granted.

### `GsReader::Writer.new(spreadsheet_id, credentials, value_input_option: 'USER_ENTERED')`

Read/write client. Uses the
`https://www.googleapis.com/auth/spreadsheets` scope, so it can also
read.

- `writer[range] = value` — writes a scalar, a 1D array (single row),
  or a 2D array (rows × columns).
- `writer.append(range, rows)` — appends rows after the last row of
  the table found in `range`.
- `writer.clear(range)` — clears values (keeps formatting).
- `value_input_option` defaults to `'USER_ENTERED'` (formulas and
  dates are interpreted). Pass `'RAW'` to store strings verbatim.

### `GsReader::FormatReader.new(spreadsheet_id, credentials)`

Read-only client that exposes per-cell *formatting*. Indexing returns
a single {`GsReader::Cell`} for an `"A1"`-style range and a 2D array
of `Cell`s for a multi-cell range. Uses the same read-only scope as
`Reader`.

`GsReader::Cell` exposes:

- `cell.background_color` → `"#rrggbb"` hex string, or `nil` if the
  cell has no fill set. Plain white shows up as `"#ffffff"` — compare
  to that yourself if you want to treat it as "no background".
- `cell.checkbox?` → `true` if the cell has a BOOLEAN data validation
  (i.e. it's a checkbox).
- `cell.checked?` → `true` only if the cell is a checkbox **and** is
  currently checked.
- `cell.value` → evaluated cell value (`String` / `Numeric` /
  `true` / `false` / `nil`).
- `cell.formatted_value` → the display string Sheets would render.
- `cell.cell_data` → the underlying
  `Google::Apis::SheetsV4::CellData` for anything else you need.

### `GsReader::RevisionReader.new(spreadsheet_id, credentials)`

Answers **"when was this checkbox last checked?"** — something the
Sheets v4 API itself can't tell you, because it exposes no per-cell
edit timestamp (there's a long-standing open feature request:
<https://issuetracker.google.com/issues/144151809>).

Instead of polling, it reads the file's **Drive revision history**
(`revisions.list` gives a timestamp per saved revision) and exports
each past revision of the cell to CSV via the Sheets `export`
endpoint. A checkbox exports as the text `TRUE` / `FALSE`, so the
checked-state can be reconstructed over time and the flip located.

- `rr.last_checked_at(range, since: nil)` → `Time` the checkbox most
  recently transitioned from unchecked → checked (start of the current
  checked streak). **`nil` means exactly one thing: the box is not
  currently checked** (so a non-`nil` result is a reliable "it's
  checked" signal).
- `rr.last_checked(range, since: nil)` → `{ at: Time, exact: Boolean }`
  or `nil`. `exact: false` means the box was already checked in the
  oldest revision Drive still keeps, so `at` is a *lower bound*
  ("checked at or before this") rather than the precise flip — Drive
  merges/prunes old revisions, so the true moment may be earlier.
- `rr.currently_checked?(range)` → `true` if checked in the latest
  revision.
- `rr.history(range, since: nil)` → chronological array of
  `{ at: Time, checked: Boolean }`, one entry per inspected revision.
- `range` must be a **single cell** (`"B2"` or `"Sheet2!B2"`).
- Pass `gid:` (the `gid=` from the sheet URL) or `sheet:` to pick the
  tab; bare ranges default to `gid: 0`.

Uses the `https://www.googleapis.com/auth/drive.readonly` scope, so the
**Google Drive API must be enabled** on your Cloud project and the
sheet shared with the credentials.

**Caveats:** Drive *merges/prunes* revisions — this is not a
keystroke-level log, so the timestamp is as precise as the file's
version history. It makes one CSV export per revision (O(revisions)
HTTP calls); bound the work with `since:`.

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then `rake spec` to run the tests. `bin/console` opens an IRB session
with the gem loaded.

To install onto your local machine: `bundle exec rake install`. To
release a new version: bump `lib/gsreader/version.rb`, then
`bundle exec rake release`.

## Contributing

Bug reports and pull requests are welcome at
<https://github.com/davidsiaw/gsreader>.

## License

MIT — see [LICENSE.txt](LICENSE.txt).
