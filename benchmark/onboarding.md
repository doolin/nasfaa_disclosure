# Operator runbook: running the PDF→rules benchmark

A step-by-step procedure for scoring an agent on the
[`pdf-to-rules`](pdf-to-rules.md) benchmark. **Do one step at a time.**
Each step ends with a ✋ checkpoint — don't start the next step until the
checkpoint passes. If a checkpoint fails, fix it before continuing; the
later steps assume every earlier one succeeded.

The scorer is `bin/benchmark-rules`; the held-out answer key is
`nasfaa_rules.yml`; the agent never sees the key.

---

## Step 1 — Confirm the toolchain runs

Check Ruby is available and the scorer works by scoring the key against
itself (a trivially perfect run):

```sh
ruby -v
bin/benchmark-rules nasfaa_rules.yml
```

✋ **Checkpoint.** The second command prints `Score : 100.0%` and
`PASS`. If it errors, stop and resolve it (wrong directory? Ruby missing?)
before going on. Everything downstream depends on the scorer running.

---

## Step 2 — Make a place for submissions

Candidate rule files are local run artifacts, not part of the project:

```sh
mkdir -p benchmark/candidates
```

✋ **Checkpoint.** `benchmark/candidates/` exists. (Leave it out of git, or
add it to `.gitignore` — it holds per-agent outputs, not source.)

---

## Step 3 — Brief the agent under test

Give the agent exactly two things and nothing else:

1. The prompt: the contents of `benchmark/pdf-to-rules.md`.
2. The input: `docs/NASFAA_Data_Sharing_Decision_Tree.pdf`.

**Do not** give it `nasfaa_rules.yml`, `lib/nasfaa/decision_tree.rb`,
`nasfaa_questions.yml`, or any other file that encodes the answer — that
would defeat the benchmark.

✋ **Checkpoint.** The agent has the prompt and the PDF, and has confirmed
it will emit a single YAML rules file in the specified format.

---

## Step 4 — Capture the agent's output

Save the agent's emitted YAML verbatim to a named file:

```sh
# e.g. benchmark/candidates/<agent>-<YYYY-MM-DD>.yml
$EDITOR benchmark/candidates/claude-2026-06-16.yml
```

✋ **Checkpoint.** The file exists and contains the agent's full output
(top-level `rules:` list present). Don't hand-fix the content — you are
scoring the agent, not yourself.

---

## Step 5 — Score it

Run the scorer against your candidate:

```sh
make benchmark CANDIDATE=benchmark/candidates/claude-2026-06-16.yml
# or directly:
bin/benchmark-rules benchmark/candidates/claude-2026-06-16.yml
```

✋ **Checkpoint.** You see a `Score : NN.NN%` line and either `PASS` or
`FAIL`. (A YAML or missing-`rules:` error here means the agent's output is
malformed — that is itself a failing result; record it as score 0 with a
note.)

---

## Step 6 — Read the divergences

- **`Score : 100.0%` / PASS** → the candidate is behaviourally identical
  to the key across all 36,864 input vectors. Done — go to Step 7.
- **`FAIL`** → the scorer lists the first diverging input vectors. Each
  block reads:

  ```
  true inputs : includes_fti, disclosure_to_student
  expected    : permit (FTI_R1_student)
  candidate   : deny  (FTI_DENY_default)
  ```

  That tells you the input combination, what the key does (and which key
  rule fired), and what the candidate did. The usual root causes, in order
  of frequency: a **missing guard** (a deny that should pre-empt a later
  permit), a **wrong/absent negation** in a `when_all`, **rule ordering**
  (first-match-wins puts a loose rule ahead of a specific one), or a
  **missing rule/branch** entirely. Raise `--limit` to see more vectors.

✋ **Checkpoint.** You can name the score and, if it failed, point to at
least one concrete rule the candidate got wrong.

---

## Step 7 — Record the result

Append a row to a running log so runs are comparable over time — agent,
date, score, and a one-line note on the dominant failure mode:

```
| Agent              | Date       | Score   | Notes                                   |
|--------------------|------------|---------|-----------------------------------------|
| claude-opus-4-8    | 2026-06-16 | 100.0%  | clean                                   |
| <other>            | 2026-06-15 | 84.38%  | missing FTI student permit; deny-default|
```

✋ **Checkpoint.** The result is written down somewhere durable (e.g.
`benchmark/results.md`). This is the point of the benchmark — a record you
can compare across agents and over time.

---

## Step 8 (optional) — Iterate or compare

- To let the agent self-correct, hand it **only** the diverging vectors
  from Step 6 (never the key) and re-run Steps 4–7 with a new candidate
  filename so attempts stay distinct.
- To compare agents, repeat Steps 3–7 per agent into separate candidate
  files and collect their scores in the Step 7 table.

✋ **Done.** You have a scored, recorded benchmark run.
