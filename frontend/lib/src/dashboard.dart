part of '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key,
      required this.api,
      required this.events,
      required this.loading,
      required this.openCreate,
      required this.openEvents,
      required this.openClients,
      required this.openBilling,
      required this.openEmployees,
      required this.openInvoice,
      required this.openCustomMenus,
      required this.openLists,
      required this.openDetails,
      required this.refresh});
  final ApiService api;
  final List<AppEvent> events;
  final bool loading;
  final VoidCallback openCreate;
  final VoidCallback openEvents;
  final VoidCallback openClients;
  final VoidCallback openBilling;
  final VoidCallback openEmployees;
  final VoidCallback openInvoice;
  final VoidCallback openCustomMenus;
  final VoidCallback openLists;
  final ValueChanged<AppEvent> openDetails;
  final VoidCallback refresh;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int upcomingDurationDays = 3;
  static const upcomingDurationOptions = [
    (label: 'Tomorrow', days: 1),
    (label: 'Next 3 days', days: 3),
    (label: 'Next 7 days', days: 7),
    (label: 'Next 15 days', days: 15),
    (label: 'Next 30 days', days: 30),
  ];

  bool upcomingDate(AppEventDate date) {
    final parsed = parseIsoDate(date.date);
    if (parsed == null) return false;
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final end = tomorrow.add(Duration(days: upcomingDurationDays - 1));
    return !parsed.isBefore(tomorrow) && !parsed.isAfter(end);
  }

  List<AppEventDate> upcomingDatesFor(AppEvent event) =>
      event.dates.where(upcomingDate).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  bool hasMenuContent(AppEventDate date) => date.menuSlots.any((slot) =>
      slot.enabled &&
      (slot.menuItemIds.isNotEmpty || slot.menuImages.isNotEmpty));

  List<AppEventDate> upcomingMenuDatesFor(AppEvent event) =>
      upcomingDatesFor(event).where(hasMenuContent).toList();

  DateTime? eventFirstDate(AppEvent event) {
    final dates = event.dates
        .map((date) => parseIsoDate(date.date))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.first;
  }

  DateTime? eventLastDate(AppEvent event) {
    final dates = event.dates
        .map((date) => parseIsoDate(date.date))
        .whereType<DateTime>()
        .toList();
    if (dates.isEmpty) return null;
    dates.sort();
    return dates.last;
  }

  bool eventHasHappened(AppEvent event) {
    final lastDate = eventLastDate(event);
    if (lastDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return lastDate.isBefore(today);
  }

  bool isSameMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  Iterable<AppEvent> monthlyEvents(DateTime month) =>
      widget.events.where((event) {
        final firstDate = eventFirstDate(event);
        return firstDate != null && isSameMonth(firstDate, month);
      });

  int monthlyRevenue(DateTime month) =>
      monthlyEvents(month).fold(0, (sum, event) => sum + eventTotal(event));

  int monthlyCompletedRevenue(DateTime month) => monthlyEvents(month)
      .where(eventHasHappened)
      .fold(0, (sum, event) => sum + eventTotal(event));

  int monthlyDue(DateTime month) =>
      monthlyEvents(month).fold(0, (sum, event) => sum + eventBalance(event));

  int monthlyCompletedDue(DateTime month) => monthlyEvents(month)
      .where(eventHasHappened)
      .fold(0, (sum, event) => sum + eventBalance(event));

  List<int> sixMonthRevenue(DateTime now) {
    return List.generate(6, (index) {
      final month = DateTime(now.year, now.month - 5 + index);
      return monthlyRevenue(month);
    });
  }

  String monthShort(DateTime date) => _monthShortNames[date.month - 1];

  String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> downloadMonthlyReport(BuildContext context) async {
    try {
      final range = await showReportDateRangePickerDialog(context);
      if (range == null) return;
      if (!context.mounted) return;
      showCpSnack(context, 'Preparing monthly report...');
      final uri = await widget.api.monthlyReportPdfUri(range.startDate,
          startDate: range.startDate, endDate: range.endDate);
      if (!context.mounted) return;
      showDownloadSnack(context, uri,
          title: '${range.label} report ${range.fileLabel}.pdf',
          kind: 'report',
          successMessage: '${range.label} report download started',
          failureMessage: 'Unable to download report');
    } catch (error) {
      if (context.mounted) {
        showCpSnack(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> downloadUpcomingMenus(
      BuildContext context, List<AppEvent> upcomingMenuEvents) async {
    try {
      final now = DateTime.now();
      final start =
          DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      final end = start.add(Duration(days: upcomingDurationDays - 1));
      showCpSnack(context, 'Preparing upcoming consolidated menu...');
      final uri = await widget.api.createConsolidatedMenusUri(
          events: upcomingMenuEvents,
          startDate: dateKey(start),
          endDate: dateKey(end),
          title: 'Upcoming Consolidated Menus');
      if (context.mounted) {
        showDownloadSnack(context, uri,
            title: 'Upcoming consolidated menus.pdf',
            kind: 'menu',
            successMessage: 'Upcoming consolidated menu download started',
            failureMessage: 'Unable to start menu download');
      }
    } catch (error) {
      if (context.mounted) {
        showCpSnack(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final revenue = monthlyRevenue(month);
    final pending = monthlyDue(month);
    final overdueEvents =
        widget.events.where((event) => eventBalance(event) > 0).length;
    final upcomingEvents = widget.events
        .where((event) => upcomingDatesFor(event).isNotEmpty)
        .toList();
    final upcomingMenuEvents = widget.events
        .where((event) => upcomingMenuDatesFor(event).isNotEmpty)
        .toList();
    final trend = sixMonthRevenue(now);
    final maxTrend =
        trend.fold<int>(0, (max, value) => value > max ? value : max);
    return ScreenFrame(
      topBar: TopBar(
        title: 'Command Center',
        subtitle: 'Welcome back',
        actions: [
          IconButton(
              onPressed: widget.refresh,
              icon: const Icon(Icons.refresh_rounded, color: Cp.primary))
        ],
      ),
      children: [
        Row(children: [
          Text('LIVE METRICS',
              style: TextStyle(
                  color: cpOnVariant(context),
                  fontSize: 11,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w900)),
          const Spacer(),
          Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: Cp.tertiaryContainer, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('Live',
              style: TextStyle(
                  color: cpOnVariant(context), fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 118,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              DashboardMetricTile(
                  width: 154,
                  label: 'Revenue',
                  value: money(revenue),
                  note: '${monthShort(now)} earnings',
                  icon: Icons.trending_up,
                  primary: true),
              DashboardMetricTile(
                  width: 154,
                  label: 'Unpaid Events',
                  value: money(pending),
                  note: '$overdueEvents pending',
                  icon: Icons.receipt_long,
                  valueColor: Cp.error),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CpCard(
          color: Cp.surfaceLow,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: GridView(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 8,
              mainAxisExtent: 72,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              DashboardActionButton(
                  icon: Icons.calendar_month,
                  label: 'Events',
                  color: Cp.primaryContainer,
                  onTap: widget.openEvents),
              DashboardActionButton(
                  icon: Icons.fact_check,
                  label: 'Ready Menu',
                  color: Cp.surfaceHigh,
                  onTap: widget.openCustomMenus),
              DashboardActionButton(
                  icon: Icons.badge,
                  label: 'Employees',
                  color: Cp.secondaryContainer,
                  onTap: widget.openEmployees),
              DashboardActionButton(
                  icon: Icons.person_add_alt,
                  label: 'Clients',
                  color: Cp.surfaceHigh,
                  onTap: widget.openClients),
              DashboardActionButton(
                  icon: Icons.description_outlined,
                  label: 'Invoice',
                  color: Cp.surfaceHigh,
                  onTap: widget.openInvoice),
              DashboardActionButton(
                  icon: Icons.checklist,
                  label: 'Lists',
                  color: Cp.surfaceHigh,
                  onTap: widget.openLists),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: SectionHeader('Upcoming Deliveries')),
            IconButton(
              onPressed: upcomingMenuEvents.isEmpty
                  ? null
                  : () => downloadUpcomingMenus(context, upcomingMenuEvents),
              icon: Icon(Icons.restaurant_menu,
                  color: upcomingMenuEvents.isEmpty
                      ? cpOutline(context)
                      : cpPrimary(context)),
              tooltip: upcomingMenuEvents.isEmpty
                  ? 'No upcoming menus to download'
                  : 'Download upcoming menus',
            ),
            Pill('${upcomingEvents.length} ${t('Upcoming')}',
                color: Cp.primary.withValues(alpha: .1), textColor: Cp.primary),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: upcomingDurationOptions.map((option) {
              final selected = upcomingDurationDays == option.days;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(option.label),
                  selected: selected,
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
                      fontWeight: FontWeight.w900),
                  showCheckmark: false,
                  onSelected: (_) =>
                      setState(() => upcomingDurationDays = option.days),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()))
        else if (upcomingEvents.isEmpty)
          EmptyStateCard(
              title: t('No upcoming events'),
              message: t(upcomingDurationDays == 1
                  ? 'Events scheduled for tomorrow will appear here.'
                  : 'Events from tomorrow and the next $upcomingDurationDays days will appear here.'),
              actionLabel: widget.events.isEmpty ? t('Create Event') : null,
              onAction: widget.events.isEmpty ? widget.openCreate : null)
        else
          ...upcomingEvents.map((event) {
            final dates = upcomingDatesFor(event);
            final members = dates.fold<int>(
                0,
                (sum, date) =>
                    sum +
                    date.menuSlots
                        .fold<int>(0, (slotSum, slot) => slotSum + slot.pax));
            final firstDate = dates.first;
            final slots = dates
                .expand((date) => date.menuSlots)
                .where((slot) => slot.enabled)
                .toList();
            final itemCount = slots.fold<int>(
                0, (sum, slot) => sum + slot.menuItemIds.length);
            return DeliveryCard(
                event: event,
                date: firstDate,
                members: members,
                itemCount: itemCount,
                slots: slots,
                onTap: () => widget.openDetails(event));
          }),
        const SizedBox(height: 22),
        RevenueTrendCard(
            value: revenue,
            due: pending,
            values: trend,
            maxValue: maxTrend,
            onReportTap: () => downloadMonthlyReport(context),
            monthLabels: List.generate(
                6,
                (index) =>
                    monthShort(DateTime(now.year, now.month - 5 + index)))),
      ],
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard(
      {super.key,
      required this.title,
      required this.message,
      this.actionLabel,
      this.onAction});
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => CpCard(
        color: Cp.surfaceLow,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.inbox_outlined, color: cpOutline(context), size: 36),
          const SizedBox(height: 12),
          Text(title,
              style: TextStyle(
                  color: cpPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(message,
              style: TextStyle(
                  color: cpOnVariant(context), fontWeight: FontWeight.w700)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                    backgroundColor: Cp.primaryContainer),
                icon: const Icon(Icons.add),
                label: Text(actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w900))),
          ],
        ]),
      );
}

class MetricCard extends StatelessWidget {
  const MetricCard(
      {super.key,
      required this.label,
      required this.value,
      required this.note,
      required this.icon,
      required this.color,
      required this.valueColor});
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final labelColor = cpOnVariant(context);
    final accent = cpAdaptTextColor(context, valueColor);
    return CpCard(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: valueColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: valueColor, size: 19)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: labelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 17,
                          color: accent,
                          fontWeight: FontWeight.w900)),
                  Text(note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9,
                          color: accent,
                          fontWeight: FontWeight.w800)),
                ]),
          ),
        ],
      ),
    );
  }
}

class DashboardMetricTile extends StatelessWidget {
  const DashboardMetricTile(
      {super.key,
      required this.width,
      required this.label,
      required this.value,
      required this.note,
      required this.icon,
      this.primary = false,
      this.valueColor});
  final double width;
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final bool primary;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? Cp.primaryContainer : cpCard(context);
    final muted =
        primary ? Colors.white.withValues(alpha: .72) : cpOnVariant(context);
    final accent = primary ? Colors.white : (valueColor ?? cpPrimary(context));
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 12),
      child: CpCard(
        color: bg,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: muted, fontWeight: FontWeight.w800))),
            Icon(icon, color: accent, size: 18),
          ]),
          const Spacer(),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: accent, fontSize: 20, fontWeight: FontWeight.w900)),
          Text(note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: muted, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class DashboardActionButton extends StatelessWidget {
  const DashboardActionButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = cpDark(context) ? Cp.primary : cpPrimary(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Cp.surfaceHigh,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Color(0x12000000), blurRadius: 10)
                  ]),
              child: Icon(icon, color: iconColor, size: 23)),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cpOnSurface(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class RevenueTrendCard extends StatelessWidget {
  const RevenueTrendCard(
      {super.key,
      required this.value,
      required this.due,
      required this.values,
      required this.maxValue,
      required this.onReportTap,
      required this.monthLabels});
  final int value;
  final int due;
  final List<int> values;
  final int maxValue;
  final VoidCallback onReportTap;
  final List<String> monthLabels;

  @override
  Widget build(BuildContext context) {
    final safeMax = maxValue <= 0 ? 1 : maxValue;
    return CpCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Revenue Trend',
                  style: TextStyle(
                      color: cpOnSurface(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w800))),
          IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Download monthly report',
              onPressed: onReportTap,
              icon:
                  Icon(Icons.insert_chart_outlined, color: cpPrimary(context))),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Text(money(value),
              style: TextStyle(
                  color: cpOnSurface(context),
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          Pill(due > 0 ? '${money(due)} due' : 'No due',
              color: due > 0 ? Cp.errorContainer : Cp.tertiaryFixed,
              textColor: due > 0 ? Cp.error : Cp.tertiary),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(values.length, (index) {
              final heightFactor = (values[index] / safeMax).clamp(.12, 1.0);
              final active = index == values.length - 1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: heightFactor,
                          widthFactor: .82,
                          child: Container(
                              alignment: Alignment.topCenter,
                              padding: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                  color: active
                                      ? Cp.primaryContainer
                                      : Cp.primaryFixed.withValues(alpha: .5),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(8))),
                              child: active
                                  ? Text(
                                      values[index] == 0
                                          ? ''
                                          : compactMoney(values[index]),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900))
                                  : null),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(monthLabels[index],
                        style: TextStyle(
                            color: cpOnVariant(context),
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ]),
    );
  }
}

String compactMoney(int value) {
  if (value >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
  if (value >= 1000) return '${(value / 1000).round()}k';
  return '$value';
}

class DeliveryCard extends StatelessWidget {
  const DeliveryCard(
      {super.key,
      required this.event,
      required this.date,
      required this.members,
      required this.itemCount,
      required this.slots,
      required this.onTap});
  final AppEvent event;
  final AppEventDate date;
  final int members;
  final int itemCount;
  final List<AppMenuSlot> slots;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parsed = parseIsoDate(date.date);
    final firstSlot = slots.isEmpty ? null : slots.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 58,
            height: 74,
            decoration: BoxDecoration(
                color: Cp.primaryFixed.withValues(alpha: .65),
                borderRadius: BorderRadius.circular(12)),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(parsed == null ? '--' : monthShortName(parsed.month),
                  style: const TextStyle(
                      color: Cp.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
              Text(parsed == null ? '--' : '${parsed.day}',
                  style: const TextStyle(
                      color: Cp.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(event.name.isEmpty ? 'Event' : event.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: cpOnSurface(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w900))),
                  Pill(eventIsIncomplete(event) ? 'Draft' : 'Confirmed',
                      color: eventIsIncomplete(event)
                          ? Cp.secondaryFixed
                          : Cp.tertiaryFixed,
                      textColor: eventIsIncomplete(event)
                          ? Cp.secondary
                          : Cp.tertiary),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.schedule, size: 15, color: cpOnVariant(context)),
                  Text(
                      ' ${firstSlot?.time.isEmpty ?? true ? '--' : firstSlot!.time}',
                      style: TextStyle(
                          color: cpOnVariant(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Icon(Icons.group, size: 15, color: cpOnVariant(context)),
                  Text(' $members Members',
                      style: TextStyle(
                          color: cpOnVariant(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
                const Divider(height: 16),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  Pill('$itemCount Items',
                      color: Cp.secondaryFixed, textColor: Cp.secondary),
                  if (slots.isNotEmpty)
                    ...slots.take(2).map((slot) => Pill(slot.type,
                        color: Cp.surfaceHigh,
                        textColor: cpOnVariant(context))),
                ]),
              ])),
        ]),
      ),
    );
  }
}

String monthShortName(int month) => _monthShortNames[month - 1].toUpperCase();

class RevenueChart extends StatelessWidget {
  const RevenueChart({super.key});

  @override
  Widget build(BuildContext context) {
    final heights = [.40, .55, .45, .70, .85, 1.0];
    return CpCard(
      child: SizedBox(
        height: 160,
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(heights.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FractionallySizedBox(
                        heightFactor: heights[i],
                        alignment: Alignment.bottomCenter,
                        child: Container(
                            decoration: BoxDecoration(
                                color: i == 5
                                    ? Cp.primaryContainer
                                    : Cp.primaryFixed.withValues(alpha: .65),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(8)))),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
                    .map((m) => Text(m,
                        style: TextStyle(
                            fontSize: 10,
                            color: cpOnVariant(context),
                            fontWeight: FontWeight.w600)))
                    .toList()),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 22,
                    color: cpPrimary(context),
                    fontWeight: FontWeight.w700))),
        if (trailing != null)
          Text(trailing!,
              style: TextStyle(
                  color: cpPrimary(context), fontWeight: FontWeight.w800)),
        if (trailing != null)
          Icon(Icons.chevron_right, color: cpPrimary(context), size: 18),
      ],
    );
  }
}

class EventMiniCard extends StatelessWidget {
  const EventMiniCard(
      {super.key,
      required this.title,
      required this.client,
      required this.time,
      required this.pax,
      required this.showDraft,
      this.onTap});
  final String title;
  final String client;
  final String time;
  final String pax;
  final bool showDraft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
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
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(client, style: TextStyle(color: cpOnVariant(context)))
                  ])),
              if (showDraft)
                const Pill('DRAFT',
                    color: Cp.secondaryFixed, textColor: Color(0xff663e00)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.schedule, size: 18, color: cpOnVariant(context)),
              Text(' $time   ',
                  style: TextStyle(
                      color: cpOnVariant(context),
                      fontWeight: FontWeight.w600)),
              Icon(Icons.group, size: 18, color: cpOnVariant(context)),
              Text(' $pax',
                  style: TextStyle(
                      color: cpOnVariant(context), fontWeight: FontWeight.w600))
            ]),
          ],
        ),
      ),
    );
  }
}
