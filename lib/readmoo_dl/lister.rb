module ReadmooDL
  class Lister
    def initialize(username, password)
      @api = API.new(username: username, password: password)
      @books = {}
    end

    def list
        JSON.parse(@api.list())['included'].map do |item|
            item.slice('id', 'title')
        end
    end
  end
end
