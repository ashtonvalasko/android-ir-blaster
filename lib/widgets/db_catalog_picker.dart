import 'package:flutter/material.dart';
import 'package:irblaster_controller/ir_finder/irblaster_db.dart';
import 'package:irblaster_controller/l10n/l10n.dart';
import 'package:irblaster_controller/utils/db_catalog_search.dart';

Future<String?> showDbCatalogPicker(BuildContext context, {String? brand}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: DbCatalogPicker(
          brand: brand,
          loadNames: () => brand == null
              ? IrBlasterDb.instance.listBrands(limit: 1 << 30)
              : IrBlasterDb.instance
                  .listModelsDistinct(brand: brand, limit: 1 << 30),
        ),
      ),
    ),
  );
}

/// Owns query and scroll state across keyboard and bottom-sheet rebuilds.
class DbCatalogPicker extends StatefulWidget {
  const DbCatalogPicker({super.key, this.brand, required this.loadNames});

  final String? brand;
  final Future<List<String>> Function() loadNames;

  @override
  State<DbCatalogPicker> createState() => _DbCatalogPickerState();
}

class _DbCatalogPickerState extends State<DbCatalogPicker> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  DbCatalogSearch? _catalog;
  List<String> _results = [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final names = await widget.loadNames();
      if (!mounted) return;
      setState(() {
        _catalog = DbCatalogSearch(names);
        _results = _catalog!.search(_query.text);
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _search() {
    setState(() => _results = _catalog?.search(_query.text) ?? []);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isBrand = widget.brand == null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: Text(isBrand ? l10n.selectBrand : widget.brand!,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: l10n.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: isBrand ? l10n.searchBrand : l10n.searchModel,
                prefixIcon: const Icon(Icons.search_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.clearAction,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _query.clear();
                          _search();
                        },
                      ),
              ),
              onChanged: (_) => _search(),
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (_query.text.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          isBrand
                              ? l10n.dbBrandSearchHelp
                              : l10n.dbModelSearchHelp,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  if (_failed || _catalog == null || _results.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _failed
                          ? Center(
                              child: FilledButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(l10n.retry)))
                          : _catalog == null
                              ? const Center(child: CircularProgressIndicator())
                              : Center(child: Text(l10n.globalSearchNoResults)),
                    )
                  else
                    SliverList.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(_results[index]),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, _results[index]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
