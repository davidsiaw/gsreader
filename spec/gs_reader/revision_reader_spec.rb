# frozen_string_literal: true

require 'google/apis/sheets_v4'

RSpec.describe GsReader::RevisionReader do
  let(:credentials) do
    { 'type' => 'service_account', 'client_email' => 'test@example.com' }
  end
  let(:client_options) { double(application_name: nil) }
  let(:service) do
    allow(client_options).to receive(:application_name=)
    d = double(client_options: client_options)
    allow(d).to receive(:authorization=)
    d
  end
  let(:transport) { instance_double(GsReader::HttpTransport) }

  before do
    allow(GsReader).to receive(:build_credentials).and_return(credentials)
  end

  def build(**opts)
    described_class.new('sheet_id', credentials, service: service, transport: transport, **opts)
  end

  # Three revisions: unchecked -> checked -> still checked.
  def stub_basic_history
    allow(transport).to receive(:list_revisions).with('sheet_id').and_return(
      [
        { id: '1', modified_time: '2026-06-01T10:00:00Z' },
        { id: '2', modified_time: '2026-06-05T12:30:00Z' },
        { id: '3', modified_time: '2026-06-08T09:00:00Z' }
      ]
    )
    allow(transport).to receive(:export_csv)
      .with('sheet_id', gid: 0, range: 'B2', revision: '1').and_return("FALSE\n")
    allow(transport).to receive(:export_csv)
      .with('sheet_id', gid: 0, range: 'B2', revision: '2').and_return("TRUE\n")
    allow(transport).to receive(:export_csv)
      .with('sheet_id', gid: 0, range: 'B2', revision: '3').and_return("TRUE\n")
  end

  describe '#history' do
    it 'returns a chronological checked/unchecked timeline' do
      stub_basic_history
      timeline = build.history('B2')
      expect(timeline.map { |e| e[:checked] }).to eq([false, true, true])
    end

    it 'parses revision timestamps into Time objects' do
      stub_basic_history
      timeline = build.history('B2')
      expect(timeline.first[:at]).to eq(Time.parse('2026-06-01T10:00:00Z'))
    end

    it 'rejects multi-cell ranges' do
      expect { build.history('A1:B2') }.to raise_error(ArgumentError, /single cell/)
    end

    it 'filters by the since: option' do
      stub_basic_history
      timeline = build.history('B2', since: Time.parse('2026-06-05T00:00:00Z'))
      expect(timeline.length).to eq(2)
    end
  end

  describe '#last_checked_at' do
    it 'returns when the box last transitioned to checked' do
      stub_basic_history
      expect(build.last_checked_at('B2')).to eq(Time.parse('2026-06-05T12:30:00Z'))
    end

    it 'returns nil when never checked' do
      allow(transport).to receive_messages(list_revisions: [{ id: '1', modified_time: '2026-06-01T10:00:00Z' }],
                                           export_csv: "FALSE\n")
      expect(build.last_checked_at('B2')).to be_nil
    end

    it 'returns nil when currently unchecked even if checked in the past' do
      allow(transport).to receive(:list_revisions).and_return(
        [
          { id: '1', modified_time: '2026-06-01T10:00:00Z' },
          { id: '2', modified_time: '2026-06-05T12:30:00Z' }
        ]
      )
      allow(transport).to receive(:export_csv)
        .with('sheet_id', gid: 0, range: 'B2', revision: '1').and_return("TRUE\n")
      allow(transport).to receive(:export_csv)
        .with('sheet_id', gid: 0, range: 'B2', revision: '2').and_return("FALSE\n")
      expect(build.last_checked_at('B2')).to be_nil
    end

    it 'uses the start of the current checked streak after a re-check' do
      allow(transport).to receive(:list_revisions).and_return(
        [
          { id: '1', modified_time: '2026-06-01T10:00:00Z' },
          { id: '2', modified_time: '2026-06-02T10:00:00Z' },
          { id: '3', modified_time: '2026-06-03T10:00:00Z' },
          { id: '4', modified_time: '2026-06-04T10:00:00Z' }
        ]
      )
      # checked, unchecked, checked, checked -> streak starts at rev 3
      %w[TRUE FALSE TRUE TRUE].each_with_index do |val, i|
        allow(transport).to receive(:export_csv)
          .with('sheet_id', gid: 0, range: 'B2', revision: (i + 1).to_s)
          .and_return("#{val}\n")
      end
      expect(build.last_checked_at('B2')).to eq(Time.parse('2026-06-03T10:00:00Z'))
    end

    it 'handles a box checked since the very first revision' do
      allow(transport).to receive_messages(list_revisions: [
                                             { id: '1', modified_time: '2026-06-01T10:00:00Z' },
                                             { id: '2', modified_time: '2026-06-02T10:00:00Z' }
                                           ], export_csv: "TRUE\n")
      expect(build.last_checked_at('B2')).to eq(Time.parse('2026-06-01T10:00:00Z'))
    end

    it 'returns nil when there are no revisions' do
      allow(transport).to receive(:list_revisions).and_return([])
      expect(build.last_checked_at('B2')).to be_nil
    end

    it 'is non-nil whenever the box is currently checked' do
      stub_basic_history
      reader = build
      expect(reader.last_checked_at('B2')).not_to be_nil
      expect(reader.currently_checked?('B2')).to be true
    end
  end

  describe '#last_checked' do
    it 'marks the timestamp exact when the flip was observed' do
      stub_basic_history
      expect(build.last_checked('B2')).to eq(
        at: Time.parse('2026-06-05T12:30:00Z'), exact: true
      )
    end

    it 'marks the timestamp as a lower bound when checked since the oldest revision' do
      allow(transport).to receive_messages(list_revisions: [
                                             { id: '1', modified_time: '2026-06-01T10:00:00Z' },
                                             { id: '2', modified_time: '2026-06-02T10:00:00Z' }
                                           ], export_csv: "TRUE\n")
      expect(build.last_checked('B2')).to eq(
        at: Time.parse('2026-06-01T10:00:00Z'), exact: false
      )
    end

    it 'returns nil when not currently checked' do
      allow(transport).to receive_messages(list_revisions: [{ id: '1', modified_time: '2026-06-01T10:00:00Z' }],
                                           export_csv: "FALSE\n")
      expect(build.last_checked('B2')).to be_nil
    end
  end

  describe '#currently_checked?' do
    it 'is true when the latest revision is checked' do
      stub_basic_history
      expect(build.currently_checked?('B2')).to be true
    end

    it 'is false with no history' do
      allow(transport).to receive(:list_revisions).and_return([])
      expect(build.currently_checked?('B2')).to be false
    end
  end

  describe 'sheet resolution' do
    it 'defaults to gid 0 for a bare range' do
      allow(transport).to receive_messages(list_revisions: [{ id: '1', modified_time: '2026-06-01T10:00:00Z' }],
                                           export_csv: "TRUE\n")
      build.history('B2')
      expect(transport).to have_received(:export_csv)
        .with('sheet_id', gid: 0, range: 'B2', revision: '1')
    end

    it 'uses a configured default gid' do
      allow(transport).to receive_messages(list_revisions: [{ id: '1', modified_time: '2026-06-01T10:00:00Z' }],
                                           export_csv: "TRUE\n")
      build(gid: 42).history('B2')
      expect(transport).to have_received(:export_csv)
        .with('sheet_id', gid: 42, range: 'B2', revision: '1')
    end

    it 'resolves a Sheet! prefix to its sheetId' do
      allow(service).to receive(:get_spreadsheet).and_return(
        Google::Apis::SheetsV4::Spreadsheet.new(
          sheets: [
            Google::Apis::SheetsV4::Sheet.new(
              properties: Google::Apis::SheetsV4::SheetProperties.new(title: 'Tasks', sheet_id: 777)
            )
          ]
        )
      )
      allow(transport).to receive_messages(list_revisions: [{ id: '1', modified_time: '2026-06-01T10:00:00Z' }],
                                           export_csv: "TRUE\n")
      build.history('Tasks!B2')
      expect(transport).to have_received(:export_csv)
        .with('sheet_id', gid: 777, range: 'B2', revision: '1')
    end
  end
end
