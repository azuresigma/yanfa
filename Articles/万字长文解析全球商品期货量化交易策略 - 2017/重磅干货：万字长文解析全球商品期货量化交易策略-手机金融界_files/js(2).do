/*
 * Swipe 2.0
 *
 * Brad Birdsall
 * Copyright 2013, MIT License
 *
*/

function Swipe(container, options) {

  "use strict";

  // utilities
  var noop = function() {}; // simple no operation function
  var offloadFn = function(fn) { setTimeout(fn || noop, 0) }; // offload a functions execution
  
  // check browser capabilities
  var browser = {
    addEventListener: !!window.addEventListener,
    touch: ('ontouchstart' in window) || window.DocumentTouch && document instanceof DocumentTouch,
    transitions: (function(temp) {
      var props = ['transformProperty', 'WebkitTransform', 'MozTransform', 'OTransform', 'msTransform'];
      for ( var i in props ) if (temp.style[ props[i] ] !== undefined) return true;
      return false;
    })(document.createElement('swipe'))
  };

  // quit if no root element
  if (!container) return;
  var element = container.children[0];
  var slides, slidePos, width;
  options = options || {};
  var index = parseInt(options.startSlide, 10) || 0;
  var speed = options.speed || 300;
  options.continuous = options.continuous ? options.continuous : true;

  function setup() {

    // cache slides
    slides = element.children;

    // create an array to store current positions of each slide
    slidePos = new Array(slides.length);

    // determine width of each slide
      width = container.getBoundingClientRect().width || container.offsetWidth;

    element.style.width = (slides.length * width) + 'px';

    // stack elements
    var pos = slides.length;
    while(pos--) {

      var slide = slides[pos];

      slide.style.width = width + 'px';
      slide.setAttribute('data-index', pos);

      if (browser.transitions) {
        slide.style.left = (pos * -width) + 'px';
        move(pos, index > pos ? -width : (index < pos ? width : 0), 0);
      }

    }

    if (!browser.transitions) element.style.left = (index * -width) + 'px';

    container.style.visibility = 'visible';

  }

  function prev() {

    if (index) slide(index-1);
    else if (options.continuous) slide(slides.length-1);

  }

  function next() {

    if (index < slides.length - 1) slide(index+1);
    else if (options.continuous) slide(0);

  }

  function slide(to, slideSpeed) {

    // do nothing if already on requested slide
    if (index == to) return;
    
    if (browser.transitions) {

      var diff = Math.abs(index-to) - 1;
      var direction = Math.abs(index-to) / (index-to); // 1:right -1:left

      while (diff--) move((to > index ? to : index) - diff - 1, width * direction, 0);

      move(index, width * direction, slideSpeed || speed);
      move(to, 0, slideSpeed || speed);

    } else {

      animate(index * -width, to * -width, slideSpeed || speed);

    }

    index = to;

    offloadFn(options.callback && options.callback(index, slides[index]));

  }

  function move(index, dist, speed) {

    translate(index, dist, speed);
    slidePos[index] = dist;

  }

  function translate(index, dist, speed) {

    var slide = slides[index];
    var style = slide && slide.style;

    if (!style) return;

    style.webkitTransitionDuration = 
    style.MozTransitionDuration = 
    style.msTransitionDuration = 
    style.OTransitionDuration = 
    style.transitionDuration = speed + 'ms';

    style.webkitTransform = 'translate(' + dist + 'px,0)' + 'translateZ(0)';
    style.msTransform = 
    style.MozTransform = 
    style.OTransform = 'translateX(' + dist + 'px)';

  }

  function animate(from, to, speed) {

    // if not an animation, just reposition
    if (!speed) {
      
      element.style.left = to + 'px';
      return;

    }
    
    var start = +new Date;
    
    var timer = setInterval(function() {

      var timeElap = +new Date - start;
      
      if (timeElap > speed) {

        element.style.left = to + 'px';

        if (delay) begin();

        options.transitionEnd && options.transitionEnd.call(event, index, slides[index]);

        clearInterval(timer);
        return;

      }

      element.style.left = (( (to - from) * (Math.floor((timeElap / speed) * 100) / 100) ) + from) + 'px';

    }, 4);

  }

  // setup auto slideshow
  var delay = options.auto || 0;
  var interval;

  function begin() {

    interval = setTimeout(next, delay);

  }

  function stop() {

    delay = 0;
    clearTimeout(interval);

  }


  // setup initial vars
  var start = {};
  var delta = {};
  var isScrolling;      

  // setup event capturing
  var events = {

    handleEvent: function(event) {

      switch (event.type) {
        case 'touchstart': this.start(event); break;
        case 'touchmove': this.move(event); break;
        case 'touchend': offloadFn(this.end(event)); break;
        case 'webkitTransitionEnd':
        case 'msTransitionEnd':
        case 'oTransitionEnd':
        case 'otransitionend':
        case 'transitionend': offloadFn(this.transitionEnd(event)); break;
        case 'resize': offloadFn(setup.call()); break;
      }

      if (options.stopPropagation) event.stopPropagation();

    },
    start: function(event) {

      var touches = event.touches[0];

      // measure start values
      start = {

        // get initial touch coords
        x: touches.pageX,
        y: touches.pageY,

        // store time to determine touch duration
        time: +new Date

      };
      
      // used for testing first move event
      isScrolling = undefined;

      // reset delta and end measurements
      delta = {};

      // attach touchmove and touchend listeners
      element.addEventListener('touchmove', this, false);
      element.addEventListener('touchend', this, false);

    },
    move: function(event) {

      // ensure swiping with one touch and not pinching
      if ( event.touches.length > 1 || event.scale && event.scale !== 1) return

      if (options.disableScroll) event.preventDefault();

      var touches = event.touches[0];

      // measure change in x and y
      delta = {
        x: touches.pageX - start.x,
        y: touches.pageY - start.y
      }

      // determine if scrolling test has run - one time test
      if ( typeof isScrolling == 'undefined') {
        isScrolling = !!( isScrolling || Math.abs(delta.x) < Math.abs(delta.y) );
      }

      // if user is not trying to scroll vertically
      if (!isScrolling) {

        // prevent native scrolling 
        event.preventDefault();

        // stop slideshow
        stop();

        // increase resistance if first or last slide
        delta.x = 
          delta.x / 
            ( (!index && delta.x > 0               // if first slide and sliding left
              || index == slides.length - 1        // or if last slide and sliding right
              && delta.x < 0                       // and if sliding at all
            ) ?                      
            ( Math.abs(delta.x) / width + 1 )      // determine resistance level
            : 1 );                                 // no resistance if false
        
        // translate 1:1
        translate(index-1, delta.x + slidePos[index-1], 0);
        translate(index, delta.x + slidePos[index], 0);
        translate(index+1, delta.x + slidePos[index+1], 0);

      }

    },
    end: function(event) {

      // measure duration
      var duration = +new Date - start.time;

      // determine if slide attempt triggers next/prev slide
      var isValidSlide = 
            Number(duration) < 250               // if slide duration is less than 250ms
            && Math.abs(delta.x) > 20            // and if slide amt is greater than 20px
            || Math.abs(delta.x) > width/2;      // or if slide amt is greater than half the width

      // determine if slide attempt is past start and end
      var isPastBounds = 
            !index && delta.x > 0                            // if first slide and slide amt is greater than 0
            || index == slides.length - 1 && delta.x < 0;    // or if last slide and slide amt is less than 0
      
      // determine direction of swipe (true:right, false:left)
      var direction = delta.x < 0;

      // if not scrolling vertically
      if (!isScrolling) {

        if (isValidSlide && !isPastBounds) {

          if (direction) {

            move(index-1, -width, 0);
            move(index, slidePos[index]-width, speed);
            move(index+1, slidePos[index+1]-width, speed);
            index += 1;

          } else {

            move(index+1, width, 0);
            move(index, slidePos[index]+width, speed);
            move(index-1, slidePos[index-1]+width, speed);
            index += -1;

          }

          options.callback && options.callback(index, slides[index]);

        } else {

          move(index-1, -width, speed);
          move(index, 0, speed);
          move(index+1, width, speed);

        }

      }

      // kill touchmove and touchend event listeners until touchstart called again
      element.removeEventListener('touchmove', events, false)
      element.removeEventListener('touchend', events, false)

    },
    transitionEnd: function(event) {

      if (parseInt(event.target.getAttribute('data-index'), 10) == index) {
        
        if (delay) begin();

        options.transitionEnd && options.transitionEnd.call(event, index, slides[index]);

      }

    }

  }

  // trigger setup
  setup();

  // start auto slideshow if applicable
  if (delay) begin();


  // add event listeners
  if (browser.addEventListener) {
    
    // set touchstart event on element    
    if (browser.touch) element.addEventListener('touchstart', events, false);

    if (browser.transitions) {
      element.addEventListener('webkitTransitionEnd', events, false);
      element.addEventListener('msTransitionEnd', events, false);
      element.addEventListener('oTransitionEnd', events, false);
      element.addEventListener('otransitionend', events, false);
      element.addEventListener('transitionend', events, false);
    }

    // set resize event on window
    window.addEventListener('resize', events, false);

  } else {

    window.onresize = function () { setup() }; // to play nice with old IE

  }

  // expose the Swipe API
  return {
    setup: function() {

      setup();

    },
    slide: function(to, speed) {

      slide(to, speed);

    },
    prev: function() {

      // cancel slideshow
      stop();

      prev();

    },
    next: function() {

      stop();

      next();

    },
    getPos: function() {

      // return current index position
      return index;

    },
    kill: function() {

      // cancel slideshow
      stop();

      // reset element
      element.style.width = 'auto';
      element.style.left = 0;

      // reset slides
      var pos = slides.length;
      while(pos--) {

        var slide = slides[pos];
        slide.style.width = '100%';
        slide.style.left = 0;

        if (browser.transitions) translate(pos, 0, 0);

      }

      // removed event listeners
      if (browser.addEventListener) {

        // remove current event listeners
        element.removeEventListener('touchstart', events, false);
        element.removeEventListener('webkitTransitionEnd', events, false);
        element.removeEventListener('msTransitionEnd', events, false);
        element.removeEventListener('oTransitionEnd', events, false);
        element.removeEventListener('otransitionend', events, false);
        element.removeEventListener('transitionend', events, false);
        window.removeEventListener('resize', events, false);

      }
      else {

        window.onresize = null;

      }

    }
  }

}


if ( window.jQuery || window.Zepto ) {
  (function($) {
    $.fn.Swipe = function(params) {
      return this.each(function() {
        $(this).data('Swipe', new Swipe($(this)[0], params));
      });
    }
  })( window.jQuery || window.Zepto )
}
/* Modernizr 2.7.1 (Custom Build) | MIT & BSD
 * Build: http://modernizr.com/download/#-fontface-backgroundsize-borderimage-borderradius-boxshadow-flexbox-flexboxlegacy-hsla-multiplebgs-opacity-rgba-textshadow-cssanimations-csscolumns-generatedcontent-cssgradients-cssreflections-csstransforms-csstransforms3d-csstransitions-applicationcache-canvas-canvastext-draganddrop-hashchange-history-audio-video-indexeddb-input-inputtypes-localstorage-postmessage-sessionstorage-websockets-websqldatabase-webworkers-geolocation-inlinesvg-smil-svg-svgclippaths-touch-webgl-shiv-cssclasses-addtest-prefixed-teststyles-testprop-testallprops-hasevent-prefixes-domprefixes-load
 */
;window.Modernizr=function(a,b,c){function C(a){j.cssText=a}function D(a,b){return C(n.join(a+";")+(b||""))}function E(a,b){return typeof a===b}function F(a,b){return!!~(""+a).indexOf(b)}function G(a,b){for(var d in a){var e=a[d];if(!F(e,"-")&&j[e]!==c)return b=="pfx"?e:!0}return!1}function H(a,b,d){for(var e in a){var f=b[a[e]];if(f!==c)return d===!1?a[e]:E(f,"function")?f.bind(d||b):f}return!1}function I(a,b,c){var d=a.charAt(0).toUpperCase()+a.slice(1),e=(a+" "+p.join(d+" ")+d).split(" ");return E(b,"string")||E(b,"undefined")?G(e,b):(e=(a+" "+q.join(d+" ")+d).split(" "),H(e,b,c))}function J(){e.input=function(c){for(var d=0,e=c.length;d<e;d++)u[c[d]]=c[d]in k;return u.list&&(u.list=!!b.createElement("datalist")&&!!a.HTMLDataListElement),u}("autocomplete autofocus list placeholder max min multiple pattern required step".split(" ")),e.inputtypes=function(a){for(var d=0,e,f,h,i=a.length;d<i;d++)k.setAttribute("type",f=a[d]),e=k.type!=="text",e&&(k.value=l,k.style.cssText="position:absolute;visibility:hidden;",/^range$/.test(f)&&k.style.WebkitAppearance!==c?(g.appendChild(k),h=b.defaultView,e=h.getComputedStyle&&h.getComputedStyle(k,null).WebkitAppearance!=="textfield"&&k.offsetHeight!==0,g.removeChild(k)):/^(search|tel)$/.test(f)||(/^(url|email)$/.test(f)?e=k.checkValidity&&k.checkValidity()===!1:e=k.value!=l)),t[a[d]]=!!e;return t}("search tel url email datetime date month week time datetime-local number range color".split(" "))}var d="2.7.1",e={},f=!0,g=b.documentElement,h="modernizr",i=b.createElement(h),j=i.style,k=b.createElement("input"),l=":)",m={}.toString,n=" -webkit- -moz- -o- -ms- ".split(" "),o="Webkit Moz O ms",p=o.split(" "),q=o.toLowerCase().split(" "),r={svg:"http://www.w3.org/2000/svg"},s={},t={},u={},v=[],w=v.slice,x,y=function(a,c,d,e){var f,i,j,k,l=b.createElement("div"),m=b.body,n=m||b.createElement("body");if(parseInt(d,10))while(d--)j=b.createElement("div"),j.id=e?e[d]:h+(d+1),l.appendChild(j);return f=["&#173;",'<style id="s',h,'">',a,"</style>"].join(""),l.id=h,(m?l:n).innerHTML+=f,n.appendChild(l),m||(n.style.background="",n.style.overflow="hidden",k=g.style.overflow,g.style.overflow="hidden",g.appendChild(n)),i=c(l,a),m?l.parentNode.removeChild(l):(n.parentNode.removeChild(n),g.style.overflow=k),!!i},z=function(){function d(d,e){e=e||b.createElement(a[d]||"div"),d="on"+d;var f=d in e;return f||(e.setAttribute||(e=b.createElement("div")),e.setAttribute&&e.removeAttribute&&(e.setAttribute(d,""),f=E(e[d],"function"),E(e[d],"undefined")||(e[d]=c),e.removeAttribute(d))),e=null,f}var a={select:"input",change:"input",submit:"form",reset:"form",error:"img",load:"img",abort:"img"};return d}(),A={}.hasOwnProperty,B;!E(A,"undefined")&&!E(A.call,"undefined")?B=function(a,b){return A.call(a,b)}:B=function(a,b){return b in a&&E(a.constructor.prototype[b],"undefined")},Function.prototype.bind||(Function.prototype.bind=function(b){var c=this;if(typeof c!="function")throw new TypeError;var d=w.call(arguments,1),e=function(){if(this instanceof e){var a=function(){};a.prototype=c.prototype;var f=new a,g=c.apply(f,d.concat(w.call(arguments)));return Object(g)===g?g:f}return c.apply(b,d.concat(w.call(arguments)))};return e}),s.flexbox=function(){return I("flexWrap")},s.flexboxlegacy=function(){return I("boxDirection")},s.canvas=function(){var a=b.createElement("canvas");return!!a.getContext&&!!a.getContext("2d")},s.canvastext=function(){return!!e.canvas&&!!E(b.createElement("canvas").getContext("2d").fillText,"function")},s.webgl=function(){return!!a.WebGLRenderingContext},s.touch=function(){var c;return"ontouchstart"in a||a.DocumentTouch&&b instanceof DocumentTouch?c=!0:y(["@media (",n.join("touch-enabled),("),h,")","{#modernizr{top:9px;position:absolute}}"].join(""),function(a){c=a.offsetTop===9}),c},s.geolocation=function(){return"geolocation"in navigator},s.postmessage=function(){return!!a.postMessage},s.websqldatabase=function(){return!!a.openDatabase},s.indexedDB=function(){return!!I("indexedDB",a)},s.hashchange=function(){return z("hashchange",a)&&(b.documentMode===c||b.documentMode>7)},s.history=function(){return!!a.history&&!!history.pushState},s.draganddrop=function(){var a=b.createElement("div");return"draggable"in a||"ondragstart"in a&&"ondrop"in a},s.websockets=function(){return"WebSocket"in a||"MozWebSocket"in a},s.rgba=function(){return C("background-color:rgba(150,255,150,.5)"),F(j.backgroundColor,"rgba")},s.hsla=function(){return C("background-color:hsla(120,40%,100%,.5)"),F(j.backgroundColor,"rgba")||F(j.backgroundColor,"hsla")},s.multiplebgs=function(){return C("background:url(https://),url(https://),red url(https://)"),/(url\s*\(.*?){3}/.test(j.background)},s.backgroundsize=function(){return I("backgroundSize")},s.borderimage=function(){return I("borderImage")},s.borderradius=function(){return I("borderRadius")},s.boxshadow=function(){return I("boxShadow")},s.textshadow=function(){return b.createElement("div").style.textShadow===""},s.opacity=function(){return D("opacity:.55"),/^0.55$/.test(j.opacity)},s.cssanimations=function(){return I("animationName")},s.csscolumns=function(){return I("columnCount")},s.cssgradients=function(){var a="background-image:",b="gradient(linear,left top,right bottom,from(#9f9),to(white));",c="linear-gradient(left top,#9f9, white);";return C((a+"-webkit- ".split(" ").join(b+a)+n.join(c+a)).slice(0,-a.length)),F(j.backgroundImage,"gradient")},s.cssreflections=function(){return I("boxReflect")},s.csstransforms=function(){return!!I("transform")},s.csstransforms3d=function(){var a=!!I("perspective");return a&&"webkitPerspective"in g.style&&y("@media (transform-3d),(-webkit-transform-3d){#modernizr{left:9px;position:absolute;height:3px;}}",function(b,c){a=b.offsetLeft===9&&b.offsetHeight===3}),a},s.csstransitions=function(){return I("transition")},s.fontface=function(){var a;return y('@font-face {font-family:"font";src:url("https://")}',function(c,d){var e=b.getElementById("smodernizr"),f=e.sheet||e.styleSheet,g=f?f.cssRules&&f.cssRules[0]?f.cssRules[0].cssText:f.cssText||"":"";a=/src/i.test(g)&&g.indexOf(d.split(" ")[0])===0}),a},s.generatedcontent=function(){var a;return y(["#",h,"{font:0/0 a}#",h,':after{content:"',l,'";visibility:hidden;font:3px/1 a}'].join(""),function(b){a=b.offsetHeight>=3}),a},s.video=function(){var a=b.createElement("video"),c=!1;try{if(c=!!a.canPlayType)c=new Boolean(c),c.ogg=a.canPlayType('video/ogg; codecs="theora"').replace(/^no$/,""),c.h264=a.canPlayType('video/mp4; codecs="avc1.42E01E"').replace(/^no$/,""),c.webm=a.canPlayType('video/webm; codecs="vp8, vorbis"').replace(/^no$/,"")}catch(d){}return c},s.audio=function(){var a=b.createElement("audio"),c=!1;try{if(c=!!a.canPlayType)c=new Boolean(c),c.ogg=a.canPlayType('audio/ogg; codecs="vorbis"').replace(/^no$/,""),c.mp3=a.canPlayType("audio/mpeg;").replace(/^no$/,""),c.wav=a.canPlayType('audio/wav; codecs="1"').replace(/^no$/,""),c.m4a=(a.canPlayType("audio/x-m4a;")||a.canPlayType("audio/aac;")).replace(/^no$/,"")}catch(d){}return c},s.localstorage=function(){try{return localStorage.setItem(h,h),localStorage.removeItem(h),!0}catch(a){return!1}},s.sessionstorage=function(){try{return sessionStorage.setItem(h,h),sessionStorage.removeItem(h),!0}catch(a){return!1}},s.webworkers=function(){return!!a.Worker},s.applicationcache=function(){return!!a.applicationCache},s.svg=function(){return!!b.createElementNS&&!!b.createElementNS(r.svg,"svg").createSVGRect},s.inlinesvg=function(){var a=b.createElement("div");return a.innerHTML="<svg/>",(a.firstChild&&a.firstChild.namespaceURI)==r.svg},s.smil=function(){return!!b.createElementNS&&/SVGAnimate/.test(m.call(b.createElementNS(r.svg,"animate")))},s.svgclippaths=function(){return!!b.createElementNS&&/SVGClipPath/.test(m.call(b.createElementNS(r.svg,"clipPath")))};for(var K in s)B(s,K)&&(x=K.toLowerCase(),e[x]=s[K](),v.push((e[x]?"":"no-")+x));return e.input||J(),e.addTest=function(a,b){if(typeof a=="object")for(var d in a)B(a,d)&&e.addTest(d,a[d]);else{a=a.toLowerCase();if(e[a]!==c)return e;b=typeof b=="function"?b():b,typeof f!="undefined"&&f&&(g.className+=" "+(b?"":"no-")+a),e[a]=b}return e},C(""),i=k=null,function(a,b){function l(a,b){var c=a.createElement("p"),d=a.getElementsByTagName("head")[0]||a.documentElement;return c.innerHTML="x<style>"+b+"</style>",d.insertBefore(c.lastChild,d.firstChild)}function m(){var a=s.elements;return typeof a=="string"?a.split(" "):a}function n(a){var b=j[a[h]];return b||(b={},i++,a[h]=i,j[i]=b),b}function o(a,c,d){c||(c=b);if(k)return c.createElement(a);d||(d=n(c));var g;return d.cache[a]?g=d.cache[a].cloneNode():f.test(a)?g=(d.cache[a]=d.createElem(a)).cloneNode():g=d.createElem(a),g.canHaveChildren&&!e.test(a)&&!g.tagUrn?d.frag.appendChild(g):g}function p(a,c){a||(a=b);if(k)return a.createDocumentFragment();c=c||n(a);var d=c.frag.cloneNode(),e=0,f=m(),g=f.length;for(;e<g;e++)d.createElement(f[e]);return d}function q(a,b){b.cache||(b.cache={},b.createElem=a.createElement,b.createFrag=a.createDocumentFragment,b.frag=b.createFrag()),a.createElement=function(c){return s.shivMethods?o(c,a,b):b.createElem(c)},a.createDocumentFragment=Function("h,f","return function(){var n=f.cloneNode(),c=n.createElement;h.shivMethods&&("+m().join().replace(/[\w\-]+/g,function(a){return b.createElem(a),b.frag.createElement(a),'c("'+a+'")'})+");return n}")(s,b.frag)}function r(a){a||(a=b);var c=n(a);return s.shivCSS&&!g&&!c.hasCSS&&(c.hasCSS=!!l(a,"article,aside,dialog,figcaption,figure,footer,header,hgroup,main,nav,section{display:block}mark{background:#FF0;color:#000}template{display:none}")),k||q(a,c),a}var c="3.7.0",d=a.html5||{},e=/^<|^(?:button|map|select|textarea|object|iframe|option|optgroup)$/i,f=/^(?:a|b|code|div|fieldset|h1|h2|h3|h4|h5|h6|i|label|li|ol|p|q|span|strong|style|table|tbody|td|th|tr|ul)$/i,g,h="_html5shiv",i=0,j={},k;(function(){try{var a=b.createElement("a");a.innerHTML="<xyz></xyz>",g="hidden"in a,k=a.childNodes.length==1||function(){b.createElement("a");var a=b.createDocumentFragment();return typeof a.cloneNode=="undefined"||typeof a.createDocumentFragment=="undefined"||typeof a.createElement=="undefined"}()}catch(c){g=!0,k=!0}})();var s={elements:d.elements||"abbr article aside audio bdi canvas data datalist details dialog figcaption figure footer header hgroup main mark meter nav output progress section summary template time video",version:c,shivCSS:d.shivCSS!==!1,supportsUnknownElements:k,shivMethods:d.shivMethods!==!1,type:"default",shivDocument:r,createElement:o,createDocumentFragment:p};a.html5=s,r(b)}(this,b),e._version=d,e._prefixes=n,e._domPrefixes=q,e._cssomPrefixes=p,e.hasEvent=z,e.testProp=function(a){return G([a])},e.testAllProps=I,e.testStyles=y,e.prefixed=function(a,b,c){return b?I(a,b,c):I(a,"pfx")},g.className=g.className.replace(/(^|\s)no-js(\s|$)/,"$1$2")+(f?" js "+v.join(" "):""),e}(this,this.document),function(a,b,c){function d(a){return"[object Function]"==o.call(a)}function e(a){return"string"==typeof a}function f(){}function g(a){return!a||"loaded"==a||"complete"==a||"uninitialized"==a}function h(){var a=p.shift();q=1,a?a.t?m(function(){("c"==a.t?B.injectCss:B.injectJs)(a.s,0,a.a,a.x,a.e,1)},0):(a(),h()):q=0}function i(a,c,d,e,f,i,j){function k(b){if(!o&&g(l.readyState)&&(u.r=o=1,!q&&h(),l.onload=l.onreadystatechange=null,b)){"img"!=a&&m(function(){t.removeChild(l)},50);for(var d in y[c])y[c].hasOwnProperty(d)&&y[c][d].onload()}}var j=j||B.errorTimeout,l=b.createElement(a),o=0,r=0,u={t:d,s:c,e:f,a:i,x:j};1===y[c]&&(r=1,y[c]=[]),"object"==a?l.data=c:(l.src=c,l.type=a),l.width=l.height="0",l.onerror=l.onload=l.onreadystatechange=function(){k.call(this,r)},p.splice(e,0,u),"img"!=a&&(r||2===y[c]?(t.insertBefore(l,s?null:n),m(k,j)):y[c].push(l))}function j(a,b,c,d,f){return q=0,b=b||"j",e(a)?i("c"==b?v:u,a,b,this.i++,c,d,f):(p.splice(this.i++,0,a),1==p.length&&h()),this}function k(){var a=B;return a.loader={load:j,i:0},a}var l=b.documentElement,m=a.setTimeout,n=b.getElementsByTagName("script")[0],o={}.toString,p=[],q=0,r="MozAppearance"in l.style,s=r&&!!b.createRange().compareNode,t=s?l:n.parentNode,l=a.opera&&"[object Opera]"==o.call(a.opera),l=!!b.attachEvent&&!l,u=r?"object":l?"script":"img",v=l?"script":u,w=Array.isArray||function(a){return"[object Array]"==o.call(a)},x=[],y={},z={timeout:function(a,b){return b.length&&(a.timeout=b[0]),a}},A,B;B=function(a){function b(a){var a=a.split("!"),b=x.length,c=a.pop(),d=a.length,c={url:c,origUrl:c,prefixes:a},e,f,g;for(f=0;f<d;f++)g=a[f].split("="),(e=z[g.shift()])&&(c=e(c,g));for(f=0;f<b;f++)c=x[f](c);return c}function g(a,e,f,g,h){var i=b(a),j=i.autoCallback;i.url.split(".").pop().split("?").shift(),i.bypass||(e&&(e=d(e)?e:e[a]||e[g]||e[a.split("/").pop().split("?")[0]]),i.instead?i.instead(a,e,f,g,h):(y[i.url]?i.noexec=!0:y[i.url]=1,f.load(i.url,i.forceCSS||!i.forceJS&&"css"==i.url.split(".").pop().split("?").shift()?"c":c,i.noexec,i.attrs,i.timeout),(d(e)||d(j))&&f.load(function(){k(),e&&e(i.origUrl,h,g),j&&j(i.origUrl,h,g),y[i.url]=2})))}function h(a,b){function c(a,c){if(a){if(e(a))c||(j=function(){var a=[].slice.call(arguments);k.apply(this,a),l()}),g(a,j,b,0,h);else if(Object(a)===a)for(n in m=function(){var b=0,c;for(c in a)a.hasOwnProperty(c)&&b++;return b}(),a)a.hasOwnProperty(n)&&(!c&&!--m&&(d(j)?j=function(){var a=[].slice.call(arguments);k.apply(this,a),l()}:j[n]=function(a){return function(){var b=[].slice.call(arguments);a&&a.apply(this,b),l()}}(k[n])),g(a[n],j,b,n,h))}else!c&&l()}var h=!!a.test,i=a.load||a.both,j=a.callback||f,k=j,l=a.complete||f,m,n;c(h?a.yep:a.nope,!!i),i&&c(i)}var i,j,l=this.yepnope.loader;if(e(a))g(a,0,l,0);else if(w(a))for(i=0;i<a.length;i++)j=a[i],e(j)?g(j,0,l,0):w(j)?B(j):Object(j)===j&&h(j,l);else Object(a)===a&&h(a,l)},B.addPrefix=function(a,b){z[a]=b},B.addFilter=function(a){x.push(a)},B.errorTimeout=1e4,null==b.readyState&&b.addEventListener&&(b.readyState="loading",b.addEventListener("DOMContentLoaded",A=function(){b.removeEventListener("DOMContentLoaded",A,0),b.readyState="complete"},0)),a.yepnope=k(),a.yepnope.executeStack=h,a.yepnope.injectJs=function(a,c,d,e,i,j){var k=b.createElement("script"),l,o,e=e||B.errorTimeout;k.src=a;for(o in d)k.setAttribute(o,d[o]);c=j?h:c||f,k.onreadystatechange=k.onload=function(){!l&&g(k.readyState)&&(l=1,c(),k.onload=k.onreadystatechange=null)},m(function(){l||(l=1,c(1))},e),i?k.onload():n.parentNode.insertBefore(k,n)},a.yepnope.injectCss=function(a,c,d,e,g,i){var e=b.createElement("link"),j,c=i?h:c||f;e.href=a,e.rel="stylesheet",e.type="text/css";for(j in d)e.setAttribute(j,d[j]);g||(n.parentNode.insertBefore(e,n),m(c,0))}}(this,document),Modernizr.load=function(){yepnope.apply(window,[].slice.call(arguments,0))};var Zepto=(function(){var n,u,F,a,N=[],q=N.slice,G=N.filter,h=window.document,K={},O={},W={"column-count":1,columns:1,"font-weight":1,"line-height":1,opacity:1,"z-index":1,zoom:1},y=/^\s*<(\w+|!)[^>]*>/,M=/^<(\w+)\s*\/?>(?:<\/\1>|)$/,k=/<(?!area|br|col|embed|hr|img|input|link|meta|param)(([\w:]+)[^>]*)\/>/ig,I=/^(?:body|html)$/i,p=/([A-Z])/g,E=["val","css","html","text","data","width","height","offset"],z=["after","prepend","before","append"],v=h.createElement("table"),P=h.createElement("tr"),i={tr:h.createElement("tbody"),tbody:v,thead:v,tfoot:v,td:P,th:P,"*":h.createElement("div")},w=/complete|loaded|interactive/,l=/^[\w-]*$/,e={},g=e.toString,d={},U,Q,H=h.createElement("div"),X={tabindex:"tabIndex",readonly:"readOnly","for":"htmlFor","class":"className",maxlength:"maxLength",cellspacing:"cellSpacing",cellpadding:"cellPadding",rowspan:"rowSpan",colspan:"colSpan",usemap:"useMap",frameborder:"frameBorder",contenteditable:"contentEditable"},B=Array.isArray||function(aa){return aa instanceof Array};d.matches=function(ae,aa){if(!aa||!ae||ae.nodeType!==1){return false}var ac=ae.webkitMatchesSelector||ae.mozMatchesSelector||ae.oMatchesSelector||ae.matchesSelector;if(ac){return ac.call(ae,aa)}var ad,af=ae.parentNode,ab=!af;if(ab){(af=H).appendChild(ae)}ad=~d.qsa(af,aa).indexOf(ae);ab&&H.removeChild(ae);return ad};function Z(aa){return aa==null?String(aa):e[g.call(aa)]||"object"}function r(aa){return Z(aa)=="function"}function L(aa){return aa!=null&&aa==aa.window}function x(aa){return aa!=null&&aa.nodeType==aa.DOCUMENT_NODE}function J(aa){return Z(aa)=="object"}function Y(aa){return J(aa)&&!L(aa)&&Object.getPrototypeOf(aa)==Object.prototype}function C(aa){return typeof aa.length=="number"}function V(aa){return G.call(aa,function(ab){return ab!=null})}function D(aa){return aa.length>0?F.fn.concat.apply([],aa):aa}U=function(aa){return aa.replace(/-+(.)?/g,function(ab,ac){return ac?ac.toUpperCase():""})};function o(aa){return aa.replace(/::/g,"/").replace(/([A-Z]+)([A-Z][a-z])/g,"$1_$2").replace(/([a-z\d])([A-Z])/g,"$1_$2").replace(/_/g,"-").toLowerCase()}Q=function(aa){return G.call(aa,function(ac,ab){return aa.indexOf(ac)==ab})};function R(aa){return aa in O?O[aa]:(O[aa]=new RegExp("(^|\\s)"+aa+"(\\s|$)"))}function f(aa,ab){return(typeof ab=="number"&&!W[o(aa)])?ab+"px":ab}function S(ac){var aa,ab;if(!K[ac]){aa=h.createElement(ac);h.body.appendChild(aa);ab=getComputedStyle(aa,"").getPropertyValue("display");aa.parentNode.removeChild(aa);ab=="none"&&(ab="block");K[ac]=ab}return K[ac]}function t(aa){return"children" in aa?q.call(aa.children):F.map(aa.childNodes,function(ab){if(ab.nodeType==1){return ab}})}d.fragment=function(ae,ac,ad){var af,ab,aa;if(M.test(ae)){af=F(h.createElement(RegExp.$1))}if(!af){if(ae.replace){ae=ae.replace(k,"<$1></$2>")}if(ac===n){ac=y.test(ae)&&RegExp.$1}if(!(ac in i)){ac="*"}aa=i[ac];aa.innerHTML=""+ae;af=F.each(q.call(aa.childNodes),function(){aa.removeChild(this)})}if(Y(ad)){ab=F(af);F.each(ad,function(ag,ah){if(E.indexOf(ag)>-1){ab[ag](ah)}else{ab.attr(ag,ah)}})}return af};d.Z=function(ab,aa){ab=ab||[];ab.__proto__=F.fn;ab.selector=aa||"";return ab};d.isZ=function(aa){return aa instanceof d.Z};d.init=function(aa,ab){var ac;if(!aa){return d.Z()}else{if(typeof aa=="string"){aa=aa.trim();if(aa[0]=="<"&&y.test(aa)){ac=d.fragment(aa,RegExp.$1,ab),aa=null}else{if(ab!==n){return F(ab).find(aa)}else{ac=d.qsa(h,aa)}}}else{if(r(aa)){return F(h).ready(aa)}else{if(d.isZ(aa)){return aa}else{if(B(aa)){ac=V(aa)}else{if(J(aa)){ac=[aa],aa=null}else{if(y.test(aa)){ac=d.fragment(aa.trim(),RegExp.$1,ab),aa=null}else{if(ab!==n){return F(ab).find(aa)}else{ac=d.qsa(h,aa)}}}}}}}}return d.Z(ac,aa)};F=function(aa,ab){return d.init(aa,ab)};function m(ac,ab,aa){for(u in ab){if(aa&&(Y(ab[u])||B(ab[u]))){if(Y(ab[u])&&!Y(ac[u])){ac[u]={}}if(B(ab[u])&&!B(ac[u])){ac[u]=[]}m(ac[u],ab[u],aa)}else{if(ab[u]!==n){ac[u]=ab[u]}}}}F.extend=function(ac){var aa,ab=q.call(arguments,1);if(typeof ac=="boolean"){aa=ac;ac=ab.shift()}ab.forEach(function(ad){m(ac,ad,aa)});return ac};d.qsa=function(ac,aa){var af,ag=aa[0]=="#",ab=!ag&&aa[0]==".",ad=ag||ab?aa.slice(1):aa,ae=l.test(ad);return(x(ac)&&ae&&ag)?((af=ac.getElementById(ad))?[af]:[]):(ac.nodeType!==1&&ac.nodeType!==9)?[]:q.call(ae&&!ag?ab?ac.getElementsByClassName(ad):ac.getElementsByTagName(aa):ac.querySelectorAll(aa))};function A(ab,aa){return aa==null?F(ab):F(ab).filter(aa)}F.contains=function(aa,ab){return aa!==ab&&aa.contains(ab)};function s(ac,ab,aa,ad){return r(ab)?ab.call(ac,aa,ad):ab}function b(ab,aa,ac){ac==null?ab.removeAttribute(aa):ab.setAttribute(aa,ac)}function T(ac,ad){var aa=ac.className,ab=aa&&aa.baseVal!==n;if(ad===n){return ab?aa.baseVal:aa}ab?(aa.baseVal=ad):(ac.className=ad)}function j(ab){var aa;try{return ab?ab=="true"||(ab=="false"?false:ab=="null"?null:!/^0/.test(ab)&&!isNaN(aa=Number(ab))?aa:/^[\[\{]/.test(ab)?F.parseJSON(ab):ab):ab}catch(ac){return ab}}F.type=Z;F.isFunction=r;F.isWindow=L;F.isArray=B;F.isPlainObject=Y;F.isEmptyObject=function(ab){var aa;for(aa in ab){return false}return true};F.inArray=function(ab,ac,aa){return N.indexOf.call(ac,ab,aa)};F.camelCase=U;F.trim=function(aa){return aa==null?"":String.prototype.trim.call(aa)};F.uuid=0;F.support={};F.expr={};F.map=function(ae,af){var ad,aa=[],ac,ab;if(C(ae)){for(ac=0;ac<ae.length;ac++){ad=af(ae[ac],ac);if(ad!=null){aa.push(ad)}}}else{for(ab in ae){ad=af(ae[ab],ab);if(ad!=null){aa.push(ad)}}}return D(aa)};F.each=function(ac,ad){var ab,aa;if(C(ac)){for(ab=0;ab<ac.length;ab++){if(ad.call(ac[ab],ab,ac[ab])===false){return ac}}}else{for(aa in ac){if(ad.call(ac[aa],aa,ac[aa])===false){return ac}}}return ac};F.grep=function(aa,ab){return G.call(aa,ab)};if(window.JSON){F.parseJSON=JSON.parse}F.each("Boolean Number String Function Array Date RegExp Object Error".split(" "),function(ab,aa){e["[object "+aa+"]"]=aa.toLowerCase()});F.fn={forEach:N.forEach,reduce:N.reduce,push:N.push,sort:N.sort,indexOf:N.indexOf,concat:N.concat,map:function(aa){return F(F.map(this,function(ac,ab){return aa.call(ac,ab,ac)}))},slice:function(){return F(q.apply(this,arguments))},ready:function(aa){if(w.test(h.readyState)&&h.body){aa(F)}else{h.addEventListener("DOMContentLoaded",function(){aa(F)},false)}return this},get:function(aa){return aa===n?q.call(this):this[aa>=0?aa:aa+this.length]},toArray:function(){return this.get()},size:function(){return this.length},remove:function(){return this.each(function(){if(this.parentNode!=null){this.parentNode.removeChild(this)}})},each:function(aa){N.every.call(this,function(ac,ab){return aa.call(ac,ab,ac)!==false});return this},filter:function(aa){if(r(aa)){return this.not(this.not(aa))}return F(G.call(this,function(ab){return d.matches(ab,aa)}))},add:function(aa,ab){return F(Q(this.concat(F(aa,ab))))},is:function(aa){return this.length>0&&d.matches(this[0],aa)},not:function(aa){var ab=[];if(r(aa)&&aa.call!==n){this.each(function(ad){if(!aa.call(this,ad)){ab.push(this)}})}else{var ac=typeof aa=="string"?this.filter(aa):(C(aa)&&r(aa.item))?q.call(aa):F(aa);this.forEach(function(ad){if(ac.indexOf(ad)<0){ab.push(ad)}})}return F(ab)},has:function(aa){return this.filter(function(){return J(aa)?F.contains(this,aa):F(this).find(aa).size()})},eq:function(aa){return aa===-1?this.slice(aa):this.slice(aa,+aa+1)},first:function(){var aa=this[0];return aa&&!J(aa)?aa:F(aa)},last:function(){var aa=this[this.length-1];return aa&&!J(aa)?aa:F(aa)},find:function(ab){var aa,ac=this;if(typeof ab=="object"){aa=F(ab).filter(function(){var ad=this;return N.some.call(ac,function(ae){return F.contains(ae,ad)})})}else{if(this.length==1){aa=F(d.qsa(this[0],ab))}else{aa=this.map(function(){return d.qsa(this,ab)})}}return aa},closest:function(aa,ab){var ac=this[0],ad=false;if(typeof aa=="object"){ad=F(aa)}while(ac&&!(ad?ad.indexOf(ac)>=0:d.matches(ac,aa))){ac=ac!==ab&&!x(ac)&&ac.parentNode}return F(ac)},parents:function(aa){var ac=[],ab=this;while(ab.length>0){ab=F.map(ab,function(ad){if((ad=ad.parentNode)&&!x(ad)&&ac.indexOf(ad)<0){ac.push(ad);return ad}})}return A(ac,aa)},parent:function(aa){return A(Q(this.pluck("parentNode")),aa)},children:function(aa){return A(this.map(function(){return t(this)}),aa)},contents:function(){return this.map(function(){return q.call(this.childNodes)})},siblings:function(aa){return A(this.map(function(ab,ac){return G.call(t(ac.parentNode),function(ad){return ad!==ac})}),aa)},empty:function(){return this.each(function(){this.innerHTML=""})},pluck:function(aa){return F.map(this,function(ab){return ab[aa]})},show:function(){return this.each(function(){this.style.display=="none"&&(this.style.display="");if(getComputedStyle(this,"").getPropertyValue("display")=="none"){this.style.display=S(this.nodeName)}})},replaceWith:function(aa){return this.before(aa).remove()},wrap:function(aa){var ab=r(aa);if(this[0]&&!ab){var ac=F(aa).get(0),ad=ac.parentNode||this.length>1}return this.each(function(ae){F(this).wrapAll(ab?aa.call(this,ae):ad?ac.cloneNode(true):ac)})},wrapAll:function(aa){if(this[0]){F(this[0]).before(aa=F(aa));var ab;while((ab=aa.children()).length){aa=ab.first()}F(aa).append(this)}return this},wrapInner:function(aa){var ab=r(aa);return this.each(function(ad){var ac=F(this),ae=ac.contents(),af=ab?aa.call(this,ad):aa;ae.length?ae.wrapAll(af):ac.append(af)})},unwrap:function(){this.parent().each(function(){F(this).replaceWith(F(this).children())});return this},clone:function(){return this.map(function(){return this.cloneNode(true)})},hide:function(){return this.css("display","none")},toggle:function(aa){return this.each(function(){var ab=F(this);(aa===n?ab.css("display")=="none":aa)?ab.show():ab.hide()})},prev:function(aa){return F(this.pluck("previousElementSibling")).filter(aa||"*")},next:function(aa){return F(this.pluck("nextElementSibling")).filter(aa||"*")},html:function(aa){return arguments.length===0?(this.length>0?this[0].innerHTML:null):this.each(function(ab){var ac=this.innerHTML;F(this).empty().append(s(this,aa,ab,ac))})},text:function(aa){return arguments.length===0?(this.length>0?this[0].textContent:null):this.each(function(){this.textContent=(aa===n)?"":""+aa})},attr:function(ab,ac){var aa;return(typeof ab=="string"&&ac===n)?(this.length==0||this[0].nodeType!==1?n:(ab=="value"&&this[0].nodeName=="INPUT")?this.val():(!(aa=this[0].getAttribute(ab))&&ab in this[0])?this[0][ab]:aa):this.each(function(ad){if(this.nodeType!==1){return}if(J(ab)){for(u in ab){b(this,u,ab[u])}}else{b(this,ab,s(this,ac,ad,this.getAttribute(ab)))}})},removeAttr:function(aa){return this.each(function(){this.nodeType===1&&b(this,aa)})},prop:function(aa,ab){aa=X[aa]||aa;return(ab===n)?(this[0]&&this[0][aa]):this.each(function(ac){this[aa]=s(this,ab,ac,this[aa])})},data:function(aa,ac){var ab=this.attr("data-"+aa.replace(p,"-$1").toLowerCase(),ac);return ab!==null?j(ab):n},val:function(aa){return arguments.length===0?(this[0]&&(this[0].multiple?F(this[0]).find("option").filter(function(){return this.selected}).pluck("value"):this[0].value)):this.each(function(ab){this.value=s(this,aa,ab,this.value)})},offset:function(ab){if(ab){return this.each(function(ad){var ag=F(this),af=s(this,ab,ad,ag.offset()),ac=ag.offsetParent().offset(),ae={top:af.top-ac.top,left:af.left-ac.left};if(ag.css("position")=="static"){ae.position="relative"}ag.css(ae)})}if(this.length==0){return null}var aa=this[0].getBoundingClientRect();return{left:aa.left+window.pageXOffset,top:aa.top+window.pageYOffset,width:Math.round(aa.width),height:Math.round(aa.height)}},css:function(af,ae){if(arguments.length<2){var ac=this[0],aa=getComputedStyle(ac,"");if(!ac){return}if(typeof af=="string"){return ac.style[U(af)]||aa.getPropertyValue(af)}else{if(B(af)){var ad={};F.each(B(af)?af:[af],function(ag,ah){ad[ah]=(ac.style[U(ah)]||aa.getPropertyValue(ah))});return ad}}}var ab="";if(Z(af)=="string"){if(!ae&&ae!==0){this.each(function(){this.style.removeProperty(o(af))})}else{ab=o(af)+":"+f(af,ae)}}else{for(u in af){if(!af[u]&&af[u]!==0){this.each(function(){this.style.removeProperty(o(u))})}else{ab+=o(u)+":"+f(u,af[u])+";"}}}return this.each(function(){this.style.cssText+=";"+ab})},index:function(aa){return aa?this.indexOf(F(aa)[0]):this.parent().children().indexOf(this[0])},hasClass:function(aa){if(!aa){return false}return N.some.call(this,function(ab){return this.test(T(ab))},R(aa))},addClass:function(aa){if(!aa){return this}return this.each(function(ab){a=[];var ad=T(this),ac=s(this,aa,ab,ad);ac.split(/\s+/g).forEach(function(ae){if(!F(this).hasClass(ae)){a.push(ae)}},this);a.length&&T(this,ad+(ad?" ":"")+a.join(" "))})},removeClass:function(aa){return this.each(function(ab){if(aa===n){return T(this,"")}a=T(this);s(this,aa,ab,a).split(/\s+/g).forEach(function(ac){a=a.replace(R(ac)," ")});T(this,a.trim())})},toggleClass:function(ab,aa){if(!ab){return this}return this.each(function(ac){var ae=F(this),ad=s(this,ab,ac,T(this));ad.split(/\s+/g).forEach(function(af){(aa===n?!ae.hasClass(af):aa)?ae.addClass(af):ae.removeClass(af)})})},scrollTop:function(ab){if(!this.length){return}var aa="scrollTop" in this[0];if(ab===n){return aa?this[0].scrollTop:this[0].pageYOffset}return this.each(aa?function(){this.scrollTop=ab}:function(){this.scrollTo(this.scrollX,ab)})},scrollLeft:function(ab){if(!this.length){return}var aa="scrollLeft" in this[0];if(ab===n){return aa?this[0].scrollLeft:this[0].pageXOffset}return this.each(aa?function(){this.scrollLeft=ab}:function(){this.scrollTo(ab,this.scrollY)})},position:function(){if(!this.length){return}var ac=this[0],ab=this.offsetParent(),ad=this.offset(),aa=I.test(ab[0].nodeName)?{top:0,left:0}:ab.offset();ad.top-=parseFloat(F(ac).css("margin-top"))||0;ad.left-=parseFloat(F(ac).css("margin-left"))||0;aa.top+=parseFloat(F(ab[0]).css("border-top-width"))||0;aa.left+=parseFloat(F(ab[0]).css("border-left-width"))||0;return{top:ad.top-aa.top,left:ad.left-aa.left}},offsetParent:function(){return this.map(function(){var aa=this.offsetParent||h.body;while(aa&&!I.test(aa.nodeName)&&F(aa).css("position")=="static"){aa=aa.offsetParent}return aa})}};F.fn.detach=F.fn.remove;["width","height"].forEach(function(ab){var aa=ab.replace(/./,function(ac){return ac[0].toUpperCase()});F.fn[ab]=function(ad){var ae,ac=this[0];if(ad===n){return L(ac)?ac["inner"+aa]:x(ac)?ac.documentElement["scroll"+aa]:(ae=this.offset())&&ae[ab]}else{return this.each(function(af){ac=F(this);ac.css(ab,s(this,ad,af,ac[ab]()))})}}});function c(ac,aa){aa(ac);for(var ab in ac.childNodes){c(ac.childNodes[ab],aa)}}z.forEach(function(ac,ab){var aa=ab%2;F.fn[ac]=function(){var ad,ae=F.map(arguments,function(ah){ad=Z(ah);return ad=="object"||ad=="array"||ah==null?ah:d.fragment(ah)}),af,ag=this.length>1;if(ae.length<1){return this}return this.each(function(ah,ai){af=aa?ai:ai.parentNode;ai=ab==0?ai.nextSibling:ab==1?ai.firstChild:ab==2?ai:null;ae.forEach(function(aj){if(ag){aj=aj.cloneNode(true)}else{if(!af){return F(aj).remove()}}c(af.insertBefore(aj,ai),function(ak){if(ak.nodeName!=null&&ak.nodeName.toUpperCase()==="SCRIPT"&&(!ak.type||ak.type==="text/javascript")&&!ak.src){window["eval"].call(window,ak.innerHTML)}})})})};F.fn[aa?ac+"To":"insert"+(ab?"Before":"After")]=function(ad){F(ad)[ac](this);return this}});d.Z.prototype=F.fn;d.uniq=Q;d.deserializeValue=j;F.zepto=d;return F})();window.Zepto=Zepto;window.$===undefined&&(window.$=Zepto);(function(d){var f=1,h,s=Array.prototype.slice,a=d.isFunction,k=function(z){return typeof z=="string"},r={},o={},g="onfocusin" in window,p={focus:"focusin",blur:"focusout"},w={mouseenter:"mouseover",mouseleave:"mouseout"};o.click=o.mousedown=o.mouseup=o.mousemove="MouseEvents";function b(z){return z._zid||(z._zid=f++)}function l(A,C,B,z){C=q(C);if(C.ns){var D=v(C.ns)}return(r[b(A)]||[]).filter(function(E){return E&&(!C.e||E.e==C.e)&&(!C.ns||D.test(E.ns))&&(!B||b(E.fn)===b(B))&&(!z||E.sel==z)})}function q(z){var A=(""+z).split(".");return{e:A[0],ns:A.slice(1).sort().join(" ")}}function v(z){return new RegExp("(?:^| )"+z.replace(" "," .* ?")+"(?: |$)")}function j(z,A){return z.del&&(!g&&(z.e in p))||!!A}function u(z){return w[z]||(g&&p[z])||z}function n(C,G,D,B,A,H,F){var z=b(C),E=(r[z]||(r[z]=[]));G.split(/\s/).forEach(function(J){if(J=="ready"){return d(document).ready(D)}var I=q(J);I.fn=D;I.sel=A;if(I.e in w){D=function(M){var L=M.relatedTarget;if(!L||(L!==this&&!d.contains(this,L))){return I.fn.apply(this,arguments)}}}I.del=H;var K=H||D;I.proxy=function(M){M=x(M);if(M.isImmediatePropagationStopped()){return}M.data=B;var L=K.apply(C,M._args==h?[M]:[M].concat(M._args));if(L===false){M.preventDefault(),M.stopPropagation()}return L};I.i=E.length;E.push(I);if("addEventListener" in C){C.addEventListener(u(I.e),I.proxy,j(I,F))}})}function y(C,B,D,z,A){var E=b(C);(B||"").split(/\s/).forEach(function(F){l(C,F,D,z).forEach(function(G){delete r[E][G.i];if("removeEventListener" in C){C.removeEventListener(u(G.e),G.proxy,j(G,A))}})})}d.event={add:n,remove:y};d.proxy=function(B,A){if(a(B)){var z=function(){return B.apply(A,arguments)};z._zid=b(B);return z}else{if(k(A)){return d.proxy(B[A],B)}else{throw new TypeError("expected function")}}};d.fn.bind=function(z,A,B){return this.on(z,A,B)};d.fn.unbind=function(z,A){return this.off(z,A)};d.fn.one=function(A,z,B,C){return this.on(A,z,B,C,1)};var t=function(){return true},i=function(){return false},e=/^([A-Z]|returnValue$|layer[XY]$)/,m={preventDefault:"isDefaultPrevented",stopImmediatePropagation:"isImmediatePropagationStopped",stopPropagation:"isPropagationStopped"};function x(z,A){if(A||!z.isDefaultPrevented){A||(A=z);d.each(m,function(C,B){var D=A[C];z[C]=function(){this[B]=t;return D&&D.apply(A,arguments)};z[B]=i});if(A.defaultPrevented!==h?A.defaultPrevented:"returnValue" in A?A.returnValue===false:A.getPreventDefault&&A.getPreventDefault()){z.isDefaultPrevented=t}}return z}function c(B){var A,z={originalEvent:B};for(A in B){if(!e.test(A)&&B[A]!==h){z[A]=B[A]}}return x(z,B)}d.fn.delegate=function(z,A,B){return this.on(A,z,B)};d.fn.undelegate=function(z,A,B){return this.off(A,z,B)};d.fn.live=function(z,A){d(document.body).delegate(this.selector,z,A);return this};d.fn.die=function(z,A){d(document.body).undelegate(this.selector,z,A);return this};d.fn.on=function(D,z,E,G,C){var B,A,F=this;if(D&&!k(D)){d.each(D,function(I,H){F.on(I,z,E,H,C)});return F}if(!k(z)&&!a(G)&&G!==false){G=E,E=z,z=h}if(a(E)||E===false){G=E,E=h}if(G===false){G=i}return F.each(function(H,I){if(C){B=function(J){y(I,J.type,G);return G.apply(this,arguments)}}if(z){A=function(L){var J,K=d(L.target).closest(z,I).get(0);if(K&&K!==I){J=d.extend(c(L),{currentTarget:K,liveFired:I});return(B||G).apply(K,[J].concat(s.call(arguments,1)))}}}n(I,D,G,E,z,A||B)})};d.fn.off=function(A,z,C){var B=this;if(A&&!k(A)){d.each(A,function(E,D){B.off(E,z,D)});return B}if(!k(z)&&!a(C)&&C!==false){C=z,z=h}if(C===false){C=i}return B.each(function(){y(this,A,C,z)})};d.fn.trigger=function(A,z){A=(k(A)||d.isPlainObject(A))?d.Event(A):x(A);A._args=z;return this.each(function(){if("dispatchEvent" in this){this.dispatchEvent(A)}else{d(this).triggerHandler(A,z)}})};d.fn.triggerHandler=function(B,A){var C,z;this.each(function(E,D){C=c(k(B)?d.Event(B):B);C._args=A;C.target=D;d.each(l(D,B.type||B),function(F,G){z=G.proxy(C);if(C.isImmediatePropagationStopped()){return false}})});return z};("focusin focusout load resize scroll unload click dblclick mousedown mouseup mousemove mouseover mouseout mouseenter mouseleave change select keydown keypress keyup error").split(" ").forEach(function(z){d.fn[z]=function(A){return A?this.bind(z,A):this.trigger(z)}});["focus","blur"].forEach(function(z){d.fn[z]=function(A){if(A){this.bind(z,A)}else{this.each(function(){try{this[z]()}catch(B){}})}return this}});d.Event=function(C,B){if(!k(C)){B=C,C=B.type}var D=document.createEvent(o[C]||"Events"),z=true;if(B){for(var A in B){(A=="bubbles")?(z=!!B[A]):(D[A]=B[A])}}D.initEvent(C,z,true);return x(D)}})(Zepto);(function($){var jsonpID=0,document=window.document,key,name,rscript=/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,scriptTypeRE=/^(?:text|application)\/javascript/i,xmlTypeRE=/^(?:text|application)\/xml/i,jsonType="application/json",htmlType="text/html",blankRE=/^\s*$/;function triggerAndReturn(context,eventName,data){var event=$.Event(eventName);$(context).trigger(event,data);return !event.isDefaultPrevented()}function triggerGlobal(settings,context,eventName,data){if(settings.global){return triggerAndReturn(context||document,eventName,data)}}$.active=0;function ajaxStart(settings){if(settings.global&&$.active++===0){triggerGlobal(settings,null,"ajaxStart")}}function ajaxStop(settings){if(settings.global&&!(--$.active)){triggerGlobal(settings,null,"ajaxStop")}}function ajaxBeforeSend(xhr,settings){var context=settings.context;if(settings.beforeSend.call(context,xhr,settings)===false||triggerGlobal(settings,context,"ajaxBeforeSend",[xhr,settings])===false){return false}triggerGlobal(settings,context,"ajaxSend",[xhr,settings])}function ajaxSuccess(data,xhr,settings,deferred){var context=settings.context,status="success";settings.success.call(context,data,status,xhr);if(deferred){deferred.resolveWith(context,[data,status,xhr])}triggerGlobal(settings,context,"ajaxSuccess",[xhr,settings,data]);ajaxComplete(status,xhr,settings)}function ajaxError(error,type,xhr,settings,deferred){var context=settings.context;settings.error.call(context,xhr,type,error);if(deferred){deferred.rejectWith(context,[xhr,type,error])}triggerGlobal(settings,context,"ajaxError",[xhr,settings,error||type]);ajaxComplete(type,xhr,settings)}function ajaxComplete(status,xhr,settings){var context=settings.context;settings.complete.call(context,xhr,status);triggerGlobal(settings,context,"ajaxComplete",[xhr,settings]);ajaxStop(settings)}function empty(){}$.ajaxJSONP=function(options,deferred){if(!("type" in options)){return $.ajax(options)}var _callbackName=options.jsonpCallback,callbackName=($.isFunction(_callbackName)?_callbackName():_callbackName)||("jsonp"+(++jsonpID)),script=document.createElement("script"),originalCallback=window[callbackName],responseData,abort=function(errorType){$(script).triggerHandler("error",errorType||"abort")},xhr={abort:abort},abortTimeout;if(deferred){deferred.promise(xhr)}$(script).on("load error",function(e,errorType){clearTimeout(abortTimeout);$(script).off().remove();if(e.type=="error"||!responseData){ajaxError(null,errorType||"error",xhr,options,deferred)}else{ajaxSuccess(responseData[0],xhr,options,deferred)}window[callbackName]=originalCallback;if(responseData&&$.isFunction(originalCallback)){originalCallback(responseData[0])}originalCallback=responseData=undefined});if(ajaxBeforeSend(xhr,options)===false){abort("abort");return xhr}window[callbackName]=function(){responseData=arguments};script.src=options.url.replace(/\?(.+)=\?/,"?$1="+callbackName);document.head.appendChild(script);if(options.timeout>0){abortTimeout=setTimeout(function(){abort("timeout")},options.timeout)}return xhr};$.ajaxSettings={type:"GET",beforeSend:empty,success:empty,error:empty,complete:empty,context:null,global:true,xhr:function(){return new window.XMLHttpRequest()},accepts:{script:"text/javascript, application/javascript, application/x-javascript",json:jsonType,xml:"application/xml, text/xml",html:htmlType,text:"text/plain"},crossDomain:false,timeout:0,processData:true,cache:true};function mimeToDataType(mime){if(mime){mime=mime.split(";",2)[0]}return mime&&(mime==htmlType?"html":mime==jsonType?"json":scriptTypeRE.test(mime)?"script":xmlTypeRE.test(mime)&&"xml")||"text"}function appendQuery(url,query){if(query==""){return url}return(url+"&"+query).replace(/[&?]{1,2}/,"?")}function serializeData(options){if(options.processData&&options.data&&$.type(options.data)!="string"){options.data=$.param(options.data,options.traditional)}if(options.data&&(!options.type||options.type.toUpperCase()=="GET")){options.url=appendQuery(options.url,options.data),options.data=undefined}}$.ajax=function(options){var settings=$.extend({},options||{}),deferred=$.Deferred&&$.Deferred();for(key in $.ajaxSettings){if(settings[key]===undefined){settings[key]=$.ajaxSettings[key]}}ajaxStart(settings);if(!settings.crossDomain){settings.crossDomain=/^([\w-]+:)?\/\/([^\/]+)/.test(settings.url)&&RegExp.$2!=window.location.host}if(!settings.url){settings.url=window.location.toString()}serializeData(settings);if(settings.cache===false){settings.url=appendQuery(settings.url,"_="+Date.now())}var dataType=settings.dataType,hasPlaceholder=/\?.+=\?/.test(settings.url);if(dataType=="jsonp"||hasPlaceholder){if(!hasPlaceholder){settings.url=appendQuery(settings.url,settings.jsonp?(settings.jsonp+"=?"):settings.jsonp===false?"":"callback=?")}return $.ajaxJSONP(settings,deferred)}var mime=settings.accepts[dataType],headers={},setHeader=function(name,value){headers[name.toLowerCase()]=[name,value]},protocol=/^([\w-]+:)\/\//.test(settings.url)?RegExp.$1:window.location.protocol,xhr=settings.xhr(),nativeSetHeader=xhr.setRequestHeader,abortTimeout;if(deferred){deferred.promise(xhr)}if(!settings.crossDomain){setHeader("X-Requested-With","XMLHttpRequest")}setHeader("Accept",mime||"*/*");if(mime=settings.mimeType||mime){if(mime.indexOf(",")>-1){mime=mime.split(",",2)[0]}xhr.overrideMimeType&&xhr.overrideMimeType(mime)}if(settings.contentType||(settings.contentType!==false&&settings.data&&settings.type.toUpperCase()!="GET")){setHeader("Content-Type",settings.contentType||"application/x-www-form-urlencoded")}if(settings.headers){for(name in settings.headers){setHeader(name,settings.headers[name])}}xhr.setRequestHeader=setHeader;xhr.onreadystatechange=function(){if(xhr.readyState==4){xhr.onreadystatechange=empty;clearTimeout(abortTimeout);var result,error=false;if((xhr.status>=200&&xhr.status<300)||xhr.status==304||(xhr.status==0&&protocol=="file:")){dataType=dataType||mimeToDataType(settings.mimeType||xhr.getResponseHeader("content-type"));result=xhr.responseText;try{if(dataType=="script"){(1,eval)(result)}else{if(dataType=="xml"){result=xhr.responseXML}else{if(dataType=="json"){result=blankRE.test(result)?null:$.parseJSON(result)}}}}catch(e){error=e}if(error){ajaxError(error,"parsererror",xhr,settings,deferred)}else{ajaxSuccess(result,xhr,settings,deferred)}}else{ajaxError(xhr.statusText||null,xhr.status?"error":"abort",xhr,settings,deferred)}}};if(ajaxBeforeSend(xhr,settings)===false){xhr.abort();ajaxError(null,"abort",xhr,settings,deferred);return xhr}if(settings.xhrFields){for(name in settings.xhrFields){xhr[name]=settings.xhrFields[name]}}var async="async" in settings?settings.async:true;xhr.open(settings.type,settings.url,async,settings.username,settings.password);for(name in headers){nativeSetHeader.apply(xhr,headers[name])}if(settings.timeout>0){abortTimeout=setTimeout(function(){xhr.onreadystatechange=empty;xhr.abort();ajaxError(null,"timeout",xhr,settings,deferred)},settings.timeout)}xhr.send(settings.data?settings.data:null);return xhr};function parseArguments(url,data,success,dataType){if($.isFunction(data)){dataType=success,success=data,data=undefined}if(!$.isFunction(success)){dataType=success,success=undefined}return{url:url,data:data,success:success,dataType:dataType}}$.get=function(){return $.ajax(parseArguments.apply(null,arguments))};$.post=function(){var options=parseArguments.apply(null,arguments);options.type="POST";return $.ajax(options)};$.getJSON=function(){var options=parseArguments.apply(null,arguments);options.dataType="json";return $.ajax(options)};$.fn.load=function(url,data,success){if(!this.length){return this}var self=this,parts=url.split(/\s/),selector,options=parseArguments(url,data,success),callback=options.success;if(parts.length>1){options.url=parts[0],selector=parts[1]}options.success=function(response){self.html(selector?$("<div>").html(response.replace(rscript,"")).find(selector):response);callback&&callback.apply(self,arguments)};$.ajax(options);return this};var escape=encodeURIComponent;function serialize(params,obj,traditional,scope){var type,array=$.isArray(obj),hash=$.isPlainObject(obj);$.each(obj,function(key,value){type=$.type(value);if(scope){key=traditional?scope:scope+"["+(hash||type=="object"||type=="array"?key:"")+"]"}if(!scope&&array){params.add(value.name,value.value)}else{if(type=="array"||(!traditional&&type=="object")){serialize(params,value,traditional,key)}else{params.add(key,value)}}})}$.param=function(obj,traditional){var params=[];params.add=function(k,v){this.push(escape(k)+"="+escape(v))};serialize(params,obj,traditional);return params.join("&").replace(/%20/g,"+")}})(Zepto);(function(a){a.fn.serializeArray=function(){var b=[],c;a([].slice.call(this.get(0).elements)).each(function(){c=a(this);var d=c.attr("type");if(this.nodeName.toLowerCase()!="fieldset"&&!this.disabled&&d!="submit"&&d!="reset"&&d!="button"&&((d!="radio"&&d!="checkbox")||this.checked)){b.push({name:c.attr("name"),value:c.val()})}});return b};a.fn.serialize=function(){var b=[];this.serializeArray().forEach(function(c){b.push(encodeURIComponent(c.name)+"="+encodeURIComponent(c.value))});return b.join("&")};a.fn.submit=function(c){if(c){this.bind("submit",c)}else{if(this.length){var b=a.Event("submit");this.eq(0).trigger(b);if(!b.isDefaultPrevented()){this.get(0).submit()}}}return this}})(Zepto);(function(b){if(!("__proto__" in {})){b.extend(b.zepto,{Z:function(e,d){e=e||[];b.extend(e,b.fn);e.selector=d||"";e.__Z=true;return e},isZ:function(d){return b.type(d)==="array"&&"__Z" in d}})}try{getComputedStyle(undefined)}catch(c){var a=getComputedStyle;window.getComputedStyle=function(d){try{return a(d)}catch(f){return null}}}})(Zepto);(function(b){var a=function(d,h,g){var e=document.getElementsByTagName("head")[0],f=document.createElement("script");f.setAttribute("type","text/javascript");f.setAttribute("src",d);if(g){f.setAttribute("charset",g)}e.appendChild(f);var c=function(){if(typeof h==="function"){h()}};if(document.all){f.onreadystatechange=function(){if(f.readyState=="loaded"||f.readyState=="complete"){c()}}}else{f.onload=function(){c()}}};if(Zepto){b.getScript=a}})(Zepto);
/**
 * StyleFix 1.0.3 & PrefixFree 1.0.7
 * @author Lea Verou
 * MIT license
 */(function(){function t(e,t){return[].slice.call((t||document).querySelectorAll(e))}if(!window.addEventListener)return;var e=window.StyleFix={link:function(t){try{if(t.rel!=="stylesheet"||t.hasAttribute("data-noprefix"))return}catch(n){return}var r=t.href||t.getAttribute("data-href"),i=r.replace(/[^\/]+$/,""),s=(/^[a-z]{3,10}:/.exec(i)||[""])[0],o=(/^[a-z]{3,10}:\/\/[^\/]+/.exec(i)||[""])[0],u=/^([^?]*)\??/.exec(r)[1],a=t.parentNode,f=new XMLHttpRequest,l;f.onreadystatechange=function(){f.readyState===4&&l()};l=function(){var n=f.responseText;if(n&&t.parentNode&&(!f.status||f.status<400||f.status>600)){n=e.fix(n,!0,t);if(i){n=n.replace(/url\(\s*?((?:"|')?)(.+?)\1\s*?\)/gi,function(e,t,n){return/^([a-z]{3,10}:|#)/i.test(n)?e:/^\/\//.test(n)?'url("'+s+n+'")':/^\//.test(n)?'url("'+o+n+'")':/^\?/.test(n)?'url("'+u+n+'")':'url("'+i+n+'")'});var r=i.replace(/([\\\^\$*+[\]?{}.=!:(|)])/g,"\\$1");n=n.replace(RegExp("\\b(behavior:\\s*?url\\('?\"?)"+r,"gi"),"$1")}var l=document.createElement("style");l.textContent=n;l.media=t.media;l.disabled=t.disabled;l.setAttribute("data-href",t.getAttribute("href"));a.insertBefore(l,t);a.removeChild(t);l.media=t.media}};try{f.open("GET",r);f.send(null)}catch(n){if(typeof XDomainRequest!="undefined"){f=new XDomainRequest;f.onerror=f.onprogress=function(){};f.onload=l;f.open("GET",r);f.send(null)}}t.setAttribute("data-inprogress","")},styleElement:function(t){if(t.hasAttribute("data-noprefix"))return;var n=t.disabled;t.textContent=e.fix(t.textContent,!0,t);t.disabled=n},styleAttribute:function(t){var n=t.getAttribute("style");n=e.fix(n,!1,t);t.setAttribute("style",n)},process:function(){t('link[rel="stylesheet"]:not([data-inprogress])').forEach(StyleFix.link);t("style").forEach(StyleFix.styleElement);t("[style]").forEach(StyleFix.styleAttribute)},register:function(t,n){(e.fixers=e.fixers||[]).splice(n===undefined?e.fixers.length:n,0,t)},fix:function(t,n,r){for(var i=0;i<e.fixers.length;i++)t=e.fixers[i](t,n,r)||t;return t},camelCase:function(e){return e.replace(/-([a-z])/g,function(e,t){return t.toUpperCase()}).replace("-","")},deCamelCase:function(e){return e.replace(/[A-Z]/g,function(e){return"-"+e.toLowerCase()})}};(function(){setTimeout(function(){t('link[rel="stylesheet"]').forEach(StyleFix.link)},10);document.addEventListener("DOMContentLoaded",StyleFix.process,!1)})()})();(function(e){function t(e,t,r,i,s){e=n[e];if(e.length){var o=RegExp(t+"("+e.join("|")+")"+r,"gi");s=s.replace(o,i)}return s}if(!window.StyleFix||!window.getComputedStyle)return;var n=window.PrefixFree={prefixCSS:function(e,r,i){var s=n.prefix;n.functions.indexOf("linear-gradient")>-1&&(e=e.replace(/(\s|:|,)(repeating-)?linear-gradient\(\s*(-?\d*\.?\d*)deg/ig,function(e,t,n,r){return t+(n||"")+"linear-gradient("+(90-r)+"deg"}));e=t("functions","(\\s|:|,)","\\s*\\(","$1"+s+"$2(",e);e=t("keywords","(\\s|:)","(\\s|;|\\}|$)","$1"+s+"$2$3",e);e=t("properties","(^|\\{|\\s|;)","\\s*:","$1"+s+"$2:",e);if(n.properties.length){var o=RegExp("\\b("+n.properties.join("|")+")(?!:)","gi");e=t("valueProperties","\\b",":(.+?);",function(e){return e.replace(o,s+"$1")},e)}if(r){e=t("selectors","","\\b",n.prefixSelector,e);e=t("atrules","@","\\b","@"+s+"$1",e)}e=e.replace(RegExp("-"+s,"g"),"-");e=e.replace(/-\*-(?=[a-z]+)/gi,n.prefix);return e},property:function(e){return(n.properties.indexOf(e)>=0?n.prefix:"")+e},value:function(e,r){e=t("functions","(^|\\s|,)","\\s*\\(","$1"+n.prefix+"$2(",e);e=t("keywords","(^|\\s)","(\\s|$)","$1"+n.prefix+"$2$3",e);n.valueProperties.indexOf(r)>=0&&(e=t("properties","(^|\\s|,)","($|\\s|,)","$1"+n.prefix+"$2$3",e));return e},prefixSelector:function(e){return e.replace(/^:{1,2}/,function(e){return e+n.prefix})},prefixProperty:function(e,t){var r=n.prefix+e;return t?StyleFix.camelCase(r):r}};(function(){var e={},t=[],r={},i=getComputedStyle(document.documentElement,null),s=document.createElement("div").style,o=function(n){if(n.charAt(0)==="-"){t.push(n);var r=n.split("-"),i=r[1];e[i]=++e[i]||1;while(r.length>3){r.pop();var s=r.join("-");u(s)&&t.indexOf(s)===-1&&t.push(s)}}},u=function(e){return StyleFix.camelCase(e)in s};if(i.length>0)for(var a=0;a<i.length;a++)o(i[a]);else for(var f in i)o(StyleFix.deCamelCase(f));var l={uses:0};for(var c in e){var h=e[c];l.uses<h&&(l={prefix:c,uses:h})}n.prefix="-"+l.prefix+"-";n.Prefix=StyleFix.camelCase(n.prefix);n.properties=[];for(var a=0;a<t.length;a++){var f=t[a];if(f.indexOf(n.prefix)===0){var p=f.slice(n.prefix.length);u(p)||n.properties.push(p)}}n.Prefix=="Ms"&&!("transform"in s)&&!("MsTransform"in s)&&"msTransform"in s&&n.properties.push("transform","transform-origin");n.properties.sort()})();(function(){function i(e,t){r[t]="";r[t]=e;return!!r[t]}var e={"linear-gradient":{property:"backgroundImage",params:"red, teal"},calc:{property:"width",params:"1px + 5%"},element:{property:"backgroundImage",params:"#foo"},"cross-fade":{property:"backgroundImage",params:"url(a.png), url(b.png), 50%"}};e["repeating-linear-gradient"]=e["repeating-radial-gradient"]=e["radial-gradient"]=e["linear-gradient"];var t={initial:"color","zoom-in":"cursor","zoom-out":"cursor",box:"display",flexbox:"display","inline-flexbox":"display",flex:"display","inline-flex":"display",grid:"display","inline-grid":"display","min-content":"width"};n.functions=[];n.keywords=[];var r=document.createElement("div").style;for(var s in e){var o=e[s],u=o.property,a=s+"("+o.params+")";!i(a,u)&&i(n.prefix+a,u)&&n.functions.push(s)}for(var f in t){var u=t[f];!i(f,u)&&i(n.prefix+f,u)&&n.keywords.push(f)}})();(function(){function s(e){i.textContent=e+"{}";return!!i.sheet.cssRules.length}var t={":read-only":null,":read-write":null,":any-link":null,"::selection":null},r={keyframes:"name",viewport:null,document:'regexp(".")'};n.selectors=[];n.atrules=[];var i=e.appendChild(document.createElement("style"));for(var o in t){var u=o+(t[o]?"("+t[o]+")":"");!s(u)&&s(n.prefixSelector(u))&&n.selectors.push(o)}for(var a in r){var u=a+" "+(r[a]||"");!s("@"+u)&&s("@"+n.prefix+u)&&n.atrules.push(a)}e.removeChild(i)})();n.valueProperties=["transition","transition-property"];e.className+=" "+n.prefix;StyleFix.register(n.prefixCSS)})(document.documentElement);if(typeof JRJWebapp=="undefined"||!JRJWebapp){var JRJWebapp={}}(function(a){JRJWebapp.swipe=function(b){this.settings=a.extend({containerId:"swipe-container",navId:"swipe-nav",startSlide:0,speed:400,continuous:true,disableScroll:false,stopPropagation:true,callback:function(c,d){},transitionEnd:function(c,d){}},b);this.container=document.getElementById(this.settings.containerId);return this.init()};JRJWebapp.swipe.prototype={init:function(){var c=this,d=this.settings.callback;var b=new Swipe(this.container,a.extend(this.settings,{callback:function(e,f){if(c.settings.navId){a("#"+c.settings.navId).find("li").removeClass("cur");a(a("#"+c.settings.navId).find("li").get(e)).addClass("cur")}d.apply(this,[e,f])}}));if(this.settings.navId){a("#"+this.settings.navId).find("li").bind("click",function(){b.slide(a(this).index(),400)})}return b}}})(Zepto);
function loading(c,d){this.canvas=(typeof c=="String"?document.getElementById(c):c);if(d){this.radius=d.radius||10;this.circleLineWidth=d.circleLineWidth||4;this.circleColor=d.circleColor||"lightgray";this.dotColor=d.dotColor||"gray"}else{this.radius=10;this.circelLineWidth=4;this.circleColor="lightgray";this.dotColor="gray"}}loading.prototype={show:function(){var i=this.canvas;if(!i.getContext){return}if(i.__loading){return}i.__loading=this;var f=i.getContext("2d");var g=this.radius;var j=[{angle:0,radius:1.5},{angle:3/g,radius:2},{angle:7/g,radius:2.5},{angle:12/g,radius:3}];var h=this;i.loadingInterval=setInterval(function(){f.clearRect(0,0,i.width,i.height);var e=h.circleLineWidth;var m={x:i.width/2-g,y:i.height/2-g};f.beginPath();f.lineWidth=e;f.strokeStyle=h.circleColor;f.arc(m.x,m.y,g,0,Math.PI*2);f.closePath();f.stroke();for(var d=0;d<j.length;d++){var a=j[d].currentAngle||j[d].angle;var b={x:m.x-(g)*Math.cos(a),y:m.y-(g)*Math.sin(a)};var c=j[d].radius;f.beginPath();f.fillStyle=h.dotColor;f.arc(b.x,b.y,c,0,Math.PI*2);f.closePath();f.fill();j[d].currentAngle=a+4/g}},50)},hide:function(){var c=this.canvas;c.__loading=false;if(c.loadingInterval){window.clearInterval(c.loadingInterval)}var d=c.getContext("2d");if(d){d.clearRect(0,0,c.width,c.height)}}};(function(){function c(){this.tapTimeLimit=500}Array.prototype.each=function(g,a,b){a=a||0;b=b||this.length-1;for(var h=a;h<=b;h++){g(this[h],this,h);if(this.breakLoop){this.breakLoop=false;break}}};c.prototype={preventDefaultEvent:function(a){if(a.preventDefault){a.preventDefault()}else{a.returnValue=false}},isTouchDevice:function(){return !!("ontouchstart" in window)},toMoney:function(a){return a.toFixed(JRJ.html54stock.gCvsCfg.code.substring(0,1)=="9"?3:2)},bigNumberToText:function(a){var h;var b=a/100000000;if(b>1){h=b.toFixed(2)+"\u4ebf"}else{var g=a/10000;if(g>1){h=g.toFixed()+"\u4e07"}else{h=a}}return h},getOffset:function(b){if(!isNaN(b.offsetX)&&!isNaN(b.offsetY)){return b}var e=b.target;if(e.offsetLeft==undefined){e=e.parentNode}var i=getPageCoord(e);var j={x:window.pageXOffset+b.clientX,y:window.pageYOffset+b.clientY};var a={offsetX:j.x-i.x,offsetY:j.y-i.y};return a},getPageCoord:function(b){var a={x:0,y:0};while(b){a.x+=b.offsetLeft;a.y+=b.offsetTop;b=b.offsetParent}return a},addLoadEvent:function(a){var b=window.onload;if(typeof b!="function"){window.onload=a}else{window.onload=function(){b();a()}}},addEvent:function(a,b,i,j){if(a.addEventListener){a.addEventListener(b,i,j);return true}else{if(a.attachEvent){var h=a.attachEvent("on"+b,i);return h}else{a["on"+b]=i}}},getEventTarget:function(a){return a.srcElement||a.target||a.relatedTarget},$id:function(a){return document.getElementById(a)}};window.extendObject=function(a,f){for(var b in a){f[b]=a[b]}};window.extendWindow=function(a){extendObject(a,window)};var d=new c();extendWindow(d);window.getQueryParam=function(b,g){var h=new RegExp("[?&]debug=([^&]+)","i");var a=h.exec(g?window.top.location.search:location.search);if(a&&a.length>1){return decodeURIComponent(a[1])}else{return""}};window.debug=getQueryParam("debug");window.setDebugMsg=function(a){if(window.debug){try{var g="debug";var b=$id(g);if(!b){b=document.createElement("DIV");b.id=g;document.body.appendChild(b)}b.innerHTML=(window.debug==2?(b.innerHTML+"<br/>"+a):a)}catch(h){alert(a+";error:"+h)}}};window.getAngle=function(b,m){var p=Math.abs(b.x-m.x);var a=Math.abs(b.y-m.y);var k=Math.sqrt(Math.pow(p,2)+Math.pow(a,2));var n=a/k;var o=Math.acos(n);var l=180/(Math.PI/o);return l};window.getTouchPoint=function(a){var f=y=0;var b=a.touches.item(0);f=b.pageX;y=b.pageY;return{x:f,y:y}};window.loadScript=function(i,a,b){var j=document.getElementsByTagName("head")[0]||document.documentElement;var k=document.createElement("script");k.setAttribute("language","javascript");if(b){k.setAttribute("charset",b)}k.setAttribute("src",i);var l=false;k.onload=k.onreadystatechange=function(){if(!l&&(!this.readyState||this.readyState==="loaded"||this.readyState==="complete")){l=true;a();k.onload=k.onreadystatechange=null;if(j&&k.parentNode){j.removeChild(k)}}};j.insertBefore(k,j.firstChild)};window.toMoney=d.toMoney})();var dashSize=2;function Painter(f,e,d){this.canvas=document.getElementById(f);if(!this.canvas.getContext){return}this.ctx=this.canvas.getContext("2d");this.data=d;this.paintImplement=e;this.width=this.canvas.width;this.height=this.canvas.height}Painter.prototype={paint:function(){var m=this.paintImplement;var l=this.data;var h=this.ctx;if(typeof m.initialize=="function"){m.initialize(this)}if(m.start){m.start.call(this)}if(typeof m.paintItems=="function"){m.paintItems.call(this)}else{var k=((typeof m.getDataLength=="function")?m.getDataLength.call(this):this.data.length);for(var n=0;n<k;n++){var i=m.getX?m.getX.call(this,n):undefined;var j=m.getY?m.getY.call(this,n):undefined;m.paintItem.call(this,n,i,j)}}if(m.end){m.end.call(this)}},drawHLine:function(n,m,k,o,i,j){var p=this.ctx;p.lineWidth=1;p.strokeStyle=n;if(k*10%10==0){k+=0.5}if(j&&j=="dashed"){var l=0;do{this.drawHLine(n,l,k,dashSize,1,"solid");l+=dashSize*2}while(l<o)}else{p.beginPath();p.moveTo(m,k);p.lineTo(m+o,k);p.stroke()}},drawVLine:function(n,m,k,l,p,h){var o=this.ctx;o.lineWidth=1;o.strokeStyle=n;if(m*10%10==0){m+=0.5}if(h&&h=="dashed"){var j=0;do{this.drawVLine(n,m,j,dashSize,1);j+=dashSize*2}while(j<l)}else{o.beginPath();o.moveTo(m,k);o.lineTo(m,k+l);o.stroke()}},setData:function(b){this.data=b},setPainterImplement:function(b){this.paintImplement=b}};var Ajax={};Ajax.request=function(j,m,k,l,h){h=h==undefined?true:h;var i=(window.ActiveXObject?new ActiveXObject("Microsoft.XMLHTTP"):(window.XMLHttpRequest?new XMLHttpRequest():false));var n=document.getElementById(l);if(n&&h){n.loadingObj=new loading(n);n.loadingObj.show()}i.onreadystatechange=function(){if(i.readyState==4&&i.status==200){if(n&&h){n.loadingObj.hide()}k(i)}};i.open(j||"POST",m,true);if(i.overrideMimeType){i.overrideMimeType("text/xml")}i.send()};Ajax.get=function(e,g,h,f){Ajax.request("GET",e,g,h,f)};Ajax.post=function(e,g,h,f){Ajax.request("POST",e,g,h,f)};function crossLines(b){this.updateOptions(b)}crossLines.prototype={updateOptions:function(b){this.canvas=b.canvas;this.canvasId=this.canvas.id;this.horizontalDivId=this.canvasId+"_crossLines_H";this.verticalDivId=this.canvasId+"_crossLines_V";this.verticalRange=b.verticalRange||{y1:0,y2:this.canvas.height};this.horizontalRange=b.horizontalRange||{x1:0,x2:this.canvas.width};this.canvasPosition=getPageCoord(this.canvas);this.crossPoint=b.crossPoint;this.color=b.color||"black"},removeCrossLines:function(){var g=this.canvas;var i=g.id;var j=i+"_crossLines_H";var h=i+"_crossLines_V";var k=$id(j);if(k){k.style.display="none"}var l=$id(h);if(l){l.style.display="none"}},getHLine:function(){return $id(this.horizontalDivId)},getVLine:function(){return $id(this.verticalDivId)},setMouseEvents:function(d,c){this.hLineMouseEvt=d;this.vLineMouseEvt=c},updateCrossPoint:function(b){this.crossPoint=b;this.drawCrossLines()},drawCrossLines:function(){var s=this.canvas;var t=this.canvas.id;var p=t+"_crossLines_H";var o=t+"_crossLines_V";var r=this.verticalRange||{y1:0,y2:s.height};var v=this.horizontalRange||{x1:0,x2:s.width};var m=this.canvasPosition;if(this.crossPoint.x<v.x1||this.crossPoint.x>v.x2||this.crossPoint.y<r.y1||this.crossPoint.y>r.y2){this.removeCrossLines();return}var n=(s.style.zIndex||1)+1;var l=false;var q;if($id(p)){l=true;q=$id(p)}else{q=document.createElement("DIV");q.id=p}q.style.display="block";q.style.position="absolute";q.style.width=Math.round(v.x2-v.x1)+"px";q.style.height="1px";q.style.left=Math.round(m.x+v.x1)+"px";q.style.top=Math.round(this.crossPoint.y+m.y)+"px";q.style.backgroundColor=this.color;q.style.zIndex=n;if(!l){document.body.appendChild(q);if(typeof this.hLineMouseEvt=="function"){addEvent(q,"mouseover",this.hLineMouseEvt);addEvent(q,"mousemove",this.hLineMouseEvt)}}l=false;var u;if($id(o)){l=true;u=$id(o)}else{u=document.createElement("DIV");u.id=o}u.style.display="block";u.style.position="absolute";u.style.height=Math.round(r.y2-r.y1)+"px";u.style.width="1px";u.style.left=Math.round(this.crossPoint.x+m.x)+"px";u.style.top=Math.round(r.y1+m.y)+"px";u.style.backgroundColor=this.color;u.style.index=n;if(!l){document.body.appendChild(u);if(typeof this.vLineMouseEvt=="function"){addEvent(u,"mouseover",this.vLineMouseEvt);addEvent(u,"mousemove",this.vLineMouseEvt)}}}};function xAxis(b){this.options=b}xAxis.prototype={initialize:function(b){b.options=this.options},start:function(){var b=this.ctx;b.save();b.fillStyle=this.options.color;b.font=this.options.font;if(this.options.textBaseline){b.textBaseline=this.options.textBaseline}b.translate(this.options.region.x,this.options.region.y)},getY:function(){return 0},getX:function(c){if(c==0){return 0}var d=this.ctx.measureText(this.data[c]).width;if(c==this.data.length-1){return this.options.region.width-d}return(this.options.region.width*c/(this.data.length-1))-d/2},paintItem:function(d,e,f){this.ctx.fillText(this.data[d],e,f)},end:function(){this.ctx.restore()}};function linePainter(b){this.options=b}linePainter.prototype={initialize:function(b){b.options=this.options},getDataLength:function(){return this.options.getDataLength.call(this)},getX:function(b){return(b+1)*(this.options.region.width/this.options.maxDotsCount)},start:function(){var g=this.ctx;var j=this.options;var h=j.region;g.save();g.translate(h.x,h.y+h.height/2);var f=0;var i=this;this.data.items.each(function(b){var a=Math.abs(j.middleValue-j.getItemValue(b));f=Math.max(a,f)});this.maxDiff=f;g.beginPath();g.strokeStyle=j.lineColor;g.lineWidth=j.lineWidth||1},end:function(){this.ctx.stroke();this.ctx.restore()},getY:function(d){var e=this.options;var f=e.getItemValue(this.data.items[d])-e.middleValue;return 0-f*e.region.height/2/this.maxDiff},paintItem:function(h,f,g){var e=this.ctx;if(h==0){e.moveTo(f,g)}else{e.lineTo(f,g)}}};function volumePainter(b){this.options=b;this.barWidth=b.bar.width;this.spaceWidth=b.region.width/b.maxDotsCount-b.bar.width;if(this.spaceWidth<1){this.spaceWidth=0}if(this.barWidth*b.maxDotsCount>b.region.width){this.barWidth=b.region.width/b.maxDotsCount}}volumePainter.prototype={initialize:function(b){b.options=this.options;b.barWidth=this.barWidth;b.spaceWidth=this.spaceWidth},getDataLength:function(){return this.options.getDataLength.call(this)},getX:function(b){return this.options.region.x+b*(this.barWidth+this.spaceWidth)},start:function(){var e=this.ctx;var h=this.options;var g=h.region;e.save();var f=0;this.data.items.each(function(a){f=Math.max(f,a.volume)});this.maxVolume=f;e.fillStyle=h.bar.color},end:function(){this.ctx.restore()},getY:function(d){var c=this.options.region.y+(this.maxVolume-this.data.items[d].volume)*this.options.region.height/this.maxVolume;return c},paintItem:function(h,f,g){var e=this.ctx;e.beginPath();e.rect(f,g,this.barWidth,this.options.region.y+this.options.region.height-g);e.fill()}};function yAxis(b){this.scalerOptions=b}yAxis.prototype={initialize:function(b){b.scalerOptions=this.scalerOptions},start:function(){var b=this.ctx;b.save();if(typeof this.scalerOptions.color=="string"){b.fillStyle=this.scalerOptions.color}b.font=this.scalerOptions.font;b.translate(this.scalerOptions.region.x,this.scalerOptions.region.y);if(this.scalerOptions.textBaseline){b.textBaseline=this.scalerOptions.textBaseline}},end:function(){this.ctx.restore()},getX:function(c){if(this.scalerOptions.align=="left"){return 0}var d=this.ctx.measureText(this.data[c]).width;return this.scalerOptions.region.width-d},getY:function(b){if(b==0){return 0}if(b==this.data.length-1){return this.scalerOptions.region.height-this.scalerOptions.fontHeight}return(this.scalerOptions.region.height*b/(this.data.length-1)-this.scalerOptions.fontHeight/2)},paintItem:function(d,e,f){if(typeof this.scalerOptions.color=="function"){this.ctx.fillStyle=this.scalerOptions.color(this.data[d])}this.ctx.fillText(this.data[d],e,f)}};function calcAxisValues(m,i,o,k){var l=m-i;var n=l/(o-1);var j=[];if(typeof k=="undefined"){k=toMoney}for(var p=0;p<o;p++){j.push(toMoney(m-p*n))}return j}function disableBubbleAndPreventDefault(b){if(b.preventDefault){b.preventDefault()}b.cancelBubble=true;if(b.stopPropagation){b.stopPropagation()}}function setTouchEventOffsetPosition(h,e){h=h||event;if(h.touches&&h.touches.length){h=h.touches[0]}else{if(h.changedTouches&&h.changedTouches.length){h=h.changedTouches[0]}}var f,g;f=h.pageX-e.x;g=h.pageY-e.y;return{offsetX:f,offsetY:g}}function crossLinesAndTipMgr_m(c,d){if(typeof Tip!="function"){window.Tip=function(){};window.Tip.prototype={show:function(){},hide:function(){},update:function(){}}}this.canvas=c;this.options=d}crossLinesAndTipMgr_m.prototype._removeTipAndCrossLines=function(){var b=this;if(b.tip){b.tip.hide()}if(b.clsMgr){b.clsMgr.removeCrossLines()}};crossLinesAndTipMgr_m.prototype.updateOptions=function(b){this.options=b};crossLinesAndTipMgr_m.prototype._onMouseOrTouchMove=function(q){q=q||event;q=getOffset(q);var r=this;var l=r.options;var v=r.canvas;var p=getPageCoord(v);var t=l.triggerEventRanges;if(q.offsetX/2<t.x/4||q.offsetX/2>t.x/2+t.width/2||q.offsetY/2<t.y/4||q.offsetY/2>t.y/2+t.height/2){r._removeTipAndCrossLines();return}var u=l.getCrossPoint(q);var n={crossPoint:u,verticalRange:{y1:t.y/2,y2:t.y/2+t.height/2},horizontalRange:{x1:t.x/2,x2:t.x/2+t.width/2},color:l.crossLineOptions.color,canvas:v};if(!r.clsMgr){var m=new crossLines(n);r.clsMgr=m}else{r.clsMgr.updateOptions(n)}r.clsMgr.drawCrossLines();if(l.tipOptions){var s=l.tipOptions;if(!r.tip){var o=new Tip({position:{x:s.position.x||false,y:s.position.y||false},size:s.size,opacity:s.opacity||80,cssClass:s.cssClass,offsetToPoint:s.offsetToPoint||30,relativePoint:{x:u.x/2,y:u.y/2},canvas:v,canvasRange:l.triggerEventRanges,innerHTML:s.getTipHtml(q)});r.tip=o}r.tip.show(u,s.getTipHtml(q))}};crossLinesAndTipMgr_m.prototype._touchstart=function(d){d=d||event;var c=d.srcElement||d.target||d.relatedTarget;this.touchstartTime=new Date();this.continueTime=null};crossLinesAndTipMgr_m.prototype._touchmove=function(i){i=i||event;this.touchmoveTime=new Date();if(this.touchmoveTime.getTime()-this.touchstartTime.getTime()<=200){this.continueTime=this.touchmoveTime.getTime()-this.touchstartTime.getTime()}if(!!this.continueTime){return}disableBubbleAndPreventDefault(i);var e=this.canvas;var j=getPageCoord(e);var h=i.srcElement||i.target||i.relatedTarget;var g=setTouchEventOffsetPosition(i,j);this._onMouseOrTouchMove(g)};crossLinesAndTipMgr_m.prototype._touchend=function(j){j=j||event;this.continueTime=null;var i=j.srcElement||j.target||j.relatedTarget;var e=this.canvas;var h=setTouchEventOffsetPosition(j,getPageCoord(e));this._removeTipAndCrossLines();var k=new Date();var l=k.getTime()-this.touchstartTime.getTime();if(l<200){if(typeof this.options.onClick=="function"){this.options.onClick()}}};crossLinesAndTipMgr_m.prototype._mouseout=function(i){var h=i||event;i=getOffset(h);var j=this;var g=j.options.triggerEventRanges;if(i.offsetX<=g.x||i.offsetX>=g.x+g.width||i.offsetY<=g.y||i.offsetY>=g.y+g.height){j._removeTipAndCrossLines();return}var e=h.toElement||h.relatedTarget||h.target;if(e){if(e==j.canvas){return}if(e==j.clsMgr.getHLine()||e==j.clsMgr.getVLine()){return}j._removeTipAndCrossLines()}};crossLinesAndTipMgr_m.prototype.addCrossLinesAndTipEvents=function(){var i=this.canvas;var j=this.options;var g=getPageCoord(i);if(!j.addCrossLinesAndTipEvents){return}j.addCrossLinesAndTipEvents=true;var f=isTouchDevice();var h=this;if(f){addEvent(i,"touchstart",function(a){h._touchstart.call(h,a)});addEvent(i,"touchmove",function(a){h._touchmove.call(h,a)});addEvent(i,"touchend",function(a){h._touchend.call(h,a)})}else{addEvent(i,"mouseout",function(a){h._mouseout.call(h,a)});addEvent(i,"mousemove",function(a){h._onMouseOrTouchMove.call(h,a)});if(typeof j.onClick=="function"){addEvent(i,"click",j.onClick)}}};function addCrossLinesAndTipEvents_m(c,d){if(!c.crossLineAndTipMgrInstance){c.crossLineAndTipMgrInstance=new crossLinesAndTipMgr_m(c,d);c.crossLineAndTipMgrInstance.addCrossLinesAndTipEvents()}else{c.crossLineAndTipMgrInstance.updateOptions(d)}};
function line(j,f,i,e,h,g,d,b,c){j.beginPath();j.strokeStyle=g;j.lineWidth=d||1;function a(u,l,t,k,s,m){var q=m===undefined?5:m,p=k-l,n=s-t,r=Math.floor(Math.sqrt(p*p+n*n)/q);for(var o=0;o<r;o++){if(o%2===0){u.moveTo(l+(p/r)*o,t+(n/r)*o)}else{u.lineTo(l+(p/r)*o,t+(n/r)*o)}}u.stroke()}if(!!b){a(j,f,i,e,h,c)}else{j.moveTo(f+0.5,i+0.5);j.lineTo(e+0.5,h+0.5);j.stroke()}}function getMinTime(b){var f=new Date();if(b<=120){f.setHours(9,30,30);f=new Date(f.getTime()+(b)*60*1000)}else{f.setHours(13,0,0);f=new Date(f.getTime()+(b-120)*60*1000)}var a=f.getHours()>9?new String(f.getHours()):"0"+f.getHours();var c=f.getMinutes()>9?new String(f.getMinutes()):"0"+f.getMinutes();var e="30";return a+""+c+e}function Tip(a){this.options=a;this.canvas=a.canvas;this.canvas.tip=this}Tip.prototype={show:function(d,c){var b=this.dataContext;var a=this.canvas.painter;if(b){if(b.isNewQuote){a.fillTopText(b.data)}else{a.fillTopText(b.data,b.index)}}},update:function(b,a){this.show(b,a)},hide:function(){var b=this.dataContext;var a=this.canvas.painter;if(b){a.fillTopText(b.data)}}};function minsChart(b,a){extendObject(a,this);this.canvas=$id(b);this.ctx=this.canvas.getContext("2d");this.canvas.painter=this}minsChart.prototype={_clear:function(){this.ctx.clearRect(0,0,this.canvas.width,this.canvas.height)},paint:function(a){this._clear();this.paintChart(a);this.fillTopText(a);this.paintxAxis();this.fillBottomText(a);this.paintVolume(a)},paintVolume:function(d){var h=this.ctx;var i=this.volume;h.beginPath();h.rect(i.region.x,i.region.y,i.region.width,i.region.height);h.strokeStyle=i.borderColor;h.stroke();line(h,i.region.x,i.region.y+i.region.height/2,i.region.x+i.region.width,i.region.y+i.region.height/2,i.splitLineColor);i.getDataLength=function(){return this.data.items.length};i.maxDotsCount=this.maxDotsCount;var a=new volumePainter(i);var f=new Painter(this.canvas.id,a,{items:d.mins});f.paint();var e=f.maxVolume;var g="\u624b";if(e/1000000>1000){e=e/1000000;g="\u767e\u4e07"}else{if(e>999999){e=e/10000;g="\u4e07"}}e=e/100;var b=[e.toFixed(2),(e/2).toFixed(2),"("+g+")"];var c=new yAxis(this.volume.yScaler);var f=new Painter(this.canvas.id,c,b);f.paint()},fillBottomText:function(c){if(!this.bottomText){return}if(typeof c.mins[c.mins.length-1]=="undefined"){return}var l=this.ctx;var d="\u9ad8";var n=this.bottomText;l.font=n.font;l.fillStyle=n.color;var k=l.measureText(d).width;l.fillText(d,n.region.x,n.region.y);var j=n.region.x+k;var a=c.quote;var i=this;function f(o){return o>a.preClose?i.riseColor:(o==a.preClose?i.normalColor:i.fallColor)}var m=f(a.highest);var b=toMoney(a.highest);l.fillStyle=m;k=l.measureText(b).width;l.fillText(b,j,n.region.y);j+=k;d=" \u4f4e";l.fillStyle=n.color;k=l.measureText(d).width;l.fillText(d,j,n.region.y);j+=k;var g=f(a.lowest);var h=toMoney(a.lowest);k=l.measureText(h).width;l.fillStyle=g;l.fillText(h,j,n.region.y);j+=k;l.fillStyle=n.color;var e=" \u6210\u4ea4"+bigNumberToText(a.amount);l.fillText(e,j,n.region.y)},paintxAxis:function(){var b=new xAxis(this.xScaler);var a=new Painter(this.canvas.id,b,this.xScaler.data);a.paint()},paintChart:function(I){var l=this.minsChart;var c=this.minsChart.region;var t=this.ctx;t.beginPath();t.strokeStyle=l.borderColor;t.lineWidth=1;t.rect(c.x,c.y,c.width,c.height+2);t.stroke();var E=(this.minsChart.horizontalLineCount+this.minsChart.horizontalLineCount%2)/2;var G=this.minsChart.horizontalLineCount+1;for(var w=1;w<=this.minsChart.horizontalLineCount;w++){var h=c.y+c.height*w/G;if(w==E){line(t,c.x,h,c.x+c.width,h,l.middleLineColor,1,true,5)}else{var u=l.otherSplitLineColor;line(t,c.x,h,c.x+c.width,h,u)}}G=this.minsChart.verticalLineCount+1;for(var w=1;w<=this.minsChart.verticalLineCount;w++){var j=c.x+c.width*w/G;line(t,j,c.y,j,c.y+c.height,l.otherSplitLineColor)}var C={region:c,maxDotsCount:this.maxDotsCount,getDataLength:function(){return this.data.items.length},getItemValue:function(i){return i.price},middleValue:I.quote.preClose,lineColor:l.priceLineColor,lineWidth:2};var m=new linePainter(C);var f=new Painter(this.canvas.id,m,{items:I.mins});f.paint();var r=this.minsChart.yScalerLeft;var v=I.quote.preClose;var H=this;r.color=function(i){var i=parseFloat(i);return i>v.toFixed(2)?H.riseColor:(i==v.toFixed(2)?H.normalColor:H.fallColor)};var k=[];var B=[];var s=(v-f.maxDiff)*100;var D=f.maxDiff*100*2/(this.minsChart.horizontalLineCount+1);if(typeof this.middleTxt!="undefined"&&typeof I.mins[I.mins.length-1]=="undefined"){var D=f.maxDiff*100*2/(1+1);for(var w=2;w>=0;w--){if(w==1){var J=s+1*D;k.push((J/100).toFixed(2));var a=(J-v*100)/v*100;if((a/100).toFixed(2)=="NaN"){B.push("0%")}else{B.push((a/100).toFixed(2)+"%")}}else{k.push("");B.push("")}}}else{for(var w=this.minsChart.horizontalLineCount+1;w>=0;w--){var J=s+w*D;k.push((J/100).toFixed(2));var a=(J-v*100)/v*100;if((a/100).toFixed(2)=="NaN"){B.push("0%")}else{B.push((a/100).toFixed(2)+"%")}}}var q=new yAxis(r);var n=new Painter(this.canvas.id,q,k);n.paint();var e=this.minsChart.yScalerRight;e.color=function(i){return(i=="0.00%"?"black":(i.charAt(0)=="-"?H.fallColor:H.riseColor))};var d=new yAxis(e);var g=new Painter(this.canvas.id,d,B);g.paint();if(this.needPaintAvgPriceLine){var o=[];var b=0;var p=0;I.mins.each(function(i){o.push(i.avg)});this.avgItems=o;C.lineColor=l.avgPriceLineColor;C.getItemValue=function(i){return i};m=new linePainter(C);m.getY=function(y){var x=this.options;var K=x.getItemValue(this.data.items[y])-x.middleValue;if(0-K*(x.region.height-3)/2/f.maxDiff>120){return 120}else{return 0-K*(x.region.height-3)/2/f.maxDiff}};var z=new Painter(this.canvas.id,m,{items:o});z.paint()}var H=this;var F=H.minsChart.region;function A(i){var K=Math.ceil((i-H.minsChart.region.x/2)*(H.maxDotsCount/(H.minsChart.region.width/2)));var N;var y;if(K>=0){if(K>=I.mins.length){K=I.mins.length-1}N=I.mins[K].price;y=false}else{N=I.quote.price;y=true}if(H.canvas.tip){H.canvas.tip.dataContext={data:I,isNewQuote:y,index:K}}var L=N-v;var M=H.minsChart.region.y+H.minsChart.region.height/4-12.5;return M-L*H.minsChart.region.height/4/f.maxDiff}addCrossLinesAndTipEvents_m(this.canvas,{getCrossPoint:function(i){return{x:i.offsetX+2,y:A(i.offsetX)}},triggerEventRanges:{x:F.x,y:F.y,width:F.width,height:H.volume.region.y+H.volume.region.height-F.y},tipOptions:{size:{width:150,height:200},getTipHtml:function(i){return null},position:{x:false,y:false}},crossLineOptions:{color:"black"},addCrossLinesAndTipEvents:this.addCrossLinesAndTipEvents})},fillTopText:function(A,c){var y=A.quote;var r=this.ctx;var B=this.topText;var b=B.region;var z=this;r.clearRect(b.x,b.y,b.width,b.height);var t;var f;if(typeof A.mins[c?c:A.mins.length-1]!="undefined"){t=A.mins[c?c:A.mins.length-1].price}else{t=0}if(c){var w=A.mins[c]["time"].toString();if(w.length==3){w="0"+w}f=w}else{if(typeof A.mins[A.mins.length-1]!="undefined"){var w=A.mins[A.mins.length-1]["time"].toString()}else{var w=0}if(w.length==3){w="0"+w}f=w}if(typeof A.mins[A.mins.length-1]!="undefined"){r.fillStyle=B.color;r.font=B.font;if(B.textBaseline){r.textBaseline=B.textBaseline}var o="\u6700\u65b0"+toMoney(t);var p=r.measureText(o).width;r.fillText(o,B.region.x,B.region.y);var a=t>y.preClose;var s=t==y.preClose;var h=t<y.preClose;var n=toMoney(t-y.preClose);var d=(a?"\u2191":(h?"\u2193":" "))+n+("(")+(toMoney(n*100/y.preClose)!="NaN"?toMoney(n*100/y.preClose):"0")+"%)";var m=B.region.x+p;r.fillStyle=a?this.riseColor:(h?this.fallColor:this.normalColor);r.fillText(d,m,B.region.y)}else{if(!!this.beforeStartType){r.fillStyle=B.color;r.font=B.font;if(B.textBaseline){r.textBaseline=B.textBaseline}var o="\u6700\u65b0"+toMoney(y.preClose);var p=r.measureText(o).width;r.fillText(o,B.region.x,B.region.y);var a=y.leftPl>0;var s=y.leftPl==0;var h=y.leftPl<0;var n=toMoney(t-y.preClose);if(typeof y.leftPl!="undefined"){var d=(a?"\u2191":(h?"\u2193":" "))+("(")+(y.leftPl)+"%)";var m=B.region.x+p;r.fillStyle=a?this.riseColor:(h?this.fallColor:this.normalColor);r.fillText(d,m,B.region.y)}}}var v=new String(f);var j=v.charAt(0)+v.charAt(1)+":"+v.charAt(2)+v.charAt(3);var l=r.measureText(j).width;if(this.needPaintAvgPriceLine){if(typeof A.mins[A.mins.length-1]!="undefined"){var k=(this.avgItems[c?c:A.mins.length-1]*100/100).toFixed(2);var q=r.measureText(k).width;r.fillStyle=k>y.preClose?this.riseColor:(k<y.preClose?this.fallColor:this.normalColor);r.fillText(k,B.region.x+B.region.width-l-q-10,B.region.y);var i="\u5747\u4ef7:";var e=r.measureText(i).width;r.fillStyle=B.color;r.fillText(i,B.region.x+B.region.width-l-q-e-10,B.region.y)}}if(typeof A.mins[A.mins.length-1]!="undefined"){window.alreadyLoadedOnceData=true;r.fillStyle=B.color;r.fillText(j,B.region.x+B.region.width-l,B.region.y)}else{if(typeof this.beforeStartType=="undefined"){r.font="48px Arial";r.fillStyle="gray";var g=r.measureText(this.middleTxt||"\u96c6\u5408\u7ade\u4ef7\u9636\u6bb5").width;var u=window.alreadyLoadedOnceData?2:1;r.fillText(this.middleTxt||"\u96c6\u5408\u7ade\u4ef7\u9636\u6bb5",B.region.x+B.region.width/2-g/2,this.canvas.height/2-48*u)}}}};function cvsLoading(b,a){this.canvas=b;if(a){this.radius=a.radius||12;this.circleLineWidth=a.circleLineWidth||4;this.circleColor=a.circleColor||"lightgray";this.moveArcColor=a.moveArcColor||"gray"}else{this.radius=12;this.circelLineWidth=4;this.circleColor="lightgray";this.moveArcColor="gray"}}cvsLoading.prototype={show:function(){var c=this.canvas;if(!c.getContext){return}if(c.__loading){return}c.__loading=this;var b=c.getContext("2d");var a=this.radius;var e=this;var f=Math.PI*1.5;var d=Math.PI/6;c.loadingInterval=setInterval(function(){b.clearRect(0,0,c.width,c.height);var h=e.circleLineWidth;var g={x:c.width/2-a,y:c.height/2-a};b.beginPath();b.lineWidth=h;b.strokeStyle=e.circleColor;b.arc(g.x,g.y,a,0,Math.PI*2);b.closePath();b.stroke();b.beginPath();b.strokeStyle=e.moveArcColor;b.arc(g.x,g.y,a,f,f+Math.PI*0.45);b.stroke();f+=d},50)},hide:function(){var b=this.canvas;b.__loading=false;if(b.loadingInterval){window.clearInterval(b.loadingInterval)}var a=b.getContext("2d");if(a){a.clearRect(0,0,b.width,b.height)}}};
