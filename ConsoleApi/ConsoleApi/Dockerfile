FROM python:3.8-slim

WORKDIR /src
COPY ["ConsoleApi/*", "/src"]

RUN pip install fastapi uvicorn[standard]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]