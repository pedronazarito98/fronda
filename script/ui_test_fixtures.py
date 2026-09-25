#!/usr/bin/env python3
"""Prepare real, isolated projects via the shipped CLI before XCUITest enters its sandbox."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

PROJECT = Path(__file__).resolve().parents[1]
MANIFEST = PROJECT / ".qa/ui-tests/manifest.json"
CASES = {
    "testAppearanceSettingPersists": "Appearance acceptance",
    "testComposerRequiresObjectiveAndCreatesPreparedRun": None,
    "testGateStatesAndStaleEvidenceAreVisible": "Gate acceptance",
    "testPaletteNavigatesAndEscapeDismissesIt": "Searchable QA run",
    "testProjectsAndRunsSurviveApplicationRestart": "Persistent QA run",
    "testSecondRunWindowCanCloseWithoutClosingMainWindow": "Window acceptance",
}


def command(argv, cwd=None, payload=None):
    return subprocess.run(argv, cwd=cwd, input=payload, text=True, capture_output=True, check=True, timeout=45).stdout


def cleanup():
    if not MANIFEST.exists():
        return
    manifest = json.loads(MANIFEST.read_text())
    for case in manifest.get("cases", {}).values():
        runtime = case["runtime"]
        service = "com.harness.coordinator." + hashlib.sha256(runtime.encode()).hexdigest()[:12]
        subprocess.run(["/bin/launchctl", "bootout", f"gui/{os.getuid()}/{service}"], capture_output=True, timeout=15)
    directory = Path(manifest["directory"])
    if directory.name.startswith("HarnessUITests-") and directory.parent == Path(tempfile.gettempdir()):
        shutil.rmtree(directory, ignore_errors=True)
    MANIFEST.unlink()


def prepare(app):
    cleanup()
    cli = str(Path(app) / "Contents/Helpers/harness")
    directory = Path(tempfile.mkdtemp(prefix="HarnessUITests-"))
    manifest = {"directory": str(directory), "cases": {}}
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)

    def persist():
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False))

    persist()
    try:
        for name, title in CASES.items():
            root = directory / name
            repository = root / "QA Project"
            runtime = str(root / "runtime")
            repository.mkdir(parents=True)
            manifest["cases"][name] = {"runtime": runtime}
            persist()
            (repository / "Greeting.swift").write_text('func greeting() -> String { "hello" }\n')
            (repository / "Next.swift").write_text('func greeting() -> String { "updated" }\n')
            git = ["git", "-c", "core.hooksPath=/dev/null", "-c", "user.name=Harness QA", "-c", "user.email=qa@example.invalid", "-c", "commit.gpgsign=false"]
            for args in [["init", "--initial-branch=main"], ["add", "Greeting.swift", "Next.swift"], ["commit", "-m", "UI acceptance fixture"]]:
                command(git + args, cwd=repository)

            def rpc(action, **fields):
                request = dict(requestID=str(uuid.uuid4()), action=action, id="", relatedID="", text="", path="", arguments=[], flag=False, number=0)
                request.update(fields)
                response = json.loads(command([cli, "--root", runtime, "rpc"], payload=json.dumps(request)))
                if response.get("error"):
                    raise RuntimeError(response["error"])
                return response

            snapshot = rpc("snapshot")["snapshot"]
            preferences = snapshot["preferences"]
            preferences["providers"] = {"Codex": "/nonexistent/harness-qa-codex", "Claude Code": "/nonexistent/harness-qa-claude"}
            rpc("preferences.save", preferences=preferences)
            project_id = rpc("project.add", path=str(repository))["id"]
            project = next(p for p in rpc("snapshot")["snapshot"]["projects"] if p["id"] == project_id)

            def gate(identity, executable, approved=True, arguments=None, read_only=True):
                return dict(id=identity, name=identity, executable=executable, arguments=arguments or [], timeoutSeconds=10, required=identity != "qa-edit", approved=approved, readOnly=read_only)

            project["validators"] = [gate("qa-pass", "/usr/bin/true"), gate("qa-fail", "/usr/bin/false"), gate("qa-blocked", "/usr/bin/true", approved=False)]
            rpc("project.update", project=project)
            book = next(b for b in snapshot["runbooks"] if b["id"] == "builtin-0")
            book["name"] = "QA local sem provider"
            # This existing UI fixture intentionally exercises the legacy, provider-free graph.
            book["workKind"] = None
            book["steps"] = [s for s in book["steps"] if s["kind"] not in ["investigation", "implementation", "review"]]
            for index, step in enumerate(book["steps"]):
                step["dependencies"] = [book["steps"][index - 1]["id"]] if index else []
            rpc("runbook.save", runbook=book)
            run = None
            if title:
                response = json.loads(command([cli, "--root", runtime, "--json", "create", project_id, title, "--runbook", book["name"], "--criterion", "Gate outputs match actual exit codes"]))
                deadline = time.monotonic() + 25
                while time.monotonic() < deadline:
                    run = rpc("run.get", id=response["id"])["run"]
                    if run["state"] == "WAITING_USER":
                        break
                    if run["state"] in ["FAILED", "BLOCKED"]:
                        raise RuntimeError(run["reason"])
                    time.sleep(0.2)
                if run["state"] != "WAITING_USER":
                    raise RuntimeError("Fixture did not prepare within 25 seconds")
            # Add an explicit mutation gate only after preparation. Its individual button lets
            # the UI exercise a real file edit without giving the UI test runner shell access.
            if name == "testGateStatesAndStaleEvidenceAreVisible":
                project["validators"].append(gate("qa-edit", "/bin/cp", arguments=["Next.swift", "Greeting.swift"], read_only=False))
                rpc("project.update", project=project)
            manifest["cases"][name].update(project=project, run=run)
            persist()
    except Exception as error:
        manifest["error"] = str(error)
        persist()
        raise
    print("Prepared six isolated UI fixtures through the real coordinator.")


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "cleanup":
        cleanup()
    elif len(sys.argv) == 3 and sys.argv[1] == "prepare":
        prepare(sys.argv[2])
    else:
        raise SystemExit("Usage: ui_test_fixtures.py prepare <Harness.app> | cleanup")
