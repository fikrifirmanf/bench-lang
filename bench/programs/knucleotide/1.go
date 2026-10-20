// k-nucleotide: counts every k-mer of the THREE sequence in a map keyed by 2-bit packed codes.
// Percentages are computed in float64; float32 (as 7.go uses) rounds 5.9575 the wrong way.
package main

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"sort"
	"strings"
)

func codeOf(c byte) uint64 {
	switch c {
	case 'A':
		return 0
	case 'C':
		return 1
	case 'G':
		return 2
	}
	return 3
}

func countKmers(seq []byte, k int) map[uint64]int {
	counts := make(map[uint64]int)
	mask := uint64(1)<<(2*uint(k)) - 1
	var key uint64
	for i, c := range seq {
		key = (key<<2 | codeOf(c)) & mask
		if i+1 >= k {
			counts[key]++
		}
	}
	return counts
}

func unpack(key uint64, k int) string {
	out := make([]byte, k)
	for i := k - 1; i >= 0; i-- {
		out[i] = "ACGT"[key&3]
		key >>= 2
	}
	return string(out)
}

func printFrequencies(w *bufio.Writer, seq []byte, k int) {
	type entry struct {
		kmer  string
		count int
	}
	var sorted []entry
	for key, count := range countKmers(seq, k) {
		sorted = append(sorted, entry{unpack(key, k), count})
	}
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].count != sorted[j].count {
			return sorted[i].count > sorted[j].count
		}
		return sorted[i].kmer < sorted[j].kmer
	})
	total := float64(len(seq) - k + 1)
	for _, e := range sorted {
		fmt.Fprintf(w, "%s %.3f\n", e.kmer, float64(e.count)*100.0/total)
	}
	fmt.Fprintln(w)
}

func main() {
	fileName := "25000_in"
	if len(os.Args) > 1 {
		fileName = os.Args[1]
	}
	file, err := os.Open(fileName)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 1<<16), 1<<20)
	for scanner.Scan() && !strings.HasPrefix(scanner.Text(), ">THREE") {
	}
	var seq bytes.Buffer
	for scanner.Scan() {
		line := scanner.Bytes()
		if len(line) > 0 && line[0] == '>' {
			break
		}
		seq.Write(bytes.ToUpper(bytes.TrimSpace(line)))
	}

	w := bufio.NewWriter(os.Stdout)
	defer w.Flush()
	data := seq.Bytes()
	printFrequencies(w, data, 1)
	printFrequencies(w, data, 2)
	for _, kmer := range []string{"GGT", "GGTA", "GGTATT", "GGTATTTTAATT", "GGTATTTTAATTTATAGT"} {
		var key uint64
		for i := 0; i < len(kmer); i++ {
			key = key<<2 | codeOf(kmer[i])
		}
		fmt.Fprintf(w, "%d\t%s\n", countKmers(data, len(kmer))[key], kmer)
	}
}
