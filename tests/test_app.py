import asyncio
import os

import pytest

os.environ["DISABLE_SCHEDULER"] = "1"

from fastapi.testclient import TestClient  # noqa: E402

from app import main  # noqa: E402

client = TestClient(main.app)


def test_healthz():
    assert client.get("/healthz").json() == {"status": "ok"}


def test_targets_file_is_valid():
    targets = main.load_targets()
    assert targets, "targets.yml should not be empty"
    assert all(t["type"] in {"http", "tcp", "dns"} for t in targets)


def test_bad_check_type_is_rejected(tmp_path):
    bad = tmp_path / "t.yml"
    bad.write_text("targets:\n  - name: x\n    type: ftp\n")
    with pytest.raises(ValueError):
        main.load_targets(bad)


def test_unreachable_target_is_marked_down():
    target = {"name": "closed-port", "type": "tcp", "host": "127.0.0.1", "port": 1}
    result = asyncio.run(main.run_check(target))
    assert result["up"] is False
    assert result["error"]


def test_status_page_and_metrics():
    asyncio.run(main.run_check({"name": "closed-port", "type": "tcp", "host": "127.0.0.1", "port": 1}))
    page = client.get("/")
    assert page.status_code == 200
    assert "DOWN" in page.text
    data = client.get("/api/status").json()
    assert data["down"] >= 1
    metrics = client.get("/metrics").text
    assert 'target_up{name="closed-port",type="tcp"} 0.0' in metrics
