function clickHandler(e){

        if (!e){var e = window.event;}
        var el = e.srcElement || e.target;

        e.preventDefault();
        var result = parent.document.getElementById("selector");
        result.value = fullPath(el).replace(/ /g, "");
        //console.log("Da real html is: "+el.outerHTML);
}

function fullPath(el){
  var names = [];
  while (el.parentNode){
    if (el.id){
      names.unshift('#'+el.id);
      break;
    }else{
      for (var c=1,e=el;e.previousElementSibling;e=e.previousElementSibling,c++);
      names.unshift(el.tagName+":nth-child("+c+")");
      el=el.parentNode;
    }
  }
  return names.join(" > ");
}

function mouseEventHandler(mEvent)
{
        var els = document.getElementsByClassName("holalabsrulz");
        for (var i=0; i<els.length; i++)
                els[i].className = els[i].className.replace("holalabsrulz", "");
        var el;
        if (mEvent.srcElement)
                el = mEvent.srcElement
        else if (mEvent.target)
                el = mEvent.target
        el.className += " holalabsrulz";
}

document.addEventListener("click", clickHandler, true);

document.addEventListener("mousemove", mouseEventHandler, true);

