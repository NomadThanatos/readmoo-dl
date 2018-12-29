module ReadmooDL
  class API
    def initialize(args={})
      @username = args[:username]
      @password = args[:password]
    end

    def fetch(path)
      response = Http.headers(default_headers)
                     .get("#{ReadmooDL::API_URL}#{path}")
      set_cookie(response)
    end

    def login
      headers = default_headers.merge(
        :'authority' => 'member.readmoo.com',
        :'content-type' => 'application/x-www-form-urlencoded; charset=UTF-8',
      )

      response = HTTP.headers(headers)
                     .post(ReadmooDL::LOGIN_URL,
                           form: { email: @username, password: @password })
      if response.code != 200
        raise "登入失敗, Details: StatusCode: #{response.code}, Body: #{response}, Headers: #{response.headers.inspect}"
      end

      set_cookie(response)
    end

    private

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
      default_headers.merge!(Cookie: response.headers['Set-Cookie'].join)
      response
    end
  end
end
