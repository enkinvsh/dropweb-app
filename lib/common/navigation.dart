import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/views/views.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class Navigation {
  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }

  Navigation._internal();
  static Navigation? _instance;

  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
  }) =>
      [
        NavigationItem(
          keep: false,
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedDashboardSquare01, size: 24),
          label: PageLabel.dashboard,
          view: const DashboardView(
            key: GlobalObjectKey(PageLabel.dashboard),
          ),
        ),
        NavigationItem(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedSettings02, size: 24),
          label: PageLabel.tools,
          view: const ToolsView(
            key: GlobalObjectKey(
              PageLabel.tools,
            ),
          ),
          modes: const [NavigationItemMode.desktop, NavigationItemMode.mobile],
        ),
      ];
}

final navigation = Navigation();
