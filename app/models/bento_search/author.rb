module BentoSearch
  class Author
    def initialize(args ={})
      args.each_pair do |key, value|
        send("#{key}=", value)
      end
    end
    
    # Can be first name or initial, whatever source provides
    attr_accessor :first
    # last name/surname/family name as provided by source
    attr_accessor :last
    # middle name or initial, as and if provided by source
    attr_accessor :middle
    
    # if source doens't provide seperate first/last, 
    # source may only be able to provide one big string, author_display
    attr_accessor :display
    
  end
end
