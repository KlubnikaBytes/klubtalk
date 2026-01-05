import 'dart:html' as html;

void preventBrowserContextMenu() {
  html.document.onContextMenu.listen((event) => event.preventDefault());
}
