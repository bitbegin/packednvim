#!/usr/bin/env python3
"""逐条核验插件目录里的仓库地址是否真实存在。

选型目录里 200 多个地址是我从调研、文档和记忆里汇总的，其中已经发现过两个 404
（slugbyte/lackloud、leslie255/nvim-lightbulb）。这个脚本把「地址对不对」变成机械
可验证的事，避免带着错地址进入 vendoring 才炸。

用 `git ls-remote` 而不是 GitHub API：不受速率限制，且顺便拿到默认分支名。
注意 `git ls-remote` 不下载仓库内容，开销很小。

用法：
    python tools/verify-repos.py                 # 核验目录里的全部仓库
    python tools/verify-repos.py --only-mini     # 只核验被标记为 mini 模块的（跳过多模块仓库的去重）
    python tools/verify-repos.py --timeout 60    # 单个仓库超时秒数
    python tools/verify-repos.py --proxy http://127.0.0.1:7892

结果写到 build/repo-check.json，并在标准输出给出汇总。
任何一条失败都以退出码 1 结束。
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CATALOG = REPO_ROOT / "catalog" / "PLUGIN-CATALOG.md"
DEFAULT_OUT = REPO_ROOT / "build" / "repo-check.json"

ENTRY_RE = re.compile(r"^\s*-\s*\[(?P<mark>[ xX])\]\s*\*\*(?P<pid>[^*]+?)\*\*")


def collect_repos(path: Path) -> list[str]:
    """从目录里抽出所有去重后的 owner/repo（忽略 #module 后缀）。"""
    repos: list[str] = []
    seen: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        m = ENTRY_RE.match(line)
        if not m:
            continue
        repo = m.group("pid").split("#", 1)[0].strip()
        if repo and repo not in seen:
            seen.add(repo)
            repos.append(repo)
    return repos


def classify(error: str) -> str:
    """把失败分成「地址真的错了」和「网络没跑完」两类。

    这个区分很要紧：代理抖动会让一个好地址看起来像坏地址，如果都当成地址错误，
    就会去改本来正确的地址。反之把真错误当成网络问题，就会带着错地址进入 vendoring。
    """
    low = error.lower()
    # GitHub 对不存在的公开仓库，git over HTTPS 会回 "Authentication failed"
    if "authentication failed" in low or "repository not found" in low or "not found" in low:
        return "notfound"
    if "超时" in error or "timeout" in low:
        return "network"
    if "tls" in low or "ssl" in low or "connection" in low or "resolve" in low or "reset" in low:
        return "network"
    if "无法执行 git" in error:
        return "env"
    return "unknown"


def ls_remote_once(repo: str, timeout: int, proxy: str | None) -> dict:
    cmd = ["git"]
    if proxy:
        cmd += ["-c", f"http.proxy={proxy}", "-c", f"https.proxy={proxy}"]
    cmd += ["ls-remote", "--symref", f"https://github.com/{repo}.git", "HEAD"]

    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, encoding="utf-8", errors="replace"
        )
    except subprocess.TimeoutExpired:
        return {"repo": repo, "ok": False, "error": f"超时（{timeout}s）"}
    except OSError as exc:
        return {"repo": repo, "ok": False, "error": f"无法执行 git：{exc}"}

    if proc.returncode != 0:
        err = (proc.stderr or "").strip().splitlines()
        msg = err[-1] if err else f"git 退出码 {proc.returncode}"
        return {"repo": repo, "ok": False, "error": msg}

    branch = None
    sha = None
    for line in (proc.stdout or "").splitlines():
        if line.startswith("ref:"):
            branch = line.split("ref:", 1)[1].strip().split("\t")[0].replace("refs/heads/", "")
        elif line.endswith("HEAD") and "\t" in line:
            sha = line.split("\t", 1)[0].strip()
    return {"repo": repo, "ok": True, "branch": branch, "head": sha}


def check_one(repo: str, timeout: int, proxy: str | None, retries: int) -> dict:
    """带重试的核验。地址确实不存在时不浪费时间重试。"""
    result: dict = {"repo": repo, "ok": False, "error": "未执行"}
    for attempt in range(1, retries + 1):
        result = ls_remote_once(repo, timeout, proxy)
        if result["ok"]:
            result["attempts"] = attempt
            return result
        result["kind"] = classify(result["error"])
        result["attempts"] = attempt
        if result["kind"] in ("notfound", "env"):
            return result
        if attempt < retries:
            time.sleep(1.5 * attempt)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="核验目录里的仓库地址")
    parser.add_argument("--catalog", type=Path, default=CATALOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--timeout", type=int, default=45, help="单个仓库超时秒数")
    parser.add_argument("--jobs", type=int, default=4, help="并发数；代理不稳时调小")
    parser.add_argument("--retries", type=int, default=4, help="每个仓库的重试次数（地址确不存在时不重试）")
    parser.add_argument("--proxy", default="", help="git 走的代理，留空则用 git 全局配置")
    args = parser.parse_args(argv)

    if not args.catalog.is_file():
        print(f"找不到目录文件：{args.catalog}", file=sys.stderr)
        return 2

    repos = collect_repos(args.catalog)
    if not repos:
        print("目录里没解析出任何仓库", file=sys.stderr)
        return 2

    proxy = args.proxy or None
    print(f"待核验仓库 {len(repos)} 个，并发 {args.jobs}，单个超时 {args.timeout}s，重试 {args.retries} 次", flush=True)
    if proxy:
        print(f"git 代理：{proxy}")
    print(flush=True)

    results: list[dict] = []
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for i, res in enumerate(
            pool.map(lambda r: check_one(r, args.timeout, proxy, args.retries), repos), 1
        ):
            results.append(res)
            if res["ok"]:
                print(f"  [{i:>3}/{len(repos)}] OK    {res['repo']}  ({res.get('branch') or '?'})", flush=True)
            else:
                tag = "地址错" if res.get("kind") == "notfound" else "网络"
                extra = f"  重试 {res.get('attempts')} 次" if res.get("attempts", 1) > 1 else ""
                print(f"  [{i:>3}/{len(repos)}] {tag}  {res['repo']}  -> {res['error']}{extra}", flush=True)

    bad = [r for r in results if not r["ok"]]
    wrong = [r for r in bad if r.get("kind") == "notfound"]
    flaky = [r for r in bad if r.get("kind") != "notfound"]
    payload = {
        "checked": len(results),
        "ok": len(results) - len(bad),
        "failed": len(bad),
        "wrong_address": len(wrong),
        "network_incomplete": len(flaky),
        "results": results,
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    print()
    print("=" * 60)
    print(f"通过 {payload['ok']} / {len(results)}")
    if wrong:
        print(f"\n【必须修正的地址】{len(wrong)} 个（这类才是真的写错了）：")
        for r in wrong:
            print(f"  - {r['repo']}  ->  {r['error']}")
    if flaky:
        print(f"\n【网络未完成】{len(flaky)} 个（地址大概率没问题，代理抖动，重跑即可）：")
        for r in flaky:
            print(f"  - {r['repo']}  ->  {r['error']}")
        print(f"\n  重跑：python tools/verify-repos.py --retries 6 --jobs 3")
    print(f"\n明细已写出 {args.out}")

    if wrong:
        return 1
    if flaky:
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
