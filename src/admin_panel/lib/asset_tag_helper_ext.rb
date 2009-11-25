module ActionView
  module Helpers
    module AssetTagHelper
      def link_tag(url_options = {}, tag_options = {})
        href = url_options.is_a?(Hash) ?
          url_for(url_options.merge(
            :only_path => false)) : url_options
        tag(
          "link",
          "rel"   => tag_options[:rel] || nil,
          "type"  => tag_options[:type] || nil,
          "title" => tag_options[:title] || nil,
          "href"  => compute_public_path(href, "", "")
        )
      end
    end
  end
end
