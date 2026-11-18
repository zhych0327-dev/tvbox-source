#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TVBox / 影视仓 单仓源自动更新脚本

流程：
  1. 读取 upstream.txt 中的上游源地址（每行一个，忽略 # 注释和空行）
  2. 并发拉取每个上游源的配置（兼容严格 JSON 与 JSONC 注释）
  3. 合并 sites / lives / rules / flags / parses，并按规范化 key 去重
  4. （可选）对站点做健康检查，剔除确认失活的条目
  5. 写入 config/tvbox.json，附带 last_updated / 统计信息

用法：
  python scripts/update.py                 # 拉取上游并合并写回
  python scripts/update.py --health-check  # 合并后做健康检查（较慢）
  python scripts/update.py --dry-run       # 只打印结果，不写文件
  python scripts/update.py --timeout 20    # 自定义单次请求超时（秒）
"""

import argparse
import concurrent.futures
import json
import os
import re
import urllib.request
from datetime import datetime, timezone

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
)

MERGE_SECTIONS = ("sites", "lives", "rules", "flags", "parses")
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UPSTREAM_FILE = os.path.join(BASE_DIR, "upstream.txt")
OUTPUT_FILE = os.path.join(BASE_DIR, "config", "tvbox.json")


def log(msg):
    print(f"[{datetime.now(timezone.utc).isoformat()}] {msg}", flush=True)


def strip_jsonc_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    lines = []
    for line in text.splitlines():
        if line.lstrip().startswith("//"):
            continue
        lines.append(line)
    return "\n".join(lines)


def parse_json_text(raw_text):
    try:
        return json.loads(raw_text)
    except json.JSONDecodeError:
        return json.loads(strip_jsonc_comments(raw_text))


def fetch_json(url, timeout):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    return parse_json_text(raw.decode("utf-8", "ignore"))


def normalize_key(value):
    if value is None:
        return ""
    return re.sub(r"[^a-z0-9]", "", str(value).lower())


def dedupe(items, key_fn):
    seen, out = set(), []
    for item in items:
        if not isinstance(item, dict):
            continue
        key = normalize_key(key_fn(item))
        if not key or key in seen:
            continue
        seen.add(key)
        out.append(item)
    return out


def load_upstreams(path):
    urls = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            urls.append(line)
    return urls


def check_url_ok(url, timeout):
    if not url or not url.startswith(("http://", "https://")):
        return True
    for method in ("HEAD", "GET"):
        try:
            req = urllib.request.Request(
                url, headers={"User-Agent": USER_AGENT, "Accept": "*/*"}, method=method)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.status < 400
        except Exception:
            if method == "GET":
                return False
    return False


def main():
    parser = argparse.ArgumentParser(description="TVBox 单仓源自动更新")
    parser.add_argument("--upstream", default=UPSTREAM_FILE)
    parser.add_argument("--output", default=OUTPUT_FILE)
    parser.add_argument("--timeout", type=float, default=15)
    parser.add_argument("--health-check", action="store_true")
    parser.add_argument("--health-workers", type=int, default=16)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    urls = load_upstreams(args.upstream)
    if not urls:
        log("upstream.txt 没有配置上游地址，仅输出空模板")
        merged = {s: [] for s in MERGE_SECTIONS}
    else:
        log(f"发现 {len(urls)} 个上游地址，开始拉取……")
        results = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
            future_map = {pool.submit(fetch_json, u, args.timeout): u for u in urls}
            for future in concurrent.futures.as_completed(future_map):
                url = future_map[future]
                try:
                    results[url] = future.result()
                    log(f"  成功  {url}")
                except Exception as exc:
                    log(f"  失败  {url}  -> {exc}")

        merged = {}
        for url, data in results.items():
            if not isinstance(data, dict):
                continue
            for section in MERGE_SECTIONS:
                items = data.get(section, [])
                if isinstance(items, list):
                    merged.setdefault(section, []).extend(items)
            url_list = data.get("url")
            if isinstance(url_list, list) and url_list:
                light = []
                for u in url_list:
                    if isinstance(u, str):
                        light.append({
                            "key": "src_%d" % len(light),
                            "name": (u.split("/")[-1] or "源"),
                            "url": u,
                            "type": 0,
                        })
                    else:
                        light.append(u)
                merged.setdefault("sites", []).extend(light)

    for section in MERGE_SECTIONS:
        items = merged.get(section, [])
        if section == "sites":
            merged[section] = dedupe(items, lambda x: x.get("key") or x.get("api") or x.get("url"))
        elif section == "lives":
            merged[section] = dedupe(items, lambda x: x.get("key") or x.get("name") or x.get("url"))
        else:
            merged[section] = dedupe(items, lambda x: json.dumps(x, ensure_ascii=False, sort_keys=True))

    if args.health_check:
        log("开始健康检查……")
        sites = merged.get("sites", [])
        dead = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.health_workers) as pool:
            future_map = {pool.submit(check_url_ok, s.get("api") or s.get("url"), args.timeout): s for s in sites}
            for future in concurrent.futures.as_completed(future_map):
                s = future_map[future]
                try:
                    ok = future.result()
                except Exception:
                    ok = False
                if not ok:
                    dead.append(s)
        if dead:
            dead_keys = {normalize_key(x.get("key") or x.get("api") or x.get("url")) for x in dead}
            merged["sites"] = [s for s in sites if normalize_key(s.get("key") or s.get("api") or s.get("url")) not in dead_keys]
            log(f"健康检查剔除 {len(dead)} 个失活站点")
        else:
            log("健康检查全部通过")

    merged["last_updated"] = datetime.now(timezone.utc).isoformat()
    merged["upstream_count"] = len(urls)
    merged["source_count"] = sum(len(merged.get(s, [])) for s in MERGE_SECTIONS)

    if args.dry_run:
        print(json.dumps(merged, ensure_ascii=False, indent=2))
        return 0

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)
    log(f"已写入 {args.output}（共 {merged['source_count']} 条，上游 {merged['upstream_count']} 个）")
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
