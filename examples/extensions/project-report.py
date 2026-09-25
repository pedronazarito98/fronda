#!/usr/bin/env python3
"""Harness command adapter: record actual Git state as a local evidence report."""
import json
from pathlib import Path
import subprocess
import sys

request = json.load(sys.stdin)
workspace = Path(request["workspace"]).resolve()
output = Path(request["outputDirectory"]).resolve()
output.mkdir(parents=True, exist_ok=True)
result = subprocess.run(
    ["/usr/bin/git", "status", "--short", "--untracked-files=no"],
    cwd=workspace, capture_output=True, text=True, check=True, timeout=20,
)
report = output / "project-state.md"
report.write_text(
    "# Estado observado do projeto\n\n"
    f"Run: {request['runID']}\n\nSnapshot: {request['revision']}\n\n"
    "Comando executado: `git status --short --untracked-files=no`\n\n"
    f"```text\n{result.stdout or '(nenhuma alteração rastreada)'}\n```\n\n"
    "Este relatório registra estado Git. Não executa validação funcional nem aprova critérios.\n",
    encoding="utf-8",
)
print(json.dumps({
    "text": "Estado Git observado e registrado em relatório local.",
    "artifacts": [{
        "path": "@output/project-state.md", "title": "Estado Git observado",
        "criterionIDs": [criterion["id"] for criterion in request["criteria"]],
        "providerReadable": True,
    }],
}))
