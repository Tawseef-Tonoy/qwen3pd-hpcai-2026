
## Final interpretation

No tested point achieved full-run GFR >= 0.90.

Results:

- C30: GFR 0.621, TTFT pass 62.1%, ITL pass 100%
- C32: GFR 0.231, TTFT pass 100%, ITL pass 23.1%
- C34: GFR 0.064, TTFT pass 100%, ITL pass 6.4%
- C36: GFR 0.057, TTFT pass 100%, ITL pass 5.7%

C30 chronological analysis showed strong startup/state effects:

- early deciles had severe TTFT failures;
- ITL remained 100% SLA-valid throughout;
- final decile reached 100% TTFT and 100% ITL pass.

C32 and above had healthy TTFT but crossed the Decode ITL boundary.

Therefore the Decode SLA knee lies between C30 and C32.

The only untested integer point is C31.

Next experiment:
EXP-007 will test C31 alone using exact official 60/120/30 timing.
