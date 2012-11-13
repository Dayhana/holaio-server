htmlEntities = function (str) {
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

updateIframe = function (err, json) {
  var frame = document.getElementById('frame');
  if (err < 300) {
    json = JSON.stringify(json);
    json = htmlEntities(json);
    frame.innerHTML = json;
   } else {
   	frame.innerHTML = err;
   }
}

loadDemo = function() {
  var holaio = new HolaIO(id);
  var url = 'https://api.holalabs.com/io'+encodeURIComponent(document.getElementById('url').value)+'/'+encodeURIComponent(document.getElementById('selector').value)+'/true';
  document.getElementById('completeUrl').value = url;
  holaio.get(document.getElementById('url').value, document.getElementById('selector').value, true, true, updateIframe)
}