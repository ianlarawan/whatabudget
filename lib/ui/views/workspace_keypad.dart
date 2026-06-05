import 'package:flutter/material.dart';

class WorkspaceKeypad extends StatelessWidget {
  final Function(String) onKeyPress;
  final VoidCallback onClear;
  final VoidCallback onCalculate;
  final bool isCurrencyMode;

  const WorkspaceKeypad({
    super.key,
    required this.onKeyPress,
    required this.onClear,
    required this.onCalculate,
    this.isCurrencyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Standard keypad layout structure configurations
    final List<String> buttons = [
      '7', '8', '9', 'C',
      '4', '5', '6', isCurrencyMode ? '' : '÷',
      '1', '2', '3', isCurrencyMode ? '' : '×',
      '.', '0', isCurrencyMode ? '' : '-', isCurrencyMode ? '=' : '+',
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: buttons.length,
      itemBuilder: (context, index) {
        final label = buttons[index];
        if (label.isEmpty) return const SizedBox.shrink();

        bool isAction = ['C', '=', '+', '-', '×', '÷'].contains(label);
        
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isAction ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainer,
            foregroundColor: isAction ? Theme.of(context).colorScheme.onPrimaryContainer : Theme.of(context).colorScheme.onSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          onPressed: () {
            if (label == 'C') {
              onClear();
            } else if (label == '=') {
              onCalculate();
            } else {
              onKeyPress(label);
            }
          },
          child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        );
      },
    );
  }
}