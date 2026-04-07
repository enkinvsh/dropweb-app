import 'dart:async';
import 'dart:convert';

import 'package:dropweb/common/common.dart';
import 'package:dropweb/enum/enum.dart';
import 'package:dropweb/models/models.dart';
import 'package:dropweb/plugins/app.dart';
import 'package:dropweb/providers/providers.dart';
import 'package:dropweb/state.dart';
import 'package:dropweb/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

class AccessView extends ConsumerStatefulWidget {
  const AccessView({super.key});

  @override
  ConsumerState<AccessView> createState() => _AccessViewState();
}

class _AccessViewState extends ConsumerState<AccessView> {
  List<String> acceptList = [];
  List<String> rejectList = [];
  late ScrollController _controller;
  final _completer = Completer();

  @override
  void initState() {
    super.initState();
    _updateInitList();
    _controller = ScrollController();
    _completer.complete(globalState.appController.getPackages());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateInitList() {
    acceptList = globalState.config.vpnProps.accessControl.acceptList;
    rejectList = globalState.config.vpnProps.accessControl.rejectList;
  }

  Widget _buildSearchButton() => IconButton(
        tooltip: appLocalizations.search,
        onPressed: () {
          showSearch(
            context: context,
            delegate: AccessControlSearchDelegate(
              acceptList: acceptList,
              rejectList: rejectList,
            ),
          ).then(
            (_) => setState(
              _updateInitList,
            ),
          );
        },
        icon: HugeIcon(icon: HugeIcons.strokeRoundedSearch01, size: 24),
      );

  Widget _buildSelectedAllButton({
    required bool isSelectedAll,
    required List<String> allValueList,
  }) {
    final tooltip = isSelectedAll
        ? appLocalizations.cancelSelectAll
        : appLocalizations.selectAll;
    return IconButton(
      tooltip: tooltip,
      onPressed: () {
        ref.read(vpnSettingProvider.notifier).updateState((state) {
          final isAccept =
              state.accessControl.mode == AccessControlMode.acceptSelected;
          if (isSelectedAll) {
            return switch (isAccept) {
              true => state.copyWith.accessControl(
                  acceptList: [],
                ),
              false => state.copyWith.accessControl(
                  rejectList: [],
                ),
            };
          } else {
            return switch (isAccept) {
              true => state.copyWith.accessControl(
                  acceptList: allValueList,
                ),
              false => state.copyWith.accessControl(
                  rejectList: allValueList,
                ),
            };
          }
        });
      },
      icon: isSelectedAll
          ? HugeIcon(
              icon: HugeIcons.strokeRoundedCursorRemoveSelection01, size: 24)
          : HugeIcon(
              icon: HugeIcons.strokeRoundedCursorAddSelection01, size: 24),
    );
  }

  Future<void> _intelligentSelected() async {
    final packageNames = ref.read(
      packageListSelectorStateProvider.select(
        (state) => state.list.map((item) => item.packageName),
      ),
    );
    final commonScaffoldState = context.commonScaffoldState;
    if (commonScaffoldState?.mounted != true) return;
    final selectedPackageNames =
        (await commonScaffoldState?.loadingRun<List<String>>(
              () async => await app?.getChinaPackageNames() ?? [],
            ))
                ?.toSet() ??
            {};
    final acceptList = packageNames
        .where((item) => !selectedPackageNames.contains(item))
        .toList();
    final rejectList =
        packageNames.where(selectedPackageNames.contains).toList();
    ref.read(vpnSettingProvider.notifier).updateState(
          (state) => state.copyWith.accessControl(
            acceptList: acceptList,
            rejectList: rejectList,
          ),
        );
  }

  Widget _buildSettingButton() => IconButton(
        onPressed: () async {
          final res = await showSheet<int>(
            context: context,
            props: const SheetProps(
              isScrollControlled: true,
            ),
            builder: (_, type) => AdaptiveSheetScaffold(
              type: type,
              body: const AccessControlPanel(),
              title: appLocalizations.proxiesSetting,
            ),
          );
          if (res == 1) {
            _intelligentSelected();
          }
        },
        icon: HugeIcon(icon: HugeIcons.strokeRoundedFilter, size: 24),
      );

  void _handleSelected(List<String> valueList, Package package, bool? value) {
    if (value == true) {
      valueList.add(package.packageName);
    } else {
      valueList.remove(package.packageName);
    }
    ref.read(vpnSettingProvider.notifier).updateState((state) =>
        switch (state.accessControl.mode == AccessControlMode.acceptSelected) {
          true => state.copyWith.accessControl(
              acceptList: valueList,
            ),
          false => state.copyWith.accessControl(
              rejectList: valueList,
            ),
        });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(packageListSelectorStateProvider);
    final accessControl = state.accessControl;
    final accessControlMode = accessControl.mode;
    final packages = state.getSortList(
      accessControlMode == AccessControlMode.acceptSelected
          ? acceptList
          : rejectList,
    );
    final currentList = accessControl.currentList;
    final packageNameList = packages.map((e) => e.packageName).toList();
    final valueList = currentList.intersection(packageNameList);
    final describe = accessControlMode == AccessControlMode.acceptSelected
        ? appLocalizations.accessControlAllowDesc
        : appLocalizations.accessControlNotAllowDesc;
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          flex: 0,
          child: ListItem.switchItem(
            title: Text(appLocalizations.appAccessControl),
            delegate: SwitchDelegate(
              value: accessControl.enable,
              onChanged: (enable) {
                ref.read(vpnSettingProvider.notifier).updateState(
                      (state) => state.copyWith.accessControl(
                        enable: enable,
                      ),
                    );
              },
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            height: 12,
          ),
        ),
        Flexible(
          child: DisabledMask(
            status: !accessControl.enable,
            child: Column(
              children: [
                ActivateBox(
                  active: accessControl.enable,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 4,
                      bottom: 4,
                      left: 16,
                      right: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: IntrinsicHeight(
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          appLocalizations.selected,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                        ),
                                      ),
                                      const Flexible(
                                        child: SizedBox(
                                          width: 8,
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          "${valueList.length}",
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Flexible(
                                  child: Text(describe),
                                )
                              ],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: _buildSearchButton(),
                            ),
                            Flexible(
                              child: _buildSelectedAllButton(
                                isSelectedAll:
                                    valueList.length == packageNameList.length,
                                allValueList: packageNameList,
                              ),
                            ),
                            Flexible(
                              child: _buildSettingButton(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: FutureBuilder(
                      future: _completer.future,
                      builder: (_, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return packages.isEmpty
                            ? NullStatus(
                                label: appLocalizations.noData,
                              )
                            : CommonScrollBar(
                                controller: _controller,
                                child: ListView.builder(
                                  controller: _controller,
                                  itemCount: packages.length,
                                  itemExtent: 72,
                                  itemBuilder: (_, index) {
                                    final package = packages[index];
                                    return PackageListItem(
                                      key: Key(package.packageName),
                                      package: package,
                                      value: valueList
                                          .contains(package.packageName),
                                      isActive: accessControl.enable,
                                      onChanged: (value) {
                                        _handleSelected(
                                            valueList, package, value);
                                      },
                                    );
                                  },
                                ),
                              );
                      }),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PackageListItem extends StatelessWidget {
  const PackageListItem({
    super.key,
    required this.package,
    required this.value,
    required this.isActive,
    required this.onChanged,
  });
  final Package package;
  final bool value;
  final bool isActive;
  final void Function(bool?) onChanged;

  @override
  Widget build(BuildContext context) => FadeScaleEnterBox(
        child: ActivateBox(
          active: isActive,
          child: ListItem.checkbox(
            leading: SizedBox(
              width: 48,
              height: 48,
              child: FutureBuilder<ImageProvider?>(
                future: app?.getPackageIcon(package.packageName),
                builder: (_, snapshot) {
                  if (!snapshot.hasData && snapshot.data == null) {
                    return Container();
                  } else {
                    return Image(
                      image: snapshot.data!,
                      gaplessPlayback: true,
                      width: 48,
                      height: 48,
                    );
                  }
                },
              ),
            ),
            title: Text(
              package.label,
              style: const TextStyle(
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
            subtitle: Text(
              package.packageName,
              style: const TextStyle(
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
            delegate: CheckboxDelegate(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
      );
}

class AccessControlSearchDelegate extends SearchDelegate {
  AccessControlSearchDelegate({
    required this.acceptList,
    required this.rejectList,
  });
  List<String> acceptList = [];
  List<String> rejectList = [];

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          onPressed: () {
            if (query.isEmpty) {
              close(context, null);
              return;
            }
            query = '';
          },
          icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 24),
        ),
        const SizedBox(
          width: 8,
        )
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () {
          close(context, null);
        },
        icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 24),
      );

  void _handleSelected(
      WidgetRef ref, List<String> valueList, Package package, bool? value) {
    if (value == true) {
      valueList.add(package.packageName);
    } else {
      valueList.remove(package.packageName);
    }
    ref.read(vpnSettingProvider.notifier).updateState((state) =>
        switch (state.accessControl.mode == AccessControlMode.acceptSelected) {
          true => state.copyWith.accessControl(
              acceptList: valueList,
            ),
          false => state.copyWith.accessControl(
              rejectList: valueList,
            ),
        });
  }

  Widget _packageList() {
    final lowQuery = query.toLowerCase();
    return Consumer(
      builder: (context, ref, __) {
        final vm3 = ref.watch(
          packageListSelectorStateProvider.select(
            (state) => VM3(
              a: state.getSortList(
                state.accessControl.mode == AccessControlMode.acceptSelected
                    ? acceptList
                    : rejectList,
              ),
              b: state.accessControl.enable,
              c: state.accessControl.currentList,
            ),
          ),
        );
        final packages = vm3.a;
        final queryPackages = packages
            .where(
              (package) =>
                  package.label.toLowerCase().contains(lowQuery) ||
                  package.packageName.contains(lowQuery),
            )
            .toList();
        final isAccessControl = vm3.b;
        final currentList = vm3.c;
        final packageNameList = packages.map((e) => e.packageName).toList();
        final valueList = currentList.intersection(packageNameList);
        return DisabledMask(
          status: !isAccessControl,
          child: ListView.builder(
            itemCount: queryPackages.length,
            itemBuilder: (_, index) {
              final package = queryPackages[index];
              return PackageListItem(
                key: Key(package.packageName),
                package: package,
                value: valueList.contains(package.packageName),
                isActive: isAccessControl,
                onChanged: (value) {
                  _handleSelected(
                    ref,
                    valueList,
                    package,
                    value,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _packageList();
}

class AccessControlPanel extends ConsumerStatefulWidget {
  const AccessControlPanel({
    super.key,
  });

  @override
  ConsumerState createState() => _AccessControlPanelState();
}

class _AccessControlPanelState extends ConsumerState<AccessControlPanel> {
  Widget _getIconWithAccessControlMode(AccessControlMode mode) =>
      switch (mode) {
        AccessControlMode.acceptSelected =>
          HugeIcon(icon: HugeIcons.strokeRoundedSettings02, size: 24),
        AccessControlMode.rejectSelected =>
          HugeIcon(icon: HugeIcons.strokeRoundedBlocked, size: 24),
      };

  String _getTextWithAccessControlMode(AccessControlMode mode) =>
      switch (mode) {
        AccessControlMode.acceptSelected => appLocalizations.whitelistMode,
        AccessControlMode.rejectSelected => appLocalizations.blacklistMode,
      };

  String _getTextWithAccessSortType(AccessSortType type) => switch (type) {
        AccessSortType.none => appLocalizations.defaultText,
        AccessSortType.name => appLocalizations.name,
        AccessSortType.time => appLocalizations.time,
      };

  Widget _getIconWithProxiesSortType(AccessSortType type) => switch (type) {
        AccessSortType.none =>
          HugeIcon(icon: HugeIcons.strokeRoundedSorting01, size: 24),
        AccessSortType.name =>
          HugeIcon(icon: HugeIcons.strokeRoundedSortingAZ01, size: 24),
        AccessSortType.time =>
          HugeIcon(icon: HugeIcons.strokeRoundedTimeline, size: 24),
      };

  List<Widget> _buildModeSetting() => generateSection(
        title: appLocalizations.mode,
        items: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            child: Consumer(
              builder: (_, ref, __) {
                final accessControlMode = ref.watch(
                  vpnSettingProvider
                      .select((state) => state.accessControl.mode),
                );
                return Wrap(
                  spacing: 16,
                  children: [
                    for (final item in AccessControlMode.values)
                      SettingInfoCard(
                        Info(
                          label: _getTextWithAccessControlMode(item),
                          iconWidget: _getIconWithAccessControlMode(item),
                        ),
                        isSelected: accessControlMode == item,
                        onPressed: () {
                          ref.read(vpnSettingProvider.notifier).updateState(
                                (state) => state.copyWith.accessControl(
                                  mode: item,
                                ),
                              );
                        },
                      )
                  ],
                );
              },
            ),
          )
        ],
      );

  List<Widget> _buildSortSetting() => generateSection(
        title: appLocalizations.sort,
        items: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            child: Consumer(
              builder: (_, ref, __) {
                final accessSortType = ref.watch(
                  vpnSettingProvider
                      .select((state) => state.accessControl.sort),
                );
                return Wrap(
                  spacing: 16,
                  children: [
                    for (final item in AccessSortType.values)
                      SettingInfoCard(
                        Info(
                          label: _getTextWithAccessSortType(item),
                          iconWidget: _getIconWithProxiesSortType(item),
                        ),
                        isSelected: accessSortType == item,
                        onPressed: () {
                          ref.read(vpnSettingProvider.notifier).updateState(
                                (state) => state.copyWith.accessControl(
                                  sort: item,
                                ),
                              );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      );

  List<Widget> _buildSourceSetting() => generateSection(
        title: appLocalizations.source,
        items: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            child: Consumer(
              builder: (_, ref, __) {
                final vm2 = ref.watch(
                  vpnSettingProvider.select(
                    (state) => VM2(
                      a: state.accessControl.isFilterSystemApp,
                      b: state.accessControl.isFilterNonInternetApp,
                    ),
                  ),
                );
                return Wrap(
                  spacing: 16,
                  children: [
                    SettingTextCard(
                      appLocalizations.systemApp,
                      isSelected: vm2.a == false,
                      onPressed: () {
                        ref.read(vpnSettingProvider.notifier).updateState(
                              (state) => state.copyWith.accessControl(
                                isFilterSystemApp: !vm2.a,
                              ),
                            );
                      },
                    ),
                    SettingTextCard(
                      appLocalizations.noNetworkApp,
                      isSelected: vm2.b == false,
                      onPressed: () {
                        ref.read(vpnSettingProvider.notifier).updateState(
                              (state) => state.copyWith.accessControl(
                                isFilterNonInternetApp: !vm2.b,
                              ),
                            );
                      },
                    )
                  ],
                );
              },
            ),
          )
        ],
      );

  Future<void> _copyToClipboard() async {
    await globalState.safeRun(() {
      final data = globalState.config.vpnProps.accessControl.toJson();
      Clipboard.setData(
        ClipboardData(
          text: json.encode(data),
        ),
      );
    });
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _pasteToClipboard() async {
    await globalState.safeRun(
      () async {
        final data = await Clipboard.getData('text/plain');
        final text = data?.text;
        if (text == null) return;
        ref.read(vpnSettingProvider.notifier).updateState(
              (state) => state.copyWith(
                accessControl: AccessControl.fromJson(
                  json.decode(text),
                ),
              ),
            );
      },
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  List<Widget> _buildActionSetting() => generateSection(
        title: appLocalizations.action,
        items: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Wrap(
              runSpacing: 16,
              spacing: 16,
              children: [
                CommonChip(
                  avatar: HugeIcon(
                      icon: HugeIcons.strokeRoundedActivitySpark, size: 24),
                  label: appLocalizations.intelligentSelected,
                  onPressed: () {
                    Navigator.of(context).pop(1);
                  },
                ),
                CommonChip(
                  avatar: HugeIcon(
                      icon: HugeIcons.strokeRoundedClipboardPaste, size: 24),
                  label: appLocalizations.clipboardImport,
                  onPressed: _pasteToClipboard,
                ),
                CommonChip(
                  avatar:
                      HugeIcon(icon: HugeIcons.strokeRoundedCopy01, size: 24),
                  label: appLocalizations.clipboardExport,
                  onPressed: _copyToClipboard,
                )
              ],
            ),
          )
        ],
      );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._buildModeSetting(),
              ..._buildSortSetting(),
              ..._buildSourceSetting(),
              ..._buildActionSetting(),
            ],
          ),
        ),
      );
}
