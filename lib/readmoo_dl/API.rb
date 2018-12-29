module ReadmooDL
  class API
    def initialize(args={})
      @username = args[:username]
      @password = args[:password]
    end

    def fetch(path)
      puts path.inspect
    end

    def login
      response = HTTP.follow
                     .post(ReadmooDL::LOGIN_URL,
                           form: { email: @username, password: @password })

      byebug
    end
  end
end
