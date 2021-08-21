module ReadmooDL
  class Lister
    def initialize(api)
      @api = api
      @books = {}
    end

    def list
        JSON.parse(@api.list())['included'].map do |item|
            item.slice('id', 'title')
        end
    end
  end
end
