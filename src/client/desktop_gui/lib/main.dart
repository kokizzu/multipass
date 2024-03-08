import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'catalogue/catalogue.dart';
import 'daemon_unavailable.dart';
import 'help.dart';
import 'logger.dart';
import 'notifications.dart';
import 'providers.dart';
import 'settings/settings.dart';
import 'sidebar.dart';
import 'tray_menu.dart';
import 'vm_details/vm_details.dart';
import 'vm_table/vm_table_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupLogger();

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1400, 800),
    title: 'Multipass',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await hotKeyManager.unregisterAll();
  final sharedPreferences = await SharedPreferences.getInstance();

  final providerContainer = ProviderContainer(overrides: [
    guiSettingProvider.overrideWith(() {
      return GuiSettingNotifier(sharedPreferences);
    }),
  ]);
  setupTrayMenu(providerContainer);
  runApp(
    UncontrolledProviderScope(
      container: providerContainer,
      child: MaterialApp(theme: theme, home: const App()),
    ),
  );
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WindowListener {
  @override
  Widget build(BuildContext context) {
    final currentKey = ref.watch(sidebarKeyProvider);
    final sidebarExpanded = ref.watch(sidebarExpandedProvider);
    final sidebarPushContent = ref.watch(sidebarPushContentProvider);
    final vms = ref.watch(vmNamesProvider);

    final widgets = {
      CatalogueScreen.sidebarKey: const CatalogueScreen(),
      VmTableScreen.sidebarKey: const VmTableScreen(),
      SettingsScreen.sidebarKey: const SettingsScreen(),
      HelpScreen.sidebarKey: const HelpScreen(),
      for (final name in vms) 'vm-$name': VmDetailsScreen(name),
    };

    final content = Stack(fit: StackFit.expand, children: [
      for (final MapEntry(:key, value: widget) in widgets.entries)
        Visibility(
          key: Key(key),
          maintainState: true,
          visible: key == currentKey,
          child: widget,
        ),
    ]);

    return Stack(children: [
      AnimatedPositioned(
        duration: SideBar.animationDuration,
        bottom: 0,
        right: 0,
        top: 0,
        left: sidebarPushContent && sidebarExpanded
            ? SideBar.expandedWidth
            : SideBar.collapsedWidth,
        child: content,
      ),
      const SideBar(),
      const Align(
        alignment: Alignment.bottomRight,
        child: SizedBox(width: 300, child: NotificationList()),
      ),
      const DaemonUnavailable(),
    ]);
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  // @override
  // void onWindowClose() {
  //   final instancesRunning = ref
  //       .read(vmStatusesProvider)
  //       .values
  //       .any((status) => status == Status.RUNNING);
  //   if (!instancesRunning) exit(0);
  //
  //   stopAllInstances() {
  //     final notification = OperationNotification(
  //       text: 'Stopping all instances',
  //       future: ref.read(grpcClientProvider).stop([]).then((_) {
  //         windowManager.destroy();
  //         return 'Stopped all instances';
  //       }).onError((_, __) => throw 'Failed to stop all instances'),
  //     );
  //     ref.read(notificationsProvider.notifier).add(notification);
  //   }
  //
  //   switch (ref.read(guiSettingProvider(onAppCloseKey))) {
  //     case 'nothing':
  //       exit(0);
  //     case 'stop':
  //       stopAllInstances();
  //     default:
  //       showDialog(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (context) => AlertDialog(
  //           title: const Text('Keep instances running in the background?'),
  //           actions: [
  //             TextButton(
  //               child: const Text('No'),
  //               onPressed: () {
  //                 Navigator.of(context).pop();
  //                 stopAllInstances();
  //               },
  //             ),
  //             TextButton(
  //               child: const Text('Yes'),
  //               onPressed: () => exit(0),
  //             ),
  //           ],
  //         ),
  //       );
  //   }
  // }
}

final theme = ThemeData(
  useMaterial3: false,
  fontFamily: 'Ubuntu',
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.zero),
    isDense: true,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(),
    ),
    suffixIconColor: Colors.black,
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      disabledForegroundColor: Colors.black.withOpacity(0.5),
      foregroundColor: Colors.black,
      padding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
      ),
      side: const BorderSide(color: Color(0xff333333)),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w300,
      ),
    ),
  ),
  scaffoldBackgroundColor: Colors.white,
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      backgroundColor: const Color(0xff0E8620),
      disabledForegroundColor: Colors.white.withOpacity(0.5),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w300,
      ),
    ),
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: Colors.black,
    selectionColor: Colors.grey,
  ),
);
