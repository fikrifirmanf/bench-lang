# Scalar mandelbrot: 50 iterations per pixel, then the MD5 of the packed bitmap.
require 'digest/md5'

size = (ARGV[0] || 200).to_i
size = (size + 7) / 8 * 8
inv = 2.0 / size
xs = Array.new(size) { |i| i * inv - 1.5 }
pixels = String.new(capacity: size * size / 8, encoding: Encoding::BINARY)
size.times do |y|
  ci = y * inv - 1.0
  (size / 8).times do |byte|
    bits = 0
    8.times do |k|
      cr = xs[byte * 8 + k]
      zr = zi = tr = ti = 0.0
      escaped = false
      i = 0
      while i < 50
        zi = (zr + zr) * zi + ci
        zr = tr - ti + cr
        tr = zr * zr
        ti = zi * zi
        if tr + ti > 4.0
          escaped = true
          break
        end
        i += 1
      end
      bits |= 0x80 >> k unless escaped
    end
    pixels << bits.chr
  end
end
puts "P4\n#{size} #{size}\n#{Digest::MD5.hexdigest(pixels)}"
