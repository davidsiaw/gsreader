# frozen_string_literal: true

require 'googleauth'

RSpec.describe GsReader do
  it 'has a version number' do
    expect(GsReader::VERSION).not_to be_nil
  end

  it 'defines Reader class' do
    expect(GsReader::Reader).to be < GsReader::Sheet
  end

  it 'defines Writer class' do
    expect(GsReader::Writer).to be < GsReader::Sheet
  end

  it 'defines FormatReader class' do
    expect(GsReader::FormatReader).to be < GsReader::Sheet
  end

  describe '.build_credentials' do
    it 'returns passthrough for credentials objects' do
      credentials_obj = instance_double(Google::Auth::UserRefreshCredentials,
                                        fetch_access_token!: { 'access_token' => 't' })
      expect(described_class.build_credentials(credentials_obj, scope: GsReader::READ_SCOPE)).to eq(credentials_obj)
    end

    it 'raises on an unsupported credentials type' do
      expect { described_class.build_credentials(123, scope: GsReader::READ_SCOPE) }.to raise_error(GsReader::CredentialError)
    end

    it 'raises on a bad credentials path' do
      expect { described_class.build_credentials('/no/such/file.json', scope: GsReader::READ_SCOPE) }.to raise_error(GsReader::CredentialError)
    end
  end

  describe 'API methods' do
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
      allow(described_class).to receive(:build_credentials).and_return(credentials)
    end

    it 'has get_range method' do
      allow(service).to receive(:get_spreadsheet_values).and_return(
        Google::Apis::SheetsV4::ValueRange.new(values: [%w[a b]])
      )
      reader = GsReader::Reader.new('test_spreadsheet_id', credentials, service: service)
      expect(reader.get_range('A1:B1')).to be_a(Google::Apis::SheetsV4::ValueRange)
    end

    it 'has spreadsheet method' do
      allow(service).to receive(:get_spreadsheet).and_return(
        Google::Apis::SheetsV4::Spreadsheet.new(
          properties: Google::Apis::SheetsV4::SpreadsheetProperties.new(title: 'Test Sheet')
        )
      )
      reader = GsReader::Reader.new('test_spreadsheet_id', credentials, service: service)
      expect(reader.spreadsheet).to be_a(Google::Apis::SheetsV4::Spreadsheet)
    end

    it 'has sheet_titles method' do
      allow(service).to receive(:get_spreadsheet).and_return(
        Google::Apis::SheetsV4::Spreadsheet.new(
          sheets: [
            Google::Apis::SheetsV4::Sheet.new(
              properties: Google::Apis::SheetsV4::SheetProperties.new(title: 'Sheet1')
            )
          ]
        )
      )
      reader = GsReader::Reader.new('test_spreadsheet_id', credentials, service: service)
      expect(reader.sheet_titles).to eq(%w[Sheet1])
    end
  end
end
