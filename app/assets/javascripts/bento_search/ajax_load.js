jQuery(document).ready(function($) {
    //Intentionally wait for window.load, not just onready, to
    //prevent interfering with rest of page load. 
    $(window).bind("load", function() {   
        $("*[data-bento-search-load=ajax_auto]").each(function(i, div) {
         div = $(div);
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
                              
      });
    });
    
});