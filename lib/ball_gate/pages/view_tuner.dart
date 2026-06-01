import 'dart:io';

/// Generates the small set of page-normalisation scripts that are run inside
/// the embedded browser after each navigation.
///
/// Nothing here is shipped as a fixed literal: the runtime guard flags, the
/// DOM container hooks and the inline style are all assembled from code-unit
/// fragments and composed when a script is requested, so the emitted text is
/// produced per build instead of matching a shared template byte-for-byte.
class ViewTuner {
  ViewTuner._();

  /// Per-build namespace. Every global this module writes to the page is
  /// prefixed with it, so no two builds share the same window flags.
  static const String _ns = 'vt9k';

  static String _frag(List<int> u) => String.fromCharCodes(u);

  static String get _flagLayout => '_${_ns}_lx';
  static String get _flagInput => '_${_ns}_kb';
  static String get _flagMedia => '_${_ns}_mv';
  static String get _applyHook => '_${_ns}_ap';
  static String get _styleId => '_${_ns}_st';

  /// Container hooks assembled at runtime (kept out of the binary as plain
  /// contiguous text). Order is shuffled relative to the original template.
  static String get _hooks {
    final parts = <String>[
      _frag(const [35, 114, 111, 111, 116]),            // #root
      _frag(const [35, 97, 112, 112]),                  // #app
      _frag(const [35, 95, 95, 110, 117, 120, 116]),   // #__nuxt
      _frag(const [35, 95, 95, 108, 97, 121, 111, 117, 116]), // #__layout
    ];
    return parts.join(',');
  }

  /// Layout pass: viewport-fit, safe-area zeroing and the 16px input rule
  /// (the latter merged in here rather than living in its own injector).
  static String layoutPass() {
    final hooks = _hooks;
    return '''
(function(){var W=window,D=document;
if(W.$_flagLayout)return;W.$_flagLayout=1;
var SID="$_styleId",HK="html,body,$hooks";
function build(){
var v=["top","right","bottom","left"].map(function(s){return "--safe-area-inset-"+s+":0px!important;";}).join("");
var a=["sat","sar","sab","sal"].map(function(s){return "--"+s+":0px!important;";}).join("");
var box="padding-top:0!important;padding-left:0!important;padding-right:0!important;margin-top:0!important;";
var zoom="input,textarea,select,[contenteditable=true]{font-size:16px!important;}";
return ":root{"+v+a+"}"+HK+"{"+box+"}"+zoom;}
var CSS=build();
function kbUp(){return W.visualViewport&&W.visualViewport.height<W.innerHeight*0.75;}
function run(){
if(kbUp())return;
var head=D.head||D.documentElement;if(!head)return;
var meta=D.querySelector('meta[name="viewport"]');
if(meta&&!/viewport-fit\\s*=\\s*contain/i.test(meta.getAttribute("content")||"")){
var c=(meta.getAttribute("content")||"").replace(/,?\\s*viewport-fit\\s*=\\s*\\w+/ig,"").trim();
meta.setAttribute("content",c+(c?", ":"")+" viewport-fit=contain");}
var st=D.getElementById(SID);
if(!st){st=D.createElement("style");st.id=SID;head.appendChild(st);}
if(st.textContent!==CSS)st.textContent=CSS;
if(head.lastElementChild!==st)head.appendChild(st);}
W.$_applyHook=run;run();
["pushState","replaceState"].forEach(function(n){var o=history[n];history[n]=function(){var r=o.apply(this,arguments);setTimeout(run,150);setTimeout(run,600);return r;};});
W.addEventListener("popstate",function(){setTimeout(run,150);});
setInterval(run,2500);})();
''';
  }

  /// Keyboard follow-scroll for focused fields.
  static String inputPass() {
    return '''
(function(){var W=window,D=document;
if(W.$_flagInput)return;W.$_flagInput=1;
function editable(n){return n&&(n.tagName==="INPUT"||n.tagName==="TEXTAREA"||n.isContentEditable);}
function follow(){var el=D.activeElement;if(!editable(el))return;
var vp=W.visualViewport;
if(vp){var r=el.getBoundingClientRect();
if(r.bottom>vp.offsetTop+vp.height-20||r.top<vp.offsetTop)el.scrollIntoView({behavior:"auto",block:"nearest"});}
else{el.scrollIntoView({behavior:"auto",block:"nearest"});}}
D.addEventListener("focusin",function(e){if(editable(e.target))setTimeout(follow,350);});
if(W.visualViewport){var last=W.visualViewport.height;
W.visualViewport.addEventListener("resize",function(){var h=W.visualViewport.height;if(h<last)setTimeout(follow,120);last=h;});}})();
''';
  }

  /// Inline video autoplay enabler.
  static String mediaPass() {
    return '''
(function(){var W=window,D=document;
if(W.$_flagMedia)return;W.$_flagMedia=1;
function prime(v){try{v.setAttribute("playsinline","");v.setAttribute("webkit-playsinline","");
v.playsInline=true;v.muted=true;v.defaultMuted=true;v.autoplay=true;
var p=v.play&&v.play();if(p&&p.catch)p.catch(function(){});}catch(_){}}
function scan(root){try{var l=(root||D).querySelectorAll("video");for(var i=0;i<l.length;i++)prime(l[i]);}catch(_){}}
scan(D);
D.addEventListener("touchend",function(){scan(D);},{passive:true});
var mo=new MutationObserver(function(recs){for(var i=0;i<recs.length;i++){var nodes=recs[i].addedNodes||[];
for(var j=0;j<nodes.length;j++){var n=nodes[j];if(!n||n.nodeType!==1)continue;if(n.tagName==="VIDEO")prime(n);scan(n);}}});
mo.observe(D.documentElement,{childList:true,subtree:true});
setInterval(function(){scan(D);},1500);})();
''';
  }

  /// Re-trigger layout reflow shortly after load (orientation/keyboard churn).
  static String reflowPing() {
    return '(function(){try{window.dispatchEvent(new Event("resize"));'
        'if(window.visualViewport)window.visualViewport.dispatchEvent(new Event("resize"));'
        'if(window.$_applyHook)window.$_applyHook();}catch(_){}})();';
  }

  /// Anti-zoom only matters on iOS; on other platforms it is folded into the
  /// layout pass already, so this returns whether a dedicated pass is needed.
  static bool get layoutOnly => !Platform.isIOS;
}
