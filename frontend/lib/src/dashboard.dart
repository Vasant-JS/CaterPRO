part of '../main.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen(
      {super.key,
      required this.api,
      required this.events,
      required this.loading,
      required this.loadError,
      required this.openCreate,
      required this.openDetails,
      required this.refresh});
  final ApiService api;
  final List<AppEvent> events;
  final bool loading;
  final String? loadError;
  final VoidCallback openCreate;
  final ValueChanged<AppEvent> openDetails;
  final VoidCallback refresh;

  bool upcomingDate(AppEventDate date) {
    final parsed = parseIsoDate(date.date);
    if (parsed == null) return false;
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final end = tomorrow.add(const Duration(days: 2));
    return !parsed.isBefore(tomorrow) && !parsed.isAfter(end);
  }

  List<AppEventDate> upcomingDatesFor(AppEvent event) =>
      event.dates.where(upcomingDate).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  bool hasMenuContent(AppEventDate date) =>
      date.menuSlots.any((slot) => slot.enabled && slot.menuItemIds.isNotEmpty);

  List<AppEventDate> upcomingMenuDatesFor(AppEvent event) =>
      upcomingDatesFor(event).where(hasMenuContent).toList();

  Future<void> downloadUpcomingMenus(BuildContext context) async {
    try {
      final error = await api.upcomingMenusError(days: 3);
      if (!context.mounted) return;
      if (error != null) {
        showCpSnack(context, error);
        return;
      }
      final uri = await api.upcomingMenusUri(days: 3);
      final launched = await launchUrl(uri,
          mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
      if (context.mounted) {
        showCpSnack(
            context,
            launched
                ? 'Upcoming menus download started'
                : 'Unable to start menu download');
      }
    } catch (error) {
      if (context.mounted) {
        showCpSnack(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDates =
        events.fold<int>(0, (sum, event) => sum + event.dates.length);
    final totalSlots = events.fold<int>(
        0,
        (sum, event) =>
            sum +
            event.dates.fold<int>(
                0, (dateSum, date) => dateSum + date.menuSlots.length));
    final paidTotal =
        events.fold<int>(0, (sum, event) => sum + eventPaid(event));
    final upcomingEvents =
        events.where((event) => upcomingDatesFor(event).isNotEmpty).toList();
    final upcomingMenuEvents = events
        .where((event) => upcomingMenuDatesFor(event).isNotEmpty)
        .toList();
    return ScreenFrame(
      topBar: TopBar(
        title: 'CaterPro',
        subtitle: t('Manage your events'),
        actions: [
          IconButton(
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded, color: Cp.primary))
        ],
      ),
      children: [
        if (loadError != null) ...[
          CpCard(
              color: Cp.errorContainer,
              child: Text(loadError!,
                  style: const TextStyle(
                      color: Cp.error, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: constraints.maxWidth > 720 ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: constraints.maxWidth > 720 ? 2.45 : 1.95,
            children: [
              MetricCard(
                  label: t('Events'),
                  value: '${events.length}',
                  note: loading ? t('Loading...') : t('Created'),
                  icon: Icons.calendar_month,
                  color: Cp.card,
                  valueColor: Cp.primary),
              MetricCard(
                  label: t('Dates'),
                  value: '$totalDates',
                  note: t('Event dates'),
                  icon: Icons.today,
                  color: Cp.primaryFixed.withValues(alpha: .5),
                  valueColor: Cp.primary),
              MetricCard(
                  label: t('Menus'),
                  value: '$totalSlots',
                  note: t('Menu slots'),
                  icon: Icons.restaurant_menu,
                  color: Cp.secondaryFixed,
                  valueColor: Cp.secondary),
              MetricCard(
                  label: t('Payments'),
                  value: money(paidTotal),
                  note: t('Collected'),
                  icon: Icons.payments,
                  color: Cp.tertiaryFixed.withValues(alpha: .4),
                  valueColor: Cp.tertiary),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
                child: Text(t('Upcoming Events'),
                    style: TextStyle(
                        fontSize: 22,
                        color: Cp.primary,
                        fontWeight: FontWeight.w700))),
            IconButton(
              onPressed: upcomingMenuEvents.isEmpty
                  ? null
                  : () => downloadUpcomingMenus(context),
              icon: Icon(Icons.restaurant_menu,
                  color: upcomingMenuEvents.isEmpty ? Cp.outline : Cp.primary),
              tooltip: upcomingMenuEvents.isEmpty
                  ? 'No upcoming menus to download'
                  : 'Download upcoming menus',
            ),
            Pill('${upcomingEvents.length} ${t('Upcoming')}',
                color: Cp.primary.withValues(alpha: .1), textColor: Cp.primary),
          ],
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()))
        else if (upcomingEvents.isEmpty)
          EmptyStateCard(
              title: t('No upcoming events'),
              message: t(
                  'Events from tomorrow and the next 2 days will appear here.'),
              actionLabel: events.isEmpty ? t('Create Event') : null,
              onAction: events.isEmpty ? openCreate : null)
        else
          ...upcomingEvents.map((event) {
            final dates = upcomingDatesFor(event);
            final pax = dates.fold<int>(
                0,
                (sum, date) =>
                    sum +
                    date.menuSlots
                        .fold<int>(0, (slotSum, slot) => slotSum + slot.pax));
            return EventMiniCard(
                title: event.name,
                client: event.mobile,
                time: dates
                    .map((date) => readableDateLabel(date.date))
                    .join(', '),
                pax: '$pax pax',
                showDraft: eventIsIncomplete(event),
                onTap: () => openDetails(event));
          }),
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
          const Icon(Icons.inbox_outlined, color: Cp.outline, size: 36),
          const SizedBox(height: 12),
          Text(title,
              style: const TextStyle(
                  color: Cp.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(message,
              style: const TextStyle(
                  color: Cp.onVariant, fontWeight: FontWeight.w700)),
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
                      style: const TextStyle(
                          color: Cp.onVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 17,
                          color: valueColor,
                          fontWeight: FontWeight.w900)),
                  Text(note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9,
                          color: valueColor,
                          fontWeight: FontWeight.w800)),
                ]),
          ),
        ],
      ),
    );
  }
}

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
                        style: const TextStyle(
                            fontSize: 10,
                            color: Cp.onVariant,
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
                style: const TextStyle(
                    fontSize: 22,
                    color: Cp.primary,
                    fontWeight: FontWeight.w700))),
        if (trailing != null)
          Text(trailing!,
              style: const TextStyle(
                  color: Cp.primary, fontWeight: FontWeight.w800)),
        if (trailing != null)
          const Icon(Icons.chevron_right, color: Cp.primary, size: 18),
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
                    Text(client, style: const TextStyle(color: Cp.onVariant))
                  ])),
              if (showDraft)
                const Pill('DRAFT',
                    color: Cp.secondaryFixed, textColor: Color(0xff663e00)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.schedule, size: 18, color: Cp.onVariant),
              Text(' $time   ',
                  style: const TextStyle(
                      color: Cp.onVariant, fontWeight: FontWeight.w600)),
              const Icon(Icons.group, size: 18, color: Cp.onVariant),
              Text(' $pax',
                  style: const TextStyle(
                      color: Cp.onVariant, fontWeight: FontWeight.w600))
            ]),
          ],
        ),
      ),
    );
  }
}
