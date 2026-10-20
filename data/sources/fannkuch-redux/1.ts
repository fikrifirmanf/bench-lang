// Single-threaded fannkuch-redux on Int32Arrays.
function fannkuch(n: number): [number, number] {
  const perm = new Int32Array(n);
  const perm1 = new Int32Array(n);
  const count = new Int32Array(n);
  for (let i = 0; i < n; i++) perm1[i] = i;

  let maxFlips = 0, checksum = 0, permCount = 0, r = n;
  for (;;) {
    for (; r !== 1; r--) count[r - 1] = r;

    perm.set(perm1);
    let flips = 0;
    for (let k = perm[0]; k !== 0; k = perm[0], flips++) {
      for (let i = 0, j = k; i < j; i++, j--) {
        const t = perm[i];
        perm[i] = perm[j];
        perm[j] = t;
      }
    }
    if (flips > maxFlips) maxFlips = flips;
    checksum += permCount % 2 === 0 ? flips : -flips;

    for (;;) {
      if (r === n) return [checksum, maxFlips];
      const first = perm1[0];
      for (let i = 0; i < r; i++) perm1[i] = perm1[i + 1];
      perm1[r] = first;
      if (--count[r] > 0) break;
      r++;
    }
    permCount++;
  }
}

const n = +Deno.args[0] || 7;
const [checksum, maxFlips] = fannkuch(n);
console.log(`${checksum}\nPfannkuchen(${n}) = ${maxFlips}`);
