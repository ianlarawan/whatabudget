import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart';

class CurrencyMatrixView extends StatefulWidget {
  const CurrencyMatrixView({super.key});

  @override
  State<CurrencyMatrixView> createState() => _CurrencyMatrixViewState();
}

class _CurrencyMatrixViewState extends State<CurrencyMatrixView> {
  int _activeRowIndex = 0;
  bool _isLoading = false;
  bool _hasEvaluatedActiveRow = false;
  String _lastRefreshedDateStr = 'Loading...';

  final List<String> _selectedCurrencies = ['USD', 'PHP', 'JPY'];
  final List<String> _rowValues = ['1.00', '58.50', '156.20'];

  final Map<String, Map<String, String>> _currencyMetadata = {
    'USD': {'name': 'United States', 'symbol': '\$'},
    'PHP': {'name': 'Philippines', 'symbol': '₱'},
    'JPY': {'name': 'Japan', 'symbol': '¥'},
    'EUR': {'name': 'Eurozone', 'symbol': '€'},
    'GBP': {'name': 'United Kingdom', 'symbol': '£'},
    'SGD': {'name': 'Singapore', 'symbol': 'S\$'},
    'AUD': {'name': 'Australia', 'symbol': 'A\$'},
    'CAD': {'name': 'Canada', 'symbol': 'C\$'},
    'CHF': {'name': 'Switzerland', 'symbol': 'CHF'},
    'CNY': {'name': 'China', 'symbol': '¥'},
    'HKD': {'name': 'Hong Kong', 'symbol': 'HK\$'},
    'NZD': {'name': 'New Zealand', 'symbol': 'NZ\$'},
    'KRW': {'name': 'South Korea', 'symbol': '₩'},
    'INR': {'name': 'India', 'symbol': '₹'},
    'BRL': {'name': 'Brazil', 'symbol': 'R\$'},
    'MXN': {'name': 'Mexico', 'symbol': 'Mex\$'},
    'IDR': {'name': 'Indonesia', 'symbol': 'Rp'},
    'MYR': {'name': 'Malaysia', 'symbol': 'RM'},
    'THB': {'name': 'Thailand', 'symbol': '฿'},
    'VND': {'name': 'Vietnam', 'symbol': '₫'},
    'ZAR': {'name': 'South Africa', 'symbol': 'R'},
    'RUB': {'name': 'Russia', 'symbol': '₽'},
    'TRY': {'name': 'Turkey', 'symbol': '₺'},
    'PLN': {'name': 'Poland', 'symbol': 'zł'},
    'SEK': {'name': 'Sweden', 'symbol': 'kr'},
    'NOK': {'name': 'Norway', 'symbol': 'kr'},
    'DKK': {'name': 'Denmark', 'symbol': 'kr'},
    'ILS': {'name': 'Israel', 'symbol': '₪'},
    'HUF': {'name': 'Hungary', 'symbol': 'Ft'},
    'CZK': {'name': 'Czech Republic', 'symbol': 'Kč'},
    'BGN': {'name': 'Bulgaria', 'symbol': 'лв'},
    'RON': {'name': 'Romania', 'symbol': 'lei'},
    'ISK': {'name': 'Iceland', 'symbol': 'kr'},
  };

  final Map<String, double> _usdExchangeRates = {
    'USD': 1.0, 'PHP': 58.50, 'JPY': 156.20, 'EUR': 0.92, 'GBP': 0.78, 'SGD': 1.35, 'AUD': 1.50,
    'CAD': 1.37, 'CHF': 0.89, 'CNY': 7.25, 'HKD': 7.81, 'NZD': 1.63, 'KRW': 1375.0, 'INR': 83.50,
    'BRL': 5.25, 'MXN': 17.50, 'IDR': 16250.0, 'MYR': 4.71, 'THB': 36.60, 'VND': 25400.0,
    'ZAR': 18.90, 'RUB': 89.0, 'TRY': 32.20, 'PLN': 4.01, 'SEK': 10.50, 'NOK': 10.60, 'DKK': 6.88,
    'ILS': 3.72, 'HUF': 365.0, 'CZK': 22.90, 'BGN': 1.80, 'RON': 4.58, 'ISK': 139.0,
  };

  final List<String> _availableCurrencies = [
    'USD', 'PHP', 'JPY', 'EUR', 'GBP', 'SGD', 'AUD', 'CAD', 'CHF', 'CNY', 'HKD', 'NZD', 'KRW', 
    'INR', 'BRL', 'MXN', 'IDR', 'MYR', 'THB', 'VND', 'ZAR', 'RUB', 'TRY', 'PLN', 'SEK', 'NOK', 
    'DKK', 'ILS', 'HUF', 'CZK', 'BGN', 'RON', 'ISK'
  ];

  @override
  void initState() {
    super.initState();
    _fetchLiveRates();
  }

  Future<void> _fetchLiveRates() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('https://api.frankfurter.dev/v1/latest?base=USD');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final rates = data['rates'] as Map<String, dynamic>;
        
        final String rawDateFromServer = data['date'] ?? '';
        String parsedFormattedDate = rawDateFromServer;
        try {
          if (rawDateFromServer.isNotEmpty) {
            final DateTime parsedDate = DateTime.parse(rawDateFromServer);
            parsedFormattedDate = DateFormat('d MMM yyyy').format(parsedDate).toUpperCase();
          }
        } catch (_) {
          parsedFormattedDate = DateFormat('d MMM yyyy').format(DateTime.now()).toUpperCase();
        }

        setState(() {
          _lastRefreshedDateStr = parsedFormattedDate;
          _usdExchangeRates['USD'] = 1.0;
          for (var key in rates.keys) {
            if (_availableCurrencies.contains(key)) {
              _usdExchangeRates[key] = rates[key].toDouble();
            }
          }
          _recalculateValuesFromActiveRow();
        });
      }
    } catch (_) {
      if (_lastRefreshedDateStr == 'Loading...') {
        setState(() {
          _lastRefreshedDateStr = DateFormat('d MMM yyyy').format(DateTime.now()).toUpperCase();
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleInput(String token) {
    setState(() {
      String current = _rowValues[_activeRowIndex];
      bool isOperator = ['+', '-', '×', '÷'].contains(token);

      if (_hasEvaluatedActiveRow) {
        if (isOperator) {
          _rowValues[_activeRowIndex] = current + token;
        } else {
          _rowValues[_activeRowIndex] = token;
        }
        _hasEvaluatedActiveRow = false;
      } else {
        if (current == '0' || current == '0.00') {
          _rowValues[_activeRowIndex] = token;
        } else {
          _rowValues[_activeRowIndex] = current + token;
        }
      }
      
      if (!_containsOperators(_rowValues[_activeRowIndex])) {
        _recalculateValuesFromActiveRow();
      }
    });
  }

  bool _containsOperators(String value) {
    return value.contains('+') || value.contains('-') || value.contains('×') || value.contains('÷');
  }

  void _handleBackspace() {
    setState(() {
      String current = _rowValues[_activeRowIndex];
      if (_hasEvaluatedActiveRow) {
        _clearAll();
        return;
      }
      if (current.isNotEmpty) {
        _rowValues[_activeRowIndex] = current.substring(0, current.length - 1);
        if (_rowValues[_activeRowIndex].isEmpty) _rowValues[_activeRowIndex] = '0';
      }
      
      if (!_containsOperators(_rowValues[_activeRowIndex])) {
        _recalculateValuesFromActiveRow();
      }
    });
  }

  void _clearAll() {
    setState(() {
      _rowValues[0] = '0';
      _rowValues[1] = '0';
      _rowValues[2] = '0';
      _hasEvaluatedActiveRow = false;
    });
  }

  void _evaluateExpression() {
    String currentExpression = _rowValues[_activeRowIndex];
    if (!_containsOperators(currentExpression) || _hasEvaluatedActiveRow) return;

    try {
      String parseTarget = currentExpression.replaceAll('×', '*').replaceAll('÷', '/');
      Parser p = Parser();
      Expression exp = p.parse(parseTarget);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      
      setState(() {
        _rowValues[_activeRowIndex] = (eval % 1 == 0) ? eval.toInt().toString() : eval.toStringAsFixed(2);
        _hasEvaluatedActiveRow = true;
        _recalculateValuesFromActiveRow();
      });
    } catch (_) {
      setState(() {
        _rowValues[_activeRowIndex] = 'Error';
        _hasEvaluatedActiveRow = false;
      });
    }
  }

  void _recalculateValuesFromActiveRow() {
    double activeValue = double.tryParse(_rowValues[_activeRowIndex]) ?? 0.0;
    String activeCurrency = _selectedCurrencies[_activeRowIndex];
    double valueInUSD = activeValue / (_usdExchangeRates[activeCurrency] ?? 1.0);

    for (int i = 0; i < 3; i++) {
      if (i == _activeRowIndex) continue;
      String targetCurrency = _selectedCurrencies[i];
      double targetRate = _usdExchangeRates[targetCurrency] ?? 1.0;
      double computedValue = valueInUSD * targetRate;
      _rowValues[i] = computedValue == 0 ? '0' : computedValue.toStringAsFixed(2);
    }
  }

  void _showCurrencySelector(int rowIndex) {
  final List<String> sortedCurrencies = List.from(_availableCurrencies);
  
  sortedCurrencies.sort((a, b) {
    bool aSelected = _selectedCurrencies.contains(a);
    bool bSelected = _selectedCurrencies.contains(b);
    
    // Step 1: Prioritize selected items to stay at the absolute top
    if (aSelected && !bSelected) return -1;
    if (!aSelected && bSelected) return 1;
    
    // Step 2: Retrieve full country names for proper alphabetical sequencing
    String nameA = _currencyMetadata[a]?['name'] ?? a;
    String nameB = _currencyMetadata[b]?['name'] ?? b;
    
    // Step 3: Compare by country name strings instead of currency ticker keys
    return nameA.compareTo(nameB);
  });

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Select Currency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: sortedCurrencies.length,
                itemBuilder: (ctx, idx) {
                  final currency = sortedCurrencies[idx];
                  bool isSelected = _selectedCurrencies.contains(currency);
                  final meta = _currencyMetadata[currency] ?? {'name': currency, 'symbol': ''};

                  return ListTile(
                    title: Text(
                      meta['name']!, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      '${meta['symbol']} $currency',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                    enabled: !isSelected,
                    onTap: () {
                      setState(() {
                        _selectedCurrencies[rowIndex] = currency;
                        _recalculateValuesFromActiveRow();
                      });
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildButton(String label, {bool isOperator = false, bool isAccent = false, VoidCallback? onTap}) {
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
            onPressed: onTap ?? () => _handleInput(label),
            child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          for (int i = 0; i < 3; i++) ...[
            GestureDetector(
              onTap: () => setState(() {
                _activeRowIndex = i;
                _hasEvaluatedActiveRow = false;
              }),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _activeRowIndex == i ? colorScheme.primaryContainer.withValues(alpha: 0.3) : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _activeRowIndex == i ? colorScheme.primary : Colors.transparent, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => _showCurrencySelector(i),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currencyMetadata[_selectedCurrencies[i]]?['name'] ?? _selectedCurrencies[i],
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedCurrencies[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down, size: 24),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: RichText(
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: _activeRowIndex == i ? colorScheme.primary : colorScheme.onSurface,
                          ),
                          children: [
                            TextSpan(
                              text: () {
                                final String fullSymbol = _currencyMetadata[_selectedCurrencies[i]]?['symbol'] ?? '';
                                if (fullSymbol.isEmpty) return '';
                                return fullSymbol.substring(fullSymbol.length - 1);
                              }(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.normal,
                                color: (_activeRowIndex == i ? colorScheme.primary : colorScheme.onSurface)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            TextSpan(
                              text: _rowValues[i],
                              style: TextStyle(
                                fontSize: _rowValues[i].length > 12 ? 20 : 26, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const Spacer(),
          
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, left: 6.0, right: 6.0),
            child: InkWell(
              onTap: _isLoading ? null : _fetchLiveRates,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoading) ...[
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      'Rates provided by Frankfurter • $_lastRefreshedDateStr',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    if (!_isLoading) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.refresh, size: 12, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                    ],
                  ],
                ),
              ),
            ),
          ),

          Row(children: [
            _buildButton('C', isOperator: true, onTap: _clearAll),
            _buildButton('÷', isOperator: true),
            _buildButton('×', isOperator: true),
            _buildButton('⌫', isOperator: true, onTap: _handleBackspace),
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
                      Row(children: [_buildButton('00'), _buildButton('0'), _buildButton('.')]),
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
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _evaluateExpression,
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