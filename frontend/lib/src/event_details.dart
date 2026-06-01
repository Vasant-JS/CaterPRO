part of '../main.dart';

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen(
      {super.key,
      required this.event,
      required this.api,
      required this.employees,
      required this.onEdit,
      required this.onEventUpdated,
      required this.onClose});
  final AppEvent? event;
  final ApiService api;
  final List<Employee> employees;
  final ValueChanged<AppEvent> onEdit;
  final ValueChanged<AppEvent> onEventUpdated;
  final VoidCallback onClose;

  Future<void> handleAction(
      BuildContext context, EventScreenAction action) async {
    final selectedEvent = event;
    if (selectedEvent == null) return;
    switch (action) {
      case EventScreenAction.assignEmployees:
        showCpSnack(context, 'Open the Team tab, then tap Assign.');
        break;
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
      case EventScreenAction.shareMenu:
        await showMenuShareSheet(context, selectedEvent);
        break;
      case EventScreenAction.deleteEvent:
        if (await confirmEventAction(context, 'Delete Event?',
            'This will remove this event and all linked dates, menus, payments, and documents.')) {
          if (!context.mounted) return;
          showCpSnack(context, 'Event deleted');
          onClose();
        }
        break;
      case EventScreenAction.deleteDate:
        if (await confirmEventAction(context, 'Delete Date?',
            'This will remove the selected event date and its menus.')) {
          if (!context.mounted) return;
          showCpSnack(context, 'Selected date deleted');
        }
        break;
      case EventScreenAction.deleteMenu:
        if (await confirmEventAction(context, 'Delete Menu?',
            'This will remove the selected menu configuration for this event.')) {
          if (!context.mounted) return;
          showCpSnack(context, 'Selected menu deleted');
        }
        break;
    }
  }

  Future<void> downloadDocument(
      BuildContext context, AppEvent event, String type,
      {String? dateId}) async {
    try {
      final uri = await api.documentUri(event.id, type, dateId: dateId);
      final launched = await launchUrl(uri,
          mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      if (!context.mounted) return;
      final label = switch (type) {
        'invoice' => 'Invoice',
        'quotation' => 'Quotation',
        'menu' => 'Menu',
        'all-menus' => 'All days menu',
        _ => 'Document',
      };
      showCpSnack(context,
          launched ? '$label download started' : 'Unable to start download');
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
      final message = 'CaterPro menu for ${event.name}: $link';
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                              color: Cp.outlineVariant,
                              borderRadius: BorderRadius.circular(99)))),
                  const Text('Share Menu',
                      style: TextStyle(
                          color: Cp.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  Text(event.name,
                      style: const TextStyle(
                          color: Cp.onVariant, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  ShareMenuTile(
                    icon: Icons.chat,
                    label: 'WhatsApp',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await launchUrl(
                          Uri.parse(
                              'https://wa.me/?text=${Uri.encodeComponent(message)}'),
                          mode: LaunchMode.externalApplication,
                          webOnlyWindowName: '_blank');
                    },
                  ),
                  ShareMenuTile(
                    icon: Icons.email,
                    label: 'Email',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await launchUrl(
                          Uri(scheme: 'mailto', queryParameters: {
                            'subject': 'Menu - ${event.name}',
                            'body': message
                          }),
                          mode: LaunchMode.externalApplication);
                    },
                  ),
                  ShareMenuTile(
                    icon: Icons.sms,
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
                    icon: Icons.link,
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
                    icon: Icons.picture_as_pdf,
                    label: 'Download PDF',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication,
                          webOnlyWindowName: '_blank');
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

  @override
  Widget build(BuildContext context) => ScreenFrame(
        topBar: TopBar(
          title: event?.name.isEmpty == false ? event!.name : 'Event Details',
          avatar: false,
          leading: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.arrow_back, color: Cp.primary)),
          actions: [
            if (event != null)
              IconButton(
                  onPressed: () => onEdit(event!),
                  icon: const Icon(Icons.edit, color: Cp.primary),
                  tooltip: 'Edit event'),
            PopupMenuButton<EventScreenAction>(
              icon: const Icon(Icons.more_vert, color: Cp.onVariant),
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
                            color: action.destructive ? Cp.error : Cp.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            action.label,
                            style: TextStyle(
                                color: action.destructive
                                    ? Cp.error
                                    : Cp.onSurface,
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
                    api: api,
                    employees: employees,
                    onEventUpdated: onEventUpdated)
              ],
      );
}

class EventDetailsContent extends StatefulWidget {
  const EventDetailsContent(
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
  State<EventDetailsContent> createState() => _EventDetailsContentState();
}

class _EventDetailsContentState extends State<EventDetailsContent> {
  int selectedTab = 0;
  static const tabs = ['Overview', 'Dates & Menus', 'Payments', 'Team'];
  static const tabIcons = [
    Icons.notes,
    Icons.restaurant_menu,
    Icons.payments,
    Icons.groups
  ];

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
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
                const Text('Primary Contact',
                    style: TextStyle(
                        color: Cp.outline,
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
                Text(
                    event.primaryClient.isEmpty
                        ? event.mobile
                        : event.primaryClient,
                    style: const TextStyle(
                        color: Cp.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                Text(event.mobile,
                    style: const TextStyle(
                        color: Cp.onVariant, fontWeight: FontWeight.w700))
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
          const InfoTile(Icons.restaurant_menu, 'Menu Pax', 'Meal-wise'),
          InfoTile(Icons.pending_actions, 'Balance Due', money(balance),
              color: Cp.error)
        ]),
        const SizedBox(height: 18),
        const Text('Payment Progress',
            style: TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                color: Cp.primaryContainer,
                backgroundColor: Cp.surfaceHigh)),
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
                  avatar: Icon(tabIcons[index],
                      size: 18, color: selected ? Colors.white : Cp.primary),
                  label: selected ? Text(tabs[index]) : const SizedBox.shrink(),
                  selectedColor: Cp.primaryContainer,
                  labelStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
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
          employees: widget.employees,
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
      required this.employees,
      required this.onEventUpdated});
  final int tab;
  final AppEvent event;
  final ApiService api;
  final List<Employee> employees;
  final ValueChanged<AppEvent> onEventUpdated;

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case 1:
        return event.dates.isEmpty
            ? const EmptyStateCard(
                title: 'No dates configured',
                message: 'Add event dates and menu types from the create flow.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: event.dates
                    .map((date) => EventDateMenuCard(
                        date: date,
                        onDownload: () async {
                          final uri = await api.documentUri(event.id, 'menu',
                              dateId: date.id);
                          if (context.mounted) {
                            final launched = await launchUrl(uri,
                                mode: LaunchMode.externalApplication,
                                webOnlyWindowName: '_blank');
                            if (context.mounted) {
                              showCpSnack(
                                  context,
                                  launched
                                      ? 'Menu download started'
                                      : 'Unable to start download');
                            }
                          }
                        }))
                    .toList());
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
                              '${money(payment.amount)} • ${payment.mode}\n${payment.date}${payment.reference.isEmpty ? '' : ' • ${payment.reference}'}',
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

  @override
  void initState() {
    super.initState();
    attendanceFuture = widget.api.getAttendance(eventId: widget.event.id);
  }

  void reloadAttendance() {
    setState(() {
      attendanceFuture = widget.api.getAttendance(eventId: widget.event.id);
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
                                  '${employee.designation} • ${money(employee.payPerDay)}/day • ${money(employee.payPerHour)}/hr'),
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
                            reloadAttendance();
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
            await widget.api.saveAttendance(record);
            reloadAttendance();
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
            final records = snapshot.data ?? const <AttendanceRecord>[];
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
                                            '${employee.designation} • ${money(employee.payPerDay)}/day • ${money(employee.payPerHour)}/hr',
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
                                          : '${readableDateLabel(date)} • ${record.status == 'present' ? 'Present full day' : record.status}${record.status == 'partial' ? ' ${record.hours}h' : ''}';
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
              '${widget.employee.name} • ${readableDateLabel(widget.date)}',
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
    await showDialog<void>(
      context: context,
      builder: (context) => MaterialDocumentDialog(
          event: event,
          api: api,
          type: type,
          document: document,
          onSaved: onEventUpdated),
    );
  }

  Future<void> download(
      BuildContext context, EventMaterialDocument document) async {
    final uri = await api.materialDocumentPdfUri(event.id, document.id);
    final launched = await launchUrl(uri,
        mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (context.mounted) {
      showCpSnack(
          context,
          launched
              ? 'Material PDF download started'
              : 'Unable to start download');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CpCard(
          color: Cp.primaryContainer,
          child: Text(
              'Event Notes\n${event.notes.isEmpty ? 'No notes added.' : event.notes}',
              style: const TextStyle(
                  color: Colors.white,
                  height: 1.45,
                  fontWeight: FontWeight.w700))),
      const SizedBox(height: 14),
      Row(children: [
        const Expanded(
            child: Text('Event Material Documents',
                style: TextStyle(
                    color: Cp.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900))),
        Pill('${event.materialDocuments.length} lists'),
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
                          : Icons.inventory_2,
                      color: Cp.primary),
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
                            '${document.typeLabel} • ${document.items.length} items',
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
      const SizedBox(height: 6),
      Wrap(spacing: 10, runSpacing: 10, children: [
        OutlinedButton.icon(
            onPressed: () => openEditor(context, 'raw'),
            icon: const Icon(Icons.inventory_2),
            label: const Text('Create Raw Material List')),
        OutlinedButton.icon(
            onPressed: () => openEditor(context, 'produce'),
            icon: const Icon(Icons.eco),
            label: const Text('Create Vegetables & Fruits List')),
      ]),
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
  final unitControllers = <String, TextEditingController>{};
  bool loading = true;
  bool saving = false;
  String query = '';
  String? error;

  String get typeLabel =>
      widget.type == 'produce' ? 'Vegetables & Fruits' : 'Raw Materials';

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
    for (final controller in unitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadCatalog() async {
    try {
      final loaded = widget.type == 'produce'
          ? await widget.api.getProduceItems()
          : await widget.api.getRawMaterials();
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(loaded);
        for (final item in items) {
          quantityControllers[item.id] = TextEditingController();
          unitControllers[item.id] = TextEditingController(text: item.unit);
        }
        for (final line
            in widget.document?.items ?? const <EventMaterialLine>[]) {
          quantityControllers[line.itemId]?.text = line.quantity;
          unitControllers[line.itemId]?.text = line.unit;
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
      final aSelected =
          (quantityControllers[a.id]?.text.trim().isNotEmpty ?? false) ? 0 : 1;
      final bSelected =
          (quantityControllers[b.id]?.text.trim().isNotEmpty ?? false) ? 0 : 1;
      if (aSelected != bSelected) return aSelected.compareTo(bSelected);
      return a.name.compareTo(b.name);
    });
    return filtered;
  }

  Future<void> save() async {
    final lines = <EventMaterialLine>[];
    for (final item in items) {
      final quantity = quantityControllers[item.id]?.text.trim() ?? '';
      if (quantity.isEmpty) continue;
      lines.add(EventMaterialLine(
          itemId: item.id,
          name: item.name,
          category: item.category,
          quantity: quantity,
          unit: unitControllers[item.id]?.text.trim() ?? item.unit));
    }
    if (lines.isEmpty) {
      setState(() => error = 'Enter quantity/count for at least one item.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
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
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        backgroundColor: Cp.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: 820,
              maxHeight: MediaQuery.of(context).size.height * .86),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                            widget.document == null
                                ? 'Create $typeLabel List'
                                : 'Edit $typeLabel List',
                            style: const TextStyle(
                                color: Cp.primary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900))),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close))
                  ]),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 12),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(color: Cp.primary))
                        : ListView.separated(
                            itemCount: visibleItems.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = visibleItems[index];
                              return CpCard(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  Expanded(
                                      flex: 3,
                                      child: Text(item.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Cp.primary))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: TextField(
                                          controller:
                                              quantityControllers[item.id],
                                          decoration: const InputDecoration(
                                              labelText: 'Count/Qty',
                                              isDense: true),
                                          onChanged: (_) => setState(() {}))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: TextField(
                                          controller: unitControllers[item.id],
                                          decoration: const InputDecoration(
                                              labelText: 'Unit',
                                              isDense: true))),
                                ]),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900)))),
                ]),
          ),
        ),
      );
}

class EventDateMenuCard extends StatelessWidget {
  const EventDateMenuCard(
      {super.key, required this.date, required this.onDownload});
  final AppEventDate date;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          child: Row(
            children: [
              Container(
                width: 54,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Cp.primaryFixed,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(date.date.split('-').skip(1).join('\n'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Cp.primary,
                        fontWeight: FontWeight.w900,
                        height: 1.1)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(date.label.isEmpty ? date.date : date.label,
                        style: const TextStyle(
                            color: Cp.primary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                        date.menuSlots.isEmpty
                            ? 'No menu slots'
                            : date.menuSlots
                                .map((slot) =>
                                    '${slot.type} • ${slot.pax} pax • ${money(slot.pricePerPax)}/pax')
                                .join('\n'),
                        style: const TextStyle(
                            color: Cp.onVariant, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDownload,
                icon: const Icon(Icons.picture_as_pdf, color: Cp.primary),
                tooltip: 'Download menu PDF',
              ),
            ],
          ),
        ),
      );
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
  Widget build(BuildContext context) => SizedBox(
      width: 150,
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: Cp.outline,
                  fontWeight: FontWeight.w900)),
          Text(value,
              style: TextStyle(
                  color: color == Cp.error ? color : Cp.onSurface,
                  fontWeight: FontWeight.w800))
        ]))
      ]));
}
