# Single-threaded fannkuch-redux.
def fannkuch(n)
  perm1 = (0...n).to_a
  count = Array.new(n, 0)
  max_flips = checksum = perm_count = 0
  r = n
  loop do
    while r != 1
      count[r - 1] = r
      r -= 1
    end
    perm = perm1.dup
    flips = 0
    while (k = perm[0]) != 0
      perm[0..k] = perm[0..k].reverse!
      flips += 1
    end
    max_flips = flips if flips > max_flips
    checksum += perm_count.even? ? flips : -flips
    loop do
      return [checksum, max_flips] if r == n

      perm1.insert(r, perm1.shift)
      count[r] -= 1
      break if count[r] > 0

      r += 1
    end
    perm_count += 1
  end
end

n = (ARGV[0] || 7).to_i
checksum, max_flips = fannkuch(n)
puts "#{checksum}\nPfannkuchen(#{n}) = #{max_flips}"
