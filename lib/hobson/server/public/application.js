!function(){

  Hobson = {};

  Hobson.loadContent = function(callback){
    $('body').addClass('loading');
    var request = $.get(location.toString());

    Hobson.loadContent.request = request;

    request.success(function(html){
      $('#content').html(html);
      $('body').removeClass('loading');
    });

    if (callback) request.complete(callback);
  };

  Hobson.autoRefresh = function(now){
    console.log('starting to auto refresh');
    Hobson.autoRefresh.on = true;

    function loadContent(){
      Hobson.loadContent(refresh);
    }

    function refresh(){
      if (!Hobson.autoRefresh.on) return console.log('was going to refresh but now im not');
      Hobson.autoRefresh.timeout = setTimeout(loadContent, Hobson.autoRefresh.rate);
    }

    now ? loadContent() : refresh();
  };

  Hobson.autoRefresh.rate = 5000;

  Hobson.autoRefresh.stop = function(){
    console.log('stopping auto refresh');
    Hobson.autoRefresh.on = false;
    clearTimeout(Hobson.autoRefresh.timeout);
    if (Hobson.loadContent.request) Hobson.loadContent.request.abort();
  };

}();

Hobson.autoRefresh();
