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
      required this.customerEvents,
      required this.onSaveService,
      required this.onDeleteService});
  final AppEvent? initialEvent;
  final ValueChanged<AppEvent> onDraftSaved;
  final VoidCallback onClose;
  final Future<void> Function(EventDraft draft) onCreate;
  final List<AdditionalServiceItem> services;
  final List<CustomMenu> customMenus;
  final List<AppEvent> customerEvents;
  final ValueChanged<AdditionalServiceItem> onSaveService;
  final ValueChanged<String> onDeleteService;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final api = ApiService();
  int step = 0;
  bool saving = false;
  bool autosaving = false;
  String? error;
  late final EventDraft draft;

  @override
  void initState() {
    super.initState();
    draft = widget.initialEvent == null
        ? EventDraft()
        : EventDraft.fromEvent(widget.initialEvent!);
  }

  List<CustomerSuggestion> get customerSuggestions {
    final byMobile = <String, CustomerSuggestion>{};
    for (final event in widget.customerEvents) {
      final mobile = normalizeMobileNumber(event.mobile);
      if (mobile.isEmpty) continue;
      final name =
          event.primaryClient.isEmpty ? event.name : event.primaryClient;
      byMobile[mobile] = CustomerSuggestion(name: name, mobile: mobile);
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
    if (draft.name.trim().isEmpty) return 'Event name is required.';
    if (draft.client.trim().isEmpty) return 'Primary client is required.';
    if (draft.mobile.trim().isEmpty) return 'Mobile number is required.';
    if (draft.mobile.length != 10) return 'Mobile number must be 10 digits.';
    return null;
  }

  String? validateEventForFinalSave() {
    final detailsError = validateDetails();
    if (detailsError != null) return detailsError;
    if (draft.dates.isEmpty) return 'Add at least one event date.';
    for (final date in draft.dates) {
      final dateError =
          isoDateValidator(date.date, label: 'Event date', noPast: true);
      if (dateError != null) return dateError;
      for (final slot in date.slots.where((item) => item.enabled)) {
        final pax = int.tryParse(slot.pax.trim()) ?? 0;
        if (pax <= 0) return '${slot.type} members must be more than zero.';
        if (slot.pricePerPax <= 0) {
          return '${slot.type} price per member must be more than zero.';
        }
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

  @override
  Widget build(BuildContext context) {
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
            icon: const Icon(Icons.arrow_back, color: Cp.primary)),
        actions: [
          if (autosaving)
            const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Cp.primary))))
        ],
      ),
      children: [
        StepperHeader(active: step),
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
              onChanged: () => setState(() => error = null)),
        if (step == 1)
          CreateDatesStep(
              dates: draft.dates,
              onChanged: () {
                setState(() {});
                autosaveDraft();
              }),
        if (step == 2)
          CreateMenuStep(
              dates: draft.dates,
              services: widget.services,
              customMenus: widget.customMenus,
              onChanged: () => autosaveDraft(),
              onSaveService: widget.onSaveService,
              onDeleteService: widget.onDeleteService),
        if (step == 3)
          CreateReviewStep(
              draft: draft,
              onChanged: () {
                setState(() {});
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
                      backgroundColor: Cp.primaryContainer),
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

  void updateMatches(String value) {
    final q = value.trim().toLowerCase();
    setState(() {
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
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      CpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.assignment, color: Cp.primary),
            SizedBox(width: 8),
            Text('Event Fundamentals',
                style: TextStyle(
                    fontSize: 20,
                    color: Cp.primary,
                    fontWeight: FontWeight.w800))
          ]),
          const SizedBox(height: 20),
          FormFieldBox(
              label: 'Event Name',
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
              updateMatches(value);
              widget.onChanged();
            },
          ),
          if (matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: Cp.surfaceLow,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: matches
                      .map((customer) => ListTile(
                            dense: true,
                            leading:
                                const Icon(Icons.person, color: Cp.primary),
                            title: Text(customer.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            subtitle: Text(customer.mobile),
                            onTap: () => selectCustomer(customer),
                          ))
                      .toList(),
                ),
              ),
            ),
          FormFieldBox(
              label: 'Mobile Number (Unique Customer ID)',
              value: widget.draft.mobile,
              icon: Icons.phone_iphone,
              inputFormatters: mobileInputFormatters,
              onChanged: (value) {
                widget.draft.mobile = normalizeMobileNumber(value);
                updateMatches(widget.draft.mobile);
                widget.onChanged();
              }),
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
      const Text('Event Dates',
          style: TextStyle(
              color: Cp.primary, fontSize: 24, fontWeight: FontWeight.w900)),
      const Text(
          'Add every date in the event schedule. Members are configured later for each date and menu type.',
          style: TextStyle(color: Cp.onVariant)),
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
              dates.add(date);
              onChanged();
            }
          }),
    ]);
  }
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
                const Text('Add Event Date',
                    style: TextStyle(
                        color: Cp.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const Text('Select a date. Previous dates are disabled.',
                    style: TextStyle(color: Cp.onVariant)),
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
                              DraftDateConfig(
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
            child: Row(children: [
          Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: Cp.primaryFixed,
                  borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                Text(month,
                    style: const TextStyle(
                        color: Cp.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
                Text(day,
                    style: const TextStyle(
                        color: Cp.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900))
              ])),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w900)),
                Text(summary,
                    style: const TextStyle(
                        color: Cp.onVariant, fontWeight: FontWeight.w700))
              ])),
          if (onDelete != null)
            IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, color: Cp.error))
        ])),
      );
}

class CreateMenuStep extends StatefulWidget {
  const CreateMenuStep(
      {super.key,
      required this.dates,
      required this.services,
      required this.customMenus,
      required this.onChanged,
      required this.onSaveService,
      required this.onDeleteService});
  final List<DraftDateConfig> dates;
  final List<AdditionalServiceItem> services;
  final List<CustomMenu> customMenus;
  final VoidCallback onChanged;
  final ValueChanged<AdditionalServiceItem> onSaveService;
  final ValueChanged<String> onDeleteService;

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
            selectedColor: Cp.primaryContainer,
            labelStyle: TextStyle(
                color: selected ? Colors.white : Cp.onVariant,
                fontWeight: FontWeight.w800),
            onSelected: (_) => setState(() => selectedDateIndex = index),
          );
        }),
      ),
      const SizedBox(height: 16),
      if (config.slots.isEmpty)
        CpCard(
          color: Cp.surfaceLow,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.event_note, color: Cp.outline),
                SizedBox(height: 10),
                Text('No menu configured for this date yet.',
                    style: TextStyle(
                        color: Cp.primary, fontWeight: FontWeight.w900)),
                Text(
                    'Add only the menu types and services needed for this date.',
                    style: TextStyle(color: Cp.onVariant)),
              ]),
        )
      else
        ...config.slots.map((slot) => MealSlotCard(
              key: ValueKey('${config.label}-${slot.type}'),
              slot: slot,
              items: selectedMenuTitles(slot),
              onEnabledChanged: (value) {
                setState(() => slot.enabled = value);
                widget.onChanged();
              },
              onPaxChanged: (value) {
                setState(() => slot.pax = value);
                widget.onChanged();
              },
              onPriceChanged: (value) {
                setState(() => slot.pricePerPax = int.tryParse(value) ?? 0);
                widget.onChanged();
              },
              onEditMenu: () => openMenuPicker(slot),
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
      const Text('Additional Services',
          style: TextStyle(color: Cp.onVariant, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      if (config.additionalServices.isEmpty)
        const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('No additional services for this date.',
                style: TextStyle(
                    color: Cp.onVariant, fontStyle: FontStyle.italic)))
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
          label: 'Add Service',
          icon: Icons.add_circle,
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

  void openMealTypePicker() {
    const availableTypes = [
      ('Breakfast', '8:00 AM', 0),
      ('Juice', '5:00 PM', 0),
      ('Lunch', '1:30 PM', 0),
      ('Snack', '4:30 PM', 0),
      ('Dinner', '8:00 PM', 0),
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
                Text('Add Menu Type for ${readableDateLabel(config.date)}',
                    style: const TextStyle(
                        color: Cp.primary,
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
                              color: exists ? Cp.outline : Cp.primary),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  exists ? '${type.$1} already added' : type.$1,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900))),
                          Text(type.$2,
                              style: const TextStyle(
                                  color: Cp.onVariant,
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
      this.enabled = true})
      : selectedMenuIds = selectedMenuIds ?? <String>{};

  String? id;
  final String type;
  final String time;
  String pax;
  int pricePerPax;
  Set<String> selectedMenuIds;
  bool enabled;

  factory MealSlotConfig.fromEventSlot(AppMenuSlot slot) {
    return MealSlotConfig(
        id: slot.id,
        type: slot.type,
        time: slot.time,
        pax: slot.pax.toString(),
        pricePerPax: slot.pricePerPax,
        selectedMenuIds: slot.menuItemIds.toSet(),
        enabled: slot.enabled);
  }

  Map<String, dynamic> toJson() => {
        if (id != null && id!.isNotEmpty) 'id': id,
        'type': type,
        'time': time,
        'pax': int.tryParse(pax) ?? 0,
        'pricePerPax': pricePerPax,
        'enabled': enabled,
        'menuItemIds': selectedMenuIds.toList(),
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
        decoration: const BoxDecoration(
            color: Cp.surface,
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
                          color: Cp.outlineVariant,
                          borderRadius: BorderRadius.circular(99)))),
              const Text('Add Service',
                  style: TextStyle(
                      color: Cp.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const Text('Choose services from Settings > Additional Services.',
                  style: TextStyle(color: Cp.onVariant)),
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
                                    color: selected ? Cp.primary : Cp.outline)),
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
                      backgroundColor: Cp.primaryContainer),
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
  late Set<String> selectedIds;
  String query = '';

  @override
  void initState() {
    super.initState();
    selectedIds = {...widget.selectedIds};
  }

  @override
  Widget build(BuildContext context) {
    final items = MenuMasterScreen.menuItems
        .where((item) =>
            item.title.toLowerCase().contains(query.toLowerCase()) ||
            item.english.toLowerCase().contains(query.toLowerCase()) ||
            item.kannada.contains(query))
        .toList()
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
      backgroundColor: Cp.background,
      appBar: AppBar(
        backgroundColor: Cp.surface,
        foregroundColor: Cp.primary,
        title: Text('Select ${widget.meal} Menu'),
        actions: [
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
          DashedAction(
              label: 'Select From Ready Made Menus',
              icon: Icons.fact_check,
              onTap: openReadyMadeMenuPicker),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search menu items',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            final selected = selectedIds.contains(item.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CpCard(
                color: selected ? Cp.primaryFixed : Cp.card,
                onTap: () => setState(() => selected
                    ? selectedIds.remove(item.id)
                    : selectedIds.add(item.id)),
                child: Row(children: [
                  Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                      color: selected ? Cp.primary : Cp.outline),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(item.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                        Text('${item.id} • ${item.category} • ${item.meals}',
                            style: const TextStyle(color: Cp.onVariant))
                      ])),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  void openReadyMadeMenuPicker() {
    final menus = widget.customMenus
        .where((menu) => menu.type == widget.meal)
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
          decoration: const BoxDecoration(
              color: Cp.surface,
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
                            color: Cp.outlineVariant,
                            borderRadius: BorderRadius.circular(99)))),
                Text('Ready Made ${widget.meal} Menus',
                    style: const TextStyle(
                        color: Cp.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const Text(
                    'Selecting one will add all its items. You can still add extra items below.',
                    style: TextStyle(color: Cp.onVariant)),
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
                            const Icon(Icons.playlist_add_check,
                                color: Cp.primary),
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
      required this.onEnabledChanged,
      required this.onPaxChanged,
      required this.onPriceChanged,
      required this.onEditMenu,
      required this.onDelete});
  final MealSlotConfig slot;
  final List<String> items;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onPaxChanged;
  final ValueChanged<String> onPriceChanged;
  final VoidCallback onEditMenu;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final enabled = slot.enabled;
    return Opacity(
      opacity: enabled ? 1 : .58,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          color: enabled ? Cp.card : Cp.surfaceLow,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.restaurant_menu,
                  color: enabled ? Cp.primary : Cp.outline),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(slot.type,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    Text(
                        enabled
                            ? '${slot.time} • ${slot.pax.isEmpty ? 0 : slot.pax} Members'
                            : 'Not Scheduled • 0 Members',
                        style: const TextStyle(color: Cp.onVariant))
                  ])),
              IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Cp.error)),
              Switch(
                  value: enabled,
                  activeThumbColor: Cp.primary,
                  onChanged: onEnabledChanged),
            ]),
            if (enabled) ...[
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: FormFieldBox(
                        label: '${slot.type} Members',
                        value: slot.pax,
                        icon: Icons.person,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: onPaxChanged)),
                const SizedBox(width: 12),
                Expanded(
                    child: FormFieldBox(
                        label: 'Price / Member',
                        value:
                            slot.pricePerPax == 0 ? '' : '${slot.pricePerPax}',
                        icon: Icons.currency_rupee,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onChanged: onPriceChanged)),
              ]),
            ],
            if (enabled) ...[
              const SizedBox(height: 12),
              if (items.isEmpty)
                const Text('No menu items selected.',
                    style: TextStyle(
                        color: Cp.onVariant, fontStyle: FontStyle.italic))
              else
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items
                        .map((e) => Pill(e, color: Cp.surfaceHigh))
                        .toList()),
              const Divider(height: 24),
              Row(children: [
                Text('₹${slot.pricePerPax}/member',
                    style: const TextStyle(
                        color: Cp.primary, fontWeight: FontWeight.w900)),
                const Spacer(),
                InkWell(
                    onTap: onEditMenu,
                    child: const Row(children: [
                      Icon(Icons.edit, color: Cp.primary, size: 18),
                      Text(' Edit Menu',
                          style: TextStyle(
                              color: Cp.primary, fontWeight: FontWeight.w800))
                    ]))
              ]),
            ],
            if (!enabled)
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Menu slot is currently disabled.',
                      style: TextStyle(
                          color: Cp.onVariant, fontStyle: FontStyle.italic))),
          ]),
        ),
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
  int get serviceTotal => draft.dates.fold(
      0,
      (dateSum, date) =>
          dateSum +
          date.additionalServices.fold(
              0,
              (sum, service) =>
                  sum + ((service['price'] as num?)?.toInt() ?? 0)));
  int get addOnTotal => draft.addOns
      .fold(0, (sum, addOn) => sum + ((addOn['cost'] as num?)?.toInt() ?? 0));
  int get grandTotal => menuTotal + serviceTotal + addOnTotal;

  @override
  Widget build(BuildContext context) => Column(children: [
        CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(draft.name.isEmpty ? 'Untitled Event' : draft.name,
              style: const TextStyle(
                  color: Cp.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          Text('${draft.client} • ${draft.mobile}',
              style: const TextStyle(color: Cp.onVariant)),
          const Divider(),
          Wrap(spacing: 18, runSpacing: 12, children: [
            InfoTile(Icons.currency_rupee, 'Total Amount', money(grandTotal)),
            InfoTile(Icons.restaurant_menu, 'Menu',
                menuTotal > 0 ? money(menuTotal) : 'Not priced'),
            InfoTile(Icons.room_service, 'Services',
                serviceTotal > 0 ? money(serviceTotal) : 'None'),
            InfoTile(Icons.add_card, 'Add-ons',
                addOnTotal > 0 ? money(addOnTotal) : 'None'),
            InfoTile(Icons.calendar_today, 'Dates', '${draft.dates.length}'),
            InfoTile(Icons.restaurant_menu, 'Menu Slots',
                '${draft.dates.fold<int>(0, (sum, date) => sum + date.slots.length)}'),
            InfoTile(Icons.location_on, 'Venue',
                draft.venue.isEmpty ? 'Not set' : draft.venue)
          ])
        ])),
        const SizedBox(height: 12),
        CpCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Text('Add-ons',
                      style: TextStyle(
                          color: Cp.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900))),
              TextButton.icon(
                  onPressed: () => openAddOnSheet(context),
                  icon: const Icon(Icons.add_circle),
                  label: const Text('Add Add-on')),
            ]),
            const Text(
                'Optional custom costs like service, decorations, printing, transport, etc.',
                style: TextStyle(color: Cp.onVariant)),
            const SizedBox(height: 12),
            if (draft.addOns.isEmpty)
              const Text('No add-ons added.',
                  style: TextStyle(
                      color: Cp.onVariant, fontStyle: FontStyle.italic))
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
                            icon: const Icon(Icons.edit, color: Cp.primary)),
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
                    style: const TextStyle(
                        color: Cp.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900))),
            if (draft.addOns.isNotEmpty)
              Align(
                  alignment: Alignment.centerRight,
                  child: Text('Add-ons Total: ${money(addOnTotal)}',
                      style: const TextStyle(
                          color: Cp.onVariant, fontWeight: FontWeight.w800))),
          ]),
        ),
        const SizedBox(height: 12),
        CpCard(
            color: Cp.primaryContainer,
            child: const Text('Event will be saved to your account via API.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900))),
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
                Text(addOn == null ? 'Add Add-on' : 'Edit Add-on',
                    style: const TextStyle(
                        color: Cp.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const Text(
                    'Enter a custom title and cost. This amount is added to the event total.',
                    style: TextStyle(color: Cp.onVariant)),
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
      {super.key, required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                border: Border.all(
                    color: Cp.outlineVariant,
                    width: 2,
                    style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: Cp.primary),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Cp.primary, fontWeight: FontWeight.w900))
            ])),
      );
}

class StepperHeader extends StatelessWidget {
  const StepperHeader({super.key, required this.active});
  final int active;
  @override
  Widget build(BuildContext context) {
    final labels = ['Details', 'Dates', 'Menu', 'Review'];
    return Row(
        children: List.generate(
            labels.length,
            (i) => Expanded(
                    child: Column(children: [
                  CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          i <= active ? Cp.primaryContainer : Cp.surfaceHigh,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: i <= active ? Colors.white : Cp.onVariant,
                              fontWeight: FontWeight.w900))),
                  const SizedBox(height: 4),
                  Text(labels[i],
                      style: TextStyle(
                          color: i <= active ? Cp.primary : Cp.onVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w800))
                ]))));
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
            border: Border.all(color: Cp.outline),
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
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: const TextStyle(
                      color: Cp.primary,
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
                  child: Icon(widget.icon, color: Cp.outline)),
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
  final IconData icon;
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
                color: Cp.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Cp.outlineVariant)),
            child: Row(children: [
              Icon(icon, color: Cp.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: Cp.primary, fontWeight: FontWeight.w900))),
              const Icon(Icons.chevron_right, color: Cp.outline),
            ]),
          ),
        ),
      );
}
