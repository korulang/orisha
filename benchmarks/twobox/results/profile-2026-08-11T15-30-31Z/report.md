
## Held-out skewed workload over the whole site

| build | req/s (median) | vs cold |
|---|---|---|
| orisha-cold | 150,900 | 1.000x |
| orisha-warm | 155,075 | 1.028x |
| nginx | 108,902 | 0.722x |
| h2o | 97,217 | 0.644x |

nginx and h2o are controls — neither can read a profile, so any movement
between their rounds is the machine, not the experiment.

  orisha-cold: 150,900, 154,557, 147,244
  orisha-warm: 147,356, 155,075, 160,379
  nginx: 108,558, 111,202, 108,902
  h2o: 91,616, 97,217, 99,214
