import 'package:dropweb/common/print.dart';
import 'package:dropweb/plugins/tile.dart';
import 'package:dropweb/state.dart';
import 'package:flutter/material.dart';

class TileManager extends StatefulWidget {
  const TileManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  State<TileManager> createState() => _TileContainerState();
}

class _TileContainerState extends State<TileManager> with TileListener {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void onStart() {
    commonPrint.log('TileManager.onStart — syncing UI to running');
    globalState.appController.updateStatus(true);
    super.onStart();
  }

  @override
  Future<void> onStop() async {
    commonPrint.log('TileManager.onStop — syncing UI to stopped');
    globalState.appController.updateStatus(false);
    super.onStop();
  }

  @override
  void initState() {
    super.initState();
    tile?.addListener(this);
  }

  @override
  void dispose() {
    tile?.removeListener(this);
    super.dispose();
  }
}
