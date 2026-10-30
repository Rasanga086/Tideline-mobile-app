import 'package:flutter/widgets.dart';

/// Remembers which bottom-navigation tabs were visited, so Back returns to the previous tab
/// (app bar arrow, Android system back and the browser's back button on the web all arrive
/// as a pop of the shell's route). Once there is no earlier tab, Back does what it did before:
/// leaves the shell if it was pushed, or closes the app at the root.
mixin TabHistory<T extends StatefulWidget> on State<T> {
  int tabIndex = 0;
  final List<int> _visited = [];

  bool get canGoBackTab => _visited.isNotEmpty;

  /// Runs whenever a tab becomes visible, by tap or by Back.
  void onTabShown(int index) {}

  void selectTab(int index) {
    if (index == tabIndex) return;
    setState(() {
      // Each tab appears once, so the history stays short and Back never repeats a tab.
      _visited
        ..remove(tabIndex)
        ..remove(index)
        ..add(tabIndex);
      tabIndex = index;
    });
    onTabShown(index);
  }

  void backTab() {
    if (_visited.isEmpty) return;
    setState(() => tabIndex = _visited.removeLast());
    onTabShown(tabIndex);
  }

  /// Wrap the shell's Scaffold in this so Back pops tabs before it pops the route.
  Widget tabBackScope({required Widget child}) => PopScope(
    canPop: _visited.isEmpty,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) backTab();
    },
    child: child,
  );
}
