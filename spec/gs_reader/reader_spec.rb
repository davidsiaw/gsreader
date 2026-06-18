# frozen_string_literal: true

require 'google/apis/sheets_v4'

RSpec.describe GsReader::Reader do
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

  describe 'checkbox revision delegation' do
    let(:delegate) { instance_double(GsReader::RevisionReader) }
    let(:reader) { described_class.new('sheet_id', credentials, gid: 7, service: service) }

    before do
      allow(GsReader::RevisionReader).to receive(:new).and_return(delegate)
    end

    it 'builds a RevisionReader from the same id, credentials and defaults' do
      reader.revision_reader
      expect(GsReader::RevisionReader).to have_received(:new)
        .with('sheet_id', credentials, sheet: nil, gid: 7)
    end

    it 'memoizes the delegate' do
      expect(reader.revision_reader).to be(reader.revision_reader)
      expect(GsReader::RevisionReader).to have_received(:new).once
    end

    it 'delegates last_checked_at' do
      t = Time.now
      allow(delegate).to receive(:last_checked_at).with('B2', since: nil).and_return(t)
      expect(reader.last_checked_at('B2')).to eq(t)
    end

    it 'delegates last_checked with since:' do
      since = Time.now
      allow(delegate).to receive(:last_checked).with('B2', since: since).and_return(at: since, exact: true)
      expect(reader.last_checked('B2', since: since)).to eq(at: since, exact: true)
    end

    it 'delegates checkbox_history to the reader history' do
      allow(delegate).to receive(:history).with('B2', since: nil).and_return([{ at: Time.now, checked: true }])
      expect(reader.checkbox_history('B2').first[:checked]).to be true
    end
  end
end
