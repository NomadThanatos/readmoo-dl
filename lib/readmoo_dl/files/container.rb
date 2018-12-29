module ReadmooDL
  module Files
    class Container < ::ReadmooDL::File
      def root_file_path
        doc.css('rootfile').first.attr('full-path')
      end

      private

      def doc
        Nokogiri::XML(content)
      end
    end
  end
end
