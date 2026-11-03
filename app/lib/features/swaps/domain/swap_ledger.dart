import 'shift_swap.dart';

/// What one colleague owes in the ledger.
///
/// The balance nets what was given and what came back: a colleague who owes
/// me two shifts and whom I owe one owes me **one** shift.
class SwapBalance {
  const SwapBalance({
    required this.colleague,
    required this.net,
    required this.pendingCount,
    required this.settledCount,
  });

  /// The colleague, as it was written (the newest change that mentions them).
  final String colleague;

  /// The shifts they still owe me: positive when they owe me, negative when
  /// I owe them. Settled changes do not count.
  final int net;

  /// The changes that are not settled.
  final int pendingCount;

  /// The changes that are settled (closed).
  final int settledCount;

  /// The shifts they still owe me (0 when the balance is the other way
  /// round).
  int get theyOweMe => net > 0 ? net : 0;

  /// The shifts I still owe them (0 when the balance is the other way
  /// round).
  int get iOweThem => net < 0 ? -net : 0;

  /// Nobody owes anything: the balance is zero.
  bool get isSettled => net == 0;

  /// Whether this colleague has something pending.
  bool get hasPending => pendingCount > 0;

  @override
  bool operator ==(Object other) =>
      other is SwapBalance &&
      other.colleague == colleague &&
      other.net == net &&
      other.pendingCount == pendingCount &&
      other.settledCount == settledCount;

  @override
  int get hashCode => Object.hash(colleague, net, pendingCount, settledCount);

  @override
  String toString() =>
      'SwapBalance($colleague, net: $net, pending: $pendingCount)';
}

/// The swap ledger of a calendar: the changes and the balance of each
/// colleague.
///
/// The balances are ordered by pending: the colleagues with something open
/// come first, and inside them the ones who owe more shifts; a tie is broken
/// by the name.
class SwapLedger {
  const SwapLedger({required this.swaps, required this.balances});

  /// Every change of the calendar, newest day first (as the repository
  /// returns them).
  final List<ShiftSwap> swaps;

  /// The balance of each colleague, ordered by pending.
  final List<SwapBalance> balances;

  /// The changes that are not settled: the ones that still count in the
  /// balance.
  List<ShiftSwap> get pending => [
    for (final swap in swaps)
      if (!swap.isReturned) swap,
  ];

  /// The changes that are settled (closed).
  List<ShiftSwap> get settled => [
    for (final swap in swaps)
      if (swap.isReturned) swap,
  ];

  /// The balance of [colleague] (the name is compared ignoring spaces and
  /// case), or `null` when there is no change with them.
  SwapBalance? balanceOf(String colleague) {
    final key = _key(colleague);
    for (final balance in balances) {
      if (_key(balance.colleague) == key) return balance;
    }
    return null;
  }

  /// The changes with [colleague] (the name is compared ignoring spaces and
  /// case), newest day first.
  List<ShiftSwap> swapsOf(String colleague) {
    final key = _key(colleague);
    return [
      for (final swap in swaps)
        if (_key(swap.colleague) == key) swap,
    ];
  }

  /// The ledger of [swaps]: the balance of every colleague, with the changes
  /// as they came.
  ///
  /// The colleague is free text, so the same person written in two ways
  /// («Marta» and «marta ») is one balance: the name is compared ignoring
  /// spaces and case, and the newest spelling is the one shown.
  factory SwapLedger.from(Iterable<ShiftSwap> swaps) {
    final list = List<ShiftSwap>.unmodifiable(swaps);
    final names = <String, String>{};
    final nets = <String, int>{};
    final pending = <String, int>{};
    final settled = <String, int>{};
    for (final swap in list) {
      final key = _key(swap.colleague);
      names.putIfAbsent(key, () => swap.colleague.trim());
      if (swap.isReturned) {
        settled[key] = (settled[key] ?? 0) + 1;
        continue;
      }
      pending[key] = (pending[key] ?? 0) + 1;
      nets[key] = (nets[key] ?? 0) + swap.netShifts;
    }
    final balances = <SwapBalance>[
      for (final MapEntry(key: key, value: name) in names.entries)
        SwapBalance(
          colleague: name,
          net: nets[key] ?? 0,
          pendingCount: pending[key] ?? 0,
          settledCount: settled[key] ?? 0,
        ),
    ]..sort(_byPending);
    return SwapLedger(swaps: list, balances: List.unmodifiable(balances));
  }

  /// The colleague with something open comes first; inside them, the one who
  /// owes more shifts; a tie is broken by the name.
  static int _byPending(SwapBalance a, SwapBalance b) {
    if (a.hasPending != b.hasPending) return a.hasPending ? -1 : 1;
    final pendingA = a.theyOweMe + a.iOweThem;
    final pendingB = b.theyOweMe + b.iOweThem;
    if (pendingA != pendingB) return pendingB.compareTo(pendingA);
    final byName = a.colleague.toLowerCase().compareTo(
      b.colleague.toLowerCase(),
    );
    if (byName != 0) return byName;
    return a.colleague.compareTo(b.colleague);
  }

  /// The key of a colleague: the name without spaces nor case.
  static String _key(String colleague) =>
      colleague.trim().toLowerCase().replaceAll(' ', '');
}

/// The ledger of [swaps].
SwapLedger buildSwapLedger(Iterable<ShiftSwap> swaps) =>
    SwapLedger.from(swaps);
