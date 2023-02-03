import 'dart:async';

// import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_browser/custom_image.dart';
import 'package:flutter_browser/models/webview_model.dart';
import 'package:flutter_browser/tab_viewer.dart';
import 'package:flutter_browser/util.dart';
import 'package:flutter_browser/webview_tab.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:tab_switcher/tab_count_icon.dart';
import 'package:tab_switcher/tab_switcher.dart';

import 'empty_tab.dart';
import 'models/browser_model.dart';

class Browser extends StatefulWidget {
  const Browser({Key? key}) : super(key: key);

  @override
  State<Browser> createState() => _BrowserState();
}

class NewTabButton extends StatelessWidget {
  final TabSwitcherController controller;

  const NewTabButton({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
        child: MaterialButton(
      visualDensity: VisualDensity.compact,
      child: Row(
        children: const [
          Icon(Icons.add),
          SizedBox(width: 8),
          Text('New tab'),
        ],
      ),
      onPressed: () => controller.pushTab(EmptyTab(), foreground: true),
    ));
  }
}

class _BrowserState extends State<Browser> with SingleTickerProviderStateMixin {
  static const platform =
      MethodChannel('com.pichillilorenzo.flutter_browser.intent_data');

  var _isRestored = false;

  late TabSwitcherController controller;

  @override
  Widget build(BuildContext context) {
    return _buildBrowser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isRestored) {
      _isRestored = true;
      restore();
    }
    precacheImage(const AssetImage("assets/icon/icon.png"), context);
  }

  @override
  void dispose() {
    super.dispose();
  }

  getIntentData() async {
    if (Util.isAndroid()) {
      String? url = await platform.invokeMethod("getIntentData");
      if (url != null) {
        if (mounted) {
          var browserModel = Provider.of<BrowserModel>(context, listen: false);
          browserModel.addTab(WebViewTab(
            key: GlobalKey(),
            webViewModel: WebViewModel(url: WebUri(url)),
          ));
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    controller = TabSwitcherController();
    getIntentData();
  }

  restore() async {
    var browserModel = Provider.of<BrowserModel>(context, listen: true);
    browserModel.restore();
  }

  Widget _buildBrowser() {
    var currentWebViewModel = Provider.of<WebViewModel>(context, listen: true);
    var browserModel = Provider.of<BrowserModel>(context, listen: true);

    browserModel.addListener(() {
      browserModel.save();
    });
    currentWebViewModel.addListener(() {
      browserModel.save();
    });

    var canShowTabScroller =
        browserModel.showTabScroller && browserModel.webViewTabs.isNotEmpty;

    return IndexedStack(
      index: canShowTabScroller ? 1 : 0,
      children: [
        _buildWebViewTabs(),
        canShowTabScroller ? _buildWebViewTabsViewer() : Container()
      ],
    );
  }

  Widget _buildWebViewTabs() {
    var browserModel = Provider.of<BrowserModel>(context, listen: false);
    var webViewModel = browserModel.getCurrentTab()?.webViewModel;
    var webViewController = webViewModel?.webViewController;
    return WillPopScope(
      onWillPop: () async {
        if (webViewController != null) {
          if (await webViewController.canGoBack()) {
            webViewController.goBack();
            return false;
          }
        }

        if (webViewModel != null && webViewModel.tabIndex != null) {
          setState(() {
            browserModel.closeTab(webViewModel.tabIndex!);
          });
          if (mounted) {
            FocusScope.of(context).unfocus();
          }
          return false;
        }

        return browserModel.webViewTabs.isEmpty;
      },
      child: Listener(
        onPointerUp: (_) {
          FocusScopeNode currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus &&
              currentFocus.focusedChild != null) {
            currentFocus.focusedChild!.unfocus();
          }
        },
        child: Scaffold(
          // appBar: const BrowserAppBar(),
          // body: _buildWebViewTabsContent(),
          body: TabSwitcherWidget(
            controller: controller,
            appBarBuilder: ((context, tab) => tab != null
                ? AppBar(
                    // title: NewTabButton(controller: controller),
                    actions: [TabCountIcon(controller: controller)],
                  )
                : AppBar(
                    elevation: 0,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    foregroundColor:
                        Theme.of(context).textTheme.bodyText1!.color,
                    titleSpacing: 8,
                    title: NewTabButton(controller: controller),
                    actions: [TabCountIcon(controller: controller)],
                  )),
          ),
          bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                  border: Border(
                top: BorderSide(
                    color: Colors.grey, width: 1, style: BorderStyle.solid),
              )),
              alignment: Alignment.topCenter,
              height: 83,
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () async {
                        if (webViewController != null) {
                          if (await webViewController.canGoBack()) {
                            webViewController.goBack();
                          }
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (webViewController != null) {
                          if (await webViewController.canGoForward()) {
                            webViewController.goForward();
                          }
                        }
                      },
                      icon: Icon((webViewController != null
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.home_max_rounded)),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.menu),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.file_download_rounded),
                    ),
                    TabCountIcon(controller: controller),
                  ])),
        ),
      ),
    );
  }

  Widget _buildWebViewTabsContent() {
    var browserModel = Provider.of<BrowserModel>(context, listen: true);

    if (browserModel.webViewTabs.isEmpty) {
      // return const EmptyTab();
    }

    var stackChildren = <Widget>[
      IndexedStack(
        index: browserModel.getCurrentTabIndex(),
        children: browserModel.webViewTabs.map((webViewTab) {
          var isCurrentTab = webViewTab.webViewModel.tabIndex ==
              browserModel.getCurrentTabIndex();

          if (isCurrentTab) {
            Future.delayed(const Duration(milliseconds: 100), () {
              webViewTabStateKey.currentState?.onShowTab();
            });
          } else {
            webViewTabStateKey.currentState?.onHideTab();
          }

          return webViewTab;
        }).toList(),
      ),
      _createProgressIndicator()
    ];

    return Stack(
      children: stackChildren,
    );
  }

  Widget _buildWebViewTabsViewer() {
    var browserModel = Provider.of<BrowserModel>(context, listen: true);

    return WillPopScope(
        onWillPop: () async {
          browserModel.showTabScroller = false;
          return false;
        },
        child: Scaffold(
            // appBar: const TabViewerAppBar(),
            body: TabViewer(
          currentIndex: browserModel.getCurrentTabIndex(),
          children: browserModel.webViewTabs.map((webViewTab) {
            webViewTabStateKey.currentState?.pause();
            var screenshotData = webViewTab.webViewModel.screenshot;
            Widget screenshotImage = SizedBox(
              // decoration: const BoxDecoration(color: Colors.white),
              width: double.infinity,
              child:
                  screenshotData != null ? Image.memory(screenshotData) : null,
            );

            var url = webViewTab.webViewModel.url;
            var faviconUrl = webViewTab.webViewModel.favicon != null
                ? webViewTab.webViewModel.favicon!.url
                : (url != null && ["http", "https"].contains(url.scheme)
                    ? Uri.parse("${url.origin}/favicon.ico")
                    : null);

            var isCurrentTab = browserModel.getCurrentTabIndex() ==
                webViewTab.webViewModel.tabIndex;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Material(
                  color: isCurrentTab
                      ? const Color(0xFF3F3F47)
                      : (webViewTab.webViewModel.isIncognitoMode
                          ? Colors.black
                          : Colors.white),
                  child: ListTile(
                    leading: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // CachedNetworkImage(
                        //   placeholder: (context, url) =>
                        //   url == "about:blank"
                        //       ? Container()
                        //       : CircularProgressIndicator(),
                        //   imageUrl: faviconUrl,
                        //   height: 30,
                        // )
                        CustomImage(
                            url: faviconUrl, maxWidth: 30.0, height: 30.0)
                      ],
                    ),
                    title: Text(
                        webViewTab.webViewModel.title ??
                            webViewTab.webViewModel.url?.toString() ??
                            "",
                        maxLines: 2,
                        style: TextStyle(
                          color: webViewTab.webViewModel.isIncognitoMode ||
                                  isCurrentTab
                              ? Colors.white
                              : Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis),
                    subtitle:
                        Text(webViewTab.webViewModel.url?.toString() ?? "",
                            style: TextStyle(
                              color: webViewTab.webViewModel.isIncognitoMode ||
                                      isCurrentTab
                                  ? Colors.white60
                                  : Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 20.0,
                            color: webViewTab.webViewModel.isIncognitoMode ||
                                    isCurrentTab
                                ? Colors.white60
                                : Colors.black54,
                          ),
                          onPressed: () {
                            setState(() {
                              if (webViewTab.webViewModel.tabIndex != null) {
                                browserModel.closeTab(
                                    webViewTab.webViewModel.tabIndex!);
                                if (browserModel.webViewTabs.isEmpty) {
                                  browserModel.showTabScroller = false;
                                }
                              }
                            });
                          },
                        )
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: screenshotImage,
                )
              ],
            );
          }).toList(),
          onTap: (index) async {
            browserModel.showTabScroller = false;
            browserModel.showTab(index);
          },
        )));
  }

  Widget _createProgressIndicator() {
    return Selector<WebViewModel, double>(
        selector: (context, webViewModel) => webViewModel.progress,
        builder: (context, progress, child) {
          if (progress >= 1.0) {
            return Container();
          }
          return PreferredSize(
              preferredSize: const Size(double.infinity, 4.0),
              child: SizedBox(
                  height: 4.0,
                  child: LinearProgressIndicator(
                    value: progress,
                  )));
        });
  }
}
