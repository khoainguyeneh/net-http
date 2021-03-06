module TestNetHTTP_version_1_1_methods

  def test_s_get
    assert_equal $test_net_http_data,
        Net::HTTP.get(config('host'), '/', config('port'))

    assert_equal $test_net_http_data,
        Net::HTTP.get("http://#{config('host')}:#{config('port')}/")

    assert_equal $test_net_http_data,
        Net::HTTP.get(URI.parse("http://#{config('host')}:#{config('port')}/"))
  end

  def test_head
    start {|http|
      res = http.head('/')
      assert_kind_of Net::HTTPResponse, res
      assert_equal $test_net_http_data_type, res['Content-Type']
      if !chunked? && !gzip?
        assert_equal $test_net_http_data.size, res['Content-Length'].to_i
      end
    }
  end

  def test_get_with_block_start
    socket = nil

    start do |http|
      socket = http.socket
      _test_get__get http
      assert_equal socket, http.socket
      _test_get__iter http
      assert_equal socket, http.socket
      _test_get__chunked http
      assert_equal socket, http.socket

      assert !socket.closed?

      resp = http.get "/", "Connection" => "close"
      resp.read_body
      assert socket.closed?

      http.get "/"
      assert socket != http.socket
    end

    start do |http|
      socket2 = http.socket
      assert socket2 != socket
    end
  end

  def test_get_with_no_block
    http = start

    socket = http.socket
    _test_get__get http
    assert_equal socket, http.socket
    _test_get__read_nonblock http
    assert_equal socket, http.socket
    _test_get__iter http
    assert_equal socket, http.socket
    _test_get__chunked http
    assert_equal socket, http.socket

    assert !socket.closed?

    resp = http.get "/", "Connection" => "close"
    resp.read_body
    assert socket.closed?

    http.get "/"
    assert socket != http.socket
  end

  def _test_get__get(http)
    res = http.get('/')
    assert_kind_of Net::HTTPResponse, res
    assert_kind_of String, res.body
    if !chunked? && !gzip?
      assert_not_nil res['content-length']
      assert_equal $test_net_http_data.size, res['content-length'].to_i
    end
    assert_equal $test_net_http_data_type, res['Content-Type']
    assert_equal $test_net_http_data.size, res.body.size
    assert_equal $test_net_http_data, res.body

    assert_nothing_raised {
      res, body = http.get('/', { 'User-Agent' => 'test' }.freeze)
    }
  end

  def _test_get__iter(http)
    buf = ''
    res = http.get('/') {|s| buf << s }
    assert_kind_of Net::HTTPResponse, res
    if !chunked? && !gzip?
      assert_not_nil res['content-length']
      assert_equal $test_net_http_data.size, res['content-length'].to_i
    end
    assert_equal $test_net_http_data_type, res['Content-Type']
    assert_equal $test_net_http_data.size, buf.size
    assert_equal $test_net_http_data, buf
  end

  def _test_get__chunked(http)
    buf = ''
    res = http.get('/') {|s| buf << s }
    assert_kind_of Net::HTTPResponse, res
    if !chunked? && !gzip?
      assert_not_nil res['content-length']
      assert_equal $test_net_http_data.size, res['content-length'].to_i
    end
    assert_equal $test_net_http_data_type, res['Content-Type']
    assert_equal $test_net_http_data.size, buf.size
    assert_equal $test_net_http_data, buf

    res = http.get '/'
    assert_kind_of Net::HTTPResponse, res
    if !chunked? && !gzip?
      assert_not_nil res['content-length']
      assert_equal $test_net_http_data.size, res['content-length'].to_i
    end
    assert_equal $test_net_http_data_type, res['Content-Type']
    assert_equal $test_net_http_data.size, res.body.size
    assert_equal $test_net_http_data, res.body
  end

  def _test_get__read_nonblock(http)
    res = nil
    buf = nil

    res = http.request_get('/')
    assert_kind_of Net::HTTPResponse, res

    buf = ''

    until res.finished?
      res.wait(1)
      chunk = res.read_nonblock(1000)
      buf << chunk
    end

    assert_raises EOFError do
      res.read_nonblock(10)
    end

    assert_equal $test_net_http_data_type, res['Content-Type']
    assert_equal $test_net_http_data, buf

    assert_nothing_raised do
      res, body = http.get('/', { 'User-Agent' => 'test' }.freeze)
    end

  end

  def wait(socket, timeout=nil)
    io = socket.to_io

    if io.is_a?(OpenSSL::SSL::SSLSocket)
      return if IO.select nil, [io], nil, timeout
    else
      return if IO.select [io], nil, nil, timeout
    end

    raise Timeout::Error
  end

  def test_get__break
    i = 0
    start {|http|
      http.get('/') do |str|
        i += 1
        break
      end
    }
    assert_equal 1, i
  end

  def test_get__implicit_start
    res = new().get('/')
    assert_kind_of Net::HTTPResponse, res
    assert_kind_of String, res.body
    if !chunked? && !gzip?
      assert_not_nil res['content-length']
    end
    assert_equal $test_net_http_data_type, res['Content-Type']
    assert_equal $test_net_http_data.size, res.body.size
    assert_equal $test_net_http_data, res.body
  end

  def test_get2
    start {|http|
      http.get2('/') {|res|
        assert_kind_of Net::HTTPResponse, res
        assert_kind_of Net::HTTPResponse, res.header
        if !chunked? && !gzip?
          assert_not_nil res['content-length']
        end
        assert_equal $test_net_http_data_type, res['Content-Type']
        assert_kind_of String, res.body
        assert_kind_of String, res.entity
        assert_equal $test_net_http_data.size, res.body.size
        assert_equal $test_net_http_data, res.body
        assert_equal $test_net_http_data, res.entity
      }
    }
  end

  def test_post
    start {|http|
      _test_post__base http
      _test_post__file http
    }
  end

  def _test_post__base(http)
    uheader = {}
    uheader['Accept'] = 'application/octet-stream'
    data = 'post data'
    res = http.post('/', data)
    assert_kind_of Net::HTTPResponse, res
    assert_kind_of String, res.body
    assert_equal data, res.body
    assert_equal data, res.entity
  end

  def _test_post__file(http)
    data = 'post data'
    f = StringIO.new
    http.post('/', data, nil, f)
    assert_equal data, f.string
  end

  def test_s_post_form
    res = Net::HTTP.post_form(
              URI.parse("http://#{config('host')}:#{config('port')}/"),
              "a" => "x")
    assert_equal ["a=x"], res.body.split(/[;&]/).sort

    res = Net::HTTP.post_form(
              URI.parse("http://#{config('host')}:#{config('port')}/"),
              "a" => "x",
              "b" => "y")
    assert_equal ["a=x", "b=y"], res.body.split(/[;&]/).sort

    # TODO: Why is this failing?
    #res = Net::HTTP.post_form(
              #URI.parse("http://#{config('host')}:#{config('port')}/"),
              #"a" => ["x1", "x2"],
              #"b" => "y")
    #assert_equal ["a=x1", "a=x2", "b=y"], res.body.split(/[;&]/).sort
  end

  def test_patch
    start {|http|
      _test_patch__base http
    }
  end

  def _test_patch__base(http)
    uheader = {}
    uheader['Accept'] = 'application/octet-stream'
    data = 'patch data'
    res = http.patch('/', data)
    assert_kind_of Net::HTTPResponse, res
    assert_kind_of String, res.body
    assert_equal data, res.body
    assert_equal data, res.entity
  end

  def test_timeout_during_HTTP_session
    bug4246 = "expected the HTTP session to have timed out but have not. c.f. [ruby-core:34203]"

    # listen for connections... but deliberately do not complete SSL handshake
    TCPServer.open(0) {|server|
      port = server.addr[1]

      conn = Net::HTTP.new('localhost', port)
      conn.read_timeout = 1
      conn.open_timeout = 1

      th = Thread.new do
        assert_raise(Timeout::Error) {
          conn.get('/')
        }
      end
      assert th.join(10), bug4246
    }
  end
end


module TestNetHTTP_version_1_2_methods

  def test_request
    start {|http|
      _test_request__GET http
      _test_request__file http
      # _test_request__range http   # WEBrick does not support Range: header.
      _test_request__HEAD http
      _test_request__POST http
      _test_request__stream_body http, :body_stream=
      _test_request__stream_body http, :body=

    }
  end

  def _test_request__GET(http)
    req = Net::HTTP::Get.new('/')
    http.request(req) {|res|
      assert_kind_of Net::HTTPResponse, res
      assert_kind_of String, res.body
      if !chunked? && !gzip?
        assert_not_nil res['content-length']
        assert_equal $test_net_http_data.size, res['content-length'].to_i
      end
      assert_equal $test_net_http_data.size, res.body.size
      assert_equal $test_net_http_data, res.body
    }
  end

  def _test_request__file(http)
    req = Net::HTTP::Get.new('/')
    http.request(req) {|res|
      assert_kind_of Net::HTTPResponse, res
      if !chunked? && !gzip?
        assert_not_nil res['content-length']
        assert_equal $test_net_http_data.size, res['content-length'].to_i
      end
      str = ""
      str.force_encoding("BINARY") if str.encoding_aware?
      f = StringIO.new(str)
      res.read_body f
      assert_equal $test_net_http_data.bytesize, f.string.bytesize
      assert_equal $test_net_http_data.encoding, f.string.encoding if f.string.encoding_aware?
      assert_equal $test_net_http_data, f.string
    }
  end

  def _test_request__range(http)
    req = Net::HTTP::Get.new('/')
    req['range'] = 'bytes=0-5'
    assert_equal $test_net_http_data[0,6], http.request(req).body
  end

  def _test_request__HEAD(http)
    req = Net::HTTP::Head.new('/')
    http.request(req) {|res|
      assert_kind_of Net::HTTPResponse, res
      if !chunked? && !gzip?
        assert_not_nil res['content-length']
        assert_equal $test_net_http_data.size, res['content-length'].to_i
      end
      assert_nil res.body
    }
  end

  def _test_request__POST(http)
    data = 'post data'
    req = Net::HTTP::Post.new('/')
    req['Accept'] = $test_net_http_data_type
    http.request(req, data) {|res|
      assert_kind_of Net::HTTPResponse, res
      if !chunked? && !gzip?
        assert_equal data.size, res['content-length'].to_i
      end
      assert_kind_of String, res.body
      assert_equal data, res.body
    }
  end

  def _test_request__stream_body(http, method = :body_stream=)
    req = Net::HTTP::Post.new('/')
    data = $test_net_http_data
    req.content_length = data.size
    req.send method, StringIO.new(data)
    res = http.request(req)
    assert_kind_of Net::HTTPResponse, res
    assert_kind_of String, res.body
    assert_equal data.size, res.body.size
    assert_equal data, res.body
  end

  def test_send_request
    start {|http|
      _test_send_request__GET http
      _test_send_request__POST http
    }
  end

  def _test_send_request__GET(http)
    res = http.send_request('GET', '/')
    assert_kind_of Net::HTTPResponse, res
    if !chunked? && !gzip?
      assert_equal $test_net_http_data.size, res['content-length'].to_i
    end
    assert_kind_of String, res.body
    assert_equal $test_net_http_data, res.body
  end

  def _test_send_request__POST(http)
    data = 'aaabbb cc ddddddddddd lkjoiu4j3qlkuoa'
    res = http.send_request('POST', '/', data)
    assert_kind_of Net::HTTPResponse, res
    assert_kind_of String, res.body
    assert_equal data.size, res.body.size
    assert_equal data, res.body
  end

  def test_set_form
    require 'tempfile'
    file = Tempfile.new('ruby-test')
    file << "\xE3\x83\x87\xE3\x83\xBC\xE3\x82\xBF"
    #file << "\u{30c7}\u{30fc}\u{30bf}"
    data = [
      ['name', 'Gonbei Nanashi'],
      ['name', "\xE5\x90\x8D\xE7\x84\xA1\xE3\x81\x97\xE3\x81\xAE\xE6\xA8\xA9\xE5\x85\xB5\xE8\xA1\x9B"],
      #['name', "\u{540d}\u{7121}\u{3057}\u{306e}\u{6a29}\u{5175}\u{885b}"],
      ['s"i\o', StringIO.new("\xE3\x81\x82\xE3\x81\x84\xE4\xBA\x9C\xE9\x89\x9B")],
      #['s"i\o', StringIO.new("\u{3042 3044 4e9c 925b}")],
      ["file", file, {:filename => "ruby-test"}]
    ]
    expected = <<"__EOM__".gsub(/\n/, "\r\n")
--<boundary>
Content-Disposition: form-data; name="name"

Gonbei Nanashi
--<boundary>
Content-Disposition: form-data; name="name"

\xE5\x90\x8D\xE7\x84\xA1\xE3\x81\x97\xE3\x81\xAE\xE6\xA8\xA9\xE5\x85\xB5\xE8\xA1\x9B
--<boundary>
Content-Disposition: form-data; name="s\\"i\\\\o"

\xE3\x81\x82\xE3\x81\x84\xE4\xBA\x9C\xE9\x89\x9B
--<boundary>
Content-Disposition: form-data; name="file"; filename="ruby-test"
Content-Type: application/octet-stream

\xE3\x83\x87\xE3\x83\xBC\xE3\x82\xBF
--<boundary>--
__EOM__
    start {|http|
      _test_set_form_urlencoded(http, data.reject{|k,v|!v.is_a?(String)})
      _test_set_form_multipart(http, false, data, expected)
      _test_set_form_multipart(http, true, data, expected)
    }
  end

  def _test_set_form_urlencoded(http, data)
    req = Net::HTTP::Post.new('/')
    req.set_form(data)
    res = http.request req
    assert_equal "name=Gonbei+Nanashi&name=%E5%90%8D%E7%84%A1%E3%81%97%E3%81%AE%E6%A8%A9%E5%85%B5%E8%A1%9B", res.body
  end

  def _test_set_form_multipart(http, chunked_p, data, expected)
    data.each{|k,v|v.rewind rescue nil}
    req = Net::HTTP::Post.new('/')
    req.set_form(data, 'multipart/form-data')
    req['Transfer-Encoding'] = 'chunked' if chunked_p
    res = http.request req
    body = res.body
    assert_match(/\A--(\S+)/, body)
    /\A--(\S+)/ =~ body
    expected = expected.gsub(/<boundary>/, $1)
    assert_equal(expected, body)
  end

  def test_set_form_with_file
    require 'tempfile'
    file = Tempfile.new('ruby-test')
    file.binmode
    file << $test_net_http_data
    filename = File.basename(file.to_path)
    data = [['file', file]]
    expected = <<"__EOM__".gsub(/\n/, "\r\n")
--<boundary>
Content-Disposition: form-data; name="file"; filename="<filename>"
Content-Type: application/octet-stream

<data>
--<boundary>--
__EOM__
    expected.sub!(/<filename>/, filename)
    expected.sub!(/<data>/, $test_net_http_data)
    start {|http|
      data.each{|k,v|v.rewind rescue nil}
      req = Net::HTTP::Post.new('/')
      req.set_form(data, 'multipart/form-data')
      res = http.request req
      body = res.body
      header, _ = body.split(/\r\n\r\n/, 2)
      assert_match(/\A--(\S+)/, body)
      /\A--(\S+)/ =~ body
      expected = expected.gsub(/<boundary>/, $1)
      assert_match(/^--(\S+)\r\n/, header)
      assert_match(
        /^Content-Disposition: form-data; name="file"; filename="#{filename}"\r\n/,
        header)
      assert_equal(expected, body)

      data.each{|k,v|v.rewind rescue nil}
      req['Transfer-Encoding'] = 'chunked'
      res = http.request req
      #assert_equal(expected, res.body)
    }
  end
end

