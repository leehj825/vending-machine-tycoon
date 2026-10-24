import 'dart:convert';

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'lowpoly_engine.dart';

/// Moves and zooms the city page. Same calls as [LowPolyController].
class CityWebController {
  _CityWebViewState? _state;

  /// Multiplies the camera distance: below 1 zooms in, above 1 zooms out.
  void zoomBy(double factor) => _state?._run('window.city.zoom($factor)');

  /// Returns the camera to the city's starting view.
  void reset() => _state?._run('window.city.reset()');

  /// Glides the camera to look at [target] from [distance] at [pitch]. With [yaw], the
  /// camera comes in from that direction; otherwise it keeps its current direction.
  void focusOn(Vec3 target, {double distance = 5, double pitch = 0.5, double? yaw}) =>
      _state?._run(
        'window.city.focus(${target.x}, ${target.y}, ${target.z}, $distance, $pitch, ${yaw ?? 'null'})',
      );
}

/// The 3D city, drawn by a three.js page in a WebView. [scene] is sent when it changes,
/// [frame] on every update. Taps arrive as decoded JSON in [onTap].
class CityWebView extends StatefulWidget {
  const CityWebView({
    super.key,
    required this.scene,
    required this.frame,
    required this.controller,
    required this.onTap,
    required this.background,
  });

  /// JSON for `window.city.setScene`. Compared by identity, so keep one string per scene.
  final String scene;

  /// JSON for `window.city.setFrame`. Compared by identity, so build a new string per frame.
  final String frame;
  final CityWebController controller;
  final ValueChanged<Map<String, Object?>> onTap;
  final Color background;

  @override
  State<CityWebView> createState() => _CityWebViewState();
}

class _CityWebViewState extends State<CityWebView> {
  WebViewController? _web;
  bool _pageReady = false;
  String? _sentScene;
  String? _sentFrame;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
    try {
      final web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(widget.background)
        ..addJavaScriptChannel('CityTap', onMessageReceived: _onTap)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            _pageReady = true;
            _push();
          },
        ));
      web.loadFlutterAsset('assets/city/city.html');
      _web = web;
    } catch (_) {
      // No WebView here, such as in a unit test. The city stays blank.
      _web = null;
    }
  }

  @override
  void didUpdateWidget(covariant CityWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._state = null;
      widget.controller._state = this;
    }
    _push();
  }

  @override
  void dispose() {
    if (widget.controller._state == this) widget.controller._state = null;
    super.dispose();
  }

  void _run(String script) {
    if (!_pageReady) return;
    _web?.runJavaScript(script);
  }

  /// Sends the scene first, when it has changed, then the frame. The page needs the
  /// scene before any frame that draws people.
  void _push() {
    final web = _web;
    if (web == null || !_pageReady) return;
    if (!identical(_sentScene, widget.scene)) {
      _sentScene = widget.scene;
      web.runJavaScript('window.city.setScene(${widget.scene})');
    }
    if (!identical(_sentFrame, widget.frame)) {
      _sentFrame = widget.frame;
      web.runJavaScript('window.city.setFrame(${widget.frame})');
    }
  }

  void _onTap(JavaScriptMessage message) {
    final decoded = jsonDecode(message.message);
    if (decoded is Map<String, Object?>) widget.onTap(decoded);
  }

  @override
  Widget build(BuildContext context) {
    final web = _web;
    if (web == null) return ColoredBox(color: widget.background);
    // The page needs every touch for orbiting and pinching. Without this, the parent's
    // gesture recognizers take drags and the camera stays where it is.
    return WebViewWidget(
      controller: web,
      gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
    );
  }
}
