# frozen_string_literal: true

RSpec.describe GsReader::Writer do
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

  describe '#initialize' do
    let(:writer) { described_class.new(spreadsheet_id, credentials, service: service) }

    it 'uses default value_input_option' do
      expect(writer.value_input_option).to eq('USER_ENTERED')
    end

    it 'allows custom value_input_option' do
      writer = described_class.new(spreadsheet_id, credentials, value_input_option: 'RAW', service: service)
      expect(writer.value_input_option).to eq('RAW')
    end
  end

  describe '#[]=' do
    let(:writer) { described_class.new(spreadsheet_id, credentials, service: service) }

    before do
      allow(service).to receive(:update_spreadsheet_value)
    end

    it 'writes scalar values' do
      writer['A1'] = 'hello'
      expect(service).to have_received(:update_spreadsheet_value).with(
        spreadsheet_id, 'A1', an_instance_of(S::ValueRange), value_input_option: 'USER_ENTERED'
      )
    end

    it 'writes 2D arrays' do
      writer['A1:B2'] = [%w[a b], %w[c d]]
      expect(service).to have_received(:update_spreadsheet_value).with(
        spreadsheet_id, 'A1:B2', an_instance_of(S::ValueRange), value_input_option: 'USER_ENTERED'
      )
    end

    it 'writes 1D arrays' do
      writer['A1:C1'] = %w[a b c]
      expect(service).to have_received(:update_spreadsheet_value).with(
        spreadsheet_id, 'A1:C1', an_instance_of(S::ValueRange), value_input_option: 'USER_ENTERED'
      )
    end
  end

  describe '#append' do
    let(:writer) { described_class.new(spreadsheet_id, credentials, service: service) }

    before do
      allow(service).to receive(:append_spreadsheet_value)
    end

    it 'appends rows' do
      writer.append('Sheet1!A:B', [%w[x y], %w[z w]])
      expect(service).to have_received(:append_spreadsheet_value).with(
        spreadsheet_id, 'Sheet1!A:B', an_instance_of(S::ValueRange), value_input_option: 'USER_ENTERED'
      )
    end
  end

  describe '#clear' do
    let(:writer) { described_class.new(spreadsheet_id, credentials, service: service) }

    before do
      allow(service).to receive(:clear_values)
    end

    it 'clears a range' do
      writer.clear('A1:B2')
      expect(service).to have_received(:clear_values).with(
        spreadsheet_id, 'A1:B2', an_instance_of(S::ClearValuesRequest)
      )
    end
  end

  describe '#normalize_values' do
    let(:writer) { described_class.new(spreadsheet_id, credentials, service: service) }

    it 'handles scalar values' do
      expect(writer.send(:normalize_values, 'hello')).to eq([['hello']])
    end

    it 'handles 1D arrays' do
      expect(writer.send(:normalize_values, %w[a b c])).to eq([%w[a b c]])
    end

    it 'handles 2D arrays' do
      expect(writer.send(:normalize_values, [%w[a b], %w[c d]])).to eq([%w[a b], %w[c d]])
    end

    it 'handles empty arrays' do
      expect(writer.send(:normalize_values, [])).to eq([[]])
    end
  end

  describe 'edge cases' do
    let(:writer) { described_class.new(spreadsheet_id, credentials, service: service) }

    before do
      allow(service).to receive(:append_spreadsheet_value)
    end

    it 'handles empty values in append' do
      writer.append('Sheet1!A:B', [])
      expect(service).to have_received(:append_spreadsheet_value)
    end
  end
end
