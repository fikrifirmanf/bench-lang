# Digits of e by binary splitting of sum(1/k!), on Ruby's arbitrary-precision Integer.
def sum_terms(a, b)
  return [1, b] if b == a + 1

  mid = (a + b) / 2
  p_left, q_left = sum_terms(a, mid)
  p_right, q_right = sum_terms(mid, b)
  [p_left * q_right + p_right, q_left * q_right]
end

def test_k(n, k)
  return false if k <= 0

  ln_k_factorial = k * (Math.log(k) - 1) + 0.5 * Math.log(2 * Math::PI)
  ln_k_factorial / Math.log(10) >= n + 50
end

def binary_search(n)
  a = 0
  b = 1
  until test_k(n, b)
    a = b
    b *= 2
  end
  while b - a > 1
    m = (a + b) / 2
    if test_k(n, m) then b = m else a = m end
  end
  b
end

n = (ARGV[0] || 27).to_i
p, q = sum_terms(0, binary_search(n) - 1)
s = ((p + q) * 10**(n - 1) / q).to_s
out = +''
(0...n).step(10) do |i|
  if i + 10 <= n
    out << "#{s[i, 10]}\t:#{i + 10}\n"
  else
    out << "#{s[i...n].ljust(10)}\t:#{n}\n"
  end
end
$stdout.write(out)
