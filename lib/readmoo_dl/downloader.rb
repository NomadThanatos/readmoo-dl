require 'zip'

module ReadmooDL
  class Downloader
    def initialize(username, password)
      @api = API.new(username: username, password: password)
      @books = {}
    end

    def download(book_id)
      return puts '該書正在下載中... 請稍候' if @books[book_id]

      # init book
      @books[book_id] = {
        base_path: nil,
        root_file_path: nil,
        root_file: nil,
        files: [
          ::ReadmooDL::File.new('mimetype', 'application/epub+zip')
        ]
      }

      job('取得檔案路徑') { fetch_base_file(book_id) }
      job('取得 META-INF/container.xml') { fetch_container_file(book_id) }
      job('取得 META-INF/encryption.xml') { fetch_encryption_file(book_id) }
      job('取得 *.opf 檔案') { fetch_root_file(book_id) }
      fetch_book_content(book_id) # 由內部顯示 job 訊息
      job('製作 epub 檔案') { build_epub(book_id) }

      puts "#{book_id} 下載完成"
    end

    private

    def job (name, &block)
      print "正在#{name}..."
      block.call
      puts '成功'
    end

    def fetch_base_file(book_id)
      content = @api.fetch("/api/book/#{book_id}/nav", {:'authorization' => 'bearer ********'}).to_s
      @books[book_id][:base_path] = JSON.parse(content)['base']
    end

    def fetch_container_file(book_id)
      path = 'META-INF/container.xml'
      content = @api.fetch(full_path(book_id, path))

      container_file = ::ReadmooDL::Files::Container.new(path, content)

      @books[book_id][:root_file_path] = container_file.root_file_path
      @books[book_id][:files] << container_file
    end

    def fetch_encryption_file(book_id)
      path = 'META-INF/encryption.xml'
      content = @api.fetch(full_path(book_id, path))

      encryption_file = ::ReadmooDL::File.new(path, content)

      @books[book_id][:files] << encryption_file
    rescue StandardError => e
      puts 'Cannot fetch `encryption.xml` file'
      puts e.inspect
      puts "Just a encryption file, it doesn't matter..."
    end

    def fetch_root_file(book_id)
      path = @books[book_id][:root_file_path]
      content = @api.fetch(full_path(book_id, path))

      root_file = ::ReadmooDL::Files::Content.new(path, content)

      @books[book_id][:root_file] = root_file
      @books[book_id][:files] << root_file
    end

    def fetch_book_content(book_id)
      root_file = @books[book_id][:root_file]
      file_paths = root_file.file_paths
      total = file_paths.size

      file_paths.each_with_index do |path, index|
        puts "#{index+1}/#{total} => 開始下載 #{path}"
        content = @api.fetch(full_path(book_id, path))

        @books[book_id][:files] << ReadmooDL::File.new(path, content)
      end
    end

    def build_epub(book_id)
      book = @books[book_id]
      title = book[:root_file].title
      files = book[:files]
      filename = "#{title}.epub"

      Zip::File.open(filename, Zip::File::CREATE) do |zipfile|
        files.each do |file|
          zipfile.get_output_stream(file.path) { |zip| zip.write(file.content) }
        end
      end
    end

    def full_path(book_id, path)
      base = @books[book_id][:base_path]
      base + path
    end
  end
end
