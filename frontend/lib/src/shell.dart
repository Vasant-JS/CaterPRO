part of '../main.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final api = ApiService();
  int tab = 0;
  int parentTab = 0;
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
  bool localSyncPending = false;
  static const _userDataCachePrefix = 'caterpro.userDataCache.v2.';

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

  Future<String> userDataCacheKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('auth.userId') ??
        prefs.getString('auth.email') ??
        prefs.getString('auth.token') ??
        'default';
    return '$_userDataCachePrefix$userId';
  }

  Future<Map<String, dynamic>> loadCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await userDataCacheKey());
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Ignore corrupt local cache; fresh backend data will replace it.
    }
    return {};
  }

  Future<void> saveCachedUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await userDataCacheKey(), jsonEncode(userData));
  }

  Future<void> cacheCurrentUserData(
      {Map<String, dynamic>? base, bool synced = false}) {
    final snapshot = currentUserDataJson(base: base);
    return Future.wait([
      saveCachedUserData(snapshot),
      LocalCaterProDb.instance.saveSnapshot(
        userData: snapshot,
        universal: currentUniversalJson(),
        synced: synced,
      ),
    ]).then((_) {
      localSyncPending = !synced;
    });
  }

  Map<String, dynamic> currentUserDataJson({Map<String, dynamic>? base}) => {
        if (base != null) ...base,
        'events': events.map((event) => event.toJson()).toList(),
        'clients': clients.map((client) => client.toJson()).toList(),
        'employees': employees.map((employee) => employee.toJson()).toList(),
        'manualInvoices':
            manualInvoices.map((invoice) => invoice.toJson()).toList(),
        'additionalServices':
            services.map((service) => service.toJson()).toList(),
        'customMenus': customMenus.map((menu) => menu.toJson()).toList(),
        'businessProfile': businessProfile.toJson(),
      };

  Map<String, dynamic> currentUniversalJson() => {
        'menuItems':
            MenuMasterScreen.menuItems.map((item) => item.toJson()).toList(),
      };

  Map<String, dynamic> mergeUserData(
      Map<String, dynamic> server, Map<String, dynamic> cached) {
    final merged = <String, dynamic>{...cached, ...server};
    const userLists = [
      'events',
      'clients',
      'employees',
      'attendance',
      'additionalServices',
      'customMenus',
      'manualInvoices',
    ];
    for (final key in userLists) {
      merged[key] = mergeRecordLists(cached[key], server[key], key: key);
    }
    merged['businessProfile'] = {
      if (cached['businessProfile'] is Map)
        ...Map<String, dynamic>.from(cached['businessProfile'] as Map),
      if (server['businessProfile'] is Map)
        ...Map<String, dynamic>.from(server['businessProfile'] as Map),
    };
    return merged;
  }

  Map<String, dynamic> normalizeUserData(Map<String, dynamic> userData) {
    final normalized = <String, dynamic>{...userData};
    normalized['events'] =
        jsonMapList(userData['events']).map(normalizeEventJson).toList();
    normalized['attendance'] =
        dedupeJsonList(userData['attendance'], key: 'attendance');
    return normalized;
  }

  Map<String, dynamic> normalizeEventJson(Map<String, dynamic> event) {
    final normalized = <String, dynamic>{...event};
    normalized['dates'] = mergeEventDateJsonList(event['dates']);
    normalized['payments'] = dedupeJsonList(event['payments'], key: 'payments');
    normalized['materialDocuments'] =
        dedupeJsonList(event['materialDocuments'], key: 'materialDocuments');
    normalized['employeeAssignments'] =
        dedupeJsonList(event['employeeAssignments'], key: 'employeeAssignments');
    return normalized;
  }

  List<Map<String, dynamic>> mergeEventDateJsonList(Object? value) {
    final byDate = <String, Map<String, dynamic>>{};
    for (final date in jsonMapList(value)) {
      final key = date['date']?.toString().isNotEmpty == true
          ? date['date'].toString()
          : date['id']?.toString() ?? '';
      final normalized = <String, dynamic>{
        ...date,
        'id': date['date']?.toString().isNotEmpty == true
            ? date['date'].toString()
            : date['id']?.toString() ?? '',
        'menuSlots': dedupeJsonList(date['menuSlots'], key: 'menuSlots'),
        'additionalServices':
            dedupeJsonList(date['additionalServices'], key: 'selectedServices'),
      };
      final existing = byDate[key];
      if (existing == null) {
        byDate[key] = normalized;
      } else {
        byDate[key] = {
          ...existing,
          ...normalized,
          'id': existing['date'] ?? existing['id'] ?? normalized['id'],
          'menuSlots': dedupeJsonList(
              [...jsonMapList(existing['menuSlots']), ...jsonMapList(normalized['menuSlots'])],
              key: 'menuSlots'),
          'additionalServices': dedupeJsonList([
            ...jsonMapList(existing['additionalServices']),
            ...jsonMapList(normalized['additionalServices'])
          ], key: 'selectedServices'),
        };
      }
    }
    return byDate.values.toList();
  }

  List<Map<String, dynamic>> dedupeJsonList(Object? value, {required String key}) {
    final byKey = <String, Map<String, dynamic>>{};
    for (final item in jsonMapList(value)) {
      byKey[recordKey(item, key)] = item;
    }
    return byKey.values.toList();
  }

  List<Map<String, dynamic>> mergeRecordLists(Object? cached, Object? server,
      {required String key}) {
    final records = <String, Map<String, dynamic>>{};
    final order = <String>[];
    void addAll(Object? source, bool fromServer) {
      for (final item in jsonMapList(source)) {
        final id = recordKey(item, key);
        if (!order.contains(id)) order.add(id);
        final previous = records[id];
        records[id] = previous == null
            ? item
            : fromServer
                ? mergeRecord(previous, item, key)
                : mergeRecord(item, previous, key);
      }
    }

    addAll(cached, false);
    addAll(server, true);
    return order.map((id) => records[id]!).toList();
  }

  Map<String, dynamic> mergeRecord(
      Map<String, dynamic> cached, Map<String, dynamic> server, String key) {
    final merged = <String, dynamic>{...cached, ...server};
    if (key == 'events') {
      merged['dates'] =
          mergeRecordLists(cached['dates'], server['dates'], key: 'eventDates');
      merged['payments'] = mergeRecordLists(cached['payments'],
          server['payments'], key: 'payments');
      merged['materialDocuments'] = mergeRecordLists(
          cached['materialDocuments'], server['materialDocuments'],
          key: 'materialDocuments');
      merged['employeeAssignments'] = mergeRecordLists(
          cached['employeeAssignments'], server['employeeAssignments'],
          key: 'employeeAssignments');
    } else if (key == 'eventDates') {
      merged['menuSlots'] = mergeRecordLists(cached['menuSlots'],
          server['menuSlots'], key: 'menuSlots');
      merged['additionalServices'] = mergeRecordLists(
          cached['additionalServices'], server['additionalServices'],
          key: 'selectedServices');
    } else if (key == 'menuSlots') {
      merged['menuItemIds'] =
          mergeStringList(cached['menuItemIds'], server['menuItemIds']);
      merged['additionalServices'] = mergeRecordLists(
          cached['additionalServices'], server['additionalServices'],
          key: 'selectedServices');
    } else if (key == 'materialDocuments') {
      merged['items'] =
          mergeRecordLists(cached['items'], server['items'], key: 'materialItems');
    }
    return merged;
  }

  List<Map<String, dynamic>> jsonMapList(Object? value) {
    return ((value as List?) ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<String> mergeStringList(Object? cached, Object? server) {
    final values = <String>[];
    for (final source in [cached, server]) {
      for (final item in ((source as List?) ?? const [])) {
        final value = item.toString();
        if (value.isNotEmpty && !values.contains(value)) values.add(value);
      }
    }
    return values;
  }

  String recordKey(Map<String, dynamic> item, String listKey) {
    if (listKey == 'eventDates') {
      final date = item['date']?.toString() ?? '';
      if (date.isNotEmpty) return date;
    }
    final id = item['id']?.toString() ?? '';
    if (id.isNotEmpty) return id;
    if (listKey == 'attendance') {
      return [
        item['eventId'],
        item['employeeId'],
        item['date'],
      ].map((value) => value?.toString() ?? '').join('|');
    }
    if (listKey == 'selectedServices') {
      return [
        item['serviceId'],
        item['name'],
        item['count'],
      ].map((value) => value?.toString() ?? '').join('|');
    }
    if (listKey == 'materialItems') {
      return [
        item['itemId'],
        item['name'],
        item['quantity'],
      ].map((value) => value?.toString() ?? '').join('|');
    }
    final mobile = item['mobile']?.toString() ?? '';
    if (mobile.isNotEmpty) return mobile;
    final name = item['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    return jsonEncode(item);
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
      final serverUserData = Map<String, dynamic>.from(
          (bootstrap['userData'] as Map?) ?? const {});
      final userData = normalizeUserData(serverUserData);
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
      await saveCachedUserData(userData);
      await LocalCaterProDb.instance.saveSnapshot(
          userData: userData, universal: Map<String, dynamic>.from(universal), synced: true);
      localSyncPending = false;
    } catch (e) {
      final localSnapshot = await LocalCaterProDb.instance.loadSnapshot();
      if (localSnapshot != null) {
        final universal =
            Map<String, dynamic>.from(localSnapshot['universal'] as Map);
        final userData =
            Map<String, dynamic>.from(localSnapshot['userData'] as Map);
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
          localSyncPending = true;
          loadError = 'Offline mode: showing local SQLite data';
        });
        return;
      }
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
    unawaited(cacheCurrentUserData(synced: true));
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
    unawaited(cacheCurrentUserData(synced: true));
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
    unawaited(cacheCurrentUserData(synced: true));
  }

  Future<void> deleteClient(AppClient client) async {
    showCpSnack(context, 'Deleting client...');
    if (client.id.isNotEmpty) await api.deleteClient(client.id);
    setState(() => clients.removeWhere((item) =>
        item.id == client.id ||
        normalizeMobileText(item.mobile) ==
            normalizeMobileText(client.mobile)));
    unawaited(cacheCurrentUserData(synced: true));
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
    unawaited(cacheCurrentUserData(synced: true));
  }

  Future<void> deleteEmployee(Employee employee) async {
    showCpSnack(context, 'Deleting employee...');
    if (employee.id.isNotEmpty) await api.deleteEmployee(employee.id);
    setState(() => employees.removeWhere((item) =>
        item.id == employee.id ||
        normalizeMobileText(item.mobile) ==
            normalizeMobileText(employee.mobile)));
    unawaited(cacheCurrentUserData(synced: true));
  }

  Future<void> openManualInvoiceForm() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ManualInvoiceFormScreen(
            clients: clients, onSave: saveManualInvoice)));
    if (mounted) setState(() => tab = 3);
  }

  void openEventDetails(AppEvent event) {
    setState(() {
      parentTab = tab == 6 ? parentTab : tab;
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
    unawaited(cacheCurrentUserData(synced: true));
  }

  void removeSelectedEvent(String eventId) {
    setState(() {
      events.removeWhere((event) => event.id == eventId);
      if (selectedEventId == eventId) selectedEventId = null;
    });
    unawaited(cacheCurrentUserData(synced: true));
  }

  void openCreateEvent() {
    setState(() {
      parentTab = tab == 5 ? parentTab : tab;
      editingEvent = null;
      selectedEventId = null;
      createSession++;
      tab = 5;
    });
  }

  void openEditEvent(AppEvent event) {
    setState(() {
      parentTab = tab == 5 ? parentTab : tab;
      editingEvent = event;
      selectedEventId = event.id;
      createSession++;
      tab = 5;
    });
  }

  void openChildTab(int nextTab) {
    setState(() {
      parentTab = tab;
      tab = nextTab;
    });
  }

  int parentForTab(int current) {
    if (current == 5 && editingEvent != null) {
      return selectedEventId == null ? 1 : 6;
    }
    if (current == 5 || current == 6) {
      return parentTab == current ? 1 : parentTab;
    }
    if ({7, 8, 9, 10, 11, 12, 13, 15, 16, 17}.contains(current)) {
      return 4;
    }
    if (current != 0) return parentTab == current ? 0 : parentTab;
    return 0;
  }

  void closeToParent() {
    setState(() {
      final next = parentForTab(tab);
      tab = next;
      if (next != 6) selectedEventId = null;
      if (next != 5) editingEvent = null;
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
    unawaited(cacheCurrentUserData());
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
      unawaited(cacheCurrentUserData(synced: true));
    }).catchError((error) {
      if (mounted) {
        showCpSnack(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }));
  }

  void removeService(String id) {
    showCpSnack(context, 'Deleting service...');
    setState(() => services.removeWhere((item) => item.id == id));
    unawaited(cacheCurrentUserData());
    unawaited(api.deleteAdditionalService(id).then((_) {
      unawaited(cacheCurrentUserData(synced: true));
    }).catchError((error) {
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
    unawaited(cacheCurrentUserData(synced: true));
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    showCpSnack(context, 'Updating business profile...');
    final saved = await api.saveBusinessProfile(profile);
    setState(() => businessProfile = saved);
    unawaited(cacheCurrentUserData(synced: true));
  }

  Future<void> saveInvoiceSettings(BusinessProfile profile) async {
    showCpSnack(context, 'Updating invoice settings...');
    final saved = await api.saveBusinessProfile(profile);
    setState(() => businessProfile = saved);
    unawaited(cacheCurrentUserData(synced: true));
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
    openChildTab(13);
  }

  void openUserManagement() {
    openChildTab(14);
  }

  void openAppAppearance() {
    openChildTab(15);
  }

  void openInvoiceSettings() {
    openChildTab(16);
  }

  Future<bool> handleBackPressed() async {
    if (tab != 0) {
      closeToParent();
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
            openClients: () => setState(() => tab = 2),
            openBilling: () => setState(() => tab = 3),
            openInvoice: openManualInvoiceForm,
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
            openBusiness: () => openChildTab(8),
            openInvoiceSettings: openInvoiceSettings,
            openMenu: () => openChildTab(7),
            openCustomMenus: () => openChildTab(11),
            openEmployees: () => openChildTab(9),
            openRawMaterials: () => openChildTab(10),
            openProduceItems: () => openChildTab(12),
            openNotifications: openNotifications,
            openUserManagement: openUserManagement,
            openReports: () => openChildTab(17),
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
            onClose: closeToParent,
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
            onEventDeleted: removeSelectedEvent,
            onClose: closeToParent),
        MenuMasterScreen(onClose: closeToParent),
        BusinessProfileScreen(
            profile: businessProfile,
            onSave: saveBusinessProfile,
            onClose: closeToParent),
        EmployeeScreen(
            api: api,
            employees: employees,
            events: events,
            onSave: saveEmployee,
            onDelete: deleteEmployee,
            onClose: closeToParent),
        RawMaterialScreen(onClose: closeToParent),
        CustomMenuScreen(
            onClose: closeToParent,
            customMenus: customMenus,
            onSave: saveCustomMenu),
        ProduceItemScreen(onClose: closeToParent),
        NotificationsScreen(
            notifications: [
              ...systemNotifications,
              ...buildEventNotifications(events)
            ]..sort((a, b) => b.date.compareTo(a.date)),
            events: events,
            onOpenEvent: openEventDetails,
            onClose: closeToParent),
        UserManagementScreen(employees: employees, onClose: closeToParent),
        AppAppearanceScreen(onClose: closeToParent),
        InvoiceSettingsScreen(
            profile: businessProfile,
            onSave: saveInvoiceSettings,
            onClose: closeToParent),
        ReportsScreen(
            api: api,
            events: events,
            employees: employees,
            manualInvoices: manualInvoices,
            onClose: closeToParent),
      ];

  @override
  Widget build(BuildContext context) {
    const drawerTabs = {0, 1, 2, 3, 4, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17};
    final showDrawer = drawerTabs.contains(tab);
    final showMainFab = tab < 5;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await handleBackPressed();
        if (shouldExit) SystemNavigator.pop();
      },
      child: Scaffold(
        drawer: showDrawer
            ? CaterSideDrawer(
                index: tab,
                onChanged: (i) => setState(() {
                      parentTab = 0;
                      selectedEventId = null;
                      editingEvent = null;
                      tab = i;
                    }))
            : null,
        body: IndexedStack(index: tab, children: pages),
        floatingActionButton: showMainFab ? _fabForTab() : null,
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

  static const settingsSubItems = [
    (9, Icons.badge, 'Employees'),
    (17, Icons.analytics_outlined, 'Reports'),
    (16, Icons.description, 'Invoice Settings'),
    (13, Icons.notifications, 'Notifications'),
    (15, Icons.wb_sunny, 'App Appearance'),
  ];

  static const settingsTabs = {4, 8, 9, 10, 11, 12, 13, 15, 16, 17};

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
                    final selected =
                        i == index || (i == 4 && settingsTabs.contains(index));
                    final item = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
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
                          if (i == 4 && settingsTabs.contains(index))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(52, 4, 8, 2),
                              child: Column(
                                children: settingsSubItems.map((subItem) {
                                  final subSelected = index == subItem.$1;
                                  return ListTile(
                                    dense: true,
                                    minLeadingWidth: 24,
                                    visualDensity: VisualDensity.compact,
                                    selected: subSelected,
                                    selectedTileColor:
                                        scheme.primary.withValues(alpha: .12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    leading: Icon(subItem.$2,
                                        size: 19,
                                        color: subSelected
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant),
                                    title: Text(t(subItem.$3),
                                        style: TextStyle(
                                            color: subSelected
                                                ? scheme.primary
                                                : scheme.onSurfaceVariant,
                                            fontSize: 13,
                                            fontWeight: subSelected
                                                ? FontWeight.w900
                                                : FontWeight.w700)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      onChanged(subItem.$1);
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
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
