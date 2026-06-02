part of '../main.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final api = ApiService();
  int tab = 0;
  bool loading = true;
  String? loadError;
  final List<AppEvent> events = [];
  final List<AppClient> clients = [];
  final List<Employee> employees = [];
  final List<ManualInvoice> manualInvoices = [];
  final List<AdditionalServiceItem> services = [];
  final List<CustomMenu> customMenus = [];
  final List<AppNotification> systemNotifications = [];
  BusinessProfile businessProfile = const BusinessProfile();
  String? selectedEventId;
  AppEvent? editingEvent;
  int createSession = 0;
  Timer? autoSyncTimer;
  DateTime? lastSyncedAt;

  @override
  void initState() {
    super.initState();
    refreshEvents();
    autoSyncTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => refreshEvents(silent: true));
  }

  @override
  void dispose() {
    autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshEvents({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        loadError = null;
      });
    }
    try {
      final bootstrap = await api.bootstrap();
      final universal = (bootstrap['universal'] as Map?) ?? {};
      final userData = (bootstrap['userData'] as Map?) ?? {};
      final loaded = decodeJsonList(userData['events'], AppEvent.fromJson);
      final loadedClients =
          decodeJsonList(userData['clients'], AppClient.fromJson);
      final loadedEmployees =
          decodeJsonList(userData['employees'], Employee.fromJson);
      final loadedManualInvoices =
          decodeJsonList(userData['manualInvoices'], ManualInvoice.fromJson);
      final menuItems =
          decodeJsonList(universal['menuItems'], MenuMasterItem.fromJson);
      final additionalServices = decodeJsonList(
          userData['additionalServices'], AdditionalServiceItem.fromJson);
      final loadedCustomMenus =
          decodeJsonList(userData['customMenus'], CustomMenu.fromJson);
      final loadedBusinessProfile = BusinessProfile.fromJson(
          Map<String, dynamic>.from(
              (userData['businessProfile'] as Map?) ?? const {}));
      if (!mounted) return;
      setState(() {
        events
          ..clear()
          ..addAll(loaded);
        clients
          ..clear()
          ..addAll(loadedClients);
        employees
          ..clear()
          ..addAll(loadedEmployees);
        manualInvoices
          ..clear()
          ..addAll(loadedManualInvoices);
        MenuMasterScreen.menuItems
          ..clear()
          ..addAll(menuItems);
        services
          ..clear()
          ..addAll(additionalServices);
        customMenus
          ..clear()
          ..addAll(loadedCustomMenus);
        businessProfile = loadedBusinessProfile;
        lastSyncedAt = DateTime.now();
        loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      final message = friendlyNetworkMessage(e);
      setState(() {
        if (!silent || events.isEmpty) loadError = message;
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> createEvent(EventDraft draft) async {
    showCpSnack(context,
        (draft.id ?? '').isEmpty ? 'Creating event...' : 'Updating event...');
    final event = await api.saveEventDraft(draft, eventId: draft.id);
    setState(() {
      final index = events.indexWhere((item) => item.id == event.id);
      if (index == -1) {
        events.add(event);
      } else {
        events[index] = event;
      }
      selectedEventId = event.id;
      tab = 1;
      editingEvent = null;
    });
  }

  Future<void> saveManualInvoice(ManualInvoice invoice) async {
    showCpSnack(context, 'Saving invoice...');
    final saved = await api.saveManualInvoice(invoice);
    setState(() {
      final index = manualInvoices.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        manualInvoices.add(saved);
      } else {
        manualInvoices[index] = saved;
      }
      tab = 3;
    });
  }

  Future<void> saveClient(AppClient client) async {
    showCpSnack(
        context, client.id.isEmpty ? 'Saving client...' : 'Updating client...');
    final saved = await api.saveClient(
        client.copyWith(mobile: normalizeMobileText(client.mobile)));
    setState(() {
      final index = clients.indexWhere((item) =>
          item.id == saved.id ||
          normalizeMobileText(item.mobile) == saved.mobile);
      if (index == -1) {
        clients.add(saved);
      } else {
        clients[index] = saved;
      }
    });
  }

  Future<void> deleteClient(AppClient client) async {
    showCpSnack(context, 'Deleting client...');
    if (client.id.isNotEmpty) await api.deleteClient(client.id);
    setState(() => clients.removeWhere((item) =>
        item.id == client.id ||
        normalizeMobileText(item.mobile) ==
            normalizeMobileText(client.mobile)));
  }

  Future<void> saveEmployee(Employee employee) async {
    showCpSnack(context,
        employee.id.isEmpty ? 'Saving employee...' : 'Updating employee...');
    final saved = await api.saveEmployee(
        employee.copyWith(mobile: normalizeMobileText(employee.mobile)));
    setState(() {
      final index = employees.indexWhere((item) =>
          item.id == saved.id ||
          normalizeMobileText(item.mobile) == saved.mobile);
      if (index == -1) {
        employees.add(saved);
      } else {
        employees[index] = saved;
      }
    });
  }

  Future<void> deleteEmployee(Employee employee) async {
    showCpSnack(context, 'Deleting employee...');
    if (employee.id.isNotEmpty) await api.deleteEmployee(employee.id);
    setState(() => employees.removeWhere((item) =>
        item.id == employee.id ||
        normalizeMobileText(item.mobile) ==
            normalizeMobileText(employee.mobile)));
  }

  Future<void> openManualInvoiceForm() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ManualInvoiceFormScreen(
            clients: clients, onSave: saveManualInvoice)));
    if (mounted) setState(() => tab = 3);
  }

  void openEventDetails(AppEvent event) {
    setState(() {
      selectedEventId = event.id;
      tab = 6;
    });
  }

  void updateSelectedEvent(AppEvent event) {
    setState(() {
      final index = events.indexWhere((item) => item.id == event.id);
      if (index == -1) {
        events.add(event);
      } else {
        events[index] = event;
      }
      selectedEventId = event.id;
    });
  }

  void openCreateEvent() {
    setState(() {
      editingEvent = null;
      selectedEventId = null;
      createSession++;
      tab = 5;
    });
  }

  void openEditEvent(AppEvent event) {
    setState(() {
      editingEvent = event;
      selectedEventId = event.id;
      createSession++;
      tab = 5;
    });
  }

  void upsertService(AdditionalServiceItem service) {
    showCpSnack(context, 'Updating service...');
    setState(() {
      final index = services.indexWhere((item) => item.id == service.id);
      if (index == -1) {
        services.add(service);
      } else {
        services[index] = service;
      }
    });
    unawaited(api.saveAdditionalService(service).then((saved) {
      if (!mounted) return;
      setState(() {
        final index = services.indexWhere((item) => item.id == saved.id);
        if (index == -1) {
          services.add(saved);
        } else {
          services[index] = saved;
        }
      });
    }).catchError((error) {
      if (mounted) {
        showCpSnack(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }));
  }

  void removeService(String id) {
    showCpSnack(context, 'Deleting service...');
    setState(() => services.removeWhere((item) => item.id == id));
    unawaited(api.deleteAdditionalService(id).catchError((error) {
      if (mounted) {
        showCpSnack(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }));
  }

  Future<void> saveCustomMenu(CustomMenu menu) async {
    showCpSnack(context, 'Saving custom menu...');
    final saved = await api.saveCustomMenu(menu);
    setState(() {
      final index = customMenus.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        customMenus.add(saved);
      } else {
        customMenus[index] = saved;
      }
    });
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    showCpSnack(context, 'Updating business profile...');
    final saved = await api.saveBusinessProfile(profile);
    setState(() => businessProfile = saved);
  }

  Future<void> saveInvoiceSettings(BusinessProfile profile) async {
    showCpSnack(context, 'Updating invoice settings...');
    final saved = await api.saveBusinessProfile(profile);
    setState(() => businessProfile = saved);
  }

  void addSystemNotification({
    required String title,
    required String message,
    required String kind,
    required IconData icon,
    required Color color,
  }) {
    setState(() {
      systemNotifications.insert(
          0,
          AppNotification(
              id: '$kind-${DateTime.now().microsecondsSinceEpoch}',
              eventId: '',
              title: title,
              message: message,
              kind: kind,
              icon: icon,
              color: color,
              date: DateTime.now()));
    });
  }

  Future<void> exportData() async {
    showCpSnack(context, 'Preparing export...');
    final uri = await api.backupExportUri();
    final launched = await launchUrl(uri,
        mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    addSystemNotification(
        title: launched ? 'Data export started' : 'Data export failed',
        message: launched
            ? 'CaterPro backup download was started.'
            : 'Could not open the backup download link.',
        kind: 'export',
        icon: Icons.download,
        color: launched ? Cp.primary : Cp.error);
    if (mounted) {
      showCpSnack(context,
          launched ? 'Backup export started' : 'Unable to start export');
    }
  }

  Future<void> importData() async {
    showCpSnack(context, 'Select backup file to import...');
    final result = await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;
    try {
      if (!mounted) return;
      showCpSnack(context, 'Importing data...');
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid CaterPro backup file');
      }
      final response = await api.importBackup(decoded);
      await refreshEvents(silent: true);
      if (!mounted) return;
      final counts = response['counts'] as Map?;
      addSystemNotification(
          title: 'Data import complete',
          message:
              '${counts?['events'] ?? 0} events and ${counts?['clients'] ?? 0} clients restored from backup.',
          kind: 'import',
          icon: Icons.upload_file,
          color: Cp.tertiary);
      showCpSnack(context,
          'Import complete: ${counts?['events'] ?? 0} events, ${counts?['clients'] ?? 0} clients restored');
    } catch (e) {
      addSystemNotification(
          title: 'Data import failed',
          message: e.toString().replaceFirst('Exception: ', ''),
          kind: 'import',
          icon: Icons.error_outline,
          color: Cp.error);
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> backupToGoogleDrive() async {
    showCpSnack(context, 'Preparing Google Drive backup...');
    await exportData();
    final launched = await launchUrl(
        Uri.parse('https://drive.google.com/drive/my-drive'),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank');
    addSystemNotification(
        title:
            launched ? 'Google Drive backup ready' : 'Google Drive unavailable',
        message: launched
            ? 'Upload the downloaded CaterPro backup file to Google Drive.'
            : 'Could not open Google Drive after export.',
        kind: 'drive-backup',
        icon: Icons.cloud_upload,
        color: launched ? Cp.primary : Cp.error);
    if (mounted && launched) {
      showCpSnack(
          context, 'Upload the downloaded CaterPro backup to Google Drive');
    }
  }

  Future<void> syncNow() async {
    showCpSnack(context, 'Syncing...');
    await refreshEvents(silent: true);
    if (mounted) showCpSnack(context, 'Synced with server');
  }

  void openNotifications() {
    setState(() => tab = 13);
  }

  void openUserManagement() {
    setState(() => tab = 14);
  }

  void openAppAppearance() {
    setState(() => tab = 15);
  }

  void openInvoiceSettings() {
    setState(() => tab = 16);
  }

  Future<bool> handleBackPressed() async {
    if (tab != 0) {
      setState(() {
        tab = 0;
        selectedEventId = null;
        editingEvent = null;
      });
      return false;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit CaterPro?'),
        content: const Text('Do you want to close the app?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Exit')),
        ],
      ),
    );
    return exit ?? false;
  }

  List<Widget> get pages => <Widget>[
        DashboardScreen(
            api: api,
            events: events,
            loading: loading,
            loadError: loadError,
            openCreate: openCreateEvent,
            openDetails: openEventDetails,
            refresh: refreshEvents),
        EventsScreen(
            events: events,
            loading: loading,
            loadError: loadError,
            openDetails: openEventDetails,
            openCreate: openCreateEvent,
            refresh: refreshEvents),
        ClientsScreen(
            clients: clients,
            events: events,
            manualInvoices: manualInvoices,
            onSaveClient: saveClient,
            onDeleteClient: deleteClient,
            openEvent: openEventDetails,
            openNotifications: openNotifications),
        BillingScreen(
            events: events,
            manualInvoices: manualInvoices,
            api: api,
            onSaveManualInvoice: saveManualInvoice,
            onAddManualInvoice: openManualInvoiceForm),
        SettingsScreen(
            openBusiness: () => setState(() => tab = 8),
            openInvoiceSettings: openInvoiceSettings,
            openMenu: () => setState(() => tab = 7),
            openCustomMenus: () => setState(() => tab = 11),
            openEmployees: () => setState(() => tab = 9),
            openRawMaterials: () => setState(() => tab = 10),
            openProduceItems: () => setState(() => tab = 12),
            openNotifications: openNotifications,
            openUserManagement: openUserManagement,
            openAppAppearance: openAppAppearance,
            onExportData: exportData,
            onImportData: importData,
            onBackupToGoogleDrive: backupToGoogleDrive,
            onSyncNow: syncNow,
            lastSyncedAt: lastSyncedAt,
            businessProfile: businessProfile,
            services: services,
            onSaveService: upsertService,
            onDeleteService: removeService),
        CreateEventScreen(
            key: ValueKey('create-$createSession-${editingEvent?.id ?? 'new'}'),
            initialEvent: editingEvent,
            onDraftSaved: updateSelectedEvent,
            onClose: () => setState(() {
                  editingEvent = null;
                  tab = 1;
                }),
            onCreate: createEvent,
            services: services,
            customMenus: customMenus,
            customerEvents: events,
            onSaveService: upsertService,
            onDeleteService: removeService),
        EventDetailsScreen(
            event: events
                .where((event) => event.id == selectedEventId)
                .firstOrNull,
            api: api,
            employees: employees,
            onEdit: openEditEvent,
            onEventUpdated: updateSelectedEvent,
            onClose: () => setState(() => tab = 1)),
        MenuMasterScreen(onClose: () => setState(() => tab = 4)),
        BusinessProfileScreen(
            profile: businessProfile,
            onSave: saveBusinessProfile,
            onClose: () => setState(() => tab = 4)),
        EmployeeScreen(
            api: api,
            employees: employees,
            onSave: saveEmployee,
            onDelete: deleteEmployee,
            onClose: () => setState(() => tab = 4)),
        RawMaterialScreen(onClose: () => setState(() => tab = 4)),
        CustomMenuScreen(
            onClose: () => setState(() => tab = 4),
            customMenus: customMenus,
            onSave: saveCustomMenu),
        ProduceItemScreen(onClose: () => setState(() => tab = 4)),
        NotificationsScreen(
            notifications: [
              ...systemNotifications,
              ...buildEventNotifications(events)
            ]..sort((a, b) => b.date.compareTo(a.date)),
            events: events,
            onOpenEvent: openEventDetails,
            onClose: () => setState(() => tab = 4)),
        UserManagementScreen(
            employees: employees, onClose: () => setState(() => tab = 4)),
        AppAppearanceScreen(onClose: () => setState(() => tab = 4)),
        InvoiceSettingsScreen(
            profile: businessProfile,
            onSave: saveInvoiceSettings,
            onClose: () => setState(() => tab = 4)),
      ];

  @override
  Widget build(BuildContext context) {
    final showNav = tab < 5;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await handleBackPressed();
        if (shouldExit) SystemNavigator.pop();
      },
      child: Scaffold(
        drawer: showNav
            ? CaterSideDrawer(
                index: tab, onChanged: (i) => setState(() => tab = i))
            : null,
        body: IndexedStack(index: tab, children: pages),
        floatingActionButton: showNav ? _fabForTab() : null,
      ),
    );
  }

  Widget? _fabForTab() {
    final icons = [Icons.add, Icons.add, Icons.add, Icons.add, null];
    if (icons[tab] == null) return null;
    return FloatingActionButton(
      backgroundColor: Cp.secondaryContainer,
      foregroundColor: Color(0xff694000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () {
        if (tab == 0 || tab == 1) {
          openCreateEvent();
        } else if (tab == 3) {
          openManualInvoiceForm();
        } else {
          showCpSnack(context, 'Add from this section will be enabled soon');
        }
      },
      child: Icon(icons[tab]),
    );
  }
}

class CaterSideDrawer extends StatelessWidget {
  const CaterSideDrawer(
      {super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const items = [
    (Icons.home_rounded, 'Dashboard'),
    (Icons.calendar_month_rounded, 'Events'),
    (Icons.group_rounded, 'Clients'),
    (Icons.receipt_long_rounded, 'Billing'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
              child: Row(
                children: [
                  const CircleAvatar(
                      radius: 26,
                      backgroundColor: Cp.primaryContainer,
                      child: Text('RC',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CaterPro',
                            style: TextStyle(
                                color: scheme.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        Text('CaterPro Manager',
                            style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                children: [
                  ...List.generate(items.length, (i) {
                    final selected = i == index;
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        selected: selected,
                        selectedTileColor: scheme.secondaryContainer,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                        leading: Icon(item.$1,
                            color: selected
                                ? scheme.onSecondaryContainer
                                : scheme.onSurfaceVariant),
                        title: Text(t(item.$2),
                            style: TextStyle(
                                color: selected
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurface,
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w700)),
                        onTap: () {
                          Navigator.pop(context);
                          onChanged(i);
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Divider(color: scheme.outlineVariant),
                  ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    leading: Icon(Icons.restaurant_menu,
                        color: scheme.onSurfaceVariant),
                    title: Text(t('Menu Master'),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.pop(context);
                      onChanged(7);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar(
      {super.key,
      required this.title,
      this.subtitle,
      this.leading,
      this.actions = const [],
      this.avatar = true});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool avatar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canOpenDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;
    final defaultLeading = canOpenDrawer
        ? Builder(
            builder: (context) => IconButton(
              tooltip: 'Open menu',
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: Icon(Icons.menu_rounded, color: scheme.primary),
            ),
          )
        : (avatar
            ? const CircleAvatar(
                radius: 20,
                backgroundColor: Cp.primaryContainer,
                child: Text('R',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800)))
            : const SizedBox.shrink());
    return SafeArea(
      bottom: false,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: scheme.surface,
        child: Row(
          children: [
            leading ?? defaultLeading,
            if (leading != null || avatar || canOpenDrawer)
              const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t(title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                              fontSize: 22,
                              height: 1.1,
                              fontWeight: FontWeight.w800)
                          .copyWith(color: scheme.primary)),
                  if (subtitle != null)
                    Text(t(subtitle!),
                        style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class CpCard extends StatelessWidget {
  const CpCard(
      {super.key,
      required this.child,
      this.color = Cp.card,
      this.padding = const EdgeInsets.all(16),
      this.borderColor,
      this.onTap});

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final actualColor = cpAdaptSurfaceColor(context, color);
    final actualBorder = borderColor == null
        ? cpOutlineVariant(context)
        : cpAdaptTextColor(context, borderColor!);
    final shadowAlpha =
        Theme.of(context).brightness == Brightness.dark ? .18 : .04;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: actualColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: actualBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: shadowAlpha),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
    return onTap == null
        ? card
        : InkWell(
            borderRadius: BorderRadius.circular(12), onTap: onTap, child: card);
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text,
      {super.key,
      this.color = Cp.surfaceHigh,
      this.textColor = Cp.onVariant,
      this.icon});
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final actualColor = cpAdaptSurfaceColor(context, color);
    final actualTextColor = cpAdaptTextColor(context, textColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: actualColor, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: actualTextColor),
            const SizedBox(width: 4)
          ],
          Text(text,
              style: TextStyle(
                  color: actualTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

void showCpSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Cp.primaryContainer,
    ),
  );
}

enum EventScreenAction {
  assignEmployees,
  downloadQuotation,
  downloadInvoice,
  currentDayMenu,
  allDaysMenu,
  shareEventInfo,
  shareMenu,
  deleteEvent,
  deleteDate,
  deleteMenu,
}

class EventActionMenuItem {
  const EventActionMenuItem(this.value, this.label, this.icon,
      {this.destructive = false});
  final EventScreenAction value;
  final String label;
  final IconData icon;
  final bool destructive;
}

const eventScreenActions = [
  EventActionMenuItem(
      EventScreenAction.assignEmployees, 'Assign Employees', Icons.group_add),
  EventActionMenuItem(EventScreenAction.downloadQuotation, 'Download Quotation',
      Icons.request_quote),
  EventActionMenuItem(EventScreenAction.downloadInvoice, 'Download Invoice',
      Icons.receipt_long),
  EventActionMenuItem(
      EventScreenAction.currentDayMenu, 'Current Day Menu', Icons.today),
  EventActionMenuItem(
      EventScreenAction.allDaysMenu, 'All Days Menu', Icons.date_range),
  EventActionMenuItem(
      EventScreenAction.shareEventInfo, 'Share Event Info', Icons.chat),
  EventActionMenuItem(EventScreenAction.shareMenu, 'Share Menu', Icons.share),
  EventActionMenuItem(
      EventScreenAction.deleteEvent, 'Delete Event', Icons.delete_forever,
      destructive: true),
  EventActionMenuItem(
      EventScreenAction.deleteDate, 'Delete Date', Icons.event_busy,
      destructive: true),
  EventActionMenuItem(
      EventScreenAction.deleteMenu, 'Delete Menu', Icons.no_meals,
      destructive: true),
];

Future<bool> confirmEventAction(
    BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title,
          style:
              const TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: FilledButton.styleFrom(
              backgroundColor: Cp.error, foregroundColor: Colors.white),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class ScreenFrame extends StatelessWidget {
  const ScreenFrame(
      {super.key,
      required this.topBar,
      required this.children,
      this.bottomPadding = 24});

  final Widget topBar;
  final List<Widget> children;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cpSurface(context),
      child: Column(
        children: [
          topBar,
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
