require 'rails/generators'
module BentoSearch
  class PullEbscoDbsGenerator < ::Rails::Generators::Base
    source_root File.expand_path('../templates', __FILE__)
    
    desc "Pull avail dbs from EBSCO info task, write to source file that defines an array in ruby global variable."
    
    argument :engine_id, :type => :string

    class_option :output_file, :type => :string, :default => "./config/ebsco_dbs.rb", :description => "filepath to write ruby file"
    class_option :global_name, :type => :string, :default => "$ebsco_dbs", :description => "global variable to set in generated source file" 
    
    def generate
      engine  = BentoSearch.get_engine( engine_id )
      
      @dbs    = engine.get_info.xpath("./info/dbInfo/db") #.sort_by {|n| n["shortName"]}
      
      
      template("ebsco_global_var.erb", options.output_file)
      
    end
    
  end
end
