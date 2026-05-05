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
    // We use resizeToAvoidBottomInset:false so the WebView never shrinks
    // when the soft keyboard opens. The keyboard overlays the content and
    // the visualViewport API reports a reduced visible area. This script
    // scrolls the focused element into that smaller viewport exactly once
    // per focus event, without any padding hacks or restore logic that
    // caused jitter in earlier versions.
    _wv.runJavaScript(r'''
(function(){
  if (window.__grKbFix) return;
  window.__grKbFix = true;
  function isInput(n){
    return n && (n.tagName === 'INPUT' || n.tagName === 'TEXTAREA' || n.isContentEditable);
  }
  function pull(){
    var el = document.activeElement;
    if (!isInput(el)) return;
    var vp = window.visualViewport;
    if (vp){
      var rect = el.getBoundingClientRect();
      if (rect.bottom > vp.offsetTop + vp.height - 24 || rect.top < vp.offsetTop){
        el.scrollIntoView({behavior:'smooth', block:'center'});
      }
    } else {
      el.scrollIntoView({behavior:'smooth', block:'center'});
    }
  }
  document.addEventListener('focusin', function(e){
    if (isInput(e.target)){
      setTimeout(pull, 220);
      setTimeout(pull, 480);
      setTimeout(pull, 820);
    }
  });
  if (window.visualViewport){
    var prev = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if (h < prev){ setTimeout(pull, 80); setTimeout(pull, 320); }
      prev = h;
    });
  }
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
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // In immersiveSticky mode MediaQuery.padding only reflects
            // display-cutout insets (status bar is hidden and not counted).
            // Using .padding on all sides keeps the WebView clear of the
            // physical notch in both portrait and landscape orientations.
            Padding(
              padding: MediaQuery.of(context).padding,
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
