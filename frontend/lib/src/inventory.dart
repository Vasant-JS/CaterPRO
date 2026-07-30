part of '../main.dart';

class RawMaterialItem {
  const RawMaterialItem(
      {required this.id,
      required this.name,
      required this.category,
      required this.unit});
  final String id;
  final String name;
  final String category;
  final String unit;

  factory RawMaterialItem.fromJson(Map<String, dynamic> json) =>
      RawMaterialItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'category': category, 'unit': unit};
}

String isoToday() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key, required this.events, required this.onClose});

  final List<AppEvent> events;
  final VoidCallback onClose;

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  final api = ApiService();
  final lists = <EventMaterialDocument>[];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadLists();
  }

  Future<void> loadLists() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await api.getRequirementLists();
      if (!mounted) return;
      setState(() {
        lists
          ..clear()
          ..addAll(loaded);
        lists.sort((a, b) => b.date.compareTo(a.date));
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String eventName(String eventId) =>
      widget.events
          .where((event) => event.id == eventId)
          .map((event) => event.name)
          .firstOrNull ??
      '';

  Future<void> chooseListType() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: cpSurface(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cpOutline(context))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                leading: const Icon(Icons.restaurant_menu, color: Cp.primary),
                title: const Text('Menu List',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(context, 'menu')),
            ListTile(
                leading: const Icon(Icons.eco, color: Cp.primary),
                title: const Text('Vegetable List',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(context, 'produce')),
            ListTile(
                leading: const Icon(Icons.soup_kitchen, color: Cp.primary),
                title: const Text('Utensil List',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(context, 'vessels')),
          ]),
        ),
      ),
    );
    if (type == null || !mounted) return;
    final saved = await Navigator.of(context).push<EventMaterialDocument>(
      MaterialPageRoute(
          builder: (_) => ListEditorScreen(
              type: type, events: widget.events, existing: null)),
    );
    if (saved != null) await loadLists();
  }

  Future<void> editList(EventMaterialDocument list) async {
    final saved = await Navigator.of(context).push<EventMaterialDocument>(
      MaterialPageRoute(
          builder: (_) => ListEditorScreen(
              type: list.type, events: widget.events, existing: list)),
    );
    if (saved != null) await loadLists();
  }

  Future<void> downloadList(EventMaterialDocument list) async {
    final uri = await api.requirementListPdfUri(list.id);
    if (!mounted) return;
    showDownloadSnack(context, uri,
        title: '${list.title.isEmpty ? list.typeLabel : list.title}.pdf',
        kind: 'pdf',
        successMessage: 'List PDF download started',
        failureMessage: 'Unable to open PDF');
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        ScreenFrame(
          bottomPadding: 92,
          topBar: TopBar(
              title: 'Lists',
              avatar: false,
              leading: IconButton(
                  onPressed: widget.onClose,
                  icon: Icon(Icons.arrow_back, color: cpPrimary(context)))),
          children: [
            CpCard(
                color: Cp.primaryFixed,
                child: Row(children: [
                  Icon(Icons.checklist, color: cpPrimary(context)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Create menu, vegetable, and utensil lists with optional event association.',
                          style: TextStyle(
                              color: cpPrimary(context),
                              fontWeight: FontWeight.w800)))
                ])),
            const SizedBox(height: 14),
            if (error != null)
              CpCard(
                  color: Cp.errorContainer,
                  child: Text(error!,
                      style: const TextStyle(
                          color: Cp.error, fontWeight: FontWeight.w800))),
            if (loading)
              const Center(child: CircularProgressIndicator(color: Cp.primary)),
            if (!loading && lists.isEmpty)
              const EmptyStateCard(
                  title: 'No lists',
                  message:
                      'Tap + to create a menu, vegetable, or utensil list.'),
            if (!loading)
              ...lists.map((list) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CpCard(
                      onTap: () => editList(list),
                      child: Row(children: [
                        Icon(
                            list.type == 'menu'
                                ? Icons.restaurant_menu
                                : list.type == 'vessels'
                                    ? Icons.soup_kitchen
                                    : Icons.eco,
                            color: cpPrimary(context)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  list.title.isEmpty
                                      ? list.typeLabel
                                      : list.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              Text(
                                  [
                                    if (list.date.isNotEmpty)
                                      readableDateLabel(list.date),
                                    if (eventName(list.eventId).isNotEmpty)
                                      eventName(list.eventId),
                                    '${list.items.length} items'
                                  ].join(' | '),
                                  style: TextStyle(
                                      color: cpOnVariant(context),
                                      fontWeight: FontWeight.w700))
                            ])),
                        IconButton(
                            tooltip: 'Download PDF',
                            onPressed: () => downloadList(list),
                            icon: Icon(Icons.picture_as_pdf,
                                color: cpPrimary(context)))
                      ]),
                    ),
                  ))
          ],
        ),
        Positioned(
          right: 18,
          bottom: 24,
          child: FloatingActionButton(
              heroTag: 'addList',
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onSecondaryContainer,
              onPressed: chooseListType,
              child: const Icon(Icons.add)),
        )
      ]);
}

class ListEditorScreen extends StatefulWidget {
  const ListEditorScreen(
      {super.key, required this.type, required this.events, this.existing});

  final String type;
  final List<AppEvent> events;
  final EventMaterialDocument? existing;

  @override
  State<ListEditorScreen> createState() => _ListEditorScreenState();
}

class _ListEditorScreenState extends State<ListEditorScreen> {
  final api = ApiService();
  final titleController = TextEditingController();
  final searchController = TextEditingController();
  final quantityControllers = <String, TextEditingController>{};
  final unitControllers = <String, TextEditingController>{};
  final selectedIds = <String>{};
  final selectedOrder = <String>[];
  final items = <RawMaterialItem>[];
  bool loading = true;
  bool saving = false;
  String query = '';
  String selectedEventId = '';
  String selectedDate = isoToday();
  String? error;

  String get typeLabel => widget.type == 'menu'
      ? 'Menu List'
      : widget.type == 'vessels'
          ? 'Utensil List'
          : 'Vegetable List';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    titleController.text = existing?.title ?? typeLabel;
    selectedEventId = existing?.eventId ?? '';
    selectedDate =
        existing?.date.isNotEmpty == true ? existing!.date : isoToday();
    loadItems();
  }

  @override
  void dispose() {
    titleController.dispose();
    searchController.dispose();
    for (final controller in quantityControllers.values) {
      controller.dispose();
    }
    for (final controller in unitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> loadItems() async {
    try {
      final loaded = widget.type == 'menu'
          ? MenuMasterScreen.menuItems
              .map((item) => RawMaterialItem(
                  id: item.id,
                  name: item.title,
                  category: item.category,
                  unit: ''))
              .toList()
          : widget.type == 'vessels'
              ? await api.getVesselItems()
              : await api.getProduceItems();
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
            in widget.existing?.items ?? const <EventMaterialLine>[]) {
          selectItem(line.itemId);
          quantityControllers[line.itemId]?.text =
              combinedQuantityUnit(line.quantity, line.unit);
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
    final values = items.where((item) {
      final text = '${item.name} ${item.category}'.toLowerCase();
      return normalized.isEmpty || text.contains(normalized);
    }).toList();
    values.sort((a, b) {
      final aSelected = selectedIds.contains(a.id);
      final bSelected = selectedIds.contains(b.id);
      final selectedCompare = aSelected == bSelected
          ? 0
          : aSelected
              ? -1
              : 1;
      if (selectedCompare != 0) return selectedCompare;
      if (aSelected && bSelected) {
        return selectedOrder
            .indexOf(a.id)
            .compareTo(selectedOrder.indexOf(b.id));
      }
      return a.name.compareTo(b.name);
    });
    return values;
  }

  bool get isMenuList => widget.type == 'menu';

  String combinedQuantityUnit(String quantity, String unit) => [
        quantity.trim(),
        unit.trim()
      ].where((value) => value.isNotEmpty).join(' ');

  (String quantity, String unit) splitQuantityUnit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return ('', '');
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts.first, '');
    return (parts.sublist(0, parts.length - 1).join(' '), parts.last);
  }

  void selectItem(String id) {
    selectedIds.add(id);
    if (!selectedOrder.contains(id)) selectedOrder.add(id);
  }

  void unselectItem(String id) {
    selectedIds.remove(id);
    selectedOrder.remove(id);
  }

  void toggleItem(String id, bool? value) {
    setState(() {
      if (value == true) {
        selectItem(id);
      } else {
        unselectItem(id);
      }
    });
  }

  void reorderVisibleItems(int oldIndex, int newIndex) {
    final visible = visibleItems;
    final moving = visible[oldIndex];
    if (!selectedIds.contains(moving.id)) return;
    final selectedVisible =
        visible.where((item) => selectedIds.contains(item.id)).toList();
    final from = selectedVisible.indexWhere((item) => item.id == moving.id);
    final beforeTarget = newIndex >= visible.length ? null : visible[newIndex];
    var to = selectedVisible.length - 1;
    if (beforeTarget != null && selectedIds.contains(beforeTarget.id)) {
      to = selectedVisible.indexWhere((item) => item.id == beforeTarget.id);
    }
    if (from < 0 || to < 0 || from == to) return;
    setState(() {
      final id = selectedOrder.removeAt(selectedOrder.indexOf(moving.id));
      selectedOrder.insert(to, id);
    });
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
                    meals: 'Breakfast, Lunch, Dinner',
                    veg: true,
                  ),
                  creating: true,
                );
                if (context.mounted) Navigator.pop(context, saved);
              } catch (e) {
                setDialogState(() {
                  popupError = e.toString().replaceFirst('Exception: ', '');
                  savingItem = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Add menu item'),
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
        items.add(RawMaterialItem(
            id: item.id, name: item.title, category: item.category, unit: ''));
        quantityControllers[item.id] = TextEditingController();
        unitControllers[item.id] = TextEditingController();
        selectItem(item.id);
        query = '';
        searchController.clear();
      });
      showCpSnack(context, 'Menu item added');
    } finally {
      english.dispose();
      kannada.dispose();
    }
  }

  Future<void> pickDate() async {
    final initial = parseIsoDate(selectedDate) ?? DateTime.now();
    final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (picked == null) return;
    setState(() {
      selectedDate =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> save() async {
    final lines = <EventMaterialLine>[];
    final byId = {for (final item in items) item.id: item};
    for (final itemId in selectedOrder.where(selectedIds.contains)) {
      final item = byId[itemId];
      if (item == null) continue;
      final quantityUnit = splitQuantityUnit(
          isMenuList ? '' : quantityControllers[item.id]?.text ?? '');
      lines.add(EventMaterialLine(
          itemId: item.id,
          name: item.name,
          category: item.category,
          quantity: quantityUnit.$1,
          unit: quantityUnit.$2));
    }
    if (lines.isEmpty) {
      setState(() => error = 'Select at least one item.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved = await api.saveRequirementList(EventMaterialDocument(
          id: widget.existing?.id ?? '',
          type: widget.type,
          title: titleController.text.trim().isEmpty
              ? typeLabel
              : titleController.text.trim(),
          eventId: selectedEventId,
          date: selectedDate,
          items: lines));
      if (!mounted) return;
      showCpSnack(context, 'List saved');
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
        color: cpSurface(context),
        child: ScreenFrame(
          topBar: TopBar(
              title: typeLabel,
              avatar: false,
              leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Cp.primary)),
              actions: [
                TextButton(
                    onPressed: saving ? null : save,
                    child: Text(saving ? 'Saving...' : 'Save',
                        style: const TextStyle(fontWeight: FontWeight.w900)))
              ]),
          children: [
            EditableInlineField(
                label: 'List Name', controller: titleController),
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final eventOptionsById = <String, AppEvent>{};
              for (final event in widget.events) {
                final eventId = event.id.trim();
                if (eventId.isEmpty) continue;
                eventOptionsById.putIfAbsent(eventId, () => event);
              }
              final eventOptions = eventOptionsById.values.toList();
              final dropdownEventId =
                  eventOptionsById.containsKey(selectedEventId)
                      ? selectedEventId
                      : '';
              final dateField = InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: pickDate,
                child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(Icons.calendar_month),
                        border: OutlineInputBorder()),
                    child: Text(readableDateLabel(selectedDate),
                        overflow: TextOverflow.ellipsis)),
              );
              final eventField = DropdownButtonFormField<String>(
                initialValue: dropdownEventId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Event',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder()),
                selectedItemBuilder: (context) => [
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('No event selected',
                          overflow: TextOverflow.ellipsis)),
                  ...eventOptions.map((event) => Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (event.primaryClient.trim().isNotEmpty)
                                Text(event.primaryClient,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: Cp.onVariant)),
                            ]),
                      ))
                ],
                items: [
                  const DropdownMenuItem(
                      value: '', child: Text('No event selected')),
                  ...eventOptions.map((event) => DropdownMenuItem(
                      value: event.id,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (event.primaryClient.trim().isNotEmpty)
                              Text(event.primaryClient,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Cp.onVariant)),
                          ])))
                ],
                onChanged: (value) =>
                    setState(() => selectedEventId = value ?? ''),
              );
              return Row(children: [
                Expanded(child: dateField),
                const SizedBox(width: 10),
                Expanded(child: eventField),
              ]);
            }),
            const SizedBox(height: 12),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search items',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
              onChanged: (value) => setState(() => query = value),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!,
                  style: const TextStyle(
                      color: Cp.error, fontWeight: FontWeight.w800))
            ],
            const SizedBox(height: 12),
            if (loading)
              const Center(child: CircularProgressIndicator(color: Cp.primary)),
            if (!loading && visibleItems.isEmpty)
              isMenuList
                  ? CpCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                color: Cp.outline, size: 36),
                            const SizedBox(height: 14),
                            const Text('No items',
                                style: TextStyle(
                                    color: Cp.primary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            const Text('No items match this search.'),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                  onPressed: addMenuItemPopup,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add menu item')),
                            ),
                          ]),
                    )
                  : const EmptyStateCard(
                      title: 'No items',
                      message: 'No items match this search.'),
            if (!loading)
              ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: visibleItems.length,
                  onReorderItem: reorderVisibleItems,
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    final selected = selectedIds.contains(item.id);
                    return Padding(
                      key: ValueKey(item.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: CpCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Checkbox(
                              value: selected,
                              onChanged: (value) => toggleItem(item.id, value)),
                          Expanded(
                              flex: isMenuList ? 1 : 85,
                              child: Text(item.name,
                                  maxLines: isMenuList ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Cp.primary,
                                      fontWeight: FontWeight.w800))),
                          if (!isMenuList) ...[
                            const SizedBox(width: 8),
                            Expanded(
                                flex: 30,
                                child: TextField(
                                    controller: quantityControllers[item.id],
                                    decoration: const InputDecoration(
                                        labelText: 'Qty / Unit', isDense: true),
                                    onChanged: (_) =>
                                        setState(() => selectItem(item.id)))),
                          ],
                          if (selected) ...[
                            const SizedBox(width: 6),
                            ReorderableDragStartListener(
                                index: index,
                                child: const Icon(Icons.drag_indicator,
                                    color: Cp.onVariant)),
                          ],
                        ]),
                      ),
                    );
                  }),
          ],
        ),
      );
}

class RawMaterialScreen extends StatefulWidget {
  const RawMaterialScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<RawMaterialScreen> createState() => _RawMaterialScreenState();
}

class _RawMaterialScreenState extends State<RawMaterialScreen> {
  final api = ApiService();
  final items = <RawMaterialItem>[];
  final searchController = TextEditingController();
  String query = '';
  String selectedCategory = 'All';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadRawMaterials();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadRawMaterials() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await api.getRawMaterials();
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> get categories {
    final values = items
        .map((item) => item.category)
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<RawMaterialItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    return items.where((item) {
      final matchesCategory =
          selectedCategory == 'All' || item.category == selectedCategory;
      final text =
          '${item.id} ${item.name} ${item.category} ${item.unit}'.toLowerCase();
      return matchesCategory &&
          (normalized.isEmpty || text.contains(normalized));
    }).toList();
  }

  Future<void> upsertRawMaterial(RawMaterialItem item) async {
    try {
      final saved = await api.saveRawMaterial(item);
      setState(() {
        final index = items.indexWhere((existing) => existing.id == saved.id);
        if (index == -1) {
          items.add(saved);
        } else {
          items[index] = saved;
        }
      });
      if (mounted) showCpSnack(context, 'Raw material saved');
    } catch (e) {
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> deleteRawMaterial(RawMaterialItem item) async {
    final confirmed = await confirmDeleteCatalogItem(context, item.name);
    if (!confirmed) return;
    final previous = List<RawMaterialItem>.from(items);
    setState(() => items.removeWhere((entry) => entry.id == item.id));
    try {
      await api.deleteRawMaterial(item.id);
      if (mounted) showCpSnack(context, 'Raw material deleted');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(previous);
      });
      showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          ScreenFrame(
            bottomPadding: 92,
            topBar: TopBar(
                title: 'Raw Materials',
                avatar: false,
                leading: IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.arrow_back, color: Cp.primary))),
            children: [
              CpCard(
                  color: Cp.primaryFixed,
                  child: const Row(children: [
                    Icon(Icons.public, color: Cp.primary),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'Your private raw material catalog. Add, rename, edit, or delete items without sharing them with other users.',
                            style: TextStyle(
                                color: Cp.primary,
                                fontWeight: FontWeight.w800)))
                  ])),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(() {
                                  query = '';
                                  searchController.clear();
                                }),
                            icon: const Icon(Icons.close)),
                    hintText: 'Search raw materials',
                    filled: true,
                    fillColor: Cp.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 12),
              if (error != null) ...[
                CpCard(
                    color: Cp.errorContainer,
                    child: Text(error!,
                        style: const TextStyle(
                            color: Cp.error, fontWeight: FontWeight.w800))),
                const SizedBox(height: 12)
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((category) {
                    final selected = category == selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () =>
                            setState(() => selectedCategory = category),
                        child: Pill(category,
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
              if (loading)
                const Center(
                    child: CircularProgressIndicator(color: Cp.primary)),
              if (!loading && visibleItems.isEmpty)
                const EmptyStateCard(
                    title: 'No raw materials',
                    message: 'No items match this search.'),
              if (!loading)
                ...visibleItems.map((item) => RawMaterialCard(
                    item: item,
                    onEdit: () => showRawMaterialEditor(context, item: item,
                            onSave: (value) {
                          upsertRawMaterial(value);
                        }),
                    onDelete: () => deleteRawMaterial(item))),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'addRawMaterial',
              backgroundColor: Cp.secondaryContainer,
              foregroundColor: const Color(0xff694000),
              onPressed: () => showRawMaterialEditor(context, onSave: (value) {
                upsertRawMaterial(value);
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add Item',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      );
}

class ProduceItemScreen extends StatefulWidget {
  const ProduceItemScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<ProduceItemScreen> createState() => _ProduceItemScreenState();
}

class _ProduceItemScreenState extends State<ProduceItemScreen> {
  final api = ApiService();
  final items = <RawMaterialItem>[];
  final searchController = TextEditingController();
  String query = '';
  String selectedCategory = 'All';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadItems() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await api.getProduceItems();
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> get categories {
    final values = items
        .map((item) => item.category)
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<RawMaterialItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    return items.where((item) {
      final matchesCategory =
          selectedCategory == 'All' || item.category == selectedCategory;
      final text =
          '${item.id} ${item.name} ${item.category} ${item.unit}'.toLowerCase();
      return matchesCategory &&
          (normalized.isEmpty || text.contains(normalized));
    }).toList();
  }

  Future<void> upsertItem(RawMaterialItem item) async {
    try {
      final saved = await api.saveProduceItem(item);
      setState(() {
        final index = items.indexWhere((existing) => existing.id == saved.id);
        if (index == -1) {
          items.add(saved);
        } else {
          items[index] = saved;
        }
      });
      if (mounted) showCpSnack(context, 'Vegetable/fruit saved');
    } catch (e) {
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> deleteItem(RawMaterialItem item) async {
    final confirmed = await confirmDeleteCatalogItem(context, item.name);
    if (!confirmed) return;
    final previous = List<RawMaterialItem>.from(items);
    setState(() => items.removeWhere((entry) => entry.id == item.id));
    try {
      await api.deleteProduceItem(item.id);
      if (mounted) showCpSnack(context, 'Vegetable/fruit deleted');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(previous);
      });
      showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          ScreenFrame(
            bottomPadding: 92,
            topBar: TopBar(
                title: 'Vegetables & Fruits',
                avatar: false,
                leading: IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.arrow_back, color: Cp.primary))),
            children: [
              CpCard(
                  color: Cp.primaryFixed,
                  child: const Row(children: [
                    Icon(Icons.public, color: Cp.primary),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'Your private vegetables and fruits catalog. Add, rename, edit, or delete items without sharing them with other users.',
                            style: TextStyle(
                                color: Cp.primary,
                                fontWeight: FontWeight.w800)))
                  ])),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(() {
                                  query = '';
                                  searchController.clear();
                                }),
                            icon: const Icon(Icons.close)),
                    hintText: 'Search vegetables and fruits',
                    filled: true,
                    fillColor: Cp.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 12),
              if (error != null) ...[
                CpCard(
                    color: Cp.errorContainer,
                    child: Text(error!,
                        style: const TextStyle(
                            color: Cp.error, fontWeight: FontWeight.w800))),
                const SizedBox(height: 12)
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((category) {
                    final selected = category == selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () =>
                            setState(() => selectedCategory = category),
                        child: Pill(category,
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
              if (loading)
                const Center(
                    child: CircularProgressIndicator(color: Cp.primary)),
              if (!loading && visibleItems.isEmpty)
                const EmptyStateCard(
                    title: 'No vegetables/fruits',
                    message: 'No items match this search.'),
              if (!loading)
                ...visibleItems.map((item) => RawMaterialCard(
                    item: item,
                    onEdit: () => showRawMaterialEditor(context,
                            item: item,
                            noun: 'Vegetable/Fruit', onSave: (value) {
                          upsertItem(value);
                        }),
                    onDelete: () => deleteItem(item))),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'addProduceItem',
              backgroundColor: Cp.secondaryContainer,
              foregroundColor: const Color(0xff694000),
              onPressed: () => showRawMaterialEditor(context,
                  noun: 'Vegetable/Fruit', onSave: (value) {
                upsertItem(value);
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add Item',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      );
}

class VesselItemScreen extends StatefulWidget {
  const VesselItemScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<VesselItemScreen> createState() => _VesselItemScreenState();
}

class _VesselItemScreenState extends State<VesselItemScreen> {
  final api = ApiService();
  final items = <RawMaterialItem>[];
  final searchController = TextEditingController();
  String query = '';
  String selectedCategory = 'All';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadItems();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadItems() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await api.getVesselItems();
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> get categories {
    final values = items
        .map((item) => item.category)
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<RawMaterialItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    return items.where((item) {
      final matchesCategory =
          selectedCategory == 'All' || item.category == selectedCategory;
      final text =
          '${item.id} ${item.name} ${item.category} ${item.unit}'.toLowerCase();
      return matchesCategory &&
          (normalized.isEmpty || text.contains(normalized));
    }).toList();
  }

  Future<void> upsertItem(RawMaterialItem item) async {
    try {
      final saved = await api.saveVesselItem(item);
      setState(() {
        final index = items.indexWhere((existing) => existing.id == saved.id);
        if (index == -1) {
          items.add(saved);
        } else {
          items[index] = saved;
        }
      });
      if (mounted) showCpSnack(context, 'Vessel/utensil saved');
    } catch (e) {
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> deleteItem(RawMaterialItem item) async {
    final confirmed = await confirmDeleteCatalogItem(context, item.name);
    if (!confirmed) return;
    final previous = List<RawMaterialItem>.from(items);
    setState(() => items.removeWhere((entry) => entry.id == item.id));
    try {
      await api.deleteVesselItem(item.id);
      if (mounted) showCpSnack(context, 'Vessel/utensil deleted');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        items
          ..clear()
          ..addAll(previous);
      });
      showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          ScreenFrame(
            bottomPadding: 92,
            topBar: TopBar(
                title: 'Vessels & Utensils',
                avatar: false,
                leading: IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.arrow_back, color: Cp.primary))),
            children: [
              CpCard(
                  color: Cp.primaryFixed,
                  child: const Row(children: [
                    Icon(Icons.soup_kitchen, color: Cp.primary),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'Your private vessels and utensils catalog. Add, rename, edit, or delete items without sharing them with other users.',
                            style: TextStyle(
                                color: Cp.primary,
                                fontWeight: FontWeight.w800)))
                  ])),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(() {
                                  query = '';
                                  searchController.clear();
                                }),
                            icon: const Icon(Icons.close)),
                    hintText: 'Search vessels and utensils',
                    filled: true,
                    fillColor: Cp.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 12),
              if (error != null) ...[
                CpCard(
                    color: Cp.errorContainer,
                    child: Text(error!,
                        style: const TextStyle(
                            color: Cp.error, fontWeight: FontWeight.w800))),
                const SizedBox(height: 12)
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((category) {
                    final selected = category == selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () =>
                            setState(() => selectedCategory = category),
                        child: Pill(category,
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
              if (loading)
                const Center(
                    child: CircularProgressIndicator(color: Cp.primary)),
              if (!loading && visibleItems.isEmpty)
                const EmptyStateCard(
                    title: 'No vessels/utensils',
                    message: 'No items match this search.'),
              if (!loading)
                ...visibleItems.map((item) => RawMaterialCard(
                    item: item,
                    onEdit: () => showRawMaterialEditor(context,
                            item: item,
                            noun: 'Vessel/Utensil', onSave: (value) {
                          upsertItem(value);
                        }),
                    onDelete: () => deleteItem(item))),
            ],
          ),
          Positioned(
            right: 18,
            bottom: 24,
            child: FloatingActionButton.extended(
              heroTag: 'addVesselItem',
              backgroundColor: Cp.secondaryContainer,
              foregroundColor: const Color(0xff694000),
              onPressed: () => showRawMaterialEditor(context,
                  noun: 'Vessel/Utensil', onSave: (value) {
                upsertItem(value);
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add Item',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      );
}

class RawMaterialCard extends StatelessWidget {
  const RawMaterialCard(
      {super.key,
      required this.item,
      required this.onEdit,
      required this.onDelete});
  final RawMaterialItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CpCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: onEdit,
          child: Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: Cp.primaryFixed,
                    borderRadius: BorderRadius.circular(8)),
                child:
                    const Icon(Icons.inventory_2, color: Cp.primary, size: 21)),
            const SizedBox(width: 10),
            Expanded(
              child: MarqueeText(
                item.name,
                style: kannadaMenuTextStyle(context,
                        fontSize: 14, fontWeight: FontWeight.w800)
                    .copyWith(color: Cp.primary),
              ),
            ),
            IconButton(
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit, color: Cp.primary)),
            IconButton(
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Cp.error)),
          ]),
        ),
      );
}

Future<bool> confirmDeleteCatalogItem(BuildContext context, String name) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete item?'),
          content: Text('Delete "$name" from your private catalog?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete')),
          ],
        ),
      ) ??
      false;
}

class RawMaterialCardLegacy extends StatelessWidget {
  const RawMaterialCardLegacy(
      {super.key, required this.item, required this.onEdit});
  final RawMaterialItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CpCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: onEdit,
          child: Row(children: [
            Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: Cp.primaryFixed,
                    borderRadius: BorderRadius.circular(8)),
                child:
                    const Icon(Icons.inventory_2, color: Cp.primary, size: 21)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.name,
                      style: const TextStyle(
                          color: Cp.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w500)),
                  Text('${item.id} | ${item.category}',
                      style: const TextStyle(
                          color: Cp.onVariant, fontWeight: FontWeight.w700))
                ])),
            Pill(item.unit),
            IconButton(
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit, color: Cp.primary)),
          ]),
        ),
      );
}

void showRawMaterialEditor(BuildContext context,
    {RawMaterialItem? item,
    required ValueChanged<RawMaterialItem> onSave,
    String noun = 'Raw Material'}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        RawMaterialEditorSheet(item: item, onSave: onSave, noun: noun),
  );
}

class RawMaterialEditorSheet extends StatefulWidget {
  const RawMaterialEditorSheet(
      {super.key, this.item, required this.onSave, required this.noun});
  final RawMaterialItem? item;
  final ValueChanged<RawMaterialItem> onSave;
  final String noun;

  @override
  State<RawMaterialEditorSheet> createState() => _RawMaterialEditorSheetState();
}

class _RawMaterialEditorSheetState extends State<RawMaterialEditorSheet> {
  late final id = TextEditingController(text: widget.item?.id ?? '');
  late final name = TextEditingController(text: widget.item?.name ?? '');
  late final category =
      TextEditingController(text: widget.item?.category ?? '');
  late final unit = TextEditingController(text: widget.item?.unit ?? '');
  String? error;

  @override
  void dispose() {
    id.dispose();
    name.dispose();
    category.dispose();
    unit.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().isEmpty ||
        category.text.trim().isEmpty ||
        unit.text.trim().isEmpty) {
      setState(() => error = 'Fill Name, Category, and Unit.');
      return;
    }
    widget.onSave(RawMaterialItem(
        id: id.text.trim(),
        name: name.text.trim(),
        category: category.text.trim(),
        unit: unit.text.trim()));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(
              20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          decoration: BoxDecoration(
              color: cpSurface(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28))),
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
                              color: cpOutlineVariant(context),
                              borderRadius: BorderRadius.circular(99)))),
                  Text(
                      widget.item == null
                          ? 'Add ${widget.noun}'
                          : 'Edit ${widget.noun}',
                      style: TextStyle(
                          color: cpPrimary(context),
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  Text('Universal item, available to every user.',
                      style: TextStyle(color: cpOnVariant(context))),
                  const SizedBox(height: 16),
                  EditableInlineField(label: 'ID', controller: id),
                  EditableInlineField(label: 'Name', controller: name),
                  Row(children: [
                    Expanded(
                        child: EditableInlineField(
                            label: 'Category', controller: category)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: EditableInlineField(
                            label: 'Unit', controller: unit))
                  ]),
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
                          onPressed: save,
                          style: FilledButton.styleFrom(
                              backgroundColor: Cp.primaryContainer),
                          icon: const Icon(Icons.save),
                          label: Text('Save ${widget.noun}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900)))),
                ]),
          ),
        ),
      );
}
