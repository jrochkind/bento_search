Rails.application.routes.draw do
  require 'bento_search/routes'
  BentoSearch::Routes.new(self).draw
  

end
