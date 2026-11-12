"""Run: python tests/check_conversion_heap.py [repository ...] (requires JDK)."""

from pathlib import Path
import re
import subprocess
import sys


for root in map(Path, sys.argv[1:] or ["."]):
    patch = root / "folia-server/minecraft-patches/features/0015-Add-Linear-region-format-support-with-worlds-setting.patch"
    text = patch.read_text(encoding="utf-8")
    subprocess.run(["git", "apply", "--numstat", str(patch.resolve())],
                   check=True, capture_output=True, text=True)
    expression = re.search(r"MEMORY_THROTTLE_BYTES = ([^;]+);", text).group(1)
    assert expression == "(long) (Runtime.getRuntime().maxMemory() * 0.8)"
    assert "if (current % 100 == 0 || used >= MEMORY_THROTTLE_BYTES)" in text
    assert "if (used >= MEMORY_THROTTLE_BYTES)" in text
    assert "while (used >= MEMORY_THROTTLE_BYTES)" in text
    for obsolete in ("MAX_ALLOWED_MEMORY_BYTES", "12288", "usedMb > 8000", "10 GB", "12 GB"):
        assert obsolete not in text, obsolete
    for heap in ("256m", "1g"):
        result = subprocess.run(
            ["jshell", f"-R-Xmx{heap}", "--feedback", "silent"],
            input=f"""long max = Runtime.getRuntime().maxMemory();
long limit = {expression};
if (limit == max * 4 / 5 && limit > 0 && limit < max) System.out.println("HEAP_CHECK_OK");
/exit
""",
            check=True, capture_output=True, text=True, timeout=60,
        )
        assert "HEAP_CHECK_OK" in result.stdout, result.stdout + result.stderr
    print(f"PASS {root}: patch syntax, throttle checks, JVM heaps 256m/1g")
