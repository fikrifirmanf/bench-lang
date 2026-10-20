// Scalar mandelbrot: 50 iterations per pixel, then the MD5 of the packed bitmap.
// Go may fuse x*y+z into one FMA instruction on arm64, which rounds differently from the reference output;
// an explicit float64() conversion of the product forbids that fusion.
package main

import (
	"crypto/md5"
	"fmt"
	"os"
	"strconv"
)

func pixelByte(cr []float64, ci float64) byte {
	var bits byte
	for k := 0; k < 8; k++ {
		var zr, zi, tr, ti float64
		escaped := false
		for i := 0; i < 50 && !escaped; i++ {
			zi = float64((zr+zr)*zi) + ci
			zr = tr - ti + cr[k]
			tr = zr * zr
			ti = zi * zi
			escaped = float64(tr)+float64(ti) > 4.0
		}
		if !escaped {
			bits |= 0x80 >> k
		}
	}
	return bits
}

func main() {
	size := 200
	if len(os.Args) > 1 {
		if n, err := strconv.Atoi(os.Args[1]); err == nil {
			size = n
		}
	}
	size = (size + 7) / 8 * 8
	rowBytes := size / 8
	inv := 2.0 / float64(size)
	xs := make([]float64, size)
	for i := range xs {
		xs[i] = float64(float64(i)*inv) - 1.5
	}
	pixels := make([]byte, size*rowBytes)
	for y := 0; y < size; y++ {
		ci := float64(float64(y)*inv) - 1.0
		for i := 0; i < rowBytes; i++ {
			pixels[y*rowBytes+i] = pixelByte(xs[i*8:i*8+8], ci)
		}
	}
	fmt.Printf("P4\n%d %d\n%x\n", size, size, md5.Sum(pixels))
}
