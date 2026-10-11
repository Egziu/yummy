# Railway build for Yummy OS: the source lives in yummy-os.zip next to this file.
FROM python:3.13-slim AS src
COPY yummy-os.zip /tmp/src.zip
RUN python -m zipfile -e /tmp/src.zip /x && mv /x/yummy-os /src

FROM node:22-alpine AS frontend
WORKDIR /app
COPY --from=src /src/frontend/package.json /src/frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY --from=src /src/frontend/ ./
COPY --from=src /src/spec/ /spec/
RUN npx vite build

FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/* && useradd --create-home --uid 10001 yummy
WORKDIR /app
COPY --from=src /src/backend/requirements.txt .
RUN pip install -r requirements.txt
COPY --from=src /src/backend/ /app/
COPY --from=frontend /app/dist /app/frontend-dist
ENV YUMMY_FRONTEND_DIST=/app/frontend-dist
RUN YUMMY_DEBUG=1 python manage.py collectstatic --noinput -v0 && chmod +x /app/start.sh && chown -R yummy /app
USER yummy
EXPOSE 8080
CMD ["/app/start.sh"]
