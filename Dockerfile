FROM python:3.13-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PYTHONPATH=/app/api
WORKDIR /app
COPY api/requirements.txt /app/api/requirements.txt
RUN pip install --no-cache-dir -r /app/api/requirements.txt && useradd --create-home --uid 10001 stockgo
COPY api /app/api
USER stockgo
EXPOSE 8081
CMD ["python", "-m", "stockgo_cloud.start"]
