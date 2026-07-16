part of '../main.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen(
      {super.key,
      required this.events,
      required this.manualInvoices,
      required this.api,
      required this.onSaveManualInvoice,
      required this.onAddManualInvoice});
  final List<AppEvent> events;
  final List<ManualInvoice> manualInvoices;
  final ApiService api;
  final Future<void> Function(ManualInvoice invoice) onSaveManualInvoice;
  final VoidCallback onAddManualInvoice;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  int selectedTab = 0;

  List<AppEvent> get quotationEvents =>
      widget.events.where((event) => event.payments.isEmpty).toList();
  List<({AppEvent event, AppPayment payment})> get invoicePayments => [
        for (final event in widget.events)
          for (final payment in event.payments)
            (event: event, payment: payment),
      ];

  Future<void> downloadDocument(
      BuildContext context, AppEvent event, String type) async {
    showCpSnack(context, 'Downloading...');
    final uri = await widget.api.documentUri(event.id, type);
    if (!context.mounted) return;
    showDownloadSnack(context, uri,
        title: downloadTitleForEvent(event, type),
        kind: 'invoice',
        successMessage:
            '${type == 'invoice' ? 'Invoice' : 'Quotation'} download started',
        failureMessage: 'Unable to start download');
  }

  void openDocumentDetails(AppEvent event, String type, {AppPayment? payment}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BillingDocumentDetailsScreen(
          event: event, payment: payment, type: type, api: widget.api),
    ));
  }

  Future<void> openAddInvoice() async {
    widget.onAddManualInvoice();
  }

  Future<void> downloadManualInvoice(
      BuildContext context, ManualInvoice invoice) async {
    showCpSnack(context, 'Downloading invoice...');
    final uri = await widget.api.manualInvoicePdfUri(invoice.id);
    if (!context.mounted) return;
    showDownloadSnack(context, uri,
        title: '${invoice.eventName} invoice.pdf',
        kind: 'invoice',
        successMessage: 'Invoice download started',
        failureMessage: 'Unable to start download');
  }

  void openManualInvoiceDetails(ManualInvoice invoice) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ManualInvoiceDetailsScreen(invoice: invoice, api: widget.api)));
  }

  Widget tabChip(int index, String label, int count) {
    final selected = selectedTab == index;
    final selectedColor =
        cpDark(context) ? cpPrimary(context) : Cp.primaryContainer;
    return ChoiceChip(
      selected: selected,
      selectedColor: selectedColor,
      labelStyle: TextStyle(
          color: selected
              ? (cpDark(context) ? const Color(0xff6fa0be) : Colors.white)
              : cpOnVariant(context),
          fontWeight: FontWeight.w900),
      label: Text('$label ($count)'),
      onSelected: (_) => setState(() => selectedTab = index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalQuotationValue =
        quotationEvents.fold<int>(0, (sum, event) => sum + eventTotal(event));
    final totalInvoiceValue =
        invoicePayments.fold<int>(0, (sum, item) => sum + item.payment.amount) +
            widget.manualInvoices
                .fold<int>(0, (sum, invoice) => sum + invoice.total);
    return ScreenFrame(
      topBar: TopBar(
          title: 'Billing',
          subtitle: 'Quotations and invoices',
          actions: [
            IconButton(
                onPressed: openAddInvoice,
                icon: const Icon(Icons.add, color: Cp.toolbarIcon),
                tooltip: 'Add invoice')
          ]),
      children: [
        Row(children: [
          Expanded(
              child: BillingSummaryCell(
                  label: 'Quotation Value',
                  value: money(totalQuotationValue),
                  icon: Icons.request_quote,
                  color: Cp.primary)),
          const SizedBox(width: 10),
          Expanded(
              child: BillingSummaryCell(
                  label: 'Invoice Payments',
                  value: money(totalInvoiceValue),
                  icon: Icons.receipt_long,
                  color: Cp.tertiaryContainer)),
        ]),
        const SizedBox(height: 16),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              tabChip(0, 'Quotations', quotationEvents.length),
              const SizedBox(width: 8),
              tabChip(1, 'Invoices',
                  invoicePayments.length + widget.manualInvoices.length)
            ])),
        const SizedBox(height: 16),
        if (selectedTab == 0) ...[
          if (quotationEvents.isEmpty)
            const EmptyStateCard(
                title: 'No quotations pending',
                message:
                    'Events move here only until the first payment is recorded.')
          else
            ...quotationEvents.map((event) => BillingDocumentCard(
                  title: event.name,
                  subtitle:
                      '${event.primaryClient.isEmpty ? event.mobile : event.primaryClient} • ${event.mobile}',
                  code: 'QUOTE-${event.id.toUpperCase()}',
                  amountLabel: 'Event Total',
                  amount: money(eventTotal(event)),
                  dateLabel: event.dates.isEmpty
                      ? 'No dates'
                      : event.dates.map((date) => date.date).join(', '),
                  status: 'Quotation',
                  statusColor: Cp.primary,
                  icon: Icons.request_quote,
                  onDownload: () =>
                      downloadDocument(context, event, 'quotation'),
                  onTap: () => openDocumentDetails(event, 'quotation'),
                )),
        ] else ...[
          if (invoicePayments.isEmpty && widget.manualInvoices.isEmpty)
            const EmptyStateCard(
                title: 'No invoices yet',
                message:
                    'Invoices appear here after any payment is recorded for an event.')
          else ...[
            ...widget.manualInvoices.map((invoice) => BillingDocumentCard(
                  title: invoice.eventName,
                  subtitle: '${invoice.clientName} • ${invoice.mobile}',
                  code: invoice.invoiceNumber.isEmpty
                      ? 'INV-${invoice.id.toUpperCase()}'
                      : invoice.invoiceNumber,
                  amountLabel: invoice.pending == 0 ? 'Total' : 'Pending',
                  amount: money(
                      invoice.pending == 0 ? invoice.total : invoice.pending),
                  dateLabel: invoice.invoiceDate,
                  status: invoice.pending == 0 ? 'Settled' : 'Manual',
                  statusColor:
                      invoice.pending == 0 ? Cp.tertiaryContainer : Cp.primary,
                  icon: Icons.receipt,
                  onDownload: () => downloadManualInvoice(context, invoice),
                  onTap: () => openManualInvoiceDetails(invoice),
                )),
            ...invoicePayments.map((item) => BillingDocumentCard(
                  title: item.event.name,
                  subtitle:
                      '${item.event.primaryClient.isEmpty ? item.event.mobile : item.event.primaryClient} • ${item.payment.mode}${item.payment.reference.isEmpty ? '' : ' • ${item.payment.reference}'}',
                  code: 'INV-${item.payment.id.toUpperCase()}',
                  amountLabel: 'Payment Amount',
                  amount: money(item.payment.amount),
                  dateLabel: item.payment.date,
                  status: item.payment.settled ? 'Settled' : 'Paid',
                  statusColor:
                      item.payment.settled ? Cp.tertiaryContainer : Cp.tertiary,
                  icon: Icons.receipt_long,
                  onDownload: () =>
                      downloadDocument(context, item.event, 'invoice'),
                  onTap: () => openDocumentDetails(item.event, 'invoice',
                      payment: item.payment),
                )),
          ],
        ],
      ],
    );
  }
}

class ManualInvoiceLineController {
  ManualInvoiceLineController(
      {String title = '', String quantity = '1', String rate = ''})
      : title = TextEditingController(text: title),
        quantity = TextEditingController(text: quantity),
        rate = TextEditingController(text: rate);
  final TextEditingController title;
  final TextEditingController quantity;
  final TextEditingController rate;

  void dispose() {
    title.dispose();
    quantity.dispose();
    rate.dispose();
  }
}

class ClientLookupField extends StatefulWidget {
  const ClientLookupField(
      {super.key,
      required this.label,
      required this.controller,
      required this.clients,
      required this.onSelected,
      this.validator,
      this.keyboardType,
      this.inputFormatters});
  final String label;
  final TextEditingController controller;
  final List<AppClient> clients;
  final ValueChanged<AppClient> onSelected;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<ClientLookupField> createState() => _ClientLookupFieldState();
}

class _ClientLookupFieldState extends State<ClientLookupField> {
  final focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    focusNode.addListener(() => setState(() {}));
    widget.controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  List<AppClient> get matches {
    final query = widget.controller.text.trim().toLowerCase();
    if (query.isEmpty || !focusNode.hasFocus) return [];
    final queryDigits = normalizeMobileText(query);
    return widget.clients
        .where((client) {
          final mobile = normalizeMobileText(client.mobile);
          return client.name.toLowerCase().contains(query) ||
              (queryDigits.isNotEmpty && mobile.contains(queryDigits)) ||
              client.gst.toLowerCase().contains(query);
        })
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = matches;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: widget.controller,
        focusNode: focusNode,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        validator: widget.validator,
        decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.keyboardType == TextInputType.phone
                ? Icons.phone_android
                : Icons.person),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
      if (results.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
              color: Cp.surface,
              border: Border.all(color: Cp.outlineVariant),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 12)
              ]),
          child: Column(
            children: results.map((client) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.person_search, color: Cp.primary),
                title: Text(client.name,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text([
                  normalizeMobileText(client.mobile),
                  client.address.isNotEmpty ? client.address : client.city,
                  client.gst
                ].where((item) => item.trim().isNotEmpty).join(' • ')),
                onTap: () {
                  widget.onSelected(client);
                  focusNode.unfocus();
                },
              );
            }).toList(),
          ),
        ),
    ]);
  }
}

class ManualInvoiceFormScreen extends StatefulWidget {
  const ManualInvoiceFormScreen(
      {super.key, required this.clients, required this.onSave});
  final List<AppClient> clients;
  final Future<void> Function(ManualInvoice invoice) onSave;

  @override
  State<ManualInvoiceFormScreen> createState() =>
      _ManualInvoiceFormScreenState();
}

class _ManualInvoiceFormScreenState extends State<ManualInvoiceFormScreen> {
  final formKey = GlobalKey<FormState>();
  final clientName = TextEditingController();
  final mobile = TextEditingController();
  final clientAddress = TextEditingController();
  final clientGst = TextEditingController();
  final eventName = TextEditingController();
  final venue = TextEditingController();
  final eventDate = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));
  final invoiceDate = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));
  final advance = TextEditingController(text: '0');
  final settlement = TextEditingController(text: '0');
  final notes = TextEditingController();
  final items = <ManualInvoiceLineController>[
    ManualInvoiceLineController(title: 'Catering service')
  ];
  bool saving = false;

  @override
  void dispose() {
    clientName.dispose();
    mobile.dispose();
    clientAddress.dispose();
    clientGst.dispose();
    eventName.dispose();
    venue.dispose();
    eventDate.dispose();
    invoiceDate.dispose();
    advance.dispose();
    settlement.dispose();
    notes.dispose();
    for (final item in items) {
      item.dispose();
    }
    super.dispose();
  }

  int number(TextEditingController controller) =>
      int.tryParse(controller.text.replaceAll(',', '').trim()) ?? 0;
  String cleanMobile() => normalizeMobileText(mobile.text);
  int lineAmount(ManualInvoiceLineController item) =>
      number(item.quantity) * number(item.rate);

  int get subtotal => items.fold(0, (sum, item) {
        return sum + lineAmount(item);
      });
  int get pending =>
      (subtotal - number(advance) - number(settlement)).clamp(0, subtotal);

  Future<void> pickDate(TextEditingController controller) async {
    final initial = parseIsoDate(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (picked != null) {
      setState(
          () => controller.text = picked.toIso8601String().substring(0, 10));
    }
  }

  void addItem() => setState(() => items.add(ManualInvoiceLineController()));

  void removeItem(int index) {
    if (items.length == 1) return;
    final removed = items.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void selectClient(AppClient client) {
    setState(() {
      clientName.text = client.name;
      mobile.text = normalizeMobileText(client.mobile);
      clientAddress.text =
          client.address.isNotEmpty ? client.address : client.city;
      clientGst.text = client.gst;
    });
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final lines = <ManualInvoiceItem>[];
    for (final item in items) {
      final title = item.title.text.trim();
      final qty = number(item.quantity);
      final rate = number(item.rate);
      final amount = qty * rate;
      if (title.isNotEmpty && amount > 0) {
        lines.add(ManualInvoiceItem(
            id: '', title: title, quantity: qty, rate: rate, amount: amount));
      }
    }
    if (lines.isEmpty) {
      showCpSnack(context, 'Add at least one invoice item with amount');
      return;
    }
    final adv = number(advance);
    final settle = number(settlement);
    if (adv + settle > subtotal) {
      showCpSnack(context, 'Advance and settlement cannot exceed total');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onSave(ManualInvoice(
        id: '',
        clientName: clientName.text.trim(),
        mobile: cleanMobile(),
        clientAddress: clientAddress.text.trim(),
        clientGst: clientGst.text.trim(),
        eventName: eventName.text.trim(),
        venue: venue.text.trim(),
        eventDate: eventDate.text.trim(),
        invoiceDate: invoiceDate.text.trim(),
        invoiceNumber: '',
        notes: notes.text.trim(),
        items: lines,
        subtotal: subtotal,
        total: subtotal,
        advance: adv,
        settlement: settle,
        pending: pending,
      ));
      if (!mounted) return;
      Navigator.pop(context);
      showCpSnack(context, 'Invoice saved');
    } catch (e) {
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  InputDecoration fieldDecoration(String label, {IconData? icon}) =>
      InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cpSurface(context),
      body: Form(
        key: formKey,
        child: ScreenFrame(
          topBar: TopBar(
              title: 'Add Invoice',
              avatar: false,
              leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, color: cpPrimary(context)))),
          bottomPadding: 110,
          children: [
            CpCard(
              child: Column(children: [
                ClientLookupField(
                  label: 'Client Name',
                  controller: clientName,
                  clients: widget.clients,
                  onSelected: selectClient,
                  validator: (value) =>
                      requiredTextValidator(value, 'Client name'),
                ),
                const SizedBox(height: 12),
                ClientLookupField(
                  label: 'Mobile Number',
                  controller: mobile,
                  clients: widget.clients,
                  onSelected: selectClient,
                  keyboardType: TextInputType.phone,
                  inputFormatters: mobileInputFormatters,
                  validator: mobileValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: clientAddress,
                    minLines: 2,
                    maxLines: 3,
                    decoration: fieldDecoration('Client Address',
                        icon: Icons.home_outlined)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: clientGst,
                    textCapitalization: TextCapitalization.characters,
                    decoration: fieldDecoration('Client GST',
                        icon: Icons.badge_outlined)),
                const SizedBox(height: 12),
                TextFormField(
                    controller: eventName,
                    decoration:
                        fieldDecoration('Event Name', icon: Icons.celebration),
                    validator: (value) =>
                        requiredTextValidator(value, 'Event name')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: venue,
                    decoration: fieldDecoration('Venue', icon: Icons.place)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: eventDate,
                          readOnly: true,
                          onTap: () => pickDate(eventDate),
                          decoration:
                              fieldDecoration('Event Date', icon: Icons.event),
                          validator: (value) =>
                              isoDateValidator(value, label: 'Event date'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextFormField(
                          controller: invoiceDate,
                          readOnly: true,
                          onTap: () => pickDate(invoiceDate),
                          decoration: fieldDecoration('Invoice Date',
                              icon: Icons.receipt),
                          validator: (value) =>
                              isoDateValidator(value, label: 'Invoice date'))),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            CpCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Invoice Items',
                              style: TextStyle(
                                  color: cpPrimary(context),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900))),
                      IconButton(
                          onPressed: addItem,
                          icon:
                              Icon(Icons.add_circle, color: cpPrimary(context)))
                    ]),
                    const SizedBox(height: 8),
                    ...List.generate(items.length, (index) {
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final wide = constraints.maxWidth > 820;
                          final fields = [
                            Expanded(
                                flex: 4,
                                child: TextFormField(
                                    controller: item.title,
                                    decoration: fieldDecoration('Item Title'),
                                    validator: (value) => requiredTextValidator(
                                        value, 'Item title'))),
                            const SizedBox(width: 8),
                            SizedBox(
                                width: wide ? 110 : null,
                                child: TextFormField(
                                    controller: item.quantity,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onChanged: (_) => setState(() {}),
                                    decoration: fieldDecoration('Qty'),
                                    validator: (value) =>
                                        positiveMoneyValidator(value, 'Qty',
                                            allowZero: false))),
                            const SizedBox(width: 8),
                            Expanded(
                                flex: 2,
                                child: TextFormField(
                                    controller: item.rate,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    onChanged: (_) => setState(() {}),
                                    decoration: fieldDecoration('Rate'),
                                    validator: (value) =>
                                        positiveMoneyValidator(value, 'Rate',
                                            allowZero: false))),
                            const SizedBox(width: 8),
                            Expanded(
                                flex: 2,
                                child: InputDecorator(
                                    decoration: fieldDecoration('Amount'),
                                    child: Text(money(lineAmount(item)),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900)))),
                            IconButton(
                                onPressed: () => removeItem(index),
                                icon:
                                    const Icon(Icons.delete, color: Cp.error)),
                          ];
                          if (wide) {
                            return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: fields);
                          }
                          return Column(children: [
                            Row(children: [fields[0], fields.last]),
                            const SizedBox(height: 10),
                            Row(children: fields.sublist(2, 7)),
                          ]);
                        }),
                      );
                    }),
                  ]),
            ),
            const SizedBox(height: 12),
            CpCard(
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: advance,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: fieldDecoration('Advance Paid',
                              icon: Icons.payments),
                          validator: (value) => positiveMoneyValidator(
                              value, 'Advance paid',
                              allowZero: true))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextFormField(
                          controller: settlement,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: fieldDecoration('Settlement / Discount',
                              icon: Icons.price_check),
                          validator: (value) => positiveMoneyValidator(
                              value, 'Settlement',
                              allowZero: true))),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: fieldDecoration('Notes')),
                const Divider(height: 24),
                AmountLine('Grand Total', money(subtotal), strong: true),
                AmountLine('Advance', money(number(advance)),
                    color: Cp.tertiaryContainer),
                AmountLine('Settlement', money(number(settlement)),
                    color: Cp.tertiaryContainer),
                AmountLine('Pending', money(pending),
                    color: pending == 0 ? Cp.tertiaryContainer : Cp.error,
                    strong: true),
              ]),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          color: cpSurface(context),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
                onPressed: saving ? null : save,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  disabledBackgroundColor:
                      scheme.primary.withValues(alpha: .38),
                  disabledForegroundColor:
                      scheme.onPrimary.withValues(alpha: .68),
                ),
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save),
                label: Text(saving ? 'Saving...' : 'Save Invoice',
                    style: const TextStyle(fontWeight: FontWeight.w900))),
          ),
        ),
      ),
    );
  }
}

class ManualInvoiceDetailsScreen extends StatelessWidget {
  const ManualInvoiceDetailsScreen(
      {super.key, required this.invoice, required this.api});
  final ManualInvoice invoice;
  final ApiService api;

  Future<void> download(BuildContext context) async {
    showCpSnack(context, 'Downloading invoice...');
    final uri = await api.manualInvoicePdfUri(invoice.id);
    if (context.mounted) {
      showDownloadSnack(context, uri,
          title: '${invoice.eventName} invoice.pdf',
          kind: 'invoice',
          successMessage: 'Invoice download started',
          failureMessage: 'Unable to start download');
    }
  }

  Future<void> requestPayment() async {
    final text =
        'Hello ${invoice.clientName}, pending payment for ${invoice.eventName} is ${money(invoice.pending)}. Please complete the payment. - CaterPro';
    await launchUrl(
        Uri.parse(
            'https://wa.me/91${invoice.mobile}?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cp.background,
      body: ScreenFrame(
        topBar: TopBar(
            title: 'Invoice Details',
            avatar: false,
            leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Cp.primary))),
        bottomPadding: 96,
        children: [
          CpCard(
            color: const Color(0xfffff7ff),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: CircleAvatar(
                      radius: 30,
                      backgroundColor: invoice.pending == 0
                          ? Cp.tertiaryFixed
                          : Cp.primaryFixed,
                      child: Icon(
                          invoice.pending == 0
                              ? Icons.check
                              : Icons.receipt_long,
                          color: invoice.pending == 0
                              ? Cp.tertiaryContainer
                              : Cp.primary,
                          size: 34))),
              const SizedBox(height: 12),
              Center(
                  child: Text(
                      invoice.pending == 0
                          ? 'Invoice settled'
                          : 'Pending ${money(invoice.pending)}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900))),
              const Divider(height: 28),
              DetailNavTile(
                  iconText: invoice.clientName.isEmpty
                      ? 'C'
                      : invoice.clientName[0].toUpperCase(),
                  label: 'Client Name',
                  value: '${invoice.clientName} • ${invoice.mobile}'),
              if (invoice.clientAddress.isNotEmpty)
                SmallInfoBlock(
                    label: 'Client Address', value: invoice.clientAddress),
              if (invoice.clientGst.isNotEmpty)
                SmallInfoBlock(label: 'Client GST', value: invoice.clientGst),
              DetailNavTile(
                  iconText: invoice.eventName.isEmpty
                      ? 'E'
                      : invoice.eventName[0].toUpperCase(),
                  label: 'Event Name',
                  value: invoice.eventName),
              SmallInfoBlock(
                  label: 'Invoice#',
                  value: invoice.invoiceNumber.isEmpty
                      ? invoice.id.toUpperCase()
                      : invoice.invoiceNumber),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: SmallInfoBlock(
                        label: 'Event Date', value: invoice.eventDate)),
                Expanded(
                    child: SmallInfoBlock(
                        label: 'Invoice Date', value: invoice.invoiceDate))
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          CpCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Items',
                  style: TextStyle(
                      color: Cp.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              ...invoice.items
                  .map((item) => AmountLine(item.title, money(item.amount))),
            ]),
          ),
          const SizedBox(height: 12),
          CpCard(
            child: Column(children: [
              AmountLine('Grand Total', money(invoice.total), strong: true),
              AmountLine('Advance / Paid', money(invoice.advance),
                  color: Cp.tertiaryContainer),
              AmountLine('Settlement', money(invoice.settlement),
                  color: Cp.tertiaryContainer),
              Divider(height: 18, color: cpOutlineVariant(context)),
              AmountLine('Pending', money(invoice.pending),
                  color: invoice.pending == 0 ? Cp.tertiaryContainer : Cp.error,
                  strong: true),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          color: cpSurface(context),
          child: Row(children: [
            Expanded(
                child: FilledButton(
                    onPressed: invoice.pending == 0 ? null : requestPayment,
                    style: FilledButton.styleFrom(
                        backgroundColor: Cp.secondaryContainer,
                        foregroundColor: const Color(0xff694000)),
                    child: const Text('Request Payment',
                        style: TextStyle(fontWeight: FontWeight.w900)))),
            const SizedBox(width: 10),
            IconButton.filledTonal(
                onPressed: () => download(context),
                icon: const Icon(Icons.download)),
          ]),
        ),
      ),
    );
  }
}

class BillingSummaryCell extends StatelessWidget {
  const BillingSummaryCell(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => CpCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Builder(builder: (context) {
            final accent = cpAdaptTextColor(context, color);
            return Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: accent, size: 19));
          }),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        color: cpOnVariant(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: cpAdaptTextColor(context, color),
                        fontSize: 16,
                        fontWeight: FontWeight.w900))
              ])),
        ]),
      );
}

class BillingDocumentCard extends StatelessWidget {
  const BillingDocumentCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.code,
      required this.amountLabel,
      required this.amount,
      required this.dateLabel,
      required this.status,
      required this.statusColor,
      required this.icon,
      required this.onDownload,
      this.onTap});
  final String title, subtitle, code, amountLabel, amount, dateLabel, status;
  final Color statusColor;
  final IconData icon;
  final VoidCallback onDownload;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = cpPrimary(context);
    final muted = cpOnVariant(context);
    final outline = cpOutline(context);
    final statusAccent = cpAdaptTextColor(context, statusColor);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: accent),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          color: accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w900)),
                  Text(subtitle,
                      style:
                          TextStyle(color: muted, fontWeight: FontWeight.w700)),
                  Text(code,
                      style: TextStyle(
                          color: outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w800))
                ])),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Pill(status,
                  color: statusAccent.withValues(alpha: .14),
                  textColor: statusAccent),
              IconButton(
                  onPressed: onDownload,
                  icon: Icon(Icons.download, color: accent),
                  tooltip: 'Download'),
            ]),
          ]),
          const Divider(height: 22),
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(amountLabel,
                      style: TextStyle(
                          color: outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  Text(amount,
                      style: TextStyle(
                          color: accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w900))
                ])),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  Text('Date',
                      style: TextStyle(
                          color: outline,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  Text(dateLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800))
                ])),
          ]),
        ]),
      ),
    );
  }
}

class BillingDocumentDetailsScreen extends StatelessWidget {
  const BillingDocumentDetailsScreen(
      {super.key,
      required this.event,
      required this.type,
      required this.api,
      this.payment});
  final AppEvent event;
  final String type;
  final ApiService api;
  final AppPayment? payment;

  bool get isInvoice => type == 'invoice';
  String get title => isInvoice ? 'Invoice Details' : 'Quotation Details';
  String get docCode => isInvoice
      ? 'INV-${(payment?.id ?? event.id).toUpperCase()}'
      : 'QUOTE-${event.id.toUpperCase()}';

  Future<Uri> documentUri() =>
      api.documentUri(event.id, isInvoice ? 'invoice' : 'quotation');

  Future<void> download(BuildContext context) async {
    showCpSnack(context, 'Downloading...');
    final uri = await documentUri();
    if (context.mounted) {
      showDownloadSnack(context, uri,
          title:
              downloadTitleForEvent(event, isInvoice ? 'invoice' : 'quotation'),
          kind: 'invoice',
          successMessage:
              '${isInvoice ? 'Invoice' : 'Quotation'} download started',
          failureMessage: 'Unable to start download');
    }
  }

  Future<void> shareOverWhatsApp(BuildContext context) async {
    final uri = await documentUri();
    final label = isInvoice ? 'invoice' : 'quotation';
    final text = 'CaterPro $label for ${event.name}: $uri';
    await launchUrl(
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank');
  }

  Future<void> requestPayment(BuildContext context) async {
    final pending = eventBalance(event);
    final client =
        event.primaryClient.isEmpty ? 'Customer' : event.primaryClient;
    final text =
        'Hello $client, pending payment for ${event.name} is ${money(pending)}. Please complete the payment. - CaterPro';
    await launchUrl(
        Uri.parse(
            'https://wa.me/${event.mobile}?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final total = eventTotal(event);
    final paid = eventPaid(event);
    final currentPayment = payment?.amount ?? 0;
    final pending = eventBalance(event);
    final clientName =
        event.primaryClient.isEmpty ? event.mobile : event.primaryClient;
    final menuCount =
        event.dates.fold<int>(0, (sum, date) => sum + date.menuSlots.length);
    final menuItems = event.dates
        .expand((date) => date.menuSlots)
        .expand((slot) => slot.menuItemIds)
        .length;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cpSurface(context),
      body: ScreenFrame(
        topBar: TopBar(
            title: title,
            avatar: false,
            leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: cpPrimary(context)))),
        bottomPadding: 98,
        children: [
          CpCard(
            color: isInvoice
                ? Cp.tertiaryFixed.withValues(alpha: .28)
                : Cp.primaryFixed.withValues(alpha: .42),
            child: Column(children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      isInvoice ? Cp.tertiaryFixed : Cp.primaryFixed,
                  child: Icon(isInvoice ? Icons.check : Icons.request_quote,
                      color: isInvoice ? Cp.tertiaryContainer : Cp.primary,
                      size: 34)),
              const SizedBox(height: 12),
              Text(isInvoice ? 'Payment recorded' : 'Quotation ready',
                  style: TextStyle(
                      color: cpOnVariant(context),
                      fontWeight: FontWeight.w900)),
              Text(isInvoice ? money(currentPayment) : money(total),
                  style: TextStyle(
                      color: cpOnSurface(context),
                      fontSize: 30,
                      fontWeight: FontWeight.w900)),
            ]),
          ),
          const SizedBox(height: 12),
          DetailNavTile(
              iconText: clientName.isEmpty ? 'C' : clientName[0].toUpperCase(),
              label: 'Client Name',
              value: clientName),
          DetailNavTile(
              iconText: event.name.isEmpty ? 'E' : event.name[0].toUpperCase(),
              label: 'Event Name',
              value: event.name),
          CpCard(
            color: const Color(0xfffff7ff),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  'Event Date: ${event.dates.isEmpty ? '-' : event.dates.map((date) => date.date).join(', ')}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              Text('Terms: Due of Receipt',
                  style: TextStyle(
                      color: cpOnVariant(context),
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: SmallInfoBlock(
                        label: isInvoice ? 'Invoice#' : 'Quotation#',
                        value: docCode)),
                const SizedBox(width: 12),
                Expanded(
                    child: SmallInfoBlock(
                        label: isInvoice ? 'Invoice Date' : 'Quotation Date',
                        value: payment?.date ??
                            DateTime.now().toIso8601String().substring(0, 10))),
              ]),
              Divider(height: 24, color: cpOutlineVariant(context)),
              SmallInfoBlock(label: 'Event#', value: event.id.toUpperCase()),
            ]),
          ),
          const SizedBox(height: 12),
          CpCard(
            color: const Color(0xfffff7ff),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [
                Expanded(
                    child: Text('Menu Items',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900))),
                Icon(Icons.chevron_right)
              ]),
              const SizedBox(height: 8),
              Text('$menuCount menu slots • $menuItems selected items',
                  style: TextStyle(
                      color: cpOnVariant(context),
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...event.dates.take(4).map((date) => Text(
                  '${date.date}: ${date.menuSlots.map((slot) => '${slot.type} ${slot.pax} Members').join(', ')}',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 12),
          CpCard(
            color: const Color(0xfffff7ff),
            child: Column(children: [
              AmountLine('Subtotal', money(total)),
              Divider(height: 18, color: cpOutlineVariant(context)),
              AmountLine('Grand Total', money(total), strong: true),
              AmountLine('Advance / Paid Till Now', money(paid),
                  color: Cp.tertiaryContainer),
              if (isInvoice)
                AmountLine('Payment Made', money(currentPayment),
                    color: Cp.tertiaryContainer),
              Divider(height: 18, color: cpOutlineVariant(context)),
              AmountLine('Pending', money(pending),
                  color: pending == 0 ? Cp.tertiaryContainer : Cp.error,
                  strong: true),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: cpSurface(context),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: pending == 0 ? null : () => requestPayment(context),
                style: FilledButton.styleFrom(
                    backgroundColor: scheme.secondaryContainer,
                    foregroundColor: scheme.onSecondaryContainer,
                    disabledBackgroundColor: cpSurfaceHigh(context),
                    disabledForegroundColor: cpOnVariant(context)),
                child: Text(
                    pending == 0 ? 'Payment Complete' : 'Request Payment',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
                onPressed: () => download(context),
                icon: const Icon(Icons.download)),
            const SizedBox(width: 8),
            IconButton.filledTonal(
                onPressed: () => shareOverWhatsApp(context),
                icon: const Icon(Icons.chat)),
          ]),
        ),
      ),
    );
  }
}

class DetailNavTile extends StatelessWidget {
  const DetailNavTile(
      {super.key,
      required this.iconText,
      required this.label,
      required this.value});
  final String iconText, label, value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          color: const Color(0xfffff7ff),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: cpSurfaceHigh(context),
                child: Text(iconText,
                    style: TextStyle(
                        color: cpOnSurface(context),
                        fontWeight: FontWeight.w900))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          color: cpOnVariant(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800))
                ])),
            Icon(Icons.chevron_right, color: cpOnVariant(context)),
          ]),
        ),
      );
}

class SmallInfoBlock extends StatelessWidget {
  const SmallInfoBlock({super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        Text(value,
            style: TextStyle(
                color: cpOnVariant(context), fontWeight: FontWeight.w700))
      ]);
}

class AmountLine extends StatelessWidget {
  const AmountLine(this.label, this.value,
      {super.key, this.color, this.strong = false});
  final String label, value;
  final Color? color;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: color == null
                          ? cpOnVariant(context)
                          : cpAdaptTextColor(context, color!),
                      fontWeight: strong ? FontWeight.w900 : FontWeight.w700))),
          Text(value,
              style: TextStyle(
                  color: color == null
                      ? cpOnSurface(context)
                      : cpAdaptTextColor(context, color!),
                  fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
        ]),
      );
}

void showRecordPaymentSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const RecordPaymentSheet(),
  );
}

class InvoiceCard extends StatelessWidget {
  const InvoiceCard(
      {super.key,
      required this.code,
      required this.event,
      required this.amount,
      required this.dateLabel,
      required this.date,
      required this.status,
      required this.color,
      this.onTap});
  final String code, event, amount, dateLabel, date, status;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        onTap: onTap,
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(code,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(event, style: const TextStyle(color: Cp.onVariant))
                ])),
            Pill(status,
                color: color.withValues(alpha: .18),
                textColor: color,
                icon: status == 'Paid'
                    ? Icons.check_circle
                    : status == 'Overdue'
                        ? Icons.warning
                        : null)
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Total Amount',
                      style: TextStyle(color: Cp.outline, fontSize: 12)),
                  Text(amount,
                      style: TextStyle(
                          color: color == Cp.error ? Cp.error : Cp.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900))
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(dateLabel,
                  style: TextStyle(
                      color: color == Cp.error ? Cp.error : Cp.outline,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              Text(date, style: const TextStyle(fontWeight: FontWeight.w700))
            ])
          ]),
        ]),
      ),
    );
  }
}

class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({super.key});

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  static const int totalAmount = 350000;
  static const int paidAmount = 225000;
  static const int balanceAmount = 125000;
  final paymentController = TextEditingController(text: '50000');
  final dateController = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10));
  final refController = TextEditingController(text: 'REF123456789');
  final paymentModes = const ['Cash', 'UPI', 'NEFT', 'RTGS', 'Cheque'];
  int selectedMode = 0;
  bool settled = false;
  String? errorText;

  int get paymentAmount =>
      int.tryParse(paymentController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
      0;
  int get remainingAfterPayment =>
      (balanceAmount - paymentAmount).clamp(0, balanceAmount);
  int get settledDiscount =>
      settled && paymentAmount <= balanceAmount ? remainingAfterPayment : 0;
  int get finalBalance =>
      settled && paymentAmount <= balanceAmount ? 0 : remainingAfterPayment;

  @override
  void dispose() {
    paymentController.dispose();
    dateController.dispose();
    refController.dispose();
    super.dispose();
  }

  String money(int value) {
    final text = value.toString();
    if (text.length <= 3) return '₹$text';
    final tail = text.substring(text.length - 3);
    var head = text.substring(0, text.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    return '₹${groups.join(',')},$tail';
  }

  bool validate() {
    if (paymentAmount <= 0) {
      setState(() => errorText = 'Enter a payment amount.');
      return false;
    }
    if (paymentAmount > balanceAmount) {
      setState(() => errorText =
          'Payment cannot be more than remaining balance ${money(balanceAmount)}.');
      return false;
    }
    final dateError =
        isoDateValidator(dateController.text, label: 'Payment date');
    if (dateError != null) {
      setState(() => errorText = dateError);
      return false;
    }
    setState(() => errorText = null);
    return true;
  }

  void savePayment() {
    if (!validate()) return;
    final discount = settledDiscount;
    Navigator.pop(context);
    showCpSnack(
      context,
      discount > 0
          ? 'Payment saved. ${money(discount)} marked as settled discount.'
          : 'Payment saved by ${paymentModes[selectedMode]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        decoration: BoxDecoration(
            color: cpCard(context),
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
            Text('Record Payment',
                style: TextStyle(
                    color: cpPrimary(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Update the financial records for this event.',
                style: TextStyle(color: cpOnVariant(context))),
            const SizedBox(height: 18),
            CpCard(
              color: Cp.surfaceLow,
              child: Row(
                children: [
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
                ],
              ),
            ),
            const SizedBox(height: 18),
            PaymentInputBox(
                label: 'Payment Amount',
                controller: paymentController,
                icon: Icons.currency_rupee,
                keyboardType: TextInputType.number,
                onChanged: (_) => validate()),
            if (errorText != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(errorText!,
                      style: const TextStyle(
                          color: Cp.error, fontWeight: FontWeight.w800))),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(paymentModes.length, (i) {
                  final selected = i == selectedMode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => selectedMode = i),
                      child: Pill(paymentModes[i],
                          color:
                              selected ? Cp.primaryContainer : Cp.surfaceHigh,
                          textColor: selected
                              ? scheme.onPrimaryContainer
                              : cpOnVariant(context),
                          icon: selected ? Icons.check : null),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: settled,
              activeColor: scheme.primary,
              onChanged: (value) => setState(() => settled = value ?? false),
              title: const Text('Mark balance as settled',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(settled
                  ? '${money(settledDiscount)} will be treated as discount/settlement. Final balance: ${money(finalBalance)}'
                  : 'Unchecked keeps ${money(remainingAfterPayment)} as pending balance.'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 20),
            SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                    onPressed: savePayment,
                    style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary),
                    icon: const Icon(Icons.save),
                    label: const Text('Save Payment',
                        style: TextStyle(fontWeight: FontWeight.w900)))),
            Center(
                child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: cpPrimary(context),
                            fontWeight: FontWeight.w800)))),
          ],
        ),
      ),
    );
  }
}

class PaymentInputBox extends StatelessWidget {
  const PaymentInputBox(
      {super.key,
      required this.label,
      required this.controller,
      this.icon,
      this.keyboardType,
      this.onChanged});
  final String label;
  final TextEditingController controller;
  final IconData? icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
        decoration: BoxDecoration(
            color: cpInputFill(context),
            border: Border.all(color: cpOutline(context)),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                onChanged: onChanged,
                style: TextStyle(
                    color: cpOnSurface(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: label,
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
            if (icon != null)
              Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(icon, color: cpOutline(context))),
          ],
        ),
      ),
    );
  }
}

class _MoneyCell extends StatelessWidget {
  const _MoneyCell({required this.label, required this.value, this.color});
  final String label, value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(label,
            style: TextStyle(
                color: cpOnVariant(context),
                fontSize: 10,
                fontWeight: FontWeight.w900)),
        Text(value,
            style: TextStyle(
                color: color == null
                    ? cpOnSurface(context)
                    : cpAdaptTextColor(context, color!),
                fontWeight: FontWeight.w900))
      ]);
}
