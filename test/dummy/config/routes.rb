Rails.application.routes.draw do
  require 'bento_search/routes'
  BentoSearch::Routes.new(self).draw
  
  # need a root path so we can test code that
  # uses root_url route helper
  root :to => "dummy#index"
end
