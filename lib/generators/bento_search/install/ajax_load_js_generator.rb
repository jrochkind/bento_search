require 'rails/generators'
module BentoSearch
  module Install
    class AjaxLoadJsGenerator < ::Rails::Generators::Base
      source_root BentoSearch::Engine.root.to_s

      desc "Copy ajax_load.js file to local .app/javascript/src/js/"

      def generate
        copy_file 'app/assets/javascripts/bento_search/ajax_load.js',
        (Rails.root + "app/javascript/src/js/bento_search_ajax_load.js")
      end
    end
  end
end
