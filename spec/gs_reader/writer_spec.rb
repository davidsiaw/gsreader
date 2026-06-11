# frozen_string_literal: true

RSpec.describe GsReader::Writer do
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

  describe '#initialize' do
    it 'uses default value_input_option' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      expect(writer.value_input_option).to eq('USER_ENTERED')
    end

    it 'allows custom value_input_option' do
      writer = described_class.new('test_spreadsheet_id', credentials,
                                   value_input_option: 'RAW', service: service)
      expect(writer.value_input_option).to eq('RAW')
    end
  end

  describe '#[]=' do
    before do
      allow(service).to receive(:update_spreadsheet_value)
    end

    it 'writes scalar values' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      writer['A1'] = 'hello'
      expect(service).to have_received(:update_spreadsheet_value).with(
        'test_spreadsheet_id', 'A1', an_instance_of(S::ValueRange),
        value_input_option: 'USER_ENTERED'
      )
    end

    it 'writes 2D arrays' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      writer['A1:B2'] = [%w[a b], %w[c d]]
      expect(service).to have_received(:update_spreadsheet_value).with(
        'test_spreadsheet_id', 'A1:B2', an_instance_of(S::ValueRange),
        value_input_option: 'USER_ENTERED'
      )
    end

    it 'writes 1D arrays' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      writer['A1:C1'] = %w[a b c]
      expect(service).to have_received(:update_spreadsheet_value).with(
        'test_spreadsheet_id', 'A1:C1', an_instance_of(S::ValueRange),
        value_input_option: 'USER_ENTERED'
      )
    end
  end

  describe '#append' do
    before do
      allow(service).to receive(:append_spreadsheet_value)
    end

    it 'appends rows' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      writer.append('Sheet1!A:B', [%w[x y], %w[z w]])
      expect(service).to have_received(:append_spreadsheet_value).with(
        'test_spreadsheet_id', 'Sheet1!A:B', an_instance_of(S::ValueRange),
        value_input_option: 'USER_ENTERED'
      )
    end
  end

  describe '#clear' do
    before do
      allow(service).to receive(:clear_values)
    end

    it 'clears a range' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      writer.clear('A1:B2')
      expect(service).to have_received(:clear_values).with(
        'test_spreadsheet_id', 'A1:B2', an_instance_of(S::ClearValuesRequest)
      )
    end
  end

  describe '#normalize_values' do
    it 'handles scalar values' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      expect(writer.send(:normalize_values, 'hello')).to eq([['hello']])
    end

    it 'handles 1D arrays' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      expect(writer.send(:normalize_values, %w[a b c])).to eq([%w[a b c]])
    end

    it 'handles 2D arrays' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      expect(writer.send(:normalize_values, [%w[a b], %w[c d]])).to eq([%w[a b], %w[c d]])
    end

    it 'handles empty arrays' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      expect(writer.send(:normalize_values, [])).to eq([[]])
    end
  end

  describe 'edge cases' do
    before do
      allow(service).to receive(:append_spreadsheet_value)
    end

    it 'handles empty values in append' do
      writer = described_class.new('test_spreadsheet_id', credentials, service: service)
      writer.append('Sheet1!A:B', [])
      expect(service).to have_received(:append_spreadsheet_value)
    end
  end
end
