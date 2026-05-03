import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../domain/models/category.dart';

class CategoryManagerScreen extends ConsumerStatefulWidget {
  const CategoryManagerScreen({super.key});
  @override
  ConsumerState<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends ConsumerState<CategoryManagerScreen> {
  void _showCategoryDialog([Category? existing]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final iconCtrl = TextEditingController(text: existing?.icon ?? '🏷️');
    String type = existing?.type ?? 'expense';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Category' : 'Edit Category'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                items: const [DropdownMenuItem(value: 'expense', child: Text('Expense')), DropdownMenuItem(value: 'income', child: Text('Income'))],
                onChanged: existing == null ? (val) => type = val! : null, 
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextFormField(controller: iconCtrl, decoration: const InputDecoration(labelText: 'Icon (Emoji)'), validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final cat = Category(id: existing?.id, name: nameCtrl.text, icon: iconCtrl.text, type: type);
                if (existing == null) {
                  ref.read(categoriesProvider.notifier).addCategory(cat);
                } else {
                  ref.read(categoriesProvider.notifier).updateCategory(cat);
                }
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (categories) {
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return ListTile(
                leading: Text(cat.icon, style: const TextStyle(fontSize: 24)),
                title: Text(cat.name),
                subtitle: Text(cat.type.toUpperCase()),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showCategoryDialog(cat)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => ref.read(categoriesProvider.notifier).deleteCategory(cat.id!)),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}