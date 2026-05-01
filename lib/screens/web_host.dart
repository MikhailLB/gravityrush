import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/browser_http.dart';
import '../services/cloud_push_client.dart';
import '../services/local_store.dart';
import '../services/network_monitor.dart';
import 'connection_lost_screen.dart';

Future<void> primeBrowser() async {}

class WebHost extends StatefulWidget {
  final String target;
  final LocalStore store;
  final CloudPushClient push;
  final NetworkMonitor net;

  const WebHost({
    super.key,
    required this.target,
    required this.store,
    required this.push,
    required this.net,
  });

  @override
  State<WebHost> createState() => _WebHostState();
}

class _WebHostState extends State<WebHost> with WidgetsBindingObserver {
  late final WebViewController _wv;
  bool _spinning = true;
  StreamSubscription<List<ConnectivityResult>>? _netSub;
  bool _offlineRouted = false;
  String? _lastMainFrameUrl;
  int _redirectRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockOrientations();
    _applyFullscreen();

    _wv = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(browserHttp.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(_delegate());

    _setupPlatform();
    _wv.loadRequest(Uri.parse(widget.target));

    widget.push.onRemoteTarget = (url) {
      if (!mounted) return;
      _wv.loadRequest(Uri.parse(url));
    };

    _netSub = widget.net.watch().listen((statuses) {
      final allGone = statuses.every((s) => s == ConnectivityResult.none);
      if (allGone) _maybeRouteOffline();
    });
  }

  void _lockOrientations() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _applyFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyFullscreen();
  }

  NavigationDelegate _delegate() {
    return NavigationDelegate(
      onPageStarted: (_) {
        if (mounted) setState(() => _spinning = true);
      },
      onPageFinished: (_) {
        if (mounted) setState(() => _spinning = false);
        _redirectRetries = 0;
        _injectSafeAreaShim();
        _injectKeyboardScroll();
      },
      onWebResourceError: (err) {
        if (err.isForMainFrame != true) return;
        final desc = err.description.toLowerCase();
        final loop = desc.contains('too_many_redirects') ||
            desc.contains('too many redirects') ||
            err.errorCode == -1007 ||
            err.errorCode == -9;
        if (loop && _lastMainFrameUrl != null && _redirectRetries < 3) {
          _redirectRetries++;
          _wv.loadRequest(Uri.parse(_lastMainFrameUrl!));
          return;
        }
        _maybeRouteOffline();
      },
      onHttpError: (_) {},
      onNavigationRequest: (req) {
        final uri = Uri.tryParse(req.url);
        if (uri == null) return NavigationDecision.prevent;
        final scheme = uri.scheme;
        final browserScheme = scheme == 'http' ||
            scheme == 'https' ||
            scheme == 'about' ||
            scheme == 'data' ||
            scheme == 'blob';
        if (browserScheme) {
          if (req.isMainFrame) _lastMainFrameUrl = req.url;
          return NavigationDecision.navigate;
        }
        _launchExternal(uri);
        return NavigationDecision.prevent;
      },
    );
  }

  void _setupPlatform() {
    if (Platform.isAndroid && _wv.platform is AndroidWebViewController) {
      final android = _wv.platform as AndroidWebViewController;
      android.setMediaPlaybackRequiresUserGesture(false);
      android.setOnShowFileSelector(_pickFiles);
      final cookies = AndroidWebViewCookieManager(
        AndroidWebViewCookieManagerCreationParams
            .fromPlatformWebViewCookieManagerCreationParams(
          const PlatformWebViewCookieManagerCreationParams(),
        ),
      );
      cookies.setAcceptThirdPartyCookies(android, true);
    }
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (result == null) return const [];
      return result.files
          .where((f) => f.path != null)
          .map((f) => Uri.file(f.path!).toString())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _maybeRouteOffline() async {
    if (_offlineRouted) return;
    final hasNet = await widget.net.isOnline();
    if (hasNet || !mounted) return;
    _offlineRouted = true;
    final currentUrl = await _wv.currentUrl() ?? widget.target;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConnectionLostScreen(
          net: widget.net,
          retryBuilder: (_) => WebHost(
            target: currentUrl,
            store: widget.store,
            push: widget.push,
            net: widget.net,
          ),
        ),
      ),
    );
  }

  void _launchExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _injectKeyboardScroll() {
    // Minimal keyboard helper. We rely on `resizeToAvoidBottomInset: true`
    // and Android's adjustResize so the WebView gets the correct viewport
    // height when the soft keyboard appears. The script's only job is to
    // make sure the focused field ends up visible inside that smaller
    // viewport — exactly once per focus, no padding hacks, no repeated
    // scrollBy. Earlier versions injected paddingBottom=45vh and ran
    // four delayed scrollIntoView passes which caused the blocks to
    // jitter under the keyboard.
    _wv.runJavaScript(r'''
(function(){
  if (window.__grKbFix) return;
  window.__grKbFix = true;

  function inputLike(n){
    return n && (n.tagName === 'INPUT'
      || n.tagName === 'TEXTAREA'
      || n.isContentEditable);
  }

  // savedY = scroll position at the moment the FIRST input in a typing
  // session got focus. We restore to it once every input has lost focus
  // again. Without restore, ensureVisible's scrollIntoView leaves the
  // page scrolled up after the keyboard is dismissed, which looks like
  // "the login modal jumped under the keyboard" in the UI.
  var savedY = null;
  var savedScrollerY = null;
  var savedScroller = null;
  var blurTimer = null;

  function findScroller(node){
    var el = node && node.parentElement;
    while (el && el !== document.body && el !== document.documentElement){
      var s = getComputedStyle(el);
      var oy = s.overflowY;
      if ((oy === 'auto' || oy === 'scroll') && el.scrollHeight > el.clientHeight){
        return el;
      }
      el = el.parentElement;
    }
    return null;
  }

  function ensureVisible(){
    var el = document.activeElement;
    if (!inputLike(el)) return;
    var vp = window.visualViewport;
    var rect = el.getBoundingClientRect();
    var top = vp ? vp.offsetTop : 0;
    var bottom = vp ? (vp.offsetTop + vp.height) : window.innerHeight;
    if (rect.bottom > bottom - 16 || rect.top < top + 16){
      try {
        el.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'auto' });
      } catch (_) {
        el.scrollIntoView();
      }
    }
  }

  function snapshotScroll(target){
    if (savedY === null){
      savedY = window.scrollY || window.pageYOffset || 0;
      savedScroller = findScroller(target);
      savedScrollerY = savedScroller ? savedScroller.scrollTop : null;
    }
  }

  function restoreScroll(){
    if (savedScroller && savedScrollerY !== null){
      try { savedScroller.scrollTop = savedScrollerY; } catch(_){}
    }
    if (savedY !== null){
      try {
        window.scrollTo({ top: savedY, left: 0, behavior: 'auto' });
      } catch(_){
        window.scrollTo(0, savedY);
      }
    }
    savedY = null;
    savedScroller = null;
    savedScrollerY = null;
  }

  document.addEventListener('focusin', function(e){
    if (!inputLike(e.target)) return;
    if (blurTimer){ clearTimeout(blurTimer); blurTimer = null; }
    snapshotScroll(e.target);
    setTimeout(ensureVisible, 280);
  });

  document.addEventListener('focusout', function(e){
    if (!inputLike(e.target)) return;
    if (blurTimer) clearTimeout(blurTimer);
    // Wait long enough to know whether focus is moving to ANOTHER input
    // (tab between login fields) or leaving the form entirely. Only the
    // latter triggers a scroll restore.
    blurTimer = setTimeout(function(){
      blurTimer = null;
      if (inputLike(document.activeElement)) return;
      restoreScroll();
    }, 200);
  });
})();
''');
  }

  void _injectSafeAreaShim() {
    _wv.runJavaScript(r'''
(function(){
  if (window.__grSaShim) return;
  window.__grSaShim = true;
  var ID = '__grSaShim';
  var CSS = ':root{'
    + '--safe-area-inset-top:0px!important;'
    + '--safe-area-inset-right:0px!important;'
    + '--safe-area-inset-bottom:0px!important;'
    + '--safe-area-inset-left:0px!important;'
    + '--sat:0px!important;--sar:0px!important;'
    + '--sab:0px!important;--sal:0px!important;'
    + '--safe-top:0px!important;--safe-right:0px!important;'
    + '--safe-bottom:0px!important;--safe-left:0px!important;'
    + '}'
    + 'html,body,#__nuxt,#__layout,#app,#root,.gameview-mobile-header{'
    + 'padding-top:0!important;padding-left:0!important;padding-right:0!important;margin-top:0!important;'
    + '}';
  function apply(){
    var head = document.head || document.documentElement;
    if (!head) return;
    var vp = document.querySelector('meta[name="viewport"]');
    if (vp && !/viewport-fit\s*=\s*contain/i.test(vp.getAttribute('content') || '')){
      var c = (vp.getAttribute('content') || '').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      vp.setAttribute('content', c + (c ? ', ' : '') + 'viewport-fit=contain');
    }
    var s = document.getElementById(ID);
    if (!s){ s = document.createElement('style'); s.id = ID; head.appendChild(s); }
    if (s.textContent !== CSS) s.textContent = CSS;
    if (head.lastElementChild !== s) head.appendChild(s);
  }
  apply();
  ['pushState','replaceState'].forEach(function(name){
    var orig = history[name];
    history[name] = function(){
      var r = orig.apply(this, arguments);
      setTimeout(apply,80); setTimeout(apply,400);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(apply,80); });
  setInterval(apply, 2500);
})();
''');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _netSub?.cancel();
    widget.push.onRemoteTarget = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _lockOrientations();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    if (await _wv.canGoBack()) {
      await _wv.goBack();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).orientation ==
                        Orientation.landscape
                    ? 0
                    : MediaQuery.of(context).viewPadding.top,
              ),
              child: WebViewWidget(controller: _wv),
            ),
            if (_spinning)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
