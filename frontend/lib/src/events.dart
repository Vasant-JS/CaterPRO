part of '../main.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen(
      {super.key,
      required this.api,
      required this.resetToken,
      required this.events,
      required this.loading,
      required this.openDetails,
      required this.openCreate,
      required this.refresh});
  final ApiService api;
  final int resetToken;
  final List<AppEvent> events;
  final bool loading;
  final ValueChanged<AppEvent> openDetails;
  final VoidCallback openCreate;
  final VoidCallback refresh;

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final searchController = TextEditingController();
  final dateChipScrollController = ScrollController();
  final dateChipKeys = List.generate(15, (_) => GlobalKey());
  String query = '';
  String? clientFilter;
  String? dateFilter;
  DateTimeRange? dateRangeFilter;
  bool showPastEvents = false;
  bool showOverduePayments = false;
  String paymentFilter = 'All';
  static const shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollChipsToToday());
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.resetToken != oldWidget.resetToken) {
      resetFilters();
      scrollChipsToToday();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    dateChipScrollController.dispose();
    super.dispose();
  }

  void scrollChipsToToday() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = dateChipKeys[0].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0,
          duration: const Duration(milliseconds: 1),
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
        return;
      }
      if (!dateChipScrollController.hasClients) return;
      dateChipScrollController.jumpTo(0);
    });
  }

  List<String> get clientOptions {
    final clients = widget.events
        .map((event) =>
            event.primaryClient.isEmpty ? event.name : event.primaryClient)
        .where((client) => client.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return clients;
  }

  List<AppEvent> get filteredEvents {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return widget.events.where((event) {
      final client =
          event.primaryClient.isEmpty ? event.name : event.primaryClient;
      final haystack = '${event.name} $client ${event.mobile}'.toLowerCase();
      if (query.isNotEmpty && !haystack.contains(query.toLowerCase())) {
        return false;
      }
      if (clientFilter != null && client != clientFilter) return false;
      if (dateFilter != null &&
          !event.dates.any((date) => date.date == dateFilter)) {
        return false;
      }
      if (dateRangeFilter != null &&
          !event.dates.any((date) {
            final parsed = _parseDate(date.date);
            if (parsed == null) return false;
            final start = DateTime(dateRangeFilter!.start.year,
                dateRangeFilter!.start.month, dateRangeFilter!.start.day);
            final end = DateTime(dateRangeFilter!.end.year,
                dateRangeFilter!.end.month, dateRangeFilter!.end.day);
            return !parsed.isBefore(start) && !parsed.isAfter(end);
          })) {
        return false;
      }
      final hasCurrentOrFutureDate = event.dates.any((date) {
        final parsed = _parseDate(date.date);
        return parsed != null && !parsed.isBefore(todayOnly);
      });
      if (!showPastEvents &&
          dateFilter == null &&
          dateRangeFilter == null &&
          !hasCurrentOrFutureDate) {
        return false;
      }
      final balance = eventBalance(event);
      if (paymentFilter == 'Paid' && balance != 0) return false;
      if (paymentFilter == 'Unpaid' && balance == 0) return false;
      if (showOverduePayments &&
          !(balance > 0 &&
              event.dates.any((date) =>
                  _parseDate(date.date)?.isBefore(todayOnly) ?? false))) {
        return false;
      }
      return true;
    }).toList();
  }

  DateTime? _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _dateChipLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}, ${shortMonths[date.month - 1]}';

  String _rangeLabel(DateTimeRange range) =>
      '${_dateKey(range.start)} to ${_dateKey(range.end)}';

  List<DateTime> get dateChipDates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(15, (index) => today.add(Duration(days: index)));
  }

  void toggleDateFilter(DateTime date) {
    final key = _dateKey(date);
    setState(() {
      dateFilter = dateFilter == key ? null : key;
      if (dateFilter != null) dateRangeFilter = null;
    });
  }

  Future<void> chooseClient() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * .72),
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
                Text('Filter Client',
                    style: TextStyle(
                        color: cpPrimary(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                ListTile(
                    leading: const Icon(Icons.all_inclusive, color: Cp.primary),
                    title: const Text('All Clients'),
                    onTap: () => Navigator.pop(context, null)),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: clientOptions
                        .map((client) => ListTile(
                            leading: Icon(
                                client == clientFilter
                                    ? Icons.check_circle
                                    : Icons.person,
                                color: Cp.primary),
                            title: Text(client),
                            onTap: () => Navigator.pop(context, client)))
                        .toList(),
                  ),
                ),
              ]),
        ),
      ),
    );
    if (mounted) setState(() => clientFilter = selected);
  }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
        initialDate: DateTime.now());
    if (picked == null) return;
    setState(() {
      dateFilter = _dateKey(picked);
      dateRangeFilter = null;
    });
  }

  Future<void> chooseDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: dateRangeFilter ??
          DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: DateTime(now.year, now.month, now.day),
          ),
    );
    if (picked == null) return;
    setState(() {
      dateRangeFilter = picked;
      dateFilter = null;
    });
  }

  void clearFilters() {
    setState(() {
      resetFilters();
    });
  }

  void resetFilters() {
    clientFilter = null;
    dateFilter = null;
    dateRangeFilter = null;
    showPastEvents = false;
    showOverduePayments = false;
    paymentFilter = 'All';
    query = '';
    searchController.clear();
  }

  PopupMenuItem<String> filterMenuItem(
      String value, IconData icon, String label,
      {bool selected = false}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(selected ? Icons.check_circle : icon,
            color: selected ? Cp.toolbarIcon : cpOnSurface(context)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
  }

  Future<void> downloadConsolidatedMenus(
      BuildContext context, List<AppEvent> visibleEvents) async {
    if (visibleEvents.isEmpty) {
      showCpSnack(context, 'No events available for consolidated menu');
      return;
    }
    try {
      showCpSnack(context, 'Preparing consolidated menu...');
      final uri = await widget.api.createConsolidatedMenusUri(
          events: visibleEvents,
          date: dateFilter,
          startDate:
              dateRangeFilter == null ? null : _dateKey(dateRangeFilter!.start),
          endDate:
              dateRangeFilter == null ? null : _dateKey(dateRangeFilter!.end),
          title: dateFilter == null
              ? dateRangeFilter == null
                  ? 'Events Consolidated Menus'
                  : 'Events Consolidated Menus - ${_rangeLabel(dateRangeFilter!)}'
              : 'Events Consolidated Menus - $dateFilter');
      if (!context.mounted) return;
      showDownloadSnack(context, uri,
          title: 'Consolidated menus.pdf',
          kind: 'menu',
          successMessage: 'Consolidated menu download started',
          failureMessage: 'Unable to start consolidated menu download');
    } catch (error) {
      if (context.mounted) {
        showCpSnack(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = filteredEvents;
    final fieldBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cpOutlineVariant(context)));
    return ScreenFrame(
      topBar: TopBar(title: 'Events', actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list, color: Cp.primary),
          tooltip: 'Filter events',
          onSelected: (value) {
            switch (value) {
              case 'client':
                chooseClient();
                break;
              case 'date':
                chooseDate();
                break;
              case 'date-range':
                chooseDateRange();
                break;
              case 'past':
                setState(() => showPastEvents = !showPastEvents);
                break;
              case 'overdue':
                setState(() => showOverduePayments = !showOverduePayments);
                break;
              case 'paid':
                setState(() =>
                    paymentFilter = paymentFilter == 'Paid' ? 'All' : 'Paid');
                break;
              case 'unpaid':
                setState(() => paymentFilter =
                    paymentFilter == 'Unpaid' ? 'All' : 'Unpaid');
                break;
              case 'clear':
                clearFilters();
                break;
            }
          },
          itemBuilder: (context) => [
            filterMenuItem(
                'client',
                Icons.person_search,
                clientFilter == null
                    ? 'Filter Client'
                    : 'Client: $clientFilter',
                selected: clientFilter != null),
            filterMenuItem('date', Icons.event,
                dateFilter == null ? 'Filter Date' : 'Date: $dateFilter',
                selected: dateFilter != null),
            filterMenuItem(
                'date-range',
                Icons.date_range,
                dateRangeFilter == null
                    ? 'Filter Date Range'
                    : 'Range: ${_rangeLabel(dateRangeFilter!)}',
                selected: dateRangeFilter != null),
            filterMenuItem('past', Icons.history, 'Show Old Events',
                selected: showPastEvents),
            filterMenuItem(
                'overdue', Icons.warning_amber, 'Show Overdue Payments',
                selected: showOverduePayments),
            const PopupMenuDivider(),
            filterMenuItem('paid', Icons.check_circle, 'Payment Status: Paid',
                selected: paymentFilter == 'Paid'),
            filterMenuItem('unpaid', Icons.cancel, 'Payment Status: Unpaid',
                selected: paymentFilter == 'Unpaid'),
            const PopupMenuDivider(),
            filterMenuItem('clear', Icons.filter_alt_off, 'Clear Filters'),
          ],
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Cp.toolbarIcon),
          tooltip: 'Event options',
          onSelected: (value) {
            switch (value) {
              case 'refresh':
                widget.refresh();
                break;
              case 'consolidated-menu':
                downloadConsolidatedMenus(context, visible);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'refresh',
              child: Row(children: [
                Icon(Icons.refresh, color: cpOnSurface(context)),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text('Refresh',
                        style: TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
            PopupMenuItem<String>(
              value: 'consolidated-menu',
              enabled: visible.isNotEmpty,
              child: Row(children: [
                Icon(Icons.picture_as_pdf,
                    color: visible.isEmpty
                        ? cpOutline(context)
                        : cpOnSurface(context)),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text('Consolidated Menu PDF',
                        style: TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
          ],
        ),
      ]),
      children: [
        TextField(
          scrollPadding: cpTextFieldScrollPadding(context),
          controller: searchController,
          textCapitalization: cpTextCapitalizationForField(
              hint: 'Search by event or client name'),
          onChanged: (value) => setState(() => query = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search by event or client name',
            prefixIcon: Icon(Icons.search, color: cpOutline(context)),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(() {
                          query = '';
                          searchController.clear();
                        }),
                    icon: const Icon(Icons.close)),
            filled: true,
            fillColor: cpCard(context),
            border: fieldBorder,
            enabledBorder: fieldBorder,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          controller: dateChipScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: dateChipDates.asMap().entries.map((entry) {
              final index = entry.key;
              final date = entry.value;
              final key = _dateKey(date);
              final selected = dateFilter == key;
              return Padding(
                key: dateChipKeys[index],
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_dateChipLabel(date)),
                  selected: selected,
                  onSelected: (_) => toggleDateFilter(date),
                  selectedColor: cpPrimary(context),
                  backgroundColor: cpCard(context),
                  side: BorderSide(
                      color: selected
                          ? cpPrimary(context)
                          : cpOutlineVariant(context)),
                  labelStyle: TextStyle(
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : cpOnSurface(context),
                      fontWeight: FontWeight.w800),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill('${visible.length} shown',
              color: Cp.primary.withValues(alpha: .1), textColor: Cp.primary),
          if (clientFilter != null)
            Pill(clientFilter!,
                color: Cp.surfaceHigh,
                textColor: Cp.onVariant,
                icon: Icons.person),
          if (dateFilter != null)
            Pill(dateFilter!,
                color: Cp.surfaceHigh,
                textColor: Cp.onVariant,
                icon: Icons.event),
          if (dateRangeFilter != null)
            Pill(_rangeLabel(dateRangeFilter!),
                color: Cp.surfaceHigh,
                textColor: Cp.onVariant,
                icon: Icons.date_range),
          if (paymentFilter != 'All')
            Pill(paymentFilter,
                color: Cp.surfaceHigh,
                textColor: Cp.onVariant,
                icon: Icons.payments),
          if (showPastEvents)
            const Pill('Old events',
                color: Cp.surfaceHigh,
                textColor: Cp.onVariant,
                icon: Icons.history),
          if (showPastEvents ||
              showOverduePayments ||
              clientFilter != null ||
              dateFilter != null ||
              dateRangeFilter != null ||
              paymentFilter != 'All' ||
              query.isNotEmpty)
            InkWell(
                onTap: clearFilters,
                child: const Pill('Clear',
                    color: Cp.errorContainer,
                    textColor: Cp.error,
                    icon: Icons.close)),
        ]),
        const SizedBox(height: 16),
        if (widget.loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()))
        else if (widget.events.isEmpty)
          EmptyStateCard(
              title: 'No events added',
              message: 'Use Create Event to add the first event from scratch.',
              actionLabel: 'Create Event',
              onAction: widget.openCreate)
        else if (visible.isEmpty)
          const EmptyStateCard(
              title: 'No matching events',
              message: 'Try changing the search or filter options.')
        else
          ...visible.map((event) {
            final meals = event.dates
                .expand((date) => date.menuSlots.map((slot) => slot.type))
                .toSet()
                .toList();
            final dateText = event.dates.isEmpty
                ? 'No dates'
                : event.dates.map((date) => date.date).join(', ');
            final balance = eventBalance(event);
            return EventListCard(
                title: event.name,
                client: event.primaryClient.isEmpty
                    ? event.name
                    : event.primaryClient,
                phone: event.mobile,
                dates: dateText,
                amount: money(eventTotal(event)),
                balance: balance == 0 ? 'Paid' : '${money(balance)} due',
                status: balance == 0 ? 'PAID' : 'UNPAID',
                meals: meals,
                onTap: () => widget.openDetails(event));
          }),
      ],
    );
  }
}

class ChipRow extends StatefulWidget {
  const ChipRow(this.labels, {super.key});
  final List<String> labels;

  @override
  State<ChipRow> createState() => _ChipRowState();
}

class _ChipRowState extends State<ChipRow> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(widget.labels.length, (i) {
          final selected = i == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                setState(() => selectedIndex = i);
                showCpSnack(context, '${widget.labels[i]} selected');
              },
              child: Pill(widget.labels[i],
                  color: selected ? Cp.primaryContainer : Cp.surfaceHigh,
                  textColor: selected ? Colors.white : Cp.onVariant,
                  icon: selected ? Icons.check : null),
            ),
          );
        }),
      ),
    );
  }
}

class EventListCard extends StatelessWidget {
  const EventListCard(
      {super.key,
      required this.title,
      required this.client,
      required this.phone,
      required this.dates,
      required this.amount,
      required this.balance,
      required this.status,
      required this.meals,
      this.onTap});
  final String title, client, phone, dates, amount, balance, status;
  final List<String> meals;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final pending = status != 'PAID';
    final scheme = Theme.of(context).colorScheme;
    final titleColor =
        pending && !cpDark(context) ? Cp.primary : cpPrimary(context);
    final mutedColor = cpOnVariant(context);
    final balanceColor = balance.startsWith('Paid')
        ? cpAdaptTextColor(context, Cp.tertiary)
        : pending
            ? scheme.onErrorContainer
            : cpAdaptTextColor(context, Cp.error);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        color: pending ? const Color(0xffffebeb) : Cp.card,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 18,
                            color: titleColor,
                            fontWeight: FontWeight.w800)),
                    Row(children: [
                      Icon(Icons.person, size: 16, color: mutedColor),
                      Flexible(
                          child: Text(' $client | $phone',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: mutedColor,
                                  fontWeight: FontWeight.w600)))
                    ])
                  ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Pill(status,
                    color: pending ? Cp.secondaryContainer : Cp.tertiaryFixed,
                    textColor: pending ? Color(0xff694000) : Color(0xff00210c)),
                const SizedBox(height: 6),
                Text(amount,
                    style: TextStyle(
                        color: cpAdaptTextColor(context, Cp.primaryContainer),
                        fontWeight: FontWeight.w900)),
                Text(balance,
                    style: TextStyle(
                        color: balanceColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12))
              ]),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.calendar_today, size: 18, color: mutedColor),
              Text(' $dates',
                  style:
                      TextStyle(color: mutedColor, fontWeight: FontWeight.w700))
            ]),
            const SizedBox(height: 12),
            Wrap(
                spacing: 8,
                children: meals
                    .map((m) =>
                        Pill(m, color: Cp.surfaceHigh, textColor: Cp.onSurface))
                    .toList()),
          ],
        ),
      ),
    );
  }
}
