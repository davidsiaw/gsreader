# frozen_string_literal: true

module GsReader
  # Low-level HTTP transport used by {GsReader::RevisionReader} to talk to
  # the Drive REST API (for the revision list) and to the Google Sheets
  # `export` endpoint (to download the contents of a *specific* revision).
  #
  # Neither of these is covered by the `google-apis-sheets_v4` gem, so we
  # speak raw HTTP with a bearer token pulled from the supplied
  # credentials.
  #
  # The actual network call is isolated behind `fetcher`, a
  # `->(url, headers) { body_string }` callable, so tests can inject a
  # fake without hitting the network.
  #
  # @example
  #   creds = GsReader.build_credentials(json, scope: GsReader::RevisionReader::HISTORY_SCOPE)
  #   t = GsReader::HttpTransport.new(creds)
  #   t.list_revisions("1abc...")  # => [{ id: "43965", modified_time: "..." }, ...]
  class HttpTransport
    # Maximum number of HTTP redirects to follow for a single request.
    MAX_REDIRECTS = 5

    # @param credentials [#apply!] anything that can populate an
    #   `Authorization` header (a Signet/googleauth credentials object)
    # @param fetcher [#call, nil] optional `->(url, headers) { body }`
    #   override; defaults to a real `Net::HTTP` GET that follows
    #   redirects
    def initialize(credentials, fetcher: nil)
      @credentials = credentials
      @fetcher = fetcher || method(:http_get)
    end

    # List a file's revisions (id + modification time), following
    # pagination to the end.
    #
    # @param spreadsheet_id [String]
    # @return [Array<Hash>] each `{ id: String, modified_time: String }`
    #   in API order (oldest first)
    def list_revisions(spreadsheet_id)
      revisions = []
      page_token = nil

      loop do
        json = JSON.parse(@fetcher.call(revisions_url(spreadsheet_id, page_token), auth_headers))
        (json['revisions'] || []).each do |r|
          revisions << { id: r['id'], modified_time: r['modifiedTime'] }
        end
        page_token = json['nextPageToken']
        break unless page_token
      end

      revisions
    end

    # Export a single range from a specific revision as CSV text.
    #
    # @param spreadsheet_id [String]
    # @param gid [Integer, String] the tab's `sheetId` (the `gid=` in the URL)
    # @param range [String] a bare A1 range, e.g. `"A1"` (no `Sheet!` prefix)
    # @param revision [String] the Drive revision id
    # @return [String] CSV body
    def export_csv(spreadsheet_id, gid:, range:, revision:)
      @fetcher.call(export_url(spreadsheet_id, gid, range, revision), auth_headers)
    end

    private

    def revisions_url(spreadsheet_id, page_token)
      params = { fields: 'revisions(id,modifiedTime),nextPageToken', pageSize: 1000 }
      params[:pageToken] = page_token if page_token
      "https://www.googleapis.com/drive/v3/files/#{spreadsheet_id}/revisions?#{URI.encode_www_form(params)}"
    end

    def export_url(spreadsheet_id, gid, range, revision)
      params = { format: 'csv', gid: gid, range: range, revision: revision }
      "https://docs.google.com/spreadsheets/d/#{spreadsheet_id}/export?#{URI.encode_www_form(params)}"
    end

    # Build an Authorization header from the credentials, refreshing the
    # access token first if the object knows how.
    #
    # @return [Hash{String=>String}]
    def auth_headers
      @credentials.fetch_access_token! if @credentials.respond_to?(:fetch_access_token!)
      headers = {}
      @credentials.apply!(headers) if @credentials.respond_to?(:apply!)
      headers
    end

    # GET `url`, following redirects (carrying the same headers) up to
    # {MAX_REDIRECTS} times.
    #
    # @param url [String]
    # @param headers [Hash]
    # @param limit [Integer]
    # @return [String] response body
    # @raise [GsReader::Error] on too many redirects or a non-2xx status
    def http_get(url, headers, limit = MAX_REDIRECTS)
      raise GsReader::Error, 'too many redirects' if limit.negative?

      uri = URI(url)
      response = perform_get(uri, headers)

      case response
      when Net::HTTPSuccess     then response.body
      when Net::HTTPRedirection then http_get(response['location'], headers, limit - 1)
      else raise GsReader::Error, "HTTP #{response.code} for #{url}"
      end
    end

    def perform_get(uri, headers)
      request = Net::HTTP::Get.new(uri)
      headers.each { |k, v| request[k] = v }
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        http.request(request)
      end
    end
  end
end
