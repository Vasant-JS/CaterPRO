part of '../main.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen(
      {super.key,
      required this.events,
      required this.loading,
      required this.openDetails,
      required this.openCreate,
      required this.refresh});
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
  String query = '';
  String? clientFilter;
  String? dateFilter;
  bool showPastEvents = true;
  bool showOverduePayments = false;
  String paymentFilter = 'All';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
      if (!showPastEvents &&
          event.dates.any(
              (date) => _parseDate(date.date)?.isBefore(todayOnly) ?? false)) {
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

  Future<void> chooseClient() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
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
                ...clientOptions.map((client) => ListTile(
                    leading: Icon(
                        client == clientFilter
                            ? Icons.check_circle
                            : Icons.person,
                        color: Cp.primary),
                    title: Text(client),
                    onTap: () => Navigator.pop(context, client))),
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
    setState(() => dateFilter =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
  }

  void clearFilters() {
    setState(() {
      clientFilter = null;
      dateFilter = null;
      showPastEvents = true;
      showOverduePayments = false;
      paymentFilter = 'All';
      query = '';
      searchController.clear();
    });
  }

  PopupMenuItem<String> filterMenuItem(
      String value, IconData icon, String label,
      {bool selected = false}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(selected ? Icons.check_circle : icon,
            color: selected ? Cp.tertiaryContainer : Cp.primary),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = filteredEvents;
    final fieldBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cpOutlineVariant(context)));
    return ScreenFrame(
      topBar: TopBar(title: 'Events', actions: [
        IconButton(onPressed: widget.refresh, icon: const Icon(Icons.refresh)),
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
            filterMenuItem('past', Icons.history,
                showPastEvents ? 'Hide Past Events' : 'Show Past Events',
                selected: !showPastEvents),
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
        IconButton(
            onPressed: widget.openCreate,
            icon: const Icon(Icons.add, color: Cp.toolbarIcon)),
      ]),
      children: [
        TextField(
          controller: searchController,
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
          if (paymentFilter != 'All')
            Pill(paymentFilter,
                color: Cp.surfaceHigh,
                textColor: Cp.onVariant,
                icon: Icons.payments),
          if (!showPastEvents ||
              showOverduePayments ||
              clientFilter != null ||
              dateFilter != null ||
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
                          child: Text(' $client • $phone',
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
