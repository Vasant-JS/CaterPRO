part of '../main.dart';

class ClientSummary {
  const ClientSummary(
      {required this.client, required this.events, required this.invoices});
  final AppClient client;
  final List<AppEvent> events;
  final List<ManualInvoice> invoices;

  int get revenue =>
      events.fold(0, (sum, event) => sum + eventTotal(event)) +
      invoices.fold(0, (sum, invoice) => sum + invoice.total);
}

class ClientsScreen extends StatefulWidget {
  const ClientsScreen(
      {super.key,
      required this.clients,
      required this.events,
      required this.manualInvoices,
      required this.onSaveClient,
      required this.onDeleteClient,
      required this.openEvent,
      required this.openNotifications});
  final List<AppClient> clients;
  final List<AppEvent> events;
  final List<ManualInvoice> manualInvoices;
  final Future<void> Function(AppClient client) onSaveClient;
  final Future<void> Function(AppClient client) onDeleteClient;
  final ValueChanged<AppEvent> openEvent;
  final VoidCallback openNotifications;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<ClientSummary> get summaries {
    final map = <String, AppClient>{};
    final savedClientMobileByName = <String, String>{};

    String nameKey(String value) => value.trim().toLowerCase();

    void put(AppClient client) {
      final mobile = normalizeMobileText(client.mobile);
      if (mobile.isEmpty) return;
      final existing = map[mobile];
      map[mobile] = AppClient(
        id: existing?.id.isNotEmpty == true ? existing!.id : client.id,
        name: client.name.isNotEmpty ? client.name : existing?.name ?? mobile,
        mobile: mobile,
        city: client.city.isNotEmpty ? client.city : existing?.city ?? '',
        notes: client.notes.isNotEmpty ? client.notes : existing?.notes ?? '',
      );
    }

    for (final client in widget.clients) {
      put(client);
      if (client.name.trim().isNotEmpty) {
        savedClientMobileByName[nameKey(client.name)] =
            normalizeMobileText(client.mobile);
      }
    }
    for (final event in widget.events) {
      final clientName =
          event.primaryClient.isEmpty ? event.name : event.primaryClient;
      final savedMobile = savedClientMobileByName[nameKey(clientName)];
      put(AppClient(
          id: '',
          name: clientName,
          mobile: savedMobile?.isNotEmpty == true ? savedMobile! : event.mobile,
          city: event.venue));
    }
    for (final invoice in widget.manualInvoices) {
      final savedMobile = savedClientMobileByName[nameKey(invoice.clientName)];
      put(AppClient(
          id: '',
          name: invoice.clientName,
          mobile:
              savedMobile?.isNotEmpty == true ? savedMobile! : invoice.mobile,
          city: invoice.venue));
    }

    final result = map.values.map((client) {
      final mobile = normalizeMobileText(client.mobile);
      final clientNameKey = nameKey(client.name);
      return ClientSummary(
        client: client,
        events: widget.events.where((event) {
          final eventName =
              event.primaryClient.isEmpty ? event.name : event.primaryClient;
          return normalizeMobileText(event.mobile) == mobile ||
              (clientNameKey.isNotEmpty && nameKey(eventName) == clientNameKey);
        }).toList(),
        invoices: widget.manualInvoices.where((invoice) {
          return normalizeMobileText(invoice.mobile) == mobile ||
              (clientNameKey.isNotEmpty &&
                  nameKey(invoice.clientName) == clientNameKey);
        }).toList(),
      );
    }).toList()
      ..sort((a, b) =>
          a.client.name.toLowerCase().compareTo(b.client.name.toLowerCase()));
    if (query.isEmpty) return result;
    final q = query.toLowerCase();
    return result
        .where((summary) => [
              summary.client.name,
              summary.client.mobile,
              summary.client.city
            ].any((value) => value.toLowerCase().contains(q)))
        .toList();
  }

  Future<void> editClient(AppClient client) async {
    await showClientEditor(context,
        client: client, onSave: widget.onSaveClient);
    if (mounted) setState(() {});
  }

  Future<void> deleteClient(AppClient client) async {
    if (client.id.isEmpty) {
      showCpSnack(context,
          'This client is coming from event/bill data. Edit or delete the linked record first.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete client?'),
        content: Text(
            'Delete ${client.name} from the client master? Events and invoices will remain.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await widget.onDeleteClient(client);
    if (mounted) showCpSnack(context, 'Client deleted');
  }

  void showEvents(ClientSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Events - ${summary.client.name}',
              style: const TextStyle(
                  color: Cp.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (summary.events.isEmpty)
            const EmptyStateCard(
                title: 'No events',
                message: 'No events found for this client.'),
          ...summary.events.map((event) => ListTile(
                leading: const Icon(Icons.event, color: Cp.primary),
                title: Text(event.name),
                subtitle: Text(event.dates.map((date) => date.date).join(', ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  widget.openEvent(event);
                },
              )),
        ],
      ),
    );
  }

  void showBills(ClientSummary summary) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Bills - ${summary.client.name}',
              style: const TextStyle(
                  color: Cp.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          if (summary.events
                  .where((event) => event.payments.isNotEmpty)
                  .isEmpty &&
              summary.invoices.isEmpty)
            const EmptyStateCard(
                title: 'No bills',
                message: 'No invoices or payments found for this client.'),
          ...summary.invoices.map((invoice) => ListTile(
              leading: const Icon(Icons.receipt_long, color: Cp.primary),
              title: Text(invoice.eventName),
              subtitle: Text(invoice.invoiceNumber),
              trailing: Text(money(invoice.total)))),
          ...summary.events.expand((event) => event.payments.map((payment) =>
              ListTile(
                  leading:
                      const Icon(Icons.payments, color: Cp.tertiaryContainer),
                  title: Text(event.name),
                  subtitle: Text(payment.date),
                  trailing: Text(money(payment.amount))))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = summaries;
    final fieldBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cpOutlineVariant(context)));
    return ScreenFrame(
      topBar: TopBar(title: 'CaterPro', actions: [
        IconButton(
            onPressed: () =>
                showClientEditor(context, onSave: widget.onSaveClient),
            icon: const Icon(Icons.add, color: Cp.toolbarIcon)),
        IconButton(
            onPressed: widget.openNotifications,
            icon: Icon(Icons.notifications, color: cpPrimary(context)))
      ]),
      children: [
        TextField(
          controller: search,
          onChanged: (value) => setState(() => query = value.trim()),
          decoration: InputDecoration(
            hintText: 'Search clients by name, city, or phone...',
            prefixIcon: Icon(Icons.search, color: cpOutline(context)),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(() {
                          query = '';
                          search.clear();
                        }),
                    icon: const Icon(Icons.close)),
            filled: true,
            fillColor: cpCard(context),
            border: fieldBorder,
            enabledBorder: fieldBorder,
          ),
        ),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
              child: Text('Clients',
                  style: TextStyle(
                      fontSize: 22,
                      color: cpPrimary(context),
                      fontWeight: FontWeight.w700))),
          Text('${visible.length} Total',
              style: TextStyle(
                  color: cpOutline(context), fontWeight: FontWeight.w600))
        ]),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const EmptyStateCard(
              title: 'No clients yet',
              message:
                  'Clients will appear after you create events, bills, or client records.')
        else
          ...visible.map((summary) => ClientCard(
                summary: summary,
                onEvents: () => showEvents(summary),
                onBills: () => showBills(summary),
                onEdit: () => editClient(summary.client),
                onDelete: () => deleteClient(summary.client),
              )),
      ],
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox(this.hint, {super.key});
  final String hint;
  @override
  Widget build(BuildContext context) {
    final borderColor = cpOutlineVariant(context);
    final textColor = cpOutline(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: Cp.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor)),
      child: Row(children: [
        Icon(Icons.search, color: textColor),
        const SizedBox(width: 12),
        Expanded(
            child: Text(hint, style: TextStyle(color: textColor, fontSize: 15)))
      ]),
    );
  }
}

class ClientCard extends StatefulWidget {
  const ClientCard(
      {super.key,
      required this.summary,
      required this.onEvents,
      required this.onBills,
      required this.onEdit,
      required this.onDelete});
  final ClientSummary summary;
  final VoidCallback onEvents;
  final VoidCallback onBills;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<ClientCard> createState() => _ClientCardState();
}

class _ClientCardState extends State<ClientCard> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final client = summary.client;
    final initials = client.name.trim().isEmpty
        ? 'C'
        : client.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((part) => part[0].toUpperCase())
            .join();
    final mutedColor = cpOutline(context);
    final revenueColor = cpAdaptTextColor(context, Cp.secondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
                radius: 24,
                backgroundColor: Cp.primaryContainer,
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900))),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(client.name.isEmpty ? client.mobile : client.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(client.mobile,
                      style: TextStyle(
                          fontSize: 12,
                          color: mutedColor,
                          fontWeight: FontWeight.w600)),
                  if (client.city.isNotEmpty)
                    Text(client.city,
                        style: TextStyle(
                            fontSize: 12,
                            color: mutedColor,
                            fontWeight: FontWeight.w600))
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(summary.revenue),
                  style: TextStyle(
                      color: revenueColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              Text(
                  '${summary.events.length} events • ${summary.invoices.length} bills',
                  style: TextStyle(color: mutedColor, fontSize: 12)),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip:
                    expanded ? 'Hide client options' : 'Show client options',
                onPressed: () => setState(() => expanded = !expanded),
                icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.more_horiz_rounded,
                    color: cpPrimary(context)),
              ),
            ]),
          ]),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(children: [
              const Divider(height: 24, color: Cp.outlineVariant),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ActionChip(
                    avatar: const Icon(Icons.event, size: 18),
                    label: const Text('Events'),
                    onPressed: widget.onEvents),
                ActionChip(
                    avatar: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Bills'),
                    onPressed: widget.onBills),
                ActionChip(
                    avatar: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                    onPressed: () =>
                        launchUrl(Uri.parse('tel:${client.mobile}'))),
                ActionChip(
                    avatar: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp'),
                    onPressed: () => launchUrl(
                        Uri.parse('https://wa.me/91${client.mobile}'),
                        mode: LaunchMode.externalApplication,
                        webOnlyWindowName: '_blank')),
                ActionChip(
                    avatar: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    onPressed: widget.onEdit),
                ActionChip(
                    avatar: const Icon(Icons.delete, size: 18, color: Cp.error),
                    label: const Text('Delete'),
                    onPressed: widget.onDelete),
              ]),
            ]),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ]),
      ),
    );
  }
}

Future<void> showClientEditor(BuildContext context,
    {AppClient? client,
    required Future<void> Function(AppClient client) onSave}) async {
  final parentContext = context;
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController(text: client?.name ?? '');
  final mobile = TextEditingController(text: client?.mobile ?? '');
  final city = TextEditingController(text: client?.city ?? '');
  final notes = TextEditingController(text: client?.notes ?? '');
  final address = TextEditingController(text: client?.address ?? '');
  final gst = TextEditingController(text: client?.gst ?? '');
  bool saving = false;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
              color: cpSurface(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 58,
                            height: 6,
                            decoration: BoxDecoration(
                                color: cpOutlineVariant(context),
                                borderRadius: BorderRadius.circular(999)))),
                    const SizedBox(height: 18),
                    Text(client == null ? 'Add Client' : 'Edit Client',
                        style: TextStyle(
                            color: cpPrimary(context),
                            fontSize: 24,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: name,
                        validator: (value) =>
                            requiredTextValidator(value, 'Client name'),
                        decoration: InputDecoration(
                            labelText: 'Client Name',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: mobile,
                        keyboardType: TextInputType.phone,
                        inputFormatters: mobileInputFormatters,
                        validator: mobileValidator,
                        decoration: InputDecoration(
                            labelText: 'Mobile Number',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: city,
                        decoration: InputDecoration(
                            labelText: 'City / Area',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: address,
                        minLines: 2,
                        maxLines: 3,
                        decoration: InputDecoration(
                            labelText: 'Client Address',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: gst,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                            labelText: 'GST',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: notes,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final clean = normalizeMobileText(mobile.text);
                                if (!(formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }
                                final draft = AppClient(
                                    id: client?.id ?? '',
                                    name: name.text.trim(),
                                    mobile: clean,
                                    city: city.text.trim(),
                                    notes: notes.text.trim(),
                                    address: address.text.trim(),
                                    gst: gst.text.trim());
                                setSheetState(() => saving = true);
                                if (context.mounted) Navigator.pop(context);
                                try {
                                  await onSave(draft);
                                } catch (e) {
                                  if (parentContext.mounted) {
                                    showCpSnack(
                                        parentContext,
                                        e
                                            .toString()
                                            .replaceFirst('Exception: ', ''));
                                  }
                                }
                              },
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(saving ? 'Saving...' : 'Save Client',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  } finally {
    name.dispose();
    mobile.dispose();
    city.dispose();
    notes.dispose();
    address.dispose();
    gst.dispose();
  }
}
