jQuery(document).ready(function($) {
    //Intentionally wait for window.load, not just onready, to
    //prevent interfering with rest of page load. 
    $(window).bind("load", function() {   
      $(".bento_search_ajax_wait").each(function(i, div) {
         div = $(div);
         // from html5 data-bento-ajax-url
         div.load( div.data("bentoAjaxUrl"), function(response, status, xhr) {
            if (status == "error") {
              var msg = "Sorry but there was an error: ";
              div.html(msg + xhr.status + " " + xhr.statusText);
            }        
         });            
      });
    });
    
});