FROM python:3.12.12-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN useradd --system --uid 10001 --no-create-home first47

WORKDIR /opt/first47

COPY requirements.txt ./
RUN pip install --no-cache-dir --requirement requirements.txt

COPY app/stage_first47.py ./stage_first47.py

# The ECS task runs as root because different EFS access points enforce
# different POSIX identities (100:101 and 999:999) for separate mounts.
USER 0:0

ENTRYPOINT ["python", "/opt/first47/stage_first47.py"]
