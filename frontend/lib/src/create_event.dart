part of '../main.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen(
      {super.key,
      this.initialEvent,
      required this.onDraftSaved,
      required this.onClose,
      required this.onCreate,
      required this.services,
      required this.customMenus,
      required this.clients,
      required this.customerEvents,
      required this.onSaveService,
      required this.onDeleteService,
      required this.onSaveCustomMenu,
      this.initialStep = 0});
  final AppEvent? initialEvent;
  final int initialStep;
  final ValueChanged<AppEvent> onDraftSaved;
  final VoidCallback onClose;
  final Future<void> Function(EventDraft draft) onCreate;
  final List<AdditionalServiceItem> services;
  final List<CustomMenu> customMenus;
  final List<AppClient> clients;
  final List<AppEvent> customerEvents;
  final ValueChanged<AdditionalServiceItem> onSaveService;
  final ValueChanged<String> onDeleteService;
  final Future<void> Function(CustomMenu menu) onSaveCustomMenu;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final api = ApiService();
  int step = 0;
  bool saving = false;
  bool autosaving = false;
  bool hasUnsavedChanges = false;
  String? error;
  late final EventDraft draft;

  bool get isEditing => widget.initialEvent != null;

  @override
  void initState() {
    super.initState();
    step = widget.initialStep.clamp(0, 3).toInt();
    draft = widget.initialEvent == null
        ? EventDraft()
        : EventDraft.fromEvent(widget.initialEvent!);
  }

  List<CustomerSuggestion> get customerSuggestions {
    final byMobile = <String, CustomerSuggestion>{};
    for (final client in widget.clients) {
      final mobile = normalizeMobileNumber(client.mobile);
      if (mobile.isEmpty) continue;
      byMobile[mobile] =
          CustomerSuggestion(name: client.name.trim(), mobile: mobile);
    }
    for (final event in widget.customerEvents) {
      final mobile = normalizeMobileNumber(event.mobile);
      if (mobile.isEmpty) continue;
      final name =
          event.primaryClient.isEmpty ? event.name : event.primaryClient;
      byMobile.putIfAbsent(
          mobile, () => CustomerSuggestion(name: name, mobile: mobile));
    }
    final list = byMobile.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> save() async {
    draft.mobile = normalizeMobileNumber(draft.mobile);
    final saveError = validateEventForFinalSave();
    if (saveError != null) {
      setState(() => error = saveError);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onCreate(draft);
      if (!mounted) return;
      showCpSnack(context,
          widget.initialEvent == null ? 'Event created' : 'Event updated');
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String? validateDetails() {
    draft.mobile = normalizeMobileNumber(draft.mobile);
    if (draft.client.trim().isEmpty) return 'Primary client is required.';
    if (draft.mobile.trim().isEmpty) return 'Mobile number is required.';
    if (draft.mobile.length != 10) return 'Mobile number must be 10 digits.';
    return null;
  }

  String? validateEventForFinalSave() {
    final detailsError = validateDetails();
    if (detailsError != null) return detailsError;
    if (draft.dates.isEmpty) return 'Add at least one event date.';
    final seenDates = <String>{};
    for (final date in draft.dates) {
      final dateError =
          isoDateValidator(date.date, label: 'Event date', noPast: !isEditing);
      if (dateError != null) return dateError;
      if (!seenDates.add(date.date.trim())) return 'Date already added';
      for (final slot in date.slots.where((item) => item.enabled)) {
        final pax = int.tryParse(slot.pax.trim()) ?? 0;
        if (pax <= 0) return '${slot.type} members must be more than zero.';
      }
    }
    return null;
  }

  Future<bool> autosaveDraft() async {
    if (autosaving) return true;
    final detailsError = validateDetails();
    if (detailsError != null) {
      setState(() => error = detailsError);
      return false;
    }
    setState(() {
      autosaving = true;
      error = null;
    });
    try {
      final saved = await api.saveEventDraft(draft, eventId: draft.id);
      draft.id = saved.id;
      widget.onDraftSaved(saved);
      if (mounted) setState(() => hasUnsavedChanges = false);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
      return false;
    } finally {
      if (mounted) setState(() => autosaving = false);
    }
  }

  Future<void> goNext() async {
    if (step == 0) {
      final detailsError = validateDetails();
      if (detailsError != null) {
        setState(() => error = detailsError);
        return;
      }
    }
    final saved = await autosaveDraft();
    if (!saved || !mounted) return;
    setState(() {
      error = null;
      step++;
    });
  }

  void markChanged() {
    setState(() {
      hasUnsavedChanges = true;
      error = null;
    });
  }

  Future<String?> confirmStepJump() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('Save your changes before moving to this step?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, 'skip'),
              child: const Text('Skip')),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> jumpToStep(int targetStep) async {
    if (targetStep == step || saving || autosaving) return;
    if (hasUnsavedChanges) {
      final choice = await confirmStepJump();
      if (!mounted || choice == null) return;
      if (choice == 'save') {
        final saved = await autosaveDraft();
        if (!saved || !mounted) return;
      }
    }
    setState(() {
      error = null;
      step = targetStep;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScreenFrame(
      bottomPadding: 24,
      topBar: TopBar(
        title: step == 2
            ? 'Menu Configuration'
            : widget.initialEvent == null
                ? 'Create Event'
                : 'Edit Event',
        avatar: false,
        leading: IconButton(
            onPressed: widget.onClose,
            icon: Icon(Icons.arrow_back, color: cpPrimary(context))),
        actions: [
          if (autosaving)
            Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cpPrimary(context)))))
        ],
      ),
      children: [
        StepperHeader(active: step, onStepTap: jumpToStep),
        const SizedBox(height: 24),
        if (error != null) ...[
          CpCard(
              color: Cp.errorContainer,
              child: Text(error!,
                  style: const TextStyle(
                      color: Cp.error, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12)
        ],
        if (step == 0)
          CreateDetailsStep(
              draft: draft,
              customers: customerSuggestions,
              onChanged: markChanged),
        if (step == 1)
          CreateDatesStep(
              dates: draft.dates,
              onChanged: () {
                setState(() => hasUnsavedChanges = true);
                autosaveDraft();
              }),
        if (step == 2)
          CreateMenuStep(
              dates: draft.dates,
              services: widget.services,
              customMenus: widget.customMenus,
              onChanged: () {
                setState(() => hasUnsavedChanges = true);
                autosaveDraft();
              },
              onSaveService: widget.onSaveService,
              onDeleteService: widget.onDeleteService,
              onSaveCustomMenu: widget.onSaveCustomMenu),
        if (step == 3)
          CreateReviewStep(
              draft: draft,
              onChanged: () {
                setState(() => hasUnsavedChanges = true);
                autosaveDraft();
              }),
        const SizedBox(height: 20),
        Row(
          children: [
            if (step > 0)
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => setState(() => step--),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'))),
            if (step > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: saving || autosaving
                      ? null
                      : () => step == 3 ? save() : goNext(),
                  style: FilledButton.styleFrom(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      disabledBackgroundColor:
                          scheme.primaryContainer.withValues(alpha: .42),
                      disabledForegroundColor:
                          scheme.onPrimaryContainer.withValues(alpha: .65)),
                  label: Text(
                      saving
                          ? 'Saving...'
                          : step == 0
                              ? 'Next: Add Dates'
                              : step == 1
                                  ? 'Next: Add Menus'
                                  : step == 2
                                      ? 'Next: Review'
                                      : widget.initialEvent == null
                                          ? 'Create Event'
                                          : 'Save Event',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  icon: Icon(step == 3 ? Icons.check : Icons.arrow_forward),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CreateDetailsStep extends StatefulWidget {
  const CreateDetailsStep(
      {super.key,
      required this.draft,
      required this.customers,
      required this.onChanged});
  final EventDraft draft;
  final List<CustomerSuggestion> customers;
  final VoidCallback onChanged;

  @override
  State<CreateDetailsStep> createState() => _CreateDetailsStepState();
}

class _CreateDetailsStepState extends State<CreateDetailsStep> {
  List<CustomerSuggestion> matches = [];
  String suggestionSource = '';

  void updateMatches(String value, String source) {
    final q = value.trim().toLowerCase();
    setState(() {
      suggestionSource = q.isEmpty ? '' : source;
      matches = q.isEmpty
          ? []
          : widget.customers
              .where((customer) =>
                  customer.name.toLowerCase().contains(q) ||
                  customer.mobile.contains(q))
              .take(6)
              .toList();
    });
  }

  void selectCustomer(CustomerSuggestion customer) {
    setState(() {
      widget.draft.client = customer.name;
      widget.draft.mobile = customer.mobile;
      matches = [];
      suggestionSource = '';
    });
    widget.onChanged();
  }

  Widget suggestionList(String source) {
    if (matches.isEmpty || suggestionSource != source) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: cpSurfaceLow(context),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: matches
              .map((customer) => ListTile(
                    dense: true,
                    leading: Icon(Icons.person, color: cpPrimary(context)),
                    title: Text(
                        customer.name.isEmpty
                            ? 'Unnamed client'
                            : customer.name,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text(customer.mobile),
                    onTap: () => selectCustomer(customer),
                  ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.assignment, color: cpPrimary(context)),
            const SizedBox(width: 8),
            Text('Event Fundamentals',
                style: TextStyle(
                    fontSize: 20,
                    color: cpPrimary(context),
                    fontWeight: FontWeight.w800))
          ]),
          const SizedBox(height: 20),
          FormFieldBox(
              label: 'Event Name (Optional)',
              value: widget.draft.name,
              onChanged: (value) {
                widget.draft.name = value;
                widget.onChanged();
              }),
          FormFieldBox(
            label: 'Primary Client',
            value: widget.draft.client,
            icon: Icons.person_search,
            onChanged: (value) {
              widget.draft.client = value;
              updateMatches(value, 'client');
              widget.onChanged();
            },
          ),
          suggestionList('client'),
          FormFieldBox(
              label: 'Mobile Number (Unique Customer ID)',
              value: widget.draft.mobile,
              icon: Icons.phone_iphone,
              inputFormatters: mobileInputFormatters,
              onChanged: (value) {
                widget.draft.mobile = normalizeMobileNumber(value);
                updateMatches(widget.draft.mobile, 'mobile');
                widget.onChanged();
              }),
          suggestionList('mobile'),
          FormFieldBox(
              label: 'Venue',
              value: widget.draft.venue,
              icon: Icons.location_on,
              onChanged: (value) {
                widget.draft.venue = value;
                widget.onChanged();
              }),
          FormFieldBox(
              label: 'Event Notes & Logistics',
              value: widget.draft.notes,
              height: 98,
              onChanged: (value) {
                widget.draft.notes = value;
                widget.onChanged();
              }),
        ]),
      ),
    ]);
  }
}

class CreateDatesStep extends StatelessWidget {
  const CreateDatesStep(
      {super.key, required this.dates, required this.onChanged});
  final List<DraftDateConfig> dates;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Event Dates',
          style: TextStyle(
              color: cpPrimary(context),
              fontSize: 24,
              fontWeight: FontWeight.w900)),
      Text(
          'Add every date in the event schedule. Members are configured later for each date and menu type.',
          style: TextStyle(color: cpOnVariant(context))),
      const SizedBox(height: 16),
      if (dates.isEmpty)
        const EmptyStateCard(
            title: 'No dates added',
            message:
                'Add each event date. Members are configured per menu type later.'),
      ...dates.map((date) => DateScheduleCard(
          month: shortMonthLabel(date.date),
          day: dayLabel(date.date),
          title: date.label.isEmpty ? 'Event Date' : date.label,
          summary: readableDateLabel(date.date),
          onDelete: () {
            dates.remove(date);
            onChanged();
          })),
      DashedAction(
          label: 'Add Date',
          icon: Icons.add_circle,
          onTap: () async {
            final date = await showAddDateSheet(context);
            if (date != null) {
              final dateExists =
                  dates.any((item) => item.date.trim() == date.date.trim());
              if (dateExists) {
                if (context.mounted) await showDateAlreadyAddedDialog(context);
                return;
              }
              dates.add(date);
              onChanged();
            }
          }),
    ]);
  }
}

Future<void> showDateAlreadyAddedDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Date already added'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String defaultMenuTimeForType(String type) {
  return appPreferences.value.defaultMenuTimes[type] ??
      defaultEventMenuTimes[type] ??
      '10:00 AM';
}

TimeOfDay parseMenuTimeOfDay(String value, {String fallback = '10:00 AM'}) {
  final raw = value.trim().isEmpty ? fallback.trim() : value.trim();
  final match =
      RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$').firstMatch(raw);
  if (match == null) return const TimeOfDay(hour: 10, minute: 0);
  var hour = int.tryParse(match.group(1) ?? '') ?? 10;
  final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
  final suffix = match.group(3)?.toUpperCase();
  if (suffix == 'PM' && hour < 12) hour += 12;
  if (suffix == 'AM' && hour == 12) hour = 0;
  return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}

String formatMenuTimeOfDay(TimeOfDay time) {
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  return '$hour12:${time.minute.toString().padLeft(2, '0')} $suffix';
}

MealSlotConfig defaultMealSlotForType(String type) {
  return MealSlotConfig(
    type: type,
    time: defaultMenuTimeForType(type),
    pax: '',
    pricePerPax: 0,
  );
}

DraftDateConfig defaultDraftDateConfig(
    {required String date, required String label}) {
  final config = DraftDateConfig(date: date, label: label);
  final autoTypes = appPreferences.value.autoMenuTypes;
  config.slots.addAll(
      eventMenuTypes.where(autoTypes.contains).map(defaultMealSlotForType));
  return config;
}

Future<DraftDateConfig?> showAddDateSheet(BuildContext context) {
  final dateController = TextEditingController();
  final labelController = TextEditingController();
  DateTime? selectedDate;
  final today = DateTime.now();
  final firstDate = DateTime(today.year, today.month, today.day);
  String formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return showModalBottomSheet<DraftDateConfig>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          decoration: BoxDecoration(
              color: cpSurface(context),
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
                            color: cpOutlineVariant(context),
                            borderRadius: BorderRadius.circular(99)))),
                Text('Add Event Date',
                    style: TextStyle(
                        color: cpPrimary(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                Text('Select a date. Previous dates are disabled.',
                    style: TextStyle(color: cpOnVariant(context))),
                const SizedBox(height: 18),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? firstDate,
                      firstDate: firstDate,
                      lastDate: DateTime(firstDate.year + 5),
                    );
                    if (picked == null) return;
                    setSheetState(() {
                      selectedDate = picked;
                      dateController.text = formatDate(picked);
                    });
                  },
                  child: IgnorePointer(
                      child: EditableInlineField(
                          label: 'Event Date', controller: dateController)),
                ),
                EditableInlineField(
                    label: 'Date Label', controller: labelController),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: selectedDate == null
                          ? null
                          : () => Navigator.pop(
                              context,
                              defaultDraftDateConfig(
                                  date: dateController.text.trim(),
                                  label: labelController.text.trim())),
                      style: FilledButton.styleFrom(
                          backgroundColor: Cp.secondaryContainer,
                          foregroundColor: const Color(0xff694000)),
                      child: const Text('Save Date'),
                    ),
                  ),
                ]),
              ]),
        ),
      ),
    ),
  );
}

class DateScheduleCard extends StatelessWidget {
  const DateScheduleCard(
      {super.key,
      required this.month,
      required this.day,
      required this.title,
      required this.summary,
      this.onDelete});
  final String month, day, title, summary;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
          child: Row(children: [
        Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(month,
                  style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
              Text(day,
                  style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontSize: 22,
                      fontWeight: FontWeight.w900))
            ])),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          Text(summary,
              style: TextStyle(
                  color: cpOnVariant(context), fontWeight: FontWeight.w700))
        ])),
        if (onDelete != null)
          IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete, color: Cp.error))
      ])),
    );
  }
}

class CreateMenuStep extends StatefulWidget {
  const CreateMenuStep(
      {super.key,
      required this.dates,
      required this.services,
      required this.customMenus,
      required this.onChanged,
      required this.onSaveService,
      required this.onDeleteService,
      required this.onSaveCustomMenu});
  final List<DraftDateConfig> dates;
  final List<AdditionalServiceItem> services;
  final List<CustomMenu> customMenus;
  final VoidCallback onChanged;
  final ValueChanged<AdditionalServiceItem> onSaveService;
  final ValueChanged<String> onDeleteService;
  final Future<void> Function(CustomMenu menu) onSaveCustomMenu;

  @override
  State<CreateMenuStep> createState() => _CreateMenuStepState();
}

class _CreateMenuStepState extends State<CreateMenuStep> {
  int selectedDateIndex = 0;

  DraftDateConfig? get currentConfig => widget.dates.isEmpty
      ? null
      : widget.dates[selectedDateIndex.clamp(0, widget.dates.length - 1)];

  @override
  Widget build(BuildContext context) {
    final config = currentConfig;
    final scheme = Theme.of(context).colorScheme;
    final primary = cpPrimary(context);
    final onSurface = cpOnSurface(context);
    final onVariant = cpOnVariant(context);
    final outline = cpOutline(context);
    if (config == null) {
      return const EmptyStateCard(
          title: 'Add dates first',
          message:
              'Menu configuration is available after you add at least one event date.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 10,
        children: List.generate(widget.dates.length, (index) {
          final selected = index == selectedDateIndex;
          return ChoiceChip(
            selected: selected,
            label: Text(readableDateLabel(widget.dates[index].date)),
            selectedColor: scheme.primaryContainer,
            backgroundColor: scheme.surfaceContainerHigh,
            side: BorderSide(
                color:
                    selected ? scheme.primaryContainer : scheme.outlineVariant),
            showCheckmark: false,
            labelStyle: TextStyle(
                color: selected ? scheme.onPrimaryContainer : onSurface,
                fontWeight: FontWeight.w800),
            onSelected: (_) => setState(() => selectedDateIndex = index),
          );
        }),
      ),
      const SizedBox(height: 16),
      if (config.slots.isEmpty)
        CpCard(
          color: Cp.surfaceLow,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.event_note, color: outline),
            const SizedBox(height: 10),
            Text('No menu configured for this date yet.',
                style: TextStyle(color: primary, fontWeight: FontWeight.w900)),
            Text('Add only the menu types and services needed for this date.',
                style: TextStyle(color: onVariant)),
          ]),
        )
      else
        ...config.slots.map((slot) => MealSlotCard(
              key: ValueKey('${config.label}-${slot.type}'),
              slot: slot,
              items: selectedMenuTitles(slot),
              services: slot.additionalServices,
              menuImages: slot.menuImages,
              onPaxChanged: (value) {
                setState(() => slot.pax = value);
                widget.onChanged();
              },
              onPriceChanged: (value) {
                setState(() => slot.pricePerPax = int.tryParse(value) ?? 0);
                widget.onChanged();
              },
              onTimeChanged: (value) {
                setState(() => slot.time = value);
                widget.onChanged();
              },
              onEditMenu: () => openMenuPicker(slot),
              onSaveAsCustomMenu: () => saveSlotAsCustomMenu(slot),
              onEditServices: () => openSlotServicePicker(slot),
              onAddImage: () => addMenuImage(slot),
              onRemoveImage: (image) {
                setState(() => slot.menuImages.remove(image));
                widget.onChanged();
              },
              onDelete: () {
                setState(() => config.slots.remove(slot));
                widget.onChanged();
              },
            )),
      const SizedBox(height: 4),
      DashedAction(
          label: 'Add Menu Type',
          icon: Icons.add_circle,
          onTap: openMealTypePicker),
      const SizedBox(height: 12),
      Text('Date-level Additional Services',
          style: TextStyle(color: onVariant, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (config.additionalServices.isEmpty)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('No additional services for this date.',
                style:
                    TextStyle(color: onVariant, fontStyle: FontStyle.italic)))
      else
        ...config.additionalServices.map((service) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CpCard(
                  child: Row(children: [
                Expanded(
                    child: Text(additionalServiceLine(service),
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                IconButton(
                    onPressed: () {
                      setState(() => config.additionalServices.remove(service));
                      widget.onChanged();
                    },
                    icon: const Icon(Icons.delete, color: Cp.error))
              ])),
            )),
      const SizedBox(height: 12),
      DashedAction(
          label: 'Add Date Service',
          icon: Icons.add_circle,
          count: config.additionalServices.length,
          onTap: openServicePicker),
    ]);
  }

  List<String> selectedMenuTitles(MealSlotConfig slot) {
    return slot.selectedMenuIds
        .map((id) => menuItemById(id)?.english ?? id)
        .toList();
  }

  void openMenuPicker(MealSlotConfig slot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MenuPickerScreen(
          meal: slot.type,
          selectedIds: slot.selectedMenuIds,
          customMenus: widget.customMenus,
          onChanged: (ids) {
            setState(() => slot.selectedMenuIds = {...ids});
            widget.onChanged();
          },
        ),
      ),
    );
  }

  Future<void> saveSlotAsCustomMenu(MealSlotConfig slot) async {
    if (slot.selectedMenuIds.isEmpty) {
      showCpSnack(context, 'Select menu items before saving custom menu');
      return;
    }
    final config = currentConfig;
    final defaultName = [
      slot.type,
      if (config != null) readableDateLabel(config.date),
    ].join(' ');
    final controller = TextEditingController(text: defaultName);
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Save as custom menu'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Custom menu name'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Save')),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty || !mounted) return;
      await widget.onSaveCustomMenu(CustomMenu(
          id: '',
          name: name.trim(),
          type: slot.type,
          itemIds: slot.selectedMenuIds));
      if (mounted) showCpSnack(context, 'Custom menu saved');
    } catch (e) {
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      controller.dispose();
    }
  }

  void openSlotServicePicker(MealSlotConfig slot) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServicePickerSheet(
        services: widget.services,
        selectedServices: slot.additionalServices,
        onChanged: (selectedServices) {
          setState(() {
            slot.additionalServices
              ..clear()
              ..addAll(selectedServices);
          });
          widget.onChanged();
        },
      ),
    );
  }

  Future<void> addMenuImage(MealSlotConfig slot) async {
    if (slot.menuImages.length >= 2) {
      showCpSnack(context, 'Maximum 2 images per menu type');
      return;
    }
    final result =
        await fp.FilePicker.pickFiles(type: fp.FileType.image, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;
    final extension = (file!.extension ?? '').toLowerCase();
    final mime = extension == 'jpg' || extension == 'jpeg'
        ? 'image/jpeg'
        : extension == 'webp'
            ? 'image/webp'
            : 'image/png';
    setState(() {
      slot.menuImages.add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'name': file.name,
        'dataUrl': 'data:$mime;base64,${base64Encode(bytes)}',
      });
    });
    widget.onChanged();
  }

  void openMealTypePicker() {
    final availableTypes = [
      for (final type in eventMenuTypes)
        (type, defaultMenuTimeForType(type), 0),
    ];
    final config = currentConfig;
    if (config == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * .78),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: BoxDecoration(
              color: cpSurface(context),
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
                            color: cpOutlineVariant(context),
                            borderRadius: BorderRadius.circular(99)))),
                Text('Add Menu Type for ${readableDateLabel(config.date)}',
                    style: TextStyle(
                        color: cpPrimary(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableTypes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final type = availableTypes[index];
                      final exists =
                          config.slots.any((slot) => slot.type == type.$1);
                      return CpCard(
                        color: exists ? Cp.surfaceLow : Cp.card,
                        onTap: exists
                            ? null
                            : () {
                                setState(() => config.slots.add(MealSlotConfig(
                                    type: type.$1,
                                    time: type.$2,
                                    pax: '',
                                    pricePerPax: type.$3)));
                                widget.onChanged();
                                Navigator.pop(context);
                              },
                        child: Row(children: [
                          Icon(exists ? Icons.check_circle : Icons.add_circle,
                              color: exists
                                  ? cpOutline(context)
                                  : cpPrimary(context)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  exists ? '${type.$1} already added' : type.$1,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900))),
                          Text(type.$2,
                              style: TextStyle(
                                  color: cpOnVariant(context),
                                  fontWeight: FontWeight.w700)),
                        ]),
                      );
                    },
                  ),
                ),
              ]),
        ),
      ),
    );
  }

  void openServicePicker() {
    final config = currentConfig;
    if (config == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServicePickerSheet(
        services: widget.services,
        selectedServices: config.additionalServices,
        onChanged: (selectedServices) {
          setState(() {
            config.additionalServices
              ..clear()
              ..addAll(selectedServices);
          });
          widget.onChanged();
        },
      ),
    );
  }
}

class DateMenuConfig {
  DateMenuConfig(
      {required this.label,
      List<MealSlotConfig>? slots,
      Set<String>? selectedServiceIds})
      : slots = slots ?? <MealSlotConfig>[],
        selectedServiceIds = selectedServiceIds ?? <String>{};

  final String label;
  final List<MealSlotConfig> slots;
  final Set<String> selectedServiceIds;
}

class MealSlotConfig {
  MealSlotConfig(
      {this.id,
      required this.type,
      required this.time,
      required this.pax,
      required this.pricePerPax,
      Set<String>? selectedMenuIds,
      List<Map<String, dynamic>>? additionalServices,
      List<Map<String, dynamic>>? menuImages,
      this.enabled = true})
      : selectedMenuIds = selectedMenuIds ?? <String>{},
        additionalServices = additionalServices ?? <Map<String, dynamic>>[],
        menuImages = menuImages ?? <Map<String, dynamic>>[];

  String? id;
  final String type;
  String time;
  String pax;
  int pricePerPax;
  Set<String> selectedMenuIds;
  final List<Map<String, dynamic>> additionalServices;
  final List<Map<String, dynamic>> menuImages;
  bool enabled;

  factory MealSlotConfig.fromEventSlot(AppMenuSlot slot) {
    return MealSlotConfig(
        id: slot.id,
        type: slot.type,
        time: slot.time.trim().isEmpty
            ? defaultMenuTimeForType(slot.type)
            : slot.time,
        pax: slot.pax.toString(),
        pricePerPax: slot.pricePerPax,
        selectedMenuIds: slot.menuItemIds.toSet(),
        additionalServices: slot.additionalServices
            .map((service) => Map<String, dynamic>.from(service))
            .toList(),
        menuImages: slot.menuImages
            .map((image) => Map<String, dynamic>.from(image))
            .toList(),
        enabled: slot.enabled);
  }

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        'type': type,
        'time': time.trim().isEmpty ? defaultMenuTimeForType(type) : time,
        'pax': int.tryParse(pax) ?? 0,
        'pricePerPax': pricePerPax,
        'enabled': enabled,
        'menuItemIds': selectedMenuIds.toList(),
        'additionalServices': additionalServices,
        'menuImages': menuImages,
      };
}

class ServicePickerSheet extends StatefulWidget {
  const ServicePickerSheet(
      {super.key,
      required this.services,
      required this.selectedServices,
      required this.onChanged});
  final List<AdditionalServiceItem> services;
  final List<Map<String, dynamic>> selectedServices;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  @override
  State<ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<ServicePickerSheet> {
  late Set<String> selectedIds;
  final quantityControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    selectedIds = widget.selectedServices
        .map((service) => service['serviceId'].toString())
        .toSet();
    for (final service in widget.services) {
      final selected = widget.selectedServices
          .where((item) => item['serviceId'] == service.id)
          .firstOrNull;
      final quantity =
          (selected?['quantity'] as num?)?.toInt() ?? service.quantity;
      quantityControllers[service.id] =
          TextEditingController(text: quantity > 0 ? '$quantity' : '');
    }
  }

  @override
  void dispose() {
    for (final controller in quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final services = [...widget.services]..sort((a, b) {
        final selectedCompare = (selectedIds.contains(b.id) ? 1 : 0)
            .compareTo(selectedIds.contains(a.id) ? 1 : 0);
        if (selectedCompare != 0) return selectedCompare;
        return a.name.compareTo(b.name);
      });

    return SafeArea(
      top: false,
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .75),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: BoxDecoration(
            color: cpSurface(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                  child: Container(
                      width: 48,
                      height: 6,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: cpOutlineVariant(context),
                          borderRadius: BorderRadius.circular(99)))),
              Text('Add Service',
                  style: TextStyle(
                      color: cpPrimary(context),
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              Text('Choose services from Settings > Additional Services.',
                  style: TextStyle(color: cpOnVariant(context))),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final selected = selectedIds.contains(service.id);
                    return CpCard(
                      color: selected ? Cp.primaryFixed : Cp.card,
                      onTap: () => setState(() => selected
                          ? selectedIds.remove(service.id)
                          : selectedIds.add(service.id)),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Icon(
                                    selected
                                        ? Icons.check_circle
                                        : Icons.circle_outlined,
                                    color: selected
                                        ? cpPrimary(context)
                                        : cpOutline(context))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    serviceLine(
                                        service.name,
                                        int.tryParse(
                                                quantityControllers[service.id]
                                                        ?.text ??
                                                    '') ??
                                            service.quantity,
                                        service.unit,
                                        service.price),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800))),
                            if (selected) ...[
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 96,
                                child: TextField(
                                  controller: quantityControllers[service.id],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: 'Count',
                                      isDense: true,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10))),
                                  onTap: () {},
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          ]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer),
                  onPressed: () {
                    for (final service in widget.services
                        .where((service) => selectedIds.contains(service.id))) {
                      final raw =
                          quantityControllers[service.id]?.text.trim() ?? '';
                      final quantity = int.tryParse(raw);
                      if (raw.isNotEmpty &&
                          (quantity == null || quantity < 0)) {
                        showCpSnack(
                            context, 'Enter a valid count for ${service.name}');
                        return;
                      }
                    }
                    widget.onChanged(widget.services
                        .where((service) => selectedIds.contains(service.id))
                        .map((service) {
                      final quantity = int.tryParse(
                              quantityControllers[service.id]?.text.trim() ??
                                  '') ??
                          0;
                      return {
                        'serviceId': service.id,
                        'name': service.name,
                        'quantity': quantity,
                        'unit': service.unit,
                        'price': service.price
                      };
                    }).toList());
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Services',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
      ),
    );
  }
}

class AdditionalServiceCard extends StatelessWidget {
  const AdditionalServiceCard(
      {super.key, required this.service, required this.onDelete});
  final AdditionalServiceItem service;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: CpCard(
          color: Cp.surfaceLow,
          child: Row(children: [
            const Icon(Icons.flatware, color: Cp.secondary),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    serviceLine(service.name, service.quantity, service.unit,
                        service.price),
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            IconButton(
                onPressed: () => onDelete(service.id),
                icon: const Icon(Icons.delete, color: Cp.error)),
          ]),
        ),
      );
}

class MenuPickerScreen extends StatefulWidget {
  const MenuPickerScreen(
      {super.key,
      required this.meal,
      required this.selectedIds,
      required this.customMenus,
      required this.onChanged});
  final String meal;
  final Set<String> selectedIds;
  final List<CustomMenu> customMenus;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<MenuPickerScreen> createState() => _MenuPickerScreenState();
}

class _MenuPickerScreenState extends State<MenuPickerScreen> {
  final api = ApiService();
  late Set<String> selectedIds;
  final searchController = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    selectedIds = {...widget.selectedIds};
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Set<String> get menuTypeMeals {
    final meal = widget.meal.trim();
    if (meal == 'Lunch' || meal == 'Dinner') return {'Lunch', 'Dinner'};
    if (meal == 'Snack' || meal == 'Snacks') return {'Snack'};
    if (meal == 'Other') return {'Others'};
    return {meal};
  }

  bool itemMatchesMenuType(MenuMasterItem item) {
    final itemMeals = item.meals
        .split(',')
        .map((meal) => meal.trim())
        .where((meal) => meal.isNotEmpty)
        .map((meal) => meal == 'Other' ? 'Others' : meal)
        .toSet();
    if (selectedIds.contains(item.id)) return true;
    if (itemMeals.isEmpty) return menuTypeMeals.contains('Others');
    return itemMeals.intersection(menuTypeMeals).isNotEmpty;
  }

  String nextMenuItemId() {
    var maxNumber = 0;
    for (final item in MenuMasterScreen.menuItems) {
      final match = RegExp(r'^MNU-(\d+)$').firstMatch(item.id);
      if (match == null) continue;
      final value = int.tryParse(match.group(1) ?? '') ?? 0;
      if (value > maxNumber) maxNumber = value;
    }
    return 'MNU-${(maxNumber + 1).toString().padLeft(3, '0')}';
  }

  Future<void> addMenuItemPopup() async {
    final english = TextEditingController(text: query.trim());
    final kannada = TextEditingController();
    try {
      final item = await showDialog<MenuMasterItem>(
        context: context,
        builder: (context) {
          String? popupError;
          var savingItem = false;
          return StatefulBuilder(builder: (context, setDialogState) {
            Future<void> saveItem() async {
              final englishText = english.text.trim();
              final kannadaText = kannada.text.trim();
              if (englishText.isEmpty || kannadaText.isEmpty) {
                setDialogState(
                    () => popupError = 'Enter both English and Kannada text.');
                return;
              }
              setDialogState(() {
                popupError = null;
                savingItem = true;
              });
              try {
                final saved = await api.saveMenuItem(
                    MenuMasterItem(
                        id: nextMenuItemId(),
                        english: englishText,
                        kannada: kannadaText,
                        category: 'Other',
                        meals: eventMenuTypes
                            .where((meal) => menuTypeMeals.contains(meal))
                            .join(', '),
                        veg: true),
                    creating: true);
                if (context.mounted) Navigator.pop(context, saved);
              } catch (e) {
                setDialogState(() {
                  popupError = e.toString().replaceFirst('Exception: ', '');
                  savingItem = false;
                });
              }
            }

            return AlertDialog(
              title: Text('Add ${widget.meal} item'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  controller: english,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'English'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: kannada,
                  decoration: const InputDecoration(labelText: 'Kannada'),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => savingItem ? null : saveItem(),
                ),
                if (popupError != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(popupError!,
                        style: const TextStyle(
                            color: Cp.error, fontWeight: FontWeight.w800)),
                  ),
                ],
              ]),
              actions: [
                TextButton(
                    onPressed: savingItem ? null : () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: savingItem ? null : saveItem,
                    child: Text(savingItem ? 'Saving...' : 'Add')),
              ],
            );
          });
        },
      );
      if (item == null || !mounted) return;
      setState(() {
        final index = MenuMasterScreen.menuItems
            .indexWhere((existing) => existing.id == item.id);
        if (index == -1) {
          MenuMasterScreen.menuItems.add(item);
        } else {
          MenuMasterScreen.menuItems[index] = item;
        }
        selectedIds.add(item.id);
        query = '';
        searchController.clear();
      });
      showCpSnack(context, '${widget.meal} item added');
    } finally {
      english.dispose();
      kannada.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = MenuMasterScreen.menuItems.where((item) {
      if (item.disabled) return false;
      if (appPreferences.value.vegOnlyDefault && !item.veg) return false;
      final matchesType = itemMatchesMenuType(item);
      final matchesSearch =
          item.title.toLowerCase().contains(query.toLowerCase()) ||
              item.english.toLowerCase().contains(query.toLowerCase()) ||
              item.kannada.contains(query);
      return matchesType && matchesSearch;
    }).toList()
      ..sort((a, b) {
        final aOrder = selectedOrder(a.id, selectedIds);
        final bOrder = selectedOrder(b.id, selectedIds);
        if (aOrder != -1 && bOrder != -1) return aOrder.compareTo(bOrder);
        final selectedCompare = (selectedIds.contains(b.id) ? 1 : 0)
            .compareTo(selectedIds.contains(a.id) ? 1 : 0);
        if (selectedCompare != 0) return selectedCompare;
        return a.english.compareTo(b.english);
      });

    return Scaffold(
      backgroundColor: cpSurface(context),
      appBar: AppBar(
        backgroundColor: cpSurface(context),
        foregroundColor: cpPrimary(context),
        title: Text('Select ${widget.meal} Menu'),
        actions: [
          IconButton(
              tooltip: 'Select from ready made menus',
              onPressed: openReadyMadeMenuPicker,
              icon: const Icon(Icons.fact_check)),
          IconButton(
              tooltip: 'Add ${widget.meal} item',
              onPressed: addMenuItemPopup,
              icon: const Icon(Icons.add, color: Cp.toolbarIcon)),
          TextButton(
            onPressed: () {
              widget.onChanged(selectedIds);
              Navigator.pop(context);
            },
            child: const Text('Done',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close)),
                hintText: 'Search menu items',
                filled: true,
                fillColor: scheme.surfaceContainerLow,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            CpCard(
              onTap: addMenuItemPopup,
              color: Cp.primaryFixed,
              child: Row(children: [
                Icon(Icons.add_circle, color: cpPrimary(context), size: 24),
                const SizedBox(width: 12),
                Expanded(
                    child: Text('Add item',
                        style: TextStyle(
                            color: cpPrimary(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w900))),
              ]),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: (oldIndex, newIndex) => reorderSelectedItem(
                  items: items, oldIndex: oldIndex, newIndex: newIndex),
              itemBuilder: (context, index) {
                final item = items[index];
                final selected = selectedIds.contains(item.id);
                return Padding(
                  key: ValueKey(item.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CpCard(
                    color: selected ? Cp.primaryFixed : Cp.card,
                    onTap: () => setState(() {
                      if (selected) {
                        selectedIds.remove(item.id);
                        return;
                      }
                      selectedIds.add(item.id);
                      query = '';
                      searchController.clear();
                    }),
                    child: Row(children: [
                      Icon(
                          selected ? Icons.check_circle : Icons.circle_outlined,
                          color: selected
                              ? cpPrimary(context)
                              : cpOutline(context),
                          size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MarqueeText(
                          '${item.kannada}/${item.english}',
                          style: kannadaMenuTextStyle(context,
                              fontSize: 14, fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        ReorderableDragStartListener(
                          index: index,
                          child: Tooltip(
                            message: 'Drag to reorder selected menu items',
                            child: Icon(Icons.drag_handle,
                                color: cpPrimary(context)),
                          ),
                        ),
                      ],
                    ]),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void reorderSelectedItem(
      {required List<MenuMasterItem> items,
      required int oldIndex,
      required int newIndex}) {
    if (oldIndex < 0 || oldIndex >= items.length) return;
    final dragged = items[oldIndex];
    if (!selectedIds.contains(dragged.id)) return;

    final selectedVisible =
        items.where((item) => selectedIds.contains(item.id)).toList();
    if (selectedVisible.length < 2) return;

    final adjustedNewIndex = newIndex.clamp(0, selectedVisible.length - 1);

    final orderedIds = selectedIds.toList();
    orderedIds.remove(dragged.id);
    final targetId = selectedVisible[adjustedNewIndex].id;
    final insertAt = orderedIds.indexOf(targetId);
    orderedIds.insert(
        insertAt == -1 ? orderedIds.length : insertAt, dragged.id);
    setState(() => selectedIds = orderedIds.toSet());
  }

  void openReadyMadeMenuPicker() {
    final menus = widget.customMenus
        .where((menu) =>
            menu.type == widget.meal ||
            (widget.meal == 'Others' && menu.type == 'Other'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * .72),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: BoxDecoration(
              color: cpSurface(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                        width: 48,
                        height: 6,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                            color: cpOutlineVariant(context),
                            borderRadius: BorderRadius.circular(99)))),
                Text('Ready Made ${widget.meal} Menus',
                    style: TextStyle(
                        color: cpPrimary(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                Text(
                    'Selecting one will add all its items. You can still add extra items below.',
                    style: TextStyle(color: cpOnVariant(context))),
                const SizedBox(height: 14),
                if (menus.isEmpty)
                  const EmptyStateCard(
                      title: 'No ready made menus',
                      message: 'Add custom menus from Settings > Custom Menus.')
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: menus.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final menu = menus[index];
                        return CpCard(
                          onTap: () {
                            setState(() => selectedIds.addAll(menu.itemIds));
                            Navigator.pop(context);
                            showCpSnack(context, '${menu.name} items selected');
                          },
                          child: Row(children: [
                            Icon(Icons.playlist_add_check,
                                color: cpPrimary(context)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    '${menu.name}\n${menu.itemIds.length} items',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900))),
                          ]),
                        );
                      },
                    ),
                  ),
              ]),
        ),
      ),
    );
  }
}

class MealSlotCard extends StatelessWidget {
  const MealSlotCard(
      {super.key,
      required this.slot,
      required this.items,
      required this.services,
      required this.menuImages,
      required this.onPaxChanged,
      required this.onPriceChanged,
      required this.onTimeChanged,
      required this.onEditMenu,
      required this.onSaveAsCustomMenu,
      required this.onEditServices,
      required this.onAddImage,
      required this.onRemoveImage,
      required this.onDelete});
  final MealSlotConfig slot;
  final List<String> items;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> menuImages;
  final ValueChanged<String> onPaxChanged;
  final ValueChanged<String> onPriceChanged;
  final ValueChanged<String> onTimeChanged;
  final VoidCallback onEditMenu;
  final VoidCallback onSaveAsCustomMenu;
  final VoidCallback onEditServices;
  final VoidCallback onAddImage;
  final ValueChanged<Map<String, dynamic>> onRemoveImage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final primary = cpPrimary(context);
    final onVariant = cpOnVariant(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.restaurant_menu, color: primary),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(slot.type,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900)),
                  Text(
                      '${slot.time} | ${slot.pax.isEmpty ? 0 : slot.pax} Members',
                      style: TextStyle(color: onVariant))
                ])),
            IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Cp.error)),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final timeField = SizedBox(
              width: 52,
              child: MenuTimeField(
                  label: '',
                  value: slot.time,
                  fallback: defaultMenuTimeForType(slot.type),
                  iconOnly: true,
                  onChanged: onTimeChanged),
            );
            final membersField = FormFieldBox(
                label: 'Members',
                value: slot.pax,
                icon: Icons.person,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: onPaxChanged);
            final priceField = FormFieldBox(
                label: 'Price / Member',
                value: slot.pricePerPax == 0 ? '' : '${slot.pricePerPax}',
                icon: Icons.currency_rupee,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: onPriceChanged);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              timeField,
              const SizedBox(width: 12),
              Expanded(child: membersField),
              const SizedBox(width: 12),
              Expanded(child: priceField),
            ]);
          }),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('No menu items selected.',
                style: TextStyle(color: onVariant, fontStyle: FontStyle.italic))
          else
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    items.map((e) => Pill(e, color: Cp.surfaceHigh)).toList()),
          if (services.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: services
                    .map((service) => Pill(additionalServiceLine(service),
                        color: Cp.primaryFixed))
                    .toList()),
          ],
          if (menuImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: menuImages.map((image) {
                  final name = image['name']?.toString().trim();
                  return InputChip(
                    avatar: const Icon(Icons.image, size: 18),
                    label: Text(
                        name == null || name.isEmpty ? 'Menu image' : name),
                    onDeleted: () => onRemoveImage(image),
                  );
                }).toList()),
          ],
          const Divider(height: 24),
          Row(children: [
            Expanded(
                child: MenuSlotActionButton(
                    icon: Icons.edit, label: 'Menu', onPressed: onEditMenu)),
            Expanded(
                child: MenuSlotActionButton(
                    icon: Icons.playlist_add_check,
                    label: 'Custom',
                    onPressed: items.isEmpty ? null : onSaveAsCustomMenu)),
            Expanded(
                child: MenuSlotActionButton(
                    icon: Icons.room_service,
                    label: 'Service',
                    count: services.length,
                    onPressed: onEditServices)),
            Expanded(
                child: MenuSlotActionButton(
                    icon: Icons.add_photo_alternate,
                    label: 'Image',
                    onPressed: menuImages.length >= 2 ? null : onAddImage)),
          ]),
        ]),
      ),
    );
  }
}

class MenuSlotActionButton extends StatelessWidget {
  const MenuSlotActionButton(
      {super.key,
      required this.icon,
      required this.label,
      this.count = 0,
      required this.onPressed});

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          CountBadge(count: count),
        ],
      ),
    );
  }
}

class CreateReviewStep extends StatelessWidget {
  const CreateReviewStep(
      {super.key, required this.draft, required this.onChanged});
  final EventDraft draft;
  final VoidCallback onChanged;

  int get menuTotal => draft.dates.fold(
      0,
      (dateSum, date) =>
          dateSum +
          date.slots.where((slot) => slot.enabled).fold(
              0,
              (slotSum, slot) =>
                  slotSum + (int.tryParse(slot.pax) ?? 0) * slot.pricePerPax));
  int get serviceTotal => draft.dates.fold<int>(
      0,
      (dateSum, date) =>
          dateSum +
          date.additionalServices.fold<int>(
              0,
              (sum, service) =>
                  sum + ((service['price'] as num?)?.toInt() ?? 0)) +
          date.slots.fold<int>(
              0,
              (slotSum, slot) =>
                  slotSum +
                  slot.additionalServices.fold<int>(
                      0,
                      (sum, service) =>
                          sum + ((service['price'] as num?)?.toInt() ?? 0))));
  int get addOnTotal => draft.addOns
      .fold(0, (sum, addOn) => sum + ((addOn['cost'] as num?)?.toInt() ?? 0));
  int get grandTotal => menuTotal + serviceTotal + addOnTotal;

  @override
  Widget build(BuildContext context) => Column(children: [
        CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(draft.name.isEmpty ? 'Untitled Event' : draft.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: cpPrimary(context),
                          fontSize: 21,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(
                      [
                        if (draft.client.trim().isNotEmpty) draft.client,
                        if (draft.mobile.trim().isNotEmpty) draft.mobile
                      ].join(' | '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: cpOnVariant(context),
                          fontWeight: FontWeight.w700)),
                ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Total',
                  style: TextStyle(
                      color: cpOutline(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
              Text(money(grandTotal),
                  style: TextStyle(
                      color: cpPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
            ]),
          ]),
          const Divider(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: [
            ReviewSummaryChip(
                icon: Icons.restaurant_menu,
                label: 'Menu',
                value: menuTotal > 0 ? money(menuTotal) : 'Not priced'),
            ReviewSummaryChip(
                icon: Icons.room_service,
                label: 'Services',
                value: serviceTotal > 0 ? money(serviceTotal) : 'None'),
            ReviewSummaryChip(
                icon: Icons.add_card,
                label: 'Add-ons',
                value: addOnTotal > 0 ? money(addOnTotal) : 'None'),
            ReviewSummaryChip(
                icon: Icons.calendar_today,
                label: 'Dates',
                value: '${draft.dates.length}'),
            ReviewSummaryChip(
                icon: Icons.restaurant,
                label: 'Slots',
                value:
                    '${draft.dates.fold<int>(0, (sum, date) => sum + date.slots.length)}'),
            ReviewSummaryChip(
                icon: Icons.location_on,
                label: 'Venue',
                value: draft.venue.isEmpty ? 'Not set' : draft.venue),
          ]),
        ])),
        const SizedBox(height: 12),
        CpCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text('Add-ons',
                      style: TextStyle(
                          color: cpPrimary(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w900))),
              TextButton.icon(
                  onPressed: () => openAddOnSheet(context),
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Add Add-on')),
            ]),
            const SizedBox(height: 4),
            if (draft.addOns.isEmpty)
              Text('No add-ons added.',
                  style: TextStyle(
                      color: cpOnVariant(context), fontStyle: FontStyle.italic))
            else
              ...draft.addOns.map((addOn) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CpCard(
                      color: Cp.surfaceLow,
                      child: Row(children: [
                        const Icon(Icons.add_business, color: Cp.secondary),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(addOnLine(addOn),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                        IconButton(
                            onPressed: () =>
                                openAddOnSheet(context, addOn: addOn),
                            icon: Icon(Icons.edit, color: cpPrimary(context))),
                        IconButton(
                            onPressed: () {
                              draft.addOns.remove(addOn);
                              onChanged();
                            },
                            icon: const Icon(Icons.delete, color: Cp.error)),
                      ]),
                    ),
                  )),
            Align(
                alignment: Alignment.centerRight,
                child: Text('Grand Total: ${money(grandTotal)}',
                    style: TextStyle(
                        color: cpPrimary(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w900))),
            if (draft.addOns.isNotEmpty)
              Align(
                  alignment: Alignment.centerRight,
                  child: Text('Add-ons Total: ${money(addOnTotal)}',
                      style: TextStyle(
                          color: cpOnVariant(context),
                          fontWeight: FontWeight.w800))),
          ]),
        ),
      ]);

  Future<void> openAddOnSheet(BuildContext context,
      {Map<String, dynamic>? addOn}) async {
    final result = await showAddOnSheet(context, addOn: addOn);
    if (result == null) return;
    if (addOn == null) {
      draft.addOns.add(result);
    } else {
      addOn
        ..clear()
        ..addAll(result);
    }
    onChanged();
  }
}

class ReviewSummaryChip extends StatelessWidget {
  const ReviewSummaryChip(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: 138,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
            color: cpSurfaceLow(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cpOutlineVariant(context))),
        child: Row(children: [
          Icon(icon, color: cpPrimary(context), size: 19),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: cpOutline(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: cpOnSurface(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ])),
        ]),
      );
}

Future<Map<String, dynamic>?> showAddOnSheet(BuildContext context,
    {Map<String, dynamic>? addOn}) {
  final titleController =
      TextEditingController(text: addOn?['title']?.toString() ?? '');
  final costController = TextEditingController(
      text: ((addOn?['cost'] as num?)?.toInt() ?? 0) > 0
          ? '${(addOn?['cost'] as num).toInt()}'
          : '');
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: BoxDecoration(
              color: cpSurface(context),
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
                            color: cpOutlineVariant(context),
                            borderRadius: BorderRadius.circular(99)))),
                Text(addOn == null ? 'Add Add-on' : 'Edit Add-on',
                    style: TextStyle(
                        color: cpPrimary(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                Text(
                    'Enter a custom title and cost. This amount is added to the event total.',
                    style: TextStyle(color: cpOnVariant(context))),
                const SizedBox(height: 18),
                EditableInlineField(
                    label: 'Add-on Title', controller: titleController),
                EditableInlineField(label: 'Cost', controller: costController),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Cp.secondaryContainer,
                          foregroundColor: const Color(0xff694000)),
                      onPressed: () {
                        final title = titleController.text.trim();
                        final cost =
                            int.tryParse(costController.text.trim()) ?? 0;
                        if (title.isEmpty || cost <= 0) {
                          showCpSnack(context, 'Enter add-on title and cost');
                          return;
                        }
                        Navigator.pop(context, {
                          'id': addOn?['id'] ??
                              'addon_${DateTime.now().microsecondsSinceEpoch}',
                          'title': title,
                          'cost': cost
                        });
                      },
                      child: const Text('Save Add-on',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ]),
              ]),
        ),
      ),
    ),
  ).whenComplete(() {
    titleController.dispose();
    costController.dispose();
  });
}

class DashedAction extends StatelessWidget {
  const DashedAction(
      {super.key,
      required this.label,
      required this.icon,
      this.count = 0,
      this.onTap});
  final String label;
  final IconData icon;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final accent = enabled ? cpPrimary(context) : cpOutline(context);
    final border = enabled ? cpOutline(context) : cpOutlineVariant(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: cpDark(context) ? cpSurface(context) : null,
              border:
                  Border.all(color: border, width: 2, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900)),
            ),
            CountBadge(count: count),
          ])),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$count',
          style: TextStyle(
              color: scheme.onSecondaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w900)),
    );
  }
}

class StepperHeader extends StatelessWidget {
  const StepperHeader({super.key, required this.active, this.onStepTap});
  final int active;
  final ValueChanged<int>? onStepTap;
  @override
  Widget build(BuildContext context) {
    final labels = ['Details', 'Dates', 'Menu', 'Review'];
    return Row(
        children: List.generate(
            labels.length,
            (i) => Expanded(
                child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onStepTap == null ? null : () => onStepTap!(i),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(children: [
                          CircleAvatar(
                              radius: 16,
                              backgroundColor: i <= active
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : cpSurfaceHigh(context),
                              child: Text('${i + 1}',
                                  style: TextStyle(
                                      color: i <= active
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                          : cpOnVariant(context),
                                      fontWeight: FontWeight.w900))),
                          const SizedBox(height: 4),
                          Text(labels[i],
                              style: TextStyle(
                                  color: i <= active
                                      ? cpPrimary(context)
                                      : cpOnVariant(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800))
                        ]))))));
  }
}

class MenuTimeField extends StatelessWidget {
  const MenuTimeField(
      {super.key,
      required this.label,
      required this.value,
      required this.fallback,
      this.iconOnly = false,
      required this.onChanged});
  final String label;
  final String value;
  final String fallback;
  final bool iconOnly;
  final ValueChanged<String> onChanged;

  Future<void> pickTime(BuildContext context) async {
    final picked = await showTimePicker(
        context: context,
        initialTime: parseMenuTimeOfDay(value, fallback: fallback));
    if (picked == null) return;
    onChanged(formatMenuTimeOfDay(picked));
  }

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IconButton.outlined(
          tooltip: value.trim().isEmpty ? fallback : value,
          onPressed: () => pickTime(context),
          icon: Icon(Icons.schedule, color: cpOutline(context)),
          style: IconButton.styleFrom(
            minimumSize: const Size(52, 56),
            side: BorderSide(color: cpOutline(context)),
            backgroundColor: cpDark(context) ? cpSurfaceLow(context) : null,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => pickTime(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
          decoration: BoxDecoration(
              color: cpDark(context) ? cpSurfaceLow(context) : null,
              border: Border.all(color: cpOutline(context)),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text(label,
                      style: TextStyle(
                          color: cpOnVariant(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(value.trim().isEmpty ? fallback : value,
                      style: TextStyle(
                          color: cpOnSurface(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ])),
            Icon(Icons.schedule, color: cpOutline(context)),
          ]),
        ),
      ),
    );
  }
}

class FormFieldBox extends StatefulWidget {
  const FormFieldBox(
      {super.key,
      required this.label,
      required this.value,
      this.icon,
      this.height = 56,
      this.onChanged,
      this.inputFormatters});
  final String label, value;
  final IconData? icon;
  final double height;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<FormFieldBox> createState() => _FormFieldBoxState();
}

class _FormFieldBoxState extends State<FormFieldBox> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant FormFieldBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && controller.text != widget.value) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  TextInputType get keyboardType {
    final label = widget.label.toLowerCase();
    if (label.contains('phone') ||
        label.contains('mobile') ||
        label.contains('member') ||
        label.contains('price') ||
        label.contains('amount') ||
        label.contains('number')) {
      return TextInputType.phone;
    }
    if (label.contains('email')) return TextInputType.emailAddress;
    return widget.height > 70 ? TextInputType.multiline : TextInputType.text;
  }

  @override
  Widget build(BuildContext context) {
    final multiline = widget.height > 70;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        constraints: BoxConstraints(minHeight: widget.height),
        padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
        decoration: BoxDecoration(
            color: cpDark(context) ? cpSurfaceLow(context) : null,
            border: Border.all(color: cpOutline(context)),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment:
              multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                inputFormatters: widget.inputFormatters,
                onChanged: widget.onChanged,
                maxLines: multiline ? null : 1,
                minLines: multiline ? 3 : 1,
                cursorColor: cpPrimary(context),
                style: TextStyle(
                    color: cpOnSurface(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: TextStyle(
                      color: cpOnVariant(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (widget.icon != null)
              Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: Icon(widget.icon, color: cpOutline(context))),
          ],
        ),
      ),
    );
  }
}

class ShareMenuTile extends StatelessWidget {
  const ShareMenuTile(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
                color: cpCard(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cpOutlineVariant(context))),
            child: Row(children: [
              SizedBox(width: 24, height: 24, child: Center(child: icon)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: cpPrimary(context),
                          fontWeight: FontWeight.w900))),
              Icon(Icons.chevron_right, color: cpOutline(context)),
            ]),
          ),
        ),
      );
}
