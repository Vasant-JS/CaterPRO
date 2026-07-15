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

int selectedOrder(String id, Iterable<String> selectedIds) {
  var index = 0;
  for (final selectedId in selectedIds) {
    if (selectedId == id) return index;
    index++;
  }
  return -1;
}

String nextMenuMasterItemId() {
  var maxNumber = 0;
  final pattern = RegExp(r'^MNU-(\d+)$', caseSensitive: false);
  for (final item in MenuMasterScreen.menuItems) {
    final match = pattern.firstMatch(item.id.trim());
    final value = int.tryParse(match?.group(1) ?? '') ?? 0;
    if (value > maxNumber) maxNumber = value;
  }
  return 'MNU-${(maxNumber + 1).toString().padLeft(3, '0')}';
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
  final searchController = TextEditingController();
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

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void upsertMenuItem(MenuMasterItem item) {
    final creating = !MenuMasterScreen.menuItems
        .any((existing) => existing.id == item.id);
    setState(() {
      final index = MenuMasterScreen.menuItems
          .indexWhere((existing) => existing.id == item.id);
      if (index == -1) {
        MenuMasterScreen.menuItems.add(item);
      } else {
        MenuMasterScreen.menuItems[index] = item;
      }
    });
    unawaited(api.saveMenuItem(item, creating: creating).then((saved) {
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

  Future<void> exportMenuCatalogPdf(String language) async {
    final uri = await api.menuCatalogPdfUri(language,
        search: query, meal: selectedMealFilter, vegOnly: vegOnly);
    if (!mounted) return;
    showDownloadSnack(context, uri,
        title: 'Menu catalog $language.pdf',
        kind: 'menu',
        successMessage: 'Menu catalog PDF started',
        failureMessage: 'Unable to open menu PDF');
  }

  PopupMenuItem<String> filterItem(String value, String label,
      {IconData? icon, bool selected = false}) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(selected ? Icons.check_circle : icon ?? Icons.restaurant_menu,
            color: selected ? Cp.tertiaryContainer : Cp.primary),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w800))),
      ]),
    );
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
                PopupMenuButton<String>(
                  tooltip: 'Filter menu items',
                  icon: const Icon(Icons.filter_list, color: Cp.primary),
                  onSelected: (value) {
                    setState(() {
                      if (value == 'veg') {
                        vegOnly = !vegOnly;
                      } else if (value == 'clear') {
                        selectedMealFilter = 'All';
                        vegOnly = false;
                      } else {
                        selectedMealFilter = value;
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    ...eventMenuTypes.map((type) => filterItem(type, type,
                        selected: selectedMealFilter == type)),
                    const PopupMenuDivider(),
                    filterItem('All', 'All Menu Types',
                        icon: Icons.all_inclusive,
                        selected: selectedMealFilter == 'All' && !vegOnly),
                    filterItem('veg', 'Veg Only',
                        icon: Icons.eco, selected: vegOnly),
                    const PopupMenuDivider(),
                    filterItem('clear', 'Clear Filters',
                        icon: Icons.filter_alt_off),
                  ],
                ),
                PopupMenuButton<String>(
                  tooltip: 'Menu export options',
                  icon: const Icon(Icons.more_vert, color: Cp.primary),
                  onSelected: exportMenuCatalogPdf,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                        value: 'kannada',
                        child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.picture_as_pdf),
                            title: Text('Export Kannada menu'))),
                    PopupMenuItem(
                        value: 'english',
                        child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.picture_as_pdf),
                            title: Text('Export English menu'))),
                    PopupMenuItem(
                        value: 'both',
                        child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.picture_as_pdf),
                            title: Text('Export both language menu'))),
                  ],
                ),
              ]),
          children: [
            CpCard(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Row(children: [
                  Icon(Icons.public,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          'Universal menu catalog. Add/edit only. Every user can access these items.',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontSize: 13,
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
                  hintText: 'Search menu items',
                  filled: true,
                  fillColor: cpCard(context),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 18),
            if (query.trim().isNotEmpty &&
                !visibleItems.any((item) =>
                    item.english.toLowerCase() == query.trim().toLowerCase() ||
                    item.kannada == query.trim()))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DashedAction(
                    label: 'Add "${query.trim()}"',
                    icon: Icons.add_circle,
                    onTap: () => showMenuItemEditor(context,
                        initialEnglish: query.trim(),
                        initialMeals: {
                          if (selectedMealFilter != 'All') selectedMealFilter
                        },
                        onSave: upsertMenuItem)),
              ),
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

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({super.key, required this.item, required this.onEdit});
  final MenuMasterItem item;
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
                    color: item.veg
                        ? Cp.tertiaryFixed.withValues(alpha: .3)
                        : Cp.errorContainer,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.restaurant,
                    size: 21, color: item.veg ? Cp.tertiary : Cp.error)),
            const SizedBox(width: 10),
            Expanded(
              child: MarqueeText(
                '${item.kannada}/${item.english}',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit, color: Cp.primary)),
          ]),
        ),
      );
}

class MenuItemCardLegacy extends StatelessWidget {
  const MenuItemCardLegacy(
      {super.key, required this.item, required this.onEdit});
  final MenuMasterItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: CpCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          onTap: onEdit,
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: item.veg
                        ? Cp.tertiaryFixed.withValues(alpha: .3)
                        : Cp.errorContainer,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.restaurant,
                    size: 24, color: item.veg ? Cp.tertiary : Cp.error)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: item.veg ? Colors.green : Colors.red,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('${item.kannada} / ${item.english}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)))
                    ]),
                    const SizedBox(height: 2),
                    Text('${item.id} • ${item.category} • ${item.meals}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Cp.onVariant, fontSize: 12)),
                  ]),
            ),
            IconButton(
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit, color: Cp.primary)),
          ]),
        ),
      );
}

void showMenuItemEditor(BuildContext context,
    {MenuMasterItem? item,
    String? initialEnglish,
    Set<String>? initialMeals,
    required ValueChanged<MenuMasterItem> onSave}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MenuItemEditorSheet(
        item: item,
        initialEnglish: initialEnglish,
        initialMeals: initialMeals,
        onSave: onSave),
  );
}

class MenuItemEditorSheet extends StatefulWidget {
  const MenuItemEditorSheet(
      {super.key,
      this.item,
      this.initialEnglish,
      this.initialMeals,
      required this.onSave});
  final MenuMasterItem? item;
  final String? initialEnglish;
  final Set<String>? initialMeals;
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
    'Juice',
    'Lunch',
    'Snack',
    'Dinner',
    'Others'
  ];
  late final id = TextEditingController(
      text: widget.item?.id ?? nextMenuMasterItemId());
  late final english = TextEditingController(
      text: widget.item?.english ?? widget.initialEnglish ?? '');
  late final kannada = TextEditingController(text: widget.item?.kannada ?? '');
  late String category = categoryOptions.contains(widget.item?.category)
      ? widget.item!.category
      : categoryOptions.first;
  late Set<String> selectedMeals = {
    if (widget.item != null)
      ...widget.item!.meals
          .split(',')
          .map((meal) => meal.trim())
          .map((meal) => meal == 'Other' ? 'Others' : meal)
          .where((meal) => mealOptions.contains(meal)),
    if (widget.item == null && widget.initialMeals != null)
      ...widget.initialMeals!
          .map((meal) => meal == 'Other' ? 'Others' : meal)
          .where((meal) => mealOptions.contains(meal)),
  };
  late bool veg = widget.item?.veg ?? true;
  String? error;

  bool get vegOnlyDefault => appPreferences.value.vegOnlyDefault;

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
        veg: vegOnlyDefault ? true : veg));
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
          decoration: BoxDecoration(
              color: cpCard(context),
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
                  Text(widget.item == null ? 'Add Menu Item' : 'Edit Menu Item',
                      style: TextStyle(
                          color: cpPrimary(context),
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  Text('Universal item, available to every user.',
                      style: TextStyle(color: cpOnVariant(context))),
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
                                    style:
                                        TextStyle(color: cpOnSurface(context)),
                                    overflow: TextOverflow.ellipsis)),
                            Icon(Icons.arrow_drop_down,
                                color: cpPrimary(context)),
                          ]),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (!vegOnlyDefault)
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: veg,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChanged: (value) => setState(() => veg = value),
                        title: const Text('Vegetarian',
                            style: TextStyle(fontWeight: FontWeight.w900))),
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w800))),
                  SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                          onPressed: save,
                          style: FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primaryContainer,
                              foregroundColor: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer),
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
        decoration: BoxDecoration(
            color: cpCard(context),
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
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: cpOutlineVariant(context),
                          borderRadius: BorderRadius.circular(99)))),
              Text('Select Meals',
                  style: TextStyle(
                      color: cpPrimary(context),
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
                            activeColor: Theme.of(context).colorScheme.primary,
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
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer),
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
            icon: Icon(Icons.arrow_back, color: cpPrimary(context))),
        actions: [
          IconButton(
              onPressed: saving ? null : () => openEditor(),
              icon: const Icon(Icons.add, color: Cp.toolbarIcon))
        ],
      ),
      children: [
        CpCard(
            color: Cp.primaryFixed,
            child: Row(children: [
              Icon(Icons.fact_check, color: cpPrimary(context)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      'Ready made menu sets are saved under your user and can be applied during event menu selection.',
                      style: TextStyle(
                          color: cpPrimary(context),
                          fontWeight: FontWeight.w800)))
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
                  Icon(Icons.playlist_add_check, color: cpPrimary(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(menu.name,
                              style: TextStyle(
                                  color: cpPrimary(context),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900)),
                          Text(
                              '${menu.itemIds.length} items${names.isEmpty ? '' : ' • $names'}',
                              style: TextStyle(
                                  color: cpOnVariant(context),
                                  fontWeight: FontWeight.w700)),
                        ]),
                  ),
                  Icon(Icons.edit, color: cpPrimary(context)),
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
      if (appPreferences.value.vegOnlyDefault && !item.veg) return false;
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
        decoration: BoxDecoration(
            color: cpSurface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
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
                          color: cpOutlineVariant(context),
                          borderRadius: BorderRadius.circular(99)))),
              Text(
                  widget.menu == null
                      ? 'Add ${widget.type} Custom Menu'
                      : 'Edit ${widget.type} Custom Menu',
                  style: TextStyle(
                      color: cpPrimary(context),
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              Text('Pick the items that should be selected together.',
                  style: TextStyle(color: cpOnVariant(context))),
              const SizedBox(height: 14),
              EditableInlineField(label: 'Menu Name', controller: name),
              TextField(
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search, color: cpOnVariant(context)),
                    hintText: 'Search ${widget.type} items',
                    filled: true,
                    fillColor: cpSurfaceLow(context),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12))),
                onChanged: (value) => setState(() => query = value),
              ),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w800))),
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
                            color: selected
                                ? cpPrimary(context)
                                : cpOutline(context),
                            size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                            child: MarqueeText(
                                '${item.title}\n${item.id} • ${item.category}',
                                style: const TextStyle(
                                    fontSize: 14,
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
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                      icon: const Icon(Icons.save),
                      label: const Text('Save Custom Menu',
                          style: TextStyle(fontWeight: FontWeight.w900)))),
            ]),
      ),
    );
  }
}
