import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/app_controller.dart';
import '../utils/category_style.dart';

/// Bottom sheet used to create or edit a category.
class CategoryEditorSheet extends StatefulWidget {
  const CategoryEditorSheet({
    super.key,
    required this.controller,
    this.category,
  });

  final AppController controller;
  final Category? category;

  static Future<bool?> show(
    BuildContext context, {
    required AppController controller,
    Category? category,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          CategoryEditorSheet(controller: controller, category: category),
    );
  }

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  late final TextEditingController _nameController;
  late Color _color;
  late IconData _icon;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _color = widget.category == null
        ? categoryColorOptions.first
        : colorFromValue(widget.category!.colorValue);
    _icon = widget.category == null
        ? categoryIconOptions.first
        : iconFromCodePoint(widget.category!.iconCodePoint);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Category name cannot be empty.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_isEditing) {
        await widget.controller.updateCategory(
          category: widget.category!,
          name: name,
          colorValue: _color.toARGB32(),
          iconCodePoint: _icon.codePoint,
        );
      } else {
        await widget.controller.addCategory(
          name: name,
          colorValue: _color.toARGB32(),
          iconCodePoint: _icon.codePoint,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final bool duplicate = error.toString().toLowerCase().contains('unique');
      setState(() {
        _isSaving = false;
        _errorMessage = duplicate
            ? 'A category with this name already exists.'
            : 'Could not save the category. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit category' : 'New category',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: !_isEditing,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Finance',
                prefixIcon: Icon(_icon, color: _color),
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            Text('Color', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in categoryColorOptions)
                  _ColorChoice(
                    color: color,
                    selected: color.toARGB32() == _color.toARGB32(),
                    onTap: () => setState(() => _color = color),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Icon', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final icon in categoryIconOptions)
                  _IconChoice(
                    icon: icon,
                    color: _color,
                    selected: icon.codePoint == _icon.codePoint,
                    onTap: () => setState(() => _icon = icon),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Create Category'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2.5,
                )
              : null,
        ),
        child: selected
            ? Icon(
                Icons.check_rounded,
                color:
                    ThemeData.estimateBrightnessForColor(color) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
                size: 20,
              )
            : null,
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: selected ? Border.all(color: color, width: 1.6) : null,
        ),
        child: Icon(icon, color: selected ? color : null, size: 22),
      ),
    );
  }
}
