part of '../main.dart';

int menuTimeSortMinutes(String value) {
  final raw = value.trim();
  final match =
      RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$').firstMatch(raw);
  if (match == null) return 24 * 60;
  var hour = int.tryParse(match.group(1) ?? '') ?? 0;
  final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
  final suffix = match.group(3)?.toUpperCase();
  if (suffix == 'PM' && hour < 12) hour += 12;
  if (suffix == 'AM' && hour == 12) hour = 0;
  return hour.clamp(0, 23) * 60 + minute.clamp(0, 59);
}

List<AppEventDate> sortedEventDates(Iterable<AppEventDate> dates) =>
    dates.toList()..sort((a, b) => a.date.compareTo(b.date));

List<AppMenuSlot> sortedMenuSlots(Iterable<AppMenuSlot> slots) => slots.toList()
  ..sort((a, b) {
    final byTime =
        menuTimeSortMinutes(a.time).compareTo(menuTimeSortMinutes(b.time));
    if (byTime != 0) return byTime;
    return a.type.compareTo(b.type);
  });

List<AppMenuSlot> sortedVisibleMenuSlots(Iterable<AppMenuSlot> slots) =>
    sortedMenuSlots(slots.where((slot) => slot.enabled && slot.pax > 0));

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen(
      {super.key,
      required this.event,
      required this.events,
      required this.api,
      required this.employees,
      required this.businessProfile,
      required this.onEdit,
      required this.onEditStep,
      required this.onAddEvent,
      required this.onEventUpdated,
      required this.onEventDeleted,
      required this.onClose});
  final AppEvent? event;
  final ApiService api;
  final List<AppEvent> events;
  final List<Employee> employees;
  final BusinessProfile businessProfile;
  final ValueChanged<AppEvent> onEdit;
  final void Function(AppEvent event, int step) onEditStep;
  final VoidCallback onAddEvent;
  final ValueChanged<AppEvent> onEventUpdated;
  final ValueChanged<String> onEventDeleted;
  final VoidCallback onClose;

  Future<void> handleAction(
      BuildContext context, EventScreenAction action) async {
    final selectedEvent = event;
    if (selectedEvent == null) return;
    switch (action) {
      case EventScreenAction.downloadQuotation:
        await downloadDocument(context, selectedEvent, 'quotation');
        break;
      case EventScreenAction.downloadInvoice:
        await downloadDocument(context, selectedEvent, 'invoice');
        break;
      case EventScreenAction.currentDayMenu:
        if (selectedEvent.dates.isEmpty) {
          showCpSnack(context, 'No event dates available for menu download');
        } else {
          await downloadDocument(context, selectedEvent, 'menu',
              dateId: selectedEvent.dates.first.id);
        }
        break;
      case EventScreenAction.allDaysMenu:
        await downloadDocument(context, selectedEvent, 'all-menus');
        break;
      case EventScreenAction.shareEventInfo:
        await shareEventInfoOnWhatsApp(context, selectedEvent);
        break;
      case EventScreenAction.shareMenu:
        await showMenuShareSheet(context, selectedEvent);
        break;
      case EventScreenAction.deleteEvent:
        final confirmed = await confirmEventAction(context, 'Delete Event?',
            'This will remove this event and all linked dates, menus, payments, and documents.');
        if (!context.mounted || !confirmed) return;
        await deleteEvent(context, selectedEvent);
        break;
      case EventScreenAction.deleteDate:
        final date = await pickDateToDelete(context, selectedEvent);
        if (!context.mounted || date == null) return;
        final confirmed = await confirmEventAction(context, 'Delete Date?',
            'This will remove ${date.label.isEmpty ? date.date : date.label} and its menus.');
        if (!context.mounted || !confirmed) return;
        await deleteDate(context, selectedEvent, date);
        break;
      case EventScreenAction.deleteMenu:
        final menu = await pickMenuToDelete(context, selectedEvent);
        if (!context.mounted || menu == null) return;
        final confirmed = await confirmEventAction(context, 'Delete Menu?',
            'This will remove ${menu.value.type} from ${menu.key.label.isEmpty ? menu.key.date : menu.key.label}.');
        if (!context.mounted || !confirmed) return;
        await deleteMenu(context, selectedEvent, menu.key, menu.value);
        break;
    }
  }

  Future<void> deleteEvent(BuildContext context, AppEvent event) async {
    try {
      showCpSnack(context, 'Deleting event...');
      await api.deleteEvent(event.id);
      onEventDeleted(event.id);
      if (!context.mounted) return;
      showCpSnack(context, 'Event deleted');
      onClose();
    } catch (e) {
      if (!context.mounted) return;
      showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> deleteDate(
      BuildContext context, AppEvent event, AppEventDate date) async {
    try {
      showCpSnack(context, 'Deleting date...');
      final updated = await api.deleteEventDate(event.id, date.id);
      onEventUpdated(updated);
      if (!context.mounted) return;
      showCpSnack(context, 'Date deleted');
    } catch (e) {
      if (!context.mounted) return;
      showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> deleteMenu(BuildContext context, AppEvent event,
      AppEventDate date, AppMenuSlot menu) async {
    try {
      showCpSnack(context, 'Deleting menu...');
      final updated = await api.deleteMenuSlot(event.id, date.id, menu.id);
      onEventUpdated(updated);
      if (!context.mounted) return;
      showCpSnack(context, 'Menu deleted');
    } catch (e) {
      if (!context.mounted) return;
      showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<AppEventDate?> pickDateToDelete(
      BuildContext context, AppEvent event) async {
    if (event.dates.isEmpty) {
      showCpSnack(context, 'No dates available to delete');
      return null;
    }
    if (event.dates.length == 1) return event.dates.first;
    return showDialog<AppEventDate>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select Date',
            style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)),
        children: [
          for (final date in event.dates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, date),
              child: Text(date.label.isEmpty ? date.date : date.label,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Future<MapEntry<AppEventDate, AppMenuSlot>?> pickMenuToDelete(
      BuildContext context, AppEvent event) async {
    final menus = <MapEntry<AppEventDate, AppMenuSlot>>[];
    for (final date in event.dates) {
      for (final slot in date.menuSlots) {
        menus.add(MapEntry(date, slot));
      }
    }
    if (menus.isEmpty) {
      showCpSnack(context, 'No menus available to delete');
      return null;
    }
    if (menus.length == 1) return menus.first;
    return showDialog<MapEntry<AppEventDate, AppMenuSlot>>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select Menu',
            style: TextStyle(color: Cp.primary, fontWeight: FontWeight.w900)),
        children: [
          for (final menu in menus)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, menu),
              child: Text(
                  '${menu.value.type} | ${menu.key.label.isEmpty ? menu.key.date : menu.key.label}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Future<void> downloadDocument(
      BuildContext context, AppEvent event, String type,
      {String? dateId}) async {
    try {
      showCpSnack(context, 'Downloading...');
      final uri = await api.documentUri(event.id, type, dateId: dateId);
      if (!context.mounted) return;
      final label = switch (type) {
        'invoice' => 'Invoice',
        'quotation' => 'Quotation',
        'menu' => 'Menu',
        'all-menus' => 'All days menu',
        _ => 'Document',
      };
      showDownloadSnack(context, uri,
          title: downloadTitleForEvent(event, type, dateId: dateId),
          kind: type == 'menu' || type == 'all-menus' ? 'menu' : 'pdf',
          successMessage: '$label download started',
          failureMessage: 'Unable to start download');
    } catch (e) {
      if (!context.mounted) return;
      showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> showMenuShareSheet(BuildContext context, AppEvent event) async {
    try {
      final uri = await api.documentUri(event.id, 'all-menus');
      if (!context.mounted) return;
      final link = uri.toString();
      final message = buildMenuWhatsAppMessage(event);
      showModalBottomSheet<void>(
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
                          width: 48,
                          height: 6,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                              color: cpOutlineVariant(context),
                              borderRadius: BorderRadius.circular(99)))),
                  Text('Share Menu',
                      style: TextStyle(
                          color: cpPrimary(context),
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  Text(
                      whatsappClientEventPhrase(whatsappEventClientName(event)),
                      style: TextStyle(
                          color: cpOnVariant(context),
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  ShareMenuTile(
                    icon: const WhatsAppIcon(size: 22),
                    label: 'WhatsApp',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await shareMenuOnWhatsApp(context, event, message);
                    },
                  ),
                  ShareMenuTile(
                    icon: const Icon(Icons.email, color: Cp.primary),
                    label: 'Email',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await launchUrl(
                          Uri(scheme: 'mailto', queryParameters: {
                            'subject':
                                'Menu - ${whatsappClientEventPhrase(whatsappEventClientName(event))}',
                            'body': message
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
                          Uri(
                              scheme: 'sms',
                              queryParameters: {'body': message}),
                          mode: LaunchMode.externalApplication);
                    },
                  ),
                  ShareMenuTile(
                    icon: const Icon(Icons.link, color: Cp.primary),
                    label: 'Copy Link',
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                      if (context.mounted) {
                        showCpSnack(context, 'Menu link copied');
                      }
                    },
                  ),
                  ShareMenuTile(
                    icon: const Icon(Icons.picture_as_pdf, color: Cp.primary),
                    label: 'Download PDF',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      if (context.mounted) {
                        showDownloadSnack(context, uri,
                            title: downloadTitleForEvent(event, 'all-menus'),
                            kind: 'menu',
                            successMessage: 'Menu download started',
                            failureMessage: 'Unable to start download');
                      }
                    },
                  ),
                ]),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> shareEventInfoOnWhatsApp(
      BuildContext context, AppEvent event) async {
    final mobile = normalizeMobileText(event.mobile);
    final target = mobile.length == 10 ? '91$mobile' : mobile;
    final message = buildEventWhatsAppMessage(event);
    final uri = Uri.parse(target.isEmpty
        ? 'https://wa.me/?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/$target?text=${Uri.encodeComponent(message)}');
    showCpSnack(context, 'Opening WhatsApp...');
    final launched = await launchUrl(uri,
        mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (!context.mounted) return;
    showCpSnack(context,
        launched ? 'Event info ready to share' : 'Unable to open WhatsApp');
  }

  Future<void> shareMenuOnWhatsApp(
      BuildContext context, AppEvent event, String message) async {
    final mobile = normalizeMobileText(event.mobile);
    final target = mobile.length == 10 ? '91$mobile' : mobile;
    final uri = Uri.parse(target.isEmpty
        ? 'https://wa.me/?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/$target?text=${Uri.encodeComponent(message)}');
    showCpSnack(context, 'Opening WhatsApp...');
    final launched = await launchUrl(uri,
        mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (!context.mounted) return;
    showCpSnack(
        context, launched ? 'Menu ready to share' : 'Unable to open WhatsApp');
  }

  String buildMenuWhatsAppMessage(AppEvent event) {
    return buildFormattedMenuShareMessage(event,
        businessProfile: businessProfile);
  }

  String buildEventWhatsAppMessage(AppEvent event) {
    final lines = buildFormattedMenuShareLines(event,
        businessProfile: businessProfile, includeFooter: false);

    if (event.notes.trim().isNotEmpty) {
      lines
        ..add('')
        ..add('📝 *NOTES*')
        ..add(event.notes.trim());
    }

    if (event.addOns.isNotEmpty) {
      lines
        ..add('')
        ..add('➕ *ADD-ONS*');
      for (final addOn in event.addOns) {
        final title = addOn['title']?.toString() ?? 'Add-on';
        final cost = (addOn['cost'] as num?)?.toInt() ?? 0;
        lines.add('• $title${cost > 0 ? ' | ${whatsAppMoney(cost)}' : ''}');
      }
    }

    if (event.employeeAssignments.isNotEmpty) {
      lines
        ..add('')
        ..add('👥 *TEAM*');
      for (final employee in event.employeeAssignments) {
        lines.add(
            '• ${employee.employeeName}${employee.designation.isEmpty ? '' : ' (${employee.designation})'}');
      }
    }

    final total = eventTotal(event);
    final paid = eventPaid(event);
    final balance = eventBalance(event);
    lines
      ..add('')
      ..add('💳 *PAYMENT SUMMARY*')
      ..add('Total: ${whatsAppMoney(total)}')
      ..add('Paid: ${whatsAppMoney(paid)}')
      ..add('Balance: ${whatsAppMoney(balance)}')
      ..add('')
      ..add(
          '🙏 Thank you for choosing *${businessDisplayName(businessProfile)}*');

    return lines.join('\n');
  }

  String oneLineService(Map<String, dynamic> service) {
    final name = service['name']?.toString() ?? 'Service';
    final quantity = service['quantity']?.toString() ?? '';
    final unit = service['unit']?.toString() ?? '';
    final price = (service['price'] as num?)?.toInt() ?? 0;
    final parts = <String>[];
    if (quantity.trim().isNotEmpty && quantity != '0') {
      parts.add('$quantity $unit'.trim());
    }
    if (price > 0) parts.add(whatsAppMoney(price));
    return parts.isEmpty ? name : '$name (${parts.join(', ')})';
  }

  String whatsAppMoney(int amount) =>
      money(amount).replaceFirst(RegExp(r'^\s*[^\d-]+'), 'Rs. ');

  @override
  Widget build(BuildContext context) {
    final primary = cpPrimary(context);
    final onVariant = cpOnVariant(context);
    final onSurface = cpOnSurface(context);
    final error = Theme.of(context).colorScheme.error;
    return ScreenFrame(
      topBar: TopBar(
        title: event?.name.isEmpty == false ? event!.name : 'Event Details',
        avatar: false,
        leading: IconButton(
            onPressed: onClose, icon: Icon(Icons.arrow_back, color: primary)),
        actions: [
          if (event != null)
            IconButton(
                onPressed: () => onEdit(event!),
                icon: Icon(Icons.edit, color: primary),
                tooltip: 'Edit event'),
          PopupMenuButton<EventScreenAction>(
            icon: Icon(Icons.more_vert, color: onVariant),
            color: cpCard(context),
            surfaceTintColor: Colors.transparent,
            tooltip: 'Event menu',
            onSelected: (action) => handleAction(context, action),
            itemBuilder: (context) => [
              for (final action in eventScreenActions) ...[
                if (action.value == EventScreenAction.deleteEvent)
                  const PopupMenuDivider(),
                PopupMenuItem<EventScreenAction>(
                  value: action.value,
                  child: Row(
                    children: [
                      Icon(action.icon,
                          color: action.destructive ? error : primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          action.label,
                          style: TextStyle(
                              color: action.destructive ? error : onSurface,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      children: event == null
          ? const [
              EmptyStateCard(
                  title: 'Select an event',
                  message:
                      'Open an event from the event list to view details, payments, invoices, and quotations.')
            ]
          : [
              EventDetailsContent(
                  event: event!,
                  events: events,
                  api: api,
                  employees: employees,
                  businessProfile: businessProfile,
                  onEditStep: onEditStep,
                  onAddEvent: onAddEvent,
                  onEventUpdated: onEventUpdated)
            ],
    );
  }
}

class EventDetailsContent extends StatefulWidget {
  const EventDetailsContent(
      {super.key,
      required this.event,
      required this.events,
      required this.api,
      required this.employees,
      required this.businessProfile,
      required this.onEditStep,
      required this.onAddEvent,
      required this.onEventUpdated});
  final AppEvent event;
  final List<AppEvent> events;
  final ApiService api;
  final List<Employee> employees;
  final BusinessProfile businessProfile;
  final void Function(AppEvent event, int step) onEditStep;
  final VoidCallback onAddEvent;
  final ValueChanged<AppEvent> onEventUpdated;

  @override
  State<EventDetailsContent> createState() => _EventDetailsContentState();
}

String buildFormattedMenuShareMessage(AppEvent event,
    {AppEventDate? onlyDate,
    BusinessProfile businessProfile = const BusinessProfile()}) {
  return buildFormattedMenuShareLines(event,
          onlyDate: onlyDate, businessProfile: businessProfile)
      .join('\n');
}

List<String> buildFormattedMenuShareLines(AppEvent event,
    {AppEventDate? onlyDate,
    BusinessProfile businessProfile = const BusinessProfile(),
    bool includeFooter = true}) {
  final businessName = businessDisplayName(businessProfile);
  final lines = <String>[
    '🍽 *$businessName – Event Details*',
    '',
  ];

  if (event.primaryClient.trim().isNotEmpty) {
    lines.add('👤 Client: ${event.primaryClient.trim()}');
  }
  if (event.mobile.trim().isNotEmpty) {
    lines.add('📞 Mobile: ${event.mobile.trim()}');
  }
  if (event.venue.trim().isNotEmpty) {
    lines.add('📍 Address: ${event.venue.trim()}');
  }

  final dates = onlyDate == null ? sortedEventDates(event.dates) : [onlyDate];
  if (dates.isEmpty) {
    lines
      ..add('📅 Date: ')
      ..add('⏰ Time: ')
      ..add('')
      ..add('----------------------------')
      ..add('🧺 *SERVICE OPTIONS*')
      ..add('—')
      ..add('')
      ..add('----------------------------')
      ..add('🍴 *MENU*')
      ..add('No menu configured.');
    if (includeFooter) {
      lines
        ..add('----------------------------')
        ..add('🙏 Thank you for choosing *$businessName*');
    }
    return lines;
  }

  for (final date in dates) {
    final slots = sortedVisibleMenuSlots(date.menuSlots);
    if (dates.length > 1) {
      lines.add('');
    }
    lines
      ..add('📅 Date: ${whatsAppDateLabel(date.date)}')
      ..add('⏰ Time: ${whatsAppTimeSummary(slots)}')
      ..add('')
      ..add('----------------------------')
      ..add('🧺 *SERVICE OPTIONS*');
    if (date.label.trim().isNotEmpty) {
      lines.add('_${date.label.trim()}_');
    }

    final serviceLines = whatsAppServiceLines(date, slots);
    if (serviceLines.isEmpty) {
      lines.add('—');
    } else {
      lines.addAll(serviceLines);
    }

    lines
      ..add('')
      ..add('----------------------------')
      ..add('🍴 *MENU*');

    if (slots.isEmpty) {
      lines.add('No menu configured.');
    } else {
      for (final slot in slots) {
        final itemNames = slot.menuItemIds
            .map((id) => menuItemById(id))
            .whereType<MenuMasterItem>()
            .map((item) => item.title)
            .toList();
        lines
          ..add('')
          ..add('🔹 ${slot.type}')
          ..add('👥 Members: ${slot.pax}')
          ..add('🍽 Items:');

        if (itemNames.isEmpty) {
          lines.add('• Menu items not selected');
        } else {
          for (final name in itemNames) {
            lines.add('• $name');
          }
        }
      }
    }
  }

  if (includeFooter) {
    lines
      ..add('----------------------------')
      ..add('🙏 Thank you for choosing *$businessName*');
  }
  return lines;
}

String menuShareOneLineService(Map<String, dynamic> service) {
  final name = service['name']?.toString() ?? 'Service';
  final quantity = service['quantity']?.toString() ?? '';
  final unit = service['unit']?.toString() ?? '';
  final price = (service['price'] as num?)?.toInt() ?? 0;
  final parts = <String>[];
  if (quantity.trim().isNotEmpty && quantity != '0') {
    parts.add('$quantity $unit'.trim());
  }
  if (price > 0) {
    parts.add(money(price).replaceFirst(RegExp(r'^\s*[^\d-]+'), 'Rs. '));
  }
  return parts.isEmpty ? name : '$name (${parts.join(', ')})';
}

String businessDisplayName(BusinessProfile businessProfile) {
  final name = businessProfile.businessName.trim();
  return name.isEmpty ? 'CaterPro' : name;
}

String whatsAppDateLabel(String isoDate) {
  final date = parseIsoDate(isoDate);
  if (date == null) return isoDate;
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day-$month-${date.year}';
}

String whatsAppTimeSummary(List<AppMenuSlot> slots) {
  final times = slots
      .where((slot) => slot.time.trim().isNotEmpty)
      .map((slot) => '${slot.type}: ${slot.time.trim()}')
      .toList();
  return times.join(' | ');
}

List<String> whatsAppServiceLines(
    AppEventDate date, List<AppMenuSlot> visibleSlots) {
  final lines = <String>[];
  for (final service in date.additionalServices) {
    lines.add('• ${menuShareOneLineService(service)}');
  }
  for (final slot in visibleSlots) {
    for (final service in slot.additionalServices) {
      lines.add('• ${slot.type}: ${menuShareOneLineService(service)}');
    }
  }
  return lines;
}

class _EventDetailsContentState extends State<EventDetailsContent> {
  int selectedTab = 0;
  static const tabs = ['Overview', 'Dates & Menus', 'Payments', 'Team'];
  static const tabIcons = [
    Icons.dashboard_outlined,
    Icons.restaurant_menu,
    Icons.account_balance_wallet_outlined,
    Icons.group_outlined
  ];

  Future<void> callClient(BuildContext context, String mobile) async {
    final clean = normalizeMobileText(mobile);
    if (clean.isEmpty) {
      showCpSnack(context, 'Client mobile number is not available');
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: clean),
        mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!launched) showCpSnack(context, 'Unable to start call');
  }

  Future<void> openClientWhatsApp(BuildContext context, String mobile) async {
    final clean = normalizeMobileText(mobile);
    if (clean.isEmpty) {
      showCpSnack(context, 'Client mobile number is not available');
      return;
    }
    final target = clean.length == 10 ? '91$clean' : clean;
    final launched = await launchUrl(Uri.parse('https://wa.me/$target'),
        mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (!context.mounted) return;
    if (!launched) showCpSnack(context, 'Unable to open WhatsApp');
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final scheme = Theme.of(context).colorScheme;
    final primary = cpPrimary(context);
    final onSurface = cpOnSurface(context);
    final onVariant = cpOnVariant(context);
    final outline = cpOutline(context);
    final total = eventTotal(event);
    final paid = eventPaid(event);
    final balance = eventBalance(event);
    final progressValue = paid + eventSettledDiscount(event);
    final progress = total == 0 ? 0.0 : (progressValue / total).clamp(0.0, 1.0);
    return Column(children: [
      CpCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Primary Contact',
                    style: TextStyle(
                        color: outline,
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
                Text(
                    event.primaryClient.isEmpty
                        ? event.mobile
                        : event.primaryClient,
                    style: TextStyle(
                        color: primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                Row(children: [
                  Flexible(
                    child: Text(event.mobile,
                        style: TextStyle(
                            color: onVariant, fontWeight: FontWeight.w700)),
                  ),
                  if (event.mobile.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Call client',
                        onPressed: () => callClient(context, event.mobile),
                        icon: Icon(Icons.call, size: 18, color: primary)),
                    IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'WhatsApp client',
                        onPressed: () =>
                            openClientWhatsApp(context, event.mobile),
                        icon: const WhatsAppIcon(size: 20)),
                  ]
                ])
              ])),
          if (eventIsIncomplete(event))
            const Pill('DRAFT',
                color: Cp.secondaryFixed, textColor: Color(0xff663e00))
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 18, runSpacing: 16, children: [
          InfoTile(Icons.calendar_today, 'Dates',
              event.dates.map((date) => date.date).join(', ')),
          InfoTile(Icons.location_on, 'Venue',
              event.venue.isEmpty ? 'Not set' : event.venue),
          InfoTile(Icons.restaurant_menu, 'Menu Members', 'Meal-wise',
              color: primary),
          InfoTile(Icons.pending_actions, 'Balance Due', money(balance),
              color: Cp.error)
        ]),
        const SizedBox(height: 18),
        Text('Payment Progress',
            style: TextStyle(color: onVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                color: scheme.primary,
                backgroundColor: scheme.surfaceContainerHighest)),
      ])),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final selected = index == selectedTab;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Tooltip(
                message: tabs[index],
                child: ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(tabIcons[index],
                      size: 18,
                      color: selected ? scheme.onPrimaryContainer : primary),
                  label: Text(tabs[index]),
                  selectedColor: scheme.primaryContainer,
                  backgroundColor: scheme.surfaceContainerLow,
                  side: BorderSide(
                      color: selected
                          ? scheme.primaryContainer
                          : scheme.outlineVariant),
                  labelStyle: TextStyle(
                      color: selected ? scheme.onPrimaryContainer : onSurface,
                      fontWeight: FontWeight.w800),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => selectedTab = index),
                ),
              ),
            );
          }),
        ),
      ),
      const SizedBox(height: 16),
      EventDetailsTabContent(
          tab: selectedTab,
          event: event,
          api: widget.api,
          events: widget.events,
          employees: widget.employees,
          businessProfile: widget.businessProfile,
          onEditStep: widget.onEditStep,
          onAddEvent: widget.onAddEvent,
          onEventUpdated: widget.onEventUpdated),
    ]);
  }
}

class EventDetailsTabContent extends StatelessWidget {
  const EventDetailsTabContent(
      {super.key,
      required this.tab,
      required this.event,
      required this.api,
      required this.events,
      required this.employees,
      required this.businessProfile,
      required this.onEditStep,
      required this.onAddEvent,
      required this.onEventUpdated});
  final int tab;
  final AppEvent event;
  final ApiService api;
  final List<AppEvent> events;
  final List<Employee> employees;
  final BusinessProfile businessProfile;
  final void Function(AppEvent event, int step) onEditStep;
  final VoidCallback onAddEvent;
  final ValueChanged<AppEvent> onEventUpdated;

  Future<void> shareMenuDateOnWhatsApp(
      BuildContext context, AppEvent event, String message) async {
    final mobile = normalizeMobileText(event.mobile);
    final target = mobile.length == 10 ? '91$mobile' : mobile;
    final uri = Uri.parse(target.isEmpty
        ? 'https://wa.me/?text=${Uri.encodeComponent(message)}'
        : 'https://wa.me/$target?text=${Uri.encodeComponent(message)}');
    showCpSnack(context, 'Opening WhatsApp...');
    final launched = await launchUrl(uri,
        mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (!context.mounted) return;
    showCpSnack(
        context, launched ? 'Menu ready to share' : 'Unable to open WhatsApp');
  }

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case 1:
        return event.dates.isEmpty
            ? const EmptyStateCard(
                title: 'No dates configured',
                message: 'Add event dates and menu types from the create flow.')
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () => onEditStep(event, 2),
                    icon: const Icon(Icons.edit_calendar),
                    label: const Text('Edit menus & members',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 12),
                ...event.dates.map((date) => EventDateMenuCard(
                    date: date,
                    onShareWhatsApp: () async {
                      await shareMenuDateOnWhatsApp(
                          context,
                          event,
                          buildFormattedMenuShareMessage(event,
                              onlyDate: date,
                              businessProfile: businessProfile));
                    },
                    onDownload: () async {
                      final uri = await api.documentUri(event.id, 'menu',
                          dateId: date.id);
                      if (context.mounted) {
                        showDownloadSnack(context, uri,
                            title: downloadTitleForEvent(event, 'menu',
                                dateId: date.id),
                            kind: 'menu',
                            successMessage: 'Menu download started',
                            failureMessage: 'Unable to start download');
                      }
                    }))
              ]);
      case 2:
        final total = eventTotal(event);
        final paid = eventPaid(event);
        final balance = eventBalance(event);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CpCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Payment Summary',
                        style: TextStyle(
                            color: Cp.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('Total: ${money(total)}'),
                    Text('Paid: ${money(paid)}'),
                    if (eventSettledDiscount(event) > 0)
                      Text(
                          'Settlement Discount: ${money(eventSettledDiscount(event))}'),
                    Text('Balance: ${money(balance)}',
                        style: TextStyle(
                            color: balance == 0 ? Cp.tertiary : Cp.error,
                            fontWeight: FontWeight.w800))
                  ])),
              if (event.payments.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...event.payments.map((payment) => CpCard(
                        child: Row(children: [
                      const Icon(Icons.payments, color: Cp.primary),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              '${money(payment.amount)} | ${payment.mode}\n${payment.date}${payment.reference.isEmpty ? '' : ' | ${payment.reference}'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800))),
                      if (payment.settled)
                        const Pill('Settled',
                            color: Cp.tertiaryFixed,
                            textColor: Color(0xff00210c))
                    ]))),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: balance == 0
                      ? null
                      : () => showEventRecordPaymentSheet(context,
                          event: event, api: api, onSaved: onEventUpdated),
                  style: FilledButton.styleFrom(
                      backgroundColor: Cp.secondaryContainer,
                      foregroundColor: const Color(0xff694000),
                      disabledBackgroundColor: Cp.surfaceHigh,
                      disabledForegroundColor: Cp.onVariant),
                  icon:
                      Icon(balance == 0 ? Icons.check_circle : Icons.payments),
                  label: Text(
                      balance == 0 ? 'Payment Complete' : 'Record Payment',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ]);
      case 3:
        return EventTeamSection(
            event: event,
            api: api,
            employees: employees,
            onEventUpdated: onEventUpdated);
      default:
        return MaterialDocumentsSection(
            event: event, api: api, onEventUpdated: onEventUpdated);
    }
  }
}

class EventTeamSection extends StatefulWidget {
  const EventTeamSection(
      {super.key,
      required this.event,
      required this.api,
      required this.employees,
      required this.onEventUpdated});
  final AppEvent event;
  final ApiService api;
  final List<Employee> employees;
  final ValueChanged<AppEvent> onEventUpdated;

  @override
  State<EventTeamSection> createState() => _EventTeamSectionState();
}

class _EventTeamSectionState extends State<EventTeamSection> {
  late Future<List<AttendanceRecord>> attendanceFuture;
  List<AttendanceRecord> attendanceRecords = [];

  @override
  void initState() {
    super.initState();
    attendanceFuture = loadAttendance();
  }

  @override
  void didUpdateWidget(covariant EventTeamSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id) {
      attendanceRecords = [];
      attendanceFuture = loadAttendance();
    }
  }

  void reloadAttendance() {
    setState(() {
      attendanceFuture = loadAttendance();
    });
  }

  Future<List<AttendanceRecord>> loadAttendance() async {
    final records = await widget.api.getAttendance(eventId: widget.event.id);
    if (mounted) attendanceRecords = records;
    return records;
  }

  void upsertLocalAttendance(AttendanceRecord record) {
    final next = [...attendanceRecords];
    final index = next.indexWhere((item) =>
        item.employeeId == record.employeeId &&
        item.eventId == record.eventId &&
        item.date == record.date);
    if (index == -1) {
      next.add(record);
    } else {
      next[index] = record;
    }
    setState(() {
      attendanceRecords = next;
      attendanceFuture = Future.value(next);
    });
  }

  void markAssignedEmployeesPresentLocally(AppEvent event) {
    final next = [...attendanceRecords];
    for (final assignment in event.employeeAssignments) {
      for (final date in event.dates) {
        if (date.date.isEmpty) continue;
        final exists = next.any((record) =>
            record.employeeId == assignment.employeeId &&
            record.eventId == event.id &&
            record.date == date.date);
        if (exists) continue;
        next.add(AttendanceRecord(
            id: 'local-${event.id}-${assignment.employeeId}-${date.date}',
            employeeId: assignment.employeeId,
            employeeName: assignment.employeeName,
            eventId: event.id,
            eventName: event.name,
            date: date.date,
            status: 'present',
            hours: 8,
            payPerDay: assignment.payPerDay,
            payPerHour: assignment.payPerHour));
      }
    }
    setState(() {
      attendanceRecords = next;
      attendanceFuture = Future.value(next);
    });
  }

  Future<void> assignEmployees() async {
    final selected =
        widget.event.employeeAssignments.map((item) => item.employeeId).toSet();
    await showDialog<void>(
      context: context,
      builder: (context) {
        final draft = selected.toSet();
        var saving = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Assign Employees'),
            content: SizedBox(
              width: 520,
              child: widget.employees.isEmpty
                  ? const Text('Add employees in Settings > Employees first.')
                  : SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.employees.map((employee) {
                            final checked = draft.contains(employee.id);
                            return CheckboxListTile(
                              value: checked,
                              title: Text(employee.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800)),
                              subtitle: Text(
                                  '${employee.designation} | ${money(employee.payPerDay)}/day | ${money(employee.payPerHour)}/hr'),
                              onChanged: (_) => setDialogState(() => checked
                                  ? draft.remove(employee.id)
                                  : draft.add(employee.id)),
                            );
                          }).toList()),
                    ),
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: widget.employees.isEmpty || saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        try {
                          final assignments = widget.employees
                              .where((employee) => draft.contains(employee.id))
                              .map((employee) => EventEmployeeAssignment(
                                  employeeId: employee.id,
                                  employeeName: employee.name,
                                  mobile: employee.mobile,
                                  designation: employee.designation,
                                  payPerDay: employee.payPerDay,
                                  payPerHour: employee.payPerHour))
                              .toList();
                          final saved = await widget.api
                              .saveEventEmployeeAssignments(
                                  widget.event.id, assignments);
                          if (mounted) {
                            widget.onEventUpdated(saved);
                            markAssignedEmployeesPresentLocally(saved);
                            unawaited(loadAttendance().then((records) {
                              if (mounted) {
                                setState(() =>
                                    attendanceFuture = Future.value(records));
                              }
                            }));
                            Navigator.of(this.context).pop();
                            showCpSnack(this.context,
                                'Employees assigned and marked present');
                          }
                        } catch (error) {
                          setDialogState(() => saving = false);
                          if (mounted) {
                            showCpSnack(
                                this.context,
                                error
                                    .toString()
                                    .replaceFirst('Exception: ', ''));
                          }
                        }
                      },
                child: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> markAttendance(
      Employee employee, String date, AttendanceRecord? existing) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AttendanceEditorDialog(
        employee: employee,
        event: widget.event,
        date: date,
        existing: existing,
        onSave: (record) async {
          try {
            final saved = await widget.api.saveAttendance(record);
            upsertLocalAttendance(saved);
          } catch (error) {
            if (mounted) {
              showCpSnack(this.context,
                  error.toString().replaceFirst('Exception: ', ''));
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assigned =
        widget.event.employeeAssignments.map(Employee.fromAssignment).toList();
    final dates = widget.event.dates
        .map((date) => date.date)
        .where((date) => date.isNotEmpty)
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(
            child: Text('Assigned Employees',
                style: TextStyle(
                    color: Cp.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900))),
        OutlinedButton.icon(
            onPressed: assignEmployees,
            icon: const Icon(Icons.group_add),
            label: const Text('Assign')),
      ]),
      const SizedBox(height: 10),
      if (assigned.isEmpty)
        const EmptyStateCard(
            title: 'No employees assigned',
            message:
                'Assign employees to this event to track attendance, salary, and reports later.')
      else
        FutureBuilder<List<AttendanceRecord>>(
          future: attendanceFuture,
          builder: (context, snapshot) {
            final records = snapshot.data ?? attendanceRecords;
            AttendanceRecord? findRecord(Employee employee, String date) =>
                records
                    .where((record) =>
                        record.employeeId == employee.id && record.date == date)
                    .firstOrNull;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...assigned.map((employee) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CpCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  CircleAvatar(
                                      backgroundColor: Cp.primaryFixed,
                                      child: Text(
                                          employee.name.isEmpty
                                              ? 'E'
                                              : employee.name[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: Cp.primary,
                                              fontWeight: FontWeight.w900))),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(employee.name,
                                            style: const TextStyle(
                                                color: Cp.primary,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w900)),
                                        Text(
                                            '${employee.designation} | ${money(employee.payPerDay)}/day | ${money(employee.payPerHour)}/hr',
                                            style: const TextStyle(
                                                color: Cp.onVariant,
                                                fontWeight: FontWeight.w700)),
                                      ])),
                                ]),
                                const SizedBox(height: 12),
                                if (dates.isEmpty)
                                  const Text(
                                      'Add event dates before marking attendance.',
                                      style: TextStyle(
                                          color: Cp.onVariant,
                                          fontWeight: FontWeight.w700))
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: dates.map((date) {
                                      final record = findRecord(employee, date);
                                      final icon = switch (record?.status) {
                                        'present' => Icons.check_circle,
                                        'absent' => Icons.cancel,
                                        'partial' => Icons.schedule,
                                        _ => Icons.radio_button_unchecked,
                                      };
                                      final iconColor =
                                          switch (record?.status) {
                                        'present' => Cp.tertiary,
                                        'absent' => Cp.error,
                                        'partial' => Cp.secondary,
                                        _ => Cp.outline,
                                      };
                                      final label = record == null
                                          ? 'Mark ${readableDateLabel(date)}'
                                          : '${readableDateLabel(date)} | ${record.status == 'present' ? 'Present full day' : record.status}${record.status == 'partial' ? ' ${record.hours}h' : ''}';
                                      return ActionChip(
                                        avatar: Icon(icon,
                                            size: 18, color: iconColor),
                                        label: Text(label),
                                        onPressed: () => markAttendance(
                                            employee, date, record),
                                      );
                                    }).toList(),
                                  ),
                              ]),
                        ),
                      )),
                ]);
          },
        ),
    ]);
  }
}

class AttendanceEditorDialog extends StatefulWidget {
  const AttendanceEditorDialog(
      {super.key,
      required this.employee,
      required this.event,
      required this.date,
      this.existing,
      required this.onSave});
  final Employee employee;
  final AppEvent event;
  final String date;
  final AttendanceRecord? existing;
  final Future<void> Function(AttendanceRecord record) onSave;

  @override
  State<AttendanceEditorDialog> createState() => _AttendanceEditorDialogState();
}

class _AttendanceEditorDialogState extends State<AttendanceEditorDialog> {
  late String status = widget.existing?.status ?? 'present';
  late final hours = TextEditingController(
      text: widget.existing?.hours == null || widget.existing!.hours == 0
          ? ''
          : '${widget.existing!.hours}');
  bool saving = false;

  @override
  void dispose() {
    hours.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final parsedHours = status == 'partial'
        ? double.tryParse(hours.text.trim()) ?? 0
        : status == 'present'
            ? 8.0
            : 0.0;
    if (status == 'partial' && parsedHours <= 0) {
      showCpSnack(context, 'Mention hours for partial attendance');
      return;
    }
    final record = AttendanceRecord(
      id: widget.existing?.id ?? '',
      employeeId: widget.employee.id,
      employeeName: widget.employee.name,
      eventId: widget.event.id,
      eventName: widget.event.name,
      date: widget.date,
      status: status,
      hours: parsedHours,
      payPerDay: widget.employee.payPerDay,
      payPerHour: widget.employee.payPerHour,
    );
    Navigator.pop(context);
    unawaited(widget.onSave(record));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Change Attendance'),
            const SizedBox(height: 6),
            Text(
              '${widget.employee.name} | ${readableDateLabel(widget.date)}',
              style: const TextStyle(
                  color: Cp.onVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'present',
                  icon: Icon(Icons.check_circle_outline),
                  label: Text('Present')),
              ButtonSegment(
                  value: 'absent',
                  icon: Icon(Icons.cancel_outlined),
                  label: Text('Absent')),
              ButtonSegment(
                  value: 'partial',
                  icon: Icon(Icons.schedule),
                  label: Text('Partial')),
            ],
            selected: {status},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => status = value.first),
          ),
          if (status == 'partial') ...[
            const SizedBox(height: 12),
            TextField(
                controller: hours,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Hours worked')),
          ],
        ]),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving...' : 'Save')),
        ],
      );
}

class MaterialDocumentsSection extends StatelessWidget {
  const MaterialDocumentsSection(
      {super.key,
      required this.event,
      required this.api,
      required this.onEventUpdated});
  final AppEvent event;
  final ApiService api;
  final ValueChanged<AppEvent> onEventUpdated;

  Future<void> openEditor(BuildContext context, String type,
      {EventMaterialDocument? document}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => MaterialDocumentDialog(
          event: event,
          api: api,
          type: type,
          document: document,
          onSaved: onEventUpdated,
        ),
      ),
    );
  }

  Future<void> download(
      BuildContext context, EventMaterialDocument document) async {
    showCpSnack(context, 'Downloading material PDF...');
    final uri = await api.materialDocumentPdfUri(event.id, document.id);
    if (context.mounted) {
      showDownloadSnack(context, uri,
          title:
              '${document.title.isEmpty ? document.typeLabel : document.title}.pdf',
          kind: 'pdf',
          successMessage: 'Material PDF download started',
          failureMessage: 'Unable to start download');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = cpPrimary(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CpCard(
          color: scheme.primaryContainer,
          child: Text(
              'Event Notes\n${event.notes.isEmpty ? 'No notes added.' : event.notes}',
              style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  height: 1.45,
                  fontWeight: FontWeight.w700))),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
            child: Text('Event Material Documents',
                style: TextStyle(
                    color: primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900))),
        Pill('${event.materialDocuments.length} lists'),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'Create material document',
          icon: const Icon(Icons.add_circle, color: Cp.toolbarIcon),
          onSelected: (type) => openEditor(context, type),
          itemBuilder: (context) => const [
            PopupMenuItem(
                value: 'raw',
                child: Row(children: [
                  Icon(Icons.inventory_2, color: Cp.primary),
                  SizedBox(width: 10),
                  Text('Raw Material List')
                ])),
            PopupMenuItem(
                value: 'produce',
                child: Row(children: [
                  Icon(Icons.eco, color: Cp.primary),
                  SizedBox(width: 10),
                  Text('Vegetables & Fruits List')
                ])),
            PopupMenuItem(
                value: 'vessels',
                child: Row(children: [
                  Icon(Icons.restaurant, color: Cp.primary),
                  SizedBox(width: 10),
                  Text('Vessels & Utensils List')
                ])),
          ],
        ),
      ]),
      const SizedBox(height: 10),
      if (event.materialDocuments.isEmpty)
        const EmptyStateCard(
            title: 'No material documents',
            message:
                'Create raw material, vegetables, or fruits lists for this event.')
      else
        ...event.materialDocuments.map((document) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CpCard(
                onTap: () =>
                    openEditor(context, document.type, document: document),
                child: Row(children: [
                  Icon(
                      document.type == 'produce'
                          ? Icons.eco
                          : document.type == 'vessels'
                              ? Icons.restaurant
                              : Icons.inventory_2,
                      color: primary),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            document.title.isEmpty
                                ? document.typeLabel
                                : document.title,
                            style: const TextStyle(
                                color: Cp.primary,
                                fontWeight: FontWeight.w900)),
                        Text(
                            '${document.typeLabel} | ${document.items.length} items',
                            style: const TextStyle(
                                color: Cp.onVariant,
                                fontWeight: FontWeight.w700)),
                      ])),
                  IconButton(
                      onPressed: () => download(context, document),
                      icon: const Icon(Icons.picture_as_pdf, color: Cp.primary),
                      tooltip: 'Download PDF'),
                ]),
              ),
            )),
    ]);
  }
}

class MaterialDocumentDialog extends StatefulWidget {
  const MaterialDocumentDialog(
      {super.key,
      required this.event,
      required this.api,
      required this.type,
      this.document,
      required this.onSaved});
  final AppEvent event;
  final ApiService api;
  final String type;
  final EventMaterialDocument? document;
  final ValueChanged<AppEvent> onSaved;

  @override
  State<MaterialDocumentDialog> createState() => _MaterialDocumentDialogState();
}

class _MaterialDocumentDialogState extends State<MaterialDocumentDialog> {
  final titleController = TextEditingController();
  final queryController = TextEditingController();
  final items = <RawMaterialItem>[];
  final quantityControllers = <String, TextEditingController>{};
  final selectedItemIds = <String>{};
  bool loading = true;
  bool saving = false;
  String query = '';
  String? error;

  String get typeLabel => widget.type == 'produce'
      ? 'Vegetables & Fruits'
      : widget.type == 'vessels'
          ? 'Vessels & Utensils'
          : 'Raw Materials';
  bool get isVessels => widget.type == 'vessels';

  @override
  void initState() {
    super.initState();
    final count = widget.event.materialDocuments
            .where((document) => document.type == widget.type)
            .length +
        1;
    titleController.text = widget.document?.title ?? '$typeLabel List $count';
    loadCatalog();
  }

  @override
  void dispose() {
    titleController.dispose();
    queryController.dispose();
    for (final controller in quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadCatalog() async {
    try {
      final loaded = widget.type == 'produce'
          ? await widget.api.getProduceItems()
          : widget.type == 'vessels'
              ? await widget.api.getVesselItems()
              : await widget.api.getRawMaterials();
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(loaded);
        for (final item in items) {
          quantityControllers[item.id] = TextEditingController();
        }
        for (final line
            in widget.document?.items ?? const <EventMaterialLine>[]) {
          final value = [line.quantity, line.unit]
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .join(' ');
          quantityControllers[line.itemId]?.text = value;
          if (isVessels) selectedItemIds.add(line.itemId);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<RawMaterialItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    final filtered = items.where((item) {
      final text = '${item.id} ${item.name} ${item.category}'.toLowerCase();
      return normalized.isEmpty || text.contains(normalized);
    }).toList();
    filtered.sort((a, b) {
      final aSelected = selectedItemIds.contains(a.id) ||
              (quantityControllers[a.id]?.text.trim().isNotEmpty ?? false)
          ? 0
          : 1;
      final bSelected = selectedItemIds.contains(b.id) ||
              (quantityControllers[b.id]?.text.trim().isNotEmpty ?? false)
          ? 0
          : 1;
      if (aSelected != bSelected) return aSelected.compareTo(bSelected);
      return a.name.compareTo(b.name);
    });
    return filtered;
  }

  Future<void> save() async {
    final lines = <EventMaterialLine>[];
    for (final item in items) {
      final quantity = quantityControllers[item.id]?.text.trim() ?? '';
      final selected = selectedItemIds.contains(item.id);
      if (quantity.isEmpty && !selected) continue;
      lines.add(EventMaterialLine(
          itemId: item.id,
          name: item.name,
          category: item.category,
          quantity: quantity,
          unit: ''));
    }
    if (lines.isEmpty) {
      setState(() => error = isVessels
          ? 'Select or enter quantity for at least one item.'
          : 'Enter quantity for at least one item.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    showCpSnack(context, 'Saving $typeLabel list...');
    try {
      final savedEvent = await widget.api.saveMaterialDocument(
          widget.event.id,
          EventMaterialDocument(
              id: widget.document?.id ?? '',
              type: widget.type,
              title: titleController.text.trim(),
              items: lines));
      widget.onSaved(savedEvent);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: cpSurface(context),
        body: Column(
          children: [
            TopBar(
              title: widget.document == null
                  ? 'Create $typeLabel List'
                  : 'Edit $typeLabel List',
              avatar: false,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Cp.primary),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  EditableInlineField(
                      label: 'Document Title', controller: titleController),
                  TextField(
                    controller: queryController,
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search items',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onChanged: (value) => setState(() => query = value),
                  ),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(error!,
                            style: const TextStyle(
                                color: Cp.error, fontWeight: FontWeight.w800))),
                  const SizedBox(height: 10),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                          child: CircularProgressIndicator(color: Cp.primary)),
                    )
                  else
                    ...visibleItems.map(materialItemTile),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: saving ? null : save,
                style: FilledButton.styleFrom(
                    backgroundColor: Cp.primaryContainer),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(saving ? 'Saving...' : 'Save List',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ),
      );

  Widget materialItemTile(RawMaterialItem item) {
    final selected = selectedItemIds.contains(item.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: cpAdaptSurfaceColor(context, Cp.card),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: cpOutlineVariant(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Row(children: [
            if (isVessels)
              Checkbox(
                value: selected,
                visualDensity: VisualDensity.compact,
                onChanged: (value) => setState(() {
                  if (value == true) {
                    selectedItemIds.add(item.id);
                  } else {
                    selectedItemIds.remove(item.id);
                  }
                }),
              ),
            Expanded(
              child: Text(item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Cp.primary, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 118,
              child: TextField(
                controller: quantityControllers[item.id],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: isVessels ? 'Qty' : 'Qty',
                  hintText: isVessels ? '10' : '1kg',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                ),
                onChanged: (value) {
                  if (isVessels && value.trim().isNotEmpty) {
                    selectedItemIds.add(item.id);
                  }
                  setState(() {});
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class EventDateMenuCard extends StatelessWidget {
  const EventDateMenuCard(
      {super.key,
      required this.date,
      required this.onShareWhatsApp,
      required this.onDownload});
  final AppEventDate date;
  final VoidCallback onShareWhatsApp;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        child: Row(
          children: [
            Container(
              width: 54,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(date.date.split('-').skip(1).join('\n'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                      height: 1.1)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(date.label.isEmpty ? date.date : date.label,
                      style: TextStyle(
                          color: cpPrimary(context),
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                      sortedVisibleMenuSlots(date.menuSlots).isEmpty
                          ? 'No menu slots'
                          : sortedVisibleMenuSlots(date.menuSlots)
                              .map((slot) =>
                                  '${slot.type} | ${slot.pax} Members | ${money(slot.pricePerPax)}/member')
                              .join('\n'),
                      style: TextStyle(
                          color: cpOnVariant(context),
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                onPressed: onShareWhatsApp,
                icon: const WhatsAppIcon(size: 24),
                tooltip: 'Share menu on WhatsApp',
              ),
              IconButton(
                onPressed: onDownload,
                icon: Icon(Icons.picture_as_pdf, color: cpPrimary(context)),
                tooltip: 'Download menu PDF',
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class DocumentRow extends StatelessWidget {
  const DocumentRow({super.key, required this.title, required this.subtitle});
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
            child: Row(children: [
          const Icon(Icons.description, color: Cp.primary),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(subtitle, style: const TextStyle(color: Cp.onVariant))
              ])),
          const Icon(Icons.download, color: Cp.primary)
        ])),
      );
}

class InfoTile extends StatelessWidget {
  const InfoTile(this.icon, this.label, this.value,
      {super.key, this.color = Cp.primary});
  final IconData icon;
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final actualColor = color == Cp.error
        ? Theme.of(context).colorScheme.error
        : cpAdaptTextColor(context, color);
    return SizedBox(
        width: 150,
        child: Row(children: [
          Icon(icon, color: actualColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: cpOutline(context),
                        fontWeight: FontWeight.w900)),
                Text(value,
                    style: TextStyle(
                        color: color == Cp.error
                            ? actualColor
                            : cpOnSurface(context),
                        fontWeight: FontWeight.w800))
              ]))
        ]));
  }
}
