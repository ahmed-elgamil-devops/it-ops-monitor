"""IT Ops Monitor - a small status page for the services an IT team looks after.

It reads a list of targets from targets.yml, checks them on a schedule
(HTTP, TCP port, DNS), shows the result on a simple web page and exposes
Prometheus metrics so Grafana can graph uptime and response time.
"""

import asyncio
import os
import socket
import time
from contextlib import asynccontextmanager
from pathlib import Path

import httpx
import yaml
from fastapi import FastAPI, Response
from fastapi.responses import HTMLResponse
from prometheus_client import CONTENT_TYPE_LATEST, Gauge, generate_latest

TARGETS_FILE = Path(os.getenv("TARGETS_FILE", Path(__file__).parent / "targets.yml"))
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", "30"))
TIMEOUT = float(os.getenv("CHECK_TIMEOUT", "5"))

UP = Gauge("target_up", "1 if the target is reachable, 0 if not", ["name", "type"])
LATENCY = Gauge("target_response_seconds", "Time the last check took", ["name", "type"])

# latest result per target name
results: dict[str, dict] = {}


def load_targets(path: Path = TARGETS_FILE) -> list[dict]:
    with open(path, encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    targets = data.get("targets", [])
    for t in targets:
        if t.get("type") not in {"http", "tcp", "dns"}:
            raise ValueError(f"unknown check type for {t.get('name')}: {t.get('type')}")
    return targets


async def check_http(target: dict) -> bool:
    async with httpx.AsyncClient(timeout=TIMEOUT, follow_redirects=True) as client:
        r = await client.get(target["url"])
        return r.status_code < int(target.get("max_status", 400))


async def check_tcp(target: dict) -> bool:
    _, writer = await asyncio.wait_for(
        asyncio.open_connection(target["host"], int(target["port"])), timeout=TIMEOUT
    )
    writer.close()
    await writer.wait_closed()
    return True


async def check_dns(target: dict) -> bool:
    loop = asyncio.get_running_loop()
    await asyncio.wait_for(loop.run_in_executor(None, socket.gethostbyname, target["host"]), TIMEOUT)
    return True


CHECKS = {"http": check_http, "tcp": check_tcp, "dns": check_dns}


async def run_check(target: dict) -> dict:
    start = time.perf_counter()
    try:
        ok = await CHECKS[target["type"]](target)
        error = None
    except Exception as exc:  # any failure = target is down
        ok, error = False, f"{type(exc).__name__}: {exc}"[:200]
    took = round(time.perf_counter() - start, 3)

    UP.labels(target["name"], target["type"]).set(1 if ok else 0)
    LATENCY.labels(target["name"], target["type"]).set(took)
    result = {
        "name": target["name"],
        "type": target["type"],
        "group": target.get("group", "General"),
        "up": ok,
        "response_seconds": took,
        "error": error,
        "checked_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    results[target["name"]] = result
    return result


async def check_all(targets: list[dict]) -> list[dict]:
    return await asyncio.gather(*(run_check(t) for t in targets))


async def scheduler() -> None:
    while True:
        await check_all(load_targets())
        await asyncio.sleep(CHECK_INTERVAL)


@asynccontextmanager
async def lifespan(_: FastAPI):
    task = asyncio.create_task(scheduler()) if os.getenv("DISABLE_SCHEDULER") != "1" else None
    yield
    if task:
        task.cancel()


app = FastAPI(title="IT Ops Monitor", lifespan=lifespan)


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/api/status")
def api_status() -> dict:
    items = list(results.values())
    return {"total": len(items), "down": sum(not r["up"] for r in items), "targets": items}


@app.get("/metrics")
def metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/", response_class=HTMLResponse)
def status_page() -> str:
    rows = "".join(
        f"<tr><td>{r['group']}</td><td>{r['name']}</td><td>{r['type'].upper()}</td>"
        f"<td class={'up' if r['up'] else 'down'}>{'UP' if r['up'] else 'DOWN'}</td>"
        f"<td>{r['response_seconds']}s</td><td>{r['checked_at']}</td></tr>"
        for r in sorted(results.values(), key=lambda x: (x["group"], x["name"]))
    ) or "<tr><td colspan=6>Waiting for the first check...</td></tr>"
    down = sum(not r["up"] for r in results.values())
    banner = "All systems operational" if down == 0 else f"{down} service(s) down"
    return f"""<!doctype html><html><head><meta charset="utf-8">
<meta http-equiv="refresh" content="{CHECK_INTERVAL}"><title>IT Ops Monitor</title>
<style>body{{font-family:sans-serif;max-width:900px;margin:40px auto;padding:0 16px}}
table{{width:100%;border-collapse:collapse}}td,th{{padding:8px;border-bottom:1px solid #ddd;text-align:left}}
.up{{color:#137333;font-weight:bold}}.down{{color:#c5221f;font-weight:bold}}
.banner{{padding:12px;border-radius:6px;background:{'#e6f4ea' if down == 0 else '#fce8e6'}}}</style>
</head><body><h1>IT Ops Monitor</h1><p class="banner">{banner}</p>
<table><tr><th>Group</th><th>Service</th><th>Check</th><th>Status</th><th>Response</th><th>Last check</th></tr>
{rows}</table></body></html>"""
