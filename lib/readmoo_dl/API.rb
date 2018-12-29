module ReadmooDL
  class API
    def initialize(args={})
      @username = args[:username]
      @password = args[:password]
    end

    def fetch(path)
      login unless login?

      response = Http.headers(default_headers)
                     .get("#{ReadmooDL::API_URL}#{path}")

      raise_fetch_fail(response) if response.code != 200
      set_cookie(response)

      response.to_s
    end

    private

    def login
      headers = default_headers.merge(
        :'authority' => 'member.readmoo.com',
        :'content-type' => 'application/x-www-form-urlencoded; charset=UTF-8',
      )

      response = HTTP.headers(headers)
                     .post(ReadmooDL::LOGIN_URL, form: { email: @username, password: @password })
      raise_login_fail(response) if response.code != 200
      set_cookie(response)
      response.to_s
    end

    def default_headers
      @default_headers ||= {
        origin: 'https://member.readmoo.com',
        :'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) ' \
                       'AppleWebKit/537.36 (KHTML, like Gecko) ' \
                       'Chrome/71.0.3578.98 Safari/537.36',
        :'accept' => 'application/json, text/javascript, */*; q=0.01',
        :'x-requested-with' => 'XMLHttpRequest'
      }
    end

    def set_cookie(response)
      return if response.headers['Set-Cookie'].nil?

      default_headers.merge!(Cookie: response.headers['Set-Cookie'].join)
    end

    def login?
      @default_headers.has_key?(:Cookie)
    end

    def raise_login_fail(response)
      raise "登入失敗, Details: StatusCode: #{response.code}, Body: #{response}, Headers: #{response.headers.inspect}"
    end

    def raise_fetch_fail(response)
      raise "取得 #{path} 失敗, Details: StatusCode: #{response.code}, Body: #{response}, Headers: #{response.headers.inspect}"
    end
  end
end
