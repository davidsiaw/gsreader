# frozen_string_literal: true

RSpec.describe GsReader do
  it 'has a version number' do
    expect(GsReader::VERSION).not_to be_nil
  end

  it 'defines Reader, Writer, and FormatReader classes' do
    expect(GsReader::Reader).to be < GsReader::Sheet
    expect(GsReader::Writer).to be < GsReader::Sheet
    expect(GsReader::FormatReader).to be < GsReader::Sheet
  end

  describe '.build_credentials' do
    it 'returns objects that already look like credentials untouched' do
      fake = double('creds', fetch_access_token!: { 'access_token' => 't' })
      expect(GsReader.build_credentials(fake, scope: GsReader::READ_SCOPE)).to eq(fake)
    end

    it 'raises on an unsupported credentials type' do
      expect do
        GsReader.build_credentials(123, scope: GsReader::READ_SCOPE)
      end.to raise_error(GsReader::CredentialError)
    end

    it 'raises on a string that is neither JSON nor a real path' do
      expect do
        GsReader.build_credentials('/no/such/file.json', scope: GsReader::READ_SCOPE)
      end.to raise_error(GsReader::CredentialError)
    end
  end
end
