module ReadmooDL
  class API
    def initialize(args={})
      @username = args[:username]
      @password = args[:password]
    end

    def fetch(path, auth = {})
      login unless login?
      response = HTTP.headers(default_headers.merge(auth))
                     .get("#{ReadmooDL::API_URL}#{path}")

      raise_fetch_fail(path, response) if response.code != 200
      set_cookie(response.cookies)
      response.to_s
    end

    def list()
      login unless login?
      response = HTTP.headers(default_headers)
                     .get("#{ReadmooDL::LIST_URL}")

      raise_fetch_fail(path, response) if response.code != 200
      set_cookie(response.cookies)
      response.to_s
    end

    private

    def login_selenium(driver)
      sleep(1)
      driver.find_element(:name, 'email').send_key(@username)
      sleep(1)
      driver.find_element(:name, 'password').send_key(@password)
      driver.find_element(:id, 'sign-in-btn').click

      #Need wait the page is fully loaded to get the cookies;
      sleep(30)
      driver
    end

    def login
      driver = Selenium::WebDriver.for :chrome
      driver.navigate.to(ReadmooDL::LOGIN_URL)

      driver = login_selenium(driver)
      cookies = driver.manage.all_cookies.each{ |e|
	e[:expires]=(e[:expires]||Time.now).strftime('%a, %d-%b-%Y %T GMT')
      }.map{ |e| HTTP::Cookie.new(e) }

      set_cookie(cookies)
    end

    def default_headers
      @default_headers ||= {
        :'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) ' \
                       'AppleWebKit/537.36 (KHTML, like Gecko) ' \
                       'Chrome/71.0.3578.98 Safari/537.36',
        :'x-requested-with' => 'XMLHttpRequest',
        :'referer' => 'https://reader.readmoo.com/reader/index.html',
      }
    end

    def current_cookie
      @current_cookie ||= {}
    end

    def set_cookie(cookie_jar)
      cookie_hash = cookie_jar.map { |cookie| [cookie.name, cookie.value] }.to_h
      current_cookie.merge!(cookie_hash)
      cookie = current_cookie.reduce('') { |cookie, (name, value)| cookie + "#{name}=#{value}; " }.strip

      default_headers.merge!(Cookie: cookie)
    end

    def login?
      @default_headers && @default_headers.has_key?(:Cookie)
    end

    def raise_login_fail(response)
      raise "登入失敗, Details: StatusCode: #{response.code}, Body: #{response}, Headers: #{response.headers.inspect}"
    end

    def raise_fetch_fail(path, response)
      raise "取得 #{path} 失敗, Details: StatusCode: #{response.code}, Body: #{response}, Headers: #{response.headers.inspect}"
    end
  end
end
