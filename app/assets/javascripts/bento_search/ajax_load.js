var BentoSearch = BentoSearch || {}

// Pass in a DOM node that has a data-ajax-url attribute. 
// Will AJAX load bento search results inside that node.
// optional second arg success callback function. 
BentoSearch.ajax_load = function(node, success_callback) {
  div = $(node);
  
  if (div.length == 0) {
    //we've got nothing
    return
  }
  

  // We find the "waiting"/spinner section already rendered,
  // and show it. We experimented with generating the spinner/waiting
  // purely in JS, instead of rendering a hidden one server-side. But
  // it was too weird and unreliable to do that, sorry.   
  div.find(".bento_search_ajax_loading").show();
  
  
  // Now load the actual external content from html5 data-bento-ajax-url
  $.ajax({
      url: div.data("bentoAjaxUrl"), 
      success: function(response, status, xhr) {        
        if (success_callback) {
           success_callback.apply(div, response);
        }
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