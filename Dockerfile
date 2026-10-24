# --- build stage: install dependencies into a virtualenv ---
FROM python:3.12-slim AS build
WORKDIR /build
COPY app/requirements.txt .
RUN python -m venv /venv && /venv/bin/pip install --no-cache-dir -r requirements.txt

# --- runtime stage: small image, non-root user ---
FROM python:3.12-slim
LABEL org.opencontainers.image.source="https://github.com/ahmed-elgamil-devops/it-ops-monitor"
LABEL org.opencontainers.image.description="IT Ops Monitor status page"
RUN useradd --create-home --uid 10001 appuser
WORKDIR /srv
COPY --from=build /venv /venv
COPY app/ ./app/
ENV PATH="/venv/bin:$PATH" PYTHONUNBUFFERED=1
USER appuser
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request;urllib.request.urlopen('http://localhost:8000/healthz')"
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
