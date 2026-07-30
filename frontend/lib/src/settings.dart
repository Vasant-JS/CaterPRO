part of '../main.dart';

Uint8List? bytesFromDataUrl(String value) {
  if (value.isEmpty || !value.contains(',')) return null;
  try {
    return base64Decode(value.split(',').last);
  } catch (_) {
    return null;
  }
}

class BusinessLogoAvatar extends StatelessWidget {
  const BusinessLogoAvatar(
      {super.key, required this.profile, this.radius = 24});
  final BusinessProfile profile;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final logoBytes = bytesFromDataUrl(profile.logoBase64);
    final initials = profile.businessName.trim().isEmpty
        ? 'RC'
        : profile.businessName
            .trim()
            .split(RegExp(r'\s+'))
            .map((part) => part[0])
            .take(2)
            .join()
            .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: Cp.primaryContainer,
      backgroundImage: logoBytes == null ? null : MemoryImage(logoBytes),
      child: logoBytes == null
          ? Text(initials,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * .5,
                  fontWeight: FontWeight.w900))
          : null,
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen(
      {super.key,
      required this.openBusiness,
      required this.openInvoiceSettings,
      required this.openMenu,
      required this.openCustomMenus,
      required this.openEmployees,
      required this.openRawMaterials,
      required this.openProduceItems,
      required this.openVesselItems,
      required this.openLists,
      required this.openNotifications,
      required this.openUserManagement,
      required this.openReports,
      required this.openAppAppearance,
      required this.openEventDefaults,
      required this.openDownloads,
      required this.onExportData,
      required this.onImportData,
      required this.onBackupToGoogleDrive,
      required this.onSyncNow,
      this.lastSyncedAt,
      required this.businessProfile,
      required this.services,
      required this.onSaveService,
      required this.onDeleteService});
  final VoidCallback openBusiness;
  final VoidCallback openInvoiceSettings;
  final VoidCallback openMenu;
  final VoidCallback openCustomMenus;
  final VoidCallback openEmployees;
  final VoidCallback openRawMaterials;
  final VoidCallback openProduceItems;
  final VoidCallback openVesselItems;
  final VoidCallback openLists;
  final VoidCallback openNotifications;
  final VoidCallback openUserManagement;
  final VoidCallback openReports;
  final VoidCallback openAppAppearance;
  final VoidCallback openEventDefaults;
  final VoidCallback openDownloads;
  final Future<void> Function() onExportData;
  final Future<void> Function() onImportData;
  final Future<void> Function() onBackupToGoogleDrive;
  final Future<void> Function() onSyncNow;
  final DateTime? lastSyncedAt;
  final BusinessProfile businessProfile;
  final List<AdditionalServiceItem> services;
  final ValueChanged<AdditionalServiceItem> onSaveService;
  final ValueChanged<String> onDeleteService;

  void showSettingsInfo(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  Future<void> showResetPasswordDialog(BuildContext context) async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    var saving = false;
    String? error;
    var showOldPassword = false;
    var showNewPassword = false;
    var showConfirmPassword = false;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Reset Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPassword,
                  obscureText: !showOldPassword,
                  decoration: InputDecoration(
                      labelText: 'Old Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                          tooltip: showOldPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () => setDialogState(
                              () => showOldPassword = !showOldPassword),
                          icon: Icon(showOldPassword
                              ? Icons.visibility_off
                              : Icons.visibility))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassword,
                  obscureText: !showNewPassword,
                  decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.password),
                      suffixIcon: IconButton(
                          tooltip: showNewPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () => setDialogState(
                              () => showNewPassword = !showNewPassword),
                          icon: Icon(showNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassword,
                  obscureText: !showConfirmPassword,
                  decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                          tooltip: showConfirmPassword
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () => setDialogState(
                              () => showConfirmPassword = !showConfirmPassword),
                          icon: Icon(showConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility))),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: TextStyle(
                          color: cpAdaptTextColor(dialogContext, Cp.error),
                          fontWeight: FontWeight.w800)),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final next = newPassword.text;
                        if (oldPassword.text.isEmpty) {
                          setDialogState(
                              () => error = 'Enter your old password.');
                          return;
                        }
                        if (next.length < 4) {
                          setDialogState(() => error =
                              'New password must be at least 4 characters.');
                          return;
                        }
                        if (next != confirmPassword.text) {
                          setDialogState(
                              () => error = 'New passwords do not match.');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await AuthService().changePassword(
                              oldPassword: oldPassword.text, newPassword: next);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (context.mounted) {
                            showCpSnack(context, 'Password updated');
                          }
                        } catch (e) {
                          setDialogState(() {
                            saving = false;
                            error =
                                e.toString().replaceFirst('Exception: ', '');
                          });
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Save'),
              )
            ],
          ),
        ),
      );
    } finally {
      oldPassword.dispose();
      newPassword.dispose();
      confirmPassword.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      topBar: TopBar(title: 'CaterPro', avatar: false, actions: [
        IconButton(
            onPressed: openNotifications,
            icon: const Icon(Icons.notifications, color: Cp.primary)),
        const CircleAvatar(
            radius: 16,
            backgroundColor: Cp.primaryContainer,
            child:
                Text('RC', style: TextStyle(fontSize: 10, color: Colors.white)))
      ]),
      children: [
        CpCard(
          onTap: openBusiness,
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            BusinessLogoAvatar(profile: businessProfile, radius: 48),
            const SizedBox(height: 12),
            Text(
                businessProfile.businessName.isEmpty
                    ? t('Business Profile')
                    : businessProfile.businessName,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(
                businessProfile.address.isEmpty
                    ? 'Add your business details'
                    : businessProfile.address,
                style: TextStyle(color: cpOnVariant(context))),
          ]),
        ),
        const SizedBox(height: 20),
        SettingsGroup(
            title: t('Business'),
            items: [(Icons.storefront, 'Business Profile')],
            onItemTap: {'Business Profile': openBusiness}),
        SettingsGroup(title: t('Masters'), items: [
          (Icons.restaurant_menu, 'Menu Master'),
          (Icons.fact_check, 'Custom Menus'),
          (Icons.room_service, 'Additional Services'),
          (Icons.inventory_2, 'Raw Materials'),
          (Icons.eco, 'Vegetables & Fruits'),
          (Icons.soup_kitchen, 'Vessels & Utensils'),
          (Icons.checklist, 'Lists')
        ], onItemTap: {
          'Menu Master': openMenu,
          'Custom Menus': openCustomMenus,
          'Additional Services': () => showAdditionalServiceManager(context,
              services: services,
              onSave: onSaveService,
              onDelete: onDeleteService),
          'Raw Materials': openRawMaterials,
          'Vegetables & Fruits': openProduceItems,
          'Vessels & Utensils': openVesselItems,
          'Lists': openLists
        }),
        SettingsGroup(title: t('Team'), items: [
          (Icons.badge, 'Employees'),
        ], onItemTap: {
          'Employees': openEmployees,
        }),
        SettingsGroup(title: 'Reports', items: [
          (Icons.analytics_outlined, 'Reports'),
        ], onItemTap: {
          'Reports': openReports,
        }),
        SettingsGroup(title: t('Preferences'), items: [
          (Icons.description, 'Invoice Settings'),
          (Icons.tune, 'Event Defaults'),
          (Icons.notifications_active, 'Notifications'),
          (Icons.light_mode, 'App Appearance'),
          (Icons.lock_reset, 'Reset Password')
        ], onItemTap: {
          'Invoice Settings': openInvoiceSettings,
          'Event Defaults': openEventDefaults,
          'Notifications': openNotifications,
          'App Appearance': openAppAppearance,
          'Reset Password': () => unawaited(showResetPasswordDialog(context)),
        }),
        SettingsGroup(title: t('Data'), items: [
          (Icons.folder_open, 'Downloads'),
          (Icons.file_download, 'Export Data'),
          (Icons.upload_file, 'Import Data'),
          (Icons.cloud_upload, 'Backup to Google Drive'),
          (Icons.sync, 'Sync Now'),
        ], onItemTap: {
          'Downloads': openDownloads,
          'Export Data': () => unawaited(onExportData()),
          'Import Data': () => unawaited(onImportData()),
          'Backup to Google Drive': () => unawaited(onBackupToGoogleDrive()),
          'Sync Now': () => unawaited(onSyncNow()),
        }),
        CpCard(
            color: Cp.primaryFixed,
            child: Row(children: [
              const Icon(Icons.sync, color: Cp.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      'Auto sync runs every 1 minute. Last sync: ${lastSyncedAt == null ? 'not yet' : '${lastSyncedAt!.hour.toString().padLeft(2, '0')}:${lastSyncedAt!.minute.toString().padLeft(2, '0')}'}',
                      style: TextStyle(
                          color: cpPrimary(context),
                          fontWeight: FontWeight.w800))),
            ])),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false);
              }
            },
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(t('Logout'),
                    style: const TextStyle(
                        color: Cp.error,
                        fontSize: 16,
                        fontWeight: FontWeight.w800))),
          ),
        ),
      ],
    );
  }
}

class EventDefaultsScreen extends StatefulWidget {
  const EventDefaultsScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<EventDefaultsScreen> createState() => _EventDefaultsScreenState();
}

class _EventDefaultsScreenState extends State<EventDefaultsScreen> {
  late Map<String, String> times;
  late Set<String> autoTypes;
  late bool vegOnlyDefault;

  @override
  void initState() {
    super.initState();
    final prefs = appPreferences.value;
    times = {
      for (final type in eventMenuTypes)
        type: prefs.defaultMenuTimes[type] ??
            defaultEventMenuTimes[type] ??
            '10:00 AM'
    };
    autoTypes = {...prefs.autoMenuTypes};
    vegOnlyDefault = prefs.vegOnlyDefault;
  }

  TimeOfDay parseTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(value.trim());
    if (match == null) return const TimeOfDay(hour: 10, minute: 0);
    var hour = int.tryParse(match.group(1) ?? '') ?? 10;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final period = (match.group(3) ?? 'AM').toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(
        hour: hour.clamp(0, 23).toInt(), minute: minute.clamp(0, 59).toInt());
  }

  String formatTime(TimeOfDay time) {
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> pickTime(String type) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: parseTime(times[type] ?? defaultEventMenuTimes[type] ?? ''),
    );
    if (picked == null) return;
    setState(() => times[type] = formatTime(picked));
  }

  Future<void> save() async {
    await appPreferences.save(appPreferences.value.copyWith(
        defaultMenuTimes: times,
        autoMenuTypes: autoTypes,
        vegOnlyDefault: vegOnlyDefault));
    if (!mounted) return;
    showCpSnack(context, 'Event defaults saved');
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      topBar: TopBar(
          title: 'Event Defaults',
          avatar: false,
          leading: IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.arrow_back, color: Cp.primary)),
          actions: [
            TextButton(
                onPressed: save,
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w900)))
          ]),
      children: [
        CpCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: vegOnlyDefault,
                activeThumbColor: Cp.primary,
                title: const Text('Veg Only',
                    style: TextStyle(
                        color: Cp.primary, fontWeight: FontWeight.w900)),
                subtitle: Text(
                    'New menu items default to vegetarian and non-veg options are hidden.',
                    style: TextStyle(color: cpOnVariant(context))),
                onChanged: (value) => setState(() => vegOnlyDefault = value)),
          ]),
        ),
        const SizedBox(height: 12),
        CpCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Default Menu Types',
                style: TextStyle(
                    color: Cp.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Selected types are automatically added to every new date.',
                style: TextStyle(color: cpOnVariant(context))),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: eventMenuTypes.map((type) {
                final selected = autoTypes.contains(type);
                return FilterChip(
                    selected: selected,
                    label: Text(type),
                    avatar: selected ? const Icon(Icons.check) : null,
                    onSelected: (value) => setState(() {
                          if (value) {
                            autoTypes.add(type);
                          } else {
                            autoTypes.remove(type);
                          }
                        }));
              }).toList(),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        CpCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Default Timing',
                style: TextStyle(
                    color: Cp.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ...eventMenuTypes.map((type) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule, color: Cp.primary),
                    title: Text(type,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    trailing: FilledButton.tonalIcon(
                        onPressed: () => pickTime(type),
                        icon: const Icon(Icons.access_time),
                        label: Text(times[type] ?? '-')),
                  ),
                )),
          ]),
        ),
      ],
    );
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen(
      {super.key,
      required this.api,
      required this.events,
      required this.employees,
      required this.manualInvoices,
      required this.onClose});
  final ApiService api;
  final List<AppEvent> events;
  final List<Employee> employees;
  final List<ManualInvoice> manualInvoices;
  final VoidCallback onClose;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  String get monthKey =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  void changeMonth(int delta) {
    setState(() => month = DateTime(month.year, month.month + delta));
  }

  bool isSameMonth(DateTime date) =>
      date.year == month.year && date.month == month.month;

  DateTime? firstDate(AppEvent event) {
    final dates = event.dates
        .map((date) => parseIsoDate(date.date))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }

  List<AppEvent> get monthEvents => widget.events.where((event) {
        final date = firstDate(event);
        return date != null && isSameMonth(date);
      }).toList();

  int get revenue => widget.events.fold(
      0,
      (sum, event) =>
          sum +
          event.payments.where((payment) {
            final date = parseIsoDate(payment.date);
            return date != null && isSameMonth(date);
          }).fold<int>(
              0, (paymentSum, payment) => paymentSum + payment.amount));

  int get bookedRevenue =>
      monthEvents.fold(0, (sum, event) => sum + eventTotal(event));
  int get outstanding =>
      monthEvents.fold(0, (sum, event) => sum + eventBalance(event));
  int get netProfit => revenue - outstanding;
  int get avgMembers {
    final slots = monthEvents
        .expand((event) => event.dates)
        .expand((date) => date.menuSlots)
        .toList();
    if (slots.isEmpty) return 0;
    return (slots.fold<int>(0, (sum, slot) => sum + slot.pax) / slots.length)
        .round();
  }

  Future<void> openAttendanceReport() async {
    await showDialog<void>(
        context: context,
        builder: (context) => AttendanceSheetDialog(
            api: widget.api, employees: widget.employees));
  }

  Future<void> downloadAttendancePdf() async {
    try {
      showCpSnack(context, 'Preparing attendance report...');
      final uri = await widget.api.attendancePdfUri(monthKey);
      if (!mounted) return;
      showDownloadSnack(context, uri,
          title: 'Attendance report $monthKey.pdf',
          kind: 'report',
          successMessage: 'Attendance report download started',
          failureMessage: 'Unable to download');
    } catch (e) {
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> downloadMonthlyReportPdf() async {
    try {
      showCpSnack(context, 'Preparing monthly report...');
      final uri = await widget.api.monthlyReportPdfUri(monthKey);
      if (!mounted) return;
      showDownloadSnack(context, uri,
          title: 'Monthly report $monthKey.pdf',
          kind: 'report',
          successMessage: 'Monthly report download started',
          failureMessage: 'Unable to download report');
    } catch (e) {
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final newClients = monthEvents
        .map((event) => normalizeMobileText(event.mobile))
        .where((mobile) => mobile.isNotEmpty)
        .toSet()
        .length;
    final eventTypeCounts = <String, int>{};
    for (final event in monthEvents) {
      eventTypeCounts[event.name.isEmpty ? 'Event' : event.name] =
          (eventTypeCounts[event.name.isEmpty ? 'Event' : event.name] ?? 0) + 1;
    }
    final topStaff = widget.employees.take(3).toList();
    final pendingEvents =
        monthEvents.where((event) => eventBalance(event) > 0).take(3).toList();
    return ScreenFrame(
      topBar: TopBar(
          title: 'Reports',
          avatar: false,
          leading: IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.arrow_back, color: Cp.primary)),
          actions: [
            IconButton(
                onPressed: downloadMonthlyReportPdf,
                icon:
                    const Icon(Icons.insert_chart_outlined, color: Cp.primary),
                tooltip: 'Monthly report PDF'),
            IconButton(
                onPressed: openAttendanceReport,
                icon: const Icon(Icons.fact_check, color: Cp.primary),
                tooltip: 'Attendance report')
          ]),
      children: [
        Row(children: [
          Expanded(
              child: Text('Monthly Report',
                  style: TextStyle(
                      color: cpOnSurface(context),
                      fontSize: 22,
                      fontWeight: FontWeight.w900))),
          IconButton(
              onPressed: () => changeMonth(-1),
              icon: Icon(Icons.chevron_left, color: cpPrimary(context))),
          Pill('${_monthShortNames[month.month - 1]} ${month.year}',
              color: Cp.surfaceHigh, textColor: cpOnSurface(context)),
          IconButton(
              onPressed: () => changeMonth(1),
              icon: Icon(Icons.chevron_right, color: cpPrimary(context))),
        ]),
        const SizedBox(height: 12),
        ReportMetricCard(
            title: 'TOTAL REVENUE',
            value: money(revenue),
            note: bookedRevenue > 0
                ? '${((revenue / bookedRevenue) * 100).round()}% collected'
                : 'No bookings this month',
            icon: Icons.trending_up,
            accent: Cp.tertiaryContainer),
        ReportMetricCard(
            title: 'OUTSTANDING PAYMENTS',
            value: money(outstanding),
            note: '${pendingEvents.length} pending invoices/events',
            icon: Icons.trending_up,
            accent: Cp.error),
        CpCard(
          color: Cp.primaryContainer,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text('NET PROFIT',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: .76),
                          fontWeight: FontWeight.w900))),
              const Icon(Icons.payments, color: Cp.secondaryContainer),
            ]),
            const SizedBox(height: 28),
            Text(money(netProfit),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900)),
            Text(
                netProfit >= 0
                    ? 'Positive cash position'
                    : 'Pending exceeds collection',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .76),
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: ReportMiniCard(
                  icon: Icons.restaurant_menu,
                  value: '${monthEvents.length}',
                  label: 'Events',
                  color: Cp.secondary)),
          const SizedBox(width: 8),
          Expanded(
              child: ReportMiniCard(
                  icon: Icons.person_add_alt,
                  value: '$newClients',
                  label: 'Clients',
                  color: Cp.primary)),
          const SizedBox(width: 8),
          Expanded(
              child: ReportMiniCard(
                  icon: Icons.groups,
                  value: '$avgMembers',
                  label: 'Avg. Members',
                  color: Cp.tertiary)),
        ]),
        const SizedBox(height: 16),
        CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Revenue by Event Type',
              style: TextStyle(
                  color: cpOnSurface(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          if (eventTypeCounts.isEmpty)
            Text('No events this month.',
                style: TextStyle(color: cpOnVariant(context)))
          else
            ...eventTypeCounts.entries.take(4).map((entry) {
              final percent =
                  ((entry.value / monthEvents.length) * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                          color: Cp.primaryContainer, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.key)),
                  Text('$percent%',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ]),
              );
            }),
        ])),
        const SizedBox(height: 16),
        CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Top Performing Staff',
              style: TextStyle(
                  color: cpOnSurface(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (topStaff.isEmpty)
            Text('Add employees to see this report.',
                style: TextStyle(color: cpOnVariant(context)))
          else
            ...topStaff.map((employee) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    CircleAvatar(
                        backgroundColor: Cp.primaryFixed,
                        child: Text(employee.name.substring(0, 1),
                            style: const TextStyle(
                                color: Cp.primary,
                                fontWeight: FontWeight.w900))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(employee.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          Text(employee.designation,
                              style: TextStyle(color: cpOnVariant(context))),
                        ])),
                    Text('${money(employee.payPerDay)}/day',
                        style: TextStyle(
                            color: cpPrimary(context),
                            fontWeight: FontWeight.w900)),
                  ]),
                )),
        ])),
        const SizedBox(height: 16),
        CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Outstanding Payments',
                    style: TextStyle(
                        color: cpOnSurface(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w900))),
            Text(money(outstanding),
                style: const TextStyle(
                    color: Cp.error, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 12),
          if (pendingEvents.isEmpty)
            Text('No outstanding event payments this month.',
                style: TextStyle(color: cpOnVariant(context)))
          else
            ...pendingEvents.map((event) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CpCard(
                    color: Cp.surfaceLow,
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(event.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            Text(event.primaryClient,
                                style: TextStyle(color: cpOnVariant(context))),
                          ])),
                      Text(money(eventBalance(event)),
                          style: const TextStyle(
                              color: Cp.error, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                )),
        ])),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
              onPressed: downloadMonthlyReportPdf,
              style:
                  FilledButton.styleFrom(backgroundColor: Cp.primaryContainer),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download Monthly PDF',
                  style: TextStyle(fontWeight: FontWeight.w900))),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
              onPressed: downloadAttendancePdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download Attendance PDF',
                  style: TextStyle(fontWeight: FontWeight.w900))),
        ),
      ],
    );
  }
}

class ReportMetricCard extends StatelessWidget {
  const ReportMetricCard(
      {super.key,
      required this.title,
      required this.value,
      required this.note,
      required this.icon,
      required this.accent});
  final String title;
  final String value;
  final String note;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          color: cpOnVariant(context),
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 28),
                  Text(value,
                      style: TextStyle(
                          color: cpOnSurface(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  Text(note,
                      style: TextStyle(
                          color: cpOnVariant(context),
                          fontWeight: FontWeight.w700)),
                ])),
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(999)),
                child: Icon(icon, color: accent)),
          ]),
        ),
      );
}

class ReportMiniCard extends StatelessWidget {
  const ReportMiniCard(
      {super.key,
      required this.icon,
      required this.value,
      required this.label,
      required this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => CpCard(
        child: Column(children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cpOnVariant(context), fontWeight: FontWeight.w700)),
        ]),
      );
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup(
      {super.key,
      required this.title,
      required this.items,
      this.onItemTap = const {}});
  final String title;
  final List<(IconData, String)> items;
  final Map<String, VoidCallback> onItemTap;
  @override
  Widget build(BuildContext context) {
    void fallback(String label) => showCpSnack(context, '$label opened');
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(title,
                style: TextStyle(
                    color: cpPrimary(context), fontWeight: FontWeight.w800))),
        Material(
          color: cpSurfaceLow(context),
          borderRadius: BorderRadius.circular(12),
          child: Column(
              children: List.generate(items.length, (i) {
            final label = items[i].$2;
            return ListTile(
              onTap: onItemTap[label] ?? () => fallback(label),
              leading: Icon(items[i].$1, color: cpOnVariant(context)),
              title: Text(t(label),
                  style: TextStyle(
                      color: cpOnSurface(context),
                      fontWeight: FontWeight.w700)),
              trailing: Icon(Icons.chevron_right, color: cpOutline(context)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            );
          })),
        ),
      ]),
    );
  }
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final selectedIds = <String>{};

  String timeLabel(DateTime value) {
    final date =
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  IconData iconFor(String kind) => switch (kind) {
        'pdf' => Icons.picture_as_pdf,
        'backup' => Icons.archive,
        'report' => Icons.analytics_outlined,
        'menu' => Icons.restaurant_menu,
        'invoice' => Icons.receipt_long,
        _ => Icons.insert_drive_file,
      };

  List<DownloadEntry> selectedEntries(List<DownloadEntry> items) =>
      items.where((item) => selectedIds.contains(item.id)).toList();

  void toggleSelected(String id) {
    setState(() => selectedIds.contains(id)
        ? selectedIds.remove(id)
        : selectedIds.add(id));
  }

  Future<void> openEntry(BuildContext context, DownloadEntry entry) async {
    final uri = Uri.tryParse(entry.url);
    if (uri == null) {
      showCpSnack(context, 'File link is not valid');
      return;
    }
    final launched =
        await openDownloadedFile(uri, title: entry.title, kind: entry.kind);
    if (!context.mounted) return;
    showCpSnack(context, launched ? 'Opening file...' : 'Unable to open file');
  }

  Future<void> deleteEntries(BuildContext context, Set<String> ids) async {
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ids.length == 1 ? 'Delete download?' : 'Delete downloads?',
            style: const TextStyle(
                color: Cp.primary, fontWeight: FontWeight.w900)),
        content: Text(ids.length == 1
            ? 'Remove this file from downloads history?'
            : 'Remove ${ids.length} files from downloads history?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Cp.error, foregroundColor: Colors.white),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await downloadHistory.removeWhere(ids);
    if (!mounted) return;
    setState(() => selectedIds.removeAll(ids));
    showCpSnack(this.context, 'Download history updated');
  }

  Future<void> clearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear downloads?',
            style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)),
        content: const Text('Remove all files from downloads history?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Cp.error, foregroundColor: Colors.white),
              child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;
    await downloadHistory.clear();
    if (!mounted) return;
    setState(selectedIds.clear);
  }

  Future<void> shareEntries(
      BuildContext context, List<DownloadEntry> entries) async {
    if (entries.isEmpty) return;
    final links =
        entries.map((entry) => '${entry.title}\n${entry.url}').join('\n\n');
    final first = entries.first;
    final title = entries.length == 1 ? first.title : '${entries.length} files';
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: BoxDecoration(
              color: cpSurface(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 52,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                            color: cpOutlineVariant(context),
                            borderRadius: BorderRadius.circular(99)))),
                Text('Share Download',
                    style: TextStyle(
                        color: cpPrimary(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                Text(title,
                    style: TextStyle(
                        color: cpOnVariant(context),
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                if (entries.length == 1)
                  ShareMenuTile(
                      icon: const Icon(Icons.open_in_new, color: Cp.primary),
                      label: 'Open',
                      onTap: () {
                        Navigator.pop(sheetContext);
                        unawaited(openEntry(context, first));
                      }),
                ShareMenuTile(
                  icon: const Icon(Icons.chat, color: Cp.primary),
                  label: 'WhatsApp',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await launchUrl(
                        Uri.parse(
                            'https://wa.me/?text=${Uri.encodeComponent(links)}'),
                        mode: LaunchMode.externalApplication,
                        webOnlyWindowName: '_blank');
                  },
                ),
                ShareMenuTile(
                  icon: const Icon(Icons.email, color: Cp.primary),
                  label: 'Email',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await launchUrl(
                        Uri(scheme: 'mailto', queryParameters: {
                          'subject': 'CaterPro download - $title',
                          'body': links
                        }),
                        mode: LaunchMode.externalApplication);
                  },
                ),
                ShareMenuTile(
                  icon: const Icon(Icons.sms, color: Cp.primary),
                  label: 'SMS',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await launchUrl(
                        Uri(scheme: 'sms', queryParameters: {'body': links}),
                        mode: LaunchMode.externalApplication);
                  },
                ),
                ShareMenuTile(
                  icon: const Icon(Icons.link, color: Cp.primary),
                  label: 'Copy Link',
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: links));
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                    if (context.mounted) showCpSnack(context, 'Link copied');
                  },
                ),
                ShareMenuTile(
                    icon: const Icon(Icons.delete_outline, color: Cp.error),
                    label: entries.length == 1 ? 'Delete' : 'Delete selected',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      unawaited(deleteEntries(
                          context, entries.map((entry) => entry.id).toSet()));
                    }),
              ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
        topBar: TopBar(
            title: 'Downloads',
            subtitle:
                selectedIds.isEmpty ? null : '${selectedIds.length} selected',
            avatar: false,
            leading: IconButton(
                onPressed: selectedIds.isEmpty
                    ? widget.onClose
                    : () => setState(selectedIds.clear),
                icon: const Icon(Icons.arrow_back, color: Cp.primary)),
            actions: [
              AnimatedBuilder(
                  animation: downloadHistory,
                  builder: (context, _) {
                    final items = downloadHistory.items;
                    final selected = selectedEntries(items);
                    if (selectedIds.isNotEmpty) {
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            tooltip: 'Share selected',
                            onPressed: selected.isEmpty
                                ? null
                                : () =>
                                    unawaited(shareEntries(context, selected)),
                            icon: const Icon(Icons.share, color: Cp.primary)),
                        IconButton(
                            tooltip: 'Delete selected',
                            onPressed: selected.isEmpty
                                ? null
                                : () => unawaited(deleteEntries(context,
                                    selected.map((entry) => entry.id).toSet())),
                            icon: const Icon(Icons.delete_outline,
                                color: Cp.error)),
                      ]);
                    }
                    return IconButton(
                        tooltip: 'Clear downloads',
                        onPressed: items.isEmpty
                            ? null
                            : () => unawaited(clearAll(context)),
                        icon:
                            const Icon(Icons.delete_sweep, color: Cp.primary));
                  })
            ]),
        children: [
          AnimatedBuilder(
              animation: downloadHistory,
              builder: (context, _) {
                final items = downloadHistory.items;
                selectedIds
                    .removeWhere((id) => !items.any((item) => item.id == id));
                if (items.isEmpty) {
                  return const EmptyStateCard(
                      title: 'No downloads yet',
                      message:
                          'Downloaded PDFs, reports, menus, invoices, and backups will appear here.');
                }
                return CpCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                      children: List.generate(items.length, (index) {
                    final item = items[index];
                    final selected = selectedIds.contains(item.id);
                    return Column(children: [
                      ListTile(
                        selected: selected,
                        selectedTileColor: Cp.primaryFixed,
                        onLongPress: () => toggleSelected(item.id),
                        onTap: selectedIds.isEmpty
                            ? () => unawaited(openEntry(context, item))
                            : () => toggleSelected(item.id),
                        leading: Icon(iconFor(item.kind), color: Cp.primary),
                        title: Text(item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(timeLabel(item.createdAt),
                            style: TextStyle(
                                color: cpOnVariant(context),
                                fontWeight: FontWeight.w600)),
                        trailing: selectedIds.isEmpty
                            ? PopupMenuButton<String>(
                                tooltip: 'Download actions',
                                onSelected: (action) {
                                  switch (action) {
                                    case 'open':
                                      unawaited(openEntry(context, item));
                                      break;
                                    case 'share':
                                      unawaited(shareEntries(context, [item]));
                                      break;
                                    case 'select':
                                      toggleSelected(item.id);
                                      break;
                                    case 'delete':
                                      unawaited(
                                          deleteEntries(context, {item.id}));
                                      break;
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                      value: 'open',
                                      child: Row(children: [
                                        Icon(Icons.open_in_new,
                                            color: Cp.primary),
                                        SizedBox(width: 10),
                                        Text('Open')
                                      ])),
                                  PopupMenuItem(
                                      value: 'share',
                                      child: Row(children: [
                                        Icon(Icons.share, color: Cp.primary),
                                        SizedBox(width: 10),
                                        Text('Share')
                                      ])),
                                  PopupMenuItem(
                                      value: 'select',
                                      child: Row(children: [
                                        Icon(Icons.check_box_outlined,
                                            color: Cp.primary),
                                        SizedBox(width: 10),
                                        Text('Select')
                                      ])),
                                  PopupMenuDivider(),
                                  PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete_outline,
                                            color: Cp.error),
                                        SizedBox(width: 10),
                                        Text('Delete')
                                      ])),
                                ],
                              )
                            : Checkbox(
                                value: selected,
                                onChanged: (_) => toggleSelected(item.id)),
                      ),
                      if (index != items.length - 1)
                        Divider(height: 1, color: cpOutline(context)),
                    ]);
                  })),
                );
              }),
        ],
      );
}

String downloadTitleForEvent(AppEvent event, String type, {String? dateId}) {
  final base = event.name.isEmpty ? 'Event' : event.name;
  return switch (type) {
    'invoice' => '$base invoice.pdf',
    'quotation' => '$base quotation.pdf',
    'menu' => '$base menu${dateId == null ? '' : ' $dateId'}.pdf',
    'all-menus' => '$base all menus.pdf',
    _ => '$base document.pdf',
  };
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen(
      {super.key,
      required this.notifications,
      required this.events,
      required this.onOpenEvent,
      required this.onClose});

  final List<AppNotification> notifications;
  final List<AppEvent> events;
  final ValueChanged<AppEvent> onOpenEvent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ScreenFrame(
        topBar: TopBar(
            title: 'Notifications',
            avatar: false,
            leading: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back, color: Cp.primary))),
        children: [
          CpCard(
              color: Cp.primaryFixed,
              child: Row(children: [
                const Icon(Icons.notifications_active, color: Cp.primary),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        '${notifications.length} alerts from event creation, team assignment, and payment follow-ups.',
                        style: const TextStyle(
                            color: Cp.primary, fontWeight: FontWeight.w800))),
              ])),
          const SizedBox(height: 16),
          if (notifications.isEmpty)
            const EmptyStateCard(
                title: 'No notifications',
                message: 'Event reminders and payment alerts will appear here.')
          else
            ...notifications.map((notification) {
              final event = events
                  .where((item) => item.id == notification.eventId)
                  .firstOrNull;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CpCard(
                  onTap: event == null ? null : () => onOpenEvent(event),
                  child: Row(children: [
                    CircleAvatar(
                        backgroundColor:
                            notification.color.withValues(alpha: .12),
                        child: Icon(notification.icon,
                            color: notification.color, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(notification.title,
                              style: const TextStyle(
                                  color: Cp.primary,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(notification.message,
                              style: const TextStyle(
                                  color: Cp.onVariant,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text(
                              readableDateLabel(notification.date
                                  .toIso8601String()
                                  .substring(0, 10)),
                              style: const TextStyle(
                                  color: Cp.outline, fontSize: 12)),
                        ])),
                    if (event != null)
                      const Icon(Icons.chevron_right, color: Cp.outline),
                  ]),
                ),
              );
            }),
        ],
      );
}

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen(
      {super.key, required this.employees, required this.onClose});

  final List<Employee> employees;
  final VoidCallback onClose;

  Future<AuthSession?> loadSession() => AuthService().savedSession();

  @override
  Widget build(BuildContext context) => ScreenFrame(
        topBar: TopBar(
            title: 'User Management',
            avatar: false,
            leading: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.arrow_back, color: Cp.primary))),
        children: [
          FutureBuilder<AuthSession?>(
              future: loadSession(),
              builder: (context, snapshot) {
                final session = snapshot.data;
                return CpCard(
                    child: Row(children: [
                  const CircleAvatar(
                      backgroundColor: Cp.primaryContainer,
                      child: Icon(Icons.admin_panel_settings,
                          color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(session?.name ?? 'Current user',
                            style: const TextStyle(
                                color: Cp.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900)),
                        Text(session?.email ?? 'Signed in account',
                            style: const TextStyle(color: Cp.onVariant)),
                        const SizedBox(height: 6),
                        const Pill('Owner', color: Cp.primaryFixed),
                      ])),
                ]));
              }),
          const SizedBox(height: 16),
          const SectionHeader('Access Roles'),
          CpCard(
              child: Column(children: const [
            _RoleRow(
                icon: Icons.verified_user,
                title: 'Owner',
                subtitle: 'Full access to events, billing, menus, settings.'),
            Divider(color: Cp.outlineVariant),
            _RoleRow(
                icon: Icons.manage_accounts,
                title: 'Manager',
                subtitle: 'Can manage events, clients, menus, and team work.'),
            Divider(color: Cp.outlineVariant),
            _RoleRow(
                icon: Icons.badge,
                title: 'Staff',
                subtitle: 'Can be assigned to events and attendance reports.'),
          ])),
          const SizedBox(height: 16),
          SectionHeader('Team Users (${employees.length})'),
          if (employees.isEmpty)
            const EmptyStateCard(
                title: 'No employees',
                message: 'Add employees to prepare staff access later.')
          else
            ...employees.take(8).map((employee) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CpCard(
                      child: Row(children: [
                    CircleAvatar(
                        backgroundColor: Cp.primaryFixed,
                        child: Text(employee.name.isEmpty
                            ? 'E'
                            : employee.name[0].toUpperCase())),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(employee.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          Text(employee.designation,
                              style: const TextStyle(color: Cp.onVariant)),
                        ])),
                    const Pill('Staff', color: Cp.surfaceLow),
                  ])),
                )),
          const SizedBox(height: 8),
          const Text(
              'Login permissions for managers and staff can be connected when backend role APIs are available.',
              style:
                  TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
        ],
      );
}

class _RoleRow extends StatelessWidget {
  const _RoleRow(
      {required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: Cp.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(subtitle, style: const TextStyle(color: Cp.onVariant)),
              ])),
        ]),
      );
}

class AppAppearanceScreen extends StatefulWidget {
  const AppAppearanceScreen(
      {super.key,
      required this.profile,
      required this.onSaveProfile,
      required this.onClose});

  final BusinessProfile profile;
  final Future<void> Function(BusinessProfile profile) onSaveProfile;
  final VoidCallback onClose;

  @override
  State<AppAppearanceScreen> createState() => _AppAppearanceScreenState();
}

class _AppAppearanceScreenState extends State<AppAppearanceScreen> {
  late AppPreferences draft = appPreferences.value;
  late double pdfMenuFontSize = widget.profile.pdfMenuFontSize;
  bool savingPdfMenu = false;

  Future<void> save(AppPreferences next) async {
    final normalized =
        next.copyWith(theme: AppPreferences.normalizeTheme(next.theme));
    setState(() => draft = normalized);
    await appPreferences.save(normalized);
  }

  BusinessProfile profileWithPdfMenuFontSize() => BusinessProfile(
        businessName: widget.profile.businessName,
        serviceType: widget.profile.serviceType,
        gstin: widget.profile.gstin,
        gstType: widget.profile.gstType,
        gstRate: widget.profile.gstRate,
        pan: widget.profile.pan,
        address: widget.profile.address,
        phone: widget.profile.phone,
        email: widget.profile.email,
        accountHolderName: widget.profile.accountHolderName,
        bankName: widget.profile.bankName,
        branchName: widget.profile.branchName,
        accountNumber: widget.profile.accountNumber,
        ifsc: widget.profile.ifsc,
        terms: widget.profile.terms,
        logoBase64: widget.profile.logoBase64,
        signatureBase64: widget.profile.signatureBase64,
        qrBase64: widget.profile.qrBase64,
        documentTemplate: widget.profile.documentTemplate,
        invoiceTextScale: widget.profile.invoiceTextScale,
        pdfMenuFontSize: pdfMenuFontSize,
      );

  Future<void> savePdfMenuFontSize() async {
    setState(() => savingPdfMenu = true);
    try {
      await widget.onSaveProfile(profileWithPdfMenuFontSize());
      if (mounted) showCpSnack(context, 'PDF menu font size saved');
    } catch (e) {
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => savingPdfMenu = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedTheme = AppPreferences.normalizeTheme(draft.theme);
    return ScreenFrame(
      topBar: TopBar(
          title: tr('App Appearance', kn: 'ಅ್ಯಪ್ ರೂಪ', hi: 'ऐप दिखावट'),
          avatar: false,
          leading: IconButton(
              onPressed: widget.onClose,
              icon: Icon(Icons.arrow_back, color: scheme.primary))),
      children: [
        CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Text Size', kn: 'ಅಕ್ಷರ ಗಾತ್ರ', hi: 'टेक्स्ट आकार'),
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w900)),
          Slider(
              min: .85,
              max: 1.25,
              divisions: 4,
              label: '${(draft.textScale * 100).round()}%',
              value: draft.textScale,
              onChanged: (value) => save(draft.copyWith(textScale: value))),
          Text('Preview: CaterPro 123',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ])),
        const SizedBox(height: 14),
        CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Font',
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              initialValue: draft.font,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.text_fields)),
              items: const [
                DropdownMenuItem(value: 'Quicksand', child: Text('Quicksand')),
                DropdownMenuItem(value: 'Poppins', child: Text('Poppins')),
                DropdownMenuItem(value: 'Noto Sans', child: Text('Noto Sans')),
                DropdownMenuItem(
                    value: 'Noto Sans Kannada',
                    child: Text('Noto Sans Kannada')),
              ],
              onChanged: (value) {
                if (value != null) save(draft.copyWith(font: value));
              }),
        ])),
        const SizedBox(height: 14),
        CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Theme', kn: 'ಥೀಮ್', hi: 'थीम'),
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'system',
                  icon: Icon(Icons.phone_android),
                  label: Text('System')),
              ButtonSegment(
                  value: 'light',
                  icon: Icon(Icons.light_mode),
                  label: Text('Day')),
              ButtonSegment(
                  value: 'dark',
                  icon: Icon(Icons.dark_mode),
                  label: Text('Night')),
            ],
            selected: {selectedTheme},
            showSelectedIcon: false,
            onSelectionChanged: (value) =>
                save(draft.copyWith(theme: value.first)),
          ),
        ])),
        const SizedBox(height: 14),
        CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('App Language', kn: 'ಅ್ಯಪ್ ಭಾಷೆ', hi: 'ऐप भाषा'),
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              initialValue: draft.languageCode,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.translate)),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'kn', child: Text('ಕನ್ನಡ')),
                DropdownMenuItem(value: 'hi', child: Text('हिन्दी')),
              ],
              onChanged: (value) {
                if (value != null) {
                  save(draft.copyWith(languageCode: value));
                }
              }),
          const SizedBox(height: 8),
          Text('Selected: ${draft.languageLabel}',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ])),
        const SizedBox(height: 14),
        CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PDF Menu Font Size',
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w900)),
          Slider(
              min: 10,
              max: 16,
              divisions: 6,
              label: '${pdfMenuFontSize.round()}',
              value: pdfMenuFontSize.clamp(10, 16),
              onChanged: (value) => setState(() => pdfMenuFontSize = value)),
          Text('Preview: Badam Milk / Fruit Punch',
              style: TextStyle(
                  fontSize: pdfMenuFontSize, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: savingPdfMenu ? null : savePdfMenuFontSize,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(
                      savingPdfMenu ? 'Saving...' : 'Save PDF Menu Size',
                      style: const TextStyle(fontWeight: FontWeight.w900)))),
        ])),
      ],
    );
  }
}

class InvoiceSettingsScreen extends StatefulWidget {
  const InvoiceSettingsScreen(
      {super.key,
      required this.profile,
      required this.onSave,
      required this.onClose});

  final BusinessProfile profile;
  final Future<void> Function(BusinessProfile profile) onSave;
  final VoidCallback onClose;

  @override
  State<InvoiceSettingsScreen> createState() => _InvoiceSettingsScreenState();
}

class _InvoiceSettingsScreenState extends State<InvoiceSettingsScreen> {
  late String documentTemplate = switch (widget.profile.documentTemplate) {
    'premium' => 'elegant',
    'minimal' => 'classic',
    'classic' || 'elegant' || 'modern' => widget.profile.documentTemplate,
    _ => 'modern',
  };
  late double invoiceTextScale = widget.profile.invoiceTextScale;
  late double pdfMenuFontSize = widget.profile.pdfMenuFontSize;
  bool saving = false;

  BusinessProfile currentProfile() => BusinessProfile(
        businessName: widget.profile.businessName,
        serviceType: widget.profile.serviceType,
        gstin: widget.profile.gstin,
        gstType: widget.profile.gstType,
        gstRate: widget.profile.gstRate,
        pan: widget.profile.pan,
        address: widget.profile.address,
        phone: widget.profile.phone,
        email: widget.profile.email,
        accountHolderName: widget.profile.accountHolderName,
        bankName: widget.profile.bankName,
        branchName: widget.profile.branchName,
        accountNumber: widget.profile.accountNumber,
        ifsc: widget.profile.ifsc,
        terms: widget.profile.terms,
        logoBase64: widget.profile.logoBase64,
        signatureBase64: widget.profile.signatureBase64,
        qrBase64: widget.profile.qrBase64,
        documentTemplate: documentTemplate,
        invoiceTextScale: invoiceTextScale,
        pdfMenuFontSize: pdfMenuFontSize,
      );

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.onSave(currentProfile());
      if (!mounted) return;
      showCpSnack(context, 'Invoice settings saved');
      widget.onClose();
    } catch (e) {
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
        topBar: TopBar(
            title: 'Invoice Settings',
            avatar: false,
            leading: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.arrow_back, color: Cp.primary)),
            actions: [
              TextButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving...' : 'Save',
                      style: const TextStyle(
                          color: Cp.primary, fontWeight: FontWeight.w900)))
            ]),
        children: [
          CpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Invoice / Quotation Theme',
                    style: TextStyle(
                        color: Cp.primary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: documentTemplate,
                  decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                  items: const [
                    DropdownMenuItem(value: 'classic', child: Text('Classic')),
                    DropdownMenuItem(value: 'elegant', child: Text('Elegant')),
                    DropdownMenuItem(value: 'modern', child: Text('Modern')),
                  ],
                  onChanged: (value) =>
                      setState(() => documentTemplate = value ?? 'modern'),
                ),
              ])),
          const SizedBox(height: 14),
          CpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Invoice Text Size',
                    style: TextStyle(
                        color: Cp.primary, fontWeight: FontWeight.w900)),
                Slider(
                    min: .9,
                    max: 1.2,
                    divisions: 3,
                    label: '${(invoiceTextScale * 100).round()}%',
                    value: invoiceTextScale.clamp(.9, 1.2),
                    onChanged: (value) =>
                        setState(() => invoiceTextScale = value)),
                Text('Preview: Invoice / Quotation total ${money(25000)}',
                    style: TextStyle(
                        fontSize: 15 * invoiceTextScale,
                        fontWeight: FontWeight.w700)),
              ])),
          const SizedBox(height: 14),
          CpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('PDF Menu Font Size',
                    style: TextStyle(
                        color: Cp.primary, fontWeight: FontWeight.w900)),
                Slider(
                    min: 10,
                    max: 16,
                    divisions: 6,
                    label: '${pdfMenuFontSize.round()}',
                    value: pdfMenuFontSize.clamp(10, 16),
                    onChanged: (value) =>
                        setState(() => pdfMenuFontSize = value)),
                Text('Preview: Badam Milk / Fruit Punch',
                    style: TextStyle(
                        fontSize: pdfMenuFontSize,
                        fontWeight: FontWeight.w700)),
              ])),
          const SizedBox(height: 18),
          SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                  onPressed: saving ? null : save,
                  style: FilledButton.styleFrom(backgroundColor: Cp.primary),
                  icon: const Icon(Icons.save),
                  label: Text(saving ? 'Saving...' : 'Save Settings',
                      style: const TextStyle(fontWeight: FontWeight.w900)))),
        ],
      );
}

void showAdditionalServiceManager(
  BuildContext context, {
  required List<AdditionalServiceItem> services,
  required ValueChanged<AdditionalServiceItem> onSave,
  required ValueChanged<String> onDelete,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AdditionalServiceManagerSheet(
        services: services, onSave: onSave, onDelete: onDelete),
  );
}

void showEventRecordPaymentSheet(BuildContext context,
    {required AppEvent event,
    required ApiService api,
    required ValueChanged<AppEvent> onSaved}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        EventRecordPaymentSheet(event: event, api: api, onSaved: onSaved),
  );
}

class EventRecordPaymentSheet extends StatefulWidget {
  const EventRecordPaymentSheet(
      {super.key,
      required this.event,
      required this.api,
      required this.onSaved});
  final AppEvent event;
  final ApiService api;
  final ValueChanged<AppEvent> onSaved;

  @override
  State<EventRecordPaymentSheet> createState() =>
      _EventRecordPaymentSheetState();
}

class _EventRecordPaymentSheetState extends State<EventRecordPaymentSheet> {
  late final TextEditingController paymentController;
  late final TextEditingController dateController;
  late final TextEditingController refController;
  final paymentModes = ['Cash', 'UPI', 'NEFT', 'RTGS', 'Cheque'];
  int selectedMode = 0;
  bool settled = false;
  bool saving = false;
  String? errorText;

  int get totalAmount => eventTotal(widget.event);
  int get paidAmount => eventPaid(widget.event);
  int get balanceAmount => eventBalance(widget.event);
  int get paymentAmount =>
      int.tryParse(paymentController.text.replaceAll(',', '').trim()) ?? 0;
  int get remainingAfterPayment =>
      (balanceAmount - paymentAmount).clamp(0, balanceAmount);
  int get settledDiscount =>
      settled && paymentAmount <= balanceAmount ? remainingAfterPayment : 0;
  int get finalBalance =>
      settled && paymentAmount <= balanceAmount ? 0 : remainingAfterPayment;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    paymentController = TextEditingController();
    dateController = TextEditingController(
        text:
            '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');
    refController = TextEditingController();
  }

  @override
  void dispose() {
    paymentController.dispose();
    dateController.dispose();
    refController.dispose();
    super.dispose();
  }

  void validate() {
    final amount = paymentAmount;
    setState(() {
      if (amount <= 0) {
        errorText = 'Enter a payment amount.';
      } else if (amount > balanceAmount) {
        errorText =
            'Payment cannot be more than remaining balance ${money(balanceAmount)}.';
      } else if (isoDateValidator(dateController.text, label: 'Payment date') !=
          null) {
        errorText =
            isoDateValidator(dateController.text, label: 'Payment date');
      } else {
        errorText = null;
      }
    });
  }

  Future<void> savePayment() async {
    validate();
    if (errorText != null || saving) return;
    setState(() => saving = true);
    try {
      final updated = await widget.api.recordPayment(
        widget.event.id,
        amount: paymentAmount,
        date: dateController.text.trim(),
        mode: paymentModes[selectedMode],
        reference: refController.text.trim(),
        settled: settled,
        settledDiscount: settledDiscount,
      );
      widget.onSaved(updated);
      if (!mounted) return;
      Navigator.pop(context);
      showCpSnack(
          context,
          settledDiscount > 0
              ? 'Payment saved. ${money(settledDiscount)} marked as settlement discount.'
              : 'Payment saved.');
    } catch (e) {
      if (mounted) {
        setState(
            () => errorText = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, 10, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
            color: cpSurface(context),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                        width: 48,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 22),
                        decoration: BoxDecoration(
                            color: cpOutlineVariant(context),
                            borderRadius: BorderRadius.circular(99)))),
                Text('Record Payment - ${widget.event.name}',
                    style: TextStyle(
                        color: cpPrimary(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                Text(
                    'Payment amount must be less than or equal to the remaining balance.',
                    style: TextStyle(
                        color: cpOnVariant(context),
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                CpCard(
                    color: cpCard(context),
                    child: Row(children: [
                      Expanded(
                          child: _MoneyCell(
                              label: 'Total', value: money(totalAmount))),
                      Expanded(
                          child: _MoneyCell(
                              label: 'Paid',
                              value: money(paidAmount),
                              color: Cp.tertiaryContainer)),
                      Expanded(
                          child: _MoneyCell(
                              label: 'Balance',
                              value: money(balanceAmount),
                              color: Cp.error)),
                    ])),
                const SizedBox(height: 16),
                PaymentInputBox(
                    label: 'Payment Amount',
                    controller: paymentController,
                    icon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => validate()),
                Row(children: [
                  Expanded(
                      child: PaymentInputBox(
                          label: 'Date',
                          controller: dateController,
                          icon: Icons.calendar_today)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: PaymentInputBox(
                          label: 'Ref No.',
                          controller: refController,
                          icon: Icons.confirmation_number))
                ]),
                const Text('Payment Mode',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(paymentModes.length, (index) {
                    final selected = selectedMode == index;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(paymentModes[index]),
                      selectedColor: Cp.primaryContainer,
                      labelStyle: TextStyle(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : cpOnVariant(context),
                          fontWeight: FontWeight.w800),
                      onSelected: (_) => setState(() => selectedMode = index),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: settled,
                  onChanged: (value) =>
                      setState(() => settled = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Cp.primary,
                  title: const Text('Settled',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(settled
                      ? '${money(settledDiscount)} will be treated as discount/settlement. Final balance: ${money(finalBalance)}'
                      : 'Unchecked keeps ${money(remainingAfterPayment)} as pending balance.'),
                ),
                if (errorText != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(errorText!,
                          style: const TextStyle(
                              color: Cp.error, fontWeight: FontWeight.w800))),
                SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                        onPressed: saving ? null : savePayment,
                        style:
                            FilledButton.styleFrom(backgroundColor: Cp.primary),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(saving ? 'Saving...' : 'Save Payment',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)))),
                Center(
                    child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel',
                            style: TextStyle(
                                color: cpPrimary(context),
                                fontWeight: FontWeight.w900)))),
              ]),
        ),
      ),
    );
  }
}

class AdditionalServiceManagerSheet extends StatelessWidget {
  const AdditionalServiceManagerSheet(
      {super.key,
      required this.services,
      required this.onSave,
      required this.onDelete});
  final List<AdditionalServiceItem> services;
  final ValueChanged<AdditionalServiceItem> onSave;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .82),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: BoxDecoration(
            color: cpSurface(context),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 48,
                    height: 6,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: cpOutlineVariant(context),
                        borderRadius: BorderRadius.circular(99)))),
            Row(children: [
              Expanded(
                  child: Text('Additional Services',
                      style: TextStyle(
                          color: cpPrimary(context),
                          fontSize: 24,
                          fontWeight: FontWeight.w900))),
              IconButton(
                  onPressed: () => showServiceEditor(context, onSave: onSave),
                  icon: const Icon(Icons.add_circle, color: Cp.primary)),
            ]),
            Text(
                'Add, update, or remove services used in event menu configuration.',
                style: TextStyle(color: cpOnVariant(context))),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final service = services[index];
                  return CpCard(
                    color: cpCard(context),
                    child: Row(children: [
                      const Icon(Icons.room_service, color: Cp.secondary),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              serviceLine(service.name, service.quantity,
                                  service.unit, service.price),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      IconButton(
                          onPressed: () => showServiceEditor(context,
                              service: service, onSave: onSave),
                          icon: const Icon(Icons.edit, color: Cp.primary)),
                      IconButton(
                          onPressed: () async {
                            final confirmed = await confirmEventAction(context,
                                'Delete Service?', 'Delete ${service.name}?');
                            if (confirmed) onDelete(service.id);
                          },
                          icon: const Icon(Icons.delete, color: Cp.error)),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showServiceEditor(BuildContext context,
    {AdditionalServiceItem? service,
    required ValueChanged<AdditionalServiceItem> onSave}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ServiceEditorSheet(service: service, onSave: onSave),
  );
}

class ServiceEditorSheet extends StatefulWidget {
  const ServiceEditorSheet({super.key, this.service, required this.onSave});
  final AdditionalServiceItem? service;
  final ValueChanged<AdditionalServiceItem> onSave;

  @override
  State<ServiceEditorSheet> createState() => _ServiceEditorSheetState();
}

class _ServiceEditorSheetState extends State<ServiceEditorSheet> {
  late final TextEditingController id;
  late final TextEditingController name;
  late final TextEditingController unit;
  late final TextEditingController quantity;
  late final TextEditingController price;
  String? error;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    id = TextEditingController(
        text: service?.id ??
            'SRV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    name = TextEditingController(text: service?.name ?? '');
    unit = TextEditingController(text: service?.unit ?? 'pcs');
    quantity = TextEditingController(text: '${service?.quantity ?? 0}');
    price = TextEditingController(text: '${service?.price ?? 0}');
  }

  @override
  void dispose() {
    id.dispose();
    name.dispose();
    unit.dispose();
    quantity.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: BoxDecoration(
            color: cpSurface(context),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 48,
                      height: 6,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: cpOutlineVariant(context),
                          borderRadius: BorderRadius.circular(99)))),
              Text(widget.service == null ? 'Add Service' : 'Update Service',
                  style: TextStyle(
                      color: cpPrimary(context),
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              EditableInlineField(label: 'Service ID', controller: id),
              EditableInlineField(label: 'Service Name', controller: name),
              Row(children: [
                Expanded(
                    child: EditableInlineField(
                        label: 'Quantity',
                        controller: quantity,
                        keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(
                    child: EditableInlineField(label: 'Unit', controller: unit))
              ]),
              EditableInlineField(
                  label: 'Price',
                  controller: price,
                  keyboardType: TextInputType.number),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error!,
                        style: const TextStyle(
                            color: Cp.error, fontWeight: FontWeight.w800))),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Cp.primaryContainer),
                  onPressed: () {
                    final parsedQuantity = int.tryParse(quantity.text.trim());
                    final parsedPrice = int.tryParse(price.text.trim());
                    if (id.text.trim().isEmpty ||
                        name.text.trim().isEmpty ||
                        unit.text.trim().isEmpty ||
                        parsedQuantity == null ||
                        parsedQuantity < 0 ||
                        parsedPrice == null ||
                        parsedPrice < 0) {
                      setState(() => error =
                          'Enter service ID, name, unit, and valid quantity/price.');
                      return;
                    }
                    widget.onSave(AdditionalServiceItem(
                        id: id.text.trim(),
                        name: name.text.trim(),
                        unit: unit.text.trim(),
                        quantity: parsedQuantity,
                        price: parsedPrice));
                    Navigator.pop(context);
                  },
                  child: const Text('Save Service',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
      ),
    );
  }
}

class EditableInlineField extends StatelessWidget {
  const EditableInlineField(
      {super.key,
      required this.label,
      required this.controller,
      this.enabled = true,
      this.keyboardType,
      this.inputFormatters});
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
              labelText: label,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
      );
}
