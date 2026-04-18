FROM python:3.14-slim

ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

RUN useradd -m myuser

USER myuser

COPY extract.py .

ENTRYPOINT [ "python3.14", "extract.py" ]