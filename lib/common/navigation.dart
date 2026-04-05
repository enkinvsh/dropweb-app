import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/views/views.dart';
import 'package:flutter/material.dart';

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
  }) => [
      const NavigationItem(
        keep: false,
        icon: Icon(Icons.space_dashboard),
        label: PageLabel.dashboard,
        view: DashboardView(
          key: GlobalObjectKey(PageLabel.dashboard),
        ),
      ),
      NavigationItem(
        icon: const Icon(Icons.article),
        label: PageLabel.proxies,
        view: const ProxiesView(
          key: GlobalObjectKey(
            PageLabel.proxies,
          ),
        ),
        modes: hasProxies
            ? [NavigationItemMode.mobile, NavigationItemMode.desktop]
            : [],
      ),
      const NavigationItem(
        icon: Icon(Icons.folder),
        label: PageLabel.profiles,
        view: ProfilesView(
          key: GlobalObjectKey(
            PageLabel.profiles,
          ),
        ),
      ),

      const NavigationItem(
        icon: Icon(Icons.construction),
        label: PageLabel.tools,
        view: ToolsView(
          key: GlobalObjectKey(
            PageLabel.tools,
          ),
        ),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
    ];
}

final navigation = Navigation();
