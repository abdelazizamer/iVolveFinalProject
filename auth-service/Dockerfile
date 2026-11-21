FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Keep Debian security fixes in the runtime image, including patched zlib packages.
RUN apt-get update \
    && apt-get upgrade --yes --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

COPY auth-service/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --requirement requirements.txt \
    && groupadd --system app \
    && useradd --system --gid app --home-dir /app --no-create-home app

COPY --chown=app:app auth-service/app.py ./app.py

USER app

EXPOSE 5000

CMD ["python", "app.py"]
