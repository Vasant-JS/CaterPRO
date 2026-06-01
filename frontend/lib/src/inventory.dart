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

class RawMaterialScreen extends StatefulWidget {
  const RawMaterialScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  State<RawMaterialScreen> createState() => _RawMaterialScreenState();
}

class _RawMaterialScreenState extends State<RawMaterialScreen> {
  final api = ApiService();
  final items = <RawMaterialItem>[];
  String query = '';
  String selectedCategory = 'All';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadRawMaterials();
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
                            'Universal raw material catalog. Add/edit only. Every user can access these items.',
                            style: TextStyle(
                                color: Cp.primary,
                                fontWeight: FontWeight.w800)))
                  ])),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search raw materials',
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
                        }))),
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
  String query = '';
  String selectedCategory = 'All';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadItems();
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
                            'Universal vegetables and fruits catalog in Kannada. Add/edit only. Every user can access these items.',
                            style: TextStyle(
                                color: Cp.primary,
                                fontWeight: FontWeight.w800)))
                  ])),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search vegetables and fruits',
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
                        }))),
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

class RawMaterialCard extends StatelessWidget {
  const RawMaterialCard({super.key, required this.item, required this.onEdit});
  final RawMaterialItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          onTap: onEdit,
          child: Row(children: [
            Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: Cp.primaryFixed,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.inventory_2, color: Cp.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.name,
                      style: const TextStyle(
                          color: Cp.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w500)),
                  Text('${item.id} • ${item.category}',
                      style: const TextStyle(
                          color: Cp.onVariant, fontWeight: FontWeight.w700))
                ])),
            Pill(item.unit),
            IconButton(
                onPressed: onEdit,
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
                  Text(
                      widget.item == null
                          ? 'Add ${widget.noun}'
                          : 'Edit ${widget.noun}',
                      style: const TextStyle(
                          color: Cp.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const Text('Universal item, available to every user.',
                      style: TextStyle(color: Cp.onVariant)),
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
