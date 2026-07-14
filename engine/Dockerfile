FROM python:3.12-slim
WORKDIR /opt/aimd
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY aimd/ ./aimd/
# 비루트 실행 (ADR-0009). uid 1000 = WSL 호스트 사용자와 일치시켜 dist 쓰기 권한 확보
RUN useradd -u 1000 -m aimd
USER aimd
ENV AIMD_SRC_DIR=/opt/aimd/src AIMD_DIST_DIR=/opt/aimd/dist
CMD ["python", "-m", "uvicorn", "aimd.main:create_app", "--factory", \
     "--host", "0.0.0.0", "--port", "8000", "--lifespan", "off"]
