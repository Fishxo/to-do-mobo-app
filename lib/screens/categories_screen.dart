import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/task.dart';
import '../state/app_controller.dart';
import '../utils/category_style.dart';
import '../widgets/category_editor_sheet.dart';
import '../widgets/empty_task_view.dart';
import 'category_tasks_screen.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _deleteCategory(BuildContext context, Category category) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
          '"${category.name}" will be removed. Its tasks will not be deleted — '
          'they will become uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await controller.deleteCategory(category.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category deleted. Its tasks were kept.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete the category. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final List<Category> categories = controller.categories;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Categories'),
            actions: [
              IconButton(
                tooltip: 'New category',
                onPressed: () =>
                    CategoryEditorSheet.show(context, controller: controller),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Text(
                      'Group your tasks and keep an eye on progress in each '
                      'area of life.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (categories.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyTaskView(
                      title: 'No categories yet',
                      message: 'Create a category to organize your tasks.',
                      icon: Icons.category_outlined,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 240,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.18,
                          ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final Category category = categories[index];
                        final List<Task> tasks = controller.tasksForCategory(
                          category.id,
                        );
                        final int total = tasks.length;
                        final int completed = tasks
                            .where((task) => task.isCompleted)
                            .length;
                        return _CategoryCard(
                          category: category,
                          total: total,
                          completed: completed,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryTasksScreen(
                                controller: controller,
                                categoryId: category.id,
                              ),
                            ),
                          ),
                          onEdit: () => CategoryEditorSheet.show(
                            context,
                            controller: controller,
                            category: category,
                          ),
                          onDelete: () => _deleteCategory(context, category),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                CategoryEditorSheet.show(context, controller: controller),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('New Category'),
          ),
        );
      },
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.total,
    required this.completed,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final int total;
  final int completed;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = colorFromValue(category.colorValue);
    final double progress = total == 0 ? 0 : completed / total;

    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      iconFromCodePoint(category.iconCodePoint),
                      color: color,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: color,
                    ),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                total == 0 ? 'No tasks' : '$completed of $total completed',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
