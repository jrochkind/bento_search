module BentoSearch
  class Engine < ::Rails::Engine
    #isolate_namespace BentoSearch

    if config.respond_to?(:assets)
      config.assets.precompile += %w( bento_search/large_loader.gif )
    end
  end
end
