require 'zip'
require 'pathname'
require 'concurrent'

module ReadmooDL
  class Downloader
    MAX_RETRIES = 3
    RETRY_DELAY = 5 # seconds
    MAX_DOWNLOAD_THREADS = 10 # Define constant for concurrent threads

    def initialize(api)
      @api = api
      @books = {}
    end

    def download(book_id)
      return puts '該書正在下載中... 請稍候' if @books[book_id]

      # Initialize book ONCE before retrying
      @books[book_id] = {
        base_path: nil,
        root_file_path: nil,
        root_file: nil,
        files: [
          ::ReadmooDL::File.new('mimetype', 'application/epub+zip')
        ]
      }

      retries = 0
      begin
        job("取得檔案路徑#{book_id}") { fetch_base_file(book_id) }
        # Add a check here to ensure base_path was set
        raise "無法取得書籍 base path: #{book_id}" if @books[book_id][:base_path].nil?

        job('取得 META-INF/container.xml') { fetch_container_file(book_id) }
        job('取得 META-INF/encryption.xml') { fetch_encryption_file(book_id) }
        job('取得 *.opf 檔案') { fetch_root_file(book_id) }
        fetch_book_content(book_id) # 由內部顯示 job 訊息
        epub_filename = job('製作 epub 檔案') { build_epub(book_id) } # Capture filename

        puts "#{epub_filename} 下載完成" # Use filename here
      rescue StandardError => e # Catching StandardError for simplicity, consider more specific errors
        retries += 1
        if retries <= MAX_RETRIES
          puts "下載失敗 (#{e.message})，#{RETRY_DELAY} 秒後重試 (#{retries}/#{MAX_RETRIES})..."
          sleep RETRY_DELAY
          retry # Retry the begin block
        else
          puts "下載失敗，已達最大重試次數 (#{MAX_RETRIES})。"
          # Optionally re-raise the error or handle it differently
          # raise e
          # Or remove the book entry to allow retrying later manually
          @books.delete(book_id)
        end
      end
    end

    private

    def job (name, &block)
      print "正在#{name}..."
      result = block.call # Capture the result
      puts '成功'
      result # Return the result
    end

    def fetch_base_file(book_id)
      api_path = "/api/book/#{book_id}/nav"
      auth_header = {:'authorization' => 'bearer TWBLXfuP-NbtCrjD2PAiFA'} # Assuming this token is still valid or handled by API class
      begin
        content_raw = @api.fetch(api_path, auth_header)
        content_str = content_raw.to_s
        parsed_json = JSON.parse(content_str)
        @books[book_id][:base_path] = parsed_json['base']
      rescue JSON::ParserError => e
        puts "\n無法解析書籍基本路徑 API 回應 (JSON::ParserError): #{e.message}"
        @books[book_id][:base_path] = nil # Ensure it's nil on parse failure
      rescue => e # Catch other potential errors during fetch/parse
        puts "\n獲取書籍基本路徑時發生錯誤 (#{e.class}): #{e.message}"
        @books[book_id][:base_path] = nil
      end
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
      # Check if the error message string contains 'StatusCode: 403'
      if e.message.to_s.include?('StatusCode: 403')
        puts "Cannot fetch `encryption.xml` file (HTTP 403 Forbidden). It doesn't matter..."
      else
        # Print full details for other errors
        puts 'Cannot fetch `encryption.xml` file'
        puts e.inspect # Keep inspect for unexpected errors
        puts "Just a encryption file, it doesn't matter..."
      end
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
      fetched_count = Concurrent::AtomicFixnum.new(0) # Thread-safe counter
      downloaded_files = Concurrent::Array.new # Thread-safe array

      # Adjust pool size based on experimentation/network limits
      pool = Concurrent::FixedThreadPool.new(MAX_DOWNLOAD_THREADS)

      puts "準備下載 #{total} 個檔案..."

      futures = file_paths.each_with_index.map do |path, index|
        Concurrent::Future.execute(executor: pool) do
          begin
            puts "#{index + 1}/#{total} => 開始下載 #{path}"
            content = @api.fetch(full_path(book_id, path))
            file = ::ReadmooDL::File.new(path, content)
            current_count = fetched_count.increment
            file # Return the file object
          rescue StandardError => e
            puts "\n下載檔案失敗: #{path} (#{e.message})"
            nil # Indicate failure
          end
        end
      end

      # Wait for all futures to complete and collect results
      downloaded_files.concat(futures.map(&:value).compact) # .value blocks until done, .compact removes nils from failures

      pool.shutdown
      pool.wait_for_termination

      @books[book_id][:files].concat(downloaded_files)
      puts "\n檔案下載完成"
    end

    def build_epub(book_id)
      book = @books[book_id]
      title = book[:root_file].title
      files = book[:files]
      filename = "#{title}.epub"

      # Replace reserved characters that shouldn't be used in file names
      filename = filename.gsub(/[\/\\:\*\?\"\<\>\|]/, '_')

      Zip::File.open(filename, Zip::File::CREATE) do |zipfile|
        files.each do |file|
          zipfile.get_output_stream(Pathname.new(file.path).cleanpath) { |zip| zip.write(file.content) }
        end
      end

      filename # Return the filename
    end

    def full_path(book_id, path)
      base = @books[book_id][:base_path]
      base + path
    end
  end
end
