module ReadmooDL
  class Lister
    def initialize(username, password)
      @api = API.new(username: username, password: password)
      @books = {}
    end

    def list()
        result = [];
        JSON.parse(@api.list())['included'].each do |item|
            result.push(item.slice("id", "title"))
        end
        result
    end
  end
end
