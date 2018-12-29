module ReadmooDL
  class File
    attr_reader :path, :content

    def initialize(path, content)
      @path = path
      @context = content
    end
  end
end
