$(document).ready(function(){
  $.each($('.rich-textarea'), function(index, el){
    $(el).wysihtml5({
      "font-styles": false, //Font styling, e.g. h1, h2, etc. Default true
      "emphasis": true, //Italics, bold, etc. Default true
      "lists": true, //(Un)ordered lists, e.g. Bullets, Numbers. Default true
      "html": false, //Button which allows you to edit the generated HTML. Default false
      "link": true, //Button to insert a link. Default true
      "image": false, //Button to insert an image. Default true,
      "color": false //Button to change color of font
    });
  });

  // SIT TEASER / Click through
  $('.sit-teaser').click( function() {
    Turbolinks.visit($(this).find('.sit-link').attr('href'));
  });

  // NEW SIT / title or duration
  $('.new-sit .radio_buttons input').click( function() {
    if ($(this).attr('id') == 'sit_s_type_0') {
      // Show the duration if 'sit' is selected
      $('.new-sit-title').hide();
      $('.new-sit-duration').fadeIn();
    } else {
      $('.new-sit-duration').hide();
      $('.new-sit-title').fadeIn();
    }
  });

  $( ".datepicker" ).datepicker({
    changeMonth: true,
    changeYear: true
  });

  $(".chzn-select").chosen();

  // FAVOURITES / add and remove
  $('#favourite_button').on('click', '.toggle-favourite', function(e) {
    e.preventDefault();
    $(this).closest('form').submit();
  });
});

// Loading indicator and Google Analytics
$(document).on('page:fetch', function() {
  $(".loading-indicator").show();
});

$(document).on('page:change', function() {
  $(".loading-indicator").hide();
});