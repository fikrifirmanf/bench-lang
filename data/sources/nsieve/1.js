// Sieve of Eratosthenes over a Uint8Array of flags.
function nsieve(n) {
  const composite = new Uint8Array(n);
  let count = 0;
  for (let i = 2; i < n; i++) {
    if (composite[i] === 0) {
      count++;
      for (let j = i << 1; j < n; j += i) composite[j] = 1;
    }
  }
  console.log(`Primes up to ${String(n).padStart(8)} ${String(count).padStart(8)}`);
}

const n = +process.argv[2] || 4;
for (let i = 0; i < 3; i++) nsieve(10000 << (n - i));
