# frozen_string_literal: true

require 'google/apis/sheets_v4'

RSpec.describe GsReader::Sheet do
  let(:spreadsheet_id) { 'test_spreadsheet_id' }
  let(:credentials) { { 'type' => 'service_account', 'client_email' => 'test@example.com' } }
  let(:client_options) { double(application_name: nil) }
  let(:service) do
    allow(client_options).to receive(:application_name=)
    d = double(client_options: client_options)
    allow(d).to receive(:authorization=)
    d
  end

  before do
    allow(GsReader).to receive(:build_credentials).and_return(credentials)
  end

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe '#get_range' do
    let(:expected_range) { Google::Apis::SheetsV4::ValueRange.new(values: [%w[a b], %w[c d]]) }
    let(:sheet) { described_class.new(spreadsheet_id, credentials, scope: GsReader::READ_SCOPE, service: service) }

    before do
      allow(service).to receive(:get_spreadsheet_values).and_return(expected_range)
    end

    it 'returns a ValueRange' do
      expect(sheet.get_range('A1:B2')).to be_a(Google::Apis::SheetsV4::ValueRange)
    end

    it 'returns the correct values' do
      expect(sheet.get_range('A1:B2').values).to eq([%w[a b], %w[c d]])
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe '#spreadsheet' do
    let(:expected_spreadsheet) do
      Google::Apis::SheetsV4::Spreadsheet.new(
        properties: Google::Apis::SheetsV4::SpreadsheetProperties.new(title: 'Test Sheet')
      )
    end
    let(:sheet) { described_class.new(spreadsheet_id, credentials, scope: GsReader::READ_SCOPE, service: service) }

    before do
      allow(service).to receive(:get_spreadsheet).and_return(expected_spreadsheet)
    end

    it 'returns spreadsheet metadata' do
      expect(sheet.spreadsheet.properties.title).to eq('Test Sheet')
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  # rubocop:disable RSpec/MultipleMemoizedHelpers
  describe '#sheet_titles' do
    let(:sheets) do
      [
        Google::Apis::SheetsV4::Sheet.new(
          properties: Google::Apis::SheetsV4::SheetProperties.new(title: 'Sheet1')
        ),
        Google::Apis::SheetsV4::Sheet.new(
          properties: Google::Apis::SheetsV4::SheetProperties.new(title: 'Sheet2')
        )
      ]
    end
    let(:expected_spreadsheet) { Google::Apis::SheetsV4::Spreadsheet.new(sheets: sheets) }
    let(:sheet) { described_class.new(spreadsheet_id, credentials, scope: GsReader::READ_SCOPE, service: service) }

    before do
      allow(service).to receive(:get_spreadsheet).and_return(expected_spreadsheet)
    end

    it 'returns an array' do
      expect(sheet.sheet_titles).to be_an(Array)
    end

    it 'returns the correct titles' do
      expect(sheet.sheet_titles).to eq(%w[Sheet1 Sheet2])
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers

  describe '#single_cell?' do
    let(:sheet) { described_class.new(spreadsheet_id, credentials, scope: GsReader::READ_SCOPE, service: service) }

    it 'recognizes A1' do
      expect(sheet.send(:single_cell?, 'A1')).to be true
    end

    it 'recognizes Sheet1!A1' do
      expect(sheet.send(:single_cell?, 'Sheet1!A1')).to be true
    end

    it 'recognizes A1:B2 as multi-cell' do
      expect(sheet.send(:single_cell?, 'A1:B2')).to be false
    end

    it 'recognizes Sheet1!A1:B2 as multi-cell' do
      expect(sheet.send(:single_cell?, 'Sheet1!A1:B2')).to be false
    end
  end

  describe '#qualify_range' do
    let(:sheet) { described_class.new(spreadsheet_id, credentials, scope: GsReader::READ_SCOPE, service: service) }

    it 'adds default sheet title' do
      sheet = described_class.new(spreadsheet_id, credentials, scope: GsReader::READ_SCOPE,
                                                               sheet: 'Sheet1', service: service)
      expect(sheet.send(:qualify_range, 'A1')).to eq("'Sheet1'!A1")
    end

    it 'preserves existing sheet qualifier' do
      expect(sheet.send(:qualify_range, 'Sheet1!A1')).to eq('Sheet1!A1')
    end
  end

  describe '#quote_sheet_title' do
    let(:sheet) { described_class.new(spreadsheet_id, credentials, scope: GsReader::READ_SCOPE, service: service) }

    it 'wraps titles with spaces' do
      expect(sheet.send(:quote_sheet_title, 'Sheet with spaces')).to eq("'Sheet with spaces'")
    end

    it 'doubles single quotes' do
      expect(sheet.send(:quote_sheet_title, "Sheet's title")).to eq("'Sheet''s title'")
    end
  end
end
