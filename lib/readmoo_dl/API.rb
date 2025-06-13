module ReadmooDL
  class API
    COOKIE_FILE = 'cookies.json' # Define path for cookie storage
    FRONT_PAGE_URL = 'https://readmoo.com/'.freeze
    LOGGED_IN_SELECTOR = '.member-data-nav .top-nav-my'.freeze

    def initialize(args={})
      @username = args[:username]
      @password = args[:password]
      @current_cookie = {} # Initialize before load attempt
      @default_headers = nil # Initialize before load attempt

      if load_cookies_from_file
        unless validate_cookies_headlessly
          puts "Loaded cookies are invalid or expired. Clearing and forcing login."
          @current_cookie = {}
          @default_headers = nil # Clear headers to ensure login? fails
        end
      end
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

    require 'selenium-webdriver'

    def login_selenium(driver)
      sleep(1)
      driver.find_element(:name, 'email').send_key(@username)
      sleep(1)
      driver.find_element(:name, 'password').send_key(@password)
      driver.find_element(:id, 'sign-in-btn').click

      puts "請在瀏覽器中完成登入（包含 CAPTCHA），腳本將等待最多 5 分鐘..."
      wait = Selenium::WebDriver::Wait.new(timeout: 300) # 300 seconds timeout
      begin
        wait.until { driver.find_element(css: '.member-data-nav .top-nav-my').displayed? }
        puts "登入成功，繼續執行..."
      rescue Selenium::WebDriver::Error::TimeoutError
        puts "等待登入超時（超過 5 分鐘），請重試。"
        driver.quit
        raise "Login timed out after 300 seconds waiting for CAPTCHA completion."
      end

      driver
    end

    def login
      # Only proceed with Selenium login if cookies weren't loaded or are invalid
      return if login?

      driver = Selenium::WebDriver.for :chrome
      driver.navigate.to(ReadmooDL::LOGIN_URL)

      driver = login_selenium(driver)
      cookies = driver.manage.all_cookies.each{ |e|
	e[:expires]=(e[:expires]||Time.now).strftime('%a, %d-%b-%Y %T GMT')
      }.map{ |e| HTTP::Cookie.new(e) }

      driver.quit

      set_cookie(cookies)
      save_cookies_to_file # Save cookies after successful login
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

      # Ensure default_headers is initialized before merging
      @default_headers ||= {
        :'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_2) ' \
                       'AppleWebKit/537.36 (KHTML, like Gecko) ' \
                       'Chrome/71.0.3578.98 Safari/537.36',
        :'x-requested-with' => 'XMLHttpRequest',
        :'referer' => 'https://reader.readmoo.com/reader/index.html',
      }
      default_headers.merge!(Cookie: cookie)
      # Consider saving cookies here as well if they can be updated by non-login fetches
      # save_cookies_to_file
    end

    def login?
      # Check both for the header key and if cookies were actually loaded/set
      @default_headers && @default_headers.key?(:Cookie) && !current_cookie.empty?
    end

    def raise_login_fail(response)
      raise "登入失敗, Details: StatusCode: #{response.code}, Body: #{response}, Headers: #{response.headers.inspect}"
    end

    def raise_fetch_fail(path, response)
      raise "取得 #{path} 失敗, Details: StatusCode: #{response.code}, Body: #{response}, Headers: #{response.headers.inspect}"
    end

    def validate_cookies_headlessly
      return false if @current_cookie.empty? # No cookies to validate

      puts "Validating loaded cookies"

      driver = nil
      begin
        driver = Selenium::WebDriver.for :chrome
        # Navigate to the domain first to set cookies for that domain
        driver.navigate.to FRONT_PAGE_URL

        # Add cookies one by one
        @current_cookie.each do |name, value|
          # Selenium needs cookie properties; create a minimal hash
          # Note: Domain might need adjustment if cookies are for subdomains
          # Note: expiry is not strictly needed for session check but might be for persistence
          driver.manage.add_cookie(name: name.to_s, value: value, domain: '.readmoo.com', path: '/')
        end

        # Refresh the page to apply cookies
        driver.navigate.refresh
        sleep(2) # Give page time to load with cookies

        # Check for the logged-in element
        driver.find_element(css: LOGGED_IN_SELECTOR)
        puts "Cookie validation successful."
        return true
      rescue Selenium::WebDriver::Error::NoSuchElementError
        puts "Cookie validation failed: Logged-in element not found."
        return false
      rescue StandardError => e
        puts "Error during headless cookie validation: #{e.message}"
        return false # Treat errors as validation failure
      ensure
        driver&.quit
      end
    end

    def load_cookies_from_file
      return false unless ::File.exist?(COOKIE_FILE)

      begin
        content = ::File.read(COOKIE_FILE)
        data = JSON.parse(content, symbolize_names: true) # Use symbolize_names for consistency
        if data[:cookies] && data[:headers]
          @current_cookie = data[:cookies]
          @default_headers = data[:headers]
          puts "Loaded cookies from #{COOKIE_FILE}"
          return true # Indicate success
        else
          puts "Cookie file #{COOKIE_FILE} has invalid format."
          return false
        end
      rescue JSON::ParserError => e
        puts "Error parsing cookie file #{COOKIE_FILE}: #{e.message}"
        return false
      rescue StandardError => e
        puts "Error loading cookies from #{COOKIE_FILE}: #{e.message}"
        return false
      end
    end

    def save_cookies_to_file
      # Only save if we actually have cookies and headers
      return if current_cookie.empty? || !@default_headers || !@default_headers.key?(:Cookie)

      begin
        data_to_save = {
          cookies: @current_cookie,
          headers: @default_headers
        }
        ::File.write(COOKIE_FILE, JSON.pretty_generate(data_to_save))
        puts "Saved cookies to #{COOKIE_FILE}"
      rescue StandardError => e
        puts "Error saving cookies to #{COOKIE_FILE}: #{e.message}"
      end
    end
  end
end
