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
      required this.openNotifications,
      required this.openUserManagement,
      required this.openAppAppearance,
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
  final VoidCallback openNotifications;
  final VoidCallback openUserManagement;
  final VoidCallback openAppAppearance;
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
                businessProfile.serviceType.isEmpty
                    ? 'Add your business details'
                    : businessProfile.serviceType,
                style: const TextStyle(color: Cp.onVariant)),
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
          (Icons.eco, 'Vegetables & Fruits')
        ], onItemTap: {
          'Menu Master': openMenu,
          'Custom Menus': openCustomMenus,
          'Additional Services': () => showAdditionalServiceManager(context,
              services: services,
              onSave: onSaveService,
              onDelete: onDeleteService),
          'Raw Materials': openRawMaterials,
          'Vegetables & Fruits': openProduceItems
        }),
        SettingsGroup(title: t('Team'), items: [
          (Icons.badge, 'Employees'),
        ], onItemTap: {
          'Employees': openEmployees,
        }),
        SettingsGroup(title: t('Preferences'), items: [
          (Icons.description, 'Invoice Settings'),
          (Icons.notifications_active, 'Notifications'),
          (Icons.light_mode, 'App Appearance')
        ], onItemTap: {
          'Invoice Settings': openInvoiceSettings,
          'Notifications': openNotifications,
          'App Appearance': openAppAppearance,
        }),
        SettingsGroup(title: t('Data'), items: [
          (Icons.file_download, 'Export Data'),
          (Icons.upload_file, 'Import Data'),
          (Icons.cloud_upload, 'Backup to Google Drive'),
          (Icons.sync, 'Sync Now'),
        ], onItemTap: {
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
                      style: const TextStyle(
                          color: Cp.primary, fontWeight: FontWeight.w800))),
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
                style: const TextStyle(
                    color: Cp.primary, fontWeight: FontWeight.w800))),
        Material(
          color: Cp.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          child: Column(
              children: List.generate(items.length, (i) {
            final label = items[i].$2;
            return ListTile(
              onTap: onItemTap[label] ?? () => fallback(label),
              leading: Icon(items[i].$1, color: Cp.onVariant),
              title: Text(t(label),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right, color: Cp.outline),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            );
          })),
        ),
      ]),
    );
  }
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
  const AppAppearanceScreen({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<AppAppearanceScreen> createState() => _AppAppearanceScreenState();
}

class _AppAppearanceScreenState extends State<AppAppearanceScreen> {
  late AppPreferences draft = appPreferences.value;

  Future<void> save(AppPreferences next) async {
    setState(() => draft = next);
    await appPreferences.save(next);
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
        topBar: TopBar(
            title: tr('App Appearance', kn: 'ಅ್ಯಪ್ ರೂಪ', hi: 'ऐप दिखावट'),
            avatar: false,
            leading: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.arrow_back, color: Cp.primary))),
        children: [
          CpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(tr('Text Size', kn: 'ಅಕ್ಷರ ಗಾತ್ರ', hi: 'टेक्स्ट आकार'),
                    style: const TextStyle(
                        color: Cp.primary, fontWeight: FontWeight.w900)),
                Slider(
                    min: .85,
                    max: 1.25,
                    divisions: 4,
                    label: '${(draft.textScale * 100).round()}%',
                    value: draft.textScale,
                    onChanged: (value) =>
                        save(draft.copyWith(textScale: value))),
                Text('Preview: CaterPro 123',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ])),
          const SizedBox(height: 14),
          CpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Font',
                    style: TextStyle(
                        color: Cp.primary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                    initialValue: draft.font,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.text_fields)),
                    items: const [
                      DropdownMenuItem(
                          value: 'Quicksand', child: Text('Quicksand')),
                      DropdownMenuItem(
                          value: 'Poppins', child: Text('Poppins')),
                      DropdownMenuItem(
                          value: 'Noto Sans', child: Text('Noto Sans')),
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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(tr('Theme', kn: 'ಥೀಮ್', hi: 'थीम'),
                    style: const TextStyle(
                        color: Cp.primary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'light',
                        icon: Icon(Icons.light_mode),
                        label: Text('Day')),
                    ButtonSegment(
                        value: 'dark',
                        icon: Icon(Icons.dark_mode),
                        label: Text('Night')),
                    ButtonSegment(
                        value: 'system',
                        icon: Icon(Icons.phone_android),
                        label: Text('System')),
                  ],
                  selected: {draft.theme},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      save(draft.copyWith(theme: value.first)),
                ),
              ])),
          const SizedBox(height: 14),
          CpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(tr('App Language', kn: 'ಅ್ಯಪ್ ಭಾಷೆ', hi: 'ऐप भाषा'),
                    style: const TextStyle(
                        color: Cp.primary, fontWeight: FontWeight.w900)),
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
                    style: const TextStyle(color: Cp.onVariant)),
              ])),
        ],
      );
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
        bankName: widget.profile.bankName,
        accountNumber: widget.profile.accountNumber,
        terms: widget.profile.terms,
        logoBase64: widget.profile.logoBase64,
        signatureBase64: widget.profile.signatureBase64,
        qrBase64: widget.profile.qrBase64,
        documentTemplate: documentTemplate,
        invoiceTextScale: invoiceTextScale,
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
        decoration: const BoxDecoration(
            color: Cp.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
                            color: Cp.outlineVariant,
                            borderRadius: BorderRadius.circular(99)))),
                Text('Record Payment - ${widget.event.name}',
                    style: const TextStyle(
                        color: Cp.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const Text(
                    'Payment amount must be less than or equal to the remaining balance.',
                    style: TextStyle(
                        color: Cp.onVariant, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                CpCard(
                    color: Cp.surfaceLow,
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
                          color: selected ? Colors.white : Cp.onVariant,
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
                        child: const Text('Cancel',
                            style: TextStyle(
                                color: Cp.primary,
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
        decoration: const BoxDecoration(
            color: Cp.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
                        color: Cp.outlineVariant,
                        borderRadius: BorderRadius.circular(99)))),
            Row(children: [
              const Expanded(
                  child: Text('Additional Services',
                      style: TextStyle(
                          color: Cp.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900))),
              IconButton(
                  onPressed: () => showServiceEditor(context, onSave: onSave),
                  icon: const Icon(Icons.add_circle, color: Cp.primary)),
            ]),
            const Text(
                'Add, update, or remove services used in event menu configuration.',
                style: TextStyle(color: Cp.onVariant)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final service = services[index];
                  return CpCard(
                    color: Cp.card,
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
                          onPressed: () => onDelete(service.id),
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
        decoration: const BoxDecoration(
            color: Cp.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
                          color: Cp.outlineVariant,
                          borderRadius: BorderRadius.circular(99)))),
              Text(widget.service == null ? 'Add Service' : 'Update Service',
                  style: const TextStyle(
                      color: Cp.primary,
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
      this.keyboardType,
      this.inputFormatters});
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
              labelText: label,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
      );
}
