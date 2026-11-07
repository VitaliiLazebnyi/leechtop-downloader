# typed: false
# frozen_string_literal: true

require 'json'
require 'uri'

# Builds the pages leechtop.com serves and stubs them with WebMock, so that no example reaches the network.
module LeechtopPages
  AJAX_URL = 'https://leechtop.com/wp-admin/admin-ajax.php'
  public_constant :AJAX_URL

  # The HTML of a leechtop.com file page.
  def file_page(filename: 'MyFile.zip', data_p: '123', data_mb: '456', nonce: 'abcde')
    <<~HTML
      <html>
        <body>
          <h4 class="mb-2">
            #{filename}
          </h4>
          <a class="go-download-direct" data-p="#{data_p}" data-mb="#{data_mb}">Download</a>
          <script>var zing = {"nonce":"#{nonce}"};</script>
        </body>
      </html>
    HTML
  end

  # Stubs a GET request of +url+ that answers with +body+.
  def stub_page(url, body, status: 200)
    stub_request(:get, url).to_return(status: status, body: body)
  end

  # Stubs the AJAX request that turns the tokens of file_page into +direct_link+.
  def stub_direct_link(direct_link, data_p: '123', data_mb: '456', nonce: 'abcde')
    stub_request(:post, AJAX_URL)
      .with(body: { action: 'z_do_ajax', _action: 'directDownload', p: data_p, mb: data_mb, nonce: nonce })
      .to_return(status: 200, body: JSON.generate(mes: direct_link))
  end

  # Stubs the file behind a direct link.
  def stub_file(direct_link, body, headers: {})
    stub_request(:get, direct_link).to_return(status: 200, body: body, headers: headers)
  end

  # Stubs a complete download: the file page, the AJAX request and the file. Down names a download after the
  # last segment of its URL when the server sends no Content-Disposition, so by default the direct link
  # ends with the file name the page shows.
  # Pages that are downloaded in the same example need different +data_p+ tokens. +file+ takes the
  # :direct_link and the response :headers of the file.
  def stub_download(url, body, filename: 'MyFile.zip', data_p: '123', **file)
    direct_link = file.fetch(:direct_link) { "https://cdn.example/files/#{URI.encode_www_form_component(filename)}" }
    stub_page(url, file_page(filename: filename, data_p: data_p))
    stub_direct_link(direct_link, data_p: data_p)
    stub_file(direct_link, body, headers: file.fetch(:headers, {}))
  end
end
