# frozen_string_literal: true

RSpec.describe GsReader::HttpTransport do
  let(:credentials) do
    c = double('credentials')
    allow(c).to receive(:fetch_access_token!)
    allow(c).to receive(:apply!) { |h| h['Authorization'] = 'Bearer tok' }
    c
  end

  describe '#list_revisions' do
    it 'maps the Drive revisions payload to id/modified_time hashes' do
      fetcher = lambda do |url, headers|
        expect(url).to include('/drive/v3/files/sheet_id/revisions')
        expect(headers['Authorization']).to eq('Bearer tok')
        JSON.dump('revisions' => [
                    { 'id' => '1', 'modifiedTime' => '2026-06-01T10:00:00Z' },
                    { 'id' => '2', 'modifiedTime' => '2026-06-02T10:00:00Z' }
                  ])
      end
      transport = described_class.new(credentials, fetcher: fetcher)
      expect(transport.list_revisions('sheet_id')).to eq(
        [
          { id: '1', modified_time: '2026-06-01T10:00:00Z' },
          { id: '2', modified_time: '2026-06-02T10:00:00Z' }
        ]
      )
    end

    it 'follows pagination across pages' do
      pages = [
        JSON.dump('revisions' => [{ 'id' => '1', 'modifiedTime' => 't1' }], 'nextPageToken' => 'p2'),
        JSON.dump('revisions' => [{ 'id' => '2', 'modifiedTime' => 't2' }])
      ]
      fetcher = ->(_url, _headers) { pages.shift }
      transport = described_class.new(credentials, fetcher: fetcher)
      expect(transport.list_revisions('sheet_id').map { |r| r[:id] }).to eq(%w[1 2])
    end
  end

  describe '#export_csv' do
    it 'hits the spreadsheets export endpoint with gid, range, and revision' do
      fetcher = lambda do |url, _headers|
        expect(url).to include('/spreadsheets/d/sheet_id/export')
        expect(url).to include('format=csv')
        expect(url).to include('gid=5')
        expect(url).to include('range=B2')
        expect(url).to include('revision=9')
        "TRUE\n"
      end
      transport = described_class.new(credentials, fetcher: fetcher)
      expect(transport.export_csv('sheet_id', gid: 5, range: 'B2', revision: '9')).to eq("TRUE\n")
    end
  end
end
