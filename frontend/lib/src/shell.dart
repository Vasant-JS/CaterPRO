part of '../main.dart';

class SyncProgress {
  const SyncProgress({
    required this.percent,
    required this.label,
    this.detail = '',
    this.active = true,
    this.warning = false,
  });

  final int percent;
  final String label;
  final String detail;
  final bool active;
  final bool warning;
}

class _MasterDataDownloadStatus {
  const _MasterDataDownloadStatus({
    required this.message,
    required this.downloading,
    required this.canRetry,
  }) : error = null;

  const _MasterDataDownloadStatus.downloading()
      : message =
            'Setting up menu items and inventory master data. Please wait.',
        downloading = true,
        canRetry = false,
        error = null;

  const _MasterDataDownloadStatus.error(String errorText)
      : message = 'Unable to download master data.',
        downloading = false,
        canRetry = true,
        error = errorText;

  final String message;
  final bool downloading;
  final bool canRetry;
  final String? error;
}

class _ShellRoute {
  const _ShellRoute({
    required this.tab,
    this.selectedEventId,
    this.editingEvent,
    this.createInitialStep = 0,
  });

  final int tab;
  final String? selectedEventId;
  final AppEvent? editingEvent;
  final int createInitialStep;
}

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
  final List<AuditLogEntry> auditLogs = [];
  final List<AppNotification> systemNotifications = [];
  BusinessProfile businessProfile = const BusinessProfile();
  String? selectedEventId;
  AppEvent? editingEvent;
  int createSession = 0;
  int eventsSession = 0;
  int createInitialStep = 0;
  Timer? autoSyncTimer;
  DateTime? lastSyncedAt;
  bool localSyncPending = false;
  bool syncInProgress = false;
  SyncProgress? syncProgress;
  final List<_ShellRoute> routeStack = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (mounted) unawaited(startupRefresh());
      });
    });
    autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!loading) unawaited(refreshEvents(silent: true));
    });
  }

  @override
  void dispose() {
    autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> cacheCurrentUserData(
      {Map<String, dynamic>? base, bool synced = false}) {
    final snapshot = currentUserDataJson(base: base);
    return LocalCaterProDb.instance
        .saveSnapshot(
      userData: snapshot,
      universal: currentUniversalJson(),
      synced: synced,
    )
        .then((_) {
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
        'menuItems':
            MenuMasterScreen.menuItems.map((item) => item.toJson()).toList(),
        'customMenus': customMenus.map((menu) => menu.toJson()).toList(),
        'auditLogs': auditLogs.map((entry) => entry.toJson()).toList(),
        'businessProfile': businessProfile.toJson(),
      };

  Map<String, dynamic> currentUniversalJson() => {};

  String localId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  void updateSyncProgress(
    int percent,
    String label, {
    String detail = '',
    bool active = true,
    bool warning = false,
  }) {
    if (!mounted) return;
    setState(() {
      syncProgress = SyncProgress(
        percent: percent.clamp(0, 100).toInt(),
        label: label,
        detail: detail,
        active: active,
        warning: warning,
      );
    });
  }

  String mirrorSyncDetail(Map<String, dynamic> response) {
    final mirror = response['mirrorSync'];
    if (mirror is! Map) return '';
    final status = mirror['status']?.toString() ?? '';
    if (status == 'failed' || status == 'skipped') return '';
    final failed = ((mirror['failedTables'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    if (failed.isNotEmpty) {
      return 'Mirror table issue: ${failed.take(3).join(', ')}';
    }
    if (status == 'synced') return 'Supabase mirror tables updated.';
    return status.isEmpty ? '' : 'Mirror status: $status';
  }

  int userDataRecordCount(Map<String, dynamic> userData) {
    var total = 0;
    for (final key in [
      'events',
      'clients',
      'employees',
      'attendance',
      'additionalServices',
      'menuItems',
      'rawMaterials',
      'produceItems',
      'vesselItems',
      'customMenus',
      'requirementLists',
      'payments',
      'manualInvoices',
      'auditLogs',
    ]) {
      total += ((userData[key] as List?) ?? const []).length;
    }
    return total;
  }

  AppEvent localEventFromDraft(EventDraft draft) {
    final eventId =
        (draft.id ?? '').trim().isEmpty ? localId('evt') : draft.id!.trim();
    draft.id = eventId;
    final existing = events.where((event) => event.id == eventId).firstOrNull;
    return AppEvent.fromJson({
      if (existing != null) ...existing.toJson(),
      ...draft.toJson(),
      'id': eventId,
    });
  }

  AppClient localClient(AppClient client) {
    final now = DateTime.now().toIso8601String();
    return client.copyWith(
      id: client.id.trim().isEmpty ? localId('client') : client.id.trim(),
      mobile: normalizeMobileText(client.mobile),
      createdAt: client.createdAt.isEmpty ? now : client.createdAt,
      updatedAt: now,
    );
  }

  Employee localEmployee(Employee employee) => employee.copyWith(
        id: employee.id.trim().isEmpty ? localId('emp') : employee.id.trim(),
        mobile: normalizeMobileText(employee.mobile),
      );

  ManualInvoice localManualInvoice(ManualInvoice invoice) {
    final id = invoice.id.trim().isEmpty ? localId('minv') : invoice.id.trim();
    return ManualInvoice(
      id: id,
      clientName: invoice.clientName,
      mobile: normalizeMobileText(invoice.mobile),
      clientAddress: invoice.clientAddress,
      clientGst: invoice.clientGst,
      eventName: invoice.eventName,
      venue: invoice.venue,
      eventDate: invoice.eventDate,
      invoiceDate: invoice.invoiceDate,
      invoiceNumber: invoice.invoiceNumber.trim().isEmpty
          ? 'INV-${id.split('_').last}'
          : invoice.invoiceNumber,
      notes: invoice.notes,
      items: invoice.items,
      subtotal: invoice.subtotal,
      total: invoice.total,
      advance: invoice.advance,
      settlement: invoice.settlement,
      pending: invoice.pending,
    );
  }

  void recordAudit({
    required String action,
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String summary,
    Map<String, dynamic>? metadata,
  }) {
    auditLogs.insert(
      0,
      AuditLogEntry(
        id: localId('audit'),
        action: action,
        entityType: entityType,
        entityId: entityId,
        entityLabel: entityLabel,
        summary: summary,
        createdAt: DateTime.now(),
        metadata: metadata ?? const {},
      ),
    );
    if (auditLogs.length > 1000) {
      auditLogs.removeRange(1000, auditLogs.length);
    }
  }

  void recordAuditAndBackup({
    required String action,
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String summary,
    Map<String, dynamic>? metadata,
  }) {
    recordAudit(
      action: action,
      entityType: entityType,
      entityId: entityId,
      entityLabel: entityLabel,
      summary: summary,
      metadata: metadata,
    );
    backupCurrentSnapshotQuietly();
  }

  void backupCurrentSnapshotQuietly() {
    unawaited(cacheCurrentUserData()
        .then((_) => refreshEvents(silent: true))
        .catchError((_) {}));
  }

  Future<void> startupRefresh() async {
    final ready = await ensureMasterDataReady();
    if (!mounted || !ready) return;
    await refreshEvents();
  }

  Future<bool> ensureMasterDataReady() async {
    if (await LocalCaterProDb.instance.hasMasterData()) return true;
    if (!mounted) return false;

    final status = ValueNotifier<_MasterDataDownloadStatus>(
      const _MasterDataDownloadStatus.downloading(),
    );
    var retrySignal = Completer<void>();

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: ValueListenableBuilder<_MasterDataDownloadStatus>(
            valueListenable: status,
            builder: (context, value, _) {
              return AlertDialog(
                title: const Text('Downloading master data'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (value.downloading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        else
                          Icon(Icons.error_outline,
                              color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 14),
                        Expanded(child: Text(value.message)),
                      ],
                    ),
                    if (value.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        value.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (value.canRetry)
                    FilledButton.icon(
                      onPressed: () {
                        status.value =
                            const _MasterDataDownloadStatus.downloading();
                        if (!retrySignal.isCompleted) retrySignal.complete();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                ],
              );
            },
          ),
        );
      },
    ));

    while (mounted) {
      try {
        final loadedMenuItems = await api.getMenuItems();
        final rawMaterials = await api.getRawMaterials();
        final produceItems = await api.getProduceItems();
        final vesselItems = await api.getVesselItems();
        final universal = {
          'menuItems': loadedMenuItems.map((item) => item.toJson()).toList(),
          'rawMaterials': rawMaterials.map((item) => item.toJson()).toList(),
          'produceItems': produceItems.map((item) => item.toJson()).toList(),
          'vesselItems': vesselItems.map((item) => item.toJson()).toList(),
        };
        final missing = [
          if (loadedMenuItems.isEmpty) 'menu items',
          if (produceItems.isEmpty) 'vegetables and fruits',
          if (vesselItems.isEmpty) 'vessels and utensils',
        ];
        if (missing.isNotEmpty) {
          throw Exception('Master data missing: ${missing.join(', ')}');
        }
        await LocalCaterProDb.instance.saveMasterData(
          universal: universal,
          synced: true,
        );
        if (!mounted) return false;
        setState(() {
          MenuMasterScreen.menuItems
            ..clear()
            ..addAll(loadedMenuItems);
        });
        Navigator.of(context, rootNavigator: true).pop();
        return true;
      } catch (error) {
        if (!mounted) return false;
        status.value = _MasterDataDownloadStatus.error(
          error.toString().replaceFirst('Exception: ', ''),
        );
        retrySignal = Completer<void>();
        await retrySignal.future;
      }
    }
    return false;
  }

  Map<String, dynamic> mergeUniversalData(
      Map<String, dynamic> server, Map<String, dynamic> local,
      {required bool preferLocal}) {
    final preferred = preferLocal ? local : server;
    final fallback = preferLocal ? server : local;
    return {
      ...fallback,
      ...preferred,
      'menuItems': jsonMapList(server['menuItems']),
      'rawMaterials': mergeRecordLists(
        fallback['rawMaterials'],
        preferred['rawMaterials'],
        key: 'rawMaterials',
      ),
      'produceItems': mergeRecordLists(
        fallback['produceItems'],
        preferred['produceItems'],
        key: 'produceItems',
      ),
      'vesselItems': mergeRecordLists(
        fallback['vesselItems'],
        preferred['vesselItems'],
        key: 'vesselItems',
      ),
    };
  }

  Map<String, dynamic> mergeUserData(
      Map<String, dynamic> server, Map<String, dynamic> cached) {
    final merged = <String, dynamic>{...cached, ...server};
    const userLists = [
      'clients',
      'employees',
      'attendance',
      'additionalServices',
      'customMenus',
      'manualInvoices',
      'auditLogs',
    ];
    merged['events'] = mergeServerEventsWithLocalDrafts(
      server['events'],
      cached['events'],
    );
    for (final key in userLists) {
      merged[key] = mergeRecordLists(cached[key], server[key], key: key);
    }
    merged['businessProfile'] = mergeBusinessProfileData(
        server['businessProfile'], cached['businessProfile']);
    return merged;
  }

  Map<String, dynamic> mergeBusinessProfileData(
      Object? preferred, Object? fallback) {
    final preferredProfile = preferred is Map
        ? Map<String, dynamic>.from(preferred)
        : <String, dynamic>{};
    final fallbackProfile = fallback is Map
        ? Map<String, dynamic>.from(fallback)
        : <String, dynamic>{};
    final merged = <String, dynamic>{...fallbackProfile, ...preferredProfile};
    for (final entry in fallbackProfile.entries) {
      final preferredValue = preferredProfile[entry.key];
      final fallbackValue = entry.value;
      if (preferredValue is String &&
          preferredValue.trim().isEmpty &&
          fallbackValue is String &&
          fallbackValue.trim().isNotEmpty) {
        merged[entry.key] = fallbackValue;
      }
    }
    return merged;
  }

  bool hasBusinessProfileDetails(Object? value) {
    if (value is! Map) return false;
    for (final key in const [
      'businessName',
      'serviceType',
      'gstin',
      'pan',
      'address',
      'phone',
      'email',
      'accountHolderName',
      'bankName',
      'branchName',
      'accountNumber',
      'ifsc',
      'terms',
      'logoBase64',
      'signatureBase64',
      'qrBase64',
    ]) {
      final field = value[key];
      if (field is String && field.trim().isNotEmpty) return true;
    }
    return false;
  }

  bool hasBusinessProfileImages(Object? value) {
    if (value is! Map) return false;
    for (final key in const ['logoBase64', 'signatureBase64', 'qrBase64']) {
      final field = value[key];
      if (field is! String || field.trim().isEmpty) return false;
    }
    return true;
  }

  List<Map<String, dynamic>> mergeServerEventsWithLocalDrafts(
      Object? server, Object? cached) {
    final serverEvents = jsonMapList(server);
    final serverIds = serverEvents
        .map((event) => event['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final localDrafts = jsonMapList(cached).where((event) {
      final id = event['id']?.toString() ?? '';
      return id.startsWith('evt_') && !serverIds.contains(id);
    });
    return [...serverEvents, ...localDrafts];
  }

  Map<String, dynamic> normalizeUserData(Map<String, dynamic> userData) {
    final normalized = <String, dynamic>{...userData};
    normalized['events'] =
        jsonMapList(userData['events']).map(normalizeEventJson).toList();
    normalized['attendance'] =
        dedupeJsonList(userData['attendance'], key: 'attendance');
    normalized['menuItems'] = jsonMapList(userData['menuItems']);
    normalized['rawMaterials'] = jsonMapList(userData['rawMaterials']);
    normalized['produceItems'] = jsonMapList(userData['produceItems']);
    normalized['vesselItems'] = jsonMapList(userData['vesselItems']);
    normalized['auditLogs'] =
        dedupeJsonList(userData['auditLogs'], key: 'auditLogs')
          ..sort((a, b) => (b['createdAt']?.toString() ?? '')
              .compareTo(a['createdAt']?.toString() ?? ''));
    return normalized;
  }

  Map<String, dynamic> normalizeEventJson(Map<String, dynamic> event) {
    final normalized = <String, dynamic>{...event};
    normalized['dates'] = mergeEventDateJsonList(event['dates']);
    normalized['payments'] = dedupeJsonList(event['payments'], key: 'payments');
    normalized['materialDocuments'] =
        dedupeJsonList(event['materialDocuments'], key: 'materialDocuments');
    normalized['employeeAssignments'] = dedupeJsonList(
        event['employeeAssignments'],
        key: 'employeeAssignments');
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
          'menuSlots': dedupeJsonList([
            ...jsonMapList(existing['menuSlots']),
            ...jsonMapList(normalized['menuSlots'])
          ], key: 'menuSlots'),
          'additionalServices': dedupeJsonList([
            ...jsonMapList(existing['additionalServices']),
            ...jsonMapList(normalized['additionalServices'])
          ], key: 'selectedServices'),
        };
      }
    }
    return byDate.values.toList();
  }

  List<Map<String, dynamic>> dedupeJsonList(Object? value,
      {required String key}) {
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
      merged['payments'] = mergeRecordLists(
          cached['payments'], server['payments'],
          key: 'payments');
      merged['materialDocuments'] = mergeRecordLists(
          cached['materialDocuments'], server['materialDocuments'],
          key: 'materialDocuments');
      merged['employeeAssignments'] = mergeRecordLists(
          cached['employeeAssignments'], server['employeeAssignments'],
          key: 'employeeAssignments');
    } else if (key == 'eventDates') {
      merged['menuSlots'] = mergeRecordLists(
          cached['menuSlots'], server['menuSlots'],
          key: 'menuSlots');
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
      merged['items'] = mergeRecordLists(cached['items'], server['items'],
          key: 'materialItems');
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
    if (listKey == 'auditLogs') {
      return [
        item['id'],
        item['action'],
        item['entityType'],
        item['entityId'],
        item['createdAt'],
      ].map((value) => value?.toString() ?? '').join('|');
    }
    final mobile = item['mobile']?.toString() ?? '';
    if (mobile.isNotEmpty) return mobile;
    final name = item['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    return jsonEncode(item);
  }

  Future<void> applySnapshot({
    required Map<String, dynamic> userData,
    required Map<String, dynamic> universal,
    required bool synced,
    String? error,
    bool updateLastSynced = false,
    bool persist = true,
  }) async {
    final normalized = normalizeUserData(userData);
    final loaded = decodeJsonList(normalized['events'], AppEvent.fromJson);
    final loadedClients =
        decodeJsonList(normalized['clients'], AppClient.fromJson);
    final loadedEmployees =
        decodeJsonList(normalized['employees'], Employee.fromJson);
    final loadedManualInvoices =
        decodeJsonList(normalized['manualInvoices'], ManualInvoice.fromJson);
    final menuSource = jsonMapList(normalized['menuItems']).isNotEmpty
        ? normalized['menuItems']
        : universal['menuItems'];
    final menuItems = decodeJsonList(menuSource, MenuMasterItem.fromJson);
    final additionalServices = decodeJsonList(
        normalized['additionalServices'], AdditionalServiceItem.fromJson);
    final loadedCustomMenus =
        decodeJsonList(normalized['customMenus'], CustomMenu.fromJson);
    final loadedAuditLogs =
        decodeJsonList(normalized['auditLogs'], AuditLogEntry.fromJson);
    final loadedBusinessProfile = BusinessProfile.fromJson(
        Map<String, dynamic>.from(
            (normalized['businessProfile'] as Map?) ?? const {}));
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
      auditLogs
        ..clear()
        ..addAll(loadedAuditLogs);
      businessProfile = loadedBusinessProfile;
      localSyncPending = !synced;
      loadError = error;
      if (updateLastSynced) lastSyncedAt = DateTime.now();
    });
    if (persist) {
      await LocalCaterProDb.instance.saveSnapshot(
        userData: normalized,
        universal: universal,
        synced: synced,
      );
    }
  }

  Future<void> pushCurrentSnapshot() async {
    if (syncInProgress) return;
    syncInProgress = true;
    updateSyncProgress(10, 'Preparing sync');
    try {
      updateSyncProgress(35, 'Uploading local changes');
      final response = await api.pushSyncSnapshot(
        userData: currentUserDataJson(),
        universal: currentUniversalJson(),
        includeMirrorSync: false,
      );
      updateSyncProgress(80, 'Refreshing app data');
      final universal = Map<String, dynamic>.from(
          (response['universal'] as Map?) ?? const {});
      final userData =
          Map<String, dynamic>.from((response['userData'] as Map?) ?? const {});
      await applySnapshot(
        userData: userData,
        universal: universal,
        synced: true,
        updateLastSynced: true,
      );
      final detail = mirrorSyncDetail(response);
      updateSyncProgress(100, 'Sync complete',
          detail: detail,
          active: false,
          warning: detail.startsWith('Mirror table issue'));
    } finally {
      syncInProgress = false;
    }
  }

  Future<void> cacheAndPushCurrentSnapshot() async {
    await cacheCurrentUserData();
    try {
      await pushCurrentSnapshot();
    } catch (_) {
      if (mounted) {
        setState(() {
          localSyncPending = true;
          loadError = null;
        });
      }
    }
  }

  Future<void> refreshEvents({bool silent = false}) async {
    if (syncInProgress) return;
    syncInProgress = true;
    if (!silent) {
      setState(() {
        loading = true;
        loadError = null;
      });
      updateSyncProgress(5, 'Starting sync');
    }
    Map<String, dynamic>? localUserData;
    Map<String, dynamic>? localUniversal;
    var localDirty = false;
    Map<String, dynamic>? localSnapshot;
    try {
      localSnapshot = await LocalCaterProDb.instance
          .loadSnapshot()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      localSnapshot = null;
    }
    if (!silent) updateSyncProgress(20, 'Reading local cache');
    if (localSnapshot != null) {
      localUserData =
          Map<String, dynamic>.from(localSnapshot['userData'] as Map);
      localUniversal =
          Map<String, dynamic>.from(localSnapshot['universal'] as Map);
      localDirty = await LocalCaterProDb.instance.hasUnsyncedChanges();
      await applySnapshot(
        userData: localUserData,
        universal: localUniversal,
        synced: !localDirty,
        error: null,
        persist: false,
      );
    }
    try {
      if (!silent) updateSyncProgress(40, 'Downloading server snapshot');
      final snapshot = await api.getSyncSnapshot();
      final serverUniversal = Map<String, dynamic>.from(
          (snapshot['universal'] as Map?) ?? const {});
      var serverUserData = normalizeUserData(Map<String, dynamic>.from(
          (snapshot['userData'] as Map?) ?? const {}));
      if (!hasBusinessProfileDetails(serverUserData['businessProfile']) ||
          !hasBusinessProfileImages(serverUserData['businessProfile'])) {
        try {
          if (!silent) updateSyncProgress(50, 'Fetching business profile');
          final remoteProfile = await api.getBusinessProfile();
          final remoteProfileJson = remoteProfile.toJson();
          if (hasBusinessProfileDetails(remoteProfileJson) ||
              hasBusinessProfileImages(remoteProfileJson)) {
            serverUserData = normalizeUserData({
              ...serverUserData,
              'businessProfile': mergeBusinessProfileData(
                remoteProfileJson,
                serverUserData['businessProfile'],
              ),
            });
          }
        } catch (_) {}
      }
      final localHasData =
          localUserData != null && userDataRecordCount(localUserData) > 0;
      final serverHasNoUserData = userDataRecordCount(serverUserData) == 0;
      final localHasOnlyBusinessProfile = localUserData != null &&
          hasBusinessProfileDetails(localUserData['businessProfile']) &&
          !hasBusinessProfileDetails(serverUserData['businessProfile']);
      final shouldUploadLocal = localDirty ||
          (localHasData && serverHasNoUserData) ||
          localHasOnlyBusinessProfile;
      if (localUserData == null || localUniversal == null) {
        if (!silent) updateSyncProgress(75, 'Saving local copy');
        await applySnapshot(
          userData: serverUserData,
          universal: serverUniversal,
          synced: true,
          updateLastSynced: true,
        );
        if (!silent) {
          updateSyncProgress(100, 'Sync complete', active: false);
        }
        return;
      }
      if (!shouldUploadLocal) {
        if (!silent) updateSyncProgress(75, 'Applying server changes');
        await applySnapshot(
          userData: serverUserData,
          universal: serverUniversal,
          synced: true,
          updateLastSynced: true,
        );
        if (!silent) {
          updateSyncProgress(100, 'Sync complete', active: false);
        }
        return;
      }
      if (!silent) updateSyncProgress(60, 'Merging local changes');
      final mergedUserData = normalizeUserData(shouldUploadLocal
          ? mergeUserData(localUserData, serverUserData)
          : mergeUserData(serverUserData, localUserData));
      final mergedUniversal = mergeUniversalData(
        serverUniversal,
        localUniversal,
        preferLocal: localDirty,
      );
      if (!silent) updateSyncProgress(80, 'Uploading merged data');
      final pushed = await api.pushSyncSnapshot(
        userData: mergedUserData,
        universal: mergedUniversal,
        includeMirrorSync: false,
      );
      await applySnapshot(
        userData:
            Map<String, dynamic>.from((pushed['userData'] as Map?) ?? const {}),
        universal: Map<String, dynamic>.from(
            (pushed['universal'] as Map?) ?? const {}),
        synced: true,
        updateLastSynced: true,
      );
      if (!silent) {
        final detail = mirrorSyncDetail(pushed);
        updateSyncProgress(100, 'Sync complete',
            detail: detail,
            active: false,
            warning: detail.startsWith('Mirror table issue'));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (localSnapshot != null) localSyncPending = true;
        loadError = null;
      });
      if (!silent) {
        updateSyncProgress(100, 'Sync incomplete',
            detail: e.toString().replaceFirst('Exception: ', ''),
            active: false,
            warning: true);
      }
    } finally {
      syncInProgress = false;
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> createEvent(EventDraft draft) async {
    showCpSnack(context,
        (draft.id ?? '').isEmpty ? 'Creating event...' : 'Updating event...');
    final creating = (draft.id ?? '').trim().isEmpty ||
        !events.any((item) => item.id == (draft.id ?? '').trim());
    final event = localEventFromDraft(draft);
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
      recordAudit(
        action: creating ? 'create' : 'update',
        entityType: 'event',
        entityId: event.id,
        entityLabel: event.name,
        summary: creating
            ? 'Created event ${event.name}'
            : 'Updated event ${event.name}',
        metadata: {
          'client': event.primaryClient,
          'mobile': event.mobile,
          'venue': event.venue,
        },
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> saveManualInvoice(ManualInvoice invoice) async {
    showCpSnack(context, 'Saving invoice...');
    final creating = invoice.id.trim().isEmpty ||
        !manualInvoices.any((item) => item.id == invoice.id.trim());
    final saved = localManualInvoice(invoice);
    setState(() {
      final index = manualInvoices.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        manualInvoices.add(saved);
      } else {
        manualInvoices[index] = saved;
      }
      tab = 3;
      recordAudit(
        action: creating ? 'create' : 'update',
        entityType: 'manualInvoice',
        entityId: saved.id,
        entityLabel:
            saved.invoiceNumber.isEmpty ? saved.eventName : saved.invoiceNumber,
        summary: creating
            ? 'Created invoice ${saved.invoiceNumber}'
            : 'Updated invoice ${saved.invoiceNumber}',
        metadata: {
          'client': saved.clientName,
          'mobile': saved.mobile,
          'total': saved.total,
          'pending': saved.pending,
        },
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> deleteManualInvoice(ManualInvoice invoice) async {
    showCpSnack(context, 'Deleting invoice...');
    setState(() {
      manualInvoices.removeWhere((item) => item.id == invoice.id);
      recordAudit(
        action: 'delete',
        entityType: 'manualInvoice',
        entityId: invoice.id,
        entityLabel: invoice.invoiceNumber.isEmpty
            ? invoice.eventName
            : invoice.invoiceNumber,
        summary:
            'Deleted invoice ${invoice.invoiceNumber.isEmpty ? invoice.eventName : invoice.invoiceNumber}',
        metadata: {
          'client': invoice.clientName,
          'mobile': invoice.mobile,
          'total': invoice.total,
          'pending': invoice.pending,
        },
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> deleteEventPaymentInvoice(
      AppEvent event, AppPayment payment) async {
    showCpSnack(context, 'Deleting invoice payment...');
    setState(() {
      final index = events.indexWhere((item) => item.id == event.id);
      if (index == -1) return;
      final json = events[index].toJson();
      json['payments'] = events[index]
          .payments
          .where((item) => item.id != payment.id)
          .map((item) => item.toJson())
          .toList();
      events[index] = AppEvent.fromJson(json);
      recordAudit(
        action: 'delete',
        entityType: 'eventInvoice',
        entityId: payment.id,
        entityLabel: event.name,
        summary: 'Deleted invoice payment for ${event.name}',
        metadata: {
          'eventId': event.id,
          'amount': payment.amount,
          'date': payment.date,
          'mode': payment.mode,
        },
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> saveClient(AppClient client) async {
    showCpSnack(
        context, client.id.isEmpty ? 'Saving client...' : 'Updating client...');
    final previousClient = client.id.isEmpty
        ? null
        : clients
            .where((item) => item.id == client.id)
            .cast<AppClient?>()
            .firstOrNull;
    final previousMobile = normalizeMobileText(previousClient?.mobile ?? '');
    final previousName = previousClient?.name ?? '';
    final saved = localClient(client);
    final creating = previousClient == null &&
        !clients.any((item) =>
            normalizeMobileText(item.mobile) ==
            normalizeMobileText(saved.mobile));
    setState(() {
      final index = clients.indexWhere((item) =>
          item.id == saved.id ||
          normalizeMobileText(item.mobile) == saved.mobile);
      if (index == -1) {
        clients.add(saved);
      } else {
        clients[index] = saved;
      }
      final savedMobile = normalizeMobileText(saved.mobile);
      for (var index = 0; index < events.length; index++) {
        final event = events[index];
        final eventMobile = normalizeMobileText(event.mobile);
        final linkedByMobile =
            (previousMobile.isNotEmpty && eventMobile == previousMobile) ||
                (savedMobile.isNotEmpty && eventMobile == savedMobile);
        final linkedByPreviousName = previousName.trim().isNotEmpty &&
            event.primaryClient.trim() == previousName.trim();
        if (!linkedByMobile && !linkedByPreviousName) continue;
        final json = event.toJson();
        json['mobile'] = saved.mobile;
        if (saved.name.isNotEmpty) json['primaryClient'] = saved.name;
        json['updatedAt'] = saved.updatedAt;
        events[index] = AppEvent.fromJson(json);
      }
      for (var index = 0; index < manualInvoices.length; index++) {
        final invoice = manualInvoices[index];
        final invoiceMobile = normalizeMobileText(invoice.mobile);
        final linkedByMobile =
            (previousMobile.isNotEmpty && invoiceMobile == previousMobile) ||
                (savedMobile.isNotEmpty && invoiceMobile == savedMobile);
        final linkedByPreviousName = previousName.trim().isNotEmpty &&
            invoice.clientName.trim() == previousName.trim();
        if (!linkedByMobile && !linkedByPreviousName) continue;
        final json = invoice.toJson();
        json['mobile'] = saved.mobile;
        if (saved.name.isNotEmpty) json['clientName'] = saved.name;
        if (saved.address.isNotEmpty || saved.city.isNotEmpty) {
          json['clientAddress'] =
              saved.address.isNotEmpty ? saved.address : saved.city;
        }
        if (saved.gst.isNotEmpty) json['clientGst'] = saved.gst;
        json['updatedAt'] = saved.updatedAt;
        manualInvoices[index] = ManualInvoice.fromJson(json);
      }
      recordAudit(
        action: creating ? 'create' : 'update',
        entityType: 'client',
        entityId: saved.id,
        entityLabel: saved.name,
        summary: creating
            ? 'Created client ${saved.name}'
            : 'Updated client ${saved.name}',
        metadata: {
          'mobile': saved.mobile,
          'previousMobile': previousMobile,
          'previousName': previousName,
        },
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> deleteClient(AppClient client) async {
    showCpSnack(context, 'Deleting client...');
    setState(() {
      clients.removeWhere((item) =>
          item.id == client.id ||
          normalizeMobileText(item.mobile) ==
              normalizeMobileText(client.mobile));
      recordAudit(
        action: 'delete',
        entityType: 'client',
        entityId: client.id,
        entityLabel: client.name,
        summary: 'Deleted client ${client.name}',
        metadata: {'mobile': client.mobile},
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> saveEmployee(Employee employee) async {
    showCpSnack(context,
        employee.id.isEmpty ? 'Saving employee...' : 'Updating employee...');
    final creating = employee.id.trim().isEmpty ||
        !employees.any((item) => item.id == employee.id.trim());
    final saved = localEmployee(employee);
    setState(() {
      final index = employees.indexWhere((item) =>
          item.id == saved.id ||
          normalizeMobileText(item.mobile) == saved.mobile);
      if (index == -1) {
        employees.add(saved);
      } else {
        employees[index] = saved;
      }
      recordAudit(
        action: creating ? 'create' : 'update',
        entityType: 'employee',
        entityId: saved.id,
        entityLabel: saved.name,
        summary: creating
            ? 'Created employee ${saved.name}'
            : 'Updated employee ${saved.name}',
        metadata: {
          'mobile': saved.mobile,
          'designation': saved.designation,
        },
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> deleteEmployee(Employee employee) async {
    showCpSnack(context, 'Deleting employee...');
    setState(() {
      employees.removeWhere((item) =>
          item.id == employee.id ||
          normalizeMobileText(item.mobile) ==
              normalizeMobileText(employee.mobile));
      recordAudit(
        action: 'delete',
        entityType: 'employee',
        entityId: employee.id,
        entityLabel: employee.name,
        summary: 'Deleted employee ${employee.name}',
        metadata: {
          'mobile': employee.mobile,
          'designation': employee.designation,
        },
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> openManualInvoiceForm() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ManualInvoiceFormScreen(
            clients: clients, onSave: saveManualInvoice)));
    if (mounted) setState(() => tab = 3);
  }

  AppClient billingClientFor(String name, String mobile,
      {String address = '', String gst = ''}) {
    final normalizedMobile = normalizeMobileText(mobile);
    final normalizedName = name.trim().toLowerCase();
    for (final client in clients) {
      final clientMobile = normalizeMobileText(client.mobile);
      final matches =
          (normalizedMobile.isNotEmpty && clientMobile == normalizedMobile) ||
              (normalizedName.isNotEmpty &&
                  client.name.trim().toLowerCase() == normalizedName);
      if (matches) return client;
    }
    return AppClient(
        id: '',
        name: name,
        mobile: normalizedMobile.isNotEmpty ? normalizedMobile : mobile,
        address: address,
        gst: gst);
  }

  List<AppEvent> billingLinkedEventsForClient(AppClient client) {
    final mobile = normalizeMobileText(client.mobile);
    final name = client.name.trim().toLowerCase();
    return events.where((event) {
      final eventMobile = normalizeMobileText(event.mobile);
      final eventClient = event.primaryClient.trim().toLowerCase();
      return (mobile.isNotEmpty && eventMobile == mobile) ||
          (name.isNotEmpty && eventClient == name);
    }).toList();
  }

  List<ManualInvoice> billingLinkedInvoicesForClient(AppClient client) {
    final mobile = normalizeMobileText(client.mobile);
    final name = client.name.trim().toLowerCase();
    return manualInvoices.where((invoice) {
      final invoiceMobile = normalizeMobileText(invoice.mobile);
      final invoiceClient = invoice.clientName.trim().toLowerCase();
      return (mobile.isNotEmpty && invoiceMobile == mobile) ||
          (name.isNotEmpty && invoiceClient == name);
    }).toList();
  }

  AppEvent? billingEventForManualInvoice(ManualInvoice invoice) {
    final mobile = normalizeMobileText(invoice.mobile);
    final eventName = invoice.eventName.trim().toLowerCase();
    for (final event in events) {
      final sameMobile =
          mobile.isNotEmpty && normalizeMobileText(event.mobile) == mobile;
      final sameName =
          eventName.isNotEmpty && event.name.trim().toLowerCase() == eventName;
      final sameDate = invoice.eventDate.trim().isEmpty ||
          event.dates.any((date) => date.date == invoice.eventDate.trim());
      if (sameMobile && sameName && sameDate) return event;
    }
    return null;
  }

  Future<bool> confirmBillingDelete(
      String title, String message, String actionLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(actionLabel)),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> openManualInvoiceDetails(ManualInvoice invoice) async {
    final client = billingClientFor(invoice.clientName, invoice.mobile,
        address: invoice.clientAddress, gst: invoice.clientGst);
    final linkedEvent = billingEventForManualInvoice(invoice);
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ManualInvoiceDetailsScreen(
            invoice: invoice,
            client: client,
            linkedEvent: linkedEvent,
            linkedEvents: billingLinkedEventsForClient(client),
            linkedInvoices: billingLinkedInvoicesForClient(client),
            api: api,
            onSave: saveManualInvoice,
            onEdit: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ManualInvoiceFormScreen(
                      clients: clients,
                      initialInvoice: invoice,
                      onSave: saveManualInvoice)));
            },
            onDelete: () async {
              final label = invoice.invoiceNumber.isEmpty
                  ? invoice.eventName
                  : invoice.invoiceNumber;
              final confirmed = await confirmBillingDelete(
                  'Delete Invoice?',
                  'This will remove invoice $label from this device.',
                  'Delete');
              if (!confirmed) return;
              await deleteManualInvoice(invoice);
            },
            onOpenEvent: openEventDetails,
            onEventUpdated: updateSelectedEvent,
            onAudit: recordAuditAndBackup)));
  }

  Future<void> openEventPaymentInvoiceDetails(
      AppEvent event, AppPayment payment) async {
    final client = billingClientFor(
        event.primaryClient.isEmpty ? event.name : event.primaryClient,
        event.mobile);
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BillingDocumentDetailsScreen(
            event: event,
            client: client,
            linkedInvoices: billingLinkedInvoicesForClient(client),
            payment: payment,
            type: 'invoice',
            api: api,
            onOpenEvent: openEventDetails,
            onEventUpdated: updateSelectedEvent,
            onDeleteInvoice: () async {
              final confirmed = await confirmBillingDelete(
                  'Delete Invoice Payment?',
                  'This invoice is created from a payment record. Deleting it will remove the payment of ${money(payment.amount)} from ${event.name}.',
                  'Delete Payment');
              if (!confirmed) return;
              await deleteEventPaymentInvoice(event, payment);
            },
            onAudit: recordAuditAndBackup)));
  }

  Future<void> openEventInvoiceDetails(AppEvent event) async {
    final client = billingClientFor(
        event.primaryClient.isEmpty ? event.name : event.primaryClient,
        event.mobile);
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BillingDocumentDetailsScreen(
            event: event,
            client: client,
            linkedInvoices: billingLinkedInvoicesForClient(client),
            type: 'invoice',
            api: api,
            onOpenEvent: openEventDetails,
            onEventUpdated: updateSelectedEvent,
            onDeleteInvoice: () async {
              final confirmed = await confirmBillingDelete(
                  'Delete Event Invoice?',
                  'This invoice is generated from the event itself. Deleting it will delete the event ${event.name} and its linked details.',
                  'Delete Event');
              if (!confirmed) return;
              removeSelectedEvent(event.id);
            },
            onAudit: recordAuditAndBackup)));
  }

  void openEventDetails(AppEvent event) {
    navigateToTab(6, selectedEventId: event.id);
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
      recordAudit(
        action: 'update',
        entityType: 'event',
        entityId: event.id,
        entityLabel: event.name,
        summary: 'Updated event ${event.name}',
        metadata: {
          'client': event.primaryClient,
          'mobile': event.mobile,
          'balanceDue': eventBalance(event),
        },
      );
    });
    backupCurrentSnapshotQuietly();
  }

  void removeSelectedEvent(String eventId) {
    setState(() {
      final event = events.where((item) => item.id == eventId).firstOrNull;
      events.removeWhere((event) => event.id == eventId);
      if (selectedEventId == eventId) selectedEventId = null;
      recordAudit(
        action: 'delete',
        entityType: 'event',
        entityId: eventId,
        entityLabel: event?.name ?? eventId,
        summary: 'Deleted event ${event?.name ?? eventId}',
        metadata: {
          'client': event?.primaryClient ?? '',
          'mobile': event?.mobile ?? '',
        },
      );
    });
    backupCurrentSnapshotQuietly();
  }

  void openCreateEvent() {
    navigateToTab(5,
        selectedEventId: null,
        editingEvent: null,
        createInitialStep: 0,
        incrementCreateSession: true);
  }

  void openEventsTab() {
    navigateToTab(1,
        selectedEventId: null,
        editingEvent: null,
        incrementEventsSession: true);
  }

  void openEditEvent(AppEvent event, {int initialStep = 0}) {
    navigateToTab(5,
        selectedEventId: event.id,
        editingEvent: event,
        createInitialStep: initialStep.clamp(0, 3).toInt(),
        incrementCreateSession: true);
  }

  void openChildTab(int nextTab) {
    navigateToTab(nextTab);
  }

  void openRootTab(int nextTab) {
    if (nextTab == 1) {
      eventsSession++;
    }
    setState(() {
      routeStack.clear();
      if (nextTab != 0) {
        routeStack.add(const _ShellRoute(tab: 0));
      }
      tab = nextTab;
      selectedEventId = null;
      editingEvent = null;
      createInitialStep = 0;
    });
  }

  void navigateToTab(
    int nextTab, {
    String? selectedEventId,
    AppEvent? editingEvent,
    int? createInitialStep,
    bool incrementCreateSession = false,
    bool incrementEventsSession = false,
    bool clearStack = false,
  }) {
    setState(() {
      final resetToDashboard = nextTab == 0 || clearStack;
      if (resetToDashboard) {
        routeStack.clear();
      } else if (nextTab != tab ||
          selectedEventId != this.selectedEventId ||
          editingEvent != this.editingEvent) {
        routeStack.add(_ShellRoute(
          tab: tab,
          selectedEventId: this.selectedEventId,
          editingEvent: this.editingEvent,
          createInitialStep: this.createInitialStep,
        ));
      }
      if (incrementCreateSession) createSession++;
      if (incrementEventsSession) eventsSession++;
      tab = nextTab;
      this.selectedEventId = resetToDashboard ? null : selectedEventId;
      this.editingEvent = resetToDashboard ? null : editingEvent;
      this.createInitialStep =
          resetToDashboard ? 0 : (createInitialStep ?? this.createInitialStep);
    });
  }

  void closeToParent() {
    setState(() {
      if (routeStack.isEmpty) {
        tab = tab == 0 ? 0 : 0;
        selectedEventId = null;
        editingEvent = null;
        createInitialStep = 0;
        return;
      }
      final previous = routeStack.removeLast();
      tab = previous.tab;
      selectedEventId = previous.selectedEventId;
      editingEvent = previous.editingEvent;
      createInitialStep = previous.createInitialStep;
    });
  }

  void upsertService(AdditionalServiceItem service) {
    showCpSnack(context, 'Updating service...');
    final creating = !services.any((item) => item.id == service.id);
    setState(() {
      final index = services.indexWhere((item) => item.id == service.id);
      if (index == -1) {
        services.add(service);
      } else {
        services[index] = service;
      }
      recordAudit(
        action: creating ? 'create' : 'update',
        entityType: 'additionalService',
        entityId: service.id,
        entityLabel: service.name,
        summary: creating
            ? 'Created service ${service.name}'
            : 'Updated service ${service.name}',
        metadata: {'unit': service.unit, 'price': service.price},
      );
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
    setState(() {
      final service = services.where((item) => item.id == id).firstOrNull;
      services.removeWhere((item) => item.id == id);
      recordAudit(
        action: 'delete',
        entityType: 'additionalService',
        entityId: id,
        entityLabel: service?.name ?? id,
        summary: 'Deleted service ${service?.name ?? id}',
        metadata: {
          'unit': service?.unit ?? '',
          'price': service?.price ?? 0,
        },
      );
    });
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
    final creating = menu.id.trim().isEmpty ||
        !customMenus.any((item) => item.id == menu.id.trim());
    final saved = menu.id.trim().isEmpty
        ? CustomMenu(
            id: localId('cmenu'),
            name: menu.name,
            type: menu.type,
            itemIds: menu.itemIds,
          )
        : menu;
    setState(() {
      final index = customMenus.indexWhere((item) => item.id == saved.id);
      if (index == -1) {
        customMenus.add(saved);
      } else {
        customMenus[index] = saved;
      }
      recordAudit(
        action: creating ? 'create' : 'update',
        entityType: 'customMenu',
        entityId: saved.id,
        entityLabel: saved.name,
        summary: creating
            ? 'Created custom menu ${saved.name}'
            : 'Updated custom menu ${saved.name}',
        metadata: {'type': saved.type, 'itemCount': saved.itemIds.length},
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    showCpSnack(context, 'Updating business profile...');
    setState(() {
      businessProfile = profile;
      recordAudit(
        action: 'update',
        entityType: 'businessProfile',
        entityId: 'businessProfile',
        entityLabel: profile.businessName.isEmpty
            ? 'Business profile'
            : profile.businessName,
        summary: 'Updated business profile',
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> saveInvoiceSettings(BusinessProfile profile) async {
    showCpSnack(context, 'Updating invoice settings...');
    setState(() {
      businessProfile = profile;
      recordAudit(
        action: 'update',
        entityType: 'invoiceSettings',
        entityId: 'invoiceSettings',
        entityLabel: 'Invoice settings',
        summary: 'Updated invoice settings',
      );
    });
    backupCurrentSnapshotQuietly();
  }

  Future<void> savePdfMenuSettings(BusinessProfile profile) async {
    showCpSnack(context, 'Updating PDF menu settings...');
    setState(() {
      businessProfile = profile;
      recordAudit(
        action: 'update',
        entityType: 'pdfMenuSettings',
        entityId: 'pdfMenuSettings',
        entityLabel: 'PDF menu settings',
        summary: 'Updated PDF menu settings',
      );
    });
    backupCurrentSnapshotQuietly();
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
    const title = 'CaterPro backup.json';
    if (mounted) {
      showDownloadSnack(context, uri,
          title: title,
          kind: 'backup',
          successMessage: 'Backup download started',
          failureMessage: 'Unable to save backup');
    }
    addSystemNotification(
        title: 'Data export started',
        message: 'CaterPro backup is being saved to device downloads.',
        kind: 'export',
        icon: Icons.download,
        color: Cp.primary);
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
    showCpSnack(context, 'Uploading app data...');
    await cacheCurrentUserData();
    await pushCurrentSnapshot();
    if (mounted && syncProgress?.warning == true) {
      showCpSnack(context, syncProgress?.detail ?? 'Sync needs attention');
    } else if (mounted) {
      showCpSnack(context, 'Synced with server');
    }
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
    if (routeStack.isNotEmpty || tab != 0) {
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
            openCreate: openCreateEvent,
            openEvents: openEventsTab,
            openClients: () => navigateToTab(2),
            openBilling: () => navigateToTab(3),
            openEmployees: () => navigateToTab(9),
            openInvoice: () => navigateToTab(3),
            openCustomMenus: () => openChildTab(11),
            openLists: () => openChildTab(21),
            openDetails: openEventDetails,
            refresh: refreshEvents),
        EventsScreen(
            resetToken: eventsSession,
            api: api,
            events: events,
            loading: loading,
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
            openEventInvoice: openEventInvoiceDetails,
            openManualInvoice: openManualInvoiceDetails,
            openEventPaymentInvoice: openEventPaymentInvoiceDetails,
            openNotifications: openNotifications),
        BillingScreen(
            events: events,
            clients: clients,
            manualInvoices: manualInvoices,
            api: api,
            onSaveManualInvoice: saveManualInvoice,
            onDeleteManualInvoice: deleteManualInvoice,
            onDeleteEventPaymentInvoice: deleteEventPaymentInvoice,
            onDeleteEventInvoice: removeSelectedEvent,
            onAddManualInvoice: openManualInvoiceForm,
            onOpenEvent: openEventDetails,
            onEventUpdated: updateSelectedEvent,
            onAudit: recordAuditAndBackup),
        SettingsScreen(
            openBusiness: () => openChildTab(8),
            openInvoiceSettings: openInvoiceSettings,
            openMenu: () => openChildTab(7),
            openCustomMenus: () => openChildTab(11),
            openEmployees: () => openChildTab(9),
            openRawMaterials: () => openChildTab(10),
            openProduceItems: () => openChildTab(12),
            openVesselItems: () => openChildTab(19),
            openLists: () => openChildTab(21),
            openNotifications: openNotifications,
            openUserManagement: openUserManagement,
            openReports: () => openChildTab(17),
            openAppAppearance: openAppAppearance,
            openEventDefaults: () => openChildTab(18),
            openDownloads: () => openChildTab(20),
            onExportData: exportData,
            onImportData: importData,
            onBackupToGoogleDrive: backupToGoogleDrive,
            onSyncNow: syncNow,
            lastSyncedAt: lastSyncedAt,
            syncProgress: syncProgress,
            businessProfile: businessProfile,
            services: services,
            onSaveService: upsertService,
            onDeleteService: removeService),
        CreateEventScreen(
            key: ValueKey(
                'create-$createSession-${editingEvent?.id ?? 'new'}-$createInitialStep'),
            initialEvent: editingEvent,
            initialStep: createInitialStep,
            onDraftSaved: updateSelectedEvent,
            onClose: closeToParent,
            onCreate: createEvent,
            services: services,
            customMenus: customMenus,
            clients: clients,
            customerEvents: events,
            onSaveService: upsertService,
            onDeleteService: removeService,
            onSaveCustomMenu: saveCustomMenu),
        EventDetailsScreen(
            event: events
                .where((event) => event.id == selectedEventId)
                .firstOrNull,
            api: api,
            events: events,
            employees: employees,
            businessProfile: businessProfile,
            onEdit: openEditEvent,
            onEditStep: (event, step) =>
                openEditEvent(event, initialStep: step),
            onAddEvent: openCreateEvent,
            onEventUpdated: updateSelectedEvent,
            onEventDeleted: removeSelectedEvent,
            onSaveCustomMenu: saveCustomMenu,
            onClose: closeToParent),
        MenuMasterScreen(
            onClose: closeToParent, events: events, customMenus: customMenus),
        BusinessProfileScreen(
            profile: businessProfile,
            onSave: saveBusinessProfile,
            onClose: closeToParent),
        EmployeeScreen(
            api: api,
            employees: employees,
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
        AppAppearanceScreen(
            profile: businessProfile,
            onSaveProfile: savePdfMenuSettings,
            onClose: closeToParent),
        InvoiceSettingsScreen(
            api: api,
            profile: businessProfile,
            onSave: saveInvoiceSettings,
            onClose: closeToParent),
        ReportsScreen(
            api: api,
            events: events,
            employees: employees,
            manualInvoices: manualInvoices,
            onClose: closeToParent),
        EventDefaultsScreen(onClose: closeToParent),
        VesselItemScreen(onClose: closeToParent),
        DownloadsScreen(onClose: closeToParent),
        ListsScreen(events: events, onClose: closeToParent),
      ];

  @override
  Widget build(BuildContext context) {
    const drawerTabs = {
      0,
      1,
      2,
      3,
      4,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      15,
      16,
      17,
      18,
      19,
      20,
      21
    };
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
            ? CaterSideDrawer(index: tab, onChanged: openRootTab)
            : null,
        body: IndexedStack(index: tab, children: pages),
        floatingActionButton: showMainFab ? _fabForTab() : null,
      ),
    );
  }

  Widget? _fabForTab() {
    final icons = [Icons.add, Icons.add, Icons.add, Icons.add, null];
    if (icons[tab] == null) return null;
    final scheme = Theme.of(context).colorScheme;
    return FloatingActionButton(
      backgroundColor: scheme.secondaryContainer,
      foregroundColor: scheme.onSecondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () {
        if (tab == 0 || tab == 1) {
          openCreateEvent();
        } else if (tab == 2) {
          showClientEditor(context, onSave: saveClient);
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
    (0, Icons.home_rounded, 'Dashboard'),
    (1, Icons.calendar_month_rounded, 'Events'),
    (2, Icons.group_rounded, 'Clients'),
    (3, Icons.receipt_long_rounded, 'Billing'),
    (4, Icons.settings_rounded, 'Settings'),
  ];

  static const settingsSubItems = [
    (9, Icons.badge, 'Employees'),
    (17, Icons.analytics_outlined, 'Reports'),
    (21, Icons.checklist, 'Lists'),
    (16, Icons.description, 'Invoice Settings'),
    (18, Icons.tune, 'Event Defaults'),
    (13, Icons.notifications, 'Notifications'),
    (15, Icons.wb_sunny, 'App Appearance'),
  ];

  static const settingsTabs = {
    4,
    8,
    9,
    10,
    11,
    12,
    13,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
  };

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
                    final item = items[i];
                    final tabId = item.$1;
                    final selected = tabId == index ||
                        (tabId == 4 && settingsTabs.contains(index));
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
                            leading: Icon(item.$2,
                                color: selected
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant),
                            title: Text(t(item.$3),
                                style: TextStyle(
                                    color: selected
                                        ? scheme.onSecondaryContainer
                                        : scheme.onSurface,
                                    fontWeight: selected
                                        ? FontWeight.w900
                                        : FontWeight.w700)),
                            onTap: () {
                              Navigator.pop(context);
                              onChanged(tabId);
                            },
                          ),
                          if (tabId == 4 && settingsTabs.contains(index))
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: actualBorder),
    );
    final card = Material(
      color: actualColor,
      shape: shape,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: shadowAlpha),
      child: Padding(
        padding: padding,
        child: IconTheme.merge(
          data: IconThemeData(color: cpPrimary(context)),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: cpOnSurface(context)),
            child: child,
          ),
        ),
      ),
    );
    return onTap == null
        ? card
        : Material(
            color: actualColor,
            shape: shape,
            elevation: 0,
            shadowColor: Colors.black.withValues(alpha: shadowAlpha),
            child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Padding(
                  padding: padding,
                  child: IconTheme.merge(
                    data: IconThemeData(color: cpPrimary(context)),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: cpOnSurface(context)),
                      child: child,
                    ),
                  ),
                )),
          );
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
    final scheme = Theme.of(context).colorScheme;
    final actualColor = cpAdaptSurfaceColor(context, color);
    final actualTextColor = color == Cp.primaryContainer
        ? scheme.onPrimaryContainer
        : color == Cp.secondaryContainer
            ? scheme.onSecondaryContainer
            : color == Cp.tertiaryContainer || color == Cp.tertiaryFixed
                ? scheme.onTertiaryContainer
                : color == Cp.errorContainer || color == const Color(0xffffebeb)
                    ? scheme.onErrorContainer
                    : cpAdaptTextColor(context, textColor);
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
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      dismissDirection: DismissDirection.horizontal,
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.primaryContainer,
    ),
  );
}

void showDownloadSnack(BuildContext context, Uri uri,
    {required String title,
    String kind = 'file',
    String successMessage = 'Download started',
    String failureMessage = 'Unable to start download'}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(successMessage),
      duration: const Duration(seconds: 2),
      dismissDirection: DismissDirection.horizontal,
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.primaryContainer,
    ),
  );
  unawaited(() async {
    try {
      final localUri =
          await saveDownloadToDevice(title: title, uri: uri, kind: kind);
      if (!context.mounted) return;
      final fileName = sanitizeDownloadFileName(title, kind);
      unawaited(openDownloadedFile(localUri, title: fileName, kind: kind));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening $fileName'),
          duration: const Duration(seconds: 2),
          dismissDirection: DismissDirection.horizontal,
          behavior: SnackBarBehavior.floating,
          backgroundColor: scheme.primaryContainer,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showCpSnack(context,
          '$failureMessage: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }());
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
