import 'package:flutter/material.dart';
import '../data/tr_locations.dart';
import '../l10n/l10n.dart';
import '../main.dart' show CourtThemeProvider;

/// Province (il) + district (ilçe) picker. Each field opens a searchable
/// bottom-sheet list. Reports "<İlçe>, <İl>" via [onChanged], or null while
/// no district is chosen. An unparsable [initialValue] (legacy free text)
/// starts on [defaultProvince] with no district.
class LocationPicker extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onChanged;

  const LocationPicker({super.key, this.initialValue, required this.onChanged});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late String _il;
  String? _ilce;

  @override
  void initState() {
    super.initState();
    final parsed = parseTrLocation(widget.initialValue);
    _il = parsed?.il ?? defaultProvince;
    _ilce = parsed?.ilce;
  }

  Future<void> _pickIl() async {
    final picked = await _showSearchSheet(
        context, context.l10n.locationProvince, trLocations.keys.toList(), _il);
    if (!mounted) return;
    if (picked == null || picked == _il) return;
    setState(() {
      _il = picked;
      _ilce = null;
    });
    widget.onChanged(null);
  }

  Future<void> _pickIlce() async {
    final picked = await _showSearchSheet(context, context.l10n.locationDistrict,
        trLocations[_il] ?? const [], _ilce,
        emptyHint: context.l10n.locationNoResultsHint);
    if (!mounted) return;
    if (picked == null || picked == _ilce) return;
    setState(() => _ilce = picked);
    widget.onChanged(formatTrLocation(_il, picked));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        _PickerField(
          label: l.locationProvince,
          value: _il,
          icon: Icons.location_city_outlined,
          onTap: _pickIl,
        ),
        const SizedBox(height: 12),
        _PickerField(
          label: l.locationDistrict,
          value: _ilce,
          icon: Icons.location_on_outlined,
          onTap: _pickIlce,
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cp = CourtThemeProvider.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: label,
          hintText: context.l10n.locationSelect,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(icon, size: 18),
          suffixIcon: Icon(Icons.expand_more, color: cp.muted),
        ),
        child: Text(value ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

Future<String?> _showSearchSheet(BuildContext context, String title,
    List<String> options, String? current, {String? emptyHint}) {
  final cp = CourtThemeProvider.of(context);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: cp.bg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) =>
        _SearchSheet(
            title: title,
            options: options,
            current: current,
            emptyHint: emptyHint),
  );
}

class _SearchSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? current;
  final String? emptyHint;

  const _SearchSheet({
    required this.title,
    required this.options,
    required this.current,
    this.emptyHint,
  });

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cp = CourtThemeProvider.of(context);
    final q = foldTr(_query);
    final items = q.isEmpty
        ? widget.options
        : widget.options.where((o) => foldTr(o).contains(q)).toList();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Text(widget.title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: cp.text)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: context.l10n.locationSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(context.l10n.noResults,
                                  style: TextStyle(color: cp.muted)),
                              if (widget.emptyHint case final hint?) ...[
                                const SizedBox(height: 6),
                                Text(hint,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: cp.muted, fontSize: 13)),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final o = items[i];
                          return ListTile(
                            title: Text(o, style: TextStyle(color: cp.text)),
                            trailing: o == widget.current
                                ? Icon(Icons.check, color: cp.accent)
                                : null,
                            onTap: () => Navigator.pop(context, o),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
