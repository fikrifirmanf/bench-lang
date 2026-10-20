// Prime sieve as Go-style concurrent tasks: one async generator task and one async filter task per prime, linked
// by unbuffered channels. Values hop between tasks through promises, so the 4000-deep chain never nests stacks
// (1.ts nests async generator calls 4000 deep and overflows the stack).
class Channel {
  private value = 0;
  private full = false;
  private waitingReceiver: (() => void) | null = null;
  private waitingSender: (() => void) | null = null;

  async send(value: number): Promise<void> {
    while (this.full) await new Promise<void>((resolve) => (this.waitingSender = resolve));
    this.value = value;
    this.full = true;
    this.waitingReceiver?.();
    this.waitingReceiver = null;
  }

  async receive(): Promise<number> {
    while (!this.full) await new Promise<void>((resolve) => (this.waitingReceiver = resolve));
    this.full = false;
    this.waitingSender?.();
    this.waitingSender = null;
    return this.value;
  }
}

async function generate(out: Channel) {
  for (let i = 2; ; i++) await out.send(i);
}

async function filter(input: Channel, out: Channel, prime: number) {
  for (;;) {
    const value = await input.receive();
    if (value % prime !== 0) await out.send(value);
  }
}

async function main() {
  const n = +Deno.args[0] || 100;
  let ch = new Channel();
  generate(ch);
  const lines: string[] = [];
  for (let i = 0; i < n; i++) {
    const prime = await ch.receive();
    lines.push(String(prime));
    const next = new Channel();
    filter(ch, next, prime);
    ch = next;
  }
  console.log(lines.join("\n"));
  Deno.exit(0);
}

main();
