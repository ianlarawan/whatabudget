import 'interest_tier.dart';

class Account {
  final int? id;
  final String type;
  final String provider;
  final String name;
  final double balance;
  final double? goalBalance;
  final double? interestRate; // Legacy/Fallback
  final String? cardNetwork;
  final double? creditLimit;
  final double? cashAdvanceLimit;
  final int? billingDate;
  final int? dueDateOffset;
  final String icon;
  final bool includeInNetWorth;
  
  // New Interest Engine Fields
  final String interestFrequency; // 'daily', 'monthly', 'annually', 'none'
  final List<InterestTier> interestTiers;
  final double accumulatedInterest;
  final int? lastInterestDate;

  Account({
    this.id, required this.type, required this.provider, required this.name, required this.balance,
    this.goalBalance, this.interestRate, this.cardNetwork, this.creditLimit, 
    this.cashAdvanceLimit, this.billingDate, this.dueDateOffset,
    this.icon = '🏦', this.includeInNetWorth = true,
    this.interestFrequency = 'none', this.interestTiers = const [],
    this.accumulatedInterest = 0.0, this.lastInterestDate,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'type': type, 'provider': provider, 'name': name, 'balance': balance,
    'goal_balance': goalBalance, 'interest_rate': interestRate, 'card_network': cardNetwork,
    'credit_limit': creditLimit, 'cash_advance_limit': cashAdvanceLimit,
    'billing_date': billingDate, 'due_date_offset': dueDateOffset,
    'icon': icon, 'include_in_net_worth': includeInNetWorth ? 1 : 0,
    'interest_frequency': interestFrequency,
    'interest_tiers': InterestTier.toJsonList(interestTiers),
    'accumulated_interest': accumulatedInterest,
    'last_interest_date': lastInterestDate,
  };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
    id: map['id'], type: map['type'], provider: map['provider'], name: map['name'], balance: map['balance'],
    goalBalance: map['goal_balance'], interestRate: map['interest_rate'], cardNetwork: map['card_network'],
    creditLimit: map['credit_limit'], cashAdvanceLimit: map['cash_advance_limit'],
    billingDate: map['billing_date'], dueDateOffset: map['due_date_offset'],
    icon: map['icon'] ?? '🏦', includeInNetWorth: (map['include_in_net_worth'] ?? 1) == 1,
    interestFrequency: map['interest_frequency'] ?? 'none',
    interestTiers: map['interest_tiers'] != null ? InterestTier.fromJsonList(map['interest_tiers']) : [],
    accumulatedInterest: map['accumulated_interest'] ?? 0.0,
    lastInterestDate: map['last_interest_date'],
  );
}