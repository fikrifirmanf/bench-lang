// LRU cache on LinkedHashMap in access order, evicting the eldest entry past capacity.
import java.util.LinkedHashMap;
import java.util.Map;

final class app {
  static final class Lru<K, V> extends LinkedHashMap<K, V> {
    private final int size;

    Lru(int size) {
      super(size * 2, 0.75f, true);
      this.size = size;
    }

    @Override
    protected boolean removeEldestEntry(Map.Entry<K, V> eldest) {
      return size() > size;
    }
  }

  static long seed0 = 0, seed1 = 1;

  static long lcg0() {
    seed0 = (1103515245L * seed0 + 12345) % (1L << 31);
    return seed0;
  }

  static long lcg1() {
    seed1 = (1103515245L * seed1 + 12345) % (1L << 31);
    return seed1;
  }

  public static void main(String[] args) {
    int size = args.length > 0 ? Integer.parseInt(args[0]) : 100;
    int n = args.length > 1 ? Integer.parseInt(args[1]) : 1000;
    long mod = size * 10L;
    var lru = new Lru<Integer, Integer>(size);
    long hit = 0, missed = 0;
    for (int i = 0; i < n; i++) {
      int n0 = (int) (lcg0() % mod);
      lru.put(n0, n0);
      int n1 = (int) (lcg1() % mod);
      if (lru.get(n1) == null) {
        missed++;
      } else {
        hit++;
      }
    }
    System.out.println(hit);
    System.out.println(missed);
  }
}
