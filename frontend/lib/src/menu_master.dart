part of '../main.dart';

class MenuMasterItem {
  const MenuMasterItem(
      {required this.id,
      required this.english,
      required this.kannada,
      required this.category,
      required this.meals,
      required this.veg});
  final String id;
  final String english;
  final String kannada;
  final String category;
  final String meals;
  final bool veg;

  String get title => '$kannada/$english';

  factory MenuMasterItem.fromJson(Map<String, dynamic> json) {
    final mealsValue = json['meals'];
    final mealsText = mealsValue is List
        ? mealsValue.map((item) => item.toString()).join(', ')
        : mealsValue?.toString() ?? '';
    return MenuMasterItem(
      id: json['id']?.toString() ?? '',
      english: json['english']?.toString() ?? '',
      kannada: json['kannada']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      meals: mealsText,
      veg: json['veg'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'english': english,
        'kannada': kannada,
        'category': category,
        'meals': meals
            .split(',')
            .map((meal) => meal.trim())
            .where((meal) => meal.isNotEmpty)
            .toList(),
        'veg': veg,
      };
}

MenuMasterItem? menuItemById(String id) {
  for (final item in MenuMasterScreen.menuItems) {
    if (item.id == id) return item;
  }
  return null;
}

int selectedOrder(String id, Set<String> selectedIds) {
  var index = 0;
  for (final selectedId in selectedIds) {
    if (selectedId == id) return index;
    index++;
  }
  return -1;
}

class MenuMasterScreen extends StatefulWidget {
  const MenuMasterScreen({super.key, required this.onClose});
  final VoidCallback onClose;

  static final List<MenuMasterItem> menuItems = [];

  @override
  State<MenuMasterScreen> createState() => _MenuMasterScreenState();
}

class _MenuMasterScreenState extends State<MenuMasterScreen> {
  final api = ApiService();
  String query = '';
  String selectedMealFilter = 'All';
  bool vegOnly = false;

  List<MenuMasterItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    return MenuMasterScreen.menuItems.where((item) {
      final text =
          '${item.id} ${item.english} ${item.kannada} ${item.category} ${item.meals}'
              .toLowerCase();
      final matchesSearch = normalized.isEmpty || text.contains(normalized);
      final matchesMeal = selectedMealFilter == 'All' ||
          item.meals
              .split(',')
              .map((meal) => meal.trim())
              .contains(selectedMealFilter);
      final matchesVeg = !vegOnly || item.veg;
      return matchesSearch && matchesMeal && matchesVeg;
    }).toList();
  }

  void upsertMenuItem(MenuMasterItem item) {
    setState(() {
      final index = MenuMasterScreen.menuItems
          .indexWhere((existing) => existing.id == item.id);
      if (index == -1) {
        MenuMasterScreen.menuItems.add(item);
      } else {
        MenuMasterScreen.menuItems[index] = item;
      }
    });
    unawaited(api.saveMenuItem(item).then((saved) {
      if (!mounted) return;
      setState(() {
        final index = MenuMasterScreen.menuItems
            .indexWhere((existing) => existing.id == saved.id);
        if (index == -1) {
          MenuMasterScreen.menuItems.add(saved);
        } else {
          MenuMasterScreen.menuItems[index] = saved;
        }
      });
    }).catchError((error) {
      if (mounted) {
        showCpSnack(context, error.toString().replaceFirst('Exception: ', ''));
      }
    }));
  }

  @override
  Widget build(BuildContext context) => ScreenFrame(
          topBar: TopBar(
              title: 'Menu Master',
              avatar: false,
              leading: IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.arrow_back, color: Cp.primary)),
              actions: [
                IconButton(
                    onPressed: () =>
                        showMenuItemEditor(context, onSave: upsertMenuItem),
                    icon: const Icon(Icons.add))
              ]),
          children: [
            CpCard(
                color: Cp.primaryFixed,
                child: const Row(children: [
                  Icon(Icons.public, color: Cp.primary),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Universal menu catalog. Add/edit only. Every user can access these items.',
                          style: TextStyle(
                              color: Cp.primary, fontWeight: FontWeight.w800)))
                ])),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search menu items',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...['All', 'Breakfast', 'Juice', 'Lunch', 'Snack', 'Dinner']
                      .map((filter) {
                    final selected = selectedMealFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () =>
                            setState(() => selectedMealFilter = filter),
                        child: Pill(filter,
                            color:
                                selected ? Cp.primaryContainer : Cp.surfaceHigh,
                            textColor: selected ? Colors.white : Cp.onVariant,
                            icon: selected ? Icons.check : null),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => setState(() => vegOnly = !vegOnly),
                      child: Pill('Veg Only',
                          color:
                              vegOnly ? Cp.tertiaryContainer : Cp.surfaceHigh,
                          textColor: vegOnly ? Colors.white : Cp.onVariant,
                          icon: vegOnly ? Icons.check : Icons.eco),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ...visibleItems.map((item) => MenuItemCard(
                item: item,
                onEdit: () => showMenuItemEditor(context,
                    item: item, onSave: upsertMenuItem))),
            const SizedBox(height: 18),
            CpCard(
                color: Cp.primaryContainer,
                child: Text(
                    'Universal Menu Items\n${MenuMasterScreen.menuItems.length} Items',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900))),
          ]);
}

class MenuItemCard extends StatefulWidget {
  const MenuItemCard({super.key, required this.item, required this.onEdit});
  final MenuMasterItem item;
  final VoidCallback onEdit;

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  bool active = true;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CpCard(
          onTap: widget.onEdit,
          child: Row(children: [
            Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                    color: widget.item.veg
                        ? Cp.tertiaryFixed.withValues(alpha: .3)
                        : Cp.errorContainer,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.restaurant,
                    color: widget.item.veg ? Cp.tertiary : Cp.error)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.id,
                        style: const TextStyle(
                            color: Cp.outline,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                    Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color:
                                  widget.item.veg ? Colors.green : Colors.red,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(widget.item.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)))
                    ]),
                    Text('${widget.item.category} • ${widget.item.meals}',
                        style: const TextStyle(color: Cp.onVariant)),
                  ]),
            ),
            IconButton(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit, color: Cp.primary)),
            Switch(
                value: active,
                activeThumbColor: Cp.primaryContainer,
                onChanged: (value) => setState(() => active = value)),
          ]),
        ),
      );
}

void showMenuItemEditor(BuildContext context,
    {MenuMasterItem? item, required ValueChanged<MenuMasterItem> onSave}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MenuItemEditorSheet(item: item, onSave: onSave),
  );
}

class MenuItemEditorSheet extends StatefulWidget {
  const MenuItemEditorSheet({super.key, this.item, required this.onSave});
  final MenuMasterItem? item;
  final ValueChanged<MenuMasterItem> onSave;

  @override
  State<MenuItemEditorSheet> createState() => _MenuItemEditorSheetState();
}

class _MenuItemEditorSheetState extends State<MenuItemEditorSheet> {
  static const categoryOptions = [
    'Starter',
    'Main Course',
    'Dessert',
    'South Indian',
    'Beverage',
    'Snack',
    'Other'
  ];
  static const mealOptions = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Other',
    'Snack',
    'Juice'
  ];
  late final id = TextEditingController(
      text: widget.item?.id ??
          'MNU-${(MenuMasterScreen.menuItems.length + 1).toString().padLeft(3, '0')}');
  late final english = TextEditingController(text: widget.item?.english ?? '');
  late final kannada = TextEditingController(text: widget.item?.kannada ?? '');
  late String category = categoryOptions.contains(widget.item?.category)
      ? widget.item!.category
      : categoryOptions.first;
  late Set<String> selectedMeals = {
    if (widget.item != null)
      ...widget.item!.meals
          .split(',')
          .map((meal) => meal.trim())
          .where((meal) => mealOptions.contains(meal)),
  };
  late bool veg = widget.item?.veg ?? true;
  String? error;

  @override
  void dispose() {
    id.dispose();
    english.dispose();
    kannada.dispose();
    super.dispose();
  }

  void save() {
    if (id.text.trim().isEmpty ||
        english.text.trim().isEmpty ||
        kannada.text.trim().isEmpty ||
        selectedMeals.isEmpty) {
      setState(() => error =
          'Fill ID, English, Kannada, Category, and at least one Meal.');
      return;
    }
    final meals = mealOptions.where(selectedMeals.contains).join(', ');
    widget.onSave(MenuMasterItem(
        id: id.text.trim(),
        english: english.text.trim(),
        kannada: kannada.text.trim(),
        category: category,
        meals: meals,
        veg: veg));
    Navigator.pop(context);
  }

  Future<void> pickMeals() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          MealCheckboxSheet(options: mealOptions, selected: selectedMeals),
    );
    if (result != null) setState(() => selectedMeals = result);
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
                  Text(widget.item == null ? 'Add Menu Item' : 'Edit Menu Item',
                      style: const TextStyle(
                          color: Cp.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const Text('Universal item, available to every user.',
                      style: TextStyle(color: Cp.onVariant)),
                  const SizedBox(height: 16),
                  EditableInlineField(label: 'ID', controller: id),
                  Row(children: [
                    Expanded(
                        child: EditableInlineField(
                            label: 'English', controller: english)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: EditableInlineField(
                            label: 'Kannada', controller: kannada))
                  ]),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12))),
                        items: categoryOptions
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => category = value ?? category),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: pickMeals,
                        child: InputDecorator(
                          decoration: InputDecoration(
                              labelText: 'Meals',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: Row(children: [
                            Expanded(
                                child: Text(
                                    selectedMeals.isEmpty
                                        ? 'Select meals'
                                        : mealOptions
                                            .where(selectedMeals.contains)
                                            .join(', '),
                                    overflow: TextOverflow.ellipsis)),
                            const Icon(Icons.arrow_drop_down,
                                color: Cp.primary),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: veg,
                      activeThumbColor: Cp.primary,
                      onChanged: (value) => setState(() => veg = value),
                      title: const Text('Vegetarian',
                          style: TextStyle(fontWeight: FontWeight.w900))),
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
                          label: const Text('Save Menu Item',
                              style: TextStyle(fontWeight: FontWeight.w900)))),
                ]),
          ),
        ),
      );
}

class MealCheckboxSheet extends StatefulWidget {
  const MealCheckboxSheet(
      {super.key, required this.options, required this.selected});
  final List<String> options;
  final Set<String> selected;

  @override
  State<MealCheckboxSheet> createState() => _MealCheckboxSheetState();
}

class _MealCheckboxSheetState extends State<MealCheckboxSheet> {
  late final Set<String> selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .78),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: const BoxDecoration(
            color: Cp.card,
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
              const Text('Select Meals',
                  style: TextStyle(
                      color: Cp.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: widget.options
                      .map((meal) => CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: selected.contains(meal),
                            activeColor: Cp.primary,
                            onChanged: (value) => setState(() => value == true
                                ? selected.add(meal)
                                : selected.remove(meal)),
                            title: Text(meal,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Cp.primaryContainer),
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('Apply Meals',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
      ),
    );
  }
}

class CustomMenuScreen extends StatefulWidget {
  const CustomMenuScreen(
      {super.key,
      required this.onClose,
      required this.customMenus,
      required this.onSave});
  final VoidCallback onClose;
  final List<CustomMenu> customMenus;
  final Future<void> Function(CustomMenu menu) onSave;

  static const types = [
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
    'Juice',
    'Other'
  ];

  @override
  State<CustomMenuScreen> createState() => _CustomMenuScreenState();
}

class _CustomMenuScreenState extends State<CustomMenuScreen> {
  int selectedTypeIndex = 0;
  bool saving = false;

  String get selectedType => CustomMenuScreen.types[selectedTypeIndex];

  List<CustomMenu> get visibleMenus {
    return widget.customMenus
        .where((menu) => menu.type == selectedType)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> openEditor([CustomMenu? menu]) async {
    final saved = await showModalBottomSheet<CustomMenu>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CustomMenuEditorSheet(type: selectedType, menu: menu),
    );
    if (saved == null) return;
    setState(() => saving = true);
    try {
      await widget.onSave(saved);
      if (mounted) showCpSnack(context, 'Custom menu saved');
    } catch (e) {
      if (mounted) {
        showCpSnack(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      topBar: TopBar(
        title: 'Custom Menus',
        avatar: false,
        leading: IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.arrow_back, color: Cp.primary)),
        actions: [
          IconButton(
              onPressed: saving ? null : () => openEditor(),
              icon: const Icon(Icons.add, color: Cp.primary))
        ],
      ),
      children: [
        CpCard(
            color: Cp.primaryFixed,
            child: const Row(children: [
              Icon(Icons.fact_check, color: Cp.primary),
              SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'Ready made menu sets are saved under your user and can be applied during event menu selection.',
                      style: TextStyle(
                          color: Cp.primary, fontWeight: FontWeight.w800)))
            ])),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(CustomMenuScreen.types.length, (index) {
              final type = CustomMenuScreen.types[index];
              final selected = index == selectedTypeIndex;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => setState(() => selectedTypeIndex = index),
                  child: Pill(type,
                      color: selected ? Cp.primaryContainer : Cp.surfaceHigh,
                      textColor: selected ? Colors.white : Cp.onVariant,
                      icon: selected ? Icons.check : null),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        DashedAction(
            label: 'Add $selectedType Custom Menu',
            icon: Icons.add_circle,
            onTap: saving ? null : () => openEditor()),
        const SizedBox(height: 14),
        if (visibleMenus.isEmpty)
          EmptyStateCard(
              title: 'No $selectedType custom menus',
              message: 'Tap + to create a ready made $selectedType menu.')
        else
          ...visibleMenus.map((menu) {
            final names = menu.itemIds
                .map((id) => menuItemById(id)?.english ?? id)
                .take(5)
                .join(', ');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CpCard(
                onTap: () => openEditor(menu),
                child: Row(children: [
                  const Icon(Icons.playlist_add_check, color: Cp.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(menu.name,
                              style: const TextStyle(
                                  color: Cp.primary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900)),
                          Text(
                              '${menu.itemIds.length} items${names.isEmpty ? '' : ' • $names'}',
                              style: const TextStyle(
                                  color: Cp.onVariant,
                                  fontWeight: FontWeight.w700)),
                        ]),
                  ),
                  const Icon(Icons.edit, color: Cp.primary),
                ]),
              ),
            );
          }),
      ],
    );
  }
}

class CustomMenuEditorSheet extends StatefulWidget {
  const CustomMenuEditorSheet({super.key, required this.type, this.menu});
  final String type;
  final CustomMenu? menu;

  @override
  State<CustomMenuEditorSheet> createState() => _CustomMenuEditorSheetState();
}

class _CustomMenuEditorSheetState extends State<CustomMenuEditorSheet> {
  late final name = TextEditingController(text: widget.menu?.name ?? '');
  late Set<String> selectedIds = {...?widget.menu?.itemIds};
  String query = '';
  String? error;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  List<MenuMasterItem> get visibleItems {
    final normalized = query.trim().toLowerCase();
    return MenuMasterScreen.menuItems.where((item) {
      final mealList = item.meals.split(',').map((meal) => meal.trim()).toSet();
      final typeMatches = widget.type == 'Other'
          ? mealList.contains('Other') || mealList.isEmpty
          : mealList.contains(widget.type);
      final text = '${item.id} ${item.title} ${item.category} ${item.meals}'
          .toLowerCase();
      return typeMatches && (normalized.isEmpty || text.contains(normalized));
    }).toList()
      ..sort((a, b) {
        final aOrder = selectedOrder(a.id, selectedIds);
        final bOrder = selectedOrder(b.id, selectedIds);
        if (aOrder != -1 && bOrder != -1) return aOrder.compareTo(bOrder);
        final selectedCompare = (selectedIds.contains(b.id) ? 1 : 0)
            .compareTo(selectedIds.contains(a.id) ? 1 : 0);
        if (selectedCompare != 0) return selectedCompare;
        return a.english.compareTo(b.english);
      });
  }

  void save() {
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) {
      setState(() => error = 'Menu name is required.');
      return;
    }
    if (selectedIds.isEmpty) {
      setState(() => error = 'Select at least one menu item.');
      return;
    }
    Navigator.pop(
        context,
        CustomMenu(
            id: widget.menu?.id ?? '',
            name: trimmed,
            type: widget.type,
            itemIds: selectedIds));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .9),
        padding: EdgeInsets.fromLTRB(
            20, 10, 20, MediaQuery.of(context).viewInsets.bottom + 24),
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
              Text(
                  widget.menu == null
                      ? 'Add ${widget.type} Custom Menu'
                      : 'Edit ${widget.type} Custom Menu',
                  style: const TextStyle(
                      color: Cp.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const Text('Pick the items that should be selected together.',
                  style: TextStyle(color: Cp.onVariant)),
              const SizedBox(height: 14),
              EditableInlineField(label: 'Menu Name', controller: name),
              TextField(
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search ${widget.type} items',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                onChanged: (value) => setState(() => query = value),
              ),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(error!,
                        style: const TextStyle(
                            color: Cp.error, fontWeight: FontWeight.w800))),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: visibleItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = visibleItems[index];
                    final selected = selectedIds.contains(item.id);
                    return CpCard(
                      color: selected ? Cp.primaryFixed : Cp.card,
                      onTap: () => setState(() => selected
                          ? selectedIds.remove(item.id)
                          : selectedIds.add(item.id)),
                      child: Row(children: [
                        Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: selected ? Cp.primary : Cp.outline),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                '${item.title}\n${item.id} • ${item.category}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800))),
                      ]),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                      onPressed: save,
                      style: FilledButton.styleFrom(
                          backgroundColor: Cp.primaryContainer),
                      icon: const Icon(Icons.save),
                      label: const Text('Save Custom Menu',
                          style: TextStyle(fontWeight: FontWeight.w900)))),
            ]),
      ),
    );
  }
}
