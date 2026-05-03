class TransactionItem {
  final int? id;
  final double amount;
  final String type;
  final int categoryId;
  final int accountId;
  final int date;
  final String? note;
  final bool isInstallment;
  final int? installmentTotal;
  final int? installmentCurrent;

  TransactionItem({
    this.id, required this.amount, required this.type, required this.categoryId, 
    required this.accountId, required this.date, this.note,
    this.isInstallment = false, this.installmentTotal, this.installmentCurrent,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'amount': amount, 'type': type, 'category_id': categoryId,
    'account_id': accountId, 'date': date, 'note': note,
    'is_installment': isInstallment ? 1 : 0,
    'installment_total': installmentTotal,
    'installment_current': installmentCurrent,
  };

  factory TransactionItem.fromMap(Map<String, dynamic> map) => TransactionItem(
    id: map['id'], amount: map['amount'], type: map['type'],
    categoryId: map['category_id'], accountId: map['account_id'],
    date: map['date'], note: map['note'],
    isInstallment: (map['is_installment'] ?? 0) == 1,
    installmentTotal: map['installment_total'],
    installmentCurrent: map['installment_current'],
  );
}