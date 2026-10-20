// Sieve of Eratosthenes over a Uint8List of flags.
import 'dart:typed_data';

void nsieve(int n) {
  final flags = Uint8List(n)..fillRange(0, n, 1);
  var count = 0;
  for (var i = 2; i < n; i++) {
    if (flags[i] == 1) {
      count++;
      for (var j = i << 1; j < n; j += i) {
        flags[j] = 0;
      }
    }
  }
  print('Primes up to ${n.toString().padLeft(8)} ${count.toString().padLeft(8)}');
}

void main(List<String> args) {
  final n = args.isNotEmpty ? int.parse(args[0]) : 4;
  for (var i = 0; i < 3; i++) {
    nsieve(10000 << (n - i));
  }
}
