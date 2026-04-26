Start the pi-native grind harness for this repository.

Use `/grind` directly when available. Arguments are JSON, for example:

```text
/grind {"rounds":1}
```

To stop gracefully, run:

```text
/grind-stop
```

Do not run `/reload` while a grind is active; the current harness is in-process and reload can interrupt it. Use `/grind-status` for status and `/grind-stop` before reloading.
