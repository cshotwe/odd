# Check patterns for odd-plan

## CLI feature

```
odd check "feature works end-to-end" --cmd "./app --new-flag" --expect "expected output" --kind e2e
odd check "without flag unchanged"   --cmd "./app"            --expect "original"      --kind e2e
```

## Bug fix

```
odd check "bug reproduces"  --cmd "<repro command>" --expect-fail --kind e2e
odd check "bug is fixed"    --cmd "<same command>"  --expect "<fixed output>" --kind e2e
```

## HTTP endpoint

```
odd check "GET returns data" --cmd 'curl -sf http://localhost:8000/api/items | grep -q item' --kind e2e
```

## Reference oracle (provided binary/file)

```bash
cp reference_bin .odd/reference_bin
odd check "output matches reference" \
  --cmd 'make build && diff <(./built -k "Hi") <(.odd/reference_bin -k "Hi")' \
  --kind reference
```

## Spec criterion line format

In `specs/*.md` acceptance criteria:

```
- human description | cmd: `./tool args` | expect: `substring` | kind: e2e
- error path        | cmd: `./tool bad`  | expect-fail | kind: e2e
```
