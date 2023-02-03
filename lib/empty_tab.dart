import 'package:flutter/material.dart';
import 'package:flutter_browser/webview_tab.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:tab_switcher/tab_switcher.dart';

import 'models/browser_model.dart';
import 'models/webview_model.dart';

class EmptyTab extends TabSwitcherTab {
  final _controller = TextEditingController();

  @override
  Widget build(TabState state) => StatefulBuilder(builder: (context, setState) {
        var browserModel = Provider.of<BrowserModel>(context, listen: true);
        var settings = browserModel.getSettings();

        void openNewTab(value) {
          browserModel.addTab(WebViewTab(
            key: GlobalKey(),
            webViewModel: WebViewModel(
                url: WebUri(value.startsWith("http")
                    ? value
                    : settings.searchEngine.searchUrl + value)),
          ));
        }

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image(image: AssetImage(settings.searchEngine.assetIcon)),
                const SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                        child: TextField(
                      controller: _controller,
                      onSubmitted: (value) {
                        openNewTab(value);
                      },
                      textInputAction: TextInputAction.go,
                      decoration: const InputDecoration(
                        hintText: "Search for or type a web address",
                        hintStyle:
                            TextStyle(color: Colors.black54, fontSize: 25.0),
                      ),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 25.0,
                      ),
                    )),
                    IconButton(
                      icon: const Icon(Icons.search,
                          color: Colors.black54, size: 25.0),
                      onPressed: () {
                        openNewTab(_controller.text);
                        FocusScope.of(context).unfocus();
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      });
  @override
  String getTitle() => 'Start page';
  @override
  void onSave(TabState state) {}
}
