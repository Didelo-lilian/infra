FROM python:3-alpine
ARG MODE=good
ARG VERSION=1
ENV MODE=$MODE VERSION=$VERSION
COPY app.py /app.py
USER nobody
CMD ["python", "/app.py"]
