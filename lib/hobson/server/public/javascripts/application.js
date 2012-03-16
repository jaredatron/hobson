Hobson = {};

Hobson.loadContent = function(callback){

  if (Hobson.isPageVisible()){
    console.log('reloading page content');

    $('body').addClass('loading');
    var request = $.get(location.toString());

    Hobson.loadContent.request = request;

    request.success(function(html){
      $('#content').html(html);
      $('body').removeClass('loading');
    });

    if (callback) request.complete(callback);

  }else{
    console.log('skipping page content reload');
    if (callback) setTimeout(callback);
  }
};

Hobson.isPageVisible = function(){
  return (typeof document.webkitVisibilityState === 'string') ?
    document.webkitVisibilityState === 'visible' : true;
}

Hobson.autoRefresh = function(now){
  console.log('starting to auto refresh');
  Hobson.autoRefresh.on = true;

  function loadContent(){
    Hobson.loadContent(refresh);
  }

  function refresh(){
    if (!Hobson.autoRefresh.on) return;
    Hobson.autoRefresh.timeout = setTimeout(loadContent, Hobson.autoRefresh.rate);
  }

  now ? loadContent() : refresh();
};

Hobson.autoRefresh.on = true;

Hobson.autoRefresh.rate = 5000;

Hobson.autoRefresh.stop = function(){
  console.log('stopping auto refresh');
  Hobson.autoRefresh.on = false;
  clearTimeout(Hobson.autoRefresh.timeout);
  if (Hobson.loadContent.request) Hobson.loadContent.request.abort();
};

Hobson.CI = {};

Hobson.CI.CHANGED_POLL_FREQUENCY = 1000 * 60;

Hobson.CI.checkForChanges = function(){
  $.getJSON('/ci/check-for-changes');
}

Hobson.CI.pollForChanges = function(){
  if (Hobson.CI.pollingForChanges) return;
  Hobson.CI.pollingForChanges = true;
  function waitThenCheckForChanges(){
    Hobson.CI.checkForChanges();
    setTimeout(waitThenCheckForChanges, Hobson.CI.CHANGED_POLL_FREQUENCY);
  }
  waitThenCheckForChanges();
};

$(document)
  .ajaxStart(   function(){ $('#nav .loading').show(); })
  .ajaxComplete(function(){ $('#nav .loading').hide(); })
;

$(function(){
  if (Hobson.autoRefresh.on) Hobson.autoRefresh();
});
