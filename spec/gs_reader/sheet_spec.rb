# frozen_string_literal: true

require 'google/apis/sheets_v4'

RSpec.describe GsReader::Sheet do
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

  before do
    allow(GsReader).to receive(:build_credentials).and_return(credentials)
  end

  it 'returns a ValueRange from get_range' do
    allow(service).to receive(:get_spreadsheet_values).and_return(
      Google::Apis::SheetsV4::ValueRange.new(values: [%w[a b], %w[c d]])
    )
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.get_range('A1:B2')).to be_a(Google::Apis::SheetsV4::ValueRange)
  end

  it 'returns the correct values from get_range' do
    allow(service).to receive(:get_spreadsheet_values).and_return(
      Google::Apis::SheetsV4::ValueRange.new(values: [%w[a b], %w[c d]])
    )
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.get_range('A1:B2').values).to eq([%w[a b], %w[c d]])
  end

  it 'returns spreadsheet metadata' do
    allow(service).to receive(:get_spreadsheet).and_return(
      Google::Apis::SheetsV4::Spreadsheet.new(
        properties: Google::Apis::SheetsV4::SpreadsheetProperties.new(title: 'Test Sheet')
      )
    )
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.spreadsheet.properties.title).to eq('Test Sheet')
  end

  it 'sheet_titles returns an array' do
    allow(service).to receive(:get_spreadsheet).and_return(
      Google::Apis::SheetsV4::Spreadsheet.new(
        sheets: [
          Google::Apis::SheetsV4::Sheet.new(
            properties: Google::Apis::SheetsV4::SheetProperties.new(title: 'Sheet1')
          ),
          Google::Apis::SheetsV4::Sheet.new(
            properties: Google::Apis::SheetsV4::SheetProperties.new(title: 'Sheet2')
          )
        ]
      )
    )
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.sheet_titles).to be_an(Array)
  end

  it 'sheet_titles returns the correct titles' do
    allow(service).to receive(:get_spreadsheet).and_return(
      Google::Apis::SheetsV4::Spreadsheet.new(
        sheets: [
          Google::Apis::SheetsV4::Sheet.new(
            properties: Google::Apis::SheetsV4::SheetProperties.new(title: 'Sheet1')
          ),
          Google::Apis::SheetsV4::Sheet.new(
            properties: Google::Apis::SheetsV4::SheetProperties.new(title: 'Sheet2')
          )
        ]
      )
    )
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.sheet_titles).to eq(%w[Sheet1 Sheet2])
  end

  it 'recognizes A1 as a single cell' do
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.send(:single_cell?, 'A1')).to be true
  end

  it 'recognizes Sheet1!A1 as a single cell' do
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.send(:single_cell?, 'Sheet1!A1')).to be true
  end

  it 'recognizes A1:B2 as multi-cell' do
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.send(:single_cell?, 'A1:B2')).to be false
  end

  it 'recognizes Sheet1!A1:B2 as multi-cell' do
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.send(:single_cell?, 'Sheet1!A1:B2')).to be false
  end

  it 'adds default sheet title in qualify_range' do
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, sheet: 'Sheet1',
                                service: service)
    expect(sheet.send(:qualify_range, 'A1')).to eq("'Sheet1'!A1")
  end

  it 'preserves existing sheet qualifier in qualify_range' do
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.send(:qualify_range, 'Sheet1!A1')).to eq('Sheet1!A1')
  end

  it 'wraps titles with spaces in quote_sheet_title' do
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.send(:quote_sheet_title, 'Sheet with spaces')).to eq("'Sheet with spaces'")
  end

  it 'doubles single quotes in quote_sheet_title' do
    sheet = described_class.new('test_spreadsheet_id', credentials,
                                scope: GsReader::READ_SCOPE, service: service)
    expect(sheet.send(:quote_sheet_title, "Sheet's title")).to eq("'Sheet''s title'")
  end
end
