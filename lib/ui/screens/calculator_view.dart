import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class CalculatorView extends StatefulWidget {
  const CalculatorView({super.key});

  @override
  State<CalculatorView> createState() => _CalculatorViewState();
}

class _CalculatorViewState extends State<CalculatorView> {
  String _expression = '';
  String _result = '0';
  bool _hasEvaluated = false;

  void _onKeyPress(String value) {
    setState(() {
      bool isOperator = ['+', '-', '×', '÷'].contains(value);

      if (_hasEvaluated) {
        if (isOperator) {
          // Concat the operator directly onto the previous evaluation result
          _expression = _result + value;
        } else {
          // Clear the board and start a brand new calculation if a digit is pressed
          _expression = value;
        }
        _hasEvaluated = false;
      } else {
        _expression += value;
      }
    });
  }

  void _onBackspace() {
    if (_expression.isEmpty) return;
    setState(() {
      if (_hasEvaluated) {
        _clear();
      } else {
        _expression = _expression.substring(0, _expression.length - 1);
      }
    });
  }

  void _clear() {
    setState(() {
      _expression = '';
      _result = '0';
      _hasEvaluated = false;
    });
  }

  void _evaluate() {
    if (_expression.isEmpty || _hasEvaluated) return;
    try {
      String parseTarget = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      Parser p = Parser();
      Expression exp = p.parse(parseTarget);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      
      setState(() {
        _result = (eval % 1 == 0) ? eval.toInt().toString() : eval.toStringAsFixed(2);
        _hasEvaluated = true;
      });
    } catch (_) {
      setState(() {
        _result = 'Error';
        _hasEvaluated = false;
      });
    }
  }

  Widget _buildButton(String label, {bool isOperator = false, bool isAccent = false, VoidCallback? onTap}) {
    if (label.isEmpty) {
      return const Expanded(child: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    Color bg = isOperator ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surfaceContainer;
    Color fg = isOperator ? theme.colorScheme.primary : theme.colorScheme.onSurface;

    if (isAccent) {
      bg = theme.colorScheme.primary;
      fg = theme.colorScheme.onPrimary;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: SizedBox(
          height: 68,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onTap ?? () => _onKeyPress(label),
            child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(_expression, style: const TextStyle(fontSize: 26, color: Colors.grey)),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(_result, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 24),
          Row(children: [
            _buildButton('C', isOperator: true, onTap: _clear),
            _buildButton('÷', isOperator: true),
            _buildButton('×', isOperator: true),
            _buildButton('⌫', isOperator: true, onTap: _onBackspace),
          ]),
          Row(children: [
            _buildButton('7'), _buildButton('8'), _buildButton('9'),
            _buildButton('-', isOperator: true),
          ]),
          Row(children: [
            _buildButton('4'), _buildButton('5'), _buildButton('6'),
            _buildButton('+', isOperator: true),
          ]),
          SizedBox(
            height: 160, 
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Row(children: [_buildButton('1'), _buildButton('2'), _buildButton('3')]),
                      Row(children: [_buildButton(''), _buildButton('0'), _buildButton('.')]),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: SizedBox(
                      height: double.infinity, 
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _evaluate,
                        child: const Text('=', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}