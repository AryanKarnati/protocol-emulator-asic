// Exhaustive check of the generated Verilog decoder against the ISA reference table.
// The table (formal/build/decode_expected.txt, from dump_expected.exe) has one line per
// (word, side-set configuration) case with 18 decimal fields:
//   instr count enable legal is_jmp is_wait is_in is_out is_push is_pull is_mov is_irq
//   is_set uses_lcu side_valid side_value delay bit_count
// side_value is compared only when side_valid is 1 (engine.md section 4).
// Exit status: 0 when every case agrees, 1 on any mismatch, 2 on a usage or I/O error.

#include "Vdecode.h"
#include "verilated.h"

#include <cstdio>

int main(int argc, char** argv) {
  if (argc != 2) {
    std::fprintf(stderr, "usage: %s decode_expected.txt\n", argv[0]);
    return 2;
  }
  FILE* f = std::fopen(argv[1], "r");
  if (!f) {
    std::perror("open");
    return 2;
  }

  VerilatedContext* ctx = new VerilatedContext;
  Vdecode* top = new Vdecode{ctx};

  unsigned long cases = 0, bad = 0;
  unsigned w, count, en, legal, jmp, wait_, in_, out_, push, pull, mov, irq, set_, lcu,
      sv, sval, delay, bits;
  while (std::fscanf(f,
                     "%u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u",
                     &w, &count, &en, &legal, &jmp, &wait_, &in_, &out_, &push, &pull,
                     &mov, &irq, &set_, &lcu, &sv, &sval, &delay, &bits) == 18) {
    top->instr = w;
    top->sideset_count = count;
    top->side_en = en;
    top->eval();
    cases++;

    bool ok = top->legal == legal && top->is_jmp == jmp && top->is_wait == wait_ &&
              top->is_in == in_ && top->is_out == out_ && top->is_push == push &&
              top->is_pull == pull && top->is_mov == mov && top->is_irq == irq &&
              top->is_set == set_ && top->uses_lcu == lcu &&
              top->side_valid == sv && (!sv || top->side_value == sval) &&
              top->delay == delay && top->bit_count == bits;
    if (!ok) {
      bad++;
      if (bad <= 10) {
        std::printf(
            "MISMATCH word=%04x count=%u enable=%u: rtl legal=%u in=%u out=%u sv=%u "
            "sval=%u delay=%u bits=%u | ref legal=%u in=%u out=%u sv=%u sval=%u "
            "delay=%u bits=%u\n",
            w, count, en, (unsigned)top->legal, (unsigned)top->is_in,
            (unsigned)top->is_out, (unsigned)top->side_valid,
            (unsigned)top->side_value, (unsigned)top->delay, (unsigned)top->bit_count,
            legal, in_, out_, sv, sval, delay, bits);
      }
    }
  }
  std::fclose(f);
  std::printf("verilog decode: %lu cases checked, %lu mismatches\n", cases, bad);

  top->final();
  delete top;
  delete ctx;
  if (cases != 720896UL) {
    std::fprintf(stderr, "expected 720896 cases, read %lu\n", cases);
    return 2;
  }
  return bad ? 1 : 0;
}
