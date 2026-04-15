"""ask-local --agent: bounded ReAct loop, Phi-3 drives packages/ CLIs.

GBNF forces {"tool":"<name>","args":"<str>"} | {"final":"<str>"} so the
3.8B model can't wander off-format; we parse, exec the matched argv
template, feed stdout back as an observation, cap at N turns. Tool
inventory lives in tools.json next to this file. Falsification target:
≥70% correct first-tool on bench-agent.jsonl (see backlog/adopt-tool-loop).
"""
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile

ASK_LOCAL = os.environ.get("ASK_LOCAL_BIN", "ask-local")
TOOLS = json.load(open(os.environ["ASK_LOCAL_TOOLS"]))
MAX_TURNS = int(os.environ.get("ASK_LOCAL_AGENT_TURNS", "4"))
OBS_CAP = 1200  # chars per observation; Phi-3-mini is 4k-context


def gbnf(names: list[str]) -> str:
    alts = " | ".join(f'"{n}"' for n in names)
    # Same string-literal shape as ptt-dictate's intent grammar (bench.sh).
    return (
        'root  ::= call | done\n'
        'call  ::= "{\\"tool\\":\\"" name "\\",\\"args\\":\\"" str "\\"}"\n'
        'done  ::= "{\\"final\\":\\"" str "\\"}"\n'
        f'name  ::= {alts}\n'
        'str   ::= [^"\\\\\\x7f\\x00-\\x1f]*\n'
    )


def ask(grammar_path: str, prompt: str) -> dict:
    out = subprocess.run(
        [ASK_LOCAL, "--grammar", grammar_path, "--fast", prompt],
        capture_output=True, text=True, check=False,
    ).stdout
    # --fast → llama-lookup echoes the prompt (no --no-display-prompt); the
    # constrained JSON is the last brace-pair on stdout.
    m = re.findall(r'\{[^{}]*\}', out)
    if not m:
        sys.exit(f"ask-local --agent: no JSON in model output:\n{out[-400:]}")
    return json.loads(m[-1])


def run_tool(spec: dict, args: str) -> str:
    argv: list[str] = []
    for a in spec["argv"]:
        if a != "{args}":
            argv.append(a)
            continue
        toks = shlex.split(args)
        # Observation text feeds back into the prompt, so a poisoned obs could
        # steer Phi-3 into emitting flags here. Reject; model retries on the
        # error string. Tools needing flags get a fixed-argv entry (kin-hosts).
        bad = next((t for t in toks if t.startswith("-")), None)
        if bad:
            return f"(rejected: args may not contain flags: {bad!r})"
        argv.extend(toks)
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=30)
        out = (p.stdout + p.stderr).strip()
    except FileNotFoundError:
        out = f"(tool not on PATH: {argv[0]})"
    except subprocess.TimeoutExpired:
        out = "(timed out after 30s)"
    return out[:OBS_CAP] + (" …[truncated]" if len(out) > OBS_CAP else "")


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: ask-local --agent \"<goal>\"")
    goal = " ".join(sys.argv[1:])
    by_name = {t["name"]: t for t in TOOLS}
    inventory = "\n".join(f"- {t['name']}: {t['desc']}" for t in TOOLS)
    sys_p = (
        "You are a tool-using assistant. Pick ONE tool per step, or finish.\n"
        f"Tools:\n{inventory}\n"
        'Reply with exactly {"tool":"<name>","args":"<str>"} to call a tool, '
        'or {"final":"<answer>"} when done.'
    )

    g = tempfile.NamedTemporaryFile("w", suffix=".gbnf", delete=False)
    g.write(gbnf(list(by_name)))
    g.close()

    transcript = f"{sys_p}\n\nGoal: {goal}\n"
    for turn in range(1, MAX_TURNS + 1):
        act = ask(g.name, transcript + "Action:")
        if "final" in act:
            print(act["final"])
            return
        tool, args = act["tool"], act.get("args", "")
        print(f"[{turn}] {tool} {args}", file=sys.stderr)
        obs = run_tool(by_name[tool], args)
        transcript += f"Action: {json.dumps(act)}\nObservation: {obs}\n"
    # Turn budget spent — force a final answer.
    act = ask(g.name, transcript + 'Action (you MUST use "final" now):')
    print(act.get("final", "(turn limit reached, no final answer)"))


if __name__ == "__main__":
    main()
