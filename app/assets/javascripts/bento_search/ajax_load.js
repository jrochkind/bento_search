var BentoSearch = BentoSearch || {}

// Pass in a DOM node that has a data-ajax-url attribute. 
// Will AJAX load bento search results inside that node.
BentoSearch.ajax_load = function(node) {
  div = $(node);
  // from html5 data-bento-ajax-url
  $.ajax({
      url: div.data("bentoAjaxUrl"), 
      success: function(response, status, xhr) {
        div.replaceWith(response);   
      },
      error: function(xhr, status, errorThrown) {
        var msg = "Sorry but there was an error: ";
        div.html(msg + xhr.status + " " + xhr.statusText + ", " + status);
      }
  });
}

jQuery(document).ready(function($) {
    //Intentionally wait for window.load, not just onready, to
    //prevent interfering with rest of page load. 
    $(window).bind("load", function() {   
        $("*[data-bento-search-load=ajax_auto]").each(function(i, div) {
            BentoSearch.ajax_load(div);                              
      });
    });    
});