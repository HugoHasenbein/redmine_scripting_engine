function indicatorOnConfirmClick( id ) {
  $('#'+id).on('confirm:complete', function(e) {
    if (e.detail[0]) {
     // User confirmed
     
     $('#ajax-indicator').show();
    } else {
     
     // User cancelled.
    }
  });
}
