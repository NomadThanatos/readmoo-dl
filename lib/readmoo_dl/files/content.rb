module ReadmooDL
  module Files
    class Content < ::ReadmooDL::File
      def file_paths
        doc.css('item').map do |item|
          ::File.join(base_dir, item.attr('href')).to_s
        end
      end

      def title
        doc.remove_namespaces!
           .css('title')
           .first
           .text
      end

      private

      # OEBPS/content.opf => OEBPS
      def base_dir
        ::File.dirname(path)
      end

      def doc
        Nokogiri::XML(content)
      end
    end
  end
end
