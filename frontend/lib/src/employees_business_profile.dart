part of '../main.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen(
      {super.key,
      required this.api,
      required this.employees,
      required this.onSave,
      required this.onDelete,
      required this.onClose});
  final ApiService api;
  final List<Employee> employees;
  final Future<void> Function(Employee employee) onSave;
  final Future<void> Function(Employee employee) onDelete;
  final VoidCallback onClose;

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final search = TextEditingController();
  String selectedFilter = 'All';
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<String> get filters {
    final designations = widget.employees
        .map((employee) => employee.designation)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...designations];
  }

  List<Employee> get visibleEmployees {
    final normalizedQuery = query.trim().toLowerCase();
    return widget.employees.where((employee) {
      final matchesFilter =
          selectedFilter == 'All' || employee.designation == selectedFilter;
      final text = '${employee.name} ${employee.mobile} ${employee.designation}'
          .toLowerCase();
      return matchesFilter &&
          (normalizedQuery.isEmpty || text.contains(normalizedQuery));
    }).toList();
  }

  Future<void> saveEmployee(Employee employee) async {
    await widget.onSave(employee);
    if (mounted) {
      setState(() => selectedFilter = 'All');
      showCpSnack(context, '${employee.name} saved');
    }
  }

  Future<void> deleteEmployee(Employee employee) async {
    showCpSnack(context, 'Deleting ${employee.name}...');
    await widget.onDelete(employee);
    if (mounted) showCpSnack(context, '${employee.name} deleted');
  }

  Future<void> openAttendanceSheet() async {
    await showDialog<void>(
        context: context,
        builder: (context) => AttendanceSheetDialog(
            api: widget.api, employees: widget.employees));
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleEmployees;
    return Stack(
      children: [
        ScreenFrame(
          bottomPadding: 92,
          topBar: TopBar(
            title: 'Employees',
            avatar: false,
            leading: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.arrow_back, color: Cp.primary)),
            actions: [
              IconButton(
                  onPressed: openAttendanceSheet,
                  icon: const Icon(Icons.calendar_month, color: Cp.primary),
                  tooltip: 'Attendance sheet')
            ],
          ),
          children: [
            TextField(
              controller: search,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Cp.primary),
                hintText: 'Search employees',
                filled: true,
                fillColor: Cp.card,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Cp.outlineVariant.withValues(alpha: .5))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Cp.outlineVariant.withValues(alpha: .5))),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((filter) {
                  final selected = selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => selectedFilter = filter),
                      child: Pill(filter,
                          color:
                              selected ? Cp.primaryContainer : Cp.surfaceHigh,
                          textColor: selected ? Colors.white : Cp.onVariant,
                          icon: selected ? Icons.check : null),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: Text('${visible.length} employees',
                      style: const TextStyle(
                          color: Cp.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900))),
              Pill(selectedFilter)
            ]),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              CpCard(
                  color: Cp.surfaceLow,
                  child: const Text('No employees match this search/filter.',
                      style: TextStyle(
                          color: Cp.onVariant, fontWeight: FontWeight.w800)))
            else
              ...visible.map((employee) => EmployeeCard(
                  employee: employee,
                  onTap: () => showEmployeeEditor(context,
                      employee: employee, onSave: saveEmployee),
                  onDelete: () => deleteEmployee(employee))),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 24,
          child: FloatingActionButton.extended(
            heroTag: 'addEmployee',
            backgroundColor: Cp.secondaryContainer,
            foregroundColor: const Color(0xff694000),
            onPressed: () => showEmployeeEditor(context, onSave: saveEmployee),
            icon: const Icon(Icons.person_add),
            label: const Text('Add Employee',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class EmployeeCard extends StatelessWidget {
  const EmployeeCard(
      {super.key,
      required this.employee,
      required this.onTap,
      required this.onDelete});
  final Employee employee;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CpCard(
        onTap: onTap,
        child: Row(children: [
          CircleAvatar(
              radius: 24,
              backgroundColor: Cp.primaryFixed,
              child: Text(
                  employee.name
                      .split(' ')
                      .map((part) => part[0])
                      .take(2)
                      .join(),
                  style: const TextStyle(
                      color: Cp.primary, fontWeight: FontWeight.w900))),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(employee.name,
                  style: const TextStyle(
                      color: Cp.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              Text('${employee.designation} • Age ${employee.age}',
                  style: const TextStyle(
                      color: Cp.onVariant, fontWeight: FontWeight.w700)),
              Text(employee.mobile,
                  style: const TextStyle(color: Cp.onVariant)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Pay',
                style: TextStyle(
                    color: Cp.outline,
                    fontSize: 10,
                    fontWeight: FontWeight.w900)),
            Text('${money(employee.payPerDay)}/day',
                style: const TextStyle(
                    color: Cp.primary, fontWeight: FontWeight.w900)),
            Text('${money(employee.payPerHour)}/hr',
                style: const TextStyle(
                    color: Cp.onVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete, color: Cp.error),
                tooltip: 'Delete employee'),
          ]),
        ]),
      ),
    );
  }
}

void showEmployeeEditor(BuildContext context,
    {Employee? employee,
    required Future<void> Function(Employee employee) onSave}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        EmployeeEditorSheet(employee: employee, onSave: onSave),
  );
}

class EmployeeEditorSheet extends StatefulWidget {
  const EmployeeEditorSheet({super.key, this.employee, required this.onSave});
  final Employee? employee;
  final Future<void> Function(Employee employee) onSave;

  @override
  State<EmployeeEditorSheet> createState() => _EmployeeEditorSheetState();
}

class _EmployeeEditorSheetState extends State<EmployeeEditorSheet> {
  late final name = TextEditingController(text: widget.employee?.name ?? '');
  late final age = TextEditingController(
      text: widget.employee?.age == null || widget.employee!.age == 0
          ? ''
          : '${widget.employee!.age}');
  late final mobile =
      TextEditingController(text: widget.employee?.mobile ?? '');
  late final designation =
      TextEditingController(text: widget.employee?.designation ?? '');
  late final payPerDay = TextEditingController(
      text:
          widget.employee?.payPerDay == null || widget.employee!.payPerDay == 0
              ? ''
              : '${widget.employee!.payPerDay}');
  late final payPerHour = TextEditingController(
      text: widget.employee?.payPerHour == null ||
              widget.employee!.payPerHour == 0
          ? ''
          : '${widget.employee!.payPerHour}');
  String? error;
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    mobile.dispose();
    designation.dispose();
    payPerDay.dispose();
    payPerHour.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final parsedAge = int.tryParse(age.text.trim());
    final parsedPay =
        int.tryParse(payPerDay.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final parsedHourlyPay =
        int.tryParse(payPerHour.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final cleanMobile = normalizeMobileText(mobile.text);
    if (name.text.trim().isEmpty ||
        parsedAge == null ||
        cleanMobile.isEmpty ||
        designation.text.trim().isEmpty ||
        parsedPay == null ||
        parsedHourlyPay == null) {
      setState(() => error =
          'Fill Name, Age, Mobile, Designation, Pay/Day, and Pay/Hour.');
      return;
    }
    if (parsedAge < 16 || parsedAge > 100) {
      setState(() => error = 'Age must be between 16 and 100.');
      return;
    }
    if (cleanMobile.length != 10) {
      setState(() => error = 'Mobile number must be 10 digits.');
      return;
    }
    if (parsedPay <= 0) {
      setState(() => error = 'Pay/Day must be more than zero.');
      return;
    }
    if (parsedHourlyPay <= 0) {
      setState(() => error = 'Pay/Hour must be more than zero.');
      return;
    }
    setState(() => saving = true);
    await widget.onSave(Employee(
        id: widget.employee?.id ?? '',
        name: name.text.trim(),
        age: parsedAge,
        mobile: cleanMobile,
        designation: designation.text.trim(),
        payPerDay: parsedPay,
        payPerHour: parsedHourlyPay));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        decoration: const BoxDecoration(
            color: Cp.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
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
                Text(widget.employee == null ? 'Add Employee' : 'Edit Employee',
                    style: const TextStyle(
                        color: Cp.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                EditableInlineField(label: 'Name', controller: name),
                Row(children: [
                  Expanded(
                      child: EditableInlineField(
                          label: 'Age',
                          controller: age,
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: EditableInlineField(
                          label: 'Pay/Day',
                          controller: payPerDay,
                          keyboardType: TextInputType.number))
                ]),
                EditableInlineField(
                    label: 'Pay/Hour',
                    controller: payPerHour,
                    keyboardType: TextInputType.number),
                EditableInlineField(
                    label: 'Mobile',
                    controller: mobile,
                    keyboardType: TextInputType.phone,
                    inputFormatters: mobileInputFormatters),
                EditableInlineField(
                    label: 'Designation', controller: designation),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(error!,
                          style: const TextStyle(
                              color: Cp.error, fontWeight: FontWeight.w800))),
                SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                        onPressed: saving ? null : save,
                        style: FilledButton.styleFrom(
                            backgroundColor: Cp.primaryContainer),
                        icon: const Icon(Icons.save),
                        label: Text(saving ? 'Saving...' : 'Save Employee',
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)))),
              ]),
        ),
      ),
    );
  }
}

class AttendanceSheetDialog extends StatefulWidget {
  const AttendanceSheetDialog(
      {super.key, required this.api, required this.employees});
  final ApiService api;
  final List<Employee> employees;

  @override
  State<AttendanceSheetDialog> createState() => _AttendanceSheetDialogState();
}

class _AttendanceSheetDialogState extends State<AttendanceSheetDialog> {
  late String month = DateTime.now().toIso8601String().substring(0, 7);
  late Future<List<AttendanceRecord>> recordsFuture =
      widget.api.getAttendance(month: month);

  int get daysInMonth {
    final parts = month.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1] + 1, 0).day;
  }

  void changeMonth(int delta) {
    final parts = month.split('-').map(int.parse).toList();
    final next = DateTime(parts[0], parts[1] + delta);
    setState(() {
      month = '${next.year}-${next.month.toString().padLeft(2, '0')}';
      recordsFuture = widget.api.getAttendance(month: month);
    });
  }

  Future<void> download() async {
    showCpSnack(context, 'Preparing attendance sheet...');
    final freshRecords = await widget.api.getAttendance(month: month);
    if (mounted) {
      setState(() => recordsFuture = Future.value(freshRecords));
    }
    final uri = await widget.api.attendancePdfUri(month);
    if (mounted) {
      showDownloadSnack(context, uri,
          title: 'Attendance sheet $month.pdf',
          kind: 'report',
          successMessage: 'Attendance sheet download started',
          failureMessage: 'Unable to start download');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Row(children: [
          const Expanded(child: Text('Monthly Attendance')),
          IconButton(
              onPressed: download,
              icon: const Icon(Icons.download, color: Cp.primary),
              tooltip: 'Export PDF'),
        ]),
        content: SizedBox(
          width: 720,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              IconButton(
                  onPressed: () => changeMonth(-1),
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                  child: Center(
                      child: Text(month,
                          style: const TextStyle(
                              color: Cp.primary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)))),
              IconButton(
                  onPressed: () => changeMonth(1),
                  icon: const Icon(Icons.chevron_right)),
            ]),
            const SizedBox(height: 8),
            FutureBuilder<List<AttendanceRecord>>(
              future: recordsFuture,
              builder: (context, snapshot) {
                final records = snapshot.data ?? const <AttendanceRecord>[];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator());
                }
                if (records.isEmpty) {
                  return const EmptyStateCard(
                      title: 'No attendance',
                      message:
                          'Attendance records for this month will appear here.');
                }
                final grouped = <String, Map<int, AttendanceRecord>>{};
                for (final record in records) {
                  final day = parseIsoDate(record.date)?.day;
                  if (day == null) continue;
                  grouped.putIfAbsent(record.employeeId, () => {})[day] =
                      record;
                }
                String cellText(AttendanceRecord? record) {
                  if (record == null) return '-';
                  if (record.status == 'present') return 'P';
                  if (record.status == 'absent') return 'A';
                  return record.hours.toStringAsFixed(
                      record.hours.truncateToDouble() == record.hours ? 0 : 1);
                }

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowHeight: 36,
                          dataRowMinHeight: 38,
                          dataRowMaxHeight: 44,
                          columnSpacing: 12,
                          columns: [
                            const DataColumn(
                                label: SizedBox(
                                    width: 112, child: Text('Employee'))),
                            for (var day = 1; day <= daysInMonth; day++)
                              DataColumn(label: Text('$day')),
                            const DataColumn(label: Text('P')),
                            const DataColumn(label: Text('A')),
                            const DataColumn(label: Text('Hrs')),
                            const DataColumn(label: Text('Salary')),
                          ],
                          rows: grouped.entries.map((entry) {
                            final employee = widget.employees
                                .where((item) => item.id == entry.key)
                                .firstOrNull;
                            final name = employee?.name ??
                                entry.value.values.first.employeeName;
                            final present = entry.value.values
                                .where((record) => record.status == 'present')
                                .length;
                            final absent = entry.value.values
                                .where((record) => record.status == 'absent')
                                .length;
                            final hours = entry.value.values.fold<double>(
                                0, (sum, record) => sum + record.hours);
                            final salary =
                                entry.value.values.fold<int>(0, (sum, record) {
                              if (record.status == 'present') {
                                return sum + record.payPerDay;
                              }
                              if (record.status == 'partial') {
                                return sum +
                                    (record.payPerHour * record.hours).round();
                              }
                              return sum;
                            });
                            return DataRow(cells: [
                              DataCell(SizedBox(
                                  width: 112,
                                  child: Text(name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)))),
                              for (var day = 1; day <= daysInMonth; day++)
                                DataCell(Text(cellText(entry.value[day]))),
                              DataCell(Text('$present')),
                              DataCell(Text('$absent')),
                              DataCell(Text(hours.toStringAsFixed(
                                  hours.truncateToDouble() == hours ? 0 : 1))),
                              DataCell(Text(money(salary),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800))),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      );
}

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen(
      {super.key,
      required this.profile,
      required this.onSave,
      required this.onClose});
  final BusinessProfile profile;
  final Future<void> Function(BusinessProfile profile) onSave;
  final VoidCallback onClose;

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  String normalizedDocumentTemplate(String value) => switch (value) {
        'premium' => 'elegant',
        'minimal' => 'classic',
        'classic' || 'elegant' || 'modern' => value,
        _ => 'modern',
      };

  late final businessName =
      TextEditingController(text: widget.profile.businessName);
  late final serviceType =
      TextEditingController(text: widget.profile.serviceType);
  late final gstin = TextEditingController(text: widget.profile.gstin);
  late String gstType = widget.profile.gstType == 'igst' ? 'igst' : 'cgst_sgst';
  late final gstRate = TextEditingController(
      text: widget.profile.gstin.trim().isEmpty
          ? ''
          : widget.profile.gstRate.toStringAsFixed(
              widget.profile.gstRate.truncateToDouble() ==
                      widget.profile.gstRate
                  ? 0
                  : 2));
  late final pan = TextEditingController(text: widget.profile.pan);
  late final address = TextEditingController(text: widget.profile.address);
  late final phone = TextEditingController(text: widget.profile.phone);
  late final email = TextEditingController(text: widget.profile.email);
  late final bankName = TextEditingController(text: widget.profile.bankName);
  late final accountNumber =
      TextEditingController(text: widget.profile.accountNumber);
  late final terms = TextEditingController(text: widget.profile.terms);
  late String logoBase64 = widget.profile.logoBase64;
  late String signatureBase64 = widget.profile.signatureBase64;
  late String qrBase64 = widget.profile.qrBase64;
  late String documentTemplate =
      normalizedDocumentTemplate(widget.profile.documentTemplate);
  late bool gstRegistered = widget.profile.gstin.trim().isNotEmpty;
  bool saving = false;
  String? error;

  @override
  void didUpdateWidget(covariant BusinessProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile && !saving) {
      applyProfile(widget.profile);
    }
  }

  void applyProfile(BusinessProfile profile) {
    businessName.text = profile.businessName;
    serviceType.text = profile.serviceType;
    gstin.text = profile.gstin;
    gstType = profile.gstType == 'igst' ? 'igst' : 'cgst_sgst';
    gstRate.text = profile.gstin.trim().isEmpty
        ? ''
        : profile.gstRate.toStringAsFixed(
            profile.gstRate.truncateToDouble() == profile.gstRate ? 0 : 2);
    pan.text = profile.pan;
    gstRegistered = profile.gstin.trim().isNotEmpty;
    address.text = profile.address;
    phone.text = profile.phone;
    email.text = profile.email;
    bankName.text = profile.bankName;
    accountNumber.text = profile.accountNumber;
    terms.text = profile.terms;
    logoBase64 = profile.logoBase64;
    signatureBase64 = profile.signatureBase64;
    qrBase64 = profile.qrBase64;
    documentTemplate = normalizedDocumentTemplate(profile.documentTemplate);
  }

  @override
  void dispose() {
    for (final controller in [
      businessName,
      serviceType,
      gstin,
      gstRate,
      pan,
      address,
      phone,
      email,
      bankName,
      accountNumber,
      terms
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  BusinessProfile currentProfile() => BusinessProfile(
        businessName: businessName.text.trim(),
        serviceType: serviceType.text.trim(),
        gstin: gstRegistered ? gstin.text.trim() : '',
        gstType: gstType,
        gstRate: gstRegistered ? (double.tryParse(gstRate.text.trim()) ?? 5) : 0,
        pan: pan.text.trim(),
        address: address.text.trim(),
        phone: phone.text.trim().isEmpty ? '' : normalizeMobileText(phone.text),
        email: email.text.trim(),
        bankName: bankName.text.trim(),
        accountNumber: accountNumber.text.trim(),
        terms: terms.text.trim(),
        logoBase64: logoBase64,
        signatureBase64: signatureBase64,
        qrBase64: qrBase64,
        documentTemplate: documentTemplate,
        invoiceTextScale: widget.profile.invoiceTextScale,
      );

  Future<void> save() async {
    final cleanPhone = normalizeMobileText(phone.text);
    if (businessName.text.trim().isEmpty) {
      setState(() => error = 'Business name is required.');
      return;
    }
    if (phone.text.trim().isNotEmpty && cleanPhone.length != 10) {
      setState(() => error = 'Phone number must be 10 digits.');
      return;
    }
    if (email.text.trim().isNotEmpty && !isValidEmail(email.text)) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(currentProfile());
      if (!mounted) return;
      showCpSnack(context, 'Business profile saved');
      widget.onClose();
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
          topBar: TopBar(
              title: 'Business Profile',
              avatar: false,
              leading: IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back, color: Cp.primary)),
              actions: [
                TextButton(
                    onPressed: saving ? null : save,
                    child: Text(saving ? 'Saving...' : 'Save',
                        style: const TextStyle(
                            color: Cp.primary, fontWeight: FontWeight.w900)))
              ]),
          children: [
            CpCard(
                child: Column(children: [
              BusinessLogoAvatar(profile: currentProfile(), radius: 44),
              const SizedBox(height: 12),
              const Text('Business Profile',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const Text('Enter your business information',
                  style: TextStyle(color: Cp.onVariant))
            ])),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                  child: UploadBox(
                      label: 'Logo',
                      icon: Icons.storefront,
                      value: logoBase64,
                      filled: true,
                      onChanged: (value) =>
                          setState(() => logoBase64 = value))),
              const SizedBox(width: 12),
              Expanded(
                  child: UploadBox(
                      label: 'Signature',
                      icon: Icons.draw,
                      value: signatureBase64,
                      onChanged: (value) =>
                          setState(() => signatureBase64 = value))),
              const SizedBox(width: 12),
              Expanded(
                  child: UploadBox(
                      label: 'Payment QR',
                      icon: Icons.qr_code_2,
                      value: qrBase64,
                      onChanged: (value) => setState(() => qrBase64 = value))),
            ]),
            const SizedBox(height: 16),
            if (error != null) ...[
              CpCard(
                  color: Cp.errorContainer,
                  child: Text(error!,
                      style: const TextStyle(
                          color: Cp.error, fontWeight: FontWeight.w800))),
              const SizedBox(height: 12)
            ],
            const SectionTitle('Basic Info', Icons.business),
            EditableInlineField(
                label: 'Business Name', controller: businessName),
            EditableInlineField(label: 'Service Type', controller: serviceType),
            const SectionTitle('Tax & Legal', Icons.gavel),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: gstRegistered,
              activeColor: Theme.of(context).colorScheme.primary,
              title: const Text('GST Registered',
                  style: TextStyle(fontWeight: FontWeight.w900)),
              onChanged: (value) {
                setState(() {
                  gstRegistered = value ?? false;
                  if (!gstRegistered) {
                    gstin.clear();
                    gstRate.clear();
                  } else if (gstRate.text.trim().isEmpty) {
                    gstRate.text = '5';
                  }
                });
              },
            ),
            Row(children: [
              Expanded(
                  flex: 5,
                  child: EditableInlineField(
                      label: 'GSTIN',
                      controller: gstin,
                      enabled: gstRegistered)),
              const SizedBox(width: 10),
              Expanded(
                  flex: 4,
                  child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: gstType,
                  disabledHint: Text(gstType == 'igst' ? 'IGST' : 'CGST + SGST'),
                  decoration: InputDecoration(
                      labelText: 'GST Type',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                  items: const [
                    DropdownMenuItem(
                        value: 'cgst_sgst', child: Text('CGST + SGST')),
                    DropdownMenuItem(value: 'igst', child: Text('IGST')),
                  ],
                  onChanged: gstRegistered
                      ? (value) =>
                          setState(() => gstType = value ?? 'cgst_sgst')
                      : null,
                ),
              )),
              const SizedBox(width: 10),
              Expanded(
                  flex: 3,
                  child: EditableInlineField(
                      label: 'GST %',
                      controller: gstRate,
                      enabled: gstRegistered,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)))
            ]),
            EditableInlineField(label: 'PAN', controller: pan),
            const SectionTitle('Business Address', Icons.location_on),
            EditableInlineField(label: 'Full Address', controller: address),
            const SectionTitle('Contact Information', Icons.contact_phone),
            EditableInlineField(
                label: 'Phone Number',
                controller: phone,
                keyboardType: TextInputType.phone,
                inputFormatters: mobileInputFormatters),
            EditableInlineField(
                label: 'Email Address',
                controller: email,
                keyboardType: TextInputType.emailAddress),
            const SectionTitle('Settlement Bank', Icons.account_balance),
            EditableInlineField(label: 'Bank Name', controller: bankName),
            EditableInlineField(
                label: 'Account Number',
                controller: accountNumber,
                keyboardType: TextInputType.number),
            const SectionTitle('Terms & Conditions', Icons.description),
            EditableInlineField(label: 'Standard Terms', controller: terms),
            const SizedBox(height: 18),
            SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                    onPressed: saving ? null : save,
                    style: FilledButton.styleFrom(backgroundColor: Cp.primary),
                    icon: const Icon(Icons.save),
                    label: Text(saving ? 'Saving...' : 'Save Business Profile',
                        style: const TextStyle(fontWeight: FontWeight.w900)))),
          ]);
}

class UploadBox extends StatelessWidget {
  const UploadBox(
      {super.key,
      required this.label,
      required this.icon,
      required this.value,
      required this.onChanged,
      this.filled = false});
  final String label;
  final IconData icon;
  final String value;
  final ValueChanged<String> onChanged;
  final bool filled;

  Future<void> pickImage() async {
    final result =
        await fp.FilePicker.pickFiles(type: fp.FileType.image, withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null) return;
    final ext = (file!.extension ?? '').toLowerCase();
    final mime = ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/png';
    onChanged('data:$mime;base64,${base64Encode(bytes)}');
  }

  @override
  Widget build(BuildContext context) {
    final bytes = bytesFromDataUrl(value);
    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: pickImage,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
              color: filled ? Cp.primaryContainer : Cp.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: filled ? Cp.primaryContainer : Cp.outlineVariant,
                  width: 1.4)),
          child: bytes == null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon,
                      color: filled ? Colors.white : Cp.outline, size: 30),
                  const SizedBox(height: 6),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: filled ? Colors.white : Cp.onVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                  Icon(value.isEmpty ? Icons.add_circle : Icons.edit,
                      color: filled ? Colors.white : Cp.primary, size: 16)
                ])
              : ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.memory(bytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity)),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, this.icon, {super.key});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(children: [
          Icon(icon, color: Cp.primary, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: Cp.primary, fontSize: 16, fontWeight: FontWeight.w900))
        ]),
      );
}
